import 'package:firebase_messaging/firebase_messaging.dart'
    show AuthorizationStatus;
import 'package:flutter_test/flutter_test.dart';
import 'package:santa_secreto/push.dart';

/// Pruebas de las dos decisiones PURAS de `push.dart`:
/// `debeAbrirseElAviso` (el deduplicado de `alTocarAviso`) y
/// `avisosActivos` (lo que enseña el interruptor de Configuración). Ni una
/// ni otra tocan FCM a propósito, así que se prueban con valores sueltos,
/// sin simular nada de Firebase.
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

  group('avisosActivos', () {
    // Los DOS defectos del cliente que llegaron hasta la revisión final
    // vivían en esta decisión, y los dos hacían decir ENCENDIDO al
    // interruptor con el servidor vacío o el permiso denegado. La decisión
    // está sacada a esta función precisamente para poder fijarlos aquí.

    test('permiso concedido y token en el servidor: activos', () {
      expect(avisosActivos(AuthorizationStatus.authorized, true), isTrue);
    });

    test('provisional (el permiso silencioso de iOS) también cuenta', () {
      // `provisional` entrega los avisos, solo que sin sonido. Tratarlo
      // como "denegado" apagaría el interruptor a quien sí los recibe.
      expect(avisosActivos(AuthorizationStatus.provisional, true), isTrue);
    });

    test(
      'DEFECTO 1: permiso NO concedido, aunque el dispositivo tuviera token',
      () {
        // El interruptor leía `getToken() != null`, que significa "este
        // dispositivo puede tener token", no "los avisos funcionan". Con
        // el permiso denegado o sin decidir no llega ni uno, diga lo que
        // diga el token.
        expect(avisosActivos(AuthorizationStatus.denied, true), isFalse);
        expect(avisosActivos(AuthorizationStatus.notDetermined, true), isFalse);
      },
    );

    test(
      'DEFECTO 2: permiso concedido pero el SERVIDOR no tiene el token',
      () {
        // Los tres caminos silenciosos: el token cambió y nadie lo
        // reconcilió, `guardarTokenPush` falló por red justo después de
        // aceptar, o se cambió de cuenta en este mismo dispositivo. En los
        // tres el permiso sigue concedido y no llega ningún aviso.
        expect(avisosActivos(AuthorizationStatus.authorized, false), isFalse);
        expect(avisosActivos(AuthorizationStatus.provisional, false), isFalse);
      },
    );

    test('ni permiso ni token: apagados', () {
      expect(avisosActivos(AuthorizationStatus.denied, false), isFalse);
    });
  });

  group('permisoConcedido', () {
    // Es la puerta que decide si `reconciliarAvisos` y
    // `tokenDeEsteDispositivo` siguen adelante, y por tanto lo que impide
    // que se llame a `getToken()` —que PIDE EL PERMISO ÉL MISMO— sin
    // tenerlo ya concedido.
    test('authorized y provisional sí; el resto no', () {
      expect(permisoConcedido(AuthorizationStatus.authorized), isTrue);
      expect(permisoConcedido(AuthorizationStatus.provisional), isTrue);
      expect(permisoConcedido(AuthorizationStatus.denied), isFalse);
      expect(permisoConcedido(AuthorizationStatus.notDetermined), isFalse);
    });
  });
}
