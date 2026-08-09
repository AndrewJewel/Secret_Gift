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

  test('no quedan claves de los PIN por grupo', () {
    final en = _clavesDe('lib/l10n/app_en.arb');
    // Los PIN por participante y el PIN maestro desaparecieron. Si alguna
    // de estas reaparece, es que se resucitó código muerto con ella.
    for (final muerta in const [
      'crearPinMaestro',
      'crearPinMaestroAyuda',
      'registroPin',
      'registroPinAyuda',
      'registroTuPin',
      'organizadorPinTexto',
      'organizadorPinCampo',
      'organizadorEntrar',
      'organizadorSalir',
      'organizadorActivado',
      'organizadorDesactivado',
      'loginTitulo',
      'loginHola',
      'chatQuienEres',
      'chatQuienEresTexto',
      'chatCambiarPersona',
      // Estas dos murieron en la Task 7, al borrar los botones "¿No eres tú?"
      // y "Ya me registré en otro dispositivo" con la hoja de identidad.
      'grupoNoEresTu',
      'grupoYaEstoyDentro',
    ]) {
      expect(en.contains(muerta), isFalse, reason: '$muerta debería estar borrada');
    }
  });
}
