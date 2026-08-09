import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:santa_secreto/idioma.dart';
import 'package:santa_secreto/l10n/app_localizations.dart';
import 'package:santa_secreto/selector_idioma.dart';

Widget _envoltorio(Widget hijo) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('es')],
      localizationsDelegates: Textos.localizationsDelegates,
      home: Scaffold(body: hijo),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Idioma.cambiar() escribe en SharedPreferences y muta el ValueNotifier
  // estático Idioma.actual, que es global a todo el proceso de test. Sin
  // este aislamiento, el test que sí completa una selección dejaría el
  // idioma en español para los tests siguientes del archivo (o de la suite).
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => Idioma.actual.value = const Locale('en'));

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

  // Los dos tests anteriores solo comprueban el dibujado: no fallarían si
  // se borrara el onChanged de CampoIdioma. Este completa una selección de
  // verdad y comprueba el efecto real del widget, que es llamar a
  // Idioma.cambiar(locale). Nótese que la aserción va contra
  // Idioma.actual.value, no contra lo que se ve en pantalla: el locale
  // visible viene fijo del `locale:` del MaterialApp de prueba, no de
  // Idioma.actual.
  testWidgets('elegir Español en la casilla cambia Idioma.actual', (tester) async {
    await tester.pumpWidget(_envoltorio(const CampoIdioma()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<Locale>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Español').last);
    await tester.pumpAndSettle();

    expect(Idioma.actual.value.languageCode, 'es');
  });
}
