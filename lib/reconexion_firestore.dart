import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, VoidCallback, visibleForTesting;
import 'package:flutter/widgets.dart';

/// Fuerza a Firestore a reconectar cuando la app vuelve de segundo plano.
///
/// El fallo que esto cierra: un Samsung (y otros Android) CONGELA la app en
/// segundo plano para ahorrar batería, y al congelarla le mata las
/// conexiones de red. El SDK de Firestore no se entera de que la suya murió
/// —no hay ningún aviso del sistema operativo para eso— y se queda callado
/// hasta que su propio backoff decide reintentar, que puede tardar. Con el
/// móvil en la mano y la pantalla del grupo delante nunca pasa (ver
/// pantalla_registro.dart): el fallo es solo con la app de fondo o la
/// pantalla apagada, que es justo cuando nadie está mirando para notar el
/// retraso... hasta que vuelve a mirar y los cambios de mientras tanto no
/// están.
///
/// ES EL MISMO CULPÁN — «la plataforma congela y mata conexiones sin
/// avisar»— que ya se cerró para Auth en web (ver `almacen_roto.dart`), pero
/// la cura es distinta a propósito:
///
/// - En web la cura fue recargar la página entera, porque lo que se rompía
///   ahí era IndexedDB, el almacén mismo, no una conexión — reintentar sobre
///   un recurso roto no lo repara, hay que reconstruirlo. Ese fallo no
///   aplica aquí: no hay IndexedDB en Android/iOS, y el SDK nativo de
///   Firestore no pasa por ahí. Por eso `observarReconexionFirestoreAlVolver`
///   no hace nada en web (ver el `if (kIsWeb)` de abajo) — si una pestaña
///   web se congeló de verdad, `almacen_roto.dart` ya la recarga entera en
///   cuanto algo la toca, y una recarga completa deja Firestore reconectado
///   igual que todo lo demás; forzar aquí ADEMÁS una reconexión de Firestore
///   no añadiría nada, solo un camino más que mantener.
/// - En Android/iOS lo que se rompe es la conexión, no el almacén: no hace
///   falta reconstruir nada, basta con pedirle al SDK que abra una conexión
///   nueva. Por eso la cura aquí es mucho más barata que una recarga.
///
/// ## Dónde vive el observador: uno solo, central
///
/// Hoy dos pantallas escuchan Firestore en vivo (`pantalla_registro.dart`,
/// con dos suscripciones, y `pantalla_chat.dart`), pero nada de esto es
/// propio de esas pantallas — es un problema de la CONEXIÓN, que es una sola
/// para toda la app (`FirebaseFirestore.instance` es un singleton). Poner un
/// `WidgetsBindingObserver` en cada pantalla que escucha en vivo repetiría
/// la misma reconexión tantas veces como pantallas hubiera abiertas a la vez
/// (cada una la fuerza por su cuenta, sin saber de las demás), y hay que
/// acordarse de añadirlo cada vez que una pantalla nueva empiece a escuchar
/// — se olvidaría tarde o temprano. Con un único enganche para toda la app,
/// registrado una vez y para siempre (ver `observarReconexionFirestoreAlVolver`,
/// llamado desde `_PantallaRaizState.initState()` igual que `alTocarAviso`
/// en `push.dart`), da igual cuántas pantallas escuchen ni cuántas se añadan
/// mañana: todas comparten la misma conexión y a todas las arregla el mismo
/// sitio.
///
/// ## Qué mecanismo se usa, y por qué
///
/// `FirebaseFirestore.instance.disableNetwork()` seguido de `enableNetwork()`.
/// Es la única pareja del SDK pensada para esto: apaga la capa de red del
/// cliente y la vuelve a encender, obligándolo a abrir un canal nuevo en vez
/// de esperar a que el suyo, ya muerto, decida solo que ha llegado la hora
/// de reintentar.
///
/// Se descartaron dos alternativas más agresivas:
/// - `terminate()` + volver a pedir `FirebaseFirestore.instance`: además de
///   cerrar la conexión, DESTRUYE la instancia — habría que reconstruir cada
///   referencia y cada `listen()` de cada pantalla abierta, o se quedarían
///   escuchando un objeto muerto. Un martillo mucho más grande del que hace
///   falta para "reconectar".
/// - `clearPersistence()`: ni siquiera es una opción real aquí — su propia
///   documentación exige que la instancia esté PARADA (nada de listeners
///   vivos) para poder llamarla, justo lo contrario de lo que hay cuando la
///   app vuelve de segundo plano con pantallas abiertas.
///
/// Lo importante, comprobado en la documentación del propio método antes de
/// elegirlo: `disableNetwork()` deja dicho explícitamente que la base local
/// se sigue actualizando y que "any listeners will still trigger" mientras
/// la red está apagada. O sea, el `listen()` de `pantalla_registro.dart` NO
/// se cae ni hay que resuscribirlo — sigue siendo el mismo `Stream`, la
/// misma suscripción, solo que su próxima entrega llega por la conexión
/// nueva en vez de por la vieja. Cortar y devolver la red no rompe las
/// pantallas que hoy funcionan bien; es justo la garantía que hacía falta
/// para no cambiar un fallo por otro.
///
/// ## Cuándo se dispara: `onRestart`, no `onResume`
///
/// `AppLifecycleListener.onRestart` —"called when the application is
/// resumed after being paused"— solo dispara tras haber pasado de verdad por
/// `paused`, que es exactamente "estuvo de fondo, quizá congelada, y
/// vuelve". `onResume` en cambio dispara TAMBIÉN en el arranque en frío (la
/// primera vez que la app entra en `resumed`, sin haber estado nunca de
/// fondo), donde forzar una reconexión no tiene sentido: Firestore ni
/// siquiera ha tenido tiempo de abrir su primera conexión. Con `onRestart`
/// ese caso ni se plantea. Y, según la propia documentación de Flutter,
/// `onRestart` "no se llama en web ni en escritorio" — un motivo más, aparte
/// del explicado arriba, para que el `if (kIsWeb)` de
/// `observarReconexionFirestoreAlVolver` no le quite nada a la web: ahí este
/// callback ni dispararía.
void observarReconexionFirestoreAlVolver({VoidCallback? reconectar}) {
  // Ver el porqué en el comentario de arriba: en web este fallo no se da
  // (no hay conexión nativa que el sistema operativo mate al congelar la
  // pestaña) y, si la pestaña se congeló de verdad, `almacen_roto.dart` ya
  // la recarga entera en cuanto algo la toca — lo que deja Firestore
  // reconectado igual que todo lo demás, sin que este archivo tenga que
  // hacer nada.
  if (kIsWeb) return;
  _escucha = AppLifecycleListener(onRestart: reconectar ?? forzarReconexionFirestore);
}

/// Guarda la escucha para que no la recoja el recolector de basura. En la
/// app de verdad no hace falta soltarla nunca: tiene que vivir mientras
/// viva la app entera, igual que las suscripciones de `alTocarAviso` en
/// `push.dart`, que tampoco se cancelan nunca por el mismo motivo. Sí hace
/// falta poder soltarla en pruebas — ver `olvidarEscuchaParaPruebas` más
/// abajo— para que un test no deje colgada una escucha que el siguiente test
/// del mismo archivo duplicaría.
AppLifecycleListener? _escucha;

/// SOLO para pruebas: suelta la escucha creada por
/// `observarReconexionFirestoreAlVolver` para que el siguiente test pueda
/// crear la suya sin acumular una segunda escuchando por detrás.
@visibleForTesting
void olvidarEscuchaParaPruebas() {
  _escucha?.dispose();
  _escucha = null;
}

/// La reconexión de verdad. Aparte de `observarReconexionFirestoreAlVolver`
/// para poder probarla sin depender del ciclo de vida real de la app, y
/// pública para que la pantalla de arranque pueda sustituirla en sus
/// pruebas por un doble que cuenta cuántas veces se llamó.
///
/// NUNCA lanza: la llama un callback de ciclo de vida del que nadie espera
/// el resultado, así que un fallo aquí no puede tumbar nada. Sin red, sin
/// Firebase inicializado (como en un test, donde ya se prueba que esto no
/// revienta) o cualquier otro fallo, se ignora sin más: si la reconexión de
/// verdad hacía falta, el intento normal del propio SDK sigue en marcha
/// exactamente como antes de este cambio, y la próxima vez que la app pase
/// por `paused` se vuelve a intentar.
@visibleForTesting
Future<void> forzarReconexionFirestore() async {
  try {
    final firestore = FirebaseFirestore.instance;
    await firestore.disableNetwork();
    await firestore.enableNetwork();
  } catch (_) {
    // Ver el comentario de arriba: nunca debe propagarse.
  }
}
