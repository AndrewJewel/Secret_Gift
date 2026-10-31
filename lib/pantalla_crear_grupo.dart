import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';

import 'almacen_local.dart';
import 'compra_play.dart';
import 'dialogo_pago.dart';
import 'fecha_entrega.dart';
import 'funciones.dart';
import 'glass.dart';
import 'l10n/app_localizations.dart';
import 'mi_vinculo.dart';
import 'ocasion.dart';
import 'pantalla_editar_grupo.dart' show SelectorTematica;
import 'pago.dart';
import 'pantalla_registro.dart';
import 'tematica.dart';

class PantallaCrearGrupo extends StatefulWidget {
  const PantallaCrearGrupo({super.key});

  @override
  State<PantallaCrearGrupo> createState() => _PantallaCrearGrupoState();
}

class _PantallaCrearGrupoState extends State<PantallaCrearGrupo> {
  /// Ya no se elige: el color lo pone el selector de color y el ambiente
  /// navideño la temática Navidad. Se sigue guardando para que el modelo
  /// y los grupos viejos de Santa Secreto no cambien.
  static const _ocasion = Ocasion.amigoSecreto;
  Tematica _tematica = Tematica.ninguna;
  Color? _colorPersonal;
  final TextEditingController _nombreGrupoController = TextEditingController();
  final TextEditingController _valorMinimoController = TextEditingController();
  bool _creando = false;
  DateTime? _fechaEntrega;

  /// El color y el fondo los manda la temática; sin temática, el color
  /// elegido o, si no hay, el de la ocasión.
  MaterialColor get _color => _tematica.colorDe(_ocasion, _colorPersonal);

  @override
  void dispose() {
    _nombreGrupoController.dispose();
    _valorMinimoController.dispose();
    super.dispose();
  }

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _crearGrupo() async {
    final t = Textos.of(context);
    // Teclado cerrado antes de navegar: ver pantalla_unirse_grupo.dart.
    FocusScope.of(context).unfocus();
    if (_nombreGrupoController.text.trim().isEmpty) {
      _avisar(t.crearFaltanDatos);
      return;
    }

    setState(() => _creando = true);
    try {
      await _crearYContinuar(t);
    } on FuncionError catch (e) {
      if (e.clave == 'pago_requerido') {
        await _pagarYCrear(t);
      } else {
        _avisar(e.texto(t));
      }
    } catch (e) {
      _avisar(t.errorInesperado(e.toString()));
    } finally {
      if (mounted) setState(() => _creando = false);
    }
  }

  Future<void> _crearYContinuar(Textos t) async {
    final datos = await llamarFuncion('crearGrupo', {
      'ocasion': _ocasion.id,
      'nombreGrupo': _nombreGrupoController.text.trim(),
      'valorMinimo': _valorMinimoController.text.trim(),
      'tematica': _tematica.id,
      if (_tematica == Tematica.ninguna && _colorPersonal != null)
        'color': hexDe(_colorPersonal!),
      // Arranca con las reglas propias de la temática; el organizador
      // las puede reescribir después desde "Editar grupo".
      'reglas': _tematica.reglasPorDefecto(t),
      // El servidor puede cobrar solo en Android (config/cobro.plataformas).
      'plataforma': !kIsWeb && defaultTargetPlatform == TargetPlatform.android ? 'android' : 'web',
      if (_fechaEntrega != null) ...{
        'fechaEntrega': textoDeFecha(_fechaEntrega!),
        // La zona del organizador: los avisos salen a las 10:00 de su hora.
        'zonaEntrega': DateTime.now().timeZoneOffset.inMinutes,
      },
    });
    if (!mounted) return;
    await _continuar(datos['codigo'] as String);
  }

  /// En la web: casilla → checkout de Paddle → esperar el crédito que
  /// suma el webhook → crear. Si se corta en cualquier punto, el crédito
  /// pagado se queda en la cuenta y el próximo «Crear grupo» lo usa.
  Future<void> _pagarYCrear(Textos t) async {
    if (!kIsWeb) {
      if (defaultTargetPlatform != TargetPlatform.android) {
        _avisar(t.pagoSoloWeb);
        return;
      }
      await _comprarEnPlayYCrear(t);
      return;
    }
    if (!await DialogoPago.mostrar(context, precio: t.pagoPrecioWeb) || !mounted) return;
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return;
    final String resultado;
    try {
      resultado = await abrirPago(
        uid: usuario.uid,
        correo: usuario.email ?? '',
        idioma: Localizations.localeOf(context).languageCode,
      );
    } catch (_) {
      _avisar(t.pagoNoCargo);
      return;
    }
    if (resultado != 'completado' || !mounted) return;
    _avisar(t.pagoEsperando);
    if (!await esperarCredito(usuario.uid)) {
      _avisar(t.pagoTardando);
      return;
    }
    if (!mounted) return;
    await _crearYContinuar(t);
  }

  /// Android: casilla → hoja de compra de Google Play → el servidor verifica
  /// y suma el crédito antes de responder → crear. Un pago pendiente llega
  /// solo al confirmarse (ver compra_play_android.dart).
  Future<void> _comprarEnPlayYCrear(Textos t) async {
    final precio = await precioGrupoExtra();
    if (!mounted) return;
    if (precio == null) {
      _avisar(t.pagoNoCargo);
      return;
    }
    if (!await DialogoPago.mostrar(context, precio: precio) || !mounted) return;
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return;
    final resultado = await comprarGrupoExtra(usuario.uid);
    if (!mounted) return;
    switch (resultado) {
      case 'completado':
        await _crearYContinuar(t);
      case 'pendiente':
        _avisar(t.pagoPendiente);
      case 'cancelado':
        break;
      default:
        _avisar(t.pagoNoCargo);
    }
  }

  Future<void> _continuar(String codigo) async {
    await guardarUltimoGrupo(
        codigo, _ocasion.id, _valorMinimoController.text.trim(), _nombreGrupoController.text.trim());
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaRegistro(
          codigo: codigo,
          ocasion: _ocasion,
          valorMinimo: _valorMinimoController.text.trim(),
          nombreGrupo: _nombreGrupoController.text.trim(),
          // Acabas de crear el grupo: eres su organizador y todavía no
          // tienes plaza. Es exactamente lo que `crearGrupo` guardó en la
          // cuenta, así que se pasa sin preguntárselo al servidor. Sin
          // esto la pantalla te trataba como a un desconocido y no
          // enseñaba ni el lápiz de editar ni el botón de sortear en tu
          // propio grupo recién creado.
          vinculo: const MiVinculo(rol: 'organizador'),
          recienCreado: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    return Theme(
      data: temaGlass(_color),
      child: FondoTematico(
        tematica: _tematica,
        ocasion: _ocasion,
        colorPersonal: _colorPersonal,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          // Ver la nota en pantalla_registro.dart: el teclado encoge el
          // Scaffold y el campo enfocado sube solo. Nada de rellenos
          // manuales con viewInsets: contarían el teclado dos veces.
          appBar: GlassAppBar(title: Text(t.crearTitulo), color: _color),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: ListView(
              padding: const EdgeInsets.only(top: 20, bottom: 20),
              children: [
                SelectorTematica(
                  seleccionada: _tematica,
                  color: _color,
                  ocasion: _ocasion,
                  colorPersonal: _colorPersonal,
                  onCambio: (nueva) => setState(() => _tematica = nueva),
                  onColor: (nuevo) => setState(() => _colorPersonal = nuevo),
                ),
                const SizedBox(height: 16),
                GlassTextField(
                  color: _color,
                  controller: _nombreGrupoController,
                  labelText: t.crearNombreGrupo,
                  hintText: t.crearNombreGrupoPista,
                  icon: Icons.label_outline,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                GlassTextField(
                  color: _color,
                  controller: _valorMinimoController,
                  labelText: t.crearValorMinimo,
                  hintText: t.crearValorMinimoPista,
                  icon: Icons.attach_money,
                ),
                const SizedBox(height: 16),
                CampoFechaEntrega(
                  valor: _fechaEntrega,
                  color: _color,
                  onCambio: (f) => setState(() => _fechaEntrega = f),
                ),
                const SizedBox(height: 24),
                GlassButton(
                  color: _color.shade600,
                  onPressed: _creando ? null : _crearGrupo,
                  label: _creando ? t.crearCreando : t.crearBoton,
                  icon: Icons.check,
                  trailing: _creando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
