import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santa_secreto/fecha_entrega.dart';
import 'package:santa_secreto/l10n/app_localizations.dart';

Widget _envolver(Widget hijo) => MaterialApp(
      locale: const Locale('es'),
      supportedLocales: const [Locale('en'), Locale('es')],
      localizationsDelegates: Textos.localizationsDelegates,
      home: Scaffold(body: hijo),
    );

void main() {
  test('texto y fecha van y vuelven; lo inválido es null', () {
    expect(fechaDeTexto('2026-12-24'), DateTime(2026, 12, 24));
    expect(textoDeFecha(DateTime(2026, 1, 5)), '2026-01-05');
    expect(fechaDeTexto(null), isNull);
    expect(fechaDeTexto('24/12/2026'), isNull);
  });

  test('días de calendario hasta la entrega', () {
    final entrega = DateTime(2026, 12, 24);
    expect(diasHasta(entrega, DateTime(2026, 12, 24, 23, 59)), 0);
    expect(diasHasta(entrega, DateTime(2026, 12, 23, 0, 1)), 1);
    expect(diasHasta(entrega, DateTime(2026, 12, 12, 10)), 12);
    expect(diasHasta(entrega, DateTime(2026, 12, 25)), -1);
  });

  testWidgets('la tarjeta: cuenta atrás, hoy y ya pasó', (tester) async {
    final entrega = DateTime(2026, 12, 24);
    await tester.pumpWidget(_envolver(TarjetaCuentaAtras(
        entrega: entrega, color: Colors.red, reloj: () => DateTime(2026, 12, 12, 19, 26, 50))));
    expect(find.text('Entrega de regalos en'), findsOneWidget);
    expect(find.text('11'), findsOneWidget); // días
    expect(find.text('04'), findsOneWidget); // horas
    expect(find.text('33'), findsOneWidget); // minutos
    expect(find.text('10'), findsOneWidget); // segundos

    await tester.pumpWidget(_envolver(TarjetaCuentaAtras(
        entrega: entrega, color: Colors.red, reloj: () => DateTime(2026, 12, 24, 9))));
    expect(find.text('¡Hoy es el intercambio! 🎁'), findsOneWidget);

    await tester.pumpWidget(_envolver(TarjetaCuentaAtras(
        entrega: entrega, color: Colors.red, reloj: () => DateTime(2026, 12, 26))));
    expect(find.textContaining('El intercambio fue el'), findsOneWidget);
  });
}
