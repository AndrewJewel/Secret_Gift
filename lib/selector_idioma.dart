import 'package:flutter/material.dart';

import 'glass.dart';
import 'idioma.dart';
import 'l10n/app_localizations.dart';

String _nombre(Textos t, Locale l) =>
    l.languageCode == 'en' ? t.idiomaIngles : t.idiomaEspanol;

/// Casilla de idioma para el formulario de registro. Es la primera
/// pantalla de la app, así que tiene que poder cambiarse ahí mismo: quien
/// no entienda inglés no llegaría a ningún otro sitio.
class CampoIdioma extends StatelessWidget {
  const CampoIdioma({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    final actual = Localizations.localeOf(context);
    return DropdownButtonFormField<Locale>(
      initialValue: Idioma.soportados
          .firstWhere((l) => l.languageCode == actual.languageCode),
      decoration: InputDecoration(
        labelText: t.idioma,
        prefixIcon: Icon(Icons.language, color: colorNeutro.shade700),
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white70,
      ),
      items: [
        for (final locale in Idioma.soportados)
          DropdownMenuItem<Locale>(value: locale, child: Text(_nombre(t, locale))),
      ],
      onChanged: (locale) {
        if (locale != null) Idioma.cambiar(locale);
      },
    );
  }
}
