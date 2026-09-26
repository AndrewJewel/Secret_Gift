import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:santa_secreto/exclusiones.dart';

void main() {
  // Los mismos casos que functions/sorteo.test.js.
  final casos = (jsonDecode(File('test/fixtures/casos_exclusiones.json').readAsStringSync())
          as List)
      .cast<Map<String, dynamic>>();

  for (final caso in casos) {
    test('hayCadena: ${caso['nombre']}', () {
      final prohibidas = (caso['exclusiones'] as List)
          .map((p) => (p as List).cast<int>())
          .toList();
      expect(hayCadena(caso['n'] as int, prohibidas), caso['posible']);
    });
  }

  test('clavePareja ordena los ids', () {
    expect(clavePareja('b', 'a'), 'a|b');
  });

  test('parejasVigentes ignora a quien ya no está', () {
    expect(parejasVigentes(['a|b', 'a|z'], ['a', 'b']), {'a|b'});
  });

  test('hayCadenaConIds: sin parejas siempre se puede', () {
    expect(hayCadenaConIds(['a', 'b', 'c'], {}), isTrue);
    expect(hayCadenaConIds(['a', 'b', 'c'], {'a|b'}), isFalse);
  });
}
