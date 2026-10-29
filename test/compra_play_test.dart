import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:santa_secreto/compra_play_android.dart';

void main() {
  test('cada estado de Play tiene su resultado; comprada se verifica', () {
    expect(estadoDeCompra(PurchaseStatus.pending), 'pendiente');
    expect(estadoDeCompra(PurchaseStatus.canceled), 'cancelado');
    expect(estadoDeCompra(PurchaseStatus.error), 'error');
    expect(estadoDeCompra(PurchaseStatus.purchased), isNull);
    expect(estadoDeCompra(PurchaseStatus.restored), isNull);
  });
}
