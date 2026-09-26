import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santa_secreto/dialogo_editar_participante.dart';
import 'package:santa_secreto/l10n/app_localizations.dart';
import 'package:santa_secreto/marca.dart';
import 'package:santa_secreto/tematica.dart';

/// Monta un botón que abre el diálogo y lo abre. Devuelve una función que
/// lee lo que el diálogo devolvió al cerrarse.
Future<CambiosParticipante? Function()> _abrir(WidgetTester tester,
    {required bool puedeEditarNombre, String? avatarUrl, String? deseos}) async {
  CambiosParticipante? resultado;
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('es'),
    supportedLocales: const [Locale('en'), Locale('es')],
    localizationsDelegates: Textos.localizationsDelegates,
    home: Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          resultado = await showDialog<CambiosParticipante>(
            context: context,
            builder: (_) => DialogoEditarParticipante(
              nombre: 'Ana',
              avatarUrl: avatarUrl,
              puedeEditarNombre: puedeEditarNombre,
              deseos: deseos,
              tematica: Tematica.ninguna,
              color: rojoMarca,
            ),
          );
        },
        child: const Text('abrir'),
      ),
    ),
  ));
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return () => resultado;
}

Finder _campo(String etiqueta) => find.widgetWithText(TextField, etiqueta);

void main() {
  testWidgets('el organizador en otra fila: foto y nombre, sin deseos', (tester) async {
    await _abrir(tester, puedeEditarNombre: true);
    expect(find.text('Editar participante'), findsOneWidget);
    expect(find.text('Tu foto'), findsOneWidget);
    expect(_campo('Tu nombre'), findsOneWidget);
    expect(_campo('Lista de deseos'), findsNothing);
  });

  testWidgets('un participante en su fila: foto y deseos, sin nombre', (tester) async {
    await _abrir(tester, puedeEditarNombre: false, deseos: 'Un libro');
    expect(find.text('Tu foto'), findsOneWidget);
    expect(_campo('Tu nombre'), findsNothing);
    expect(_campo('Lista de deseos'), findsOneWidget);
    expect(find.text('Un libro'), findsOneWidget);
  });

  testWidgets('guardar sin tocar nada no cambia nada', (tester) async {
    final leer = await _abrir(tester, puedeEditarNombre: true, deseos: 'Un libro');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    final cambios = leer();
    expect(cambios, isNotNull);
    expect(cambios!.nombre, isNull);
    expect(cambios.avatarBase64, isNull);
    expect(cambios.deseos, isNull);
  });

  testWidgets('cambiar nombre y deseos, y quitar la foto', (tester) async {
    final leer = await _abrir(tester,
        puedeEditarNombre: true, avatarUrl: 'https://x/y.jpg', deseos: 'Un libro');
    await tester.enterText(_campo('Tu nombre'), 'Ana María');
    await tester.enterText(_campo('Lista de deseos'), 'Una bufanda');
    await tester.tap(find.text('Quitar imagen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    final cambios = leer()!;
    expect(cambios.nombre, 'Ana María');
    expect(cambios.deseos, 'Una bufanda');
    // Vacío = quitar la imagen (así lo entiende `cambiarAvatar`).
    expect(cambios.avatarBase64, '');
  });

  testWidgets('cancelar devuelve null', (tester) async {
    final leer = await _abrir(tester, puedeEditarNombre: true);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(leer(), isNull);
  });
}
