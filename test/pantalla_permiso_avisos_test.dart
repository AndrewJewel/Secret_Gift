import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santa_secreto/l10n/app_localizations.dart';
import 'package:santa_secreto/pantalla_permiso_avisos.dart';

Widget _envoltorio(Widget hijo) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('es')],
      localizationsDelegates: Textos.localizationsDelegates,
      home: hijo,
    );

void main() {
  testWidgets('ofrece las dos salidas', (tester) async {
    await tester.pumpWidget(_envoltorio(PantallaPermisoAvisos(
      alAceptar: () async {},
      alSaltar: () {},
    )));
    await tester.pumpAndSettle();
    expect(find.text('Yes, let me know'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
  });

  testWidgets('«Ahora no» NO dispara el permiso', (tester) async {
    // Es LA prueba de esta pantalla. Si «Ahora no» acabara llamando al
    // navegador, el permiso quedaría quemado para siempre y la pantalla
    // no serviría para nada.
    var pidioPermiso = false;
    var salto = false;
    await tester.pumpWidget(_envoltorio(PantallaPermisoAvisos(
      alAceptar: () async => pidioPermiso = true,
      alSaltar: () => salto = true,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(pidioPermiso, isFalse);
    expect(salto, isTrue);
  });

  testWidgets('«Sí, avísame» sí lo dispara', (tester) async {
    var pidioPermiso = false;
    await tester.pumpWidget(_envoltorio(PantallaPermisoAvisos(
      alAceptar: () async => pidioPermiso = true,
      alSaltar: () {},
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, let me know'));
    await tester.pumpAndSettle();
    expect(pidioPermiso, isTrue);
  });
}
