import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:santa_secreto/invitacion_pendiente.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('sin invitación guardada devuelve null', () async {
    expect(await leerInvitacion(), isNull);
  });

  test('guarda y recupera código y nombre', () async {
    await guardarInvitacion('RJV2-HN8R', 'Navidad Familia');
    final i = await leerInvitacion();
    expect(i!.codigo, 'RJV2-HN8R');
    expect(i.nombreGrupo, 'Navidad Familia');
  });

  test('borrar la deja en null', () async {
    await guardarInvitacion('RJV2-HN8R', 'Navidad Familia');
    await borrarInvitacion();
    expect(await leerInvitacion(), isNull);
  });

  test('un grupo sin nombre se recupera con cadena vacía, no null', () async {
    await guardarInvitacion('ABCD-1234', '');
    final i = await leerInvitacion();
    expect(i!.codigo, 'ABCD-1234');
    expect(i.nombreGrupo, '');
  });
}
