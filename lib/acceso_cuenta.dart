import 'funciones.dart';
import 'sesion.dart';

/// Lo que devuelve el servidor al entrar: el nickname tal como se escribió
/// y los grupos vinculados a esa cuenta.
class ResultadoAcceso {
  final String nickname;
  final List<Map<String, dynamic>> grupos;
  const ResultadoAcceso(this.nickname, this.grupos);
}

/// Registro e inicio de sesión comparten casi todo: registrar es lo mismo
/// más una llamada previa. Vive fuera de las pantallas para que las dos
/// hagan exactamente lo mismo y no se desincronicen.
///
/// Lanza FuncionError, que la pantalla traduce con `e.texto(t)`.
Future<ResultadoAcceso> entrarConCuenta({
  required String nickname,
  required String password,
  required bool registrando,
  String? pin,
}) async {
  if (registrando) {
    await llamarFuncion('registrarCuenta',
        {'nickname': nickname, 'password': password, 'pin': pin ?? ''});
  }
  final r = await llamarFuncion(
      'iniciarSesionCuenta', {'nickname': nickname, 'password': password});
  await guardarSesion(nickname, password);
  return ResultadoAcceso(
    r['nickname'] as String,
    List<Map<String, dynamic>>.from(
        (r['grupos'] as List).map((g) => Map<String, dynamic>.from(g as Map))),
  );
}
