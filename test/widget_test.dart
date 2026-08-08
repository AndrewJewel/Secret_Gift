// Nota: PantallaRegistro llama a Firebase/Firestore en su initState, así
// que probarla de verdad requiere mockear Firebase (p.ej. con
// fake_cloud_firestore) — no está configurado todavía. Este placeholder
// solo evita que la suite quede rota referenciando la app de ejemplo
// (MyApp/contador) que ya no existe en este proyecto.
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('placeholder — pendiente configurar mocks de Firebase para widget tests', () {
    expect(1 + 1, 2);
  });
}
