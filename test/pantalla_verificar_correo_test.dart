import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santa_secreto/l10n/app_localizations.dart';
import 'package:santa_secreto/pantalla_verificar_correo.dart';

/// Callback vacía: solo se prueba lo que la pantalla pinta, no a dónde
/// lleva verificar. Los tres botones de aquí llaman a Firebase Auth
/// (`correoVerificado`, `mandarVerificacion`, `salir`) y por eso no se
/// pulsan en este test: hacerlo pediría dobles de FirebaseAuth, que es un
/// refactor de producción fuera de alcance.
Future<void> _sinNavegar(BuildContext _) async {}

Widget _envoltorio(Widget hijo) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('es')],
      localizationsDelegates: Textos.localizationsDelegates,
      home: hijo,
    );

void main() {
  testWidgets('muestra el título, el texto y los tres botones', (tester) async {
    await tester
        .pumpWidget(_envoltorio(PantallaVerificarCorreo(alVerificar: _sinNavegar)));
    await tester.pumpAndSettle();
    expect(find.text('Check your inbox'), findsOneWidget);
    expect(
        find.text('We sent you a link. Tap it to confirm your email, then come back here.'),
        findsOneWidget);
    expect(find.text("I've confirmed it"), findsOneWidget);
    expect(find.text('Send it again'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });
}
