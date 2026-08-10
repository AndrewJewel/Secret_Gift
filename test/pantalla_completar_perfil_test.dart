import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santa_secreto/l10n/app_localizations.dart';
import 'package:santa_secreto/pantalla_completar_perfil.dart';

/// Callback vacía: solo se prueba lo que la pantalla pinta y su validación
/// local. `completarPerfil` llama a Firebase Auth y no se ejerce aquí: eso
/// pediría dobles de FirebaseAuth, que es un refactor de producción fuera
/// de alcance.
Future<void> _sinNavegar(BuildContext _) async {}

Widget _envoltorio(Widget hijo) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('es')],
      localizationsDelegates: Textos.localizationsDelegates,
      home: hijo,
    );

void main() {
  testWidgets('muestra el título, el texto, los campos y el botón de guardar',
      (tester) async {
    await tester
        .pumpWidget(_envoltorio(PantallaCompletarPerfil(alCompletar: _sinNavegar)));
    await tester.pumpAndSettle();
    expect(find.text('One last step'), findsOneWidget);
    expect(
        find.text("Your account was created but your profile wasn't saved. "
            "Fill it in to continue."),
        findsOneWidget);
    expect(find.text('First name'), findsOneWidget);
    expect(find.text('Last name'), findsOneWidget);
    expect(find.text('4-digit PIN'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('guardar con campos vacíos avisa y no navega', (tester) async {
    var llamada = false;
    await tester.pumpWidget(_envoltorio(PantallaCompletarPerfil(alCompletar: (c) async {
      llamada = true;
    })));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('⚠️ Some required information is missing'), findsOneWidget);
    expect(llamada, isFalse);
  });
}
