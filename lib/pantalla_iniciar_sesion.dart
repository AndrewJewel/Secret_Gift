import 'package:flutter/material.dart';

import 'acceso_cuenta.dart';
import 'almacen_local.dart';
import 'auth.dart';
import 'funciones.dart';
import 'glass.dart';
import 'l10n/app_localizations.dart';
import 'ocasion.dart';
import 'pantalla_completar_perfil.dart';
import 'pantalla_crear_cuenta.dart' show AlEntrar;
import 'pantalla_permiso_avisos.dart';
import 'pantalla_recuperar_password.dart';
import 'pantalla_verificar_correo.dart';
import 'push.dart';
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
  final _correo = TextEditingController();
  final _password = TextEditingController();
  bool _cargando = false;
  bool _verPassword = false;

  @override
  void dispose() {
    _correo.dispose();
    _password.dispose();
    super.dispose();
  }

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _enviar() async {
    final t = Textos.of(context);
    final correo = _correo.text.trim();
    final password = _password.text;
    if (correo.isEmpty || password.isEmpty) {
      _avisar('⚠️ ${t.cuentaFaltanDatos}');
      return;
    }
    setState(() => _cargando = true);
    try {
      await entrar(correo: _correo.text, password: _password.text);
      final u = usuarioActual;
      if (u != null && !u.emailVerified) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PantallaVerificarCorreo(alVerificar: _trasVerificar),
          ),
        );
        return;
      }
      if (!mounted) return;
      await _trasVerificar(context);
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

    // El permiso de avisos se ofrece aquí, en el primer momento en que
    // esta persona entra de verdad. Antes de verificar el correo no puede
    // hacer nada, y preguntárselo mientras espera sería interrumpirla en
    // mitad de otra cosa.
    //
    // `yaSePreguntoPorAvisos` es por DISPOSITIVO, no por cuenta: el
    // permiso es del navegador, así que la misma persona tiene que poder
    // decidirlo en el móvil y en el portátil por separado.
    if (!await yaSePreguntoPorAvisos()) {
      await marcarPreguntadoPorAvisos();
      if (!context.mounted) return;
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => PantallaPermisoAvisos(
          alAceptar: () async {
            await pedirPermisoYRegistrar();
            if (context.mounted) Navigator.pop(context);
          },
          alSaltar: () => Navigator.pop(context),
        ),
      ));
    }
    // El `if` de arriba empieza con un `await` en su propia condición
    // (`yaSePreguntoPorAvisos`): incluso cuando ya se había preguntado y
    // el cuerpo no llega a ejecutarse, ese `await` ya es un hueco async
    // que hay que volver a comprobar antes de seguir usando `context`.
    if (!context.mounted) return;

    await widget.alEntrar(context, r);
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
                  controller: _correo,
                  labelText: t.cuentaCorreo,
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
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
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PantallaRecuperarPassword()),
                  ),
                  child: Text(t.recuperarEnlace),
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
