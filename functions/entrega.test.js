const test = require("node:test");
const assert = require("node:assert");
const e = require("./entrega");

// 2026-12-23 15:00 UTC = 10:00 en Bogotá (zona -300).
const AHORA = Date.UTC(2026, 11, 23, 15, 0);
const BOGOTA = -300;

test("fecha de entrega: formato, fecha real, no pasada, no más de 2 años", () => {
  assert.strictEqual(e.fechaValidaEntrega("2026-12-24", BOGOTA, AHORA), true);
  assert.strictEqual(e.fechaValidaEntrega("2026-12-23", BOGOTA, AHORA), true, "hoy vale");
  assert.strictEqual(e.fechaValidaEntrega("2026-12-22", BOGOTA, AHORA), false, "ayer no");
  assert.strictEqual(e.fechaValidaEntrega("2027-02-31", BOGOTA, AHORA), false, "no existe");
  assert.strictEqual(e.fechaValidaEntrega("24/12/2026", BOGOTA, AHORA), false);
  assert.strictEqual(e.fechaValidaEntrega("2028-12-23", BOGOTA, AHORA), true, "dentro de 2 años");
  assert.strictEqual(e.fechaValidaEntrega("2029-01-01", BOGOTA, AHORA), false, "más de 2 años");
  assert.strictEqual(e.fechaValidaEntrega("2026-12-24", 900, AHORA), false, "zona imposible");
  assert.strictEqual(e.fechaValidaEntrega("2026-12-24", "x", AHORA), false);
  // 2026-12-24 02:00 UTC: en Bogotá todavía es el 23, así que el 23 vale.
  assert.strictEqual(e.fechaValidaEntrega("2026-12-23", BOGOTA, Date.UTC(2026, 11, 24, 2)), true);
});

test("aviso pendiente: víspera y día a las 10:00 de la zona, una sola vez, solo sorteado", () => {
  const g = {sorteado: true, fechaEntrega: "2026-12-24", zonaEntrega: BOGOTA, avisosEntrega: {}};
  assert.strictEqual(e.avisoPendiente(g, AHORA), "vispera");
  assert.strictEqual(e.avisoPendiente(g, AHORA - 60 * 60 * 1000), null, "9:00, aún no");
  assert.strictEqual(e.avisoPendiente({...g, avisosEntrega: {vispera: true}}, AHORA), null);
  const elDia = Date.UTC(2026, 11, 24, 15);
  assert.strictEqual(e.avisoPendiente({...g, avisosEntrega: {vispera: true}}, elDia), "dia");
  assert.strictEqual(e.avisoPendiente({...g, avisosEntrega: {vispera: true, dia: true}}, elDia), null);
  assert.strictEqual(e.avisoPendiente({...g, sorteado: false}, AHORA), null);
  assert.strictEqual(e.avisoPendiente({...g, fechaEntrega: undefined}, AHORA), null);
  assert.strictEqual(e.avisoPendiente({...g, fechaEntrega: "2026-12-30"}, AHORA), null, "lejos");
});

test("fechas cercanas en UTC: ayer, hoy y mañana", () => {
  assert.deepStrictEqual(e.fechasCercanas(AHORA), ["2026-12-22", "2026-12-23", "2026-12-24"]);
});
