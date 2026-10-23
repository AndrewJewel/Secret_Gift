import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santa_secreto/condiciones.dart';
import 'package:santa_secreto/l10n/app_localizations.dart';

Widget _app(Widget hijo) => MaterialApp(
      locale: const Locale('es'),
      supportedLocales: const [Locale('en'), Locale('es')],
      localizationsDelegates: Textos.localizationsDelegates,
      home: Scaffold(body: hijo),
    );

void main() {
  test('al día solo con las dos versiones vigentes', () {
    expect(condicionesAlDia(null), isFalse);
    expect(condicionesAlDia({'terminos': {'version': versionTerminos}}), isFalse);
    expect(
        condicionesAlDia({
          'terminos': {'version': versionTerminos},
          'privacidad': {'version': versionPrivacidad},
        }),
        isTrue);
  });

  testWidgets('las casillas solo avisan «ambas» con las dos marcadas', (tester) async {
    final avisos = <bool>[];
    await tester.pumpWidget(_app(CasillasCondiciones(onCambio: avisos.add)));
    await tester.tap(find.text('Acepto las Condiciones de uso'));
    await tester.pump();
    expect(avisos.last, isFalse);
    await tester.tap(find.text('Autorizo el tratamiento de mis datos según la Política de privacidad'));
    await tester.pump();
    expect(avisos.last, isTrue);
  });

  testWidgets('el diálogo no deja aceptar hasta marcar las dos y luego guarda', (tester) async {
    var aceptado = 0;
    await tester.pumpWidget(_app(DialogoCondiciones(
      aceptar: () async => aceptado++,
      salir: () async {},
    )));
    final boton = find.widgetWithText(FilledButton, 'Aceptar');
    expect(tester.widget<FilledButton>(boton).onPressed, isNull);
    await tester.tap(find.text('Acepto las Condiciones de uso'));
    await tester.tap(find.text('Autorizo el tratamiento de mis datos según la Política de privacidad'));
    await tester.pump();
    expect(tester.widget<FilledButton>(boton).onPressed, isNotNull);
    await tester.tap(boton);
    await tester.pump();
    expect(aceptado, 1);
  });
}
