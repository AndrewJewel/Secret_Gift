import 'package:firebase_auth/firebase_auth.dart';

import 'auth.dart';
import 'funciones.dart';
import 'idioma.dart';

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
Future<void> crearCuenta({
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
  await mandarVerificacion();
}

Future<void> entrar({required String correo, required String password}) =>
    _traduciendo(() => FirebaseAuth.instance
        .signInWithEmailAndPassword(email: correo.trim(), password: password));

/// Manda (o reenvía) el enlace de verificación.
///
/// `setLanguageCode` va ANTES de mandarlo: es lo único que decide el idioma
/// del correo, y sin esto le llega en inglés a todo el mundo.
Future<void> mandarVerificacion() async {
  final u = FirebaseAuth.instance.currentUser;
  if (u == null) return;
  await FirebaseAuth.instance.setLanguageCode(Idioma.actual.value.languageCode);
  await _traduciendo(() => u.sendEmailVerification());
}

/// Recarga al usuario desde el servidor y dice si ya verificó.
///
/// Hace falta recargar: `emailVerified` es una foto del token, y el token
/// se hizo antes de que esa persona pinchara el enlace.
Future<bool> correoVerificado() async {
  final u = FirebaseAuth.instance.currentUser;
  if (u == null) return false;
  await _traduciendo(() => u.reload());
  return FirebaseAuth.instance.currentUser?.emailVerified ?? false;
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

/// Manda el enlace para poner una contraseña nueva.
///
/// **Nunca dice si ese correo tiene cuenta.** `user-not-found` se traga a
/// propósito: distinguirlo sería un oráculo de existencia — cualquiera
/// podría averiguar quién está registrado probando direcciones. Quien
/// llama debe enseñar SIEMPRE el mismo mensaje.
Future<void> mandarRecuperacion(String correo) async {
  await FirebaseAuth.instance.setLanguageCode(Idioma.actual.value.languageCode);
  try {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: correo.trim());
  } on FirebaseAuthException catch (e) {
    if (e.code == 'user-not-found') return;
    throw comoFuncionError(e);
  }
}

Future<void> salir() => FirebaseAuth.instance.signOut();

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
