/// Gemelo en Dart de `functions/sorteo.js` (solo la comprobación): sirve para
/// bloquear al instante, en la hoja «Excluir participante», la casilla que
/// dejaría el grupo sin sorteo posible. El servidor vuelve a comprobarlo al
/// guardar y al sortear.
///
/// Los dos se prueban contra test/fixtures/casos_exclusiones.json, numeran a
/// la gente igual (ids ordenados) y buscan igual paso a paso: así contestan
/// lo mismo incluso en el caso raro de que la búsqueda agote su presupuesto.
/// Si se toca uno, se toca el otro.
library;

/// Tope de pasos de la búsqueda; al pasarlo se contesta «no», lo prudente.
/// Tiene que ser el mismo que PRESUPUESTO_BUSQUEDA de functions/sorteo.js.
const _presupuestoBusqueda = 20000;

/// Clave de una pareja excluida: los dos ids ordenados, así cada pareja
/// existe una sola vez y vale en las dos direcciones.
String clavePareja(String a, String b) => a.compareTo(b) < 0 ? '$a|$b' : '$b|$a';

/// Las parejas con las dos personas todavía en el grupo.
Set<String> parejasVigentes(Iterable<String> guardadas, List<String> ids) {
  final presentes = ids.toSet();
  return {
    for (final clave in guardadas)
      if (clave.split('|').every(presentes.contains)) clave,
  };
}

/// Un grupo que no puede tocarse entre sí (una familia) no puede pasar de la
/// mitad: en la cadena, entre dos de ellos va siempre alguien de fuera. Igual
/// que `demasiadosSinTocarse` en functions/sorteo.js.
bool _demasiadosSinTocarse(int n, List<List<bool>> ok) {
  for (var inicio = 0; inicio < n; inicio++) {
    final grupo = [inicio];
    for (var v = 0; v < n; v++) {
      if (v != inicio && grupo.every((u) => !ok[u][v])) grupo.add(v);
    }
    if (2 * grupo.length > n) return true;
  }
  return false;
}

/// Búsqueda con poda, idéntica a `buscarCadena` de functions/sorteo.js:
/// empieza por quien tiene menos opciones, prueba primero al vecino con menos
/// salidas libres y corta la rama si a alguien sin colocar le quedan menos de
/// dos vecinos posibles.
bool _buscarCadena(int n, List<List<bool>> ok) {
  final grado = [for (final fila in ok) fila.where((x) => x).length];
  var inicio = 0;
  for (var v = 1; v < n; v++) {
    if (grado[v] < grado[inicio]) inicio = v;
  }
  final camino = [inicio];
  final usado = List.filled(n, false)..[inicio] = true;
  var pasos = 0;

  int libres(int v) {
    var c = 0;
    for (var w = 0; w < n; w++) {
      if (!usado[w] && w != v && ok[v][w]) c++;
    }
    return c;
  }

  bool sinSalida(int fin) {
    for (var u = 0; u < n; u++) {
      if (usado[u]) continue;
      var c = (ok[u][fin] ? 1 : 0) + (ok[u][inicio] && fin != inicio ? 1 : 0);
      for (var w = 0; w < n && c < 2; w++) {
        if (!usado[w] && w != u && ok[u][w]) c++;
      }
      if (c < 2) return true;
    }
    return false;
  }

  bool extender() {
    if (++pasos > _presupuestoBusqueda) return false;
    final ultimo = camino.last;
    if (camino.length == n) return ok[ultimo][inicio];
    final candidatos = [
      for (var v = 0; v < n; v++)
        if (!usado[v] && ok[ultimo][v]) (libres(v), v),
    ]..sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
    for (final (_, v) in candidatos) {
      usado[v] = true;
      camino.add(v);
      if (!sinSalida(v) && extender()) return true;
      camino.removeLast();
      usado[v] = false;
    }
    return false;
  }

  return extender();
}

/// ¿Existe una cadena circular única que no use ninguna pareja prohibida?
bool hayCadena(int n, List<List<int>> prohibidas) {
  if (n < 2) return false;
  final ok = List.generate(n, (i) => List.generate(n, (j) => i != j));
  for (final p in prohibidas) {
    ok[p[0]][p[1]] = false;
    ok[p[1]][p[0]] = false;
  }
  if (n == 2) return ok[0][1];
  final grado = [for (final fila in ok) fila.where((x) => x).length];
  // Cada persona necesita a alguien a cada lado en la cadena.
  if (grado.any((g) => g < 2)) return false;
  // Teorema de Dirac: todos con la mitad del grupo o más → existe seguro.
  if (grado.every((g) => 2 * g >= n)) return true;
  if (_demasiadosSinTocarse(n, ok)) return false;
  return _buscarCadena(n, ok);
}

/// Lo mismo, con ids y claves de pareja. Sin parejas vigentes no hay nada
/// que comprobar: el sorteo de siempre vale. Los ids se ordenan, como en el
/// servidor (`idsOrdenados`).
bool hayCadenaConIds(List<String> ids, Set<String> parejas) {
  final vigentes = parejasVigentes(parejas, ids);
  if (vigentes.isEmpty) return true;
  final ordenados = [...ids]..sort();
  final indice = {for (var i = 0; i < ordenados.length; i++) ordenados[i]: i};
  return hayCadena(ordenados.length, [
    for (final clave in vigentes) [for (final id in clave.split('|')) indice[id]!],
  ]);
}
