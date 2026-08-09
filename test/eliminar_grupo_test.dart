import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santa_secreto/l10n/app_localizations.dart';
import 'package:santa_secreto/pantalla_editar_grupo.dart';

Widget _envoltorio(Widget hijo) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('es')],
      localizationsDelegates: Textos.localizationsDelegates,
      home: hijo,
    );

void main() {
  testWidgets('el botón de eliminar no se activa hasta escribir el nombre',
      (tester) async {
    await tester.pumpWidget(_envoltorio(const DialogoEliminarGrupo(
        nombreGrupo: 'Navidad Familia')));
    await tester.pumpAndSettle();

    // Arranca inactivo: el PIN maestro ya no hace de freno previo, así que
    // este es el único paso que impide borrar un grupo sin querer.
    final boton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(boton.onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Navidad Famili');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Navidad Familia');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);
  });
}
