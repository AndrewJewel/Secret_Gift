import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;

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

/// Pide el permiso al navegador y registra el token.
///
/// SOLO debe llamarse desde el «Sí, avísame» de PantallaPermisoAvisos.
/// Llamarla en cualquier otro sitio gasta el permiso del navegador, que
/// solo se puede pedir una vez.
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
    if (ajustes.authorizationStatus != AuthorizationStatus.authorized &&
        ajustes.authorizationStatus != AuthorizationStatus.provisional) {
      return false;
    }

    // La vapidKey SOLO en web. En Android el dispositivo ya está
    // identificado por google-services.json.
    final token = await messaging.getToken(vapidKey: kIsWeb ? _vapid : null);
    if (token == null) return false;
    await llamarFuncion('guardarTokenPush', {'token': token});

    // El token puede cambiar sin que nadie haga nada (el navegador lo
    // renueva). Si no se vuelve a guardar, los avisos dejan de llegar sin
    // que nadie se entere.
    messaging.onTokenRefresh.listen((nuevo) {
      llamarFuncion('guardarTokenPush', {'token': nuevo}).catchError((_) {
        // Renovar en segundo plano no puede molestar a nadie con un error.
        return <String, dynamic>{};
      });
    });

    return true;
  } catch (_) {
    // Ver el comentario de arriba: esta función nunca lanza. Cualquier
    // fallo —permiso, red, VAPID, service worker— se cuenta como "no
    // quedó registrado".
    return false;
  }
}

/// El token de esta instalación, o null si no hay.
///
/// No pide permiso: si no está concedido, `getToken` devuelve null y eso
/// es exactamente la respuesta que queremos aquí.
Future<String?> tokenDeEsteDispositivo() async {
  try {
    return await FirebaseMessaging.instance
        .getToken(vapidKey: kIsWeb ? _vapid : null);
  } catch (_) {
    return null;
  }
}

/// Apaga los avisos en ESTE dispositivo, de verdad.
///
/// Borra el token en el servidor. Sin esto, apagar el interruptor sería
/// decorativo: el servidor seguiría mandando avisos a este dispositivo.
Future<void> apagarAvisos() async {
  final token = await tokenDeEsteDispositivo();
  if (token == null) return;
  try {
    await llamarFuncion('borrarTokenPush', {'token': token});
  } catch (_) {
    // Apagar no puede romperle la pantalla a nadie.
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
