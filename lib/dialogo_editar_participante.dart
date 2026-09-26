import 'package:flutter/material.dart';

import 'avatar.dart';
import 'l10n/app_localizations.dart';
import 'tematica.dart';

/// Lo que cambió en el diálogo. Un campo en null es «sin cambios».
class CambiosParticipante {
  final String? nombre;

  /// Imagen nueva en base64, o `''` para quitarla (así lo entiende
  /// `cambiarAvatar` en el servidor).
  final String? avatarBase64;

  /// Deseos nuevos (puede ser `''` para vaciarlos).
  final String? deseos;

  const CambiosParticipante({this.nombre, this.avatarBase64, this.deseos});
}

/// «Editar participante»: la foto (o la imagen del personaje), el nombre y
/// la lista de deseos.
///
/// - Foto: el organizador la de cualquiera; cada participante, la suya.
/// - Nombre: solo el organizador ([puedeEditarNombre]); `editarParticipante`
///   lo exige en el servidor.
/// - Deseos: solo los propios y solo antes del sorteo. Son privados (solo los
///   ve quien te regala), así que el campo aparece únicamente si llegan
///   [deseos]; null = no se muestra.
///
/// No llama al servidor: devuelve con `Navigator.pop` un [CambiosParticipante]
/// (o null si se cancela) y quien lo abrió guarda solo lo que cambió.
class DialogoEditarParticipante extends StatefulWidget {
  final String nombre;
  final String? avatarUrl;
  final bool puedeEditarNombre;
  final String? deseos;
  final Tematica tematica;
  final MaterialColor color;

  const DialogoEditarParticipante({
    super.key,
    required this.nombre,
    required this.avatarUrl,
    required this.puedeEditarNombre,
    this.deseos,
    required this.tematica,
    required this.color,
  });

  @override
  State<DialogoEditarParticipante> createState() => _DialogoEditarParticipanteState();
}

class _DialogoEditarParticipanteState extends State<DialogoEditarParticipante> {
  late final _nombre = TextEditingController(text: widget.nombre);
  late final _deseos = TextEditingController(text: widget.deseos ?? '');
  String? _nuevaImagen;
  bool _quitada = false;

  @override
  void dispose() {
    _nombre.dispose();
    _deseos.dispose();
    super.dispose();
  }

  Future<void> _elegir() async {
    final base64 = await elegirAvatarBase64();
    if (base64 == null || !mounted) return;
    setState(() {
      _nuevaImagen = base64;
      _quitada = false;
    });
  }

  void _guardar() {
    final nombre = _nombre.text.trim();
    final deseos = _deseos.text.trim();
    Navigator.pop(
      context,
      CambiosParticipante(
        nombre: widget.puedeEditarNombre && nombre.isNotEmpty && nombre != widget.nombre
            ? nombre
            : null,
        avatarBase64: _nuevaImagen ?? (_quitada ? '' : null),
        deseos: widget.deseos != null && deseos != widget.deseos!.trim() ? deseos : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    return AlertDialog(
      title: Text(t.editarParticipanteTitulo),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectorAvatar(
              base64: _nuevaImagen,
              urlActual: _quitada ? null : widget.avatarUrl,
              etiqueta: widget.tematica.etiquetaImagen(t),
              color: widget.color,
              onElegir: _elegir,
              onQuitar: () => setState(() {
                _nuevaImagen = null;
                _quitada = true;
              }),
            ),
            if (widget.puedeEditarNombre) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _nombre,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: widget.tematica.etiquetaNombre(t)),
                onSubmitted: (_) => _guardar(),
              ),
            ],
            if (widget.deseos != null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _deseos,
                maxLines: 4,
                minLines: 2,
                maxLength: 1000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: t.registroDeseos,
                  helperText: widget.tematica.usaPersonajes
                      ? t.registroDeseosAyudaPersonaje
                      : t.registroDeseosAyudaNormal,
                  helperMaxLines: 3,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancelar)),
        FilledButton(onPressed: _guardar, child: Text(t.guardar)),
      ],
    );
  }
}
