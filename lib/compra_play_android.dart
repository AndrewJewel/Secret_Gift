import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'funciones.dart';

// Diseño: locker/docs/superpowers/specs/2026-10-28-cobro-google-play-design.md
const productoGrupoExtra = 'grupo_extra';

final _resultados = StreamController<String>.broadcast();
StreamSubscription<List<PurchaseDetails>>? _escucha;

/// `null`: comprada, hay que verificarla en el servidor.
String? estadoDeCompra(PurchaseStatus estado) => switch (estado) {
      PurchaseStatus.pending => 'pendiente',
      PurchaseStatus.canceled => 'cancelado',
      PurchaseStatus.error => 'error',
      PurchaseStatus.purchased || PurchaseStatus.restored => null,
    };

/// Con sesión, al arrancar: toda compra de `grupo_extra` que llegue se
/// verifica en el servidor, también las que llegan tarde (un pago pendiente
/// que se confirmó, o la app cerrada a mitad de la compra). Las que siguen sin
/// consumir las vuelve a entregar `restorePurchases`. El servidor no suma dos
/// veces, así que verificar de más no cuesta nada.
void escucharComprasPlay() {
  _escucha ??= InAppPurchase.instance.purchaseStream.listen((compras) async {
    for (final c in compras.where((c) => c.productID == productoGrupoExtra)) {
      _resultados.add(estadoDeCompra(c.status) ?? await _verificar(c));
    }
  });
  InAppPurchase.instance.restorePurchases();
}

Future<String> _verificar(PurchaseDetails compra) async {
  try {
    await llamarFuncion('verificarCompraPlay', {'token': compra.verificationData.serverVerificationData});
    return 'completado';
  } catch (_) {
    // Sin consumir, Google la vuelve a entregar: se reintenta al arrancar.
    return 'error';
  }
}

/// El precio de `grupo_extra` tal como lo cobra Google Play, en la moneda de
/// quien compra (p. ej. «US$4.99»). Null si Play no está disponible.
Future<String?> precioGrupoExtra() async {
  final iap = InAppPurchase.instance;
  if (!await iap.isAvailable()) return null;
  final r = await iap.queryProductDetails({productoGrupoExtra});
  return r.productDetails.isEmpty ? null : r.productDetails.first.price;
}

/// Abre la hoja de compra de Google Play. Devuelve 'completado' cuando el
/// crédito ya está en la cuenta: quien llama puede volver a `crearGrupo`.
Future<String> comprarGrupoExtra(String uid) async {
  final iap = InAppPurchase.instance;
  if (!await iap.isAvailable()) return 'no_disponible';
  final r = await iap.queryProductDetails({productoGrupoExtra});
  if (r.productDetails.isEmpty) return 'no_disponible';
  escucharComprasPlay();
  final resultado = _resultados.stream.first;
  final lanzada = await iap.buyConsumable(
    purchaseParam: PurchaseParam(productDetails: r.productDetails.first, applicationUserName: uid),
    autoConsume: false,
  );
  if (lanzada) return resultado;
  // No se abrió la hoja. La causa típica es `itemAlreadyOwned`: una compra
  // anterior sin consumir. El `restorePurchases` de escucharComprasPlay() la
  // vuelve a entregar y se verifica, así que se espera ese resultado en vez de
  // decir «no se pudo abrir el pago» a quien ya pagó.
  return resultado.timeout(const Duration(seconds: 15), onTimeout: () => 'error');
}
