import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:santa_secreto/almacen_local.dart';
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
  setUp(() => SharedPreferences.setMockInitialValues({}));

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

  testWidgets(
      'abrir la hoja NO pide el permiso de avisos, y el interruptor sale apagado',
      (tester) async {
    // Aquí no hay Firebase inicializado, así que `estadoDelPermiso()` cae
    // en su `catch` y responde `notDetermined`. Eso es exactamente lo que
    // hace falta comprobar: la hoja se abre entera y sin errores leyendo
    // SOLO estado, sin pasar por `getToken()`, que es quien pedía el
    // permiso del navegador por su cuenta. Si `_leerEstadoAvisos` volviera
    // a llamar a `tokenDeEsteDispositivo()` sin la guarda del permiso,
    // esto seguiría pasando, pero en un navegador de verdad le saltaría el
    // cuadro del sistema a quien solo venía a cambiar el idioma.
    await marcarTokenPushEnServidor(true);
    await tester.pumpWidget(_envoltorio(
        HojaConfiguracion(alCerrarSesion: () async {})));
    await tester.pumpAndSettle();

    // Con el token registrado pero SIN permiso del sistema, apagado: hacen
    // falta las dos cosas (ver `avisosActivos` en push.dart).
    final interruptor =
        tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(interruptor.value, isFalse);
    expect(find.text('Notifications'), findsOneWidget);
  });
}
