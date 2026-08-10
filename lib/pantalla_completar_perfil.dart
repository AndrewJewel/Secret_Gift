import 'package:flutter/material.dart';

import 'acceso_cuenta.dart';
import 'funciones.dart';
import 'l10n/app_localizations.dart';

/// Red de seguridad: hay cuenta de Auth pero no documento de perfil.
/// Pasa si `guardarPerfil` falló por red justo después de registrarse.
/// Sin esta pantalla, esa persona se quedaría con una app medio rota y sin
/// forma de arreglarla.
class PantallaCompletarPerfil extends StatefulWidget {
  final Future<void> Function(BuildContext) alCompletar;
  const PantallaCompletarPerfil({super.key, required this.alCompletar});

  @override
  State<PantallaCompletarPerfil> createState() => _PantallaCompletarPerfilState();
}

class _PantallaCompletarPerfilState extends State<PantallaCompletarPerfil> {
  final _nombre = TextEditingController();
  final _apellido = TextEditingController();
  final _pin = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() {
    _nombre.dispose();
    _apellido.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final t = Textos.of(context);
    if (_nombre.text.trim().isEmpty ||
        _apellido.text.trim().isEmpty ||
        _pin.text.trim().length != 4) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('⚠️ ${t.cuentaFaltanDatos}')));
      return;
    }
    setState(() => _guardando = true);
    try {
      await completarPerfil(
          nombre: _nombre.text, apellido: _apellido.text, pin: _pin.text);
      if (!mounted) return;
      await widget.alCompletar(context);
      if (mounted) setState(() => _guardando = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '⚠️ ${e is FuncionError ? e.texto(t) : t.errorInesperado(e.toString())}')));
      setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t.completarPerfilTitulo,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(t.completarPerfilTexto, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                TextField(
                    controller: _nombre,
                    decoration: InputDecoration(labelText: t.cuentaNombre)),
                const SizedBox(height: 12),
                TextField(
                    controller: _apellido,
                    decoration: InputDecoration(labelText: t.cuentaApellido)),
                const SizedBox(height: 12),
                TextField(
                  controller: _pin,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  decoration: InputDecoration(labelText: t.cuentaPin),
                ),
                const SizedBox(height: 16),
                FilledButton(
                    onPressed: _guardando ? null : _guardar,
                    child: Text(t.guardar)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
