import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santa_secreto/grupo_a_la_vista.dart';
import 'package:santa_secreto/push.dart';
import 'package:santa_secreto/ruta_observer.dart';

/// Pantallas mínimas, sin Firestore ni nada del chat real, que reproducen
/// el mismo ciclo de vida que `PantallaChat` delega en el mixin
/// `ConGrupoALaVista`. Sirven para probar ese ciclo de verdad —con un
/// `Navigator` real y el mismo `rutaObserver` global que usa la app— sin
/// necesitar Firebase.
class _PantallaDePrueba extends StatefulWidget {
  final String codigo;
  const _PantallaDePrueba(this.codigo);

  @override
  State<_PantallaDePrueba> createState() => _PantallaDePruebaState();
}

class _PantallaDePruebaState extends State<_PantallaDePrueba>
    with ConGrupoALaVista<_PantallaDePrueba> {
  @override
  String get codigoDeGrupoALaVista => widget.codigo;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const _OtraPantalla()),
              ),
              child: const Text('tapar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('salir'),
            ),
          ],
        ),
      );
}

class _OtraPantalla extends StatelessWidget {
  const _OtraPantalla();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('volver'),
        ),
      );
}

Widget _envoltorio() => MaterialApp(
      navigatorObservers: [rutaObserver],
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const _PantallaDePrueba('ABCD-1234')),
            ),
            child: const Text('entrar'),
          ),
        ),
      ),
    );

void main() {
  // `_grupoALaVista` vive en una variable global de `push.dart`: se limpia
  // entre pruebas para que una no herede el estado de la anterior.
  setUp(() => mirandoGrupo(null));

  testWidgets('declara el grupo al entrar, y NO antes', (tester) async {
    await tester.pumpWidget(_envoltorio());
    expect(grupoALaVistaParaPruebas, isNull);

    await tester.tap(find.text('entrar'));
    await tester.pumpAndSettle();
    expect(grupoALaVistaParaPruebas, 'ABCD-1234');
  });

  testWidgets(
      'tapada por otra pantalla sin destruirse, deja de estar a la vista, y vuelve al cerrarse la que tapaba',
      (tester) async {
    await tester.pumpWidget(_envoltorio());
    await tester.tap(find.text('entrar'));
    await tester.pumpAndSettle();
    expect(grupoALaVistaParaPruebas, 'ABCD-1234');

    await tester.tap(find.text('tapar'));
    await tester.pumpAndSettle();
    expect(grupoALaVistaParaPruebas, isNull,
        reason:
            'la pantalla sigue viva, solo tapada: dispose() no se llama aquí');

    await tester.tap(find.text('volver'));
    await tester.pumpAndSettle();
    expect(grupoALaVistaParaPruebas, 'ABCD-1234',
        reason: 'vuelve a estar a la vista tras cerrarse la que tapaba');
  });

  testWidgets('al salir de verdad (pop), dispose() lo retira', (tester) async {
    await tester.pumpWidget(_envoltorio());
    await tester.tap(find.text('entrar'));
    await tester.pumpAndSettle();
    expect(grupoALaVistaParaPruebas, 'ABCD-1234');

    await tester.tap(find.text('salir'));
    await tester.pumpAndSettle();
    expect(grupoALaVistaParaPruebas, isNull);
  });
}
