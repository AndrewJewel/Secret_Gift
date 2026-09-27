import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santa_secreto/hoja_configuracion.dart';
import 'package:santa_secreto/l10n/app_localizations.dart';

Widget _app(Widget hijo) => MaterialApp(
      locale: const Locale('es'),
      supportedLocales: const [Locale('en'), Locale('es')],
      localizationsDelegates: Textos.localizationsDelegates,
      home: Scaffold(body: hijo),
    );

void main() {
  testWidgets('bloqueo: nombra cada grupo', (tester) async {
    await tester.pumpWidget(_app(const DialogoBloqueoEliminar(grupos: ['Oficina', 'Familia'])));
    expect(find.text('Debes nombrar un administrador en el grupo «Oficina» para borrar tu cuenta.'),
        findsOneWidget);
    expect(find.text('Debes nombrar un administrador en el grupo «Familia» para borrar tu cuenta.'),
        findsOneWidget);
  });

  testWidgets('confirmación: enumera lo que pasa en cada grupo', (tester) async {
    await tester.pumpWidget(_app(DialogoConfirmarEliminar(
      acciones: const [
        {'nombreGrupo': 'Colegio', 'accion': 'borrarGrupo'},
        {'nombreGrupo': 'Familia', 'accion': 'salir'},
        {'nombreGrupo': 'Oficina', 'accion': 'liberar'},
      ],
      password: TextEditingController(),
    )));
    expect(find.textContaining('«Colegio» se borrará: estás solo en ese grupo.'), findsOneWidget);
    expect(find.textContaining('Saldrás de «Familia».'), findsOneWidget);
    expect(find.textContaining('«Oficina» quedará libre'), findsOneWidget);
  });
}
