import 'package:flutter_test/flutter_test.dart';
import 'package:santa_secreto/destino_inicial.dart';

void main() {
  test('sin sesión y sin invitación: a crear cuenta', () {
    expect(decidirDestino(haySesion: false, hayInvitacion: false),
        DestinoInicial.crearCuenta);
  });

  test('sin sesión pero con invitación: a crear cuenta, la invitación espera', () {
    expect(decidirDestino(haySesion: false, hayInvitacion: true),
        DestinoInicial.crearCuenta);
  });

  test('con sesión y sin invitación: a mis grupos', () {
    expect(decidirDestino(haySesion: true, hayInvitacion: false),
        DestinoInicial.misGrupos);
  });

  test('con sesión y con invitación: directo al grupo', () {
    expect(decidirDestino(haySesion: true, hayInvitacion: true),
        DestinoInicial.grupo);
  });
}
