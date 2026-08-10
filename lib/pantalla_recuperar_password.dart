import 'package:flutter/material.dart';

import 'acceso_cuenta.dart';
import 'funciones.dart';
import 'l10n/app_localizations.dart';

class PantallaRecuperarPassword extends StatefulWidget {
  const PantallaRecuperarPassword({super.key});

  @override
  State<PantallaRecuperarPassword> createState() => _PantallaRecuperarPasswordState();
}

class _PantallaRecuperarPasswordState extends State<PantallaRecuperarPassword> {
  final _correo = TextEditingController();
  bool _mandando = false;
  bool _mandado = false;

  @override
  void dispose() {
    _correo.dispose();
    super.dispose();
  }

  Future<void> _mandar() async {
    final t = Textos.of(context);
    if (_correo.text.trim().isEmpty) return;
    setState(() => _mandando = true);
    try {
      await mandarRecuperacion(_correo.text);
      if (!mounted) return;
      // El mismo mensaje exista o no la cuenta: ver mandarRecuperacion.
      setState(() => _mandado = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '⚠️ ${e is FuncionError ? e.texto(t) : t.errorInesperado(e.toString())}')));
    } finally {
      if (mounted) setState(() => _mandando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.recuperarTitulo)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _mandado
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.mark_email_read_outlined, size: 64),
                    const SizedBox(height: 16),
                    Text(t.recuperarEnviado, textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(t.cerrar)),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(t.recuperarTexto),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _correo,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(labelText: t.cuentaCorreo),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                        onPressed: _mandando ? null : _mandar,
                        child: Text(t.recuperarBoton)),
                  ],
                ),
        ),
      ),
    );
  }
}
