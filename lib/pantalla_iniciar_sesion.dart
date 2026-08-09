import 'package:flutter/material.dart';

import 'acceso_cuenta.dart';
import 'funciones.dart';
import 'glass.dart';
import 'l10n/app_localizations.dart';
import 'ocasion.dart';
import 'pantalla_crear_cuenta.dart' show AlEntrar;
import 'tematica.dart';

/// Entrar con una cuenta que ya existe.
///
/// No lleva casilla de idioma a propósito: quien vuelve ya tiene el suyo
/// guardado, y quien llega desde un dispositivo nuevo pasa antes por la
/// pantalla de registro, donde sí está.
class PantallaIniciarSesion extends StatefulWidget {
  final AlEntrar alEntrar;

  const PantallaIniciarSesion({super.key, required this.alEntrar});

  @override
  State<PantallaIniciarSesion> createState() => _PantallaIniciarSesionState();
}

class _PantallaIniciarSesionState extends State<PantallaIniciarSesion> {
  final _nickname = TextEditingController();
  final _password = TextEditingController();
  bool _cargando = false;
  bool _verPassword = false;

  @override
  void dispose() {
    _nickname.dispose();
    _password.dispose();
    super.dispose();
  }

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _enviar() async {
    final t = Textos.of(context);
    final nickname = _nickname.text.trim();
    final password = _password.text;
    if (nickname.isEmpty || password.isEmpty) {
      _avisar('⚠️ ${t.cuentaFaltanDatos}');
      return;
    }
    setState(() => _cargando = true);
    try {
      final r = await entrarConCuenta(
          nickname: nickname, password: password, registrando: false);
      if (!mounted) return;
      await widget.alEntrar(context, r);
    } on FuncionError catch (e) {
      _avisar('⚠️ ${e.texto(t)}');
    } catch (e) {
      _avisar('⚠️ ${t.errorInesperado(e.toString())}');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    return Theme(
      data: temaGlass(colorNeutro),
      child: FondoNeutro(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: GlassAppBar(title: Text(t.cuentaEntrarTitulo), color: colorNeutro),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              children: [
                Image.asset('assets/logo.png', height: 96),
                const SizedBox(height: 24),
                GlassTextField(
                    controller: _nickname,
                    labelText: t.cuentaNickname,
                    icon: Icons.person_outline),
                const SizedBox(height: 16),
                GlassTextField(
                  controller: _password,
                  labelText: t.cuentaPassword,
                  icon: Icons.lock_outline,
                  obscureText: !_verPassword,
                  suffixIcon: IconButton(
                    icon: Icon(_verPassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _verPassword = !_verPassword),
                  ),
                ),
                const SizedBox(height: 24),
                GlassButton(
                  color: colorNeutro.shade600,
                  icon: Icons.login,
                  label: t.cuentaEntrarTitulo,
                  onPressed: _cargando ? null : _enviar,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _cargando ? null : () => Navigator.pop(context),
                  child: Text(t.cuentaNoTengoCuenta, textAlign: TextAlign.center),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
