const test = require("node:test");
const assert = require("node:assert");
const path = require("node:path");
const {randomInt} = require("node:crypto");
const {
  claveDePareja, parejasVigentes, idsOrdenados, aIndices, hayCadena, sortearCadena,
} = require("./sorteo");

// Los mismos casos que prueba la versión Dart (test/exclusiones_test.dart):
// si una de las dos cambia de opinión sobre un caso, falla su prueba.
const CASOS = require(path.join(__dirname, "..", "test", "fixtures", "casos_exclusiones.json"));

test("claveDePareja ordena los ids", () => {
  assert.strictEqual(claveDePareja("b", "a"), "a|b");
  assert.strictEqual(claveDePareja("a", "b"), "a|b");
});

test("parejasVigentes quita duplicados y parejas de quien ya no está", () => {
  assert.deepStrictEqual(
      parejasVigentes(["a|b", "a|b", "a|z"], ["a", "b", "c"]), ["a|b"]);
});

test("idsOrdenados no depende del orden de llegada", () => {
  assert.deepStrictEqual(idsOrdenados(["c", "a", "b"]), ["a", "b", "c"]);
});

test("aIndices traduce ids a posiciones", () => {
  assert.deepStrictEqual(aIndices(["a|c"], ["a", "b", "c"]), [[0, 2]]);
});

for (const caso of CASOS) {
  test(`hayCadena: ${caso.nombre}`, () => {
    assert.strictEqual(hayCadena(caso.n, caso.exclusiones), caso.posible);
  });

  test(`sortearCadena: ${caso.nombre}`, () => {
    const prohibida = new Set(caso.exclusiones.map(([a, b]) => `${a}|${b}`).concat(
        caso.exclusiones.map(([a, b]) => `${b}|${a}`)));
    for (let vez = 0; vez < (caso.n > 12 ? 20 : 200); vez++) {
      const orden = sortearCadena(caso.n, caso.exclusiones, randomInt);
      if (!caso.posible) {
        assert.strictEqual(orden, null);
        return;
      }
      assert.strictEqual(orden.length, caso.n);
      assert.strictEqual(new Set(orden).size, caso.n, "cada persona una vez");
      orden.forEach((a, i) => {
        const b = orden[(i + 1) % caso.n];
        assert.ok(!prohibida.has(`${a}|${b}`), `eslabón prohibido ${a}→${b}`);
      });
    }
  });
}

test("con dos parejas en 4, las dos cadenas válidas salen parecido", () => {
  // Cadenas válidas vistas desde 0: 0→2→1→3 y 0→3→1→2.
  const cuenta = {"0,2,1,3": 0, "0,3,1,2": 0};
  const N = 4000;
  for (let i = 0; i < N; i++) {
    const orden = sortearCadena(4, [[0, 1], [2, 3]], randomInt);
    const desde0 = orden.indexOf(0);
    const rotada = [...orden.slice(desde0), ...orden.slice(0, desde0)].join(",");
    cuenta[rotada]++;
  }
  for (const veces of Object.values(cuenta)) {
    assert.ok(veces > N * 0.4 && veces < N * 0.6, JSON.stringify(cuenta));
  }
});
