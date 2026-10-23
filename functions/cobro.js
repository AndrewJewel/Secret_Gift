// Cobro por grupo: lógica pura, sin Firestore, para probarla sin emulador.
// Diseño en el locker: docs/superpowers/specs/2026-10-22-cobro-por-grupo-design.md
const {createHmac, timingSafeEqual} = require("node:crypto");

/**
 * Gratis, con un crédito ya pagado, o hay que pagar. `config` es
 * `config/cobro`: sin él nadie paga; con `para: "probadores"` solo pagan
 * esos uids (fase de sandbox); con `para: "todos"`, todo el mundo.
 */
function decidirCobro({config, uid, gruposPropiosActivos, creditos}) {
  const aplica = config?.para === "todos" ||
    (config?.para === "probadores" && (config.probadores || []).includes(uid));
  if (!aplica || gruposPropiosActivos === 0) return "gratis";
  return creditos > 0 ? "credito" : "pago_requerido";
}

// Paddle aconseja segundos de margen, pero la función puede tardar ~3 s en
// arrancar en frío. Cinco minutos siguen cerrando la puerta a repetir un
// aviso viejo capturado.
const TOLERANCIA_FIRMA_S = 300;

/** `Paddle-Signature: ts=…;h1=…`, HMAC-SHA256 de `ts:cuerpo crudo`. */
function firmaValida(cuerpo, cabecera, secreto, ahoraS) {
  if (!cuerpo || !cabecera || !secreto) return false;
  const partes = Object.fromEntries(String(cabecera).split(";").map((p) => p.split("=")));
  if (!partes.ts || !partes.h1 || Math.abs(ahoraS - Number(partes.ts)) > TOLERANCIA_FIRMA_S) return false;
  const esperada = createHmac("sha256", secreto).update(`${partes.ts}:`).update(cuerpo).digest();
  const recibida = Buffer.from(partes.h1, "hex");
  return recibida.length === esperada.length && timingSafeEqual(recibida, esperada);
}

/** Lo que nos importa de un aviso de Paddle; null para el resto. */
function leerEvento(evento) {
  const d = evento?.data || {};
  if (evento?.event_type === "transaction.completed") {
    const cantidad = (d.items || []).reduce((n, i) => n + (Number(i.quantity) || 0), 0) || 1;
    return {
      tipo: "pago", id: d.id, uid: d.custom_data?.uid || null, cantidad,
      importe: d.details?.totals?.grand_total || null, moneda: d.currency_code || null,
    };
  }
  // ponytail: cualquier reembolso o contracargo aprobado, total o parcial,
  // quita los créditos sin usar de esa compra. Las devoluciones son a mano
  // y raras; si un día hay parciales de verdad, mirar `items` del ajuste.
  if (["adjustment.created", "adjustment.updated"].includes(evento?.event_type) &&
      ["refund", "chargeback"].includes(d.action) && d.status === "approved") {
    return {tipo: "reembolso", transaccion: d.transaction_id};
  }
  return null;
}

module.exports = {decidirCobro, firmaValida, leerEvento, TOLERANCIA_FIRMA_S};
