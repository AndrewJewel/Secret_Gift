import 'dart:convert';
import 'package:http/http.dart' as http;

import 'l10n/app_localizations.dart';

// No usamos el paquete cloud_functions: su implementación web tiene un bug
// conocido y sin arreglar en producción (dart2js) —
// https://github.com/firebase/flutterfire/issues/17924 — que hace que
// CUALQUIER llamada a una Cloud Function truene con
// "Int64 accessor not supported by dart2js". Llamamos las funciones
// directo por HTTP, el mismo protocolo que usa el SDK por dentro.
const _baseUrl = 'https://us-central1-santa-secreto-860c3.cloudfunctions.net';

class FuncionError implements Exception {
  final String codigo; // ej. 'permission-denied', imita FirebaseFunctionsException.code

  /// Clave estable del error, puesta por la Cloud Function en `details`.
  /// Existe porque el código por sí solo no alcanza para traducir: un
  /// mismo 'invalid-argument' sale en ocho sitios distintos con
  /// significados distintos. La clave sí identifica el caso exacto.
  final String clave;

  /// Texto que mandó el servidor. Solo se usa como último recurso, si
  /// llega una clave que el cliente todavía no conoce.
  final String mensaje;

  FuncionError(this.codigo, this.clave, this.mensaje);
}

extension MensajeLocalizado on FuncionError {
  /// Traduce el error al idioma de la interfaz. Si llega una clave que
  /// esta versión del cliente todavía no conoce (servidor más nuevo que
  /// la app), cae al texto que mandó el servidor: peor idioma, pero
  /// nunca una pantalla en blanco ni un mensaje vacío.
  String texto(Textos t) => switch (clave) {
        'sin_conexion' => t.errorSinConexion,
        'pin_incorrecto' => t.errorPinIncorrecto,
        'grupo_no_existe' => t.errorGrupoNoExiste,
        'participante_no_existe' => t.errorParticipanteNoExiste,
        'faltan_datos' => t.errorFaltanDatos,
        'faltan_datos_grupo' => t.errorFaltanDatosGrupo,
        'faltan_datos_participante' => t.errorFaltanDatosParticipante,
        'nickname_largo' => t.errorNicknameLargo,
        'nickname_en_uso' => t.errorNicknameEnUso,
        'nickname_no_existe' => t.errorNicknameNoExiste,
        'password_incorrecta' => t.errorPasswordIncorrecta,
        'password_debil' => t.errorPasswordDebil,
        'minimo_dos_personas' => t.errorMinimoDosPersonas,
        'nada_que_cambiar' => t.errorNadaQueCambiar,
        'nombre_vacio' => t.errorNombreVacio,
        'reglas_muy_largas' => t.errorReglasMuyLargas,
        'imagen_invalida' => t.errorImagenInvalida,
        'imagen_muy_grande' => t.errorImagenMuyGrande,
        'codigo_no_generado' => t.errorCodigoNoGenerado,
        'mensaje_vacio' => t.errorMensajeVacio,
        'mensaje_largo' => t.errorMensajeLargo,
        'muy_rapido' => t.errorMuyRapido,
        'sesion_invalida' => t.errorSesionInvalida,
        'pin_formato' => t.errorPinFormato,
        'no_eres_organizador' => t.errorNoEresOrganizador,
        'no_estas_en_el_grupo' => t.errorNoEstasEnElGrupo,
        'ya_estas_en_el_grupo' => t.errorYaEstasEnElGrupo,
        'grupo_ya_sorteado' => t.errorGrupoYaSorteado,
        'grupo_cerrado' => t.errorGrupoCerrado,
        'sorteo_ya_hecho' => t.errorSorteoYaHecho,
        'pin_bloqueado' => t.errorPinBloqueado,
        _ => mensaje,
      };
}

Future<Map<String, dynamic>> llamarFuncion(String nombre, Map<String, dynamic> datos) async {
  final http.Response resp;
  try {
    resp = await http.post(
      Uri.parse('$_baseUrl/$nombre'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'data': datos}),
    );
  } catch (e) {
    throw FuncionError('unavailable', 'sin_conexion', 'No se pudo conectar: $e');
  }

  final Map<String, dynamic> body;
  try {
    body = jsonDecode(resp.body) as Map<String, dynamic>;
  } catch (_) {
    throw FuncionError(
        'unknown', 'respuesta_invalida', 'Respuesta inválida del servidor (${resp.statusCode})');
  }

  if (body['error'] != null) {
    final err = body['error'] as Map<String, dynamic>;
    final status = (err['status'] as String? ?? 'UNKNOWN').toLowerCase().replaceAll('_', '-');
    final detalles = err['details'];
    final clave = detalles is Map ? (detalles['clave'] as String? ?? '') : '';
    throw FuncionError(status, clave, err['message'] as String? ?? 'Error desconocido');
  }

  return Map<String, dynamic>.from(body['result'] as Map? ?? {});
}
