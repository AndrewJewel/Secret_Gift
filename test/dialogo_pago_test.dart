import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santa_secreto/dialogo_pago.dart';
import 'package:santa_secreto/l10n/app_localizations.dart';

void main() {
  testWidgets('muestra el precio y «Pagar y crear» solo con la casilla marcada', (tester) async {
    bool? resultado;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: Textos.localizationsDelegates,
      supportedLocales: Textos.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => resultado = await DialogoPago.mostrar(context, precio: '4,99 USD'),
          child: const Text('abrir'),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.textContaining('4,99 USD'), findsOneWidget);

    final boton = find.widgetWithText(FilledButton, 'Pagar y crear');
    expect(tester.widget<FilledButton>(boton).onPressed, isNull);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    expect(tester.widget<FilledButton>(boton).onPressed, isNotNull);

    await tester.tap(boton);
    await tester.pumpAndSettle();
    expect(resultado, isTrue);
  });
}
