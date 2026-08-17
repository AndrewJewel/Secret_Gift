import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';
import 'package:santa_secreto/almacen_local.dart';

/// Sustituye al `SharedPreferencesStorePlatform` real por uno que revienta
/// en cuanto se le pide leer, para poder probar de verdad el `try/catch`
/// de `yaSePreguntoPorAvisos` — `SharedPreferences.setMockInitialValues`
/// (el que usan el resto de pruebas de este fichero) NUNCA lanza, así que
/// no sirve para esto: con él, los tests pasarían igual aunque se quitara
/// el `try/catch` entero.
class _AlmacenRotoDePrueba extends SharedPreferencesStorePlatform {
  @override
  Future<Map<String, Object>> getAllWithParameters(
      GetAllParameters parameters) {
    throw Exception('almacén roto, simulado en la prueba');
  }

  @override
  Future<bool> remove(String key) async => throw UnimplementedError();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      throw UnimplementedError();

  @override
  Future<bool> clear() async => throw UnimplementedError();

  @override
  Future<Map<String, Object>> getAll() async => throw UnimplementedError();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('yaSePreguntoPorAvisos / marcarPreguntadoPorAvisos', () {
    test('sin marca previa, todavía no se ha preguntado', () async {
      expect(await yaSePreguntoPorAvisos(), isFalse);
    });

    test('tras marcar, ya se ha preguntado', () async {
      await marcarPreguntadoPorAvisos();
      expect(await yaSePreguntoPorAvisos(), isTrue);
    });

    test('la marca es independiente del último grupo guardado', () async {
      // La clave de "ya se preguntó" no debe compartir espacio con la de
      // `guardarUltimoGrupo`: son dos recuerdos por dispositivo distintos.
      await guardarUltimoGrupo('ABCD-1234', 'navidad', '10', 'Familia');
      expect(await yaSePreguntoPorAvisos(), isFalse);
    });
  });

  group('avisosQueridosAqui / hayTokenPushEnServidor', () {
    test('sin nada guardado, las dos dicen que no', () async {
      // El valor de reserva de las dos es `false`, y es el seguro: nadie
      // registra avisos que no pidió, y el interruptor no dice "encendido"
      // sin constarle que el servidor tenga el token.
      expect(await avisosQueridosAqui(), isFalse);
      expect(await hayTokenPushEnServidor(), isFalse);
    });

    test('son marcas DISTINTAS y no se pisan entre ellas', () async {
      // La intención y el hecho tienen que poder discrepar: es justo lo
      // que pasa cuando alguien acepta los avisos y `guardarTokenPush`
      // falla por red. Quiere avisos (y por eso `reconciliarAvisos` los
      // arreglará en el arranque siguiente) pero el servidor no tiene su
      // token todavía.
      await marcarAvisosQueridos(true);
      expect(await avisosQueridosAqui(), isTrue);
      expect(await hayTokenPushEnServidor(), isFalse);

      await marcarTokenPushEnServidor(true);
      expect(await hayTokenPushEnServidor(), isTrue);
      expect(await avisosQueridosAqui(), isTrue);
    });

    test('cerrar sesión suelta el token pero conserva la intención',
        () async {
      // Reproduce lo que hace `soltarTokenDeEsteDispositivo`: la marca del
      // servidor se cae (ese token ya no cuelga de la cuenta que se va)
      // pero la intención sobrevive, porque es del DISPOSITIVO. Si se
      // borrara, la cuenta siguiente no registraría nada: la pantalla de
      // permiso no se vuelve a ofrecer nunca en este dispositivo.
      await marcarAvisosQueridos(true);
      await marcarTokenPushEnServidor(true);

      await marcarTokenPushEnServidor(false);

      expect(await hayTokenPushEnServidor(), isFalse);
      expect(await avisosQueridosAqui(), isTrue);
    });

    test('apagar el interruptor sí tumba la intención', () async {
      // Sin esto, apagar no se queda apagado: el permiso del sistema sigue
      // concedido, así que `reconciliarAvisos` volvería a registrar el
      // token en el arranque siguiente.
      await marcarAvisosQueridos(true);
      await marcarAvisosQueridos(false);
      expect(await avisosQueridosAqui(), isFalse);
    });

    test('ninguna de las dos se confunde con "ya se preguntó"', () async {
      await marcarPreguntadoPorAvisos();
      expect(await avisosQueridosAqui(), isFalse);
      expect(await hayTokenPushEnServidor(), isFalse);
    });
  });

  group('almacén roto', () {
    test('yaSePreguntoPorAvisos responde false, NO true, si el almacén falla',
        () async {
      // El valor de reserva importa: `true` ("ya se preguntó") apagaría
      // los avisos EN SILENCIO para siempre en ese dispositivo, porque la
      // pantalla de permiso nunca volvería a enseñarse. `false` hace que
      // se pregunte de más en vez de no preguntar nunca, y deja abierta
      // la posibilidad de que funcione: pedir el permiso y guardar el
      // token no dependen de `SharedPreferences`.
      SharedPreferencesStorePlatform.instance = _AlmacenRotoDePrueba();
      expect(await yaSePreguntoPorAvisos(), isFalse);
    });

    test('marcarPreguntadoPorAvisos no lanza aunque el almacén falle',
        () async {
      SharedPreferencesStorePlatform.instance = _AlmacenRotoDePrueba();
      await expectLater(marcarPreguntadoPorAvisos(), completes);
    });

    test('las marcas de avisos responden false y no lanzan si el almacén falla',
        () async {
      // Mismo criterio que arriba, y con la misma consecuencia: leer
      // `false` como reserva hace que el interruptor diga "apagado" y que
      // no se registre nada solo. Decir `true` sin saberlo registraría
      // avisos que nadie pidió o mostraría un interruptor mintiendo.
      SharedPreferencesStorePlatform.instance = _AlmacenRotoDePrueba();
      expect(await avisosQueridosAqui(), isFalse);
      expect(await hayTokenPushEnServidor(), isFalse);
      await expectLater(marcarAvisosQueridos(true), completes);
      await expectLater(marcarTokenPushEnServidor(true), completes);
    });
  });
}
