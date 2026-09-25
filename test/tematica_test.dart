import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santa_secreto/marca.dart';
import 'package:santa_secreto/ocasion.dart';
import 'package:santa_secreto/tematica.dart';

void main() {
  test('el color propio va y vuelve de Firestore sin perderse', () {
    const azul = Color(0xFF1565C0);
    expect(hexDe(azul), '#1565C0');
    expect(colorDesdeHex('#1565C0'), azul);
    expect(colorDesdeHex(''), isNull);
    expect(colorDesdeHex('rojo'), isNull);
  });

  test('el color propio solo manda sin temática', () {
    const verde = Color(0xFF2E7D32);
    expect(Tematica.ninguna.colorDe(Ocasion.amigoSecreto, verde).toARGB32(), verde.toARGB32());
    expect(Tematica.ninguna.colorDe(Ocasion.amigoSecreto), oroMarca);
    expect(Tematica.navidad.colorDe(Ocasion.amigoSecreto, verde), rojoMarca);
  });

  test('empresarial se registra con nombre real', () {
    expect(Tematica.empresarial.usaPersonajes, isFalse);
    expect(Tematica.desdeId('empresarial'), Tematica.empresarial);
  });

  test('cada temática tiene su fondo en las dos orientaciones', () {
    expect(Tematica.ninguna.imagenFondo(vertical: true), isNull);
    for (final tema in Tematica.values.where((t) => t != Tematica.ninguna)) {
      for (final vertical in [true, false]) {
        final ruta = tema.imagenFondo(vertical: vertical)!;
        expect(File(ruta).existsSync(), isTrue, reason: ruta);
      }
    }
  });
}
