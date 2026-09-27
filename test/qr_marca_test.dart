import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santa_secreto/qr_marca.dart';

/// Pinta el QR con el logo; con QR_PNG=ruta además lo guarda en PNG para
/// comprobar con un lector de verdad que se sigue escaneando.
void main() {
  testWidgets('el QR con logo se pinta', (tester) async {
    final clave = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: RepaintBoundary(
          key: clave,
          child: const QrMarca(datos: 'https://secretgift.app/?codigo=NYXK-AGY7', lado: 300),
        ),
      ),
    ));
    await tester.runAsync(() async {
      await precacheImage(const AssetImage('assets/logo.png'), tester.element(find.byType(QrMarca)));
    });
    await tester.pumpAndSettle();
    expect(find.byType(QrMarca), findsOneWidget);
    final ruta = Platform.environment['QR_PNG'];
    if (ruta == null) return;
    await tester.runAsync(() async {
      final limite = clave.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final imagen = await limite.toImage(pixelRatio: 2);
      final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
      File(ruta).writeAsBytesSync(datos!.buffer.asUint8List());
    });
  });
}
