// El sorteo como problema de grafos, sin Firestore: así se prueba solo.
//
// Participantes = vértices; «puede regalarle» = arista, salvo las parejas
// excluidas (siempre mutuas). Un sorteo válido es UNA cadena circular que
// pasa por todos (un ciclo hamiltoniano) sin usar ninguna arista excluida.
//
// Tiene un gemelo en Dart (lib/exclusiones.dart) para que la app bloquee la
// casilla al instante. Los dos se prueban contra
// test/fixtures/casos_exclusiones.json: si se tocan, que sea juntos.

// Tope de pasos de la búsqueda. Solo lo alcanza un grupo enorme y muy
// restringido; entonces se contesta «no» (bloquea la casilla / no sortea),
// que es lo prudente.
const PRESUPUESTO_BUSQUEDA = 2000000;
const INTENTOS_BARAJADO = 10000;

function claveDePareja(a, b) {
  return a < b ? `${a}|${b}` : `${b}|${a}`;
}

// Las parejas guardadas que siguen valiendo: sin repetir y con las dos
// personas todavía en el grupo. Las de quien se fue no se borran al irse:
// se ignoran aquí, y así no hay nada que pueda desincronizarse.
function parejasVigentes(guardadas, ids) {
  const presentes = new Set(ids);
  return [...new Set(guardadas)].filter((clave) => {
    const [a, b] = clave.split("|");
    return presentes.has(a) && presentes.has(b);
  });
}

function aIndices(parejas, ids) {
  const indice = new Map(ids.map((id, i) => [id, i]));
  return parejas.map((clave) => clave.split("|").map((id) => indice.get(id)));
}

function matrizPermitidos(n, prohibidas) {
  const ok = Array.from({length: n}, (_, i) =>
    Array.from({length: n}, (_, j) => i !== j));
  for (const [a, b] of prohibidas) {
    ok[a][b] = false;
    ok[b][a] = false;
  }
  return ok;
}

function barajar(lista, randomInt) {
  const copia = [...lista];
  for (let i = copia.length - 1; i > 0; i--) {
    const j = randomInt(i + 1);
    [copia[i], copia[j]] = [copia[j], copia[i]];
  }
  return copia;
}

// Búsqueda en profundidad de una cadena que empiece en 0. `ordenar` decide
// en qué orden se prueban los vecinos (tal cual para comprobar, barajados
// para sortear). Devuelve el orden, o null.
function buscarCadena(n, ok, ordenar) {
  const camino = [0];
  const usado = new Array(n).fill(false);
  usado[0] = true;
  let pasos = 0;
  function extender() {
    if (++pasos > PRESUPUESTO_BUSQUEDA) return false;
    const ultimo = camino[camino.length - 1];
    if (camino.length === n) return ok[ultimo][0];
    const vecinos = [];
    for (let v = 0; v < n; v++) if (!usado[v] && ok[ultimo][v]) vecinos.push(v);
    for (const v of ordenar(vecinos)) {
      usado[v] = true;
      camino.push(v);
      if (extender()) return true;
      camino.pop();
      usado[v] = false;
    }
    return false;
  }
  return extender() ? camino : null;
}

function hayCadena(n, prohibidas) {
  if (n < 2) return false;
  const ok = matrizPermitidos(n, prohibidas);
  if (n === 2) return ok[0][1];
  const grado = ok.map((fila) => fila.filter(Boolean).length);
  // En una cadena circular cada persona necesita a alguien a cada lado.
  if (grado.some((g) => g < 2)) return false;
  // Teorema de Dirac: si todos pueden regalarle a la mitad del grupo o más,
  // la cadena existe seguro. Resuelve al instante casi todo grupo real.
  if (grado.every((g) => 2 * g >= n)) return true;
  return buscarCadena(n, ok, (vecinos) => vecinos) !== null;
}

// Una cadena al azar sin eslabones excluidos, o null si no existe.
//
// Primero barajar y aceptar la primera válida (muestreo por rechazo): así
// TODAS las cadenas válidas son igual de probables y las exclusiones no
// dejan pistas de quién le tocó a quién. Sin exclusiones, la primera
// barajada ya vale: se comporta como el sorteo de siempre.
function sortearCadena(n, prohibidas, randomInt) {
  const ok = matrizPermitidos(n, prohibidas);
  const esValida = (orden) => orden.every((a, i) => ok[a][orden[(i + 1) % n]]);
  const todos = Array.from({length: n}, (_, i) => i);
  for (let intento = 0; intento < INTENTOS_BARAJADO; intento++) {
    const orden = barajar(todos, randomInt);
    if (esValida(orden)) return orden;
  }
  if (!hayCadena(n, prohibidas)) return null;
  return buscarCadena(n, ok, (vecinos) => barajar(vecinos, randomInt));
}

module.exports = {claveDePareja, parejasVigentes, aIndices, hayCadena, sortearCadena};
