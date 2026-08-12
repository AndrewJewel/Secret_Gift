import 'package:shared_preferences/shared_preferences.dart';

/// Recuerda el último grupo visitado (creado o unido) en este dispositivo,
/// para que un "atrás" del navegador o cerrar la pestaña no deje a la
/// persona varada sin el código.
class GrupoGuardado {
  final String codigo;
  final String ocasionId;
  final String valorMinimo;
  final String nombreGrupo;
  GrupoGuardado({
    required this.codigo,
    required this.ocasionId,
    required this.valorMinimo,
    required this.nombreGrupo,
  });
}

const _claveCodigo = 'ultimo_grupo_codigo';
const _claveOcasion = 'ultimo_grupo_ocasion';
const _claveValorMinimo = 'ultimo_grupo_valor_minimo';
const _claveNombreGrupo = 'ultimo_grupo_nombre';

Future<void> guardarUltimoGrupo(
    String codigo, String ocasionId, String valorMinimo, String nombreGrupo) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_claveCodigo, codigo);
  await prefs.setString(_claveOcasion, ocasionId);
  await prefs.setString(_claveValorMinimo, valorMinimo);
  await prefs.setString(_claveNombreGrupo, nombreGrupo);
}

Future<GrupoGuardado?> leerUltimoGrupo() async {
  final prefs = await SharedPreferences.getInstance();
  final codigo = prefs.getString(_claveCodigo);
  if (codigo == null) return null;
  return GrupoGuardado(
    codigo: codigo,
    ocasionId: prefs.getString(_claveOcasion) ?? '',
    valorMinimo: prefs.getString(_claveValorMinimo) ?? '',
    nombreGrupo: prefs.getString(_claveNombreGrupo) ?? '',
  );
}

const _clavePreguntadoAvisos = 'preguntado_avisos';

/// Si ya se le ofrecieron los avisos a quien usa este dispositivo.
///
/// Se guarda AQUÍ y no en el servidor a propósito: el permiso es del
/// navegador, no de la cuenta. La misma persona en el móvil y en el
/// portátil tiene que poder decidir en cada sitio.
Future<bool> yaSePreguntoPorAvisos() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_clavePreguntadoAvisos) ?? false;
}

Future<void> marcarPreguntadoPorAvisos() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_clavePreguntadoAvisos, true);
}
