import 'package:flutter_test/flutter_test.dart';
import 'package:santa_secreto/mi_vinculo.dart';

void main() {
  test('organizador que todavía no se inscribió', () {
    final v = MiVinculo.desdeMapa({
      'codigo': 'ABCD-2345',
      'rol': 'organizador',
      'participanteId': null,
      'sorteado': false,
    });
    expect(v.esOrganizador, isTrue);
    expect(v.estoyDentro, isFalse);
  });

  test('participante inscrito', () {
    final v = MiVinculo.desdeMapa({
      'codigo': 'ABCD-2345',
      'rol': 'participante',
      'participanteId': 'x7k',
      'sorteado': true,
    });
    expect(v.esOrganizador, isFalse);
    expect(v.estoyDentro, isTrue);
    expect(v.participanteId, 'x7k');
    expect(v.sorteado, isTrue);
  });

  test('un participanteId vacío cuenta como no inscrito', () {
    // El servidor manda null, pero una respuesta vieja o un campo a medio
    // escribir podrían traer "". Tratarlo como "dentro" dejaría a esa
    // persona sin formulario de alta y sin poder hacer nada.
    final v = MiVinculo.desdeMapa({
      'codigo': 'ABCD-2345',
      'rol': 'participante',
      'participanteId': '',
      'sorteado': false,
    });
    expect(v.estoyDentro, isFalse);
  });
}
