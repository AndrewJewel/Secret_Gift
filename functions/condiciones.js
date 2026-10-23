// Condiciones de uso, denuncias y bloqueo en el chat. Lógica pura, sin
// Firestore, para probarla sin emulador. Diseño en el locker:
// docs/superpowers/specs/2026-10-22-condiciones-y-moderacion-design.md

/** Versión vigente de cada documento. Debe coincidir con lib/condiciones.dart. */
const VERSIONES = {terminos: "2026-10-22", privacidad: "2026-10-22"};

const MOTIVOS = ["ofensivo", "sexual", "spam", "otro"];

/** Las dos aceptaciones, por separado, en la versión vigente. */
function condicionesAlDia(aceptaciones) {
  const a = aceptaciones || {};
  return a.terminos?.version === VERSIONES.terminos &&
    a.privacidad?.version === VERSIONES.privacidad;
}

/** Una denuncia por persona y mensaje: repetirla no duplica nada. */
function idDenuncia(codigo, mensajeId, uid) {
  return `${codigo}_${mensajeId}_${uid}`;
}

/** Qué plaza escribe con esa máscara (el mensaje no guarda autor). */
function plazaDeMascara(privados, mascara, repeticion) {
  const p = privados.find((x) =>
    x.mascara === mascara && (x.mascaraRepeticion || 0) === (repeticion || 0));
  return p ? p.id : null;
}

module.exports = {VERSIONES, MOTIVOS, condicionesAlDia, idDenuncia, plazaDeMascara};
