import 'package:flutter/material.dart';

import 'acceso_cuenta.dart';
import 'funciones.dart';
import 'l10n/app_localizations.dart';

/// Pantalla de espera tras registrarse. Bloquea a propósito: un correo sin
/// verificar es un camino de recuperación que quizá no existe, y la
/// recuperación es medio motivo de que exista esta pantalla.
class PantallaVerificarCorreo extends StatefulWidget {
  /// Qué hacer cuando el correo queda verificado.
  final Future<void> Function(BuildContext) alVerificar;
  const PantallaVerificarCorreo({super.key, required this.alVerificar});

  @override
  State<PantallaVerificarCorreo> createState() => _PantallaVerificarCorreoState();
}

class _PantallaVerificarCorreoState extends State<PantallaVerificarCorreo> {
  bool _comprobando = false;
  bool _reenviando = false;

  void _avisar(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _comprobar() async {
    final t = Textos.of(context);
    setState(() => _comprobando = true);
    try {
      if (await correoVerificado()) {
        if (!mounted) return;
        await widget.alVerificar(context);
        return;
      }
      _avisar('⚠️ ${t.verificarTodaviaNo}');
    } catch (e) {
      _avisar('⚠️ ${e is FuncionError ? e.texto(t) : t.errorInesperado(e.toString())}');
    } finally {
      if (mounted) setState(() => _comprobando = false);
    }
  }

  Future<void> _reenviar() async {
    final t = Textos.of(context);
    setState(() => _reenviando = true);
    try {
      await mandarVerificacion();
      _avisar('✅ ${t.verificarReenviado}');
    } catch (e) {
      _avisar('⚠️ ${e is FuncionError ? e.texto(t) : t.errorInesperado(e.toString())}');
    } finally {
      if (mounted) setState(() => _reenviando = false);
    }
  }

  Future<void> _salir() async {
    await salir();
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
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
                const Icon(Icons.mark_email_unread_outlined, size: 64),
                const SizedBox(height: 16),
                Text(t.verificarTitulo,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(t.verificarTexto, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _comprobando ? null : _comprobar,
                  child: Text(_comprobando ? t.verificarComprobando : t.verificarComprobar),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _reenviando ? null : _reenviar,
                  child: Text(_reenviando ? t.verificarReenviando : t.verificarReenviar),
                ),
                const SizedBox(height: 8),
                TextButton(onPressed: _salir, child: Text(t.misGruposCerrarSesion)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
