import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santa_secreto/pantalla_registro.dart';

/// Prueba de `reportarFalloDeEscucha` (ver su comentario largo en
/// `pantalla_registro.dart`): que un fallo de las escuchas en vivo del
/// grupo o de los participantes deje rastro de verdad, por el canal de
/// errores no capturados de Flutter, en vez de desaparecer en un
/// `onError: (_) {}` mudo como pasaba antes.
///
/// No se prueba disparando un `snapshots().listen()` de Firestore de
/// verdad —este proyecto no tiene un doble de Firestore, ver el comentario
/// sobre dobles de FirebaseAuth en `pantalla_raiz.dart`—, así que esto
/// prueba la función que los dos `onError` de `initState` llaman, no la
/// suscripción entera. Que las dos la llamen de verdad, con el error real
/// del stream, solo se puede comprobar apagando la red de un dispositivo o
/// congelando la app de fondo — no hay forma honesta de fingir eso aquí.
void main() {
  group('reportarFalloDeEscucha', () {
    late FlutterExceptionHandler? original;
    FlutterErrorDetails? capturado;

    setUp(() {
      original = FlutterError.onError;
      capturado = null;
      FlutterError.onError = (details) => capturado = details;
    });

    tearDown(() {
      FlutterError.onError = original;
    });

    test('reporta el error y la pila por el canal de errores de Flutter', () {
      final error = Exception('el índice que falta, o lo que sea');
      final pila = StackTrace.current;

      reportarFalloDeEscucha('grupo', error, pila);

      expect(capturado, isNotNull);
      expect(capturado!.exception, same(error));
      expect(capturado!.stack, same(pila));
    });

    test('identifica de cuál de las dos escuchas vino, en el contexto', () {
      reportarFalloDeEscucha('participantes', Exception('x'), StackTrace.current);

      expect(capturado!.context.toString(), contains('participantes'));
    });

    test('no lanza ni deja de reportar aunque no haya mensaje en el error', () {
      // Un error sin `toString()` informativo (p.ej. un objeto cualquiera,
      // no una excepción) no debe impedir que el reporte llegue: es
      // justo el tipo de fallo raro que antes desaparecía sin dejar rastro.
      expect(
        () => reportarFalloDeEscucha('grupo', Object(), StackTrace.current),
        returnsNormally,
      );
      expect(capturado, isNotNull);
    });
  });
}
