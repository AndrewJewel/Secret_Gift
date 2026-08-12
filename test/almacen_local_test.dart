import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:santa_secreto/almacen_local.dart';

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
}
