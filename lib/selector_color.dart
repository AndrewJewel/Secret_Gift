import 'package:flutter/material.dart';

import 'glass.dart';
import 'l10n/app_localizations.dart';
import 'marca.dart';
import 'ocasion.dart';
import 'tematica.dart';

/// Colores sugeridos. Todos medios u oscuros a propósito: sobre ellos se
/// calcula la escala del vidrio, y un color muy claro deja los títulos
/// (shade800) sin contraste sobre el blanco.
const coloresSugeridos = <Color>[
  Color(0xFF9B1226), // carmín
  Color(0xFFC2185B), // frambuesa
  Color(0xFFD84315), // naranja quemado
  Color(0xFFC08A2E), // oro
  Color(0xFF558B2F), // oliva
  Color(0xFF2E7D32), // verde
  Color(0xFF00838F), // turquesa
  Color(0xFF1565C0), // azul
  Color(0xFF4527A0), // índigo
  Color(0xFF7B1FA2), // morado
  Color(0xFF5D4037), // café
  Color(0xFF37474F), // grafito
];

/// Límites de la luz en el modo personalizado: por debajo el color se
/// vuelve negro, por encima los títulos se quedan sin contraste.
const _luzMin = 0.22;
const _luzMax = 0.50;

/// Abre el asistente para elegir el color del grupo. Devuelve el color
/// elegido, o null si se cancela.
Future<Color?> elegirColorGrupo(
  BuildContext context, {
  required Ocasion ocasion,
  required Color inicial,
}) =>
    showDialog<Color>(
      context: context,
      builder: (_) => DialogoColorGrupo(ocasion: ocasion, inicial: inicial),
    );

class DialogoColorGrupo extends StatefulWidget {
  final Ocasion ocasion;
  final Color inicial;

  const DialogoColorGrupo({super.key, required this.ocasion, required this.inicial});

  @override
  State<DialogoColorGrupo> createState() => _DialogoColorGrupoState();
}

class _DialogoColorGrupoState extends State<DialogoColorGrupo> {
  late HSLColor _hsl = _acotar(HSLColor.fromColor(widget.inicial));

  Color get _color => _hsl.toColor();

  HSLColor _acotar(HSLColor c) => c.withLightness(c.lightness.clamp(_luzMin, _luzMax));

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    final escala = escalaDe(_color);
    return Theme(
      data: temaGlass(escala),
      child: AlertDialog(
        title: Text(t.colorTitulo),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _vistaPrevia(t, escala),
                const SizedBox(height: 16),
                Text(t.colorSugeridos, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final c in coloresSugeridos)
                      _Muestra(
                        color: c,
                        elegida: c.toARGB32() == _color.toARGB32(),
                        onTap: () => setState(() => _hsl = _acotar(HSLColor.fromColor(c))),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(t.colorPersonalizado, style: const TextStyle(fontWeight: FontWeight.bold)),
                _deslizador(
                  etiqueta: t.colorTono,
                  valor: _hsl.hue,
                  min: 0,
                  max: 360,
                  pista: [
                    for (double h = 0; h <= 360; h += 60)
                      HSLColor.fromAHSL(1, h, _hsl.saturation, _hsl.lightness).toColor(),
                  ],
                  onCambio: (v) => setState(() => _hsl = _hsl.withHue(v)),
                ),
                _deslizador(
                  etiqueta: t.colorLuz,
                  valor: _hsl.lightness,
                  min: _luzMin,
                  max: _luzMax,
                  pista: [_hsl.withLightness(_luzMin).toColor(), _hsl.withLightness(_luzMax).toColor()],
                  onCambio: (v) => setState(() => _hsl = _hsl.withLightness(v)),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancelar)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: legibleSobreBlanco(escala.shade600)),
            onPressed: () => Navigator.pop(context, _color),
            child: Text(t.colorUsar),
          ),
        ],
      ),
    );
  }

  /// Un pedazo del grupo tal como se va a ver: el mismo fondo y el mismo
  /// vidrio, no una muestra plana. Es lo que deja juzgar el color de verdad.
  Widget _vistaPrevia(Textos t, MaterialColor escala) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 140,
        child: FondoTematico(
          tematica: Tematica.ninguna,
          ocasion: widget.ocasion,
          colorPersonal: _color,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: GlassCard(
              color: escala,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(t.colorVistaPrevia, style: tituloGlass(escala)),
                  GlassButton(
                    color: escala.shade600,
                    onPressed: () {},
                    icon: Icons.card_giftcard,
                    label: t.colorGrupo,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _deslizador({
    required String etiqueta,
    required double valor,
    required double min,
    required double max,
    required List<Color> pista,
    required ValueChanged<double> onCambio,
  }) {
    return Row(
      children: [
        SizedBox(width: 56, child: Text(etiqueta, style: const TextStyle(fontSize: 13))),
        Expanded(
          // La pista pinta el recorrido del color para que se vea a dónde
          // lleva el deslizador antes de moverlo.
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  gradient: LinearGradient(colors: pista),
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                  thumbColor: Colors.white,
                  overlayColor: Colors.black12,
                ),
                child: Slider(value: valor.clamp(min, max), min: min, max: max, onChanged: onCambio),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Muestra extends StatelessWidget {
  final Color color;
  final bool elegida;
  final VoidCallback onTap;

  const _Muestra({required this.color, required this.elegida, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: elegida,
      label: hexDe(color),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: elegida ? Colors.black87 : Colors.white, width: elegida ? 3 : 2),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
          ),
          child: elegida ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
        ),
      ),
    );
  }
}
