/// Gemelo en Dart de `functions/sorteo.js` (solo la comprobación): sirve para
/// bloquear al instante, en la hoja «Excluir participante», la casilla que
/// dejaría el grupo sin sorteo posible. El servidor vuelve a comprobarlo al
/// guardar y al sortear.
///
/// Los dos se prueban contra test/fixtures/casos_exclusiones.json: si se
/// toca uno, se toca el otro.
library;

/// Tope de pasos de la búsqueda; al pasarlo se contesta «no», lo prudente.
const _presupuestoBusqueda = 2000000;

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

  final camino = [0];
  final usado = List.filled(n, false)..[0] = true;
  var pasos = 0;
  bool extender() {
    if (++pasos > _presupuestoBusqueda) return false;
    final ultimo = camino.last;
    if (camino.length == n) return ok[ultimo][0];
    for (var v = 0; v < n; v++) {
      if (usado[v] || !ok[ultimo][v]) continue;
      usado[v] = true;
      camino.add(v);
      if (extender()) return true;
      camino.removeLast();
      usado[v] = false;
    }
    return false;
  }

  return extender();
}

/// Lo mismo, con ids y claves de pareja. Sin parejas vigentes no hay nada
/// que comprobar: el sorteo de siempre vale.
bool hayCadenaConIds(List<String> ids, Set<String> parejas) {
  final vigentes = parejasVigentes(parejas, ids);
  if (vigentes.isEmpty) return true;
  final indice = {for (var i = 0; i < ids.length; i++) ids[i]: i};
  return hayCadena(ids.length, [
    for (final clave in vigentes) [for (final id in clave.split('|')) indice[id]!],
  ]);
}
