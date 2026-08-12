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
///
/// Protegida con `try/catch`, al revés que si fuera un detalle sin
/// importancia: esta función se llama en pleno camino de entrada (justo
/// antes de `irADondeToque`/`alEntrar`, ver `oferta_avisos.dart`), y este
/// proyecto YA sufrió un almacén roto esta semana (ver el comentario largo
/// de `pantalla_verificar_correo.dart`).
///
/// Ante la duda se responde `false` —"todavía no se preguntó"— y NO
/// `true`. Son dos garantías distintas y no hay que mezclarlas: no
/// bloquear la entrada ya lo da el propio `try/catch`, con cualquiera de
/// los dos valores. Responder `true` apagaría los avisos EN SILENCIO para
/// siempre en ese dispositivo —la pantalla de permiso no volvería a
/// enseñarse jamás—, mientras que `false` como mucho pregunta de más, y
/// deja abierta una oportunidad real de que funcione: pedir el permiso y
/// guardar el token (`pedirPermisoYRegistrar`, en `push.dart`) no
/// dependen de `SharedPreferences`.
Future<bool> yaSePreguntoPorAvisos() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_clavePreguntadoAvisos) ?? false;
  } catch (_) {
    return false;
  }
}

Future<void> marcarPreguntadoPorAvisos() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_clavePreguntadoAvisos, true);
  } catch (_) {
    // Sin almacenamiento no se puede recordar la marca, pero eso no es
    // motivo para tumbar el camino de entrada.
  }
}
