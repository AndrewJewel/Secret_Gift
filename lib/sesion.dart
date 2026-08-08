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

Future<void> guardarSesion(String nickname, String password) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_claveNickname, nickname);
  await prefs.setString(_clavePassword, password);
}

Future<Sesion?> leerSesion() async {
  final prefs = await SharedPreferences.getInstance();
  final nickname = prefs.getString(_claveNickname);
  final password = prefs.getString(_clavePassword);
  if (nickname == null || password == null) return null;
  return Sesion(nickname, password);
}

Future<void> cerrarSesion() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_claveNickname);
  await prefs.remove(_clavePassword);
}
