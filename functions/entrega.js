// Fecha de entrega de regalos: lógica pura, sin Firestore, para probarla sin
// emulador. Diseño: locker/docs/superpowers/specs/2026-10-28-fecha-entrega-design.md
//
// Las fechas son "YYYY-MM-DD" sin hora. `zona` es la diferencia del
// organizador con UTC en minutos (Bogotá: -300), la que manda la app desde
// `DateTime.now().timeZoneOffset`: la hora local es UTC + zona.

const DIA_MS = 24 * 60 * 60 * 1000;
const MAX_DIAS = 731; // dos años, con un bisiesto de margen
const HORA_AVISO = 10;

/** "YYYY-MM-DD" del instante `ms`, visto en UTC. */
function diaUtc(ms) {
  return new Date(ms).toISOString().slice(0, 10);
}

/** La fecha como medianoche UTC, o null si no es una fecha real. */
function aMs(fecha) {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(typeof fecha === "string" ? fecha : "");
  if (!m) return null;
  const ms = Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
  return diaUtc(ms) === fecha ? ms : null; // descarta el 31 de febrero
}

function zonaValida(zona) {
  return Number.isInteger(zona) && zona >= -720 && zona <= 840;
}

/** Desde hoy (en la zona del organizador) hasta dos años después. */
function fechaValidaEntrega(fecha, zona, ahoraMs) {
  const ms = aMs(fecha);
  if (ms === null || !zonaValida(zona)) return false;
  const hoy = aMs(diaUtc(ahoraMs + zona * 60 * 1000));
  return ms >= hoy && ms <= hoy + MAX_DIAS * DIA_MS;
}

/**
 * El aviso que toca mandar ya, o null. Solo con el sorteo hecho (antes nadie
 * sabe a quién regalar) y a partir de las 10:00 en la zona del grupo. Si la
 * víspera se pasó sin aviso, el día sigue saliendo.
 */
function avisoPendiente(grupo, ahoraMs) {
  if (grupo?.sorteado !== true || !zonaValida(grupo.zonaEntrega)) return null;
  const entrega = aMs(grupo.fechaEntrega);
  if (entrega === null) return null;
  const local = ahoraMs + grupo.zonaEntrega * 60 * 1000;
  if (new Date(local).getUTCHours() < HORA_AVISO) return null;
  const hoy = aMs(diaUtc(local));
  const enviados = grupo.avisosEntrega || {};
  if (entrega === hoy && !enviados.dia) return "dia";
  if (entrega === hoy + DIA_MS && !enviados.vispera) return "vispera";
  return null;
}

/** Ayer, hoy y mañana en UTC: cubren el «hoy» y el «mañana» de cualquier zona. */
function fechasCercanas(ahoraMs) {
  return [-1, 0, 1].map((d) => diaUtc(ahoraMs + d * DIA_MS));
}

module.exports = {fechaValidaEntrega, avisoPendiente, fechasCercanas};
