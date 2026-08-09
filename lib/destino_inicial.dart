/// A dónde manda el portero a quien abre la app.
enum DestinoInicial { crearCuenta, misGrupos, grupo }

/// La decisión vive aquí, separada del widget, para poder probarla sin
/// Firebase ni navegación. El portero solo la obedece.
///
/// Sin sesión siempre se va a crear cuenta, incluso habiendo invitación:
/// la invitación no se descarta, queda guardada y se usa en cuanto la
/// cuenta esté lista.
DestinoInicial decidirDestino({
  required bool haySesion,
  required bool hayInvitacion,
}) {
  if (!haySesion) return DestinoInicial.crearCuenta;
  return hayInvitacion ? DestinoInicial.grupo : DestinoInicial.misGrupos;
}
