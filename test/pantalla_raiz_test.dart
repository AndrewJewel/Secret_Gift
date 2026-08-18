import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:santa_secreto/pantalla_raiz.dart';

/// Pruebas de las dos piezas de `pantalla_raiz.dart` que son puras y no
/// dependen de Firestore, disco ni plataforma:
///
/// - `leerEnlaceInvitacion`: extraer el código (y el token de reemplazo)
///   de un `Uri`. La comparten el camino de web (`Uri.base`) y el nativo
///   de Android (`app_links`).
/// - `HacerUnaVezConExito`: el mecanismo que serializa la captura de un
///   enlace nativo cuando llega por los dos caminos de `app_links` casi a
///   la vez, y que solo marca una clave como resuelta si el trabajo salió
///   bien. Es justo la pieza que falló en la ronda 1 de revisión —dos
///   fallos reales, no hipotéticos: una carrera que dejaba "crear cuenta"
///   sin el nombre del grupo, y una marca puesta ANTES de saber si el
///   guardado había ido bien— así que aquí se prueba con un `trabajo` de
///   mentira, sin necesitar Firebase para nada.
///
/// El resto —validar contra Firestore, guardar en disco, esperar el
/// primer arranque, decidir si el enlace nativo debe navegar o dejar que
/// `_arrancar()` lo haga— depende de Firebase (`usuarioActual`, leído sin
/// condición alguna dentro de `_arrancar()`) y del canal de plataforma de
/// `app_links`. Esta app no tiene ningún doble de `FirebaseAuth` ni de
/// Firestore —ver el comentario de `pantalla_completar_perfil_test.dart`,
/// que ya declaró ese tipo de mock "un refactor de producción fuera de
/// alcance"— así que montar uno solo para esta pantalla sería una
/// excepción al criterio que ya se sigue en el resto del proyecto. Esa
/// parte —en concreto, que el handler de `uriLinkStream` NO vuelva a
/// tocar la pila cuando el enlace es el de arranque— solo se puede
/// comprobar en un dispositivo o emulador de verdad, con logs.
void main() {
  group('leerEnlaceInvitacion', () {
    test('sin ?codigo=, no hay enlace de invitación', () {
      expect(leerEnlaceInvitacion(Uri.parse('https://secretgift.app/')), isNull);
    });

    test('con ?codigo=, se extrae en mayúsculas', () {
      final enlace =
          leerEnlaceInvitacion(Uri.parse('https://secretgift.app/?codigo=abcd-1234'));
      expect(enlace!.codigo, 'ABCD-1234');
      expect(enlace.reemplazo, isNull);
    });

    test('recorta espacios del código', () {
      final enlace = leerEnlaceInvitacion(
          Uri.parse('https://secretgift.app/?codigo=%20ABCD-1234%20'));
      expect(enlace!.codigo, 'ABCD-1234');
    });

    test('?codigo= vacío no cuenta como invitación', () {
      expect(leerEnlaceInvitacion(Uri.parse('https://secretgift.app/?codigo=')), isNull);
    });

    test('trae también el token de reemplazo, sin tocarlo', () {
      final enlace = leerEnlaceInvitacion(Uri.parse(
          'https://secretgift.app/?codigo=ABCD-1234&reemplazo=token-abc123'));
      expect(enlace!.codigo, 'ABCD-1234');
      expect(enlace.reemplazo, 'token-abc123');
    });

    test('sin &reemplazo=, el token queda null', () {
      final enlace =
          leerEnlaceInvitacion(Uri.parse('https://secretgift.app/?codigo=ABCD-1234'));
      expect(enlace!.reemplazo, isNull);
    });

    test(
      'la misma invitación produce el mismo resultado aunque cambie el '
      'orden de los parámetros o las mayúsculas del código (un Intent de '
      'Android no tiene por qué llegar formateado igual que Uri.base en '
      'web): es la garantía de que los dos caminos entienden el enlace '
      'igual, no solo que la función sea determinista consigo misma',
      () {
        final deWeb = leerEnlaceInvitacion(
            Uri.parse('https://secretgift.app/?codigo=abcd-1234&reemplazo=tok'));
        final deAndroid = leerEnlaceInvitacion(
            Uri.parse('https://secretgift.app/?reemplazo=tok&codigo=ABCD-1234'));
        expect(deWeb!.codigo, deAndroid!.codigo);
        expect(deWeb.reemplazo, deAndroid.reemplazo);
      },
    );
  });

  group('HacerUnaVezConExito', () {
    test('sin nada previo, ejecuta el trabajo y devuelve su resultado', () async {
      final vez = HacerUnaVezConExito<Uri>();
      final resultado = await vez.ejecutar(Uri.parse('https://x/'), () async => true);
      expect(resultado, isTrue);
    });

    test(
      'dos llamadas para la MISMA clave casi a la vez comparten el mismo '
      'trabajo en curso, no lo repiten — es el fallo que dejaba "crear '
      'cuenta" sin el nombre del grupo: el segundo camino leía el disco '
      'antes de que el primero terminara de escribirlo',
      () async {
        final vez = HacerUnaVezConExito<Uri>();
        final uri = Uri.parse('https://secretgift.app/?codigo=ABCD-1234');
        var arranques = 0;
        final enCurso = Completer<bool>();
        Future<bool> trabajo() {
          arranques++;
          return enCurso.future;
        }

        // Las dos llamadas se lanzan ANTES de que la primera termine —tal
        // cual pasa con `getInitialLink()` y el primer evento de
        // `uriLinkStream` en Android, casi a la vez y con el mismo Uri.
        final f1 = vez.ejecutar(uri, trabajo);
        final f2 = vez.ejecutar(uri, trabajo);

        expect(arranques, 1,
            reason: 'el segundo camino NO debe lanzar su propio trabajo');

        enCurso.complete(true);
        expect(await f1, isTrue);
        expect(await f2, isTrue,
            reason: 'el segundo camino ve el resultado real, no "no había nada"');
      },
    );

    test(
      'un intento fallido NO se marca: la misma clave puede reintentarse '
      'después — es el otro fallo de la ronda 1: marcar antes de saber si '
      'guardar salió bien dejaba un enlace bueno sin forma de '
      'reintentarse mientras la app seguía viva',
      () async {
        final vez = HacerUnaVezConExito<Uri>();
        final uri = Uri.parse('https://secretgift.app/?codigo=ABCD-1234');
        var intentos = 0;

        final r1 = await vez.ejecutar(uri, () async {
          intentos++;
          return false; // p.ej. sin conexión
        });
        expect(r1, isFalse);

        final r2 = await vez.ejecutar(uri, () async {
          intentos++;
          return true; // el reintento ahora sí tiene red
        });
        expect(intentos, 2, reason: 'el reintento SÍ debe ejecutarse, no darse por hecho');
        expect(r2, isTrue);
      },
    );

    test(
      'un intento con ÉXITO no se repite si la misma clave vuelve a llegar '
      '— la mutación que hizo el revisor (quitar esta guarda) deja los 85 '
      'tests de antes en verde; este test SÍ debe morir con ella',
      () async {
        final vez = HacerUnaVezConExito<Uri>();
        final uri = Uri.parse('https://secretgift.app/?codigo=ABCD-1234');
        var intentos = 0;

        final r1 = await vez.ejecutar(uri, () async {
          intentos++;
          return true;
        });
        expect(r1, isTrue);

        final r2 = await vez.ejecutar(uri, () async {
          intentos++;
          return true;
        });
        expect(intentos, 1, reason: 'NO debe repetirse: ya se resolvió con éxito');
        expect(r2, isFalse, reason: 'nada nuevo que guardar');
      },
    );

    test('claves DISTINTAS no se pisan entre sí', () async {
      final vez = HacerUnaVezConExito<Uri>();
      final r1 = await vez.ejecutar(Uri.parse('https://x/?codigo=AAAA'), () async => true);
      final r2 = await vez.ejecutar(Uri.parse('https://x/?codigo=BBBB'), () async => true);
      expect(r1, isTrue);
      expect(r2, isTrue, reason: 'una clave distinta es un enlace distinto: sí se procesa');
    });
  });
}
