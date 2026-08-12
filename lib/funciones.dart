import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'auth.dart';
import 'l10n/app_localizations.dart';

// No usamos el paquete cloud_functions: su implementación web tiene un bug
// conocido y sin arreglar en producción (dart2js) —
// https://github.com/firebase/flutterfire/issues/17924 — que hace que
// CUALQUIER llamada a una Cloud Function truene con
// "Int64 accessor not supported by dart2js". Llamamos las funciones
// directo por HTTP, el mismo protocolo que usa el SDK por dentro.
const _baseUrl = 'https://us-central1-secretgift-app.cloudfunctions.net';

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
        'correo_sin_verificar' => t.errorCorreoSinVerificar,
        'requiere_reautenticacion' => t.errorRequiereReautenticacion,
        'perfil_incompleto' => t.errorPerfilIncompleto,
        'correo_invalido' => t.errorCorreoInvalido,
        'correo_en_uso' => t.errorCorreoEnUso,
        'demasiados_intentos' => t.errorDemasiadosIntentos,
        'cuenta_deshabilitada' => t.errorCuentaDeshabilitada,
        'dominio_no_autorizado' => t.errorDominioNoAutorizado,
        // Comodín de los códigos de Auth que esta versión de la app
        // todavía no traduce. `codigo` es el campo con el `e.code` real de
        // Firebase (ver `comoFuncionError` en auth.dart) — sin él, un
        // código nuevo que Firebase invente mañana daría un mensaje que
        // nadie puede diagnosticar. Es el único caso de este switch que
        // enseña detalle técnico: todos los demás tienen una clave propia
        // y un texto ya pensado para esa clave, pero este es justo el que
        // dispara cuando NINGUNA clave conocida encaja. Sin el código y el
        // `e.message` que mandó Firebase, un fallo que le pasa a alguien
        // que no eres tú (otro dispositivo, otra cuenta, otro momento) es
        // indiagnosticable: no hay logs que consultar en caliente, solo lo
        // que esa persona puede leer y transcribir en pantalla.
        'auth_desconocido' => t.errorAuthDesconocido(codigo, mensaje),
        'nombre_largo' => t.errorNombreLargo,
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
        'reemplazo_invalido' => t.errorReemplazoInvalido,
        'grupo_sin_sortear' => t.errorGrupoSinSortear,
        'token_invalido' => t.errorTokenInvalido,
        _ => mensaje,
      };
}

Future<Map<String, dynamic>> llamarFuncion(String nombre, Map<String, dynamic> datos) async {
  // El protocolo callable saca la identidad de esta cabecera. Como no
  // usamos el paquete `cloud_functions` (ver la nota de arriba), nadie la
  // pone por nosotros: hay que adjuntarla a mano. Si falta, las quince
  // funciones ven `request.auth` vacío y la app entera deja de autorizar.
  final headers = <String, String>{'Content-Type': 'application/json'};

  // El token se pide aquí dentro, no antes de este try, porque
  // getIdToken() también puede fallar (token caducado, red caída al
  // refrescarlo) y ese fallo necesita el mismo tratamiento que el del
  // http.post de abajo: convertirse en un FuncionError con su propia
  // clave, no salir crudo y perder la traducción fina que esta tarea
  // construyó.
  String? token;
  try {
    token = await tokenActual();
  } on FuncionError {
    // tokenActual() ya lo convirtió (y, si tocaba, le puso la marca
    // "token: " delante del mensaje — ver el comentario de tokenActual()
    // en auth.dart). Aquí solo hace falta dejarlo pasar tal cual: si
    // cayera en el catch de abajo perdería el código y la clave
    // originales.
    rethrow;
  } on FirebaseAuthException catch (e) {
    throw comoFuncionError(e);
  } catch (e) {
    throw FuncionError('unavailable', 'sin_conexion', 'No se pudo conectar: $e');
  }
  if (token != null) headers['Authorization'] = 'Bearer $token';

  final http.Response resp;
  try {
    resp = await http.post(
      Uri.parse('$_baseUrl/$nombre'),
      headers: headers,
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
