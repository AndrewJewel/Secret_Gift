import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santa_secreto/hoja_configuracion.dart';
import 'package:santa_secreto/l10n/app_localizations.dart';

Widget _envoltorio(Widget hijo) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('es')],
      localizationsDelegates: Textos.localizationsDelegates,
      // El Scaffold es lo que aporta el Material que DropdownButtonFormField
      // necesita. En producción lo pone showModalBottomSheet; aquí, que la hoja
      // se pinta suelta, lo pone el test. Mismo patrón que selector_idioma_test.
      home: Scaffold(body: hijo),
    );

void main() {
  testWidgets('ofrece idioma, cambiar PIN y cerrar sesión', (tester) async {
    await tester.pumpWidget(_envoltorio(
        HojaConfiguracion(alCerrarSesion: () async {})));
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Change my PIN'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('cerrar sesión llama a su callback', (tester) async {
    var llamada = false;
    await tester.pumpWidget(_envoltorio(
        HojaConfiguracion(alCerrarSesion: () async => llamada = true)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(llamada, isTrue);
  });
}
