import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Idioma de la interfaz. Arranca en inglés y se puede cambiar a español
/// desde la pantalla de inicio; la elección se recuerda en el dispositivo.
///
/// Es un ValueNotifier y no un paquete de estado: la app entera solo
/// necesita que MaterialApp se reconstruya cuando esto cambie.
class Idioma {
  Idioma._();

  static const soportados = [Locale('en'), Locale('es')];
  static const _clave = 'idioma';

  /// Inglés por defecto, tal como se pidió. Si algún día se quisiera
  /// respetar el idioma del teléfono, este es el único sitio a tocar.
  static final actual = ValueNotifier<Locale>(const Locale('en'));

  /// Se llama al arrancar. No bloquea la interfaz: si tarda o falla, la
  /// app ya se está viendo en inglés y luego cambia sola.
  static Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final guardado = prefs.getString(_clave);
      if (guardado != null && soportados.any((l) => l.languageCode == guardado)) {
        actual.value = Locale(guardado);
      }
    } catch (_) {
      // Sin preferencias disponibles: se queda en inglés.
    }
  }

  static Future<void> cambiar(Locale locale) async {
    actual.value = locale;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_clave, locale.languageCode);
    } catch (_) {
      // El cambio ya se aplicó en pantalla aunque no se pueda guardar.
    }
  }
}
