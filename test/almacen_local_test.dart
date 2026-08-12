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
  });
}
