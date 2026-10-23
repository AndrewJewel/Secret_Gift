import 'dart:js_interop';

import 'pago.dart' show pagoEntorno, pagoPriceId, pagoToken;

@JS('sgPagar')
external JSPromise<JSString> _sgPagar(
    JSString token, JSString entorno, JSString priceId, JSString uid, JSString correo, JSString idioma);

/// Abre el checkout de Paddle encima de la página (web/pago.js).
Future<String> abrirPago({required String uid, required String correo, required String idioma}) async {
  final r = await _sgPagar(
    pagoToken.toJS, pagoEntorno.toJS, pagoPriceId.toJS, uid.toJS, correo.toJS, idioma.toJS,
  ).toDart;
  return r.toDart;
}
