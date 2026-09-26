// El sorteo como problema de grafos, sin Firestore: así se prueba solo.
//
// Participantes = vértices; «puede regalarle» = arista, salvo las parejas
// excluidas (siempre mutuas). Un sorteo válido es UNA cadena circular que
// pasa por todos (un ciclo hamiltoniano) sin usar ninguna arista excluida.
//
// Tiene un gemelo en Dart (lib/exclusiones.dart) para que la app bloquee la
// casilla al instante. Los dos se prueban contra
// test/fixtures/casos_exclusiones.json, y los dos numeran a la gente en el
// mismo orden (ids ordenados) y buscan igual paso a paso: así, incluso si
// algún día la búsqueda se queda sin presupuesto, contestan lo mismo. Si se
// toca uno, se toca el otro.

// Tope de pasos de la búsqueda. Con la poda no se alcanza en grupos reales;
// si se alcanzara, se contesta «no» (bloquea la casilla / no sortea), que es
// lo prudente.
const PRESUPUESTO_BUSQUEDA = 20000;
const INTENTOS_BARAJADO = 10000;
const INTENTOS_REETIQUETADO = 8;

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

// Índices sobre los ids ORDENADOS, igual que `hayCadenaConIds` en Dart: la
// app y el servidor tienen que numerar a la gente igual para contestar igual.
function idsOrdenados(ids) {
  return [...ids].sort();
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

// Búsqueda en profundidad de una cadena circular. Determinista: mismo grafo,
// mismo resultado (y el gemelo Dart hace exactamente los mismos pasos).
//
// - Empieza por quien tiene menos opciones.
// - Prueba primero al vecino con menos salidas libres (regla de Warnsdorff):
//   coloca antes a los más restringidos, que es donde se atasca una búsqueda
//   ingenua (p. ej. una familia grande que no puede tocarse entre sí).
// - Poda: si a alguien sin colocar le quedan menos de dos vecinos posibles
//   (entre los que faltan, el final del camino y el inicio), esa rama no
//   tiene salida.
//
// Devuelve el orden o null (no existe, o se acabó el presupuesto).
function buscarCadena(n, ok) {
  const grado = ok.map((fila) => fila.filter(Boolean).length);
  let inicio = 0;
  for (let v = 1; v < n; v++) if (grado[v] < grado[inicio]) inicio = v;

  const camino = [inicio];
  const usado = new Array(n).fill(false);
  usado[inicio] = true;
  let pasos = 0;

  const libres = (v) => {
    let c = 0;
    for (let w = 0; w < n; w++) if (!usado[w] && w !== v && ok[v][w]) c++;
    return c;
  };
  const sinSalida = (fin) => {
    for (let u = 0; u < n; u++) {
      if (usado[u]) continue;
      let c = (ok[u][fin] ? 1 : 0) + (ok[u][inicio] && fin !== inicio ? 1 : 0);
      for (let w = 0; w < n && c < 2; w++) if (!usado[w] && w !== u && ok[u][w]) c++;
      if (c < 2) return true;
    }
    return false;
  };

  function extender() {
    if (++pasos > PRESUPUESTO_BUSQUEDA) return false;
    const ultimo = camino[camino.length - 1];
    if (camino.length === n) return ok[ultimo][inicio];
    const candidatos = [];
    for (let v = 0; v < n; v++) if (!usado[v] && ok[ultimo][v]) candidatos.push([libres(v), v]);
    candidatos.sort((a, b) => a[0] - b[0] || a[1] - b[1]);
    for (const [, v] of candidatos) {
      usado[v] = true;
      camino.push(v);
      if (!sinSalida(v) && extender()) return true;
      camino.pop();
      usado[v] = false;
    }
    return false;
  }
  return extender() ? camino : null;
}

// Un grupo de gente que no puede tocarse entre sí (p. ej. una familia) no
// puede pasar de la mitad del grupo: en la cadena, entre dos de ellos tiene
// que ir siempre alguien de fuera. Se busca con avidez desde cada persona;
// no encuentra siempre el mayor, pero sí el caso real (una familia grande),
// y ahorra a la búsqueda recorrerlo todo para acabar diciendo que no.
function demasiadosSinTocarse(n, ok) {
  for (let inicio = 0; inicio < n; inicio++) {
    const grupo = [inicio];
    for (let v = 0; v < n; v++) {
      if (v !== inicio && grupo.every((u) => !ok[u][v])) grupo.push(v);
    }
    if (2 * grupo.length > n) return true;
  }
  return false;
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
  if (demasiadosSinTocarse(n, ok)) return false;
  return buscarCadena(n, ok) !== null;
}

// Una cadena al azar sin eslabones excluidos, o null si no existe.
//
// 1. Barajar y aceptar la primera válida (muestreo por rechazo): así TODAS
//    las cadenas válidas son igual de probables y las exclusiones no dejan
//    pistas de quién le tocó a quién. Sin exclusiones, la primera barajada
//    ya vale: es el sorteo de siempre. Es el camino de casi todo grupo.
// 2. Solo si el grupo está tan restringido que casi ninguna barajada vale
//    (p. ej. 20 personas con una familia de 10): buscar sobre el grupo
//    renumerado al azar, con sentido y punto de partida al azar.
//    ponytail: este respaldo no es uniforme; si algún día importa, cambiarlo
//    por un muestreo MCMC sobre ciclos.
// 3. Si ni así, la búsqueda sin renumerar: es la misma que usan `hayCadena`
//    y la app, así que nunca se sortea «imposible» algo que se dio por bueno.
//    (Si Dirac dio el sí sin buscar, en las pruebas de estrés el paso 2 ya
//    encuentra la cadena siempre.)
function sortearCadena(n, prohibidas, randomInt) {
  // La misma respuesta que la app (y que `guardarExclusiones`): lo que allí
  // se dio por imposible no se sortea, y lo que se dio por posible sí.
  if (!hayCadena(n, prohibidas)) return null;
  const ok = matrizPermitidos(n, prohibidas);
  const esValida = (orden) => orden.every((a, i) => ok[a][orden[(i + 1) % n]]);
  const todos = Array.from({length: n}, (_, i) => i);
  for (let intento = 0; intento < INTENTOS_BARAJADO; intento++) {
    const orden = barajar(todos, randomInt);
    if (esValida(orden)) return orden;
  }

  const aleatorizar = (cadena) => {
    const giro = randomInt(n);
    const girada = [...cadena.slice(giro), ...cadena.slice(0, giro)];
    return randomInt(2) === 0 ? girada : girada.reverse();
  };
  for (let intento = 0; intento < INTENTOS_REETIQUETADO; intento++) {
    const etiqueta = barajar(todos, randomInt);
    const okEtiquetado = etiqueta.map((a) => etiqueta.map((b) => ok[a][b]));
    const cadena = buscarCadena(n, okEtiquetado);
    if (cadena) return aleatorizar(cadena.map((i) => etiqueta[i]));
  }
  // hayCadena ya dijo que sí: o lo dijo Dirac, o esta misma búsqueda lo
  // encontró.
  const cadena = buscarCadena(n, ok);
  return cadena ? aleatorizar(cadena) : null;
}

module.exports = {
  claveDePareja, parejasVigentes, idsOrdenados, aIndices, hayCadena, sortearCadena,
};
