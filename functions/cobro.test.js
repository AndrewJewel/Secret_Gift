const test = require("node:test");
const assert = require("node:assert");
const {createHmac} = require("node:crypto");
const c = require("./cobro");

test("sin config o fuera de los probadores, todo gratis", () => {
  assert.strictEqual(c.decidirCobro({config: null, uid: "u", gruposPropiosActivos: 3, creditos: 0}), "gratis");
  assert.strictEqual(c.decidirCobro({
    config: {para: "probadores", probadores: ["otro"]}, uid: "u", gruposPropiosActivos: 3, creditos: 0,
  }), "gratis");
});

test("con cobro: primero gratis, luego crédito, luego pago", () => {
  const config = {para: "todos"};
  assert.strictEqual(c.decidirCobro({config, uid: "u", gruposPropiosActivos: 0, creditos: 0}), "gratis");
  assert.strictEqual(c.decidirCobro({config, uid: "u", gruposPropiosActivos: 1, creditos: 2}), "credito");
  assert.strictEqual(c.decidirCobro({config, uid: "u", gruposPropiosActivos: 1, creditos: 0}), "pago_requerido");
  const prueba = {para: "probadores", probadores: ["u"]};
  assert.strictEqual(c.decidirCobro({config: prueba, uid: "u", gruposPropiosActivos: 1, creditos: 0}), "pago_requerido");
});

function firmar(cuerpo, secreto, ts) {
  return `ts=${ts};h1=${createHmac("sha256", secreto).update(`${ts}:${cuerpo}`).digest("hex")}`;
}

test("firma de Paddle: válida, alterada, vieja o ausente", () => {
  const cuerpo = "{\"event_type\":\"transaction.completed\"}";
  const ahora = 1700000000;
  assert.strictEqual(c.firmaValida(cuerpo, firmar(cuerpo, "s3", ahora), "s3", ahora + 10), true);
  assert.strictEqual(c.firmaValida(Buffer.from(cuerpo), firmar(cuerpo, "s3", ahora), "s3", ahora), true);
  assert.strictEqual(c.firmaValida(cuerpo + " ", firmar(cuerpo, "s3", ahora), "s3", ahora), false);
  assert.strictEqual(c.firmaValida(cuerpo, firmar(cuerpo, "otro", ahora), "s3", ahora), false);
  assert.strictEqual(c.firmaValida(cuerpo, firmar(cuerpo, "s3", ahora), "s3", ahora + 301), false);
  assert.strictEqual(c.firmaValida(cuerpo, undefined, "s3", ahora), false);
  assert.strictEqual(c.firmaValida(cuerpo, "ts=1;h1=zz", "s3", 1), false);
});

test("leer eventos de Paddle", () => {
  assert.deepStrictEqual(c.leerEvento({
    event_type: "transaction.completed",
    data: {
      id: "txn_1", custom_data: {uid: "u"}, currency_code: "USD",
      items: [{quantity: 1}], details: {totals: {grand_total: "500"}},
    },
  }), {tipo: "pago", id: "txn_1", uid: "u", cantidad: 1, importe: "500", moneda: "USD"});
  assert.strictEqual(c.leerEvento({event_type: "transaction.completed", data: {id: "t", items: []}}).uid, null);
  assert.deepStrictEqual(c.leerEvento({
    event_type: "adjustment.updated", data: {action: "refund", status: "approved", transaction_id: "txn_1"},
  }), {tipo: "reembolso", transaccion: "txn_1"});
  assert.strictEqual(c.leerEvento({
    event_type: "adjustment.created", data: {action: "refund", status: "pending_approval", transaction_id: "t"},
  }), null);
  assert.strictEqual(c.leerEvento({event_type: "customer.created", data: {}}), null);
  assert.strictEqual(c.leerEvento(undefined), null);
});
