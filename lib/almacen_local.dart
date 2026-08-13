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

const _claveAvisosQueridos = 'avisos_queridos';

/// Si en ESTE dispositivo se pidieron los avisos: la INTENCIÓN de la
/// persona, no el hecho de que estén funcionando.
///
/// Hacen falta las dos cosas por separado, y esta es la que decide si la
/// app puede registrar el token sola al arrancar (ver `reconciliarAvisos`
/// en `push.dart`). Sin esta marca no se puede reconciliar sin hacer daño:
///
/// - Apagar el interruptor borra el token, pero el permiso del sistema
///   sigue concedido. Una reconciliación que mirara SOLO el permiso lo
///   volvería a registrar en el arranque siguiente, y apagar los avisos no
///   se quedaría apagado nunca.
/// - En Android anterior al 13 no existe el permiso `POST_NOTIFICATIONS`:
///   las notificaciones vienen habilitadas de fábrica, así que el sistema
///   responde "concedido" incluso a quien acaba de pulsar «Ahora no» en
///   nuestra propia pantalla. Sin esta marca le registraríamos el token
///   justo después de que dijera que no.
///
/// Es del DISPOSITIVO y sobrevive a cerrar sesión, igual que
/// `yaSePreguntoPorAvisos` y por el mismo motivo: el permiso es del
/// navegador o del móvil, no de la cuenta. Que sobreviva es justo lo que
/// hace que la cuenta siguiente que entre en este teléfono registre su
/// propio token sin volver a preguntar nada.
Future<bool> avisosQueridosAqui() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_claveAvisosQueridos) ?? false;
  } catch (_) {
    // Ante la duda, no: registrar avisos que nadie pidió es peor que no
    // registrar los que sí.
    return false;
  }
}

Future<void> marcarAvisosQueridos(bool queridos) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_claveAvisosQueridos, queridos);
  } catch (_) {
    // Igual que la marca de arriba: sin almacenamiento no se recuerda,
    // pero no se tumba nada.
  }
}

const _claveTokenEnServidor = 'token_push_en_servidor';

/// Si la última operación que hicimos dejó el token de este dispositivo
/// guardado en la cuenta que hay ahora abierta: el HECHO, no la intención.
///
/// Lo escribe `guardarTokenPush` cuando responde bien y lo borran apagar
/// los avisos y cerrar sesión. Es el segundo dato que necesita
/// `avisosActivos` (en `push.dart`) para no mentir en el interruptor: el
/// permiso concedido solo dice que este dispositivo PUEDE tener token, no
/// que ESTA cuenta lo tenga.
Future<bool> hayTokenPushEnServidor() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_claveTokenEnServidor) ?? false;
  } catch (_) {
    return false;
  }
}

Future<void> marcarTokenPushEnServidor(bool hay) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_claveTokenEnServidor, hay);
  } catch (_) {
    // Sin almacenamiento el interruptor dirá "apagado" aunque los avisos
    // lleguen. Es el error seguro de los dos: encender otra vez es
    // inofensivo (vuelve a guardar el mismo token), y decir "encendido"
    // sin serlo es el fallo que esta ronda vino a arreglar.
  }
}
