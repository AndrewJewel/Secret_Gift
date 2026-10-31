import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santa_secreto/pantalla_editar_grupo.dart';

void main() {
  // 31-oct: al borrar un grupo, la pantalla de grupo vuelve a Mis grupos en
  // cuanto ve desaparecer el documento, y Editar —aún viva en su animación de
  // salida— hacía `pop` a ciegas al llegar la respuesta: cerraba Mis grupos y
  // dejaba la pila vacía (pantalla rosa).
  testWidgets('si otra pantalla ya la sacó de arriba, no cierra la de abajo', (tester) async {
    final navegador = GlobalKey<NavigatorState>();
    late BuildContext contextoEditar;
    await tester.pumpWidget(MaterialApp(navigatorKey: navegador, home: const Text('mis grupos')));
    navegador.currentState!.push(MaterialPageRoute(builder: (c) {
      contextoEditar = c;
      return const Text('editar');
    }));
    await tester.pumpAndSettle();

    navegador.currentState!.popUntil((r) => r.isFirst);
    await tester.pump(); // a mitad de la animación: Editar sigue montada
    cerrarSiSigueArriba(contextoEditar, 'eliminado');
    await tester.pumpAndSettle();

    expect(find.text('mis grupos'), findsOneWidget);
  });
}
