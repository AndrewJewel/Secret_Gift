import 'package:flutter/material.dart';

import 'acceso_cuenta.dart';
import 'funciones.dart';
import 'glass.dart';
import 'l10n/app_localizations.dart';
import 'ocasion.dart';
import 'tematica.dart';

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
              e is FuncionError ? e.texto(t) : t.errorInesperado(e.toString()))));
    } finally {
      if (mounted) setState(() => _mandando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    // FondoNeutro es quien pinta el fondo (manchas de color sobre
    // degradado); un Scaffold suelto, sin este envoltorio ni el Theme de
    // temaGlass, sale con el gris por defecto de Material. En web no se
    // notaba porque el fondo de web/index.html lo tapaba; en Android no
    // hay nada debajo y se ve. Mismo envoltorio que el resto de pantallas
    // (ver pantalla_crear_cuenta.dart).
    return Theme(
      data: temaGlass(colorNeutro),
      child: FondoNeutro(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          // Misma barra, campos y botones que «Entrar», de donde se llega.
          appBar: GlassAppBar(title: Text(t.recuperarTitulo), color: colorNeutro),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _mandado
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mark_email_read_outlined, size: 64, color: colorNeutro.shade700),
                        const SizedBox(height: 16),
                        Text(t.recuperarEnviado, textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        GlassButton(
                          color: colorNeutro.shade600,
                          onPressed: () => Navigator.pop(context),
                          label: t.cerrar,
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(t.recuperarTexto,
                            style: const TextStyle(color: Colors.black87, fontSize: 15)),
                        const SizedBox(height: 16),
                        GlassTextField(
                          controller: _correo,
                          labelText: t.cuentaCorreo,
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                        ),
                        const SizedBox(height: 16),
                        GlassButton(
                          color: colorNeutro.shade600,
                          onPressed: _mandando ? null : _mandar,
                          icon: Icons.send_outlined,
                          label: t.recuperarBoton,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
