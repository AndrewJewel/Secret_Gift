import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'glass.dart';
import 'l10n/app_localizations.dart';

// Fecha de entrega de regalos: solo el día, sin hora. La cuenta atrás llega
// a cero a las 00:00 de ese día en la zona de quien la mira.
// Diseño: locker/docs/superpowers/specs/2026-10-28-fecha-entrega-design.md

/// "YYYY-MM-DD" → medianoche local de ese día, o null.
DateTime? fechaDeTexto(String? texto) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(texto ?? '');
  if (m == null) return null;
  return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
}

String textoDeFecha(DateTime f) =>
    '${f.year.toString().padLeft(4, '0')}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}';

/// Días de calendario entre hoy y la entrega (0 = hoy, negativo = ya pasó).
/// En UTC para que un cambio de horario no deje un día de 23 horas.
int diasHasta(DateTime entrega, DateTime ahora) => DateTime.utc(entrega.year, entrega.month, entrega.day)
    .difference(DateTime.utc(ahora.year, ahora.month, ahora.day))
    .inDays;

/// La etiqueta de Mis grupos, o null si ya pasó.
String? etiquetaEntrega(Textos t, DateTime entrega, DateTime ahora) => switch (diasHasta(entrega, ahora)) {
      < 0 => null,
      0 => t.entregaEtiquetaHoy,
      1 => t.entregaEtiquetaManana,
      final d => t.entregaEtiquetaDias(d),
    };

/// El campo de crear y editar grupo: abre el calendario del sistema, desde
/// hoy hasta dentro de dos años, y deja quitar la fecha.
class CampoFechaEntrega extends StatelessWidget {
  final DateTime? valor;
  final MaterialColor color;
  final ValueChanged<DateTime?> onCambio;

  const CampoFechaEntrega({super.key, required this.valor, required this.color, required this.onCambio});

  Future<void> _elegir(BuildContext context) async {
    final hoy = DateUtils.dateOnly(DateTime.now());
    final elegida = await showDatePicker(
      context: context,
      // Una fecha guardada que ya pasó no puede ser la inicial: el
      // calendario solo deja elegir desde hoy.
      initialDate: valor != null && !valor!.isBefore(hoy) ? valor : hoy,
      firstDate: hoy,
      lastDate: hoy.add(const Duration(days: 730)),
    );
    if (elegida != null) onCambio(elegida);
  }

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    final idioma = Localizations.localeOf(context).toLanguageTag();
    return GlassCard(
      color: color,
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: ListTile(
        leading: Icon(Icons.event, color: color.shade800),
        title: Text(t.fechaEntregaCampo, style: TextStyle(color: color.shade900, fontSize: 13)),
        subtitle: Text(
          valor == null ? t.fechaEntregaElegir : DateFormat.yMMMMEEEEd(idioma).format(valor!),
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        trailing: valor == null
            ? null
            : IconButton(
                icon: Icon(Icons.close, color: color.shade800),
                tooltip: t.fechaEntregaQuitar,
                onPressed: () => onCambio(null),
              ),
        onTap: () => _elegir(context),
      ),
    );
  }
}

/// La tarjeta de la pantalla del grupo: antes del día, días, horas, minutos y
/// segundos hasta las 00:00; el día, «¡Hoy es el intercambio!»; después, una
/// línea discreta. El reloj se puede inyectar para los tests.
class TarjetaCuentaAtras extends StatefulWidget {
  final DateTime entrega;
  final MaterialColor color;
  final DateTime Function() reloj;

  const TarjetaCuentaAtras({super.key, required this.entrega, required this.color, this.reloj = DateTime.now});

  @override
  State<TarjetaCuentaAtras> createState() => _TarjetaCuentaAtrasState();
}

class _TarjetaCuentaAtrasState extends State<TarjetaCuentaAtras> {
  Timer? _tic;

  @override
  void initState() {
    super.initState();
    _ajustarTic();
  }

  @override
  void didUpdateWidget(TarjetaCuentaAtras viejo) {
    super.didUpdateWidget(viejo);
    // El organizador puede cambiar la fecha con la pantalla abierta.
    if (viejo.entrega != widget.entrega) _ajustarTic();
  }

  /// Solo hace falta redibujar mientras falta tiempo.
  void _ajustarTic() {
    _tic?.cancel();
    _tic = widget.entrega.isAfter(widget.reloj())
        ? Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}))
        : null;
  }

  @override
  void dispose() {
    _tic?.cancel();
    super.dispose();
  }

  /// Cada número en su ficha, como un reloj de tablero (variante B del
  /// mockup del 28-oct): el vidrio de la tarjeta, un punto más tintado.
  Widget _cifra(String valor, String unidad) => Container(
        constraints: const BoxConstraints(minWidth: 52),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: widget.color.shade100.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: widget.color.shade200, width: 1.5),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(valor,
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: widget.color.shade900,
                  fontFeatures: const [FontFeature.tabularFigures()])),
          Text(unidad, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    final ahora = widget.reloj();
    final dias = diasHasta(widget.entrega, ahora);
    final fechaLarga =
        DateFormat.MMMMEEEEd(Localizations.localeOf(context).toLanguageTag()).format(widget.entrega);
    final Widget contenido;
    if (dias > 0) {
      final r = widget.entrega.difference(ahora);
      String dos(int n) => n.toString().padLeft(2, '0');
      contenido = Column(children: [
        Text(t.entregaEn, style: TextStyle(color: widget.color.shade900, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        // Las unidades son iguales en es y en: d, h, min, s.
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _cifra('${r.inDays}', 'd'),
          _cifra(dos(r.inHours % 24), 'h'),
          _cifra(dos(r.inMinutes % 60), 'min'),
          _cifra(dos(r.inSeconds % 60), 's'),
        ]),
        const SizedBox(height: 4),
        Text(fechaLarga, style: const TextStyle(color: Colors.black54)),
      ]);
    } else if (dias == 0) {
      contenido = Text(t.entregaHoy,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: widget.color.shade900));
    } else {
      contenido = Text(t.entregaFue(fechaLarga), style: const TextStyle(color: Colors.black54));
    }
    return GlassCard(
      color: widget.color,
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SizedBox(width: double.infinity, child: Center(child: contenido)),
    );
  }
}
