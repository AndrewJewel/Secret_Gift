import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

// `abrirPago`: real en web, de repuesto fuera (ver recarga_pagina.dart, el
// mismo patrón de import condicional).
export 'pago_stub.dart' if (dart.library.js_interop) 'pago_web.dart';

/// Paddle, entorno de PRUEBAS. El token de cliente es público por diseño
/// (va en la página); el secreto del webhook vive en Secret Manager.
/// Al salir a real: 'production', el token `live_…` y el price ID real.
const pagoEntorno = 'sandbox';
const pagoToken = 'test_a368d7e710228c7101846a42b31';
const pagoPriceId = 'pri_01m5ncp7fapa03z57b4ez75bds';

/// Tras el checkout, el crédito lo suma el webhook de Paddle, no la app:
/// se espera a verlo en la cuenta antes de volver a `crearGrupo`.
Future<bool> esperarCredito(String uid, {Duration limite = const Duration(seconds: 60)}) async {
  try {
    await FirebaseFirestore.instance
        .doc('usuarios/$uid')
        .snapshots()
        .firstWhere((s) => ((s.data()?['creditosGrupo'] as num?) ?? 0) > 0)
        .timeout(limite);
    return true;
  } on TimeoutException {
    return false;
  }
}
