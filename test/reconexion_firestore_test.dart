import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santa_secreto/reconexion_firestore.dart';

/// Pruebas de "cuándo toca reconectar Firestore al volver de segundo
/// plano" (ver el comentario largo en `reconexion_firestore.dart` para el
/// porqué de cada decisión). Lo único de Firebase de verdad que toca este
/// archivo es `forzarReconexionFirestore()` sin haber inicializado Firebase
/// —justo el caso de `flutter test`—, para comprobar que de verdad nunca
/// lanza. Todo lo demás se prueba sustituyendo la reconexión real por un
/// contador (`reconectar:`), así no hace falta un doble de Firestore —que
/// este proyecto no tiene, ver el comentario sobre dobles de FirebaseAuth
/// en `pantalla_raiz.dart`— para probar CUÁNDO se dispara.
void main() {
  // Simula un mensaje de plataforma en el canal `flutter/lifecycle`, la
  // misma vía por la que el sistema operativo avisa de verdad. Es el mismo
  // truco que usa la propia batería de pruebas de Flutter para
  // `AppLifecycleListener` (`app_lifecycle_listener_test.dart`): usarlo aquí
  // y no llamar directamente a `TestWidgetsFlutterBinding.
  // handleAppLifecycleStateChanged` —que es `@protected`— evita un aviso del
  // analizador por tocar un miembro protegido desde fuera de su jerarquía.
  Future<void> cambiarCicloDeVidaA(AppLifecycleState estado) async {
    final mensaje = const StringCodec().encodeMessage(estado.toString());
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage('flutter/lifecycle', mensaje, (_) {});
  }

  setUp(() {
    // Arranca en `resumed`, que es el estado inicial normal de una app en
    // primer plano — el mismo punto de partida en cada test.
    TestWidgetsFlutterBinding.instance.readTestInitialLifecycleStateFromNativeWindow();
  });

  tearDown(() {
    // Sin esto, la escucha que crea cada test se queda viva para el
    // siguiente: el segundo test heredaría también la del primero y
    // contaría el doble.
    olvidarEscuchaParaPruebas();
  });

  group('observarReconexionFirestoreAlVolver', () {
    testWidgets('NO reconecta en el arranque en frío', (tester) async {
      var veces = 0;
      observarReconexionFirestoreAlVolver(reconectar: () => veces++);

      // La app ya nace en `resumed`: no hubo ningún `paused` del que volver.
      expect(veces, 0);
    });

    testWidgets(
      'reconecta al volver de segundo plano (tras pasar por paused)',
      (tester) async {
        var veces = 0;
        observarReconexionFirestoreAlVolver(reconectar: () => veces++);

        // Se va de fondo y se congela.
        await cambiarCicloDeVidaA(AppLifecycleState.paused);
        expect(veces, 0);

        // Vuelve: AHORA sí toca reconectar. La app real pasa por `hidden`
        // e `inactive` de camino a `resumed`; se pide `resumed` directo y
        // el propio binding genera los intermedios (mismo mecanismo que usa
        // el sistema operativo real), disparando `onRestart` en el momento
        // exacto en que deja `paused`.
        await cambiarCicloDeVidaA(AppLifecycleState.resumed);
        expect(veces, 1);
      },
    );

    testWidgets(
      'no reconecta dos veces por la misma vuelta a primer plano',
      (tester) async {
        var veces = 0;
        observarReconexionFirestoreAlVolver(reconectar: () => veces++);

        await cambiarCicloDeVidaA(AppLifecycleState.paused);
        await cambiarCicloDeVidaA(AppLifecycleState.resumed);
        expect(veces, 1);

        // Perder el foco sin llegar a fondo (p.ej. un diálogo del sistema)
        // y recuperarlo no es "volver de segundo plano": no debe reconectar
        // otra vez.
        await cambiarCicloDeVidaA(AppLifecycleState.inactive);
        await cambiarCicloDeVidaA(AppLifecycleState.resumed);
        expect(veces, 1);
      },
    );

    testWidgets('no hace nada en web: no registra ninguna escucha', (tester) async {
      // No se puede conmutar `kIsWeb` en un test de VM, así que esto no
      // prueba la rama web en sí —eso solo se ve compilando y ejecutando de
      // verdad a web, o corriendo `flutter test --platform chrome`—, pero sí
      // dejar constancia, por si alguna vez deja de compilar contra web, de
      // que la función existe y no revienta al llamarla en la plataforma en
      // la que SÍ corren estos tests.
      expect(() => observarReconexionFirestoreAlVolver(reconectar: () {}), returnsNormally);
    });
  });

  group('forzarReconexionFirestore', () {
    test('nunca lanza, ni siquiera sin Firebase inicializado', () async {
      // `flutter test` no inicializa Firebase: acceder a
      // `FirebaseFirestore.instance` lanza `[core/no-app]` de verdad. Esto
      // comprueba justo la garantía que importa —llamarla desde un callback
      // de ciclo de vida, del que nadie espera el resultado, no puede tumbar
      // la app pase lo que pase— sin necesitar Firebase de verdad.
      await expectLater(forzarReconexionFirestore(), completes);
    });
  });
}
