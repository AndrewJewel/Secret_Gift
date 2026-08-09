/// Tu relación con un grupo concreto, tal como la cuenta la conoce.
///
/// Sustituye a la identidad que antes se guardaba en disco por grupo,
/// asociada al par código-de-grupo + PIN: el servidor ya sabe qué
/// participante eres en cada grupo, y lo manda en `iniciarSesionCuenta`.
/// Preguntárselo al usuario era pedirle un dato que ya teníamos.
class MiVinculo {
  /// `organizador` o `participante`.
  final String rol;

  /// Qué participante eres dentro del grupo. Null mientras no te hayas
  /// dado de alta: se puede ser organizador de un grupo en el que
  /// todavía no te inscribiste.
  final String? participanteId;

  /// Si el grupo ya sorteó. Manda qué acciones de organizador tienen
  /// sentido: tras el sorteo no se puede sacar a nadie.
  final bool sorteado;

  const MiVinculo({required this.rol, this.participanteId, this.sorteado = false});

  bool get esOrganizador => rol == 'organizador';

  bool get estoyDentro => participanteId != null && participanteId!.isNotEmpty;

  /// Lee una entrada de las que devuelve `iniciarSesionCuenta`.
  factory MiVinculo.desdeMapa(Map<String, dynamic> g) => MiVinculo(
        rol: g['rol'] as String? ?? 'participante',
        participanteId: g['participanteId'] as String?,
        sorteado: g['sorteado'] == true,
      );
}
