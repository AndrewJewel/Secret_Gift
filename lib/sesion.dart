import 'package:shared_preferences/shared_preferences.dart';

/// Sesión de cuenta cacheada en este dispositivo (nickname + contraseña),
/// para no volver a pedirla en cada acción. Es solo conveniencia local:
/// el servidor siempre re-verifica la contraseña, nunca confía en esto.
class Sesion {
  final String nickname;
  final String password;
  Sesion(this.nickname, this.password);
}

const _claveNickname = 'sesion_nickname';
const _clavePassword = 'sesion_password';

// Las tres funciones envuelven SharedPreferences en try/catch por la misma
// razón que invitacion_pendiente.dart e identidad_local.dart: con el
// almacenamiento bloqueado (Safari en privado, webview sin cookies) el
// plugin LANZA. Quien llama a `leerSesion` es el portero, que corre en
// initState sin nadie que capture nada: sin esto la app se queda colgada
// en el indicador de carga para siempre. Perder la sesión es molesto;
// quedarse sin pantalla es fatal.

Future<void> guardarSesion(String nickname, String password) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveNickname, nickname);
    await prefs.setString(_clavePassword, password);
  } catch (_) {
    // Sin almacenamiento habrá que volver a iniciar sesión al recargar,
    // pero la app sigue viva.
  }
}

Future<Sesion?> leerSesion() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final nickname = prefs.getString(_claveNickname);
    final password = prefs.getString(_clavePassword);
    if (nickname == null || password == null) return null;
    return Sesion(nickname, password);
  } catch (_) {
    // Se trata como "no hay sesión": manda a crear cuenta / iniciar
    // sesión, que es un sitio del que se puede salir.
    return null;
  }
}

Future<void> cerrarSesion() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_claveNickname);
    await prefs.remove(_clavePassword);
  } catch (_) {
    // Nada que hacer: si no se pudo leer tampoco se pudo guardar.
  }
}
