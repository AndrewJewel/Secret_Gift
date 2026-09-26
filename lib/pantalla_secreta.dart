import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'l10n/app_localizations.dart';

/// La revelación: tu caja cerrada con su lazo; al tocarla se abre, y sobre
/// el papel de seda aparece la tarjeta con el nombre de tu amigo secreto.
/// Debajo, su lista de deseos.
///
/// Es el único momento con animación grande de toda la app: el pico de la
/// experiencia (ver el brief de superficie en .impeccable/surfaces). Con
/// «reducir movimiento» se salta directo al final.
///
/// Las ilustraciones (assets/plates) no llevan texto: el nombre, el grupo y
/// los deseos los pone el código encima, porque cambian en cada grupo.
class PantallaSecreta extends StatefulWidget {
  final String nombreGrupo;

  /// Cuántas personas hay en el grupo, para el canto de la caja. Null = no
  /// se muestra.
  final int? personas;
  final String nombreAmigo;

  /// Vacío = la persona no escribió deseos.
  final String deseosAmigo;

  const PantallaSecreta({
    super.key,
    required this.nombreGrupo,
    this.personas,
    required this.nombreAmigo,
    required this.deseosAmigo,
  });

  @override
  State<PantallaSecreta> createState() => _PantallaSecretaState();
}

// El mundo de la caja: cartón dorado, cinta carmín, papel de seda y tinta.
const _marfil = Color(0xFFF4EFE5);
const _tinta = Color(0xFF181818);
const _tintaSuave = Color(0xFF6B6158);
const _carmin = Color(0xFF9B1226);
const _tintaCanto = Color(0xFF3F230B);
const _panel = Color(0xFFFAF7F1);

// Geometría medida sobre las ilustraciones (fracciones de su ancho o alto).
const _aspectoCaja =
    1036 / 1300; // abierta desde arriba, con la tarjeta en el papel
const _aspectoCajaCerrada = 1300 / 1145;
// La tarjeta en blanco va dibujada DENTRO del papel de seda (así el papel le
// cubre las orillas de verdad); el código solo escribe encima, con su giro.
const _centroTarjeta = Offset(0.489, 0.535);
// Medido sobre las cuatro esquinas de la tarjeta dibujada: los bordes
// superior e inferior son paralelos, a −10°. El texto va a ese ángulo.
const _giroTarjeta = -0.175; // rad
const _anchoTarjeta = 0.55; // largo del borde, en fracción del ancho de la caja
const _centroCantoAbierta = 0.905;
const _centroEtiquetaColgante = Offset(0.585, 0.522); // caja cerrada
const _giroEtiquetaColgante = -0.54; // rad: a lo ancho de la etiqueta
const _centroCantoCerrada = 0.882;

TextStyle _serif({
  double? tam,
  Color color = _tinta,
  double? alto,
  double? espacio,
}) => GoogleFonts.gentiumBookPlus(
  fontSize: tam,
  color: color,
  height: alto,
  letterSpacing: espacio,
);

TextStyle _versalitas(double tam) => GoogleFonts.merriweatherSans(
  fontSize: tam,
  letterSpacing: tam * 0.28,
  color: _tintaCanto,
  fontWeight: FontWeight.w600,
);

class _PantallaSecretaState extends State<PantallaSecreta>
    with SingleTickerProviderStateMixin {
  late final AnimationController _apertura = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  bool get _abierta => _apertura.value >= 0.5;

  @override
  void dispose() {
    _apertura.dispose();
    super.dispose();
  }

  void _abrir() {
    if (_apertura.value > 0) return;
    HapticFeedback.mediumImpact();
    if (MediaQuery.of(context).disableAnimations) {
      _apertura.value = 1;
    } else {
      _apertura.forward();
    }
  }

  /// Un tramo de la animación general, con su curva.
  Animation<double> _tramo(
    double desde,
    double hasta, [
    Curve curva = Curves.easeOutCubic,
  ]) => CurvedAnimation(
    parent: _apertura,
    curve: Interval(desde, hasta, curve: curva),
  );

  String get _rotuloCanto {
    final t = Textos.of(context);
    final grupo = widget.nombreGrupo.toUpperCase();
    final n = widget.personas;
    return n == null ? grupo : '$grupo · ${t.secretaPersonas(n).toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    final sinSorteo = widget.nombreAmigo.isEmpty;
    return Scaffold(
      backgroundColor: _marfil,
      appBar: AppBar(
        backgroundColor: _marfil,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        // Flecha de trazo fino, como en la imagen aprobada: la de Material
        // es más gruesa que el resto del mundo de la caja.
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(
                  CupertinoIcons.arrow_left,
                  color: _tinta,
                  size: 24,
                ),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => Navigator.maybePop(context),
              )
            : null,
        title: Text(t.secretaBarra, style: _serif(tam: 22, espacio: -0.4)),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, restricciones) {
            final ancho = math.min(restricciones.maxWidth, 460.0) - 32;
            if (sinSorteo) {
              return Center(
                child: SizedBox(width: ancho, child: _sinSorteo(t)),
              );
            }
            // La caja y los deseos se desplazan; el botón queda fijo abajo,
            // fuera del scroll. Sin IntrinsicHeight: en pantallas bajas
            // calculaba mal el alto y la columna se desbordaba.
            return AnimatedBuilder(
              animation: _apertura,
              builder: (context, _) => Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Center(
                        child: SizedBox(
                          width: ancho,
                          child: Column(
                            children: [
                              // «Oficina 2026 · sorteo hecho», solo con la caja
                              // cerrada: al abrirla se pliega y deja sitio.
                              ClipRect(
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  heightFactor: 1 - _tramo(0.0, 0.3).value,
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      '${widget.nombreGrupo} · ${t.secretaSorteoHecho}',
                                      textAlign: TextAlign.center,
                                      style: _serif(
                                        tam: 15,
                                        color: _tintaSuave,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              _escenario(t, ancho),
                              const SizedBox(height: 14),
                              _debajo(t, ancho),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: SizedBox(
                      width: ancho,
                      child: _boton(
                        _abierta ? t.secretaListo : t.secretaAbrirCaja,
                        _abierta ? () => Navigator.pop(context) : _abrir,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _sinSorteo(Textos t) => SizedBox(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          t.secretaSinSorteo,
          textAlign: TextAlign.center,
          style: _serif(tam: 22),
        ),
        const SizedBox(height: 32),
        _boton(t.secretaListo, () => Navigator.pop(context)),
      ],
    ),
  );

  /// La caja: cerrada, o abierta desde arriba con la tarjeta sobre el papel.
  Widget _escenario(Textos t, double ancho) {
    final anchoCaja = ancho * 0.95;
    final altoCaja = anchoCaja / _aspectoCaja;
    final cerrada = 1 - _tramo(0.08, 0.30, Curves.easeIn).value;
    final latido =
        1 +
        0.04 * math.sin(math.pi * _tramo(0.0, 0.14, Curves.easeInOut).value);
    final abierta = _tramo(0.18, 0.42).value;
    final asiento = _tramo(0.34, 0.80, Curves.easeOutBack).value;

    return SizedBox(
      width: ancho,
      height: altoCaja,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (cerrada > 0)
            Opacity(
              opacity: cerrada,
              child: Transform.scale(
                scale: latido,
                child: Semantics(
                  button: true,
                  label: t.secretaAbrirCaja,
                  child: GestureDetector(
                    onTap: _abrir,
                    child: _cajaCerrada(t, ancho, ancho / _aspectoCajaCerrada),
                  ),
                ),
              ),
            ),
          if (abierta > 0)
            Opacity(
              opacity: abierta,
              child: Transform.scale(
                scale: 0.95 + 0.05 * abierta,
                child: _cajaAbierta(t, anchoCaja, altoCaja, asiento),
              ),
            ),
        ],
      ),
    );
  }

  /// La caja cerrada con su lazo: «Para ti» en la etiqueta colgante y el
  /// nombre del grupo en el canto.
  Widget _cajaCerrada(Textos t, double w, double h) {
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/plates/caja_cerrada.webp',
              fit: BoxFit.fill,
            ),
          ),
          Positioned(
            left: w * _centroEtiquetaColgante.dx - w * 0.12,
            top: h * _centroEtiquetaColgante.dy - w * 0.03,
            width: w * 0.24,
            child: Transform.rotate(
              angle: _giroEtiquetaColgante,
              child: Text(
                t.secretaParaTi,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: _serif(tam: w * 0.045, color: _carmin),
              ),
            ),
          ),
          Positioned(
            left: w * 0.24,
            right: w * 0.24,
            top: h * _centroCantoCerrada - w * 0.02,
            child: Text(
              _rotuloCanto,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _versalitas(w * 0.024),
            ),
          ),
        ],
      ),
    );
  }

  /// La caja abierta vista desde arriba, con la tarjeta metida en el papel
  /// de seda. El nombre aparece escrito sobre ella al abrirse.
  Widget _cajaAbierta(Textos t, double w, double h, double asiento) {
    final anchoTexto = w * _anchoTarjeta * 0.92;
    final visible = asiento > 0.9;
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Image.asset('assets/plates/caja.webp', fit: BoxFit.fill),
          ),
          Positioned(
            left: w * _centroTarjeta.dx - anchoTexto / 2,
            top: h * _centroTarjeta.dy - w * 0.14,
            width: anchoTexto,
            height: w * 0.28,
            child: Semantics(
              liveRegion: visible,
              label: visible ? t.secretaAnuncio(widget.nombreAmigo) : null,
              excludeSemantics: true,
              child: Opacity(
                opacity: asiento.clamp(0.0, 1.0),
                child: Transform.rotate(
                  angle: _giroTarjeta,
                  child: Transform.scale(
                    scale: 1.08 - 0.08 * asiento,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          t.secretaTeToco,
                          style: _serif(tam: w * 0.042, color: _carmin),
                        ),
                        SizedBox(height: w * 0.008),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            widget.nombreAmigo,
                            textAlign: TextAlign.center,
                            style: _serif(
                              tam: w * 0.078,
                              color: _carmin,
                              alto: 1.05,
                              espacio: -0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: w * 0.27,
            right: w * 0.27,
            top: h * _centroCantoAbierta - w * 0.018,
            child: Text(
              _rotuloCanto,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _versalitas(w * 0.021),
            ),
          ),
        ],
      ),
    );
  }

  /// Cerrada: la pista. Abierta: el panel con la lista de deseos.
  Widget _debajo(Textos t, double ancho) {
    final llegada = _tramo(0.60, 1.0).value;
    if (llegada == 0) {
      return Opacity(
        opacity: 1 - _tramo(0.0, 0.2).value,
        child: Text(
          t.secretaTocaLaCaja,
          textAlign: TextAlign.center,
          style: _serif(tam: 17, color: _tintaSuave),
        ),
      );
    }
    final deseos = widget.deseosAmigo.trim().isEmpty
        ? t.secretaSinSugerencias
        : widget.deseosAmigo.trim();
    return Opacity(
      opacity: llegada,
      child: Transform.translate(
        offset: Offset(0, 30 * (1 - llegada)),
        child: Container(
          width: ancho,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.card_giftcard_outlined,
                    color: _tinta,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    t.secretaListaDeseos,
                    style: _serif(tam: 19, espacio: -0.2),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                deseos,
                style: _serif(
                  tam: 15,
                  alto: 1.4,
                  color: const Color(0xFF3A3530),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _boton(String texto, VoidCallback alPulsar) => SizedBox(
    width: double.infinity,
    height: 54,
    child: FilledButton(
      onPressed: alPulsar,
      style: FilledButton.styleFrom(
        backgroundColor: _tinta,
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
      ),
      child: Text(texto, style: _serif(tam: 19, color: Colors.white)),
    ),
  );
}
