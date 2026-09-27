// functions/cuenta.test.js
const test = require("node:test");
const assert = require("node:assert");
const {planDeEliminacion} = require("./cuenta");

const g = (o) => ({codigo: "C", nombreGrupo: "G", dirige: false, participanteId: null,
  sorteado: false, otrasPersonas: 0, otrosDirectores: 0, ...o});

test("dirige y está solo: se borra el grupo", () => {
  const p = planDeEliminacion([g({dirige: true, participanteId: "p1"})]);
  assert.deepStrictEqual(p.bloqueos, []);
  assert.strictEqual(p.acciones[0].accion, "borrarGrupo");
});

test("último que dirige con más gente: bloquea con el nombre", () => {
  const p = planDeEliminacion([g({nombreGrupo: "Oficina", dirige: true, otrasPersonas: 3})]);
  assert.deepStrictEqual(p.bloqueos, ["Oficina"]);
});

test("dirige pero hay otro director: no bloquea", () => {
  const p = planDeEliminacion([g({dirige: true, participanteId: "p1", sorteado: true,
    otrasPersonas: 3, otrosDirectores: 1})]);
  assert.deepStrictEqual(p.bloqueos, []);
  assert.strictEqual(p.acciones[0].accion, "liberar");
});

test("plaza en grupo sin sortear: sale", () => {
  const p = planDeEliminacion([g({participanteId: "p1", otrasPersonas: 2})]);
  assert.strictEqual(p.acciones[0].accion, "salir");
});

test("plaza en grupo sorteado: queda libre", () => {
  const p = planDeEliminacion([g({participanteId: "p1", sorteado: true, otrasPersonas: 2})]);
  assert.strictEqual(p.acciones[0].accion, "liberar");
  assert.strictEqual(p.acciones[0].participanteId, "p1");
});

test("organizador sin plaza con otro director: solo deja de dirigir", () => {
  const p = planDeEliminacion([g({dirige: true, otrasPersonas: 4, otrosDirectores: 1})]);
  assert.strictEqual(p.acciones[0].accion, "dejarDeDirigir");
});

test("mezcla con un bloqueo: bloquea y nombra solo ese", () => {
  const p = planDeEliminacion([
    g({codigo: "A", nombreGrupo: "Familia", participanteId: "p1", otrasPersonas: 2}),
    g({codigo: "B", nombreGrupo: "Oficina", dirige: true, participanteId: "p2", otrasPersonas: 5}),
  ]);
  assert.deepStrictEqual(p.bloqueos, ["Oficina"]);
});
