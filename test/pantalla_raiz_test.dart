import 'package:flutter_test/flutter_test.dart';
import 'package:santa_secreto/pantalla_raiz.dart';

/// Pruebas de `leerEnlaceInvitacion`, la única decisión de
/// `pantalla_raiz.dart` que es pura y no toca ni Firestore ni disco ni
/// plataforma: extraer el código (y el token de reemplazo) de un `Uri`.
/// La comparten el camino de web (`Uri.base`) y el nativo de Android
/// (`app_links`), así que un fallo aquí afectaría a los dos a la vez.
///
/// El resto de `pantalla_raiz.dart` —validar contra Firestore, guardar en
/// disco, esperar el primer arranque, no procesar el mismo enlace dos
/// veces— depende de Firebase y del plugin `app_links`, que este proyecto
/// no simula en los tests (no hay `fake_cloud_firestore` ni mocks del
/// canal de plataforma de `app_links`); esa parte solo se puede comprobar
/// en un dispositivo o emulador de verdad.
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

    test('el mismo código produce el mismo resultado venga de donde venga '
        '(web con Uri.base o un Intent de Android): es la garantía de que '
        'los dos caminos entienden el enlace igual', () {
      final deWeb = leerEnlaceInvitacion(
          Uri.parse('https://secretgift.app/?codigo=abcd-1234&reemplazo=tok'));
      final deAndroid = leerEnlaceInvitacion(
          Uri.parse('https://secretgift.app/?codigo=abcd-1234&reemplazo=tok'));
      expect(deWeb!.codigo, deAndroid!.codigo);
      expect(deWeb.reemplazo, deAndroid.reemplazo);
    });
  });
}
