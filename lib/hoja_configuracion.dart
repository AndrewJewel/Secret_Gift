import 'package:flutter/material.dart';

import 'acceso_cuenta.dart';
import 'funciones.dart';
import 'glass.dart';
import 'l10n/app_localizations.dart';
import 'ocasion.dart';
import 'push.dart';
import 'selector_idioma.dart';

/// Ajustes de la cuenta, desde "Mis grupos".
///
/// Reúne idioma, PIN y cerrar sesión en un sitio. Antes el idioma era un
/// icono suelto en la barra y cerrar sesión otro: dos iconos de ajustes
/// sin un sitio donde vivir.
class HojaConfiguracion extends StatefulWidget {
  /// Qué hacer al cerrar sesión. La hoja no navega: "Mis grupos" es quien
  /// sabe a dónde se va y cómo se vacía la pila.
  ///
  /// El tipo es `Future<void> Function()` y no `VoidCallback` porque quien
  /// la implementa tiene que esperar a `salir()` antes de navegar.
  final Future<void> Function() alCerrarSesion;

  const HojaConfiguracion({super.key, required this.alCerrarSesion});

  static Future<void> mostrar(BuildContext context,
      {required Future<void> Function() alCerrarSesion}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HojaConfiguracion(alCerrarSesion: alCerrarSesion),
    );
  }

  @override
  State<HojaConfiguracion> createState() => _HojaConfiguracionState();
}

class _HojaConfiguracionState extends State<HojaConfiguracion> {
  bool _cambiandoPin = false;

  /// Si hay avisos activos para ESTA cuenta en ESTE dispositivo. Lo decide
  /// `avisosActivos` (en `push.dart`) cruzando dos cosas: el permiso que
  /// dice el sistema y si el token está guardado en el servidor. Con una
  /// sola no basta — el permiso concedido no significa que ESTA cuenta
  /// tenga token, y una preferencia local a solas diría "activado" con el
  /// navegador bloqueándolo por su cuenta.
  bool _avisosActivos = false;
  bool _cambiandoAvisos = false;

  @override
  void initState() {
    super.initState();
    _leerEstadoAvisos();
  }

  /// Solo LEE. Antes llamaba a `tokenDeEsteDispositivo()`, que acaba en
  /// `getToken()`, y `getToken()` pide el permiso él mismo: abrir
  /// Configuración para cambiar el idioma le sacaba el cuadro del
  /// navegador a quien nunca lo pidió, y denegarlo ahí quemaba el permiso
  /// para siempre. `avisosActivosAhora()` no pide nada.
  Future<void> _leerEstadoAvisos() async {
    final activos = await avisosActivosAhora();
    if (mounted) setState(() => _avisosActivos = activos);
  }

  /// Al encender: pide permiso y registra. Si el sistema lo tiene
  /// bloqueado —lo denegó antes, en el navegador o en Android—, no hay
  /// forma de que la app lo revierta desde aquí: `pedirPermisoYRegistrar`
  /// devuelve `false` y el interruptor tiene que volver a su sitio, no
  /// quedarse encendido mintiendo.
  ///
  /// Al apagar: borra el token en el servidor de verdad (`apagarAvisos`),
  /// no solo una preferencia local, o los avisos seguirían llegando.
  Future<void> _cambiarAvisos(bool encender) async {
    final t = Textos.of(context);
    setState(() => _cambiandoAvisos = true);
    if (encender) {
      final registrado = await pedirPermisoYRegistrar();
      if (!mounted) return;
      setState(() {
        _avisosActivos = registrado;
        _cambiandoAvisos = false;
      });
      if (!registrado) _avisar(t.avisosBloqueados);
    } else {
      await apagarAvisos();
      if (!mounted) return;
      setState(() {
        _avisosActivos = false;
        _cambiandoAvisos = false;
      });
    }
  }

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  /// Cambiar el PIN pide la contraseña de la cuenta. Es la única salida si
  /// se olvida: sin ella, cuatro dígitos perdidos dejarían a esa persona
  /// sin ver su amigo secreto para siempre.
  Future<void> _cambiarPin() async {
    final t = Textos.of(context);
    final password = TextEditingController();
    final pinNuevo = TextEditingController();

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t.cambiarPinTitulo),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.cambiarPinTexto, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: password,
              obscureText: true,
              decoration: InputDecoration(labelText: t.cambiarPinPassword),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pinNuevo,
              obscureText: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(labelText: t.cambiarPinNuevo),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t.cancelar)),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(t.cambiarPinGuardar)),
        ],
      ),
    );
    if (confirmado == true && mounted) {
      setState(() => _cambiandoPin = true);
      try {
        await reautenticar(password.text);
        await llamarFuncion('cambiarPin', {'pinNuevo': pinNuevo.text.trim()});
        _avisar('✅ ${t.cambiarPinGuardado}');
      } catch (e) {
        if (mounted) {
          _avisar(
              '⚠️ ${e is FuncionError ? e.texto(t) : t.errorInesperado(e.toString())}');
        }
      } finally {
        if (mounted) setState(() => _cambiandoPin = false);
      }
    }
    password.dispose();
    pinNuevo.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colorNeutro.shade50,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.configuracion,
                textAlign: TextAlign.center, style: tituloGlass(colorNeutro)),
            const SizedBox(height: 20),
            const CampoIdioma(),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                _avisosActivos
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
                color: colorNeutro.shade700,
              ),
              title: Text(t.avisosInterruptor),
              value: _avisosActivos,
              onChanged: _cambiandoAvisos ? null : _cambiarAvisos,
            ),
            const SizedBox(height: 16),
            GlassOutlineButton(
              color: colorNeutro,
              icon: Icons.pin_outlined,
              label: t.configuracionCambiarPin,
              onPressed: _cambiandoPin ? null : _cambiarPin,
            ),
            const SizedBox(height: 16),
            GlassOutlineButton(
              color: colorNeutro,
              icon: Icons.logout,
              label: t.misGruposCerrarSesion,
              onPressed: widget.alCerrarSesion,
            ),
          ],
        ),
      ),
    );
  }
}
