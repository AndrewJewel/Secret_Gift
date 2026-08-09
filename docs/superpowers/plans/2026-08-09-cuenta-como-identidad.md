# Plan de implementación — La cuenta como identidad

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que la cuenta sea la única credencial de autorización de la app, con un solo PIN global de 4 dígitos que protege exclusivamente revelar el amigo secreto.

**Architecture:** `usuarios/{nick}.grupos` pasa de array a mapa indexado por código de grupo, lo que hace estructuralmente imposible el duplicado que hoy sale en "Mis grupos". Un único helper `autorizar()` en el backend verifica la cuenta y devuelve tu vínculo con el grupo (`rol` + `participanteId`), sustituyendo a los tres verificadores de PIN. El cliente deja de guardar identidades en disco: las recibe del servidor.

**Tech Stack:** Flutter 3.38.10 · Dart 3.10.9 · `shared_preferences` · `cloud_firestore` · Cloud Functions (Node 20, sin arnés de test) · `bcryptjs` · l10n por ARB con clase generada `Textos`.

**Spec:** `docs/superpowers/specs/2026-08-09-cuenta-como-identidad-design.md`

## Global Constraints

- **Dart 3.10.9.** No usar features de Dart 3.12 (private named parameters, primary constructors): no compilan.
- **Todo texto de interfaz pasa por ARB**, en `lib/l10n/app_en.arb` y `lib/l10n/app_es.arb`. **Los dos ficheros deben tener exactamente el mismo conjunto de claves.** La Task 1 añade un test que lo comprueba; a partir de ahí, romperlo hace fallar `flutter test`.
- **`app_en.arb` es la plantilla** (`l10n.yaml`). La clase generada se llama `Textos`, se accede con `Textos.of(context)`, y `flutter gen-l10n` corre solo durante `flutter build` / `flutter run` — **no** durante `flutter test`. Si un test necesita una clave nueva, hay que correr `flutter gen-l10n` a mano antes.
- **Los ficheros generados de l10n están trackeados en git** (`lib/l10n/app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_es.dart` — `git ls-files lib/l10n/` los lista, y `.gitignore` no los excluye). **Toda tarea que toque un `.arb` tiene que commitear también los tres generados**, en el mismo commit o en el siguiente. Si no, un checkout limpio tiene las claves nuevas en el ARB y el Dart viejo, y no compila.
- **Inglés es el idioma por defecto.**
- **La barra es `flutter analyze` sin una sola advertencia, al final de CADA tarea.** El proyecto está así hoy y no debe dejar de estarlo ni entre tareas. Por eso las claves ARB nuevas se añaden al principio (Task 1) y las muertas se borran al final (Task 12): borrarlas antes que a sus consumidores dejaría el árbol roto durante diez tareas, y un `analyze` que ya falla deja de avisar de los errores que sí importan.
- **Comentarios en español**, explicando el *porqué*, como el resto del código.
- **`SharedPreferences` nunca debe tumbar la app**: todo acceso va envuelto en `try/catch`, como en `lib/sesion.dart`.
- **Estilo:** reutilizar los widgets de `lib/glass.dart` (`GlassCard`, `GlassAppBar`, `GlassTextField`, `GlassButton`, `GlassOutlineButton`), el fondo `FondoNeutro` (`lib/tematica.dart`), el tema `temaGlass(colorNeutro)` (`lib/ocasion.dart`) y el color `colorNeutro` (`lib/glass.dart`).
- **Todo error de Cloud Function lleva una clave estable** en `details.clave`, y el cliente la traduce en `MensajeLocalizado.texto()` (`lib/funciones.dart:35`). Una clave nueva en el servidor exige su `case` en ese `switch` y su clave ARB.
- **Los códigos de grupo llevan guion** (`ABCD-2345`, ver `generarCodigo()` en `functions/index.js:11`). Como clave de mapa no dan problema; **como ruta de campo en texto, sí**. Toda escritura o borrado que apunte a `grupos.{codigo}` usa `new admin.firestore.FieldPath("grupos", codigo, ...)`, nunca una cadena con puntos.

### Rama

Trabajar en una rama nueva a partir de `flujo-cuenta`:

```bash
git checkout flujo-cuenta
git checkout -b cuenta-como-identidad
```

`main` sigue en `44bc51b` y **producción corre código que solo existe en `flujo-cuenta`**. Partir de `main` trabajaría sobre lo viejo.

### Tres correcciones al spec, verificadas contra el repo

**`scratchpad/probar.ps1` no existe.** El spec dice "reescribir"; no hay nada que reescribir. No está trackeado, no está en `.gitignore` y no aparece en el historial de git — vivía en un directorio de sesión y se perdió. La Task 12 lo **crea** dentro del repo, en Node (`scripts/probar.mjs`), para que no vuelva a perderse.

**`functions/` no tiene arnés de test.** Su `package.json` solo declara `bcryptjs`, `firebase-admin` y `firebase-functions`. Las tareas de backend NO llevan ciclo TDD: se verifican desplegando y pasándoles el script de integración de la Task 12. No inventar un framework de test para Node en este plan.

**Adición al spec: `cuenta` en el privado del participante.** El spec no lo menciona y sin ello queda un cabo suelto conocido. Hoy `borrarParticipante` no puede limpiar el puntero de `usuarios/{x}.grupos` porque no sabe de qué cuenta es esa plaza — es el bug diferido "borrarParticipante no quita el puntero" de la bitácora del 2026-08-08. Con el mapa nuevo sí se puede limpiar, pero hace falta saber a quién. `agregarParticipante` guardará `cuenta: <clave normalizada>` en `participantes/{id}/privado/data`, que es un documento cerrado a cero para el cliente (`firestore.rules`). P4 lo necesitará igual para liberar una plaza.

---

### Task 1: Claves de texto nuevas, y el test que impide que los ARB se desincronicen

Las claves que **nacen**, todas de una vez, porque casi todas las tareas siguientes las necesitan y hacerlas a trozos rompería la paridad entre idiomas una y otra vez.

**Las 16 claves muertas NO se borran aquí.** Se borran en la Task 12, cuando ya no las usa ningún fichero. Borrarlas ahora dejaría `flutter analyze` roto durante diez tareas, y un `analyze` que ya falla deja de avisar de los errores que sí importan.

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_es.arb`
- Modify: `lib/funciones.dart:35-60` — el `switch` de `MensajeLocalizado.texto()`
- Test: `test/arb_paridad_test.dart` (nuevo)

**Interfaces:**
- Consumes: nada.
- Produces: las claves ARB que consumen las Tasks 4 a 11, y los `case` nuevos del `switch` de errores.

- [ ] **Step 1: Escribir el test que falla**

Crear `test/arb_paridad_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Los dos ARB tienen que llevar exactamente las mismas claves. Se ha
/// comprobado a mano en cada sesión hasta ahora; esto lo hace solo.
///
/// Se ignoran las claves de metadatos: `@@locale` y las `@clave`, que solo
/// existen en la plantilla (`app_en.arb`) y que gen-l10n no exige duplicar.
Set<String> _clavesDe(String ruta) {
  final json = jsonDecode(File(ruta).readAsStringSync()) as Map<String, dynamic>;
  return json.keys.where((k) => !k.startsWith('@')).toSet();
}

void main() {
  test('los dos ARB llevan exactamente las mismas claves', () {
    final en = _clavesDe('lib/l10n/app_en.arb');
    final es = _clavesDe('lib/l10n/app_es.arb');

    expect(en.difference(es), isEmpty, reason: 'claves que solo están en inglés');
    expect(es.difference(en), isEmpty, reason: 'claves que solo están en español');
  });

  test('las claves nuevas del PIN global existen en los dos idiomas', () {
    final en = _clavesDe('lib/l10n/app_en.arb');
    final es = _clavesDe('lib/l10n/app_es.arb');
    for (final nueva in const [
      'cuentaPin',
      'configuracion',
      'cambiarPinTitulo',
      'verAmigoPinTitulo',
      'editarEliminarEscribeNombre',
      'errorPinFormato',
      'errorGrupoYaSorteado',
    ]) {
      expect(en.contains(nueva), isTrue, reason: 'falta $nueva en inglés');
      expect(es.contains(nueva), isTrue, reason: 'falta $nueva en español');
    }
  });
}
```

- [ ] **Step 2: Correr el test para verificar que falla**

Run: `flutter test test/arb_paridad_test.dart`
Expected: FAIL en el segundo test — `falta cuentaPin en inglés`. El primero debería pasar ya (hoy los ARB están sincronizados).

- [ ] **Step 3: Reescribir las dos claves que mencionan el PIN**

El PIN sale del formulario de alta, así que estos textos mienten. En `app_en.arb`:

```json
  "registroFaltaNombre": "The name is missing",
  "registroFaltaPersonaje": "The character is missing",
```

En `app_es.arb`:

```json
  "registroFaltaNombre": "Falta el nombre",
  "registroFaltaPersonaje": "Falta el personaje",
```

- [ ] **Step 4: Añadir las claves nuevas a `app_en.arb`**

Insertar en `lib/l10n/app_en.arb` (el sitio dentro del fichero da igual; agruparlas junto a sus vecinas temáticas lo hace legible):

```json
  "cuentaPin": "4-digit PIN",
  "cuentaPinAyuda": "You will type it to reveal your secret friend, in every group. Only you know it.",
  "cuentaPinConfirmar": "Confirm PIN",
  "cuentaPinNoCoinciden": "The PINs do not match",

  "verAmigoPinTitulo": "Type your PIN",
  "verAmigoPinTexto": "Nobody else should see this. Your PIN is asked every time.",

  "configuracion": "Settings",
  "configuracionIdioma": "Language",
  "configuracionCambiarPin": "Change my PIN",
  "cambiarPinTitulo": "Change my PIN",
  "cambiarPinTexto": "Your account password is asked because it is the only way back if you forget the PIN.",
  "cambiarPinPassword": "Account password",
  "cambiarPinNuevo": "New 4-digit PIN",
  "cambiarPinGuardar": "Save the new PIN",
  "cambiarPinGuardado": "PIN changed",

  "editarEliminarEscribeNombre": "To delete it, type the group name exactly: {grupo}",
  "@editarEliminarEscribeNombre": {
    "placeholders": { "grupo": { "type": "String" } }
  },

  "errorPinFormato": "The PIN must be exactly 4 digits",
  "errorNoEresOrganizador": "Only the group organizer can do this",
  "errorNoEstasEnElGrupo": "You are not signed up in this group yet",
  "errorGrupoYaSorteado": "The draw already happened. This person cannot be removed — they have to be replaced so the chain stays intact."
```

- [ ] **Step 5: Añadir las mismas claves a `app_es.arb`**

```json
  "cuentaPin": "PIN de 4 dígitos",
  "cuentaPinAyuda": "Lo escribirás para ver tu amigo secreto, en todos tus grupos. Solo tú lo sabes.",
  "cuentaPinConfirmar": "Confirma el PIN",
  "cuentaPinNoCoinciden": "Los PIN no coinciden",

  "verAmigoPinTitulo": "Escribe tu PIN",
  "verAmigoPinTexto": "Nadie más debería ver esto. El PIN se pide cada vez.",

  "configuracion": "Configuración",
  "configuracionIdioma": "Idioma",
  "configuracionCambiarPin": "Cambiar mi PIN",
  "cambiarPinTitulo": "Cambiar mi PIN",
  "cambiarPinTexto": "Se te pide la contraseña de la cuenta porque es la única salida si olvidas el PIN.",
  "cambiarPinPassword": "Contraseña de la cuenta",
  "cambiarPinNuevo": "PIN nuevo de 4 dígitos",
  "cambiarPinGuardar": "Guardar el PIN nuevo",
  "cambiarPinGuardado": "PIN cambiado",

  "editarEliminarEscribeNombre": "Para eliminarlo, escribe el nombre del grupo exactamente: {grupo}",

  "errorPinFormato": "El PIN tiene que ser de 4 dígitos exactos",
  "errorNoEresOrganizador": "Solo el organizador del grupo puede hacer esto",
  "errorNoEstasEnElGrupo": "Todavía no estás inscrito en este grupo",
  "errorGrupoYaSorteado": "El sorteo ya se hizo. A esta persona no se la puede sacar: hay que reemplazarla para que la cadena siga entera."
```

- [ ] **Step 6: Añadir los `case` nuevos al switch de errores**

En `lib/funciones.dart`, dentro de `MensajeLocalizado.texto()` (línea 35), añadir junto a los demás:

```dart
        'pin_formato' => t.errorPinFormato,
        'no_eres_organizador' => t.errorNoEresOrganizador,
        'no_estas_en_el_grupo' => t.errorNoEstasEnElGrupo,
        'grupo_ya_sorteado' => t.errorGrupoYaSorteado,
```

- [ ] **Step 7: Regenerar la clase de textos**

Run: `flutter gen-l10n`
Expected: termina sin error. `flutter test` NO regenera, así que sin este paso las claves nuevas no existen para el compilador.

- [ ] **Step 8: Correr los tests y el analizador**

```bash
flutter test
flutter analyze
```
Expected: **todos** los tests en verde y `No issues found!`. Esta tarea solo añade claves y reescribe dos textos: nada puede romperse. Si `analyze` se queja, es de algo que ya venía roto.

- [ ] **Step 9: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_es.arb lib/funciones.dart test/arb_paridad_test.dart
git commit -m "Textos del PIN global, y un test de paridad entre los ARB

Hasta hoy que los dos idiomas llevaran las mismas claves se comprobaba a
mano en cada sesión."
```

---

### Task 2: El PIN global en la cuenta (backend)

**Files:**
- Modify: `functions/index.js` — zona de cuentas, a partir de la línea 106

**Interfaces:**
- Consumes: `normalizarNickname`, `usuarioRef`, `validarPassword`, `bcrypt` (ya existen).
- Produces:
  - `validarPin(pin)` — lanza `HttpsError` con clave `pin_formato` si no son 4 dígitos.
  - `registrarCuenta` acepta `pin` obligatorio y guarda `pinHash`.
  - `exports.cambiarPin` — recibe `{nickname, password, pinNuevo}`, devuelve `{ok: true}`.

- [ ] **Step 1: Añadir la validación de PIN**

En `functions/index.js`, junto a `REGEX_PASSWORD` (línea 111):

```js
// El PIN es la SEGUNDA barrera, no la primera: la cuenta ya demostró
// quién eres. Este protege de que alguien con tu teléfono desbloqueado
// vea tu asignación, que es lo único irreversible de la app.
const REGEX_PIN = /^\d{4}$/;

function validarPin(pin) {
  if (!REGEX_PIN.test(pin || "")) {
    throw new HttpsError("invalid-argument", "El PIN debe ser de 4 dígitos exactos.", {clave: "pin_formato"});
  }
}
```

- [ ] **Step 2: Guardar el `pinHash` al registrar la cuenta**

En `exports.registrarCuenta` (línea 131), tras `validarPassword(password);`:

```js
  const pin = (request.data?.pin || "").trim();
  validarPin(pin);
```

Y en el `create`, junto a `hash`:

```js
    await usuarioRef(clave).create({
      nickname,
      hash,
      // Con bcrypt igual que la contraseña. Son 10.000 combinaciones: este
      // rediseño existe justamente para sacar secretos en claro de
      // Firestore, no para meter uno nuevo.
      pinHash: bcrypt.hashSync(pin, 10),
      fecha: admin.firestore.FieldValue.serverTimestamp(),
      grupos: {},
    });
```

Fíjate en `grupos: {}` — antes era `[]`. Es el mapa de la Task 3.

- [ ] **Step 3: Añadir la función de cambiar el PIN**

Justo después de `exports.registrarCuenta`:

```js
// Cambiar el PIN pide la contraseña de la cuenta. No es burocracia: es la
// ÚNICA salida si lo olvidas. Sin ella, cuatro dígitos olvidados te
// dejarían sin ver tu amigo secreto para siempre — y esta app tampoco
// tiene recuperación de contraseña.
exports.cambiarPin = onCall(async (request) => {
  const clave = normalizarNickname(request.data?.nickname);
  const password = request.data?.password || "";
  const pinNuevo = (request.data?.pinNuevo || "").trim();

  validarPin(pinNuevo);

  const snap = await usuarioRef(clave).get();
  if (!snap.exists || !bcrypt.compareSync(password, snap.data().hash)) {
    throw new HttpsError("unauthenticated", "La contraseña no es correcta.", {clave: "password_incorrecta"});
  }

  await usuarioRef(clave).update({pinHash: bcrypt.hashSync(pinNuevo, 10)});
  return {ok: true};
});
```

- [ ] **Step 4: Comprobar que el fichero es válido**

Run: `node --check functions/index.js`
Expected: sin salida (sintaxis correcta).

- [ ] **Step 5: Commit**

```bash
git add functions/index.js
git commit -m "Un PIN por cuenta, con bcrypt, en vez de uno por grupo en claro"
```

---

### Task 3: `usuarios.grupos` de array a mapa (backend)

El cambio que hace **inexpresable** el grupo duplicado en "Mis grupos".

**Files:**
- Modify: `functions/index.js` — `vincularCuenta` (línea 222) y `iniciarSesionCuenta` (línea 158)

**Interfaces:**
- Consumes: `usuarioRef`, `grupoRef`, `db`, `admin` (ya existen).
- Produces:
  - `vincularComoOrganizador(clave, codigo)`
  - `vincularComoParticipante(clave, codigo, participanteId)`
  - `iniciarSesionCuenta` devuelve `grupos: [{codigo, rol, participanteId, ocasion, valorMinimo, nombreGrupo, tematica, sorteado}]`

- [ ] **Step 1: Sustituir `vincularCuenta` por las dos funciones nuevas**

Borrar `vincularCuenta` entera (líneas 218-225) y poner en su lugar:

```js
/**
 * Al crear un grupo. La plaza de participante todavía no existe: quien
 * crea el grupo se inscribe después, como todo el mundo.
 */
async function vincularComoOrganizador(clave, codigo) {
  if (!clave) return;
  await usuarioRef(clave).set(
      {grupos: {[codigo]: {rol: "organizador", participanteId: null}}},
      {merge: true},
  );
}

/**
 * Al inscribirse en un grupo.
 *
 * `merge` hace una fusión PROFUNDA de mapas, así que esto rellena tu
 * `participanteId` sin crear una entrada nueva. Quien creó el grupo y
 * luego se apunta conserva su rol de organizador y queda UNA sola
 * entrada.
 *
 * Antes `grupos` era un array y esto se hacía con arrayUnion, que compara
 * por igualdad profunda: `{codigo, rol}` y `{codigo, participanteId, rol}`
 * son distintos, así que quedaban los DOS y el grupo salía duplicado en
 * "Mis grupos". Con el mapa indexado por código, ese bug no se puede ni
 * escribir.
 */
async function vincularComoParticipante(clave, codigo, participanteId) {
  if (!clave) return;
  const ref = usuarioRef(clave);
  // Se lee para saber si ya había rol: si no lo hubiera y no lo
  // pusiéramos, la entrada quedaría sin rol y "Mis grupos" no sabría si
  // eres organizador.
  const snap = await ref.get();
  const rol = (snap.data()?.grupos || {})[codigo]?.rol || "participante";
  await ref.set({grupos: {[codigo]: {rol, participanteId}}}, {merge: true});
}
```

- [ ] **Step 2: Reescribir `iniciarSesionCuenta` para el mapa**

Sustituir el bloque de las líneas 172-194 (desde `const grupos = datos.grupos || [];` hasta el `return`) por:

```js
  const grupos = datos.grupos || {};
  const codigos = Object.keys(grupos);
  const detalles = (await Promise.all(codigos.map(async (codigo) => {
    const gs = await grupoRef(codigo).get();
    if (!gs.exists) return null;
    return {
      codigo,
      rol: grupos[codigo].rol,
      // Null hasta que esa persona se da de alta en el grupo. Es lo que
      // el cliente usa para saber si ofrecerte el formulario de alta.
      participanteId: grupos[codigo].participanteId || null,
      ocasion: gs.data().ocasion,
      valorMinimo: gs.data().valorMinimo,
      nombreGrupo: gs.data().nombreGrupo || "",
      tematica: gs.data().tematica || "",
      sorteado: gs.data().sorteado === true,
    };
  }))).filter(Boolean);

  // Si algún grupo vinculado ya no existe (su organizador lo eliminó), se
  // borra aquí su clave del mapa. Así eliminarGrupo no tiene que recorrer
  // toda la colección de usuarios buscando a quién avisar.
  //
  // Se borra con FieldPath y no con la cadena `grupos.${codigo}`: los
  // códigos llevan guion (ABCD-2345) y una ruta en texto se parsea.
  if (detalles.length !== codigos.length) {
    const vivos = new Set(detalles.map((d) => d.codigo));
    for (const codigo of codigos) {
      if (vivos.has(codigo)) continue;
      await usuarioRef(clave).update(
          new admin.firestore.FieldPath("grupos", codigo),
          admin.firestore.FieldValue.delete(),
      );
    }
  }

  return {nickname: datos.nickname, grupos: detalles};
```

- [ ] **Step 3: Comprobar que el fichero es válido**

Run: `node --check functions/index.js`
Expected: sin salida.

- [ ] **Step 4: Verificar que no quedan usos del array viejo**

Run: `grep -n "arrayUnion\|vincularCuenta" functions/index.js`
Expected: dos usos de `vincularCuenta` en `crearGrupo` (línea ~267) y `agregarParticipante` (línea ~320), que la Task 4 reemplaza. Cero usos de `arrayUnion`.

- [ ] **Step 5: Commit**

```bash
git add functions/index.js
git commit -m "usuarios.grupos pasa de array a mapa por código

arrayUnion guardaba dos entradas para el mismo grupo -una al crearlo y
otra al inscribirse- y el grupo salía duplicado en Mis grupos. Con el mapa
indexado por código el duplicado no se puede ni escribir."
```

---

### Task 4: Autorización por cuenta en todas las funciones (backend)

**Files:**
- Modify: `functions/index.js` — de la línea 197 al final

**Interfaces:**
- Consumes: `vincularComoOrganizador` / `vincularComoParticipante` (Task 3), `validarPin` (Task 2).
- Produces:
  - `autorizar(codigo, nickname, password) → {clave, rol, participanteId, datos}`
  - `exigirOrganizador(sesion)`, `exigirParticipante(sesion)`
  - `exports.verAmigoSecreto` (sustituye a `exports.iniciarSesion`)
  - El grupo gana el campo `sorteado: true` al ejecutar el sorteo.

- [ ] **Step 1: Sustituir los tres verificadores de PIN por `autorizar`**

Borrar `verificarPinMaestro` (línea 335), `verificarPinOAdmin` (348) y `verificarPinPropio` (360), y borrar también `verificarCuentaSiAplica` (205). En su lugar:

```js
/**
 * Verifica la cuenta y devuelve tu vínculo con ese grupo.
 *
 * Lo importante no es que sustituya a tres funciones, es de dónde sale el
 * `participanteId`: antes lo mandaba el cliente y el servidor comprobaba
 * que el PIN cuadrara; ahora el servidor lo DERIVA del vínculo. El cliente
 * ya no puede decir que es otro participante, así que suplantar deja de
 * ser cuestión de adivinar cuatro cifras guardadas en texto plano.
 */
/** Solo comprueba la cuenta. La usa `crearGrupo`, donde todavía no hay
 * grupo con el que tener vínculo. */
async function verificarCuenta(nickname, password) {
  const clave = normalizarNickname(nickname);
  if (!clave || !password) {
    throw new HttpsError("unauthenticated", "Faltan las credenciales de tu cuenta.", {clave: "sesion_invalida"});
  }
  const snap = await usuarioRef(clave).get();
  if (!snap.exists || !bcrypt.compareSync(password, snap.data().hash)) {
    throw new HttpsError("unauthenticated", "La sesión de tu cuenta no es válida. Vuelve a entrar.", {clave: "sesion_invalida"});
  }
  return {clave, datos: snap.data()};
}

async function autorizar(codigo, nickname, password) {
  const {clave, datos} = await verificarCuenta(nickname, password);
  const vinculo = (datos.grupos || {})[codigo] || null;
  return {
    clave,
    rol: vinculo ? vinculo.rol : null,
    participanteId: vinculo ? (vinculo.participanteId || null) : null,
    datos,
  };
}

function exigirOrganizador(sesion) {
  if (sesion.rol !== "organizador") {
    throw new HttpsError("permission-denied", "Solo el organizador del grupo puede hacer esto.", {clave: "no_eres_organizador"});
  }
}

function exigirParticipante(sesion) {
  if (!sesion.participanteId) {
    throw new HttpsError("permission-denied", "Todavía no estás inscrito en este grupo.", {clave: "no_estas_en_el_grupo"});
  }
}
```

- [ ] **Step 2: `crearGrupo` sin PIN maestro**

En `exports.crearGrupo` (línea 227): borrar la línea que lee `pinMaestro`, quitarlo de la comprobación de `faltan_datos_grupo`, y sustituir la llamada a `verificarCuentaSiAplica`:

```js
  // La cuenta ya no es opcional: sin ella el grupo quedaría huérfano, sin
  // organizador y sin aparecer en "Mis grupos" de nadie. Aquí se usa
  // `verificarCuenta` y no `autorizar` porque el grupo todavía no existe:
  // no hay vínculo que consultar.
  const {clave} = await verificarCuenta(request.data?.nickname, request.data?.password);
```

Dentro de la transacción, **borrar** la línea `tx.set(grupoPrivadoRef(codigo), {pinMaestro});`. Y sustituir `await vincularCuenta(claveCuenta, {codigo, rol: "organizador"});` por:

```js
      await vincularComoOrganizador(clave, codigo);
```

- [ ] **Step 3: `agregarParticipante` sin PIN propio, y guardando la cuenta**

En `exports.agregarParticipante` (línea 279): borrar la lectura de `pin` y quitarlo de la comprobación de `faltan_datos_participante`. Sustituir la llamada a `verificarCuentaSiAplica` por:

```js
  const sesion = await autorizar(codigo, request.data?.nickname, request.data?.password);
```

En el batch, quitar `pin` del privado y añadir `cuenta`:

```js
  batch.set(participantePrivadoRef(codigo, ref.id), {
    // De qué cuenta es esta plaza. Sin este dato, borrarParticipante no
    // puede limpiar el puntero de usuarios/{x}.grupos —no sabría de
    // quién— y el grupo seguiría saliendo en su "Mis grupos" apuntando a
    // un participante que ya no existe. Este documento está cerrado a
    // cero para el cliente (ver firestore.rules).
    cuenta: sesion.clave,
    deseos: deseos || "¡Sorpréndeme!",
    asignado_a: "",
    nombre_asignado: "",
    deseos_asignado: "",
  });
```

Y sustituir la vinculación final:

```js
  await vincularComoParticipante(sesion.clave, codigo, ref.id);
```

- [ ] **Step 4: `iniciarSesion` se convierte en `verAmigoSecreto`**

Sustituir `exports.iniciarSesion` entera (líneas 429-442) por:

```js
// Antes se llamaba `iniciarSesion`, que se confundía con
// `iniciarSesionCuenta` y ya no describe lo que hace: no inicia ninguna
// sesión, revela una asignación.
exports.verAmigoSecreto = onCall(async (request) => {
  const codigo = (request.data?.codigo || "").trim();
  const pin = (request.data?.pin || "").trim();
  if (!codigo) {
    throw new HttpsError("invalid-argument", "Falta el grupo.", {clave: "faltan_datos"});
  }

  const sesion = await autorizar(codigo, request.data?.nickname, request.data?.password);
  exigirParticipante(sesion);

  // El PIN es la segunda barrera: la cuenta ya demostró quién eres. Este
  // protege de que alguien con tu teléfono desbloqueado vea tu
  // asignación. Una vez visto, se vio.
  if (!sesion.datos.pinHash || !bcrypt.compareSync(pin, sesion.datos.pinHash)) {
    throw new HttpsError("permission-denied", "PIN incorrecto.", {clave: "pin_incorrecto"});
  }

  const privado = await obtenerPrivado(codigo, sesion.participanteId);
  const publico = await participanteRef(codigo, sesion.participanteId).get();
  return {
    // Tu propio nombre en el grupo. Antes lo sacaba el cliente de la lista
    // de participantes que mostraba PantallaLogin, que desaparece.
    nombre: publico.data()?.nombre || "",
    nombreAmigo: privado.nombre_asignado || "",
    // Vacío y no "Sin sugerencias": el texto por defecto lo pone el
    // cliente traducido, y aquí saldría siempre en español.
    deseosAmigo: privado.deseos_asignado || "",
  };
});
```

- [ ] **Step 5: `borrarParticipante` — cuenta, límite del sorteo y limpieza del puntero**

Sustituir el cuerpo de `exports.borrarParticipante` (línea 366) por:

```js
exports.borrarParticipante = onCall(async (request) => {
  const codigo = (request.data?.codigo || "").trim();
  const participanteId = request.data?.participanteId;
  if (!codigo || !participanteId) {
    throw new HttpsError("invalid-argument", "Falta el grupo o el participante.", {clave: "faltan_datos"});
  }

  const sesion = await autorizar(codigo, request.data?.nickname, request.data?.password);
  // O es tu propia plaza, o eres el organizador.
  if (sesion.participanteId !== participanteId) exigirOrganizador(sesion);

  // Tras el sorteo, sacar a alguien deja a quien le regalaba apuntando a
  // un fantasma —su nombre_asignado sigue ahí pero ya no hay nadie— y ese
  // tercero no se entera hasta el día del intercambio. La salida es
  // reemplazar a la persona conservando su plaza en la cadena (P4), no
  // borrarla.
  const grupoSnap = await grupoRef(codigo).get();
  if (grupoSnap.data()?.sorteado === true) {
    throw new HttpsError(
        "failed-precondition",
        "El sorteo ya se hizo: a esta persona hay que reemplazarla, no sacarla.",
        {clave: "grupo_ya_sorteado"},
    );
  }

  const publico = await participanteRef(codigo, participanteId).get();
  const privado = await participantePrivadoRef(codigo, participanteId).get();
  const cuentaDeLaPlaza = privado.data()?.cuenta;

  const batch = db.batch();
  batch.delete(participanteRef(codigo, participanteId));
  batch.delete(participantePrivadoRef(codigo, participanteId));
  await batch.commit();

  // Se quita el grupo de su "Mis grupos". Sin esto quedaría listado
  // apuntando a un participante que ya no existe — era un fallo conocido
  // que no se podía arreglar porque nadie sabía de qué cuenta era la
  // plaza.
  if (cuentaDeLaPlaza) {
    await usuarioRef(cuentaDeLaPlaza).update(
        new admin.firestore.FieldPath("grupos", codigo),
        admin.firestore.FieldValue.delete(),
    );
  }

  await borrarAvatarPorUrl(publico.data()?.avatarUrl);
  return {ok: true};
});
```

- [ ] **Step 6: `cambiarAvatar` por cuenta**

En `exports.cambiarAvatar` (línea 388), borrar la lectura de `pin` y sustituir `await verificarPinOAdmin(...)` por:

```js
  const sesion = await autorizar(codigo, request.data?.nickname, request.data?.password);
  if (sesion.participanteId !== participanteId) exigirOrganizador(sesion);
```

- [ ] **Step 7: Las cinco funciones de organizador**

En `editarParticipante` (409), `ejecutarSorteo` (444), `editarGrupo` (607), `eliminarGrupo` (645) y `borrarMensaje` (564): borrar la lectura de `pinMaestro` y sustituir cada `await verificarPinMaestro(codigo, ...)` por:

```js
  exigirOrganizador(await autorizar(codigo, request.data?.nickname, request.data?.password));
```

- [ ] **Step 8: `ejecutarSorteo` marca el grupo**

En `exports.ejecutarSorteo`, justo antes de `await batch.commit();`, añadir al batch:

```js
  // Marca en el documento del grupo, que el cliente ya escucha en vivo.
  // Sin esto, saber si el grupo sorteó exigiría leer todos los
  // participantes buscando un tieneAmigo:true.
  batch.update(grupoRef(codigo), {sorteado: true});
```

- [ ] **Step 9: Chat por cuenta**

En `exports.enviarMensaje` (523), borrar la lectura de `pin` y de `participanteId`, y sustituir `const privado = await verificarPinPropio(...)` por:

```js
  const sesion = await autorizar(codigo, request.data?.nickname, request.data?.password);
  exigirParticipante(sesion);
  const participanteId = sesion.participanteId;
  const privado = await obtenerPrivado(codigo, participanteId);
```

El resto de la función (espera anti-spam, máscara, escritura) **no se toca**: el anti-spam y las máscaras siguen en pie durante P2 y solo se quitan en P3.

En `exports.miMascara` (577), lo mismo:

```js
  const sesion = await autorizar(codigo, request.data?.nickname, request.data?.password);
  exigirParticipante(sesion);
  return await obtenerMascara(codigo, sesion.participanteId);
```

- [ ] **Step 10: Borrar `verificarOrganizador`**

Borrar `exports.verificarOrganizador` entera (líneas 592-601) con su comentario. Su único trabajo era canjear el PIN maestro por un permiso en memoria; el rol viene ya en `iniciarSesionCuenta`.

- [ ] **Step 11: Comprobar que no queda ni rastro de los PIN de grupo**

```bash
node --check functions/index.js
grep -n "pinMaestro\|verificarPin\|verificarCuentaSiAplica\|verificarOrganizador\|privado.pin\b" functions/index.js
```
Expected: `node --check` sin salida. El `grep` **sin ninguna coincidencia**.

- [ ] **Step 12: NO desplegar todavía**

**Esta tarea no despliega nada.** El backend nuevo es incompatible con el cliente que hay en producción —que sigue mandando PINs— y también con los datos que hay en Firestore, donde `grupos` todavía es un array. Desplegarlo aquí dejaría la app en vivo rota durante siete tareas y daría resultados falsos en cualquier prueba manual.

El despliegue del backend, el borrado de las colecciones y la prueba de integración van juntos en la **Task 12**, cuando el cliente esté listo. Hasta entonces, la única verificación de estas funciones es `node --check`.

- [ ] **Step 13: Commit**

```bash
git add functions/index.js
git commit -m "La cuenta autoriza; los PIN de grupo desaparecen

Un solo autorizar() sustituye a los tres verificadores de PIN, y el
participanteId lo deriva el servidor del vínculo en vez de creérselo al
cliente. iniciarSesion pasa a llamarse verAmigoSecreto: no iniciaba
ninguna sesión.

Tras el sorteo ya no se puede sacar a nadie -rompía la asignación de un
tercero en silencio- y borrar a alguien antes del sorteo ahora sí limpia
su puntero en Mis grupos."
```

---

### Task 5: El PIN en el formulario de crear cuenta

**Files:**
- Modify: `lib/pantalla_crear_cuenta.dart`
- Test: `test/pantallas_cuenta_test.dart:38-52` — el test de los campos

**Interfaces:**
- Consumes: `cuentaPin` / `cuentaPinAyuda` / `cuentaPinConfirmar` / `cuentaPinNoCoinciden` / `errorPinFormato` (Task 1).
- Produces: `entrarConCuenta` pasa a aceptar `String? pin` para el registro.

- [ ] **Step 1: Escribir el test que falla**

En `test/pantallas_cuenta_test.dart`, sustituir el test `'tiene los tres campos y la casilla de idioma'` por:

```dart
  testWidgets('tiene los campos de cuenta, el PIN y la casilla de idioma',
      (tester) async {
    await tester.pumpWidget(_envoltorio(PantallaCrearCuenta(alEntrar: _sinNavegar)));
    await tester.pumpAndSettle();
    expect(find.text('Nickname'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    // El campo de confirmación queda más abajo de lo que cabe en el
    // viewport de prueba. El ListView es de slivers: los widgets fuera de
    // la vista (más allá del cacheExtent) ni siquiera se construyen, así
    // que hace falta el gesto de scroll -no basta con pumpAndSettle- para
    // que lleguen a existir en el árbol.
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(find.text('Confirm password'), findsOneWidget);
    expect(find.text('4-digit PIN'), findsOneWidget);
    expect(find.text('Confirm PIN'), findsOneWidget);
  });
```

- [ ] **Step 2: Correr el test para verificar que falla**

Run: `flutter test test/pantallas_cuenta_test.dart`
Expected: FAIL — no encuentra `4-digit PIN`.

- [ ] **Step 3: Añadir los controladores y la validación**

En `lib/pantalla_crear_cuenta.dart`, junto a `_regexPassword` (línea 14):

```dart
/// Misma exigencia que valida el servidor: 4 dígitos exactos.
final RegExp _regexPin = RegExp(r'^\d{4}$');
```

En el `State`, junto a los otros controladores:

```dart
  final _pin = TextEditingController();
  final _confirmarPin = TextEditingController();
```

Añadirlos al `dispose()`.

En `_enviar()`, tras la comprobación de que las contraseñas coinciden:

```dart
    if (!_regexPin.hasMatch(_pin.text.trim())) {
      _avisar('⚠️ ${t.errorPinFormato}');
      return;
    }
    if (_pin.text.trim() != _confirmarPin.text.trim()) {
      _avisar('⚠️ ${t.cuentaPinNoCoinciden}');
      return;
    }
```

Y pasar el PIN al registro:

```dart
      final r = await entrarConCuenta(
          nickname: nickname,
          password: password,
          registrando: true,
          pin: _pin.text.trim());
```

- [ ] **Step 4: Añadir los dos campos a la interfaz**

En el `ListView` de `build`, justo después del `GlassTextField` de `cuentaConfirmar` y antes del `SizedBox(height: 24)`:

```dart
                const SizedBox(height: 16),
                GlassTextField(
                  controller: _pin,
                  labelText: t.cuentaPin,
                  helperText: t.cuentaPinAyuda,
                  icon: Icons.pin_outlined,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                GlassTextField(
                    controller: _confirmarPin,
                    labelText: t.cuentaPinConfirmar,
                    icon: Icons.pin_outlined,
                    keyboardType: TextInputType.number,
                    obscureText: true),
```

- [ ] **Step 5: Que `entrarConCuenta` acepte el PIN**

En `lib/acceso_cuenta.dart`, cambiar la firma y la llamada:

```dart
Future<ResultadoAcceso> entrarConCuenta({
  required String nickname,
  required String password,
  required bool registrando,
  String? pin,
}) async {
  if (registrando) {
    await llamarFuncion('registrarCuenta',
        {'nickname': nickname, 'password': password, 'pin': pin ?? ''});
  }
```

- [ ] **Step 6: Correr los tests**

Run: `flutter test test/pantallas_cuenta_test.dart`
Expected: PASS los tres tests.

- [ ] **Step 7: Commit**

```bash
git add lib/pantalla_crear_cuenta.dart lib/acceso_cuenta.dart test/pantallas_cuenta_test.dart
git commit -m "Un PIN de 4 dígitos al crear la cuenta"
```

---

### Task 6: `MiVinculo` y el reparto del vínculo desde Mis grupos

**Files:**
- Create: `lib/mi_vinculo.dart`
- Modify: `lib/acceso_cuenta.dart`
- Modify: `lib/pantalla_mis_grupos.dart`
- Modify: `lib/pantalla_raiz.dart` — `_entrarAlGrupo` e `irADondeToque`
- Test: `test/mi_vinculo_test.dart` (nuevo)

**Interfaces:**
- Consumes: `ResultadoAcceso` (`lib/acceso_cuenta.dart`).
- Produces:
  - `class MiVinculo { final String rol; final String? participanteId; final bool sorteado; bool get esOrganizador; bool get estoyDentro; }`
  - `MiVinculo.desdeMapa(Map<String, dynamic> g)`
  - `PantallaRegistro` gana el parámetro opcional `MiVinculo? vinculo`.

- [ ] **Step 1: Escribir el test que falla**

Crear `test/mi_vinculo_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:santa_secreto/mi_vinculo.dart';

void main() {
  test('organizador que todavía no se inscribió', () {
    final v = MiVinculo.desdeMapa({
      'codigo': 'ABCD-2345',
      'rol': 'organizador',
      'participanteId': null,
      'sorteado': false,
    });
    expect(v.esOrganizador, isTrue);
    expect(v.estoyDentro, isFalse);
  });

  test('participante inscrito', () {
    final v = MiVinculo.desdeMapa({
      'codigo': 'ABCD-2345',
      'rol': 'participante',
      'participanteId': 'x7k',
      'sorteado': true,
    });
    expect(v.esOrganizador, isFalse);
    expect(v.estoyDentro, isTrue);
    expect(v.participanteId, 'x7k');
    expect(v.sorteado, isTrue);
  });

  test('un participanteId vacío cuenta como no inscrito', () {
    // El servidor manda null, pero una respuesta vieja o un campo a medio
    // escribir podrían traer "". Tratarlo como "dentro" dejaría a esa
    // persona sin formulario de alta y sin poder hacer nada.
    final v = MiVinculo.desdeMapa({
      'codigo': 'ABCD-2345',
      'rol': 'participante',
      'participanteId': '',
      'sorteado': false,
    });
    expect(v.estoyDentro, isFalse);
  });
}
```

- [ ] **Step 2: Correr el test para verificar que falla**

Run: `flutter test test/mi_vinculo_test.dart`
Expected: FAIL — `mi_vinculo.dart` no existe.

- [ ] **Step 3: Crear `lib/mi_vinculo.dart`**

```dart
/// Tu relación con un grupo concreto, tal como la cuenta la conoce.
///
/// Sustituye a la identidad que antes se guardaba en disco por grupo
/// (`identidad_local.dart`): el servidor ya sabe qué participante eres en
/// cada grupo, y lo manda en `iniciarSesionCuenta`. Preguntárselo al
/// usuario era pedirle un dato que ya teníamos.
class MiVinculo {
  /// `organizador` o `participante`.
  final String rol;

  /// Qué participante eres dentro del grupo. Null mientras no te hayas
  /// dado de alta: se puede ser organizador de un grupo en el que
  /// todavía no te inscribiste.
  final String? participanteId;

  /// Si el grupo ya sorteó. Manda qué acciones de organizador tienen
  /// sentido: tras el sorteo no se puede sacar a nadie.
  final bool sorteado;

  const MiVinculo({required this.rol, this.participanteId, this.sorteado = false});

  bool get esOrganizador => rol == 'organizador';

  bool get estoyDentro => participanteId != null && participanteId!.isNotEmpty;

  /// Lee una entrada de las que devuelve `iniciarSesionCuenta`.
  factory MiVinculo.desdeMapa(Map<String, dynamic> g) => MiVinculo(
        rol: g['rol'] as String? ?? 'participante',
        participanteId: g['participanteId'] as String?,
        sorteado: g['sorteado'] == true,
      );
}
```

- [ ] **Step 4: Correr el test**

Run: `flutter test test/mi_vinculo_test.dart`
Expected: PASS los tres tests.

- [ ] **Step 5: Que `PantallaRegistro` acepte el vínculo**

En `lib/pantalla_registro.dart`, añadir al widget:

```dart
  /// Tu relación con este grupo, o null si todavía no tienes ninguna
  /// (llegaste por un QR a un grupo en el que no estás). Se recibe en vez
  /// de consultarse porque quien navega aquí ya lo tiene: Mis grupos en su
  /// lista, y el portero en `resultado.grupos`.
  final MiVinculo? vinculo;
```

y al constructor: `this.vinculo,`.

- [ ] **Step 6: Que Mis grupos lo pase**

En `lib/pantalla_mis_grupos.dart`, en el `onTap` del `ListTile` (línea 153), añadir a `PantallaRegistro`:

```dart
                                      vinculo: MiVinculo.desdeMapa(g),
```

Importar `mi_vinculo.dart`.

- [ ] **Step 7: Que el portero lo pase**

En `lib/pantalla_raiz.dart`, cambiar la firma de `_entrarAlGrupo` para que reciba los grupos de la cuenta:

```dart
Future<PantallaRegistro?> _entrarAlGrupo(
    InvitacionPendiente i, List<Map<String, dynamic>> grupos) async {
```

y al construir `PantallaRegistro` al final de esa función:

```dart
  // Si la cuenta ya tiene vínculo con este grupo se le pasa; si no, null,
  // que es lo que hace que la pantalla ofrezca el formulario de alta.
  //
  // Con un bucle y no con `firstOrNull`: esa extensión vive en
  // `package:collection`, que este proyecto no importa, y añadir una
  // dependencia por una línea no compensa.
  Map<String, dynamic>? entrada;
  for (final g in grupos) {
    if (g['codigo'] == i.codigo) {
      entrada = g;
      break;
    }
  }
  return PantallaRegistro(
    codigo: i.codigo,
    ocasion: Ocasion.desdeId(data['ocasion'] as String),
    valorMinimo: data['valorMinimo'] as String? ?? '',
    nombreGrupo: data['nombreGrupo'] as String? ?? '',
    vinculo: entrada == null ? null : MiVinculo.desdeMapa(entrada),
  );
```

Y en `irADondeToque`, pasarle la lista:

```dart
  final registro =
      invitacion == null ? null : await _entrarAlGrupo(invitacion, resultado.grupos);
```

Importar `mi_vinculo.dart`.

- [ ] **Step 8: Verificar**

```bash
flutter analyze
flutter test
```
Expected: `No issues found!` y todos los tests en verde. `PantallaRegistro` gana un parámetro **opcional**, así que quienes la construyen sin pasarlo siguen compilando.

- [ ] **Step 9: Commit**

```bash
git add lib/mi_vinculo.dart lib/pantalla_registro.dart lib/pantalla_mis_grupos.dart lib/pantalla_raiz.dart test/mi_vinculo_test.dart
git commit -m "MiVinculo: la identidad de grupo viaja desde el servidor

Ya no se guarda en disco ni se le pregunta a nadie: quien navega a la
pantalla del grupo ya tiene el dato."
```

---

### Task 7: La pantalla del grupo sin PIN ni modo organizador

**Files:**
- Modify: `lib/pantalla_registro.dart`

**Interfaces:**
- Consumes: `MiVinculo` (Task 6), `leerSesion` (`lib/sesion.dart`).
- Produces: nada que consuman otras tareas.

- [ ] **Step 1: Sustituir el estado de identidad por el vínculo**

En `_PantallaRegistroState`, borrar los campos `IdentidadGrupo? _yo;`, `bool _identidadCargada = false;` y `String _pinMaestro = '';`, y sustituirlos por:

```dart
  /// Tu vínculo con este grupo. Arranca con el que llegó por parámetro y
  /// se actualiza al darte de alta. Null = no estás dentro → formulario.
  late MiVinculo? _vinculo = widget.vinculo;

  bool get _esOrganizador => _vinculo?.esOrganizador ?? false;
```

Borrar el campo `bool _esOrganizador = false;` que había.

- [ ] **Step 2: Borrar el modo organizador entero**

Borrar `_desbloquearOrganizador()` (líneas 306-355) y `_salirDeOrganizador()` (357-364), con su comentario de sección `// --- Modo organizador ---`. Borrar también cualquier botón que las llamara en `build`.

Los controles de organizador ya no se activan: se muestran cuando `_esOrganizador` es true, que se sabe antes de dibujar.

- [ ] **Step 3: Borrar la identidad local**

Borrar `_cargarIdentidad()` (170-181), `_decirQuienSoy()` (225-231) y `_dejarDeSerYo()` (233-237). En `initState`, quitar la llamada a `_cargarIdentidad()`.

Adaptar `_revisarIdentidadContraLista` — **la lógica se conserva entera**, solo cambia de dónde sale el id y qué se hace al perderlo:

```dart
  /// Si el organizador te sacó del grupo, tu vínculo apunta a alguien que
  /// ya no existe. Se descarta para no dejar la pantalla bloqueada sin
  /// formulario ni participante.
  ///
  /// La decisión NO puede tomarse desde la lista: va por detrás de las
  /// altas recién hechas. Al crear un grupo y registrarte el primero, la
  /// lista que la app tiene en ese instante está VACÍA, así que no
  /// encontrarse a uno mismo no prueba nada. Por eso, cuando faltas de la
  /// lista, se le pregunta al servidor por tu documento concreto.
  Future<void> _revisarIdentidadContraLista(List<QueryDocumentSnapshot> docs) async {
    final id = _vinculo?.participanteId;
    if (id == null || id.isEmpty || _comprobandoIdentidad) return;
    if (docs.any((d) => d.id == id)) return;

    _comprobandoIdentidad = true;
    try {
      final doc = await participantesRef
          .doc(id)
          .get(const GetOptions(source: Source.server));
      // Sigue dentro: la lista simplemente iba atrasada.
      if (doc.exists) return;
      if (!mounted || _vinculo?.participanteId != id) return;
      // Se conserva el rol: quien creó el grupo sigue siendo su
      // organizador aunque le hayan sacado como participante.
      setState(() => _vinculo = MiVinculo(
          rol: _vinculo!.rol, sorteado: _vinculo!.sorteado));
    } catch (_) {
      // Sin red no se decide nada y se conserva el vínculo. Equivocarse
      // hacia "sigues dentro" se corrige en la siguiente emisión.
    } finally {
      _comprobandoIdentidad = false;
    }
  }
```

- [ ] **Step 4: Quitar el PIN del formulario de alta**

Borrar el `TextEditingController _pinController` y su `dispose()`, y el `GlassTextField` que lo mostraba dentro de `_formularioRegistro`.

En `_agregar()`, sustituir el cuerpo del `try` por:

```dart
    if (nombreLimpio.isEmpty) {
      _avisar('⚠️ ${_info.tematica.usaPersonajes ? t.registroFaltaPersonaje : t.registroFaltaNombre}');
      return;
    }

    try {
      final sesion = await leerSesion();
      if (sesion == null) {
        // Antes esto se mandaba sin credenciales y la persona se unía al
        // grupo EN SILENCIO, sin que apareciera en su Mis grupos. Ahora
        // el servidor lo rechaza, así que se avisa aquí antes de gastar
        // la llamada.
        _avisar('⚠️ ${t.errorSesionInvalida}');
        return;
      }
      final creado = await llamarFuncion('agregarParticipante', {
        'codigo': widget.codigo,
        'nombre': nombreLimpio,
        'deseos': deseosLimpios,
        if (_avatarBase64 != null) 'avatarBase64': _avatarBase64,
        'nickname': sesion.nickname,
        'password': sesion.password,
      });
      _nombreController.clear();
      _deseosController.clear();
      if (!mounted) return;
      setState(() {
        _avatarBase64 = null;
        _vinculo = MiVinculo(
          rol: _vinculo?.rol ?? 'participante',
          participanteId: creado['id'] as String,
          sorteado: _vinculo?.sorteado ?? false,
        );
      });
      FocusScope.of(context).unfocus();
    } catch (e) {
      _avisarError(e);
    }
```

Borrar también la llamada a `guardarIdentidad` y el import de `identidad_local.dart`.

- [ ] **Step 5: Reemplazar `_pinMaestro` en las llamadas que lo mandaban**

Buscar y sustituir en las llamadas a `llamarFuncion` de esta pantalla — `ejecutarSorteo`, `editarParticipante`, `borrarParticipante` — quitando `'pinMaestro': _pinMaestro` y `'pin': _pinMaestro` y poniendo en su lugar las credenciales de la sesión. Extraer un ayudante para no repetirlo:

```dart
  /// Las credenciales que autorizan cualquier acción de esta pantalla.
  /// Devuelve null si no hay sesión, que a estas alturas no debería pasar
  /// —no se llega aquí sin cuenta— pero tumbar la app sería peor.
  Future<Map<String, String>?> _credenciales() async {
    final s = await leerSesion();
    if (s == null) return null;
    return {'nickname': s.nickname, 'password': s.password};
  }
```

y en cada llamada:

```dart
      final cred = await _credenciales();
      if (cred == null) { _avisar('⚠️ ${t.errorSesionInvalida}'); return; }
      await llamarFuncion('ejecutarSorteo', {'codigo': widget.codigo, ...cred});
```

- [ ] **Step 6: Actualizar el gate de dibujo y la navegación a Editar grupo**

Donde estaba `!_identidadCargada ? const SizedBox.shrink() : (_yo == null ? ... )` (línea 643), sustituir por:

```dart
                  child: _vinculo?.estoyDentro == true
                      ? _tarjetaYaDentro(t)
                      : _formularioRegistro(t),
```

Ya no hace falta el estado de "cargando identidad": el vínculo llega con el widget, no del disco.

En `_abrirEdicionGrupo` (366), quitar `pinMaestro: _pinMaestro` de `PantallaEditarGrupo`.

En el botón del chat (682), quitar `pinMaestro: _pinMaestro`.

- [ ] **Step 7: Verificar**

```bash
flutter analyze
```
Expected: `No issues found!`. Ojo: `pantalla_login.dart` sigue existiendo y sigue usando `registroTuPin`, que **todavía no se ha borrado** — por eso las claves muertas se borran al final. Si `analyze` se queja de algo, es un error real de esta tarea.

- [ ] **Step 8: Commit**

```bash
git add lib/pantalla_registro.dart
git commit -m "La pantalla del grupo se fía de la cuenta

Ser organizador deja de ser un modo que se desbloquea con un PIN: lo dice
tu vínculo, y se sabe antes de dibujar el primer frame."
```

---

### Task 8: Ver el amigo secreto con el PIN global

**Files:**
- Modify: `lib/pantalla_registro.dart` — el botón *Ver mi amigo secreto*
- Delete: `lib/pantalla_login.dart`
- Modify: `lib/pantalla_secreta.dart` — ninguna, se documenta que no cambia

**Interfaces:**
- Consumes: `verAmigoSecreto` (Task 4), `verAmigoPinTitulo` / `verAmigoPinTexto` / `cuentaPin` (Task 1), `MiVinculo` y el campo `_vinculo` (Task 6), y **`_credenciales()`, el ayudante privado que añade la Task 7 Step 5** — si esa tarea no está hecha, este código no compila.
- Produces: nada.

- [ ] **Step 1: Añadir el diálogo de PIN y la llamada**

En `lib/pantalla_registro.dart`, junto a los demás métodos:

```dart
  /// Pide el PIN global y abre la pantalla del amigo secreto.
  ///
  /// El PIN se pide CADA VEZ, a propósito. Si se cacheara dejaría de ser
  /// una segunda barrera y volvería a ser decorado, que es el problema del
  /// que viene todo este rediseño. Revelar tu amigo secreto se hace una
  /// vez por grupo y temporada, no cada rato.
  Future<void> _verAmigoSecreto() async {
    final t = Textos.of(context);
    final pinController = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        icon: Icon(Icons.lock_outline, color: _color.shade700, size: 36),
        title: Text(t.verAmigoPinTitulo),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.verAmigoPinTexto, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              autofocus: true,
              textAlign: TextAlign.center,
              decoration: InputDecoration(labelText: t.cuentaPin),
              onSubmitted: (v) => Navigator.pop(c, v.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t.cancelar)),
          FilledButton(
            onPressed: () => Navigator.pop(c, pinController.text.trim()),
            child: Text(t.entrar),
          ),
        ],
      ),
    );
    if (pin == null || pin.isEmpty || !mounted) return;

    final cred = await _credenciales();
    if (cred == null || !mounted) {
      _avisar('⚠️ ${t.errorSesionInvalida}');
      return;
    }
    try {
      final data = await llamarFuncion('verAmigoSecreto', {
        'codigo': widget.codigo,
        'pin': pin,
        ...cred,
      });
      if (!mounted) return;
      final deseos = data['deseosAmigo'] as String? ?? '';
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PantallaSecreta(
            ocasion: _info.ocasion,
            tematica: _info.tematica,
            nombre: data['nombre'] as String? ?? '',
            nombreAmigo: data['nombreAmigo'] as String? ?? '',
            deseosAmigo: deseos.isEmpty ? t.secretaSinSugerencias : deseos,
          ),
        ),
      );
    } catch (e) {
      _avisarError(e);
    }
  }
```

- [ ] **Step 2: Cambiar el botón**

Sustituir el `GlassOutlineButton` que navegaba a `PantallaLogin` (líneas 661-675) por:

```dart
                      GlassOutlineButton(
                        color: _color,
                        // Solo tiene sentido si estás dentro: sin plaza no
                        // hay amigo asignado.
                        onPressed: _vinculo?.estoyDentro == true ? _verAmigoSecreto : null,
                        icon: Icons.visibility,
                        label: t.registroVerAmigo,
                      ),
```

Cambiar el import de `pantalla_login.dart` por `pantalla_secreta.dart`.

- [ ] **Step 3: Borrar la pantalla intermedia**

```bash
git rm lib/pantalla_login.dart
```

Listaba a todos los participantes para que eligieras tu nombre y tecleases tu PIN. Sus dos pasos desaparecen: la cuenta ya sabe quién eres.

- [ ] **Step 4: Verificar**

```bash
flutter analyze
```
Expected: `No issues found!` y ninguna referencia a `pantalla_login.dart` en `lib/`.

- [ ] **Step 5: Commit**

```bash
git add -A lib/
git commit -m "Ver el amigo secreto: un PIN, el tuyo, y directo

Fuera la pantalla que te hacía elegir tu nombre de una lista: la cuenta ya
sabe qué participante eres."
```

---

### Task 9: La hoja de Configuración en Mis grupos

**Files:**
- Create: `lib/hoja_configuracion.dart`
- Modify: `lib/pantalla_mis_grupos.dart` — la barra
- Modify: `lib/selector_idioma.dart` — borrar `IconoIdioma`
- Test: `test/hoja_configuracion_test.dart` (nuevo)
- Modify: `test/selector_idioma_test.dart` — quitar los tests de `IconoIdioma`

**Interfaces:**
- Consumes: `CampoIdioma` (`lib/selector_idioma.dart`), `cerrarSesion` / `leerSesion` (`lib/sesion.dart`), `cambiarPin` (Task 2), claves de Task 1.
- Produces: `HojaConfiguracion.mostrar(BuildContext context, {required VoidCallback alCerrarSesion})`.

- [ ] **Step 1: Escribir el test que falla**

Crear `test/hoja_configuracion_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santa_secreto/hoja_configuracion.dart';
import 'package:santa_secreto/l10n/app_localizations.dart';

Widget _envoltorio(Widget hijo) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('es')],
      localizationsDelegates: Textos.localizationsDelegates,
      home: hijo,
    );

void main() {
  testWidgets('ofrece idioma, cambiar PIN y cerrar sesión', (tester) async {
    await tester.pumpWidget(_envoltorio(
        HojaConfiguracion(alCerrarSesion: () async {})));
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Change my PIN'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('cerrar sesión llama a su callback', (tester) async {
    var llamada = false;
    await tester.pumpWidget(_envoltorio(
        HojaConfiguracion(alCerrarSesion: () async => llamada = true)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(llamada, isTrue);
  });
}
```

- [ ] **Step 2: Correr el test para verificar que falla**

Run: `flutter test test/hoja_configuracion_test.dart`
Expected: FAIL — `hoja_configuracion.dart` no existe.

- [ ] **Step 3: Crear `lib/hoja_configuracion.dart`**

```dart
import 'package:flutter/material.dart';

import 'funciones.dart';
import 'glass.dart';
import 'l10n/app_localizations.dart';
import 'selector_idioma.dart';
import 'sesion.dart';

/// Ajustes de la cuenta, desde "Mis grupos".
///
/// Reúne idioma, PIN y cerrar sesión en un sitio. Antes el idioma era un
/// icono suelto en la barra y cerrar sesión otro: dos iconos de ajustes
/// sin un sitio donde vivir.
class HojaConfiguracion extends StatefulWidget {
  /// Qué hacer al cerrar sesión. La hoja no navega: "Mis grupos" es quien
  /// sabe a dónde se va y cómo se vacía la pila.
  ///
  /// El tipo es `Future<void> Function()` y no `VoidCallback` porque quien
  /// la implementa tiene que esperar a `cerrarSesion()` antes de navegar.
  final Future<void> Function() alCerrarSesion;

  const HojaConfiguracion({super.key, required this.alCerrarSesion});

  static Future<void> mostrar(BuildContext context,
      {required Future<void> Function() alCerrarSesion}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HojaConfiguracion(alCerrarSesion: alCerrarSesion),
    );
  }

  @override
  State<HojaConfiguracion> createState() => _HojaConfiguracionState();
}

class _HojaConfiguracionState extends State<HojaConfiguracion> {
  bool _cambiandoPin = false;

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  /// Cambiar el PIN pide la contraseña de la cuenta. Es la única salida si
  /// se olvida: sin ella, cuatro dígitos perdidos dejarían a esa persona
  /// sin ver su amigo secreto para siempre.
  Future<void> _cambiarPin() async {
    final t = Textos.of(context);
    final password = TextEditingController();
    final pinNuevo = TextEditingController();

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t.cambiarPinTitulo),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.cambiarPinTexto, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: password,
              obscureText: true,
              decoration: InputDecoration(labelText: t.cambiarPinPassword),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pinNuevo,
              obscureText: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(labelText: t.cambiarPinNuevo),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t.cancelar)),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(t.cambiarPinGuardar)),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    setState(() => _cambiandoPin = true);
    try {
      final sesion = await leerSesion();
      if (sesion == null) {
        _avisar('⚠️ ${t.errorSesionInvalida}');
        return;
      }
      await llamarFuncion('cambiarPin', {
        'nickname': sesion.nickname,
        'password': password.text,
        'pinNuevo': pinNuevo.text.trim(),
      });
      _avisar('✅ ${t.cambiarPinGuardado}');
    } catch (e) {
      if (!mounted) return;
      _avisar('⚠️ ${e is FuncionError ? e.texto(t) : t.errorInesperado(e.toString())}');
    } finally {
      if (mounted) setState(() => _cambiandoPin = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colorNeutro.shade50,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.configuracion,
                textAlign: TextAlign.center, style: tituloGlass(colorNeutro)),
            const SizedBox(height: 20),
            const CampoIdioma(),
            const SizedBox(height: 16),
            GlassOutlineButton(
              color: colorNeutro,
              icon: Icons.pin_outlined,
              label: t.configuracionCambiarPin,
              onPressed: _cambiandoPin ? null : _cambiarPin,
            ),
            const SizedBox(height: 16),
            GlassOutlineButton(
              color: colorNeutro,
              icon: Icons.logout,
              label: t.misGruposCerrarSesion,
              onPressed: widget.alCerrarSesion,
            ),
          ],
        ),
      ),
    );
  }
}
```

Nota: `tituloGlass` vive en `lib/ocasion.dart`; si el import falla, añadirlo.

- [ ] **Step 4: Correr el test**

Run: `flutter test test/hoja_configuracion_test.dart`
Expected: PASS los dos tests.

- [ ] **Step 5: Sustituir los dos iconos de la barra por uno**

En `lib/pantalla_mis_grupos.dart`, sustituir el bloque `actions:` entero (líneas 88-105) por:

```dart
            actions: [
              IconButton(
                icon: Icon(Icons.settings_outlined, color: colorNeutro.shade800),
                tooltip: t.configuracion,
                onPressed: () => HojaConfiguracion.mostrar(
                  context,
                  alCerrarSesion: () async {
                    await cerrarSesion();
                    if (!context.mounted) return;
                    // Se cierra la hoja y se vuelve a la raíz por nombre de
                    // ruta, no importando el portero. Importarlo aquí
                    // crearía un ciclo: el portero ya importa esta pantalla
                    // para navegar hacia ella. La raíz '/' es el `home:` de
                    // MaterialApp, o sea el propio portero, que al no
                    // encontrar sesión manda al registro.
                    Navigator.of(context).pop();
                    Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
                  },
                ),
              ),
            ],
```

Cambiar el import de `selector_idioma.dart` por `hoja_configuracion.dart`.

- [ ] **Step 6: Borrar `IconoIdioma`**

En `lib/selector_idioma.dart`, borrar la clase `IconoIdioma` entera (líneas 10-33). `CampoIdioma` se queda: lo usan la pantalla de crear cuenta y ahora la hoja de configuración.

En `test/selector_idioma_test.dart`, borrar el test `'el icono se dibuja'` y cualquier otro que use `IconoIdioma`.

- [ ] **Step 7: Verificar**

```bash
flutter analyze
flutter test
```
Expected: sin errores en `pantalla_mis_grupos.dart`, `selector_idioma.dart` ni `hoja_configuracion.dart`. Todos los tests de esos ficheros pasan.

- [ ] **Step 8: Commit**

```bash
git add lib/hoja_configuracion.dart lib/pantalla_mis_grupos.dart lib/selector_idioma.dart test/hoja_configuracion_test.dart test/selector_idioma_test.dart
git commit -m "Configuración: idioma, PIN y cerrar sesión en un solo sitio"
```

---

### Task 10: Crear y editar grupo sin PIN maestro, y borrar escribiendo el nombre

**Files:**
- Modify: `lib/pantalla_crear_grupo.dart`
- Modify: `lib/pantalla_editar_grupo.dart`
- Test: `test/eliminar_grupo_test.dart` (nuevo)

**Interfaces:**
- Consumes: `editarEliminarEscribeNombre` (Task 1), `leerSesion` (`lib/sesion.dart`).
- Produces: nada.

- [ ] **Step 1: Escribir el test que falla**

Crear `test/eliminar_grupo_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santa_secreto/l10n/app_localizations.dart';
import 'package:santa_secreto/pantalla_editar_grupo.dart';

Widget _envoltorio(Widget hijo) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('es')],
      localizationsDelegates: Textos.localizationsDelegates,
      home: hijo,
    );

void main() {
  testWidgets('el botón de eliminar no se activa hasta escribir el nombre',
      (tester) async {
    await tester.pumpWidget(_envoltorio(const DialogoEliminarGrupo(
        nombreGrupo: 'Navidad Familia')));
    await tester.pumpAndSettle();

    // Arranca inactivo: el PIN maestro ya no hace de freno previo, así que
    // este es el único paso que impide borrar un grupo sin querer.
    final boton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(boton.onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Navidad Famili');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Navidad Familia');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);
  });
}
```

- [ ] **Step 2: Correr el test para verificar que falla**

Run: `flutter test test/eliminar_grupo_test.dart`
Expected: FAIL — `DialogoEliminarGrupo` no existe.

- [ ] **Step 3: Extraer el diálogo a un widget propio**

En `lib/pantalla_editar_grupo.dart`, añadir al final del fichero:

```dart
/// Confirmación de borrado de grupo. Vive en su propio widget para poder
/// probarlo sin montar la pantalla entera ni tocar Firebase.
///
/// Exige teclear el nombre exacto porque el PIN maestro, que antes hacía
/// de freno sin querer, ya no existe. Se eligió esto y no la contraseña de
/// la cuenta a propósito: acostumbrar a la gente a teclear su contraseña
/// dentro de la app para acciones corrientes es el hábito del que viven
/// los engaños.
class DialogoEliminarGrupo extends StatefulWidget {
  final String nombreGrupo;

  const DialogoEliminarGrupo({super.key, required this.nombreGrupo});

  @override
  State<DialogoEliminarGrupo> createState() => _DialogoEliminarGrupoState();
}

class _DialogoEliminarGrupoState extends State<DialogoEliminarGrupo> {
  final _confirmacion = TextEditingController();

  @override
  void dispose() {
    _confirmacion.dispose();
    super.dispose();
  }

  bool get _coincide => _confirmacion.text.trim() == widget.nombreGrupo.trim();

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    return AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 40),
      title: Text(t.editarEliminarTitulo),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(t.editarEliminarTexto(widget.nombreGrupo)),
          const SizedBox(height: 16),
          Text(t.editarEliminarEscribeNombre(widget.nombreGrupo),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmacion,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancelar)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          onPressed: _coincide ? () => Navigator.pop(context, true) : null,
          child: Text(t.editarEliminarConfirmar),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Usar el diálogo nuevo y quitar el PIN maestro**

En `_confirmarEliminar()`, sustituir el `showDialog` entero por:

```dart
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (c) => DialogoEliminarGrupo(nombreGrupo: widget.nombreGrupo),
    );
```

Y en las dos `llamarFuncion` de esta pantalla (`editarGrupo` en la línea 98 y `eliminarGrupo` en la 139), quitar `'pinMaestro': widget.pinMaestro` y poner las credenciales:

```dart
      final sesion = await leerSesion();
      if (sesion == null) { _avisar('⚠️ ${t.errorSesionInvalida}'); return; }
      await llamarFuncion('eliminarGrupo', {
        'codigo': widget.codigo,
        'nickname': sesion.nickname,
        'password': sesion.password,
      });
```

Borrar el campo `final String pinMaestro;` del widget y su parámetro del constructor. Importar `sesion.dart`.

- [ ] **Step 5: Quitar el PIN maestro de crear grupo**

En `lib/pantalla_crear_grupo.dart`: borrar `_pinController` y su `dispose()`, borrar el `GlassTextField` que lo mostraba (líneas 181-189), quitar `pin` de la validación de `crearFaltanDatos`, y quitar `'pinMaestro': pin` de la llamada. Las credenciales dejan de ser opcionales:

```dart
      final sesion = await leerSesion();
      if (sesion == null) {
        _avisar('⚠️ ${t.errorSesionInvalida}');
        return;
      }
      final datos = await llamarFuncion('crearGrupo', {
        'ocasion': _ocasion.id,
        'nombreGrupo': nombreGrupo,
        'valorMinimo': valorMinimo,
        'tematica': _tematica.id,
        'reglas': _tematica.reglasPorDefecto(t),
        'nickname': sesion.nickname,
        'password': sesion.password,
      });
```

- [ ] **Step 6: Correr los tests**

```bash
flutter test test/eliminar_grupo_test.dart
flutter analyze
```
Expected: el test pasa y `analyze` dice `No issues found!`.

- [ ] **Step 7: Commit**

```bash
git add lib/pantalla_crear_grupo.dart lib/pantalla_editar_grupo.dart test/eliminar_grupo_test.dart
git commit -m "Crear y editar grupo por cuenta; borrar exige escribir el nombre"
```

---

### Task 11: El chat por cuenta, y fuera la identidad local

**Files:**
- Modify: `lib/pantalla_chat.dart`
- Delete: `lib/hoja_identidad.dart`
- Delete: `lib/identidad_local.dart`
- Modify: `lib/pantalla_registro.dart` — el paso del vínculo al chat

**Interfaces:**
- Consumes: `MiVinculo` (Task 6), `enviarMensaje` / `miMascara` / `borrarMensaje` por cuenta (Task 4).
- Produces: `PantallaChat` gana `MiVinculo? vinculo` y pierde `pinMaestro`.

**Aviso:** esta tarea NO rediseña el chat. Las máscaras, la espera entre mensajes y la moderación se quedan tal cual — eso es P3. Aquí solo se le quita la identidad por PIN, porque `hoja_identidad.dart` se borra y el chat era su otro consumidor.

- [ ] **Step 1: Cambiar los parámetros del widget**

En `lib/pantalla_chat.dart`, sustituir `final bool esOrganizador;` y `final String pinMaestro;` por:

```dart
  /// Tu vínculo con el grupo: dice si eres organizador (para moderar) y
  /// qué participante eres (para resaltar tus mensajes).
  final MiVinculo? vinculo;
```

y en el constructor, `this.vinculo,` en lugar de los dos.

- [ ] **Step 2: Quitar la identidad local**

Borrar el campo `IdentidadGrupo? _yo;`, `bool _pidiendoIdentidad = false;`, y los métodos `_recuperarIdentidad()` (74-79), `_asegurarIdentidad()` (107-123) y `_cambiarPersona()` (125-133).

En `initState`, sustituir `_recuperarIdentidad();` por `_cargarMiMascara();`.

Reescribir `_cargarMiMascara`:

```dart
  Future<void> _cargarMiMascara() async {
    if (widget.vinculo?.estoyDentro != true) return;
    final sesion = await leerSesion();
    if (sesion == null) return;
    try {
      final datos = await llamarFuncion('miMascara', {
        'codigo': widget.codigo,
        'nickname': sesion.nickname,
        'password': sesion.password,
      });
      if (!mounted) return;
      setState(() => _miMascara = datos['mascara'] as int?);
    } catch (_) {
      // Sin máscara solo se pierde el resaltado de los propios mensajes;
      // leer el chat sigue funcionando.
    }
  }
```

- [ ] **Step 3: Reescribir el envío y el borrado**

En `_enviar()`, quitar la llamada a `_asegurarIdentidad()` y sustituir la llamada:

```dart
    final sesion = await leerSesion();
    if (sesion == null || !mounted) return;

    setState(() => _enviando = true);
    try {
      final datos = await llamarFuncion('enviarMensaje', {
        'codigo': widget.codigo,
        'texto': texto,
        'nickname': sesion.nickname,
        'password': sesion.password,
      });
```

En `_borrarMensaje()`:

```dart
      final sesion = await leerSesion();
      if (sesion == null) return;
      await llamarFuncion('borrarMensaje', {
        'codigo': widget.codigo,
        'mensajeId': mensajeId,
        'nickname': sesion.nickname,
        'password': sesion.password,
      });
```

- [ ] **Step 4: Ajustar la interfaz**

En `build`, borrar el `IconButton` de `chatCambiarPersona` del `actions:` (queda `actions:` vacío, o se quita entero).

En `_listaMensajes`, sustituir `widget.esOrganizador` por `widget.vinculo?.esOrganizador == true`.

En `_redactor`, desactivar el envío si no estás dentro:

```dart
              onPressed: (_enviando || widget.vinculo?.estoyDentro != true)
                  ? null
                  : _enviar,
```

Cambiar los imports: fuera `hoja_identidad.dart` e `identidad_local.dart`, dentro `mi_vinculo.dart` y `sesion.dart`.

- [ ] **Step 5: Pasar el vínculo desde la pantalla del grupo**

En `lib/pantalla_registro.dart`, en el botón del chat, sustituir `esOrganizador: _esOrganizador, pinMaestro: _pinMaestro` por:

```dart
                              vinculo: _vinculo,
```

- [ ] **Step 6: Borrar los dos ficheros muertos**

```bash
git rm lib/hoja_identidad.dart lib/identidad_local.dart
```

- [ ] **Step 7: Verificar que no queda ni un uso**

```bash
grep -rn "identidad_local\|hoja_identidad\|IdentidadGrupo\|leerIdentidad\|guardarIdentidad\|olvidarIdentidad" lib/ test/
```
Expected: **sin ninguna coincidencia**.

- [ ] **Step 8: Verificar entero**

```bash
flutter analyze
flutter test
```
Expected: `No issues found!` y **todos** los tests en verde. A partir de aquí, ningún fichero de `lib/` usa ya las 16 claves ARB muertas: la Task 12 puede borrarlas.

- [ ] **Step 9: Commit**

```bash
git add -A lib/
git commit -m "El chat va por cuenta; fuera la identidad guardada en disco

hoja_identidad.dart e identidad_local.dart se borran. Sus claves de disco
se llamaban chat_{codigo}_pin: nacieron para el chat, cuando no había
cuentas. El chat en sí no cambia todavía -eso es P3-, solo deja de pedir
un PIN para saber quién eres."
```

---

### Task 12: Borrar las claves muertas, reglas, script de integración y verificación final

**Files:**
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_es.arb` — borrar las 16 claves muertas
- Modify: `test/arb_paridad_test.dart` — añadir el test que impide que resuciten
- Modify: `firestore.rules` — los comentarios describen PINs que ya no existen
- Modify: `functions/index.js:23-28, 106-109` — comentarios de cabecera
- Create: `scripts/probar.mjs`
- Modify: `docs/superpowers/specs/2026-08-09-cuenta-como-identidad-design.md` — corregir la referencia a `scratchpad/probar.ps1`

**Interfaces:**
- Consumes: todas las funciones desplegadas.
- Produces: `node scripts/probar.mjs` como prueba de integración contra producción.

- [ ] **Step 1: Escribir el test que falla**

Añadir a `test/arb_paridad_test.dart`, dentro de `main()`:

```dart
  test('no quedan claves de los PIN por grupo', () {
    final en = _clavesDe('lib/l10n/app_en.arb');
    // Los PIN por participante y el PIN maestro desaparecieron. Si alguna
    // de estas reaparece, es que se resucitó código muerto con ella.
    for (final muerta in const [
      'crearPinMaestro',
      'crearPinMaestroAyuda',
      'registroPin',
      'registroPinAyuda',
      'registroTuPin',
      'organizadorPinTexto',
      'organizadorPinCampo',
      'organizadorEntrar',
      'organizadorSalir',
      'organizadorActivado',
      'organizadorDesactivado',
      'loginTitulo',
      'loginHola',
      'chatQuienEres',
      'chatQuienEresTexto',
      'chatCambiarPersona',
    ]) {
      expect(en.contains(muerta), isFalse, reason: '$muerta debería estar borrada');
    }
  });
```

- [ ] **Step 2: Correr el test para verificar que falla**

Run: `flutter test test/arb_paridad_test.dart`
Expected: FAIL — `crearPinMaestro debería estar borrada`.

- [ ] **Step 3: Borrar las 16 claves muertas de los dos ARB**

En `lib/l10n/app_en.arb` y `lib/l10n/app_es.arb`, borrar estas claves **y sus bloques `@clave` de metadatos si los tienen**:

`crearPinMaestro`, `crearPinMaestroAyuda`, `registroPin`, `registroPinAyuda`, `registroTuPin`, `organizadorPinTexto`, `organizadorPinCampo`, `organizadorEntrar`, `organizadorSalir`, `organizadorActivado`, `organizadorDesactivado`, `loginTitulo`, `loginHola`, `chatQuienEres`, `chatQuienEresTexto`, `chatCambiarPersona`.

- [ ] **Step 4: Regenerar, y comprobar que no las usaba nadie**

```bash
flutter gen-l10n
flutter test test/arb_paridad_test.dart
flutter analyze
```
Expected: los tres tests de paridad pasan y `analyze` dice `No issues found!`. **Si `analyze` falla, es que queda código vivo usando una clave que se acaba de borrar** — arreglar ese código, no devolver la clave.

- [ ] **Step 5: Corregir los comentarios de `firestore.rules`**

Las reglas en sí **no cambian** (todo sigue cerrado al cliente salvo las lecturas públicas), pero sus comentarios describen campos que ya no existen. Sustituir los dos bloques equivocados:

```
// grupos/{codigo}/privado/data: las máscaras ya repartidas en el chat.
// Cero acceso de cliente en cualquier dirección. El PIN maestro que vivía
// aquí desapareció: ser organizador lo dice tu cuenta.
```

```
// grupos/{codigo}/participantes/{id}/privado/data: de qué cuenta es esta
// plaza, la lista de deseos, a quién le regala y su máscara del chat.
// Cero acceso de cliente. El PIN del participante que vivía aquí
// desapareció.
```

Y en el bloque de `usuarios/{nickname}`, añadir que ahora guarda también el `pinHash` y el mapa de grupos.

- [ ] **Step 6: Corregir los comentarios de `functions/index.js`**

En la cabecera de avatares (línea 26-28), sustituir *"el PIN del participante es la autorización"* por *"la cuenta es la autorización"*.

En la cabecera de cuentas (línea 106-109), sustituir el párrafo entero por:

```js
// --- Cuentas (nickname + contraseña + PIN) ---------------------------
// La cuenta es la ÚNICA credencial de autorización de la app. El PIN de 4
// dígitos es una segunda barrera para una sola acción —revelar tu amigo
// secreto— y no autoriza nada más.
//
// Antes había un PIN por participante y un PIN maestro por grupo, los dos
// en texto plano. Eran de cuando no existían las cuentas.
```

- [ ] **Step 7: Crear el script de integración**

Crear `scripts/probar.mjs`. **Node 20 trae `fetch` global, así que no hace falta ninguna dependencia.**

```js
// Prueba de integración contra las funciones DESPLEGADAS.
//
// Vive en el repo a propósito: la versión anterior era un .ps1 en un
// directorio de sesión sin trackear y se perdió, así que hubo que
// reescribirla de memoria.
//
// Uso:  node scripts/probar.mjs
// Crea una cuenta y un grupo de usar y tirar, y los borra al terminar.

const BASE = "https://us-central1-santa-secreto-860c3.cloudfunctions.net";

const sufijo = Date.now().toString(36);
const NICK = `prueba_${sufijo}`;
const PASSWORD = "Prueba123!";
const PIN = "4321";

let fallos = 0;

async function llamar(nombre, datos) {
  const resp = await fetch(`${BASE}/${nombre}`, {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({data: datos}),
  });
  const body = await resp.json();
  if (body.error) {
    const err = new Error(body.error.message);
    err.clave = body.error.details?.clave;
    throw err;
  }
  return body.result;
}

function ok(titulo, condicion, detalle = "") {
  if (condicion) {
    console.log(`  OK  ${titulo}`);
  } else {
    fallos++;
    console.error(`FALLO ${titulo} ${detalle}`);
  }
}

// Comprueba que una llamada falla CON la clave esperada. Que falle por
// otra razón no vale: sería pasar la prueba por accidente.
async function debeFallar(titulo, claveEsperada, fn) {
  try {
    await fn();
    fallos++;
    console.error(`FALLO ${titulo} — no lanzó`);
  } catch (e) {
    ok(titulo, e.clave === claveEsperada, `esperaba ${claveEsperada}, llegó ${e.clave}`);
  }
}

async function main() {
  console.log(`Cuenta de prueba: ${NICK}`);

  await debeFallar("registrarCuenta rechaza un PIN de 3 dígitos", "pin_formato",
      () => llamar("registrarCuenta", {nickname: NICK, password: PASSWORD, pin: "123"}));

  await llamar("registrarCuenta", {nickname: NICK, password: PASSWORD, pin: PIN});
  ok("registrarCuenta con PIN de 4 dígitos", true);

  const cred = {nickname: NICK, password: PASSWORD};

  const {codigo} = await llamar("crearGrupo", {
    ...cred, ocasion: "amigoSecreto", nombreGrupo: "Grupo de prueba",
    valorMinimo: "10", tematica: "", reglas: "",
  });
  ok("crearGrupo sin PIN maestro", typeof codigo === "string");

  // EL BUG QUE ORIGINÓ TODO ESTO: crear un grupo y apuntarse a él lo sacaba
  // DOS veces en Mis grupos, porque arrayUnion guardaba dos entradas.
  const {id} = await llamar("agregarParticipante", {
    ...cred, codigo, nombre: "Yo mismo", deseos: "Nada",
  });

  const sesion = await llamar("iniciarSesionCuenta", cred);
  const deEsteGrupo = sesion.grupos.filter((g) => g.codigo === codigo);
  ok("el grupo sale UNA sola vez tras crearlo y apuntarse",
      deEsteGrupo.length === 1, `salió ${deEsteGrupo.length} veces`);
  ok("conserva el rol de organizador", deEsteGrupo[0]?.rol === "organizador");
  ok("trae el participanteId", deEsteGrupo[0]?.participanteId === id);
  ok("todavía sin sortear", deEsteGrupo[0]?.sorteado === false);

  await debeFallar("verAmigoSecreto rechaza un PIN equivocado", "pin_incorrecto",
      () => llamar("verAmigoSecreto", {...cred, codigo, pin: "0000"}));

  await debeFallar("una contraseña equivocada no autoriza nada", "sesion_invalida",
      () => llamar("ejecutarSorteo", {nickname: NICK, password: "Otra123!", codigo}));

  // Antes del sorteo sí se puede sacar a alguien.
  const segundo = await llamar("agregarParticipante", {
    ...cred, codigo, nombre: "Sobrante", deseos: "",
  });
  await llamar("borrarParticipante", {...cred, codigo, participanteId: segundo.id});
  ok("antes del sorteo se puede sacar a alguien", true);

  // Se necesitan dos para sortear.
  await llamar("agregarParticipante", {...cred, codigo, nombre: "Otra persona", deseos: ""});
  await llamar("ejecutarSorteo", {...cred, codigo});
  ok("ejecutarSorteo por cuenta", true);

  const trasSorteo = await llamar("iniciarSesionCuenta", cred);
  ok("el grupo queda marcado como sorteado",
      trasSorteo.grupos.find((g) => g.codigo === codigo)?.sorteado === true);

  const amigo = await llamar("verAmigoSecreto", {...cred, codigo, pin: PIN});
  ok("verAmigoSecreto con el PIN correcto", typeof amigo.nombreAmigo === "string");
  ok("devuelve tu propio nombre", amigo.nombre === "Yo mismo");

  await debeFallar("tras el sorteo NO se puede sacar a nadie", "grupo_ya_sorteado",
      () => llamar("borrarParticipante", {...cred, codigo, participanteId: id}));

  await llamar("cambiarPin", {nickname: NICK, password: PASSWORD, pinNuevo: "9876"});
  await debeFallar("el PIN viejo ya no vale", "pin_incorrecto",
      () => llamar("verAmigoSecreto", {...cred, codigo, pin: PIN}));
  ok("cambiarPin", true);

  await llamar("eliminarGrupo", {...cred, codigo});
  const final = await llamar("iniciarSesionCuenta", cred);
  ok("al eliminar el grupo desaparece de Mis grupos",
      final.grupos.every((g) => g.codigo !== codigo));

  console.log(fallos === 0 ? "\nTodo en verde." : `\n${fallos} fallo(s).`);
  process.exit(fallos === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error("Reventó:", e.message, e.clave || "");
  process.exit(1);
});
```

- [ ] **Step 8: Desplegar el backend y borrar los datos viejos**

Este es el momento del corte, y los dos pasos van juntos: el backend nuevo no entiende los datos viejos y el cliente viejo no entiende el backend nuevo.

```bash
firebase deploy --only functions
```
Expected: `verificarOrganizador` e `iniciarSesion` aparecen como funciones **borradas**; `verAmigoSecreto` y `cambiarPin` como **nuevas**. Confirmar el borrado cuando lo pregunte.

Después, en la consola de Firebase → Firestore, **borrar las colecciones `grupos` y `usuarios` enteras**. No hay migración: el modelo viejo (array `grupos`, PINs en claro) es incompatible y no hay datos reales que preservar — solo grupos de prueba del propio desarrollador.

- [ ] **Step 9: Correr la prueba de integración**

Run: `node scripts/probar.mjs`
Expected: **Todo en verde**, salida 0. Si algo falla, arreglar el backend y volver a desplegar antes de seguir — esta prueba es la única verificación real que tiene el servidor.

- [ ] **Step 10: Corregir la referencia muerta del spec**

En `docs/superpowers/specs/2026-08-09-cuenta-como-identidad-design.md`, en la sección "Verificación", sustituir *"Reescribir `scratchpad/probar.ps1`"* por *"`node scripts/probar.mjs`, la prueba de integración contra producción. El `scratchpad/probar.ps1` que mencionaban las sesiones anteriores nunca estuvo en el repo y se perdió; el nuevo vive trackeado."*

- [ ] **Step 11: Verificación final**

```bash
flutter analyze
flutter test
grep -rn "pinMaestro\|IdentidadGrupo\|verificarOrganizador\|pantalla_login" lib/ functions/ test/
```
Expected: `No issues found!`, todos los tests en verde, y el `grep` **sin ninguna coincidencia**.

- [ ] **Step 12: Desplegar y probar en dispositivo**

```bash
flutter build web --release
firebase deploy --only hosting
```

Las funciones ya se desplegaron en el Step 8; aquí solo va el cliente.

Con los datos del sitio borrados o en incógnito **antes de cada camino** (el service worker sirve el build anterior y ya engañó a dos sesiones):

1. Crear cuenta con PIN de 4 dígitos → Mis grupos vacío.
2. Crear un grupo → apuntarse → volver → **aparece UNA sola vez**.
3. Ver mi amigo secreto → pide el PIN → con el PIN equivocado no entra.
4. Configuración → cambiar idioma, cambiar PIN, cerrar sesión.
5. Con una segunda cuenta: unirse al grupo → **no ve los controles de organizador**.
6. Sortear → intentar sacar a alguien → sale el aviso de que hay que reemplazarle.
7. Editar grupo → Eliminar → el botón rojo no se activa hasta escribir el nombre exacto.

- [ ] **Step 13: Commit**

```bash
git add lib/l10n/ test/arb_paridad_test.dart firestore.rules functions/index.js scripts/probar.mjs docs/superpowers/specs/2026-08-09-cuenta-como-identidad-design.md
# `lib/l10n/` incluye los tres app_localizations*.dart regenerados en el Step 4.
# Están trackeados: sin ellos el checkout no compila.
git commit -m "Fuera las claves muertas, prueba de integración y comentarios al día

El probar.ps1 de las sesiones anteriores vivía en un scratchpad sin
trackear y se perdió. Este vive en scripts/ y cubre el bug que originó
todo: crear un grupo y apuntarse sacaba el grupo dos veces."
```

---

## Lo que este plan NO hace

Está escrito aquí para que nadie lo dé por olvidado:

- **P4 — reemplazar un participante.** La contrapartida obligatoria de la prohibición de la Task 4. Hasta que exista, un grupo que ya sorteó no tiene forma de resolver que alguien se caiga. Va inmediatamente después de este plan.
- **P3 — el chat sin máscaras.** La Task 11 le quita el PIN al chat, nada más. Máscaras, anti-spam y moderación siguen igual.
- **P1 — las invitaciones QR.** Borrar la lista `invitaciones_consumidas`.
- **Recuperación de contraseña.** Sigue sin existir, y este plan la hace más urgente: sin PIN maestro, la cuenta es la única llave de tus grupos.
