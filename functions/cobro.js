// Cobro por grupo: lógica pura, sin Firestore, para probarla sin emulador.
// Diseño en el locker: docs/superpowers/specs/2026-10-22-cobro-por-grupo-design.md
const {createHmac, timingSafeEqual} = require("node:crypto");

/**
 * Gratis, con un crédito ya pagado, o hay que pagar. `config` es
 * `config/cobro`: sin él nadie paga; con `para: "probadores"` solo pagan
 * esos uids (fase de sandbox); con `para: "todos"`, todo el mundo, o solo
 * desde `plataformas` si la lista existe (p. ej. `["android"]` mientras la
 * web espera a Paddle live). Los probadores pagan siempre, en todas.
 * `plataforma` la manda la app; las versiones viejas no la mandan y cuentan
 * como "web". Mentir no da nada: la web ya es la vía gratis.
 */
function decidirCobro({config, uid, plataforma = "web", gruposPropiosActivos, creditos}) {
  const probador = ["todos", "probadores"].includes(config?.para) &&
    (config.probadores || []).includes(uid);
  const aplica = probador || (config?.para === "todos" &&
    (!config.plataformas || config.plataformas.includes(plataforma)));
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

/**
 * Una compra de `purchases.products.get` de la Play Developer API.
 * `purchaseState`: 0 comprada, 1 cancelada, 2 pendiente (efectivo o
 * transferencia: aún no hay dinero). `obfuscatedExternalAccountId` es el uid
 * que la app pasó como `applicationUserName` al comprar: si no coincide,
 * alguien intenta cobrar el token de otra cuenta.
 */
function leerCompraPlay(compra, uid) {
  if (!compra || !compra.orderId) return {ok: false, motivo: "invalida"};
  if (compra.purchaseState === 2) return {ok: false, motivo: "pendiente"};
  if (compra.purchaseState !== 0) return {ok: false, motivo: "cancelada"};
  if (!uid || compra.obfuscatedExternalAccountId !== uid) return {ok: false, motivo: "otra_cuenta"};
  return {ok: true, id: compra.orderId};
}

/** Los `orderId` de `voidedpurchases.list` (devueltas, anuladas o con contracargo). */
function leerAnuladasPlay(lista) {
  return (lista || []).map((v) => v?.orderId).filter(Boolean);
}

module.exports = {decidirCobro, firmaValida, leerEvento, leerCompraPlay, leerAnuladasPlay, TOLERANCIA_FIRMA_S};
