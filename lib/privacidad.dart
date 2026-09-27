import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'idioma.dart';

/// La política vive en la web (secretgift.app/privacidad), en los dos
/// idiomas. Se abre en la página del idioma de la app.
Future<void> abrirPrivacidad() => launchUrl(
      Uri.parse(Idioma.actual.value.languageCode == 'en'
          ? 'https://secretgift.app/privacy'
          : 'https://secretgift.app/privacidad'),
      mode: LaunchMode.externalApplication,
    );

/// Enlace discreto a la política, para Configuración y el alta.
class EnlacePrivacidad extends StatelessWidget {
  final String texto;
  const EnlacePrivacidad({super.key, required this.texto});

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: abrirPrivacidad,
        child: Text(texto, style: const TextStyle(decoration: TextDecoration.underline)),
      );
}
