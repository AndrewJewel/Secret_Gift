# Exclusiones entre participantes — diseño

**Fecha:** 2026-09-25 · **Estado:** aprobado por el usuario, pendiente de plan

## Qué y por qué

El organizador puede decir que dos participantes **no se toquen** en el
sorteo (parejas, padres e hijos, hermanos). Es de lo más pedido en este tipo
de apps y sin ello el organizador no tiene salida: el sorteo es único y no se
puede repetir. Función **gratuita**.

## Decisiones tomadas

| Tema | Decisión |
|---|---|
| Dirección | Siempre **mutua**: excluir Juan–Ana = ninguno le regala al otro |
| Visibilidad | **Solo el organizador**. Los participantes no ven ninguna exclusión |
| Modelo | **Parejas**, marcadas desde la fila de cada persona (varias a la vez) |
| Comprobación | **Exacta** y **en la hoja, al marcar**; se repite al guardar y al sortear |
| Combinación imposible | La casilla se **bloquea**; nunca se guarda una combinación imposible |
| Momento | Solo **antes del sorteo**. Después quedan congeladas y no se usan |

## Por qué la comprobación es exacta y no una tabla

Que el sorteo sea posible depende de **qué** parejas se excluyen, no de
cuántas. Con 4 personas y 2 exclusiones:

- Ana–Beto y Carla–Dani → posible (Ana → Carla → Beto → Dani → Ana).
- Ana–Beto y Ana–Carla → imposible (Ana solo puede ir junto a Dani, y en la
  cadena necesita a alguien a cada lado).

Y con **3 personas, cualquier exclusión** lo hace imposible: la única cadena
posible, A → B → C → A, usa las tres parejas.

## 1. Datos

- `grupos/{codigo}/privado/data.exclusiones`: lista de cadenas `"idA|idB"`
  con los dos ids **ordenados**, así cada pareja existe una sola vez. Ese
  documento ya existe (guarda `reemplazos`) y las reglas lo cierran a todo
  cliente (`allow read, write: if false`). Por eso no va en el documento del
  grupo ni en los participantes, que se leen públicamente.
- Las parejas cuyo id ya no corresponde a un participante **se ignoran** al
  leer y al sortear. No se limpian al sacar a alguien: menos código y nada que
  pueda desincronizarse.

## 2. Servidor (`functions/index.js`)

Dos funciones nuevas, las dos con `exigirOrganizador(await autorizar(...))`:

- **`verExclusiones({codigo})`** → `{exclusiones: [[idA, idB], ...]}`, ya
  filtradas contra los participantes actuales.
- **`guardarExclusiones({codigo, participanteId, excluidos: [id...]})`** →
  deja las exclusiones **de esa persona** exactamente como vienen: añade las
  nuevas y quita las que ya no están. Devuelve la lista completa, como
  `verExclusiones`. En una transacción. Rechaza:
  - grupo ya sorteado → clave existente `grupo_ya_sorteado`;
  - ids que no son participantes → clave existente `participante_no_existe`;
  - `participanteId` dentro de `excluidos` → `excluirse_a_si_mismo`;
  - combinación resultante sin sorteo posible → `exclusiones_imposibles`.

`ejecutarSorteo` lee las exclusiones, las filtra y sortea con el módulo de
abajo. Si no hay cadena posible (por ejemplo, alguien se salió después de
marcar), responde `exclusiones_imposibles` y **no sortea**.

## 3. Algoritmo (`functions/sorteo.js`, sin dependencias)

Participantes = vértices; «puede regalarle» = arista, salvo las parejas
excluidas. Un sorteo válido es una **cadena circular única** (ciclo
hamiltoniano) sin aristas excluidas. Se conserva la forma actual del sorteo:
una sola cadena, barajada con `crypto.randomInt`.

- **`hayCadena(n, exclusiones)`** → booleano, exacto:
  1. Si alguien tiene menos de 2 personas permitidas (n ≥ 3), imposible.
  2. Si todos tienen al menos n/2 permitidas, **posible** sin buscar (teorema
     de Dirac). Resuelve al instante casi todos los grupos reales.
  3. Si no, búsqueda en profundidad con poda. Milisegundos para los tamaños
     de un grupo de regalos.
  - Casos especiales: n = 2 es posible solo sin exclusión entre los dos.
- **`sortearCadena(n, exclusiones, randomInt)`** → orden de índices, o `null`:
  1. Hasta 10.000 veces: barajar (Fisher–Yates, como hoy) y aceptar la primera
     cadena sin aristas excluidas. Muestreo por rechazo: **todas las cadenas
     válidas son igual de probables**, así que las exclusiones no dejan pistas.
  2. Si no sale: búsqueda en profundidad con orden aleatorio; `null` si no
     hay cadena.

La **misma** `hayCadena` existe en Dart (`lib/exclusiones.dart`) para la
comprobación instantánea en la app. Las dos versiones se prueban contra el
mismo archivo de casos (ver §6).

## 4. Pantalla (`pantalla_registro.dart`, solo organizador, solo antes del sorteo)

- En cada fila de participante, un icono nuevo (`Icons.block`, tooltip
  «Excluir participante») junto a editar y sacar.
- Debajo del nombre, solo en la vista del organizador: «No le toca: Ana,
  Pedro» si tiene exclusiones.
- Al tocar el icono se abre una hoja:
  - Título: **«Excluir participante»**.
  - Una casilla por cada otro participante, **solo con el nombre** (sin foto),
    marcadas según lo guardado.
  - Al marcar o desmarcar, se recalculan todas: la casilla que haría imposible
    el sorteo (con lo que ya hay marcado en la hoja) queda **deshabilitada**,
    con el texto «Haría imposible el sorteo». Desmarcar otra puede
    rehabilitarla.
  - Botones Cancelar / Guardar. Guardar llama a `guardarExclusiones` y usa la
    lista que devuelve.
- Junto al botón Sortear: «Se respetarán N exclusiones» (y lo mismo en la
  confirmación del sorteo). Si con los participantes actuales ya no hay
  sorteo posible, aviso «Con las exclusiones actuales no hay sorteo posible.
  Quita alguna.» y el botón **Sortear deshabilitado**.
- Carga: `verExclusiones` una vez al abrir el grupo como organizador antes del
  sorteo; después, lo que devuelva cada guardado. La lista de participantes
  ya llega en vivo; las parejas de quien no está se ignoran. Que alguien se
  una nunca empeora nada (solo da más opciones).

## 5. Errores y textos

Claves nuevas con su texto en `app_es.arb` y `app_en.arb`:
`exclusiones_imposibles`, `excluirse_a_si_mismo`, más los textos de la hoja
(título, «Haría imposible el sorteo», «No le toca: …», «Se respetarán N
exclusiones», el aviso de imposible).

## 6. Pruebas

- **`test/fixtures/casos_exclusiones.json`**: casos `{n, exclusiones,
  posible}` compartidos por Dart y JS. Como mínimo: 2 sin/con exclusión; 3 con
  una; 4 con dos parejas disjuntas (posible); 4 con dos que comparten persona
  (imposible); alguien excluido de todos; 6 con una familia de 3; 20 con
  pocas exclusiones.
- **Node (`node --test`)**: `hayCadena` contra los casos; `sortearCadena`
  nunca devuelve una cadena prohibida en miles de repeticiones y devuelve
  `null` en los imposibles; con 4 personas y 2 parejas, las dos cadenas
  válidas salen con frecuencias parecidas (uniformidad).
- **Flutter**: `hayCadena` contra los casos; prueba de widget de la hoja: en
  un grupo de 3, todas las casillas deshabilitadas.
- **Integración** (`scripts/probar.mjs`): guardar una exclusión, rechazar una
  imposible, sortear respetándola.

## Fuera de alcance

Exclusiones en una sola dirección · hogares · «no repetir el del año
pasado» · que los participantes vean las exclusiones · cambiar exclusiones
después del sorteo · que los reemplazos respeten exclusiones (un reemplazo
ocupa una plaza ya sorteada; no se vuelve a sortear).
