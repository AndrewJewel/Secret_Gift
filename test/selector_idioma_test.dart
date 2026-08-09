import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santa_secreto/l10n/app_localizations.dart';
import 'package:santa_secreto/selector_idioma.dart';

Widget _envoltorio(Widget hijo) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('es')],
      localizationsDelegates: Textos.localizationsDelegates,
      home: Scaffold(body: hijo),
    );

void main() {
  testWidgets('la casilla muestra el idioma actual', (tester) async {
    await tester.pumpWidget(_envoltorio(const CampoIdioma()));
    await tester.pumpAndSettle();
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('la casilla ofrece los dos idiomas al desplegarse', (tester) async {
    await tester.pumpWidget(_envoltorio(const CampoIdioma()));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<Locale>));
    await tester.pumpAndSettle();
    expect(find.text('Español'), findsOneWidget);
  });

  testWidgets('el icono se dibuja', (tester) async {
    await tester.pumpWidget(_envoltorio(const IconoIdioma()));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.language), findsOneWidget);
  });
}
