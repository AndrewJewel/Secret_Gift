import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santa_secreto/marca.dart';

double _contrasteConBlanco(Color c) => 1.05 / (c.computeLuminance() + 0.05);

void main() {
  test('legibleSobreBlanco llega a AA (4.5:1) con cualquier color del grupo', () {
    for (final c in [oroMarca, Colors.orange.shade800, Colors.yellow, Colors.white, const Color(0xFF7FDBFF)]) {
      expect(_contrasteConBlanco(legibleSobreBlanco(c)), greaterThanOrEqualTo(4.5), reason: '$c');
    }
  });

  test('legibleSobreBlanco no toca un color que ya pasa', () {
    expect(legibleSobreBlanco(rojoMarca).toARGB32(), rojoMarca.toARGB32());
  });
}
