import 'package:shared_preferences/shared_preferences.dart';

/// Invitación a un grupo que llegó por enlace o QR (`?codigo=XXXX`) y que
/// todavía no se ha usado.
///
/// Se guarda en disco y no en memoria a propósito: entre que la persona
/// llega y termina de crear su cuenta puede recargar la página, y una
/// invitación en memoria se perdería. Acabaría en un "Mis grupos" vacío
/// sin entender por qué.
class InvitacionPendiente {
  final String codigo;

  /// Solo para mostrar "Te han invitado a X" en la pantalla de registro.
  /// Puede venir vacío: hay grupos sin nombre.
  final String nombreGrupo;

  const InvitacionPendiente(this.codigo, this.nombreGrupo);
}

const _claveCodigo = 'invitacion_codigo';
const _claveNombre = 'invitacion_nombre';

Future<void> guardarInvitacion(String codigo, String nombreGrupo) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveCodigo, codigo);
    await prefs.setString(_claveNombre, nombreGrupo);
  } catch (_) {
    // Sin almacenamiento la invitación se pierde, pero la app sigue viva.
  }
}

Future<InvitacionPendiente?> leerInvitacion() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final codigo = prefs.getString(_claveCodigo);
    if (codigo == null) return null;
    return InvitacionPendiente(codigo, prefs.getString(_claveNombre) ?? '');
  } catch (_) {
    return null;
  }
}

/// Se llama en cuanto la invitación se usa. Sin esto, cada apertura de la
/// app volvería a meter a esa persona en ese grupo para siempre.
Future<void> borrarInvitacion() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_claveCodigo);
    await prefs.remove(_claveNombre);
  } catch (_) {
    // Nada que hacer.
  }
}
