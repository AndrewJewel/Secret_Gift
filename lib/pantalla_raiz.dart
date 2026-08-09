import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'acceso_cuenta.dart';
import 'destino_inicial.dart';
import 'glass.dart';
import 'invitacion_pendiente.dart';
import 'ocasion.dart';
import 'pantalla_crear_cuenta.dart';
import 'pantalla_mis_grupos.dart';
import 'pantalla_registro.dart';
import 'sesion.dart';
import 'tematica.dart';

/// Primera pantalla real de la app: decide a dónde va cada quien.
///
/// Solo muestra un indicador mientras lee disco y, si hace falta, valida
/// el código de la URL. Nunca se queda como pantalla visible.
class PantallaRaiz extends StatefulWidget {
  const PantallaRaiz({super.key});

  @override
  State<PantallaRaiz> createState() => _PantallaRaizState();
}

class _PantallaRaizState extends State<PantallaRaiz> {
  @override
  void initState() {
    super.initState();
    _arrancar();
  }

  /// Si la URL trae ?codigo=XXXX se guarda como invitación ANTES de
  /// decidir destino. Se valida contra Firestore para no guardar códigos
  /// inventados, y de paso se obtiene el nombre del grupo, que la
  /// pantalla de registro muestra.
  Future<void> _capturarInvitacionDeLaUrl() async {
    if (!kIsWeb) return;
    final codigo = Uri.base.queryParameters['codigo']?.trim().toUpperCase();
    if (codigo == null || codigo.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('grupos')
          .doc(codigo)
          .get()
          .timeout(const Duration(seconds: 6));
      if (!doc.exists) return;
      await guardarInvitacion(codigo, doc.data()!['nombreGrupo'] as String? ?? '');
    } catch (_) {
      // Sin conexión o código inválido: se sigue el flujo normal. La
      // próxima apertura con el mismo enlace volverá a intentarlo.
    }
  }

  Future<void> _arrancar() async {
    await _capturarInvitacionDeLaUrl();
    final sesion = await leerSesion();
    final invitacion = await leerInvitacion();
    if (!mounted) return;

    switch (decidirDestino(
        haySesion: sesion != null, hayInvitacion: invitacion != null)) {
      case DestinoInicial.crearCuenta:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PantallaCrearCuenta(
                alEntrar: irADondeToque,
                nombreGrupoInvitacion: invitacion?.nombreGrupo),
          ),
        );
      case DestinoInicial.grupo:
        await _entrarAlGrupo(context, invitacion!);
      case DestinoInicial.misGrupos:
        // La sesión guardada puede haber dejado de valer: contraseña
        // cambiada desde otro dispositivo, cuenta borrada, o sin
        // conexión. Sin este catch la app se queda en el indicador de
        // carga para siempre, que es la peor pantalla posible.
        try {
          final r = await entrarConCuenta(
              nickname: sesion!.nickname, password: sesion.password, registrando: false);
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    PantallaMisGrupos(nickname: r.nickname, grupos: r.grupos)),
          );
        } catch (_) {
          await cerrarSesion();
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => PantallaCrearCuenta(alEntrar: irADondeToque)),
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
        data: temaGlass(colorNeutro),
        child: FondoNeutro(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(child: CircularProgressIndicator(color: colorNeutro.shade700)),
          ),
        ),
      );
}

/// Entra al grupo de una invitación y la borra. Borrarla importa: si no,
/// cada apertura de la app volvería a meter a esa persona en ese grupo
/// para siempre.
Future<void> _entrarAlGrupo(BuildContext context, InvitacionPendiente i) async {
  final doc =
      await FirebaseFirestore.instance.collection('grupos').doc(i.codigo).get();
  await borrarInvitacion();
  if (!context.mounted || !doc.exists) return;
  final data = doc.data()!;
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => PantallaRegistro(
        codigo: i.codigo,
        ocasion: Ocasion.desdeId(data['ocasion'] as String),
        valorMinimo: data['valorMinimo'] as String? ?? '',
        nombreGrupo: data['nombreGrupo'] as String? ?? '',
      ),
    ),
  );
}

/// A dónde se va tras crear cuenta o iniciar sesión. Lo usan las dos
/// pantallas de cuenta para no duplicar la decisión.
Future<void> irADondeToque(BuildContext context, ResultadoAcceso resultado) async {
  final invitacion = await leerInvitacion();
  if (!context.mounted) return;
  if (invitacion != null) {
    await _entrarAlGrupo(context, invitacion);
    return;
  }
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(
      builder: (_) =>
          PantallaMisGrupos(nickname: resultado.nickname, grupos: resultado.grupos),
    ),
    (r) => false,
  );
}
