import 'package:flutter/material.dart';

import 'almacen_local.dart';
import 'pantalla_permiso_avisos.dart';
import 'push.dart';

/// Ofrece la pantalla de permiso de avisos si en este dispositivo todavía
/// no se le preguntó a nadie. La llaman los tres sitios que terminan
/// `_trasVerificar` (`pantalla_raiz.dart`, `pantalla_crear_cuenta.dart`,
/// `pantalla_iniciar_sesion.dart`): es el primer momento en que la
/// persona entra de verdad, justo tras verificar el correo. Antes de
/// verificar no puede hacer nada, y preguntárselo mientras espera el
/// correo sería interrumpirla en mitad de otra cosa.
///
/// `yaSePreguntoPorAvisos` es por DISPOSITIVO, no por cuenta: el permiso
/// es del navegador, así que la misma persona tiene que poder decidirlo
/// en el móvil y en el portátil por separado.
///
/// La marca de "ya se preguntó" se pone ANTES de enseñar la pantalla y no
/// después: si se marcara después, cerrar la pestaña a medias —sin llegar
/// a tocar «Sí» ni «Ahora no»— haría que se volviera a preguntar en cada
/// arranque.
///
/// Sacada a su propio fichero (en vez de repetida en los tres sitios) para
/// que la garantía del orden se pueda probar con un `WidgetTester` sin
/// pasar por ninguna de las tres pantallas de cuenta ni por Firebase.
Future<void> ofrecerAvisosSiHaceFalta(BuildContext context) async {
  if (await yaSePreguntoPorAvisos()) return;
  await marcarPreguntadoPorAvisos();
  if (!context.mounted) return;
  await Navigator.push(context, MaterialPageRoute(
    builder: (_) => PantallaPermisoAvisos(
      alAceptar: () async {
        await pedirPermisoYRegistrar();
        if (context.mounted) Navigator.pop(context);
      },
      alSaltar: () => Navigator.pop(context),
    ),
  ));
}
