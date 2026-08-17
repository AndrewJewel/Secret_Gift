import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;

import 'almacen_local.dart';
import 'funciones.dart';

/// Sacada de la consola: Configuración del proyecto → Cloud Messaging →
/// Web Push certificates. Es del proyecto `secretgift-app`; una del
/// proyecto viejo falla con un error genérico que no dice qué pasa.
///
/// SOLO sirve para web. En Android el dispositivo se identifica con
/// `google-services.json`, y pasarle una vapidKey a `getToken` allí no
/// hace nada.
const _vapid =
    'BLGXuBp6beexh8mJZ3sDdVADhSSYFWrbuEoL3-Vm2U_7rpo4E_VBaWaRBEVC68cdFCQ6LzJIT7qkw8lL48vioi8';

/// Qué grupo se está mirando ahora mismo, o null.
///
/// Lo escribe la pantalla de chat. Sirve para NO enseñar el aviso de un
/// mensaje a quien está leyendo ese mismo chat.
String? _grupoALaVista;

void mirandoGrupo(String? codigo) {
  _grupoALaVista = codigo;
}

/// SOLO para pruebas: expone `_grupoALaVista` para poder comprobar, sin
/// necesitar FCM de verdad, que las pantallas que declaran "te estoy
/// mirando" (ver el mixin `ConGrupoALaVista` en `grupo_a_la_vista.dart`) lo
/// hacen y lo deshacen en el momento correcto.
@visibleForTesting
String? get grupoALaVistaParaPruebas => _grupoALaVista;

/// Si un estado del permiso del sistema deja mandar avisos.
///
/// `provisional` cuenta: es el permiso silencioso de iOS, que entrega los
/// avisos aunque sin sonido.
bool permisoConcedido(AuthorizationStatus estado) =>
    estado == AuthorizationStatus.authorized ||
    estado == AuthorizationStatus.provisional;

/// Qué dice el sistema AHORA sobre el permiso, sin pedirle nada a nadie.
///
/// `getNotificationSettings()` solo LEE el estado —en web es literalmente
/// `Notification.permission`, en Android `areNotificationsEnabled()`— y por
/// eso es seguro llamarla en cualquier sitio y tantas veces como haga
/// falta. `getToken()` NO lo es: ver el comentario de
/// `tokenDeEsteDispositivo`.
///
/// Ante un fallo responde `notDetermined`, que es la respuesta prudente:
/// "no consta que esté concedido", y con ella nadie registra nada.
Future<AuthorizationStatus> estadoDelPermiso() async {
  try {
    final ajustes = await FirebaseMessaging.instance.getNotificationSettings();
    return ajustes.authorizationStatus;
  } catch (_) {
    return AuthorizationStatus.notDetermined;
  }
}

/// Si los avisos están de verdad activos PARA ESTA CUENTA en ESTE
/// dispositivo. Función pura, sin nada de FCM a propósito —igual que
/// `debeAbrirseElAviso`—: los dos únicos defectos del cliente que llegaron
/// hasta la revisión final vivían justo en esta decisión, y así se prueban
/// con un test normal.
///
/// Hacen falta las DOS condiciones. El interruptor de Configuración leía
/// solo `getToken() != null`, y eso significa "este dispositivo puede tener
/// un token", que no es lo mismo:
///
/// - Con el permiso denegado, `getToken()` pedía el permiso él solo y, si
///   ya estaba quemado, lanzaba; el `catch` lo volvía null. Ahora el
///   permiso se lee aparte y sin pedirlo.
/// - Con el permiso concedido pero el servidor SIN el token —falló la red
///   justo después de aceptar, o se cambió de cuenta en este mismo
///   dispositivo— el interruptor decía ENCENDIDO y no llegaba ni un aviso.
bool avisosActivos(AuthorizationStatus estadoPermiso, bool hayTokenEnServidor) =>
    permisoConcedido(estadoPermiso) && hayTokenEnServidor;

/// Lo mismo, leyendo el estado real. No pide permiso ni toca el servidor.
Future<bool> avisosActivosAhora() async =>
    avisosActivos(await estadoDelPermiso(), await hayTokenPushEnServidor());

/// Pide el permiso al sistema y registra el token.
///
/// SOLO debe llamarse desde el «Sí, avísame» de PantallaPermisoAvisos y
/// desde el interruptor de Configuración. Llamarla en cualquier otro sitio
/// gasta el permiso del navegador, que solo se puede pedir una vez.
///
/// Nunca lanza: quien la llama (la pantalla de permiso) solo tiene un
/// `try/finally` alrededor, sin `catch`, porque hasta ahora `alAceptar` no
/// podía fallar. Aquí sí puede — permiso denegado por el sistema, red
/// caída, VAPID inválida, *service worker* que no arranca — y todo eso se
/// traduce en `false`, el mismo valor que ya se usaba para "no quedó
/// registrado". Quien llame no ve diferencia entre un "no" de la persona y
/// un fallo técnico, y no la necesita: en los dos casos lo único que puede
/// hacer es reintentarlo más tarde.
Future<bool> pedirPermisoYRegistrar() async {
  try {
    final messaging = FirebaseMessaging.instance;
    final ajustes = await messaging.requestPermission();
    if (!permisoConcedido(ajustes.authorizationStatus)) {
      // Dijo que no en el cuadro del sistema. La intención queda en "no"
      // para que la reconciliación del arranque no le registre nada por su
      // cuenta si el permiso se concediera después desde los ajustes del
      // navegador.
      await marcarAvisosQueridos(false);
      return false;
    }

    // La intención se marca AQUÍ, antes de llamar al servidor, y no
    // después de que salga bien: si `guardarTokenPush` falla por red, esta
    // persona SÍ quiere avisos y el permiso ya está concedido. Con la
    // marca puesta, `reconciliarAvisos` lo arregla sola en el arranque
    // siguiente. Al revés —marcarla solo tras el éxito— era el segundo de
    // los tres caminos que dejaban a alguien sin avisos para siempre y en
    // silencio, porque la pantalla de permiso ya no se vuelve a ofrecer.
    await marcarAvisosQueridos(true);
    return await _registrarToken(messaging);
  } catch (_) {
    // Ver el comentario de arriba: esta función nunca lanza. Cualquier
    // fallo —permiso, red, VAPID, service worker— se cuenta como "no
    // quedó registrado".
    return false;
  }
}

/// Vuelve a dejar el token de este dispositivo en la cuenta que hay
/// abierta. Es la reconciliación del arranque, y sin ella el token se
/// escribía UNA vez y no lo revisaba nadie nunca más.
///
/// No pide permiso: solo mira el que ya hay. Si no está concedido, o si en
/// este dispositivo nadie pidió los avisos (o los apagó), no hace nada.
///
/// Nunca lanza: se llama en pleno camino de entrada.
Future<bool> reconciliarAvisos() async {
  try {
    if (!await avisosQueridosAqui()) return false;
    if (!permisoConcedido(await estadoDelPermiso())) return false;
    return await _registrarToken(FirebaseMessaging.instance);
  } catch (_) {
    // Sin red no hay nada que hacer más que reintentarlo en el arranque
    // siguiente. `hayTokenPushEnServidor` sigue en false, así que el
    // interruptor dirá "apagado", que es la verdad.
    return false;
  }
}

/// Pide el token y lo guarda en la cuenta abierta. Único sitio que escribe
/// `guardarTokenPush` en el camino normal, para que la marca local y la
/// escucha de renovaciones no puedan quedar descuadradas según por dónde
/// se llegue.
Future<bool> _registrarToken(FirebaseMessaging messaging) async {
  // La vapidKey SOLO en web. En Android el dispositivo ya está
  // identificado por google-services.json.
  final token = await messaging.getToken(vapidKey: kIsWeb ? _vapid : null);
  if (token == null) return false;
  await llamarFuncion('guardarTokenPush', {'token': token});
  await marcarTokenPushEnServidor(true);
  _escucharRenovaciones(messaging);
  return true;
}

/// La escucha de renovaciones del token, o null si no hay ninguna viva.
///
/// Se guarda para poder CANCELARLA al apagar los avisos o al cerrar
/// sesión. Antes se suscribía sin guardar nada: la escucha sobrevivía al
/// apagado y podía volver a registrar el token ella sola, y además se
/// suscribía otra vez en cada `pedirPermisoYRegistrar`, acumulando
/// escuchas duplicadas sobre el mismo stream.
StreamSubscription<String>? _escuchaDeRenovaciones;

/// El token puede cambiar sin que nadie haga nada. Si no se vuelve a
/// guardar, los avisos dejan de llegar sin que nadie se entere.
///
/// EN WEB NO SIRVE DE NADA: `onTokenRefresh` de `firebase_messaging_web`
/// es un stream vacío que NO EMITE JAMÁS (`_noopOnTokenRefreshStream`, con
/// el propio paquete documentando que la API está obsoleta en web). Por eso
/// se sale antes en web —suscribirse allí sería fingir una protección que
/// no existe— y por eso la reconciliación del arranque
/// (`reconciliarAvisos`) es la ÚNICA red que hay en web contra un token que
/// cambia.
void _escucharRenovaciones(FirebaseMessaging messaging) {
  if (kIsWeb) return;
  if (_escuchaDeRenovaciones != null) return;
  _escuchaDeRenovaciones = messaging.onTokenRefresh.listen((nuevo) async {
    try {
      await llamarFuncion('guardarTokenPush', {'token': nuevo});
      await marcarTokenPushEnServidor(true);
    } catch (_) {
      // Renovar en segundo plano no puede molestar a nadie con un error.
    }
  });
}

Future<void> _dejarDeEscucharRenovaciones() async {
  final escucha = _escuchaDeRenovaciones;
  _escuchaDeRenovaciones = null;
  await escucha?.cancel();
}

/// El token de esta instalación, o null si no hay.
///
/// La comprobación del permiso NO es un adorno ni un atajo: `getToken()`
/// PIDE EL PERMISO ÉL MISMO. En el SDK de JavaScript que carga esta app
/// (firebase-js 12.17.0) lo primero que hace es
/// `if ("default" === Notification.permission) await
/// Notification.requestPermission()`, y si no queda concedido lanza
/// `permission-blocked`. O sea: llamarla sin más abría el cuadro del
/// navegador a quien solo venía a cambiar el idioma, sin contexto y sin
/// haberlo pedido — y si lo denegaba ahí, el permiso quedaba quemado para
/// siempre. `getNotificationSettings()` sí es de solo lectura, así que
/// preguntándole antes se sale sin tocar nada.
Future<String?> tokenDeEsteDispositivo() async {
  try {
    if (!permisoConcedido(await estadoDelPermiso())) return null;
    return await FirebaseMessaging.instance
        .getToken(vapidKey: kIsWeb ? _vapid : null);
  } catch (_) {
    return null;
  }
}

/// Apaga los avisos en ESTE dispositivo, de verdad y para que se quede
/// apagado.
///
/// Tres cosas, y las tres hacen falta:
/// - La intención pasa a "no", o la reconciliación del arranque volvería a
///   registrar el token en cuanto se reabriera la app (el permiso del
///   sistema sigue concedido, apagar el interruptor no lo revoca).
/// - Se borra el token en el servidor, o los avisos seguirían saliendo.
/// - Se borra el token en el dispositivo (`deleteToken`), o el interruptor
///   volvería a salir ENCENDIDO al reabrir Configuración.
Future<void> apagarAvisos() async {
  await marcarAvisosQueridos(false);
  await soltarTokenDeEsteDispositivo();
}

/// Suelta el token de este dispositivo de la cuenta que hay abierta, sin
/// tocar la intención.
///
/// Se llama al cerrar sesión (ver `salir()` en `acceso_cuenta.dart`), y
/// ahí el orden importa: ANTES del `signOut`, porque borrar el token en el
/// servidor necesita justo la sesión que se va a cerrar. Sin esto, el
/// token seguía colgando de la cuenta anterior: esa cuenta seguía
/// recibiendo avisos en este teléfono y tocar uno abría el alta de su
/// grupo, entregándole el código —la única llave que hay— a quien ahora
/// usa el teléfono.
///
/// `deleteToken()` además obliga a acuñar un token NUEVO, así que la
/// cuenta siguiente no hereda el identificador de la anterior.
///
/// La intención (`avisosQueridos`) NO se toca a propósito: es del
/// dispositivo, no de la cuenta. Conservarla es lo que hace que la cuenta
/// siguiente registre su propio token en `reconciliarAvisos` sin volver a
/// preguntarle nada a nadie.
///
/// Nunca lanza, y NUNCA tarda más de [_topeSoltarToken].
Future<void> soltarTokenDeEsteDispositivo() async {
  // Lo que no toca la red va PRIMERO y fuera del tope: si el tope salta,
  // el estado local que lee el interruptor ya quedó en "apagado" —que es
  // la verdad para la cuenta que se va— en vez de heredarse a la
  // siguiente. Bajar la marca antes es además el orden seguro: mentir
  // hacia "apagado" hace que se vuelva a intentar; mentir hacia
  // "encendido" es el fallo que esta ronda vino a arreglar.
  await marcarTokenPushEnServidor(false);
  await _dejarDeEscucharRenovaciones();

  // UN SOLO tope, y envuelve TODAS las llamadas de red de golpe. Acotar
  // únicamente el POST de `borrarTokenPush` no bastaba: en este mismo
  // camino hay otras tres esperas que también pueden colgarse —
  // `getNotificationSettings()`, `getToken()` y `deleteToken()`—, y
  // `getToken()` en web espera a `navigator.serviceWorker.ready`, que NO
  // TERMINA NUNCA si el service worker no llega a activar (justo lo que
  // puede pasar en un dispositivo que aún tenga cacheado el service worker
  // viejo tras el salto a firebase-js 12.17.0).
  //
  // Esto está en el camino de cerrar sesión, y ese botón no tiene ni
  // indicador ni estado deshabilitado: sin el tope, cerrar sesión se
  // quedaba colgado con el botón repulsable cuando antes era instantáneo.
  // Al expirar se sigue adelante y la sesión se cierra igual — no poder
  // soltar el token no puede impedirle a nadie salir de su cuenta.
  //
  // El tope no cancela nada, solo deja de esperar: si las llamadas
  // terminan más tarde, lo hacen sobre una sesión ya cerrada y sus fallos
  // se los tragan los `catch` de dentro.
  await _soltarEnElServidor().timeout(_topeSoltarToken, onTimeout: () {});
}

/// Cuánto se espera como MUCHO a soltar el token. Pasado esto se sigue
/// adelante sin él.
const _topeSoltarToken = Duration(seconds: 6);

/// La parte que habla con la red. Separada solo para poder envolverla
/// entera en un único `timeout`. Nunca lanza.
Future<void> _soltarEnElServidor() async {
  try {
    final token = await tokenDeEsteDispositivo();
    if (token != null) {
      try {
        await llamarFuncion('borrarTokenPush', {'token': token});
      } catch (_) {
        // Apagar no puede romperle la pantalla a nadie. Y aunque el
        // servidor se quede con el token, el `deleteToken()` de abajo lo
        // mata: el primer envío lo verá muerto y lo limpiará solo (ver
        // `tokensMuertos` en functions/push.js).
      }
    }
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {
      // Idem.
    }
  } catch (_) {
    // Nunca lanza: quien la llama está cerrando sesión o apagando un
    // interruptor, y ninguna de las dos cosas puede fallar por esto.
  }
}

/// Decide si hay que abrir un aviso, a partir de su identificador de
/// mensaje y del último que ya se abrió. Función pura, sin nada de FCM, a
/// propósito: así se puede probar el deduplicado con un test normal, sin
/// tener que simular nada de Firebase.
///
/// El identificador es el `messageId` que pone FCM a CADA envío —no el
/// código del grupo—. Los tres avisos de esta app (reemplazo, sorteo,
/// mensajes de chat) comparten `codigo`: deduplicar por código
/// descartaría en silencio un aviso distinto y legítimo del mismo grupo
/// que llegara después. `messageId` sí identifica un envío concreto, así
/// que solo descarta el caso que de verdad hay que descartar: que
/// `getInitialMessage()` y `onMessageOpenedApp` informen los dos del
/// MISMO mensaje al arrancar en frío.
///
/// Sin identificador —FCM no lo garantiza siempre— se abre igual: es
/// preferible abrir de más que dejar un aviso legítimo sin abrir nunca.
bool debeAbrirseElAviso(String? idDelMensaje, String? ultimoIdAbierto) {
  if (idDelMensaje == null) return true;
  return idDelMensaje != ultimoIdAbierto;
}

/// Qué hacer cuando alguien toca un aviso, y qué hacer con los que llegan
/// con la app abierta.
void alTocarAviso(void Function(String codigo) abrir) {
  // Con la app EN PRIMER PLANO, FCM no enseña nada por su cuenta —ni en
  // web ni en Android—: salta esto y decidimos nosotros. Por eso no hace
  // falta que el servidor sepa quién está mirando qué, que sería una
  // escritura de presencia por persona y por segundo.
  //
  // Y no enseñamos nada: si estás dentro de la app, ya ves el cambio.
  // Avisar a quien está leyendo el chat de que hay un mensaje en ese
  // mismo chat es la forma rápida de que apague los avisos para siempre.
  FirebaseMessaging.onMessage.listen((mensaje) {
    final codigo = mensaje.data['codigo'];
    if (codigo != null && codigo == _grupoALaVista) return;
    // El resto tampoco se enseña por ahora: la app está abierta y sus
    // pantallas ya se actualizan solas.
  });

  // El mismo toque puede, según la plataforma, contarlo tanto
  // `getInitialMessage` como `onMessageOpenedApp` de abajo. Se recuerda el
  // `messageId` del último aviso ya abierto —ver `debeAbrirseElAviso`— y
  // no el código del grupo: dos avisos DISTINTOS del mismo grupo tienen
  // que abrirse los dos.
  String? ultimoIdAbierto;
  void abrirSiCorresponde(RemoteMessage mensaje) {
    final codigo = mensaje.data['codigo'];
    if (codigo is! String) return;
    if (!debeAbrirseElAviso(mensaje.messageId, ultimoIdAbierto)) return;
    ultimoIdAbierto = mensaje.messageId;
    abrir(codigo);
  }

  // Tocar el aviso con la app en segundo plano (el proceso sigue vivo).
  FirebaseMessaging.onMessageOpenedApp.listen(abrirSiCorresponde);

  // Tocar el aviso con la app completamente cerrada, sin proceso vivo: el
  // arranque es en frío y `onMessageOpenedApp` no dispara para ese primer
  // mensaje —ese stream solo ve toques mientras la app ya estaba
  // corriendo—; FCM entrega el mensaje que despertó el proceso por aquí.
  // Es, además, el caso más frecuente: un aviso suele llegar minutos u
  // horas después, con la app cerrada, así que sin esto el enganche de
  // tocar un aviso no serviría para nada en la práctica.
  FirebaseMessaging.instance.getInitialMessage().then((mensaje) {
    if (mensaje != null) abrirSiCorresponde(mensaje);
  });
}
