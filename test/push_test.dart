import 'package:flutter_test/flutter_test.dart';
import 'package:santa_secreto/push.dart';

/// Pruebas de `debeAbrirseElAviso`, la decisión pura detrás del
/// deduplicado de `alTocarAviso` (ver `push.dart`). No hace falta
/// simular nada de FCM: la función solo compara identificadores de
/// mensaje, así que se prueba con strings sueltos.
void main() {
  group('debeAbrirseElAviso', () {
    test('sin nada visto todavía, se abre', () {
      expect(debeAbrirseElAviso('msg-1', null), isTrue);
    });

    test('el MISMO mensaje que ya se abrió, NO se vuelve a abrir', () {
      // Es el caso real que hay que cubrir: `getInitialMessage()` y
      // `onMessageOpenedApp` informando los dos del mismo mensaje que
      // despertó la app en frío.
      expect(debeAbrirseElAviso('msg-1', 'msg-1'), isFalse);
    });

    test(
      'dos avisos DISTINTOS del mismo grupo se abren los dos '
      '(el deduplicado es por mensaje, no por código de grupo)',
      () {
        // Es justo lo que fallaba en la ronda anterior: los tres avisos de
        // esta app (reemplazo, sorteo, chat) comparten `codigo` de grupo,
        // así que un deduplicado por código descartaría en silencio un
        // segundo aviso legítimo del mismo grupo. `debeAbrirseElAviso` no
        // recibe el código en absoluto — solo compara identificadores de
        // mensaje — así que dos mensajes distintos, aunque sean del mismo
        // grupo, se abren los dos.
        const idPrimerAviso = 'msg-reemplazo-1';
        const idSegundoAviso = 'msg-sorteo-2'; // mismo grupo, otro mensaje

        expect(debeAbrirseElAviso(idPrimerAviso, null), isTrue);
        // Tras "abrir" el primero, se recuerda su id (así lo hace
        // `alTocarAviso`) y se evalúa el segundo contra ESE id.
        expect(debeAbrirseElAviso(idSegundoAviso, idPrimerAviso), isTrue);
      },
    );

    test('sin identificador de mensaje, se abre igual', () {
      // FCM no garantiza `messageId` siempre. Ante la duda, se abre: es
      // preferible abrir de más que dejar un aviso legítimo sin abrir
      // nunca.
      expect(debeAbrirseElAviso(null, 'msg-1'), isTrue);
      expect(debeAbrirseElAviso(null, null), isTrue);
    });
  });
}
