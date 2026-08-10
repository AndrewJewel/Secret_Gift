import 'package:firebase_auth/firebase_auth.dart';

import 'funciones.dart';

/// Traduce el código de un [FirebaseAuthException] a una de nuestras claves
/// de error, las mismas que ya usa `MensajeLocalizado.texto()`.
///
/// `user-not-found` y `wrong-password` dan A PROPÓSITO la misma clave: si
/// dijéramos "ese correo no existe", habríamos recreado el oráculo de
/// existencia que esta migración vino a cerrar. Firebase ya empuja en esa
/// dirección devolviendo `invalid-credential` para los dos casos cuando la
/// protección de enumeración de correos está activada; esto lo garantiza
/// también si estuviera apagada.
String claveDeAuth(String code) => switch (code) {
      'invalid-email' => 'correo_invalido',
      'email-already-in-use' => 'correo_en_uso',
      // 'password-does-not-meet-requirements' aparece cuando el proyecto
      // tiene activada en la consola de Firebase una política de
      // contraseñas (mínimo de caracteres, mayúscula, minúscula, número,
      // símbolo). Sin este mapeo caería en 'auth_desconocido' y el mensaje
      // genérico, en vez de decir qué falta en la contraseña.
      'weak-password' || 'password-does-not-meet-requirements' => 'password_debil',
      'invalid-credential' || 'wrong-password' || 'user-not-found' => 'password_incorrecta',
      'user-disabled' => 'cuenta_deshabilitada',
      'too-many-requests' => 'demasiados_intentos',
      'network-request-failed' => 'sin_conexion',
      'requires-recent-login' => 'requiere_reautenticacion',
      // 'unauthorized-domain' salta cuando el dominio desde el que se abre
      // la app no está en la lista de dominios autorizados de la consola de
      // Firebase Auth. Es un error de CONFIGURACIÓN del proyecto, no algo
      // que esta persona haya hecho mal: reintentar no cambia nada, así que
      // merece su propio mensaje en vez de caer al comodín de "vuelve a
      // intentarlo".
      'unauthorized-domain' => 'dominio_no_autorizado',
      _ => 'auth_desconocido',
    };

/// Envuelve la excepción de Auth en el tipo que la interfaz ya sabe
/// traducir. Es el borde: a partir de aquí, en la app solo hay
/// [FuncionError].
///
/// `e.code` viaja en el campo `codigo` de [FuncionError] (no solo para
/// traducir la clave): es lo que necesita `errorAuthDesconocido` para
/// mostrar QUÉ código llegó cuando `claveDeAuth` todavía no lo conoce.
FuncionError comoFuncionError(FirebaseAuthException e) =>
    FuncionError(e.code, claveDeAuth(e.code), e.message ?? e.code);

FirebaseAuth get _auth => FirebaseAuth.instance;

User? get usuarioActual => _auth.currentUser;

Stream<User?> get cambiosDeUsuario => _auth.userChanges();

/// El *ID token* del usuario actual. Lo necesita [llamarFuncion] para la
/// cabecera `Authorization: Bearer`. Devuelve null si no hay sesión.
///
/// No se cachea: el SDK ya lo hace y lo refresca solo cuando caduca.
Future<String?> tokenActual() async {
  final u = _auth.currentUser;
  if (u == null) return null;
  return u.getIdToken();
}
