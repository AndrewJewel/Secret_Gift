// functions/cuenta.js
// Qué pasa con cada grupo al borrar una cuenta. Pura: sin Firestore, para
// probarla sin emulador. index.js recoge la situación y ejecuta el plan.
// Diseño: locker/docs/superpowers/specs/2026-09-27-administradores-y-eliminar-cuenta-design.md

function planDeEliminacion(situacion) {
  const bloqueos = [];
  const acciones = [];
  for (const s of situacion) {
    const base = {codigo: s.codigo, nombreGrupo: s.nombreGrupo, participanteId: s.participanteId};
    if (s.dirige && s.otrasPersonas === 0) {
      acciones.push({...base, accion: "borrarGrupo"});
    } else if (s.dirige && s.otrosDirectores === 0) {
      // Dejaría a gente en un grupo sin nadie que lo dirija.
      bloqueos.push(s.nombreGrupo);
    } else if (s.participanteId && !s.sorteado) {
      acciones.push({...base, accion: "salir"});
    } else if (s.participanteId) {
      // Tras el sorteo la plaza no se borra: alguien le regala y regalaba.
      acciones.push({...base, accion: "liberar"});
    } else {
      acciones.push({...base, accion: "dejarDeDirigir"});
    }
  }
  return {bloqueos, acciones};
}

module.exports = {planDeEliminacion};
