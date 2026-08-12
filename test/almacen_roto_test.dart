import 'package:flutter_test/flutter_test.dart';
import 'package:santa_secreto/almacen_roto.dart';
import 'package:santa_secreto/funciones.dart';

/// Pruebas de la protección contra bucles de recarga (ver el comentario
/// largo en `pantalla_verificar_correo.dart`). El acceso real a
/// `sessionStorage` vive en `recarga_pagina_web.dart`, que solo compila y
/// se ejecuta en web (`dart:js_interop` no existe en el VM que usa
/// `flutter test`) — así que aquí se prueba la parte que SÍ es Dart puro y
/// corre en cualquier plataforma: qué errores cuentan como "almacén roto"
/// y, sobre todo, que una sesión ya recargada NUNCA vuelve a recargar por
/// mucho que el error siga pareciendo el mismo.
void main() {
  group('esFalloDeAlmacenRoto', () {
    test('reconoce el fallo marcado por correoVerificado() (reload:)', () {
      final error = FuncionError(
        'unknown',
        'auth_desconocido',
        'reload: An unknown error occurred: Error: Database is closing/hidden',
      );
      expect(esFalloDeAlmacenRoto(error), isTrue);
    });

    test('reconoce el fallo marcado por tokenActual() (token:)', () {
      final error = FuncionError(
        'unknown',
        'auth_desconocido',
        'token: cualquier cosa que diga el navegador',
      );
      expect(esFalloDeAlmacenRoto(error), isTrue);
    });

    test(
      'NO se fija en el texto exacto del navegador, solo en la marca propia',
      () {
        // A propósito un texto totalmente distinto al de hoy: el punto de
        // esFalloDeAlmacenRoto() es no depender de la cadena que use un
        // navegador u otro, así que cualquier mensaje vale con tal de que
        // lleve la marca.
        final error = FuncionError(
          'unknown',
          'auth_desconocido',
          'reload: mensaje futuro inventado',
        );
        expect(esFalloDeAlmacenRoto(error), isTrue);
      },
    );

    test(
      'rechaza un auth_desconocido que no vino de reload()/getIdToken()',
      () {
        final error = FuncionError('unknown', 'auth_desconocido', 'sin marcar');
        expect(esFalloDeAlmacenRoto(error), isFalse);
      },
    );

    test('rechaza un FuncionError con otra clave, aunque lleve la marca', () {
      final error = FuncionError(
        'unavailable',
        'sin_conexion',
        'reload: no hay red',
      );
      expect(esFalloDeAlmacenRoto(error), isFalse);
    });

    test('rechaza cualquier error que no sea FuncionError', () {
      expect(esFalloDeAlmacenRoto(Exception('reload: algo')), isFalse);
      expect(esFalloDeAlmacenRoto('reload: texto suelto'), isFalse);
    });
  });

  group('debeRecargarPorAlmacenRoto — protección contra bucles', () {
    test(
      'recarga si el error encaja y esta sesión no ha recargado todavía',
      () {
        expect(
          debeRecargarPorAlmacenRoto(
            esFalloDeAlmacen: true,
            yaRecargadaEstaSesion: false,
          ),
          isTrue,
        );
      },
    );

    test('NO recarga una segunda vez, aunque el error siga encajando', () {
      // Este es el caso que de verdad importa: si tras la recarga vuelve a
      // fallar con el mismo perfil de error, no hay que recargar otra vez
      // — hay que enseñar el error de siempre. Una app en bucle de
      // recargas es peor que el fallo que esto arregla.
      expect(
        debeRecargarPorAlmacenRoto(
          esFalloDeAlmacen: true,
          yaRecargadaEstaSesion: true,
        ),
        isFalse,
      );
    });

    test(
      'no recarga si el error no es del almacén, haya recargado antes o no',
      () {
        expect(
          debeRecargarPorAlmacenRoto(
            esFalloDeAlmacen: false,
            yaRecargadaEstaSesion: false,
          ),
          isFalse,
        );
        expect(
          debeRecargarPorAlmacenRoto(
            esFalloDeAlmacen: false,
            yaRecargadaEstaSesion: true,
          ),
          isFalse,
        );
      },
    );
  });
}
