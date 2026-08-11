# Reemplazar a un participante tras el sorteo — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que un grupo ya sorteado pueda sustituir a quien no puede seguir jugando, sin romper la cadena del sorteo ni dejar a un tercero comprando un regalo para alguien que ya no está.

**Architecture:** La plaza no se borra: cambia de dueño conservando su `{id}`, así que la cadena no se entera. Lo que sí hay que tocar es la plaza de un tercero — quien le regala a esa —, porque su `nombre_asignado` y `deseos_asignado` son copias denormalizadas. Para encontrarlo, `ejecutarSorteo` pasa a escribir el puntero inverso `recibe_de`.

**Tech Stack:** Cloud Functions v2 (Node 22, `firebase-admin` 14 modular), Firestore, Flutter 3.38.10 / Dart 3.10.9.

**Spec:** `docs/superpowers/specs/2026-08-09-reemplazar-participante-design.md`

**Rama prevista:** propia, a partir de `main`.

## Lo que el spec no resolvió, y este plan decide

El spec pide que **el formulario de quien canjea venga con el nombre de la
plaza ya escrito**, para que un grupo temático funcione sin un modo aparte:
si la plaza es «Gandalf», quedarse con Gandalf es no tocar nada.

Pero **el cliente no puede saber qué plaza es**. La relación token→plaza vive
en `grupos/{codigo}/privado/data`, que está cerrado a cero para el cliente
(ver `firestore.rules`). Y aunque los participantes sí son legibles, no hay
forma de saber cuál de ellos corresponde al token.

**Se añade una tercera función, `verReemplazo({codigo, token})`**, que
devuelve solo lo justo para pintar el formulario: el nombre actual de la
plaza y la temática del grupo. No revela nada nuevo — con el código del
grupo ya se pueden leer todos los nombres; lo único que añade es *cuál* de
ellos es el de esta invitación, que es precisamente lo que quien tiene el
token necesita saber.

## Global Constraints

- **Dart 3.10.9 / Flutter 3.38.10.** Nada de sintaxis de Dart 3.12.
- **`flutter analyze` sin advertencias** y **`flutter test` en verde** al cerrar cada tarea de cliente.
- **`firebase-admin` v14 es modular.** `admin.firestore()` y `admin.storage()` **no existen**: se usan `getFirestore`, `FieldValue`, `FieldPath` y `getStorage`, ya importados en `functions/index.js`.
- **El servidor no tiene tests unitarios.** Su verificación es `scripts/probar.mjs` contra las funciones desplegadas. Las tareas de servidor se cierran con revisión de código, no con ejecución.
- **Los ficheros generados de l10n están trackeados.** Tras tocar `lib/l10n/app_*.arb`: `flutter gen-l10n` y commitear también los tres `app_localizations*.dart`. `flutter test` NO los regenera.
- **Los dos ARB con el mismo conjunto de claves.** `app_en.arb` es la plantilla y necesita el bloque `@clave` con `description`; `app_es.arb` lleva solo la traducción.
- **Toda cadena visible pasa por `Textos.of(context)`.** Cero texto literal en la interfaz.
- **Nada de `Math.random`** para el token: se usa `crypto`, como el código de grupo y la cadena del sorteo.
- **`scripts/probar.mjs` es la única prueba del backend.** Mirar expresamente la higiene de las aserciones: en este fichero han aparecido **tres veces** comprobaciones que pasaban en verde sin comprobar nada.
- Mensajes de commit en español, explicando el porqué.
- **No se despliega hasta la última tarea.**

---

### Task 1: El puntero inverso `recibe_de`

**Files:**
- Modify: `functions/index.js` — el bucle de `ejecutarSorteo`

**Interfaces:**
- Produces: cada `participantes/{id}/privado/data` gana el campo `recibe_de`, con el id de quien le regala. Lo consumen las tareas 3 y 4.

**Contexto:** `nombre_asignado` y `deseos_asignado` son copias. Si una plaza cambia de persona, quien le regala tiene guardado el nombre y los deseos de quien ya no está — **y ese es el problema real que P4 viene a arreglar**, no el cambio de nombre. Para actualizarlo hay que saber quién regala a esa plaza, y hoy no hay forma directa.

- [ ] **Step 1: Escribir el puntero en el bucle del sorteo**

En `exports.ejecutarSorteo`, dentro del `for`, **añadir una escritura** junto a las que ya hay:

```js
    batch.set(participantePrivadoRef(codigo, docs[iRegala].id), {
      asignado_a: docRecibe.id,
      nombre_asignado: docRecibe.data().nombre,
      deseos_asignado: deseosRecibe,
    }, {merge: true});
    // El puntero INVERSO: quién le regala a quien recibe. La cadena ya se
    // conoce en las dos direcciones aquí dentro, así que escribirlo cuesta
    // una línea. Sin él, reemplazar a alguien obligaría a leer los privados
    // de todo el grupo buscando cuál apunta a esa plaza — y hay que
    // actualizar `nombre_asignado` de quien le regala o esa persona
    // compraría para quien ya no está.
    batch.set(participantePrivadoRef(codigo, docRecibe.id), {
      recibe_de: docs[iRegala].id,
    }, {merge: true});
    batch.update(docs[iRegala].ref, {tieneAmigo: true});
```

- [ ] **Step 2: Verificar la sintaxis**

Run: `cd functions && node --check index.js && cd ..`
Expected: sin salida.

- [ ] **Step 3: Commit**

```bash
git add functions/index.js
git commit -m "El sorteo deja escrito quién le regala a cada plaza"
```

Con un cuerpo que explique que sin ese puntero, reemplazar a alguien obligaría a barrer todos los privados del grupo.

---

### Task 2: `generarReemplazo` — el enlace de un solo uso

**Files:**
- Modify: `functions/index.js`

**Interfaces:**
- Consumes: `autorizar(codigo, uidDe(request))` y `exigirOrganizador`, que ya existen.
- Produces: `exports.generarReemplazo` — recibe `{codigo, participanteId}`, devuelve `{token}`. El token queda en `grupos/{codigo}/privado/data` bajo `reemplazos[token] = participanteId`.

- [ ] **Step 1: Escribir la función**

Añadirla **después de `borrarParticipante`**, para que las tres funciones que tratan «quién ocupa una plaza» queden juntas:

```js
// --- Reemplazar a alguien tras el sorteo -------------------------------
// Tras el sorteo la lista no cambia: `borrarParticipante` y
// `agregarParticipante` están cerrados. Eso deja un grupo sin salida si
// alguien no puede seguir jugando, y esta es esa salida: la plaza no se
// borra, cambia de dueño conservando su id, así que la cadena no se entera.

/**
 * El token es una LLAVE: quien lo tenga toma esa plaza. Por eso sale de
 * `crypto` y no de `Math.random`, igual que el código del grupo.
 */
function generarToken() {
  return randomBytes(24).toString("base64url");
}

exports.generarReemplazo = onCall(async (request) => {
  const codigo = (request.data?.codigo || "").trim();
  const participanteId = request.data?.participanteId;
  if (!codigo || !participanteId) {
    throw new HttpsError("invalid-argument", "Falta el grupo o el participante.", {clave: "faltan_datos"});
  }

  exigirOrganizador(await autorizar(codigo, uidDe(request)));

  const grupoSnap = await grupoRef(codigo).get();
  if (!grupoSnap.exists) {
    throw new HttpsError("not-found", "Ese grupo ya no existe.", {clave: "grupo_no_existe"});
  }
  // Antes del sorteo la salida correcta es borrar y volver a apuntarse, que
  // ya funciona. Reemplazar solo tiene sentido cuando la plaza tiene un
  // sitio en la cadena que hay que conservar.
  if (grupoSnap.data().sorteado !== true) {
    throw new HttpsError(
        "failed-precondition",
        "Este grupo todavía no ha sorteado: saca a esta persona y que se apunte otra.",
        {clave: "grupo_sin_sortear"},
    );
  }

  const plaza = await participanteRef(codigo, participanteId).get();
  if (!plaza.exists) {
    throw new HttpsError("not-found", "Ese participante ya no existe.", {clave: "participante_no_existe"});
  }

  const token = generarToken();

  // Una plaza, un token vivo. Generar otro para la misma plaza borra el
  // anterior: eso es lo que cumple "el organizador puede anularlo" sin
  // añadir un botón de anular. Se hace en transacción porque hay que leer
  // el mapa para saber cuáles borrar antes de escribir.
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(grupoPrivadoRef(codigo));
    const reemplazos = snap.data()?.reemplazos || {};
    const nuevos = {};
    for (const [t, id] of Object.entries(reemplazos)) {
      if (id !== participanteId) nuevos[t] = id;
    }
    nuevos[token] = participanteId;
    tx.set(grupoPrivadoRef(codigo), {reemplazos: nuevos}, {merge: true});
  });

  return {token};
});
```

- [ ] **Step 2: Importar `randomBytes`**

En la cabecera del fichero, donde ya se importa `randomInt`:

```js
const {randomInt, randomBytes} = require("node:crypto");
```

- [ ] **Step 3: Verificar**

```bash
cd functions && node --check index.js && node -e "console.log(Object.keys(require('./index.js')).length)" && cd ..
```
Expected: sintaxis limpia y **16** exports (los 15 de antes más este).

- [ ] **Step 4: Commit**

```bash
git add functions/index.js
git commit -m "Un enlace de un solo uso para la plaza que hay que reemplazar"
```

---

### Task 3: `verReemplazo` y `canjearReemplazo`

**Files:**
- Modify: `functions/index.js`

**Interfaces:**
- Consumes: `uidDe(request)`, `guardarAvatar`, `borrarAvatarPorUrl`, `vincularComoParticipante`, `usuarioRef`, y el `recibe_de` de la Tarea 1.
- Produces:
  - `exports.verReemplazo` — `{codigo, token}` → `{nombre, tematica}`.
  - `exports.canjearReemplazo` — `{codigo, token, nombre, deseos, avatarBase64}` → `{id}`.

**El punto que rompe el patrón de todas las demás funciones, y hay que respetarlo:** quien canjea **todavía no tiene vínculo con el grupo**, así que `autorizar()` le devolvería `rol: null` y `participanteId: null` siendo perfectamente legítimo. Estas dos usan **`uidDe(request)` a secas**: basta con ser una cuenta verificada, porque **la autorización la lleva el token**, igual que en el alta normal la lleva el código del grupo.

- [ ] **Step 1: `verReemplazo`**

```js
/**
 * Lo justo para pintar el formulario de quien canjea: el nombre actual de
 * la plaza y la temática del grupo.
 *
 * No revela nada nuevo — con el código ya se pueden leer todos los nombres
 * del grupo. Lo único que añade es CUÁL de ellos es el de esta invitación,
 * que es justo lo que quien tiene el token necesita saber.
 */
exports.verReemplazo = onCall(async (request) => {
  const codigo = (request.data?.codigo || "").trim();
  const token = (request.data?.token || "").trim();
  if (!codigo || !token) {
    throw new HttpsError("invalid-argument", "Falta el grupo o el enlace.", {clave: "faltan_datos"});
  }
  uidDe(request);

  const priv = await grupoPrivadoRef(codigo).get();
  const participanteId = (priv.data()?.reemplazos || {})[token];
  if (!participanteId) {
    throw new HttpsError("not-found", "Este enlace ya no vale.", {clave: "reemplazo_invalido"});
  }

  const plaza = await participanteRef(codigo, participanteId).get();
  if (!plaza.exists) {
    throw new HttpsError("not-found", "Esa plaza ya no existe.", {clave: "participante_no_existe"});
  }
  const grupo = await grupoRef(codigo).get();

  return {
    nombre: plaza.data().nombre || "",
    tematica: grupo.data()?.tematica || "",
  };
});
```

- [ ] **Step 2: `canjearReemplazo`**

```js
exports.canjearReemplazo = onCall(async (request) => {
  const codigo = (request.data?.codigo || "").trim();
  const token = (request.data?.token || "").trim();
  const nombre = (request.data?.nombre || "").trim();
  const deseos = (request.data?.deseos || "").trim();
  if (!codigo || !token || !nombre) {
    throw new HttpsError("invalid-argument", "Falta el grupo, el enlace o el nombre.", {clave: "faltan_datos_participante"});
  }

  // NO se usa `autorizar`: quien canjea todavía no tiene vínculo con el
  // grupo, así que devolvería rol y participanteId nulos para alguien
  // legítimo. La autorización la lleva el TOKEN.
  const uid = uidDe(request);

  const priv = await grupoPrivadoRef(codigo).get();
  const participanteId = (priv.data()?.reemplazos || {})[token];
  if (!participanteId) {
    throw new HttpsError("not-found", "Este enlace ya no vale.", {clave: "reemplazo_invalido"});
  }

  const plazaRef = participanteRef(codigo, participanteId);
  const plazaSnap = await plazaRef.get();
  if (!plazaSnap.exists) {
    throw new HttpsError("not-found", "Esa plaza ya no existe.", {clave: "participante_no_existe"});
  }

  // Una cuenta, una plaza por grupo. Misma regla que `agregarParticipante`
  // y por el mismo motivo: dos plazas de la misma persona dejarían una
  // huérfana dentro de la cadena.
  const miVinculo = (await usuarioRef(uid).get()).data()?.grupos?.[codigo];
  if (miVinculo?.participanteId) {
    const mia = await participanteRef(codigo, miVinculo.participanteId).get();
    if (mia.exists) {
      throw new HttpsError("already-exists", "Ya tienes una plaza en este grupo.", {clave: "ya_estas_en_el_grupo"});
    }
  }

  const privadoPlaza = await participantePrivadoRef(codigo, participanteId).get();
  const datosPlaza = privadoPlaza.data() || {};
  const cuentaAnterior = datosPlaza.cuenta;
  const avatarAnterior = plazaSnap.data().avatarUrl;

  // La imagen se sube ANTES de escribir en Firestore, como en el alta
  // normal: si falla, no queda una plaza a medias apuntando a un avatar
  // que no existe.
  const avatarUrl = await guardarAvatar(codigo, participanteId, request.data?.avatarBase64);
  const deseosNuevos = deseos || "¡Sorpréndeme!";

  const batch = db.batch();

  // La plaza conserva su id, su `asignado_a`, su `nombre_asignado` y su
  // `deseos_asignado`: quien entra regala a la misma persona. Eso es lo que
  // mantiene la cadena entera.
  batch.update(plazaRef, {nombre, avatarUrl: avatarUrl || ""});
  batch.set(participantePrivadoRef(codigo, participanteId), {
    cuenta: uid,
    deseos: deseosNuevos,
    // Máscara nueva: quien entra no hereda las palabras de quien se fue.
    mascara: FieldValue.delete(),
    mascaraRepeticion: FieldValue.delete(),
    ultimoMensajeMs: FieldValue.delete(),
  }, {merge: true});

  // EL ARREGLO DE VERDAD: quien le regala a esta plaza tiene guardados el
  // nombre y los deseos de quien ya no está, y compraría para esa persona.
  // `recibe_de` lo dice directamente; si no estuviera —grupo sorteado antes
  // de que ese campo existiera— se barren los privados buscando quién
  // apunta aquí.
  let quienRegala = datosPlaza.recibe_de;
  if (!quienRegala) {
    const todos = await grupoRef(codigo).collection("participantes").get();
    const privados = await Promise.all(
        todos.docs.map((d) => participantePrivadoRef(codigo, d.id).get()));
    const i = privados.findIndex((p) => p.data()?.asignado_a === participanteId);
    if (i >= 0) quienRegala = todos.docs[i].id;
  }
  if (quienRegala) {
    batch.set(participantePrivadoRef(codigo, quienRegala), {
      nombre_asignado: nombre,
      deseos_asignado: deseosNuevos,
    }, {merge: true});
  }

  // El token se gasta.
  batch.set(grupoPrivadoRef(codigo), {
    reemplazos: {[token]: FieldValue.delete()},
  }, {merge: true});

  await batch.commit();

  // Se despega la cuenta anterior. Mismo trato que en `borrarParticipante`:
  // al organizador se le conserva la entrada con `participanteId: null`
  // —quitarle la clave entera le quitaría el rol y dejaría el grupo
  // ingobernable—, y al resto se le borra.
  if (cuentaAnterior && cuentaAnterior !== uid) {
    const refAnterior = usuarioRef(cuentaAnterior);
    const snapAnterior = await refAnterior.get();
    if (snapAnterior.exists) {
      const vinculo = (snapAnterior.data().grupos || {})[codigo];
      await refAnterior.update(
          new FieldPath("grupos", codigo),
          vinculo?.rol === "organizador" ?
            {rol: "organizador", participanteId: null} :
            FieldValue.delete(),
      );
    }
  }

  await vincularComoParticipante(uid, codigo, participanteId);
  await borrarAvatarPorUrl(avatarAnterior);

  return {id: participanteId};
});
```

- [ ] **Step 3: Verificar**

```bash
cd functions && node --check index.js && node -e "console.log(Object.keys(require('./index.js')).length)" && cd ..
```
Expected: sintaxis limpia y **18** exports.

- [ ] **Step 4: Commit**

```bash
git add functions/index.js
git commit -m "La plaza cambia de dueño sin que la cadena se entere"
```

Con un cuerpo que explique lo que de verdad arregla: que quien le regalaba a esa plaza deje de tener guardado el nombre de quien ya no está.

---

### Task 4: Las claves de error nuevas

**Files:**
- Modify: `lib/funciones.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_es.arb`

**Interfaces:**
- Consumes: las claves que lanzan las tareas 2 y 3.
- Produces: las tres claves traducidas, que usan las tareas 6 y 7.

- [ ] **Step 1: Añadir las claves al `switch`**

En `MensajeLocalizado.texto` de `lib/funciones.dart`, junto a las demás:

```dart
        'reemplazo_invalido' => t.errorReemplazoInvalido,
        'grupo_sin_sortear' => t.errorGrupoSinSortear,
```

- [ ] **Step 2: `lib/l10n/app_en.arb`**

```json
  "errorReemplazoInvalido": "This link is no longer valid. Ask the organiser for a new one.",
  "@errorReemplazoInvalido": {"description": "The replacement token was already used, or the organiser generated a new one"},
  "errorGrupoSinSortear": "This group hasn't drawn yet. Remove this person and let someone else sign up.",
  "@errorGrupoSinSortear": {"description": "Tried to generate a replacement link before the draw, where removing works"},
```

- [ ] **Step 3: `lib/l10n/app_es.arb`**, sin bloques `@`:

```json
  "errorReemplazoInvalido": "Este enlace ya no vale. Pídele otro al organizador.",
  "errorGrupoSinSortear": "Este grupo todavía no ha sorteado. Saca a esta persona y que se apunte otra.",
```

- [ ] **Step 4: Regenerar y verificar**

```bash
flutter gen-l10n && flutter analyze && flutter test
```
Expected: `No issues found!` y todos los tests en verde, incluido `arb_paridad_test.dart`.

- [ ] **Step 5: Commit**

```bash
git add lib/funciones.dart lib/l10n/
git commit -m "Los dos errores del reemplazo, en los dos idiomas"
```

---

### Task 5: La invitación pendiente lleva el token

**Files:**
- Modify: `lib/invitacion_pendiente.dart`
- Modify: `lib/pantalla_raiz.dart` — `_capturarInvitacionDeLaUrl`

**Interfaces:**
- Produces: `InvitacionPendiente` gana `final String? reemplazo`. `guardarInvitacion` acepta un token opcional. Lo consume la Tarea 7.

**Contexto:** el enlace de reemplazo es `https://secretgift.app/?codigo=XXXX-YYYY&reemplazo=<token>`. Ese token **tiene que sobrevivir al registro**: quien lo recibe puede no tener cuenta todavía, y entre pinchar el enlace y llegar al grupo hay un registro entero y un viaje al buzón de correo.

Es el mismo motivo por el que la invitación normal se persiste en disco.

- [ ] **Step 1: Añadir el campo a `InvitacionPendiente`**

Añadir a la clase:

```dart
  /// Token del enlace de reemplazo, si la invitación venía de uno. Null en
  /// una invitación normal.
  ///
  /// Se persiste con el resto porque quien recibe un enlace de reemplazo
  /// puede no tener cuenta: entre pinchar y llegar al grupo hay un registro
  /// entero y un viaje al buzón. Sin guardarlo, ese token se perdería por
  /// el camino y el enlace quedaría gastado sin que nadie ocupara la plaza.
  final String? reemplazo;
```

Añadirlo al constructor como parámetro nombrado opcional, y a la lectura y escritura en `shared_preferences` con una clave nueva, `'invitacion_reemplazo'`, siguiendo el patrón de las que ya hay.

`guardarInvitacion` pasa a aceptar un tercer parámetro opcional `String? reemplazo`.

**Conserva el `try/catch` que ya envuelve cada acceso a `SharedPreferences`.** Está ahí porque con el almacenamiento bloqueado —Safari en privado, webview sin cookies— el plugin **lanza**, y quien llama corre en `initState` sin nadie que capture nada.

- [ ] **Step 2: Capturar el token de la URL**

En `_capturarInvitacionDeLaUrl` de `lib/pantalla_raiz.dart`, junto a la lectura del código:

```dart
    final reemplazo = Uri.base.queryParameters['reemplazo']?.trim();
```

Y pasarlo a `guardarInvitacion`.

**Ojo con la comprobación de invitación consumida:** hoy hay un `if (await invitacionYaConsumida(codigo)) return;` que evita que una recarga vuelva a meter a alguien en el mismo grupo. Con un token de reemplazo **hay que dejar pasar igualmente**: es un enlace distinto y con otro propósito. Añade a esa condición que solo aplique cuando no hay token:

```dart
    if (reemplazo == null && await invitacionYaConsumida(codigo)) return;
```

- [ ] **Step 3: Verificar**

```bash
flutter analyze && flutter test
```
Expected: limpio y en verde. `test/invitacion_pendiente_test.dart` ya existe: **añádele un caso** que compruebe que el token se guarda y se lee.

- [ ] **Step 4: Commit**

```bash
git add lib/invitacion_pendiente.dart lib/pantalla_raiz.dart test/invitacion_pendiente_test.dart
git commit -m "El token de reemplazo sobrevive al registro"
```

---

### Task 6: El organizador genera el enlace

**Files:**
- Modify: `lib/pantalla_registro.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_es.arb`

**Interfaces:**
- Consumes: `generarReemplazo` (Tarea 2) y las claves de error (Tarea 4).

**Contexto:** en la fila de cada participante ya hay dos botones para el organizador — corregir el nombre y sacar. Se añade un tercero, **visible solo si el grupo ya sorteó**.

- [ ] **Step 1: El icono en la fila**

En el `Row` del `trailing` de `_esOrganizador`, **antes del botón de sacar**:

```dart
                        // Solo tras el sorteo: antes, la salida correcta es
                        // sacar a esa persona y que se apunte otra, que ya
                        // funciona. Reemplazar existe para conservar un
                        // sitio en la cadena, y antes del sorteo no hay
                        // cadena que conservar.
                        if (_vinculo?.sorteado ?? false)
                          IconButton(
                            icon: Icon(Icons.swap_horiz,
                                color: _color.shade700),
                            tooltip: t.reemplazarTooltip,
                            onPressed: () => _reemplazar(id, nombre),
                          ),
```

**El botón de sacar debe seguir apareciendo**: el servidor lo rechaza tras el sorteo con un mensaje que explica que hay que reemplazar, y ese mensaje es cómo se descubre esta función.

- [ ] **Step 2: El diálogo de consecuencias y la llamada**

Añadir al State:

```dart
  /// Genera un enlace de un solo uso para que otra persona ocupe esa plaza.
  ///
  /// El diálogo dice lo que va a pasar en concreto, no un "¿estás seguro?":
  /// lo que se pierde y lo que NO cambia son cosas distintas y quien decide
  /// necesita las dos.
  Future<void> _reemplazar(String id, String nombre) async {
    final t = Textos.of(context);
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t.reemplazarTitulo(nombre)),
        content: Text(t.reemplazarAviso(nombre)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(t.cancelar)),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(t.reemplazarGenerar)),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    try {
      final r = await llamarFuncion('generarReemplazo', {
        'codigo': widget.codigo,
        'participanteId': id,
      });
      final enlace =
          'https://secretgift.app/?codigo=${widget.codigo}&reemplazo=${r['token']}';
      if (!mounted) return;
      await SharePlus.instance.share(
          ShareParams(text: t.reemplazarCompartir(nombre, enlace)));
    } catch (e) {
      if (!mounted) return;
      _avisar('⚠️ ${e is FuncionError ? e.texto(t) : t.errorInesperado(e.toString())}');
    }
  }
```

Si el método de aviso del fichero no se llama `_avisar`, usar el que haya.

- [ ] **Step 3: Las claves nuevas**

En `app_en.arb` (con `@` y `placeholders` donde lleven parámetro) y `app_es.arb`:

| Clave | Inglés | Español |
|---|---|---|
| `reemplazarTooltip` | `Replace this person` | `Reemplazar a esta persona` |
| `reemplazarTitulo` | `Replace {nombre}` | `Reemplazar a {nombre}` |
| `reemplazarAviso` | `{nombre}'s place will pass to someone else, who will keep giving to the same person.\n\n· Whoever gives to {nombre} won't change, but will see a different name and wishes.\n· {nombre} will lose access to the group.\n· What {nombre} wrote in the chat stays, under their mask.` | `La plaza de {nombre} pasará a otra persona, que seguirá regalando a quien le tocaba.\n\n· Quien le regala a {nombre} NO cambia, pero verá otro nombre y otros deseos.\n· {nombre} perderá el acceso al grupo.\n· Lo que {nombre} escribió en el chat se queda, con su máscara.` |
| `reemplazarGenerar` | `Create link` | `Generar enlace` |
| `reemplazarCompartir` | `You're taking {nombre}'s place in our Secret Santa. Open this link: {enlace}` | `Vas a ocupar el lugar de {nombre} en nuestro amigo secreto. Abre este enlace: {enlace}` |

Las que llevan `{nombre}` o `{enlace}` necesitan su bloque `placeholders` en `app_en.arb`, como ya hacen otras claves del fichero.

- [ ] **Step 4: Regenerar y verificar**

```bash
flutter gen-l10n && flutter analyze && flutter test
```
Expected: limpio y en verde.

- [ ] **Step 5: Commit**

```bash
git add lib/pantalla_registro.dart lib/l10n/
git commit -m "El organizador puede pasarle una plaza a otra persona"
```

---

### Task 7: Quien canjea el enlace

**Files:**
- Modify: `lib/pantalla_registro.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_es.arb`

**Interfaces:**
- Consumes: `verReemplazo` y `canjearReemplazo` (Tarea 3), y el `reemplazo` de la invitación pendiente (Tarea 5).

**Contexto:** `pantalla_registro.dart` ya tiene el formulario de alta —nombre, deseos y avatar— para quien todavía no está en el grupo. Esta tarea hace que, **si hay un token de reemplazo pendiente para este grupo**, ese mismo formulario canjee en vez de dar de alta, y venga con el nombre de la plaza ya escrito.

**El nombre precargado es lo que hace que los grupos temáticos funcionen sin un modo aparte:** si la plaza es «Gandalf», quedarse con Gandalf es no tocar nada, y cambiarlo es escribir encima.

- [ ] **Step 1: Leer el token al abrir la pantalla**

En el `initState` o donde la pantalla ya lee la invitación pendiente, si hay un `reemplazo` para este código, llamar a `verReemplazo` y guardar el resultado en el State:

```dart
  String? _tokenReemplazo;
  String _nombrePlaza = '';

  Future<void> _mirarSiHayReemplazo() async {
    final inv = await leerInvitacion();
    if (inv == null || inv.codigo != widget.codigo || inv.reemplazo == null) return;
    try {
      final r = await llamarFuncion('verReemplazo', {
        'codigo': widget.codigo,
        'token': inv.reemplazo,
      });
      if (!mounted) return;
      setState(() {
        _tokenReemplazo = inv.reemplazo;
        _nombrePlaza = r['nombre'] as String? ?? '';
        // El nombre de la plaza, precargado. En un grupo temático quedarse
        // con el personaje es no tocar nada; en uno normal se escribe
        // encima. Sin modos ni banderas.
        _nombre.text = _nombrePlaza;
      });
    } on FuncionError catch (e) {
      // Un token gastado o anulado no debe dejar la pantalla inservible:
      // se avisa y se sigue con el alta normal, que para un grupo ya
      // sorteado el servidor rechazará con su propio mensaje.
      if (!mounted) return;
      _avisar('⚠️ ${e.texto(Textos.of(context))}');
    }
  }
```

Si el controlador del nombre no se llama `_nombre`, usar el que haya.

- [ ] **Step 2: Que el botón de alta canjee cuando toca**

Donde hoy se llama a `agregarParticipante`, ramificar:

```dart
      final creado = _tokenReemplazo != null
          ? await llamarFuncion('canjearReemplazo', {
              'codigo': widget.codigo,
              'token': _tokenReemplazo,
              'nombre': _nombre.text.trim(),
              'deseos': _deseos.text.trim(),
              if (avatarBase64 != null) 'avatarBase64': avatarBase64,
            })
          : await llamarFuncion('agregarParticipante', { /* lo que ya había */ });
```

Conservar tal cual lo que venga después: el marcado de la invitación como consumida y la actualización del vínculo.

- [ ] **Step 3: Un aviso en el formulario cuando es un reemplazo**

Sobre el campo del nombre, si `_tokenReemplazo != null`, mostrar `t.reemplazarOcupasPlaza(_nombrePlaza)`. Quien llega tiene que saber que está ocupando el sitio de alguien y no apuntándose de cero.

- [ ] **Step 4: Las claves nuevas**

| Clave | Inglés | Español |
|---|---|---|
| `reemplazarOcupasPlaza` | `You're taking {nombre}'s place. Keep the name or change it to yours.` | `Vas a ocupar el lugar de {nombre}. Deja el nombre o cámbialo por el tuyo.` |

- [ ] **Step 5: Regenerar y verificar**

```bash
flutter gen-l10n && flutter analyze && flutter test
```
Expected: limpio y en verde.

- [ ] **Step 6: Commit**

```bash
git add lib/pantalla_registro.dart lib/l10n/
git commit -m "Quien recibe el enlace ocupa la plaza, con su nombre ya escrito"
```

---

### Task 8: Los casos de `probar.mjs`

**Files:**
- Modify: `scripts/probar.mjs`

**Contexto:** es la **única** prueba que tiene el backend. Y en este fichero han aparecido **tres veces** aserciones que pasaban en verde sin comprobar nada, así que hay que mirar la higiene expresamente.

Los casos van **después del sorteo**, donde ya está la batería que comprueba que no se puede sacar ni meter a nadie.

- [ ] **Step 1: Los seis casos**

```js
  // --- Reemplazar a alguien tras el sorteo ---
  // La salida que faltaba: la plaza no se borra, cambia de dueño.

  await debeFallar("un token inventado no vale", "reemplazo_invalido",
      () => llamar("canjearReemplazo",
          {codigo, token: "inventado", nombre: "Nadie", deseos: ""}, tokenParticipante));

  const {token: tokenR} = await llamar("generarReemplazo",
      {codigo, participanteId: idOtraPersona}, tokenOrganizador);
  ok("generarReemplazo devuelve un token", typeof tokenR === "string" && tokenR.length > 20,
      `llegó ${JSON.stringify(tokenR)}`);

  // Generar otro para la MISMA plaza invalida el anterior: eso es lo que
  // cumple "el organizador puede anularlo" sin un botón de anular.
  const {token: tokenR2} = await llamar("generarReemplazo",
      {codigo, participanteId: idOtraPersona}, tokenOrganizador);
  await debeFallar("generar otro token invalida el anterior", "reemplazo_invalido",
      () => llamar("canjearReemplazo",
          {codigo, token: tokenR, nombre: "Nadie", deseos: ""}, tokenParticipante));

  // Quien YA tiene plaza en el grupo no puede coger otra.
  await debeFallar("quien ya está dentro no puede canjear", "ya_estas_en_el_grupo",
      () => llamar("canjearReemplazo",
          {codigo, token: tokenR2, nombre: "Nadie", deseos: ""}, tokenOrganizador));
```

- [ ] **Step 2: El caso que prueba que P4 sirve para algo**

**Sin este, todo lo demás puede pasar y el problema seguir ahí.**

```js
  // EL CASO QUE IMPORTA. Reemplazar cambia el nombre de una plaza, pero lo
  // que de verdad arregla es la de un TERCERO: quien le regala a esa plaza
  // tiene guardados el nombre y los deseos de quien ya no está, y compraría
  // para esa persona.
  //
  // Se comprueba revelando el amigo secreto de la organizadora. Si le toca
  // la plaza reemplazada, tiene que ver el nombre NUEVO.
  const antes = await llamar("verAmigoSecreto",
      {codigo, pin: PIN_RESCATE}, tokenOrganizador);

  await llamar("canjearReemplazo",
      {codigo, token: tokenR2, nombre: "Persona Nueva", deseos: "Un libro"},
      tokenTercero);

  const despues = await llamar("verAmigoSecreto",
      {codigo, pin: PIN_RESCATE}, tokenOrganizador);

  if (antes.nombreAmigo === nombreDeLaPlazaReemplazada) {
    ok("quien le regalaba ve el nombre NUEVO",
        despues.nombreAmigo === "Persona Nueva",
        `esperaba "Persona Nueva", ve "${despues.nombreAmigo}"`);
    ok("y también los deseos nuevos",
        despues.deseosAmigo === "Un libro",
        `esperaba "Un libro", ve "${despues.deseosAmigo}"`);
  } else {
    // Con dos personas la cadena es circular y siempre toca, pero si el
    // montaje cambiara y no tocara, hay que DECIRLO en vez de dar por
    // probado algo que no se ejecutó.
    ok("AVISO: el caso clave no se ejercitó — la organizadora no le regala a la plaza reemplazada", false,
        `su amigo es "${antes.nombreAmigo}"`);
  }
```

- [ ] **Step 3: Montar el escenario**

Los casos de arriba necesitan **una tercera cuenta** —quien canjea— y los identificadores de las plazas. Hay que:

- Añadir un `EMAIL_TERCERO` con el mismo patrón que los otros dos y crear su cuenta en el tramo `--crear`, mandándole también su enlace de verificación.
- Ampliar el mensaje del paso 1 para que imprima los **tres** correos, y el de `--seguir` para que acepte tres.
- Guardar el `id` de la plaza de la cuenta participante al apuntarse, para pasarlo como `idOtraPersona`, y su nombre para `nombreDeLaPlazaReemplazada`.

**Actualiza también la cabecera del fichero**, que hoy explica que se usan dos cuentas y por qué. Ahora son tres y el motivo de la tercera es distinto: quien canjea **no puede ser** ninguna de las que ya tienen plaza.

- [ ] **Step 4: Verificar la sintaxis**

```bash
node --check scripts/probar.mjs
```
Expected: sin salida.

**No se puede ejecutar la batería todavía**: las funciones nuevas no están desplegadas. Su ejecución es parte de la Tarea 9.

- [ ] **Step 5: Repasar la higiene de las aserciones**

Antes de commitear, releer lo escrito buscando: aserciones con una constante en vez de un valor del servidor, `catch` que den por bueno cualquier error, y comprobaciones que pasarían por un motivo distinto al pretendido. **Es el tercer defecto de esta clase que aparece en este fichero.**

- [ ] **Step 6: Commit**

```bash
git add scripts/probar.mjs
git commit -m "El reemplazo, probado por donde de verdad puede fallar"
```

---

### Task 9: Desplegar y verificar

- [ ] **Step 1: Verificación previa**

```bash
flutter analyze && flutter test && cd functions && node --check index.js && cd ..
```

- [ ] **Step 2: Desplegar**

```bash
firebase deploy --only functions
flutter build web --release && firebase deploy --only hosting
```

Las tres funciones nuevas serán `create`, no `update`.

- [ ] **Step 3: La batería, en sus dos tramos**

```bash
node scripts/probar.mjs --crear --dominio <correo real del humano>
```
Pinchar los **tres** enlaces del buzón, y luego:
```bash
node scripts/probar.mjs --seguir <correo1> <correo2> <correo3>
```
Expected: todo en verde, incluidos los seis casos nuevos.

- [ ] **Step 4: En dispositivo — lo que ninguna prueba cubre**

1. Crear un grupo con dos personas y sortear
2. Como organizador, pulsar **reemplazar** en la fila de la otra persona
3. Leer el aviso y generar el enlace
4. Abrirlo **en otro navegador con una tercera cuenta**
5. Comprobar que el formulario **viene con el nombre de la plaza escrito**
6. Canjear
7. **Revelar el amigo secreto del organizador y ver el nombre nuevo** — es lo que P4 viene a arreglar
8. Comprobar que el enlace **ya no vale** una segunda vez

- [ ] **Step 5: Bitácora y cierre**

`bitacora/2026-08-11-reemplazar-participante.md`, con lo que costó y lo que enseñó. Y cerrar la rama con `superpowers:finishing-a-development-branch`.

## Fuera de alcance

- **Avisar a quien regalaba** de que su amigo secreto cambió. Es un subsistema aparte con su propio diseño (`2026-08-09-notificaciones-push-design.md`) y P4 se puede usar sin él: el diálogo le dice al organizador que avise.
- **Reordenar la cadena.** Quien entra hereda la asignación tal cual, así que **quien se fue sabe a quién regala quien entra**. Aceptado a sabiendas el 2026-08-09.
- **Que el enlace caduque por tiempo.** Es de un solo uso y el organizador lo anula generando otro.
- **Un historial** de quién ocupó cada plaza.
