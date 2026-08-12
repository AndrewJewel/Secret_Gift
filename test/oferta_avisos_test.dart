import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:santa_secreto/almacen_local.dart';
import 'package:santa_secreto/l10n/app_localizations.dart';
import 'package:santa_secreto/oferta_avisos.dart';

/// Pantalla mínima que reproduce el punto exacto donde se llama a
/// `ofrecerAvisosSiHaceFalta` en las tres pantallas de cuenta: un botón
/// que la invoca con su propio `context`. No hace falta ni Firebase ni
/// navegación real hacia otra pantalla de destino para probar el
/// contrato que importa aquí: cuándo se marca y cuándo se enseña.
Widget _envoltorio() => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('es')],
      localizationsDelegates: Textos.localizationsDelegates,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => ofrecerAvisosSiHaceFalta(context),
            child: const Text('ir'),
          ),
        ),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('si no se había preguntado, enseña la pantalla de permiso',
      (tester) async {
    await tester.pumpWidget(_envoltorio());
    await tester.tap(find.text('ir'));
    await tester.pumpAndSettle();
    expect(find.text('Yes, let me know'), findsOneWidget);
  });

  testWidgets(
      'la marca queda puesta ANTES de que la persona toque nada de la pantalla de permiso',
      (tester) async {
    // Es justo la garantía que pide el brief de la Tarea 8: si la pestaña
    // se cerrara con la pantalla de permiso a medias en el aire —sin
    // llegar a tocar «Sí» ni «Ahora no»—, un arranque nuevo no debe volver
    // a preguntar. Aquí se simula ese "a medias": se deja la pantalla de
    // permiso abierta (nunca se toca nada) y se comprueba que la marca ya
    // quedó escrita en disco de todos modos.
    await tester.pumpWidget(_envoltorio());
    await tester.tap(find.text('ir'));
    await tester.pumpAndSettle();
    expect(find.text('Yes, let me know'), findsOneWidget,
        reason: 'la pantalla de permiso sigue abierta, nadie tocó nada');
    expect(await yaSePreguntoPorAvisos(), isTrue,
        reason: 'pero la marca ya se puso, antes de enseñarla');
  });

  testWidgets('si ya se había preguntado, no enseña la pantalla de permiso',
      (tester) async {
    await marcarPreguntadoPorAvisos();
    await tester.pumpWidget(_envoltorio());
    await tester.tap(find.text('ir'));
    await tester.pumpAndSettle();
    expect(find.text('Yes, let me know'), findsNothing);
  });
}
