import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
///
/// Lo normal es un código de 6 dígitos que se escribe aquí mismo: sin salir
/// de la app al buzón y sin un enlace de un dominio que nadie reconoce. Si
/// nuestro correo falló y salió el enlace de Firebase, la pantalla vuelve a
/// la espera de siempre ([MedioVerificacion.enlace]).
class PantallaVerificarCorreo extends StatefulWidget {
  /// Qué hacer cuando el correo queda verificado.
  final Future<void> Function(BuildContext) alVerificar;

  /// Por dónde le llegó. Null: todavía no se mandó nada en esta visita
  /// (llega desde «Entrar» o al reabrir la app), así que se manda al abrir.
  final MedioVerificacion? medio;

  /// Null: el de la sesión. Se inyecta en las pruebas.
  final String? correo;

  /// Sustitutos para las pruebas; por defecto, los reales.
  final Future<MedioVerificacion> Function()? mandar;
  final Future<void> Function(String)? verificar;

  const PantallaVerificarCorreo({
    super.key,
    required this.alVerificar,
    this.medio,
    this.correo,
    this.mandar,
    this.verificar,
  });

  @override
  State<PantallaVerificarCorreo> createState() => _PantallaVerificarCorreoState();
}

class _PantallaVerificarCorreoState extends State<PantallaVerificarCorreo> {
  final _codigo = TextEditingController();
  late MedioVerificacion _medio = widget.medio ?? MedioVerificacion.codigo;
  bool _comprobando = false;
  bool _reenviando = false;

  /// Segundos hasta poder pedir otro código (el servidor permite uno por
  /// minuto).
  int _espera = 0;
  Timer? _reloj;

  String get _correo => widget.correo ?? FirebaseAuth.instance.currentUser?.email ?? '';

  @override
  void initState() {
    super.initState();
    if (widget.medio == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reenviar(alAbrir: true));
    } else if (widget.medio == MedioVerificacion.codigo) {
      _empezarEspera();
    }
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _codigo.dispose();
    super.dispose();
  }

  void _empezarEspera() {
    _reloj?.cancel();
    _espera = 60;
    _reloj = Timer.periodic(const Duration(seconds: 1), (reloj) {
      if (!mounted) return reloj.cancel();
      setState(() => _espera--);
      if (_espera <= 0) reloj.cancel();
    });
  }

  Future<void> _verificarCodigo(String codigo) async {
    final t = Textos.of(context);
    setState(() => _comprobando = true);
    try {
      await (widget.verificar ?? verificarCodigo)(codigo);
      if (!mounted) return;
      await widget.alVerificar(context);
    } catch (e) {
      _codigo.clear();
      _avisar(e is FuncionError ? e.texto(t) : t.errorInesperado(e.toString()));
    } finally {
      if (mounted) setState(() => _comprobando = false);
    }
  }

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
      _avisar(t.verificarTodaviaNo);
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
      _avisar(e is FuncionError ? e.texto(t) : t.errorInesperado(e.toString()));
    } finally {
      if (mounted) setState(() => _comprobando = false);
    }
  }

  Future<void> _reenviar({bool alAbrir = false}) async {
    final t = Textos.of(context);
    setState(() => _reenviando = true);
    try {
      final medio = await (widget.mandar ?? mandarVerificacion)();
      if (!mounted) return;
      if (medio == MedioVerificacion.yaVerificado) {
        await widget.alVerificar(context);
        return;
      }
      setState(() {
        _medio = medio;
        if (medio == MedioVerificacion.codigo) _empezarEspera();
      });
      if (!alAbrir) {
        _avisar(
          medio == MedioVerificacion.codigo ? t.verificarCodigoMandado : t.verificarReenviado,
        );
      }
    } catch (e) {
      // Al abrir, «espera un minuto» solo significa que ya tiene un código
      // reciente en su correo: no es un error que enseñar.
      final esEspera = e is FuncionError && e.clave == 'demasiados_correos';
      if (!(alAbrir && esEspera)) {
        _avisar(e is FuncionError ? e.texto(t) : t.errorInesperado(e.toString()));
      }
      if (esEspera && mounted) setState(_empezarEspera);
    } finally {
      if (mounted) setState(() => _reenviando = false);
    }
  }

  Future<void> _salir() async {
    await salir();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
  }

  List<Widget> _modoEnlace(Textos t) => [
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
      child: Text(_comprobando ? t.verificarComprobando : t.verificarComprobar),
    ),
    const SizedBox(height: 8),
    TextButton(
      onPressed: _reenviando ? null : _reenviar,
      child: Text(_reenviando ? t.verificarReenviando : t.verificarReenviar),
    ),
  ];

  List<Widget> _modoCodigo(Textos t) {
    final completo = _codigo.text.length == 6;
    return [
      const Icon(Icons.mark_email_unread_outlined, size: 64),
      const SizedBox(height: 16),
      Text(
        t.verificarCodigoTitulo,
        style: Theme.of(context).textTheme.headlineSmall,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      Text(t.verificarCodigoTexto(_correo), textAlign: TextAlign.center),
      const SizedBox(height: 20),
      SizedBox(
        width: 220,
        child: TextField(
          controller: _codigo,
          enabled: !_comprobando,
          autofocus: true,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, letterSpacing: 10, fontWeight: FontWeight.bold),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: t.verificarCodigoCampo, counterText: ''),
          // Al sexto dígito se comprueba solo: nada que pulsar.
          onChanged: (v) {
            setState(() {});
            if (v.length == 6 && !_comprobando) _verificarCodigo(v);
          },
        ),
      ),
      const SizedBox(height: 20),
      GlassButton(
        color: colorNeutro.shade600,
        label: t.verificarCodigoBoton,
        onPressed: _comprobando || !completo ? null : () => _verificarCodigo(_codigo.text),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _reenviando || _espera > 0 ? null : _reenviar,
        child: Text(_espera > 0 ? t.verificarOtroCodigoEn(_espera) : t.verificarOtroCodigo),
      ),
      TextButton(onPressed: _comprobando ? null : _comprobar, child: Text(t.verificarConEnlace)),
    ];
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
                    if (_medio == MedioVerificacion.enlace)
                      ..._modoEnlace(t)
                    else
                      ..._modoCodigo(t),
                    const SizedBox(height: 8),
                    TextButton(onPressed: _salir, child: Text(t.misGruposCerrarSesion)),
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
