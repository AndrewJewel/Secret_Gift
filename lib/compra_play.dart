// Cobro en Google Play: real en Android, vacío en la web (que cobra con
// Paddle, ver pago.dart). El mismo patrón de import condicional.
export 'compra_play_android.dart' if (dart.library.js_interop) 'compra_play_stub.dart';
