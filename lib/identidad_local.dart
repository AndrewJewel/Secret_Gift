import 'package:shared_preferences/shared_preferences.dart';

/// Quién eres TÚ dentro de un grupo, recordado en este dispositivo.
///
/// La usan la pantalla del grupo (para no volver a ofrecerte el
/// formulario de alta si ya estás dentro) y el chat (para no pedirte el
/// PIN en cada mensaje).
///
/// Es solo conveniencia local: el servidor vuelve a verificar el PIN en
/// cada acción y nunca confía en esto.
class IdentidadGrupo {
  final String participanteId;
  final String pin;

  const IdentidadGrupo(this.participanteId, this.pin);
}

// Se guarda por grupo: la misma persona puede estar en varios y no es la
// misma identidad en cada uno.
String _claveId(String codigo) => 'chat_${codigo}_participante';
String _clavePin(String codigo) => 'chat_${codigo}_pin';

Future<void> guardarIdentidad(String codigo, IdentidadGrupo identidad) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveId(codigo), identidad.participanteId);
    await prefs.setString(_clavePin(codigo), identidad.pin);
  } catch (_) {
    // Sin almacenamiento: se pedirá de nuevo, nada más.
  }
}

Future<IdentidadGrupo?> leerIdentidad(String codigo) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_claveId(codigo));
    final pin = prefs.getString(_clavePin(codigo));
    if (id == null || pin == null) return null;
    return IdentidadGrupo(id, pin);
  } catch (_) {
    return null;
  }
}

Future<void> olvidarIdentidad(String codigo) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_claveId(codigo));
    await prefs.remove(_clavePin(codigo));
  } catch (_) {
    // Nada que hacer.
  }
}
