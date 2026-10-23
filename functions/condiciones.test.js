const test = require("node:test");
const assert = require("node:assert");
const c = require("./condiciones");

test("al día solo con las dos versiones vigentes", () => {
  const v = c.VERSIONES;
  assert.strictEqual(c.condicionesAlDia(undefined), false);
  assert.strictEqual(c.condicionesAlDia({}), false);
  assert.strictEqual(c.condicionesAlDia({terminos: {version: v.terminos}}), false);
  assert.strictEqual(c.condicionesAlDia({
    terminos: {version: v.terminos}, privacidad: {version: "2000-01-01"},
  }), false);
  assert.strictEqual(c.condicionesAlDia({
    terminos: {version: v.terminos}, privacidad: {version: v.privacidad},
  }), true);
});

test("id de denuncia determinista", () => {
  assert.strictEqual(c.idDenuncia("ABCD-2345", "m1", "u9"), "ABCD-2345_m1_u9");
});

test("plaza autora por máscara y repetición", () => {
  const privados = [
    {id: "p1", mascara: 3, mascaraRepeticion: 0},
    {id: "p2", mascara: 3, mascaraRepeticion: 1},
    {id: "p3", mascara: 7},
  ];
  assert.strictEqual(c.plazaDeMascara(privados, 3, 1), "p2");
  assert.strictEqual(c.plazaDeMascara(privados, 7, 0), "p3");
  assert.strictEqual(c.plazaDeMascara(privados, 9, 0), null);
});

test("motivos válidos", () => {
  for (const m of ["ofensivo", "sexual", "spam", "otro"]) assert.ok(c.MOTIVOS.includes(m));
  assert.ok(!c.MOTIVOS.includes("cualquiera"));
});
