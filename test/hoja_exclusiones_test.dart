import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santa_secreto/hoja_exclusiones.dart';
import 'package:santa_secreto/l10n/app_localizations.dart';
import 'package:santa_secreto/marca.dart';

Widget _envoltorio(Widget hijo) => MaterialApp(
      locale: const Locale('es'),
      supportedLocales: const [Locale('en'), Locale('es')],
      localizationsDelegates: Textos.localizationsDelegates,
      home: Scaffold(body: hijo),
    );

const _tres = <Persona>[
  (id: 'a', nombre: 'Ana'),
  (id: 'b', nombre: 'Beto'),
  (id: 'c', nombre: 'Carla'),
];

bool _habilitada(WidgetTester tester, String nombre) => tester
    .widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, nombre))
    .onChanged != null;

void main() {
  testWidgets('título y solo los demás participantes', (tester) async {
    await tester.pumpWidget(_envoltorio(const HojaExclusiones(
        personaId: 'a', participantes: _tres, parejas: {}, color: rojoMarca)));
    expect(find.text('Excluir participante'), findsOneWidget);
    expect(find.widgetWithText(CheckboxListTile, 'Beto'), findsOneWidget);
    expect(find.widgetWithText(CheckboxListTile, 'Ana'), findsNothing);
  });

  testWidgets('en un grupo de 3, toda exclusión se bloquea', (tester) async {
    await tester.pumpWidget(_envoltorio(const HojaExclusiones(
        personaId: 'a', participantes: _tres, parejas: {}, color: rojoMarca)));
    expect(_habilitada(tester, 'Beto'), isFalse);
    expect(_habilitada(tester, 'Carla'), isFalse);
    expect(find.text('Haría imposible el sorteo'), findsNWidgets(2));
  });

  testWidgets('en 4, marcar a uno bloquea al otro que compartiría persona', (tester) async {
    const cuatro = <Persona>[..._tres, (id: 'd', nombre: 'Dani')];
    await tester.pumpWidget(_envoltorio(const HojaExclusiones(
        personaId: 'a', participantes: cuatro, parejas: {}, color: rojoMarca)));
    expect(_habilitada(tester, 'Beto'), isTrue);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Beto'));
    await tester.pump();
    // Ana–Beto y Ana–Carla dejarían a Ana solo con Dani: imposible.
    expect(_habilitada(tester, 'Carla'), isFalse);
    // La marcada siempre se puede desmarcar.
    expect(_habilitada(tester, 'Beto'), isTrue);
  });
}
