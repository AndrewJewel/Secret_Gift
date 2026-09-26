// Solo para desarrollo: abre la pantalla de revelación con datos de ejemplo,
// sin sesión ni sorteo, para verla y capturarla en el navegador.
//
//   flutter build web -t tool/vista_revelacion.dart -o build/vista
//
// El despliegue compila lib/main.dart: esto nunca se publica.
import 'package:flutter/material.dart';
import 'package:santa_secreto/l10n/app_localizations.dart';
import 'package:santa_secreto/pantalla_secreta.dart';

void main() {
  final idioma = Uri.base.queryParameters['idioma'] == 'en' ? 'en' : 'es';
  final largo = Uri.base.queryParameters['largo'] == '1';
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale(idioma),
      supportedLocales: Textos.supportedLocales,
      localizationsDelegates: Textos.localizationsDelegates,
      // Encima de otra pantalla, como en la app: así se ve la flecha de volver.
      initialRoute: '/revelar',
      routes: {
        '/': (_) => const Scaffold(),
        '/revelar': (_) => PantallaSecreta(
          nombreGrupo: 'Oficina 2026',
          personas: 8,
          nombreAmigo: 'Ana María',
          deseosAmigo: largo
              ? 'Un libro de cocina italiana, una bufanda de lana gris, unos audífonos '
                    'inalámbricos, una planta pequeña para el escritorio y chocolate amargo.'
              : 'Un libro de cocina o una bufanda de lana',
        ),
      },
    ),
  );
}
