import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'marca.dart';

/// QR de invitación con la marca: esquinas en carmín, puntos redondeados y
/// el logo en el centro. Corrección de errores H (30%): el logo tapa ~6%
/// del código y sigue leyéndose con margen.
class QrMarca extends StatelessWidget {
  final String datos;
  final double lado;

  const QrMarca({super.key, required this.datos, this.lado = 200});

  @override
  Widget build(BuildContext context) {
    final logo = lado * 0.24;
    return SizedBox.square(
      dimension: lado,
      child: Stack(
        alignment: Alignment.center,
        children: [
          QrImageView(
            data: datos,
            size: lado,
            // Blanco puro alrededor: el margen silencioso que necesita el
            // lector, aunque el diálogo tenga un fondo tintado.
            backgroundColor: Colors.white,
            errorCorrectionLevel: QrErrorCorrectLevel.H,
            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: rojoMarca),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.circle,
              color: Color(0xFF181818),
            ),
          ),
          Container(
            width: logo,
            height: logo,
            padding: EdgeInsets.all(logo * 0.1),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(logo * 0.22),
            ),
            child: Image.asset('assets/logo.png'),
          ),
        ],
      ),
    );
  }
}
