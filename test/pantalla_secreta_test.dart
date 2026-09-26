import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:santa_secreto/l10n/app_localizations.dart';
import 'package:santa_secreto/pantalla_secreta.dart';

/// Con «reducir movimiento» la caja se abre al instante: la prueba no
/// depende de los tiempos de la animación.
Widget _envoltorio({required String deseos}) => MaterialApp(
      locale: const Locale('es'),
      supportedLocales: const [Locale('en'), Locale('es')],
      localizationsDelegates: Textos.localizationsDelegates,
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true, size: Size(390, 844)),
        child: PantallaSecreta(
          nombreGrupo: 'Oficina 2026',
          personas: 8,
          nombreAmigo: 'Ana María',
          deseosAmigo: deseos,
        ),
      ),
    );

void main() {
  // Sin red en las pruebas: las fuentes caen a la del sistema.
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('cerrada: no se ve el nombre hasta abrir la caja', (tester) async {
    await tester.pumpWidget(_envoltorio(deseos: 'Un libro'));
    await tester.pump();
    expect(find.text('Abrir mi caja'), findsOneWidget);
    expect(find.text('Ana María'), findsNothing);
  });

  testWidgets('al abrir aparecen el nombre y la lista de deseos', (tester) async {
    await tester.pumpWidget(_envoltorio(deseos: 'Un libro'));
    await tester.pump();
    await tester.tap(find.text('Abrir mi caja'));
    await tester.pump();
    expect(find.text('Ana María'), findsOneWidget);
    expect(find.text('Un libro'), findsOneWidget);
    expect(find.text('Listo'), findsOneWidget);
  });

  testWidgets('sin deseos dice «Sin sugerencias» en el idioma de la app', (tester) async {
    await tester.pumpWidget(_envoltorio(deseos: ''));
    await tester.pump();
    await tester.tap(find.text('Abrir mi caja'));
    await tester.pump();
    expect(find.text('Sin sugerencias'), findsOneWidget);
  });
}
