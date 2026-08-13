import 'dart:async';

import 'package:flutter/material.dart';

import 'almacen_local.dart';
import 'pantalla_permiso_avisos.dart';
import 'push.dart';

/// Ofrece la pantalla de permiso de avisos si en este dispositivo todavía
/// no se le preguntó a nadie, y RECONCILIA el token si ya se preguntó. La
/// llaman los tres sitios que terminan
/// `_trasVerificar` (`pantalla_raiz.dart`, `pantalla_crear_cuenta.dart`,
/// `pantalla_iniciar_sesion.dart`): es el primer momento en que la
/// persona entra de verdad, justo tras verificar el correo. Antes de
/// verificar no puede hacer nada, y preguntárselo mientras espera el
/// correo sería interrumpirla en mitad de otra cosa.
///
/// La reconciliación va AQUÍ, y no en `main()` ni en `PantallaRaiz`, por
/// tres razones:
///
/// 1. Este es el único punto por el que pasan los DOS caminos de entrada.
///    `_trasVerificar` cubre a quien acaba de verificar el correo (por las
///    tres pantallas de cuenta) y `_entrarConLaSesionDeAuth` cubre a quien
///    ya tenía la sesión iniciada. En `main()` no habría sesión todavía —
///    `guardarTokenPush` exige identidad— y en `PantallaRaiz.initState`
///    tampoco: se ejecuta antes de saber si la sesión guardada aún vale.
/// 2. Aquí la cuenta es ya la definitiva. Cerrar sesión suelta el token
///    (ver `soltarTokenDeEsteDispositivo`), así que la reconciliación es
///    justo lo que hace que la cuenta que ENTRA registre el suyo.
/// 3. Es el complemento exacto de la otra rama: o se pregunta, o se
///    reconcilia. Nunca las dos, y nunca ninguna.
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
  if (await yaSePreguntoPorAvisos()) {
    // Sin `await` a propósito: esto está en mitad del camino de entrada,
    // justo antes de `irADondeToque`, y no hay nada aquí que dependa del
    // resultado. Esperarlo metería un viaje al servidor entre "he entrado"
    // y ver la pantalla. `reconciliarAvisos` nunca lanza, así que soltarla
    // no deja ningún error suelto.
    unawaited(reconciliarAvisos());
    return;
  }
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
