import 'package:flutter/material.dart';

import 'acceso_cuenta.dart';
import 'funciones.dart';
import 'glass.dart';
import 'l10n/app_localizations.dart';
import 'ocasion.dart';
import 'pantalla_iniciar_sesion.dart';
import 'selector_idioma.dart';
import 'tematica.dart';

/// Misma exigencia que valida el servidor: 8+, mayúscula, minúscula,
/// número y símbolo. Se comprueba aquí para no gastar una llamada.
final RegExp _regexPassword = RegExp(
  r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}$',
);

/// Qué hacer cuando la cuenta ya está lista. La pantalla no decide el
/// destino: se lo pasa el portero, que es quien sabe si hay invitación
/// pendiente. Así esta pantalla se prueba sin navegación.
typedef AlEntrar = Future<void> Function(BuildContext, ResultadoAcceso);

/// Primera pantalla de la app.
class PantallaCrearCuenta extends StatefulWidget {
  final AlEntrar alEntrar;

  /// Si se llegó por un QR, el nombre del grupo que invitó. Se muestra en
  /// vez de la frase gancho: quien escanea necesita saber a qué entra, no
  /// leer un eslogan.
  final String? nombreGrupoInvitacion;

  const PantallaCrearCuenta({
    super.key,
    required this.alEntrar,
    this.nombreGrupoInvitacion,
  });

  @override
  State<PantallaCrearCuenta> createState() => _PantallaCrearCuentaState();
}

class _PantallaCrearCuentaState extends State<PantallaCrearCuenta> {
  final _nickname = TextEditingController();
  final _password = TextEditingController();
  final _confirmar = TextEditingController();
  bool _cargando = false;
  bool _verPassword = false;

  @override
  void dispose() {
    _nickname.dispose();
    _password.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _enviar() async {
    final t = Textos.of(context);
    final nickname = _nickname.text.trim();
    final password = _password.text;

    if (nickname.isEmpty || password.isEmpty) {
      _avisar('⚠️ ${t.cuentaFaltanDatos}');
      return;
    }
    if (!_regexPassword.hasMatch(password)) {
      _avisar('⚠️ ${t.errorPasswordDebil}');
      return;
    }
    if (password != _confirmar.text) {
      _avisar('⚠️ ${t.cuentaNoCoinciden}');
      return;
    }

    setState(() => _cargando = true);
    try {
      final r = await entrarConCuenta(
        nickname: nickname,
        password: password,
        registrando: true,
      );
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
    final invitacion = widget.nombreGrupoInvitacion;
    return Theme(
      data: temaGlass(colorNeutro),
      child: FondoNeutro(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            // SingleChildScrollView + Column, no ListView: un ListView de
            // slivers solo construye los hijos que caben en el viewport más
            // el cacheExtent, y este formulario completo (logo, gancho,
            // idioma y los tres campos) es más alto que eso. Con ListView
            // los tests de widget que buscan el campo de confirmación nunca
            // lo encontraban, porque ni siquiera llegaba a construirse.
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset('assets/logo.png', height: 120),
                  const SizedBox(height: 8),
                  Text(
                    t.appTitle,
                    textAlign: TextAlign.center,
                    style: tituloGlass(colorNeutro),
                  ),
                  const SizedBox(height: 16),
                  GlassCard(
                    color: colorNeutro,
                    child: Text(
                      invitacion != null && invitacion.isNotEmpty
                          ? t.cuentaInvitadoA(invitacion)
                          : t.cuentaFraseGancho,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const CampoIdioma(),
                  const SizedBox(height: 16),
                  GlassTextField(
                    controller: _nickname,
                    labelText: t.cuentaNickname,
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),
                  GlassTextField(
                    controller: _password,
                    labelText: t.cuentaPassword,
                    helperText: t.cuentaPasswordAyuda,
                    icon: Icons.lock_outline,
                    obscureText: !_verPassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _verPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _verPassword = !_verPassword),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GlassTextField(
                    controller: _confirmar,
                    labelText: t.cuentaConfirmar,
                    icon: Icons.lock_outline,
                    obscureText: !_verPassword,
                  ),
                  const SizedBox(height: 24),
                  GlassButton(
                    color: colorNeutro.shade600,
                    icon: Icons.person_add_alt,
                    label: t.cuentaCrearTitulo,
                    onPressed: _cargando ? null : _enviar,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _cargando
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PantallaIniciarSesion(
                                alEntrar: widget.alEntrar,
                              ),
                            ),
                          ),
                    child: Text(
                      t.cuentaYaTengoCuenta,
                      textAlign: TextAlign.center,
                    ),
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
