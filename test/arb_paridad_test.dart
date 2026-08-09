import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Los dos ARB tienen que llevar exactamente las mismas claves. Se ha
/// comprobado a mano en cada sesión hasta ahora; esto lo hace solo.
///
/// Se ignoran las claves de metadatos: `@@locale` y las `@clave`, que solo
/// existen en la plantilla (`app_en.arb`) y que gen-l10n no exige duplicar.
Set<String> _clavesDe(String ruta) {
  final json = jsonDecode(File(ruta).readAsStringSync()) as Map<String, dynamic>;
  return json.keys.where((k) => !k.startsWith('@')).toSet();
}

void main() {
  test('los dos ARB llevan exactamente las mismas claves', () {
    final en = _clavesDe('lib/l10n/app_en.arb');
    final es = _clavesDe('lib/l10n/app_es.arb');

    expect(en.difference(es), isEmpty, reason: 'claves que solo están en inglés');
    expect(es.difference(en), isEmpty, reason: 'claves que solo están en español');
  });

  test('las claves nuevas del PIN global existen en los dos idiomas', () {
    final en = _clavesDe('lib/l10n/app_en.arb');
    final es = _clavesDe('lib/l10n/app_es.arb');
    for (final nueva in const [
      'cuentaPin',
      'configuracion',
      'cambiarPinTitulo',
      'verAmigoPinTitulo',
      'editarEliminarEscribeNombre',
      'errorPinFormato',
      'errorGrupoYaSorteado',
    ]) {
      expect(en.contains(nueva), isTrue, reason: 'falta $nueva en inglés');
      expect(es.contains(nueva), isTrue, reason: 'falta $nueva en español');
    }
  });
}
