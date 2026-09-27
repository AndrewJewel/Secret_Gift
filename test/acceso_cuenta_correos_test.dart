import 'package:flutter_test/flutter_test.dart';
import 'package:santa_secreto/acceso_cuenta.dart';
import 'package:santa_secreto/funciones.dart';

void main() {
  test('verificación: si el servidor manda el código, no toca Firebase', () async {
    var respaldo = 0;
    final medio = await mandarVerificacion(
      llamar: (n, d) async => {'ok': true},
      respaldo: () async => respaldo++,
    );
    expect(medio, MedioVerificacion.codigo);
    expect(respaldo, 0);
  });

  test('verificación: si Resend falla, cae al enlace de Firebase', () async {
    var respaldo = 0;
    final medio = await mandarVerificacion(
      llamar: (n, d) async => throw FuncionError('unavailable', 'correo_no_enviado', 'x'),
      respaldo: () async => respaldo++,
    );
    expect(medio, MedioVerificacion.enlace);
    expect(respaldo, 1);
  });

  test('verificación: demasiados_correos se enseña, no se esquiva', () async {
    var respaldo = 0;
    await expectLater(
      mandarVerificacion(
        llamar: (n, d) async => throw FuncionError('resource-exhausted', 'demasiados_correos', 'x'),
        respaldo: () async => respaldo++,
      ),
      throwsA(isA<FuncionError>().having((e) => e.clave, 'clave', 'demasiados_correos')),
    );
    expect(respaldo, 0);
  });

  test('verificación: cuenta ya verificada', () async {
    final medio = await mandarVerificacion(
      llamar: (n, d) async => {'yaVerificado': true},
      respaldo: () async {},
    );
    expect(medio, MedioVerificacion.yaVerificado);
  });

  test('verificarCodigo: llama al servidor y luego refresca la sesión', () async {
    final llamadas = <String>[];
    await verificarCodigo('123456',
        llamar: (n, d) async {
          llamadas.add('$n:${d['codigo']}');
          return {'ok': true};
        },
        confirmar: () async {
          llamadas.add('confirmar');
          return true;
        });
    expect(llamadas, ['verificarCodigo:123456', 'confirmar']);
  });

  test('recuperación: cae a Firebase solo si Resend falla', () async {
    final respaldos = <String>[];
    await mandarRecuperacion(' a@x.com ',
        llamar: (n, d) async => {'ok': true}, respaldo: (c) async => respaldos.add(c));
    expect(respaldos, isEmpty);
    await mandarRecuperacion('a@x.com',
        llamar: (n, d) async => throw FuncionError('unavailable', 'sin_conexion', 'x'),
        respaldo: (c) async => respaldos.add(c));
    expect(respaldos, ['a@x.com']);
  });
}
