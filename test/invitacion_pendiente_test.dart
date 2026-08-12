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

  test('un código nuevo no está consumido', () async {
    expect(await invitacionYaConsumida('RJV2-HN8R'), isFalse);
  });

  test('marcar un código lo deja como consumido', () async {
    await marcarInvitacionConsumida('RJV2-HN8R');
    expect(await invitacionYaConsumida('RJV2-HN8R'), isTrue);
  });

  test('marcar un código no afecta a los demás', () async {
    await marcarInvitacionConsumida('RJV2-HN8R');
    expect(await invitacionYaConsumida('ABCD-1234'), isFalse);
  });

  test('varios códigos consumidos conviven', () async {
    await marcarInvitacionConsumida('RJV2-HN8R');
    await marcarInvitacionConsumida('ABCD-1234');
    expect(await invitacionYaConsumida('RJV2-HN8R'), isTrue);
    expect(await invitacionYaConsumida('ABCD-1234'), isTrue);
  });

  test('marcar dos veces el mismo código no lo duplica', () async {
    await marcarInvitacionConsumida('RJV2-HN8R');
    await marcarInvitacionConsumida('RJV2-HN8R');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('invitaciones_consumidas'), ['RJV2-HN8R']);
  });

  test('guarda y recupera el token de reemplazo junto al resto', () async {
    await guardarInvitacion('RJV2-HN8R', 'Navidad Familia', 'token-abc123');
    final i = await leerInvitacion();
    expect(i!.codigo, 'RJV2-HN8R');
    expect(i.reemplazo, 'token-abc123');
  });

  test('sin token de reemplazo, la invitación lo recupera como null', () async {
    await guardarInvitacion('RJV2-HN8R', 'Navidad Familia');
    final i = await leerInvitacion();
    expect(i!.reemplazo, isNull);
  });

  test('la marca de consumida sobrevive a borrar la invitación', () async {
    // Es justo el caso que importa: en web la URL con ?codigo= sigue ahí
    // tras recargar, así que borrar la invitación no basta para que esa
    // persona no vuelva a entrar al mismo grupo.
    await guardarInvitacion('RJV2-HN8R', 'Navidad Familia');
    await borrarInvitacion();
    await marcarInvitacionConsumida('RJV2-HN8R');
    expect(await leerInvitacion(), isNull);
    expect(await invitacionYaConsumida('RJV2-HN8R'), isTrue);
  });
}
