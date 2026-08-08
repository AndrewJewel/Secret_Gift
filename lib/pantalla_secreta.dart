import 'package:flutter/material.dart';

import 'glass.dart';
import 'l10n/app_localizations.dart';
import 'ocasion.dart';
import 'tematica.dart';

class PantallaSecreta extends StatefulWidget {
  final Ocasion ocasion;
  final Tematica tematica;
  final String nombre;
  final String nombreAmigo;
  final String deseosAmigo;

  const PantallaSecreta({
    super.key,
    required this.ocasion,
    required this.nombre,
    required this.nombreAmigo,
    required this.deseosAmigo,
    this.tematica = Tematica.ninguna,
  });

  @override
  State<PantallaSecreta> createState() => _PantallaSecretaState();
}

class _PantallaSecretaState extends State<PantallaSecreta> {
  bool revelado = false;

  MaterialColor get _color => widget.tematica.colorDe(widget.ocasion);

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    return Theme(
      data: temaGlass(_color),
      child: FondoTematico(
        tematica: widget.tematica,
        ocasion: widget.ocasion,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: GlassAppBar(title: Text(widget.nombre), color: _color),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: GlassCard(
                color: _color,
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t.secretaTitulo,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20, color: Colors.black87)),
                    const SizedBox(height: 30),
                    if (widget.nombreAmigo.isEmpty)
                      Text('⚠️ ${t.secretaSinSorteo}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.black87))
                    else if (!revelado)
                      GlassButton(
                        color: _color.shade600,
                        icon: Icons.visibility,
                        label: t.secretaRevelar,
                        onPressed: () => setState(() => revelado = true),
                      )
                    else
                      Column(
                        children: [
                          Text(widget.nombreAmigo,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: _color.shade800)),
                          const SizedBox(height: 20),
                          Text('🎁 ${t.secretaDesea(widget.deseosAmigo)}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.black54)),
                        ],
                      ),
                    const SizedBox(height: 40),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(t.salir, style: const TextStyle(color: Colors.black54)),
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
