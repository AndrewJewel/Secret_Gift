import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'l10n/app_localizations.dart';

/// Avatares: la foto de la persona en un grupo normal, o la imagen del
/// personaje en un grupo temático.
///
/// La imagen se reduce a 256px EN EL PROPIO DISPOSITIVO antes de salir de
/// aquí. Una foto de celular pesa varios megas; así queda en unos 20KB, y
/// subir 20KB por un canal de texto (base64 dentro de la llamada a la
/// Cloud Function) no le duele a nadie.
const _ladoMaximo = 256.0;
const _calidadJpeg = 85;

/// Abre la galería, reduce la imagen y la devuelve en base64 lista para
/// mandarla al servidor. Devuelve null si la persona cancela.
Future<String?> elegirAvatarBase64() async {
  final archivo = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: _ladoMaximo,
    maxHeight: _ladoMaximo,
    imageQuality: _calidadJpeg,
  );
  if (archivo == null) return null;
  return base64Encode(await archivo.readAsBytes());
}

/// Muestra el avatar de un participante en la lista. Si no tiene imagen,
/// cae al ícono de siempre — el avatar nunca es obligatorio.
class AvatarParticipante extends StatelessWidget {
  final String? url;
  final MaterialColor color;
  final double radio;
  final bool yaTieneAmigo;

  const AvatarParticipante({
    super.key,
    required this.url,
    required this.color,
    this.radio = 20,
    this.yaTieneAmigo = false,
  });

  @override
  Widget build(BuildContext context) {
    final tieneImagen = url != null && url!.isNotEmpty;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: radio,
          backgroundColor: color.shade200,
          // errorBuilder de Image no aplica a backgroundImage, así que la
          // imagen va como hijo recortado: si la URL falla, se ve el ícono.
          child: tieneImagen
              ? ClipOval(
                  child: Image.network(
                    url!,
                    width: radio * 2,
                    height: radio * 2,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Icon(Icons.person, color: Colors.white, size: radio),
                  ),
                )
              : Icon(Icons.person, color: Colors.white, size: radio),
        ),
        if (yaTieneAmigo)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
              child: const CircleAvatar(
                radius: 8,
                backgroundColor: Colors.green,
                child: Icon(Icons.check, color: Colors.white, size: 11),
              ),
            ),
          ),
      ],
    );
  }
}

/// Botón redondo para elegir imagen dentro de un formulario. Muestra lo
/// que ya se eligió, o un marcador con la etiqueta de la temática.
class SelectorAvatar extends StatelessWidget {
  /// Imagen recién elegida, en base64 (todavía sin subir).
  final String? base64;

  /// Imagen ya guardada en el servidor, si la hay.
  final String? urlActual;
  final String etiqueta;
  final MaterialColor color;
  final VoidCallback onElegir;
  final VoidCallback? onQuitar;

  const SelectorAvatar({
    super.key,
    required this.base64,
    required this.etiqueta,
    required this.color,
    required this.onElegir,
    this.urlActual,
    this.onQuitar,
  });

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    final bytes = base64 != null ? base64Decode(base64!) : null;
    final tieneAlgo = bytes != null || (urlActual != null && urlActual!.isNotEmpty);

    return Column(
      children: [
        // El área tocable cubre el círculo completo (72px de radio visual),
        // muy por encima del mínimo de 44px.
        InkWell(
          onTap: onElegir,
          customBorder: const CircleBorder(),
          child: CircleAvatar(
            radius: 44,
            backgroundColor: color.shade100,
            child: bytes != null
                ? ClipOval(child: Image.memory(bytes, width: 88, height: 88, fit: BoxFit.cover))
                : (urlActual != null && urlActual!.isNotEmpty)
                    ? ClipOval(
                        child: Image.network(urlActual!,
                            width: 88, height: 88, fit: BoxFit.cover))
                    : Icon(Icons.add_a_photo_outlined, color: color.shade700, size: 30),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onElegir,
          icon: Icon(tieneAlgo ? Icons.edit_outlined : Icons.add_photo_alternate_outlined,
              size: 18, color: color.shade700),
          label: Text(tieneAlgo ? t.avatarCambiar : etiqueta,
              style: TextStyle(color: color.shade700, fontWeight: FontWeight.w600)),
        ),
        if (tieneAlgo && onQuitar != null)
          TextButton.icon(
            onPressed: onQuitar,
            icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade700),
            label: Text(t.avatarQuitar, style: TextStyle(color: Colors.red.shade700)),
          ),
      ],
    );
  }
}
