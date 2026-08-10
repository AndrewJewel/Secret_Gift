import 'package:flutter_test/flutter_test.dart';
import 'package:santa_secreto/auth.dart';

void main() {
  group('claveDeAuth', () {
    test('traduce los códigos que la app sabe mostrar', () {
      expect(claveDeAuth('invalid-email'), 'correo_invalido');
      expect(claveDeAuth('email-already-in-use'), 'correo_en_uso');
      expect(claveDeAuth('weak-password'), 'password_debil');
      expect(claveDeAuth('password-does-not-meet-requirements'), 'password_debil');
      expect(claveDeAuth('invalid-credential'), 'password_incorrecta');
      expect(claveDeAuth('wrong-password'), 'password_incorrecta');
      expect(claveDeAuth('user-not-found'), 'password_incorrecta');
      expect(claveDeAuth('too-many-requests'), 'demasiados_intentos');
      expect(claveDeAuth('network-request-failed'), 'sin_conexion');
      expect(claveDeAuth('requires-recent-login'), 'requiere_reautenticacion');
      expect(claveDeAuth('unauthorized-domain'), 'dominio_no_autorizado');
    });

    test('user-not-found y wrong-password dan la MISMA clave', () {
      // Distinguirlas le diría a cualquiera si un correo está registrado.
      // Es el oráculo de existencia que esta migración viene a cerrar.
      expect(claveDeAuth('user-not-found'), claveDeAuth('wrong-password'));
    });

    test('un código desconocido cae en una clave genérica', () {
      expect(claveDeAuth('algo-que-firebase-invente-mañana'), 'auth_desconocido');
    });
  });
}
