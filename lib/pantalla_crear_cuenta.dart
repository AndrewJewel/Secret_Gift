import 'package:flutter/material.dart';

import 'acceso_cuenta.dart';
import 'funciones.dart';
import 'glass.dart';
import 'l10n/app_localizations.dart';
import 'ocasion.dart';
import 'oferta_avisos.dart';
import 'pantalla_completar_perfil.dart';
import 'pantalla_iniciar_sesion.dart';
import 'pantalla_verificar_correo.dart';
import 'selector_idioma.dart';
import 'tematica.dart';

/// Esta comprobación es solo del cliente: el servidor ya no valida el
/// formato de la contraseña, porque desde esta migración la guarda Firebase
/// Auth, no nuestro código. La política de verdad (longitud mínima,
/// caracteres exigidos) se configura en la consola de Firebase; este regex
/// es un adelanto para no gastar una llamada con algo que se va a rechazar
/// igual, no la fuente de verdad.
final RegExp _regexPassword =
    RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}$');

/// Misma exigencia que valida el servidor: 4 dígitos exactos.
final RegExp _regexPin = RegExp(r'^\d{4}$');

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

  const PantallaCrearCuenta(
      {super.key, required this.alEntrar, this.nombreGrupoInvitacion});

  @override
  State<PantallaCrearCuenta> createState() => _PantallaCrearCuentaState();
}

class _PantallaCrearCuentaState extends State<PantallaCrearCuenta> {
  final _correo = TextEditingController();
  final _nombre = TextEditingController();
  final _apellido = TextEditingController();
  final _password = TextEditingController();
  final _confirmar = TextEditingController();
  final _pin = TextEditingController();
  final _confirmarPin = TextEditingController();
  bool _cargando = false;
  bool _verPassword = false;

  @override
  void dispose() {
    _correo.dispose();
    _nombre.dispose();
    _apellido.dispose();
    _password.dispose();
    _confirmar.dispose();
    _pin.dispose();
    _confirmarPin.dispose();
    super.dispose();
  }

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _enviar() async {
    final t = Textos.of(context);
    final correo = _correo.text.trim();
    final nombre = _nombre.text.trim();
    final apellido = _apellido.text.trim();
    final password = _password.text;

    if (correo.isEmpty || nombre.isEmpty || apellido.isEmpty || password.isEmpty) {
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
    if (!_regexPin.hasMatch(_pin.text.trim())) {
      _avisar('⚠️ ${t.errorPinFormato}');
      return;
    }
    if (_pin.text.trim() != _confirmarPin.text.trim()) {
      _avisar('⚠️ ${t.cuentaPinNoCoinciden}');
      return;
    }

    setState(() => _cargando = true);
    try {
      await crearCuenta(
        correo: _correo.text,
        password: _password.text,
        nombre: _nombre.text,
        apellido: _apellido.text,
        pin: _pin.text,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PantallaVerificarCorreo(alVerificar: _trasVerificar),
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

  /// Tras verificar, se cargan los grupos y se sigue el camino normal —
  /// el mismo que sigue quien entra con una cuenta ya verificada.
  Future<void> _trasVerificar(BuildContext context) async {
    final r = await cargarMisGrupos();
    if (!context.mounted) return;
    if (r == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PantallaCompletarPerfil(alCompletar: _trasVerificar),
        ),
      );
      return;
    }

    await ofrecerAvisosSiHaceFalta(context);
    if (!context.mounted) return;

    await widget.alEntrar(context, r);
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
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              children: [
                Image.asset('assets/logo.png', height: 120),
                const SizedBox(height: 8),
                Text(t.appTitle,
                    textAlign: TextAlign.center, style: tituloGlass(colorNeutro)),
                const SizedBox(height: 16),
                GlassCard(
                  color: colorNeutro,
                  child: Text(
                    invitacion != null && invitacion.isNotEmpty
                        ? t.cuentaInvitadoA(invitacion)
                        : t.cuentaFraseGancho,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black87, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 24),
                const CampoIdioma(),
                const SizedBox(height: 16),
                GlassTextField(
                  controller: _correo,
                  labelText: t.cuentaCorreo,
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                GlassTextField(
                    controller: _nombre,
                    labelText: t.cuentaNombre,
                    icon: Icons.badge_outlined),
                const SizedBox(height: 16),
                GlassTextField(
                    controller: _apellido,
                    labelText: t.cuentaApellido,
                    icon: Icons.badge_outlined),
                const SizedBox(height: 16),
                GlassTextField(
                  controller: _password,
                  labelText: t.cuentaPassword,
                  helperText: t.cuentaPasswordAyuda,
                  icon: Icons.lock_outline,
                  obscureText: !_verPassword,
                  suffixIcon: IconButton(
                    icon: Icon(_verPassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _verPassword = !_verPassword),
                  ),
                ),
                const SizedBox(height: 16),
                GlassTextField(
                    controller: _confirmar,
                    labelText: t.cuentaConfirmar,
                    icon: Icons.lock_outline,
                    obscureText: !_verPassword),
                const SizedBox(height: 16),
                GlassTextField(
                  controller: _pin,
                  labelText: t.cuentaPin,
                  helperText: t.cuentaPinAyuda,
                  icon: Icons.pin_outlined,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                GlassTextField(
                    controller: _confirmarPin,
                    labelText: t.cuentaPinConfirmar,
                    icon: Icons.pin_outlined,
                    keyboardType: TextInputType.number,
                    obscureText: true),
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
                                builder: (_) =>
                                    PantallaIniciarSesion(alEntrar: widget.alEntrar)),
                          ),
                  child: Text(t.cuentaYaTengoCuenta, textAlign: TextAlign.center),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
