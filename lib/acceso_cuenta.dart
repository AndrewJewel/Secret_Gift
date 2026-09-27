import 'package:firebase_auth/firebase_auth.dart';

import 'auth.dart';
import 'funciones.dart';
import 'idioma.dart';
import 'push.dart';

/// El perfil y los grupos de quien ha entrado.
class ResultadoAcceso {
  final String nombre;
  final String apellido;
  final List<Map<String, dynamic>> grupos;
  const ResultadoAcceso(this.nombre, this.apellido, this.grupos);
}

/// Convierte cualquier fallo de Auth en el [FuncionError] que la interfaz
/// ya sabe traducir. Todo lo de este fichero pasa por aquí.
Future<T> _traduciendo<T>(Future<T> Function() accion) async {
  try {
    return await accion();
  } on FirebaseAuthException catch (e) {
    throw comoFuncionError(e);
  }
}

/// Registra la cuenta, guarda el perfil y manda el correo de verificación.
///
/// El orden importa: si `guardarPerfil` fallara después de mandar el
/// correo, quedaría alguien verificado y sin PIN. Primero el perfil.
Future<MedioVerificacion> crearCuenta({
  required String correo,
  required String password,
  required String nombre,
  required String apellido,
  required String pin,
}) async {
  await _traduciendo(() => FirebaseAuth.instance
      .createUserWithEmailAndPassword(email: correo.trim(), password: password));
  await llamarFuncion('guardarPerfil', {
    'nombre': nombre.trim(),
    'apellido': apellido.trim(),
    'pin': pin.trim(),
  });
  return mandarVerificacion();
}

Future<void> entrar({required String correo, required String password}) =>
    _traduciendo(() => FirebaseAuth.instance
        .signInWithEmailAndPassword(email: correo.trim(), password: password));

/// Cómo le llegó a la persona lo que tiene que hacer para verificar.
enum MedioVerificacion { codigo, enlace, yaVerificado }

typedef LlamadaServidor = Future<Map<String, dynamic>> Function(
    String nombre, Map<String, dynamic> datos);

/// Errores que son de quien usa la app: se enseñan tal cual. Cualquier otro
/// (Resend caído, clave sin poner, cuota agotada) cae al correo de Firebase
/// de siempre, para que nadie se quede sin poder entrar.
const _sinRespaldo = {'demasiados_correos', 'sesion_invalida', 'correo_invalido'};

/// Manda el código de verificación (correo propio, Resend). Si falla,
/// manda el enlace de Firebase y lo dice en lo que devuelve.
Future<MedioVerificacion> mandarVerificacion({
  LlamadaServidor llamar = llamarFuncion,
  Future<void> Function() respaldo = _enlaceDeFirebase,
}) async {
  try {
    final r = await llamar(
        'mandarCodigoVerificacion', {'idioma': Idioma.actual.value.languageCode});
    return r['yaVerificado'] == true
        ? MedioVerificacion.yaVerificado
        : MedioVerificacion.codigo;
  } on FuncionError catch (e) {
    if (_sinRespaldo.contains(e.clave)) rethrow;
    await respaldo();
    return MedioVerificacion.enlace;
  }
}

/// `setLanguageCode` va ANTES de mandarlo: es lo único que decide el idioma
/// del correo de Firebase.
Future<void> _enlaceDeFirebase() async {
  final u = FirebaseAuth.instance.currentUser;
  if (u == null) {
    throw FuncionError('auth', 'sesion_invalida', 'No hay sesión.');
  }
  await FirebaseAuth.instance.setLanguageCode(Idioma.actual.value.languageCode);
  await _traduciendo(() => u.sendEmailVerification());
}

/// Comprueba el código y, si es bueno, recarga la sesión para que el token
/// nuevo ya diga email_verified: true (si no, el servidor seguiría
/// respondiendo `correo_sin_verificar`).
Future<void> verificarCodigo(
  String codigo, {
  LlamadaServidor llamar = llamarFuncion,
  Future<bool> Function() confirmar = correoVerificado,
}) async {
  await llamar('verificarCodigo', {'codigo': codigo});
  await confirmar();
}

/// Manda el correo para poner una contraseña nueva (propio, con botón).
///
/// **Nunca dice si ese correo tiene cuenta:** el servidor responde ok
/// igual, y el respaldo de Firebase se traga `user-not-found`. Quien llama
/// debe enseñar SIEMPRE el mismo mensaje.
Future<void> mandarRecuperacion(
  String correo, {
  LlamadaServidor llamar = llamarFuncion,
  Future<void> Function(String) respaldo = _recuperacionDeFirebase,
}) async {
  final limpio = correo.trim();
  try {
    await llamar('mandarCorreoRecuperacion',
        {'correo': limpio, 'idioma': Idioma.actual.value.languageCode});
  } on FuncionError catch (e) {
    if (_sinRespaldo.contains(e.clave)) rethrow;
    await respaldo(limpio);
  }
}

Future<void> _recuperacionDeFirebase(String correo) async {
  await FirebaseAuth.instance.setLanguageCode(Idioma.actual.value.languageCode);
  try {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: correo);
  } on FirebaseAuthException catch (e) {
    if (e.code == 'user-not-found') return;
    throw comoFuncionError(e);
  }
}

/// Recarga al usuario desde el servidor y dice si ya verificó.
///
/// Hace falta recargar: `emailVerified` es una foto del token, y el token
/// se hizo antes de que esa persona pinchara el enlace.
Future<bool> correoVerificado() async {
  final u = FirebaseAuth.instance.currentUser;
  if (u == null) return false;
  // Firebase Auth guarda la sesión en IndexedDB, y los navegadores móviles
  // la cierran cuando la pestaña pasa a segundo plano para ahorrar
  // memoria — justo lo que pasa al salir al buzón de correo a pinchar el
  // enlace y volver. El primer reload() puede toparse con esa base de
  // datos cerrada o cerrándose y fallar aunque todo esté bien. reload()
  // es de solo lectura e idempotente, así que un único reintento tras una
  // espera corta (para dar tiempo a que termine de cerrarse y el SDK la
  // reabra) es seguro, sin necesidad de mirar qué error fue.
  try {
    await _traduciendo(() => u.reload());
  } catch (_) {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    try {
      await _traduciendo(() => u.reload());
    } on FuncionError catch (e) {
      // Misma marca que usa tokenActual() en auth.dart, y por el mismo
      // motivo: este fallo y el de tokenActual() llegan con el mismo
      // código y clave genéricos, y sin distinguirlos no hay forma de
      // saber, leyendo el mensaje que alguien transcribe desde el móvil,
      // cuál de los dos rompió.
      throw FuncionError(e.codigo, e.clave, 'reload: ${e.mensaje}');
    }
  }
  final verificado = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
  // reload() refresca el registro de usuario, NO el ID token: el que está en
  // memoria seguiría diciendo email_verified:false y el servidor rechazaría la
  // llamada siguiente con `correo_sin_verificar`, justo después de que esta
  // persona acabe de verificar. Por eso se fuerza el refresco aquí.
  if (verificado) await FirebaseAuth.instance.currentUser?.getIdToken(true);
  return verificado;
}

/// El perfil y los grupos. Devuelve null si la cuenta de Auth existe pero
/// su documento de perfil no — pasa si `guardarPerfil` falló por red justo
/// después de registrarse.
Future<ResultadoAcceso?> cargarMisGrupos() async {
  final r = await llamarFuncion('misGrupos', {});
  if (r['perfilCompleto'] != true) return null;
  return ResultadoAcceso(
    r['nombre'] as String? ?? '',
    r['apellido'] as String? ?? '',
    List<Map<String, dynamic>>.from(
        (r['grupos'] as List).map((g) => Map<String, dynamic>.from(g as Map))),
  );
}

/// Completa el perfil de una cuenta que se quedó a medias.
Future<void> completarPerfil({
  required String nombre,
  required String apellido,
  required String pin,
}) =>
    llamarFuncion('guardarPerfil', {
      'nombre': nombre.trim(),
      'apellido': apellido.trim(),
      'pin': pin.trim(),
    });


/// Cierra la sesión y suelta antes los avisos de este dispositivo.
///
/// El orden no es opcional: `borrarTokenPush` necesita la sesión que
/// estamos a punto de cerrar. Sin este paso el token seguía colgando de la
/// cuenta anterior, así que quien usara el teléfono después recibía SUS
/// avisos, y tocar uno abría la pantalla de alta de ese grupo — el código
/// del grupo es la única llave que hay, y se la estábamos entregando a
/// otra persona. Aparte, la cuenta nueva nunca llegaba a registrar el
/// suyo.
///
/// `soltarTokenDeEsteDispositivo` nunca lanza Y LLEVA SU PROPIO TOPE que
/// envuelve todas sus llamadas de red (ver `push.dart`), así que este
/// `await` no puede colgar el cierre de sesión: pasados unos segundos se
/// sigue adelante y la sesión se cierra igual, con token soltado o sin él.
/// Hace falta el tope porque este botón no tiene ni indicador ni estado
/// deshabilitado, y porque sin red —o con el service worker de web
/// atascado— `getToken()` puede no volver nunca. No poder soltar el token
/// no puede impedirle a nadie salir de su cuenta.
Future<void> salir() async {
  await soltarTokenDeEsteDispositivo();
  await FirebaseAuth.instance.signOut();
}

/// Vuelve a demostrar la contraseña. Actualiza el claim `auth_time` del
/// token, que es lo ÚNICO que el servidor mira para saber si la sesión es
/// reciente — ver `exigirReciente` en functions/index.js.
Future<void> reautenticar(String password) async {
  final u = FirebaseAuth.instance.currentUser;
  if (u == null || u.email == null) {
    throw FuncionError('auth', 'sesion_invalida', 'No hay sesión.');
  }
  await _traduciendo(() => u.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: u.email!, password: password)));
  // El token en memoria todavía lleva el auth_time viejo. Sin forzar el
  // refresco, la llamada siguiente iría con el token de antes y el
  // servidor la rechazaría — con la contraseña ya tecleada correctamente.
  await u.getIdToken(true);
}
