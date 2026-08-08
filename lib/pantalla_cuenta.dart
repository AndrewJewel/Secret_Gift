import 'package:flutter/material.dart';

import 'funciones.dart';
import 'glass.dart';
import 'l10n/app_localizations.dart';
import 'ocasion.dart';
import 'tematica.dart';
import 'pantalla_mis_grupos.dart';
import 'sesion.dart';

final RegExp _regexPassword =
    RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}$');

class PantallaCuenta extends StatefulWidget {
  const PantallaCuenta({super.key});

  @override
  State<PantallaCuenta> createState() => _PantallaCuentaState();
}

class _PantallaCuentaState extends State<PantallaCuenta> {
  bool _modoCrear = false;
  final _nicknameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmarController = TextEditingController();
  bool _cargando = false;
  bool _verPassword = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    _passwordController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _enviar() async {
    final t = Textos.of(context);
    final nickname = _nicknameController.text.trim();
    final password = _passwordController.text;

    if (nickname.isEmpty || password.isEmpty) {
      _avisar('⚠️ ${t.cuentaFaltanDatos}');
      return;
    }
    if (_modoCrear) {
      if (!_regexPassword.hasMatch(password)) {
        _avisar('⚠️ ${t.errorPasswordDebil}');
        return;
      }
      if (password != _confirmarController.text) {
        _avisar('⚠️ ${t.cuentaNoCoinciden}');
        return;
      }
    }

    setState(() => _cargando = true);
    try {
      if (_modoCrear) {
        await llamarFuncion('registrarCuenta', {'nickname': nickname, 'password': password});
      }
      final resultado =
          await llamarFuncion('iniciarSesionCuenta', {'nickname': nickname, 'password': password});
      await guardarSesion(nickname, password);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PantallaMisGrupos(
            nickname: resultado['nickname'] as String,
            grupos: List<Map<String, dynamic>>.from(
                (resultado['grupos'] as List).map((g) => Map<String, dynamic>.from(g as Map))),
          ),
        ),
      );
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
          // Ver la nota en pantalla_registro.dart.
          resizeToAvoidBottomInset: false,
          appBar: GlassAppBar(
              title: Text(_modoCrear ? t.cuentaCrearTitulo : t.cuentaEntrarTitulo),
              color: colorNeutro),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: ListView(
              padding: EdgeInsets.only(
                  top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
              children: [
                GlassTextField(
                  color: colorNeutro,
                  controller: _nicknameController,
                  labelText: t.cuentaNickname,
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 16),
                GlassTextField(
                  color: colorNeutro,
                  controller: _passwordController,
                  labelText: t.cuentaPassword,
                  icon: Icons.lock_outline,
                  obscureText: !_verPassword,
                  helperText: _modoCrear ? t.cuentaPasswordAyuda : null,
                  suffixIcon: IconButton(
                    icon: Icon(_verPassword ? Icons.visibility_off : Icons.visibility,
                        color: colorNeutro.shade700),
                    onPressed: () => setState(() => _verPassword = !_verPassword),
                  ),
                ),
                if (_modoCrear) ...[
                  const SizedBox(height: 16),
                  GlassTextField(
                    color: colorNeutro,
                    controller: _confirmarController,
                    labelText: t.cuentaConfirmar,
                    icon: Icons.lock_outline,
                    obscureText: !_verPassword,
                  ),
                ],
                const SizedBox(height: 24),
                GlassButton(
                  color: colorNeutro.shade600,
                  onPressed: _cargando ? null : _enviar,
                  label: _cargando
                      ? t.unMomento
                      : (_modoCrear ? t.cuentaCrearTitulo : t.entrar),
                  trailing: _cargando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.arrow_forward),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() => _modoCrear = !_modoCrear),
                  child: Text(
                    _modoCrear ? t.cuentaCambiarAEntrar : t.cuentaCambiarACrear,
                    style: TextStyle(color: colorNeutro.shade700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
