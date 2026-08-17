import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'acceso_cuenta.dart';
import 'almacen_roto.dart';
import 'funciones.dart';
import 'glass.dart';
import 'l10n/app_localizations.dart';
import 'ocasion.dart';
import 'recarga_pagina.dart';
import 'tematica.dart';

/// Pantalla de espera tras registrarse. Bloquea a propósito: un correo sin
/// verificar es un camino de recuperación que quizá no existe, y la
/// recuperación es medio motivo de que exista esta pantalla.
class PantallaVerificarCorreo extends StatefulWidget {
  /// Qué hacer cuando el correo queda verificado.
  final Future<void> Function(BuildContext) alVerificar;
  const PantallaVerificarCorreo({super.key, required this.alVerificar});

  @override
  State<PantallaVerificarCorreo> createState() =>
      _PantallaVerificarCorreoState();
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
      // Probado hoy en un móvil Android con Chrome: la persona verifica el
      // correo, tarda unos minutos fuera de la app y al volver el navegador
      // ha congelado la pestaña en segundo plano. Al congelarla cierra su
      // IndexedDB, que es donde Firebase Auth guarda la sesión en web, y
      // ese almacén NO se cura solo. Se probaron, y NO sirvieron, tres
      // arreglos: reintentar reload() (dca42d6), reintentar getIdToken()
      // (211da13) y forzar Persistence.LOCAL (c7ff78e) — ninguno repara un
      // recurso ya roto. Lo único que lo repara, comprobado a mano, es
      // restaurar el contexto de la página: bloquear y desbloquear el
      // móvil (que hace que el navegador la restaure) recuperó la sesión
      // donde reintentar, dos veces seguidas, no lo hizo.
      //
      // Así que en vez de reintentar, se recarga la página — exactamente
      // lo que la persona hacía a mano. Es una recarga segura aquí: no hay
      // nada que escribir en esta pantalla, y si el correo ya estaba
      // verificado `PantallaRaiz` entra directa sin pedirle a nadie que
      // pulse nada de nuevo (ver `_entrarConLaSesionDeAuth` en
      // pantalla_raiz.dart).
      //
      // El tope de una sola recarga por pestaña es IMPRESCINDIBLE: sin él,
      // un fallo persistente (no de almacén roto, sino de verdad) dejaría
      // a la persona en un bucle de recargas, que es peor que el error que
      // esto arregla. La marca vive en sessionStorage (ver
      // recarga_pagina.dart) para sobrevivir a la recarga sin sobrevivir a
      // cerrar la pestaña.
      if (kIsWeb &&
          debeRecargarPorAlmacenRoto(
            esFalloDeAlmacen: esFalloDeAlmacenRoto(e),
            yaRecargadaEstaSesion: sesionYaRecargadaPorAlmacenRoto(),
          )) {
        marcarSesionRecargadaYRecargarPagina();
        return;
      }
      _avisar(
        '⚠️ ${e is FuncionError ? e.texto(t) : t.errorInesperado(e.toString())}',
      );
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
      _avisar(
        '⚠️ ${e is FuncionError ? e.texto(t) : t.errorInesperado(e.toString())}',
      );
    } finally {
      if (mounted) setState(() => _reenviando = false);
    }
  }

  Future<void> _salir() async {
    await salir();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
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
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.mark_email_unread_outlined, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      t.verificarTitulo,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(t.verificarTexto, textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _comprobando ? null : _comprobar,
                      child: Text(
                        _comprobando
                            ? t.verificarComprobando
                            : t.verificarComprobar,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _reenviando ? null : _reenviar,
                      child: Text(
                        _reenviando
                            ? t.verificarReenviando
                            : t.verificarReenviar,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _salir,
                      child: Text(t.misGruposCerrarSesion),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
