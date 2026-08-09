import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santa_secreto/l10n/app_localizations.dart';
import 'package:santa_secreto/pantalla_crear_cuenta.dart';

/// Callback vacía: estos tests prueban la pantalla, no la navegación.
/// Poder pasarla es justo la razón de que el destino no viva aquí dentro.
Future<void> _sinNavegar(BuildContext _, dynamic _) async {}

Widget _envoltorio(Widget hijo) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('es')],
      localizationsDelegates: Textos.localizationsDelegates,
      home: hijo,
    );

void main() {
  testWidgets('sin invitación muestra la frase gancho', (tester) async {
    await tester.pumpWidget(_envoltorio(PantallaCrearCuenta(alEntrar: _sinNavegar)));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Create your account to discover who sends you the secret gifts'),
        findsOneWidget);
  });

  testWidgets('con invitación muestra el grupo en vez de la frase', (tester) async {
    await tester.pumpWidget(_envoltorio(PantallaCrearCuenta(
        alEntrar: _sinNavegar, nombreGrupoInvitacion: 'Navidad Familia')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Navidad Familia'), findsOneWidget);
    expect(
        find.text(
            'Create your account to discover who sends you the secret gifts'),
        findsNothing);
  });

  testWidgets('tiene los tres campos y la casilla de idioma', (tester) async {
    await tester.pumpWidget(_envoltorio(PantallaCrearCuenta(alEntrar: _sinNavegar)));
    await tester.pumpAndSettle();
    expect(find.text('Nickname'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
  });
}
