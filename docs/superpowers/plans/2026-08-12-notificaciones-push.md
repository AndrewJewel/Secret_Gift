# Notificaciones push (FCM) — Plan de implementación

> **Para quien lo ejecute:** SUB-SKILL OBLIGATORIA: usa
> superpowers:subagent-driven-development (recomendado) o
> superpowers:executing-plans para implementar tarea a tarea. Los pasos
> usan casillas (`- [ ]`) para llevar la cuenta.

**Objetivo:** que a quien le cambia algo en su grupo —le reemplazan su
amigo secreto, el grupo sortea, alguien escribe en el chat— le llegue un
aviso al teléfono aunque tenga la app cerrada.

**Arquitectura:** el servidor guarda los tokens de FCM de cada cuenta en un
mapa dentro de `usuarios/{uid}` y los usa desde un helper (`avisar`) que
nunca hace fallar a quien lo llama. Tres funciones ya existentes lo invocan
después de haber escrito en Firestore. En el cliente, el permiso se pide
detrás de una pantalla propia para no gastar el del navegador, y la
supresión de avisos mientras miras el chat se resuelve en primer plano, sin
que el servidor sepa nada de presencia.

**Web y Android, las dos.** `firebase_messaging` funciona igual en ambas y
casi todo el código se comparte: el servidor entero, los textos, la
pantalla de permiso y el enganche. Lo único que se bifurca es cómo se
identifica el dispositivo — en web hace falta un *service worker* y una
clave VAPID; en Android, el `google-services.json`.

**Tecnologías:** Cloud Functions v2 (Node 22), `firebase-admin` 14.2.0
modular, `firebase_messaging` en Flutter web y Android, un *service worker*
propio de FCM.

**Spec:** `docs/superpowers/specs/2026-08-09-notificaciones-push-design.md`
— **revisado el 2026-08-12**, con cuatro correcciones marcadas en su sitio.
Léelo antes de empezar.

## Restricciones globales

- **Flutter 3.38.10 / Dart 3.10.9.** Nada de sintaxis de Dart 3.12
  (parámetros nombrados privados, constructores primarios): **no compila**.
- **`firebase-admin` 14.2.0 es modular.** `admin.messaging()` **no existe**.
  Va `const {getMessaging} = require("firebase-admin/messaging")`. Lo mismo
  que ya se hace con `getFirestore`, `FieldValue`, `FieldPath` y
  `getStorage` en la cabecera de `functions/index.js`.
- **Proyecto Firebase: `secretgift-app`** (997384680563). La clave VAPID y
  la configuración del *service worker* salen de **ahí**. Una clave del
  proyecto viejo falla sin decir por qué.
- **El cliente NO usa el paquete `cloud_functions`** (bug de dart2js,
  flutterfire#17924). Toda llamada al servidor pasa por `llamarFuncion` en
  `lib/funciones.dart`, que adjunta a mano `Authorization: Bearer`.
- **Los errores se traducen por una `clave`** que la función pone en
  `details`. Cada clave nueva necesita: un `case` en el `switch` de
  `lib/funciones.dart`, y la entrada en **los dos** ARB.
- **`lib/l10n/app_en.arb` es la plantilla**: cada clave necesita además su
  `@clave` con `description`. Los generados
  `lib/l10n/app_localizations*.dart` **están commiteados en git** y
  `flutter test` **NO** los regenera — hay que correr `flutter gen-l10n` (o
  un build) y commitear el resultado.
- **Los textos de las notificaciones no llevan nombres ni contenido.** Se
  leen desde la pantalla de bloqueo, con el teléfono en la mano de
  cualquiera.
- **`avisar` nunca hace fallar a quien la llama.** Si el envío truena, se
  registra y se sigue. Un reemplazo escrito no puede deshacerse porque una
  notificación no saliera.
- Comentarios y mensajes de commit **en español**, siguiendo el estilo del
  repositorio: explican el *porqué*, no el *qué*.

## Las dos cosas que solo puede dar el humano

Ninguna se puede inventar, y las dos llegan de la consola de Firebase del
proyecto **`secretgift-app`**. Si falta alguna cuando toque, **para y
pídela** — un valor de relleno da errores genéricos que se confunden con
diez cosas más y se pierde media tarde.

| Qué | De dónde | Se necesita en |
|---|---|---|
| **`google-services.json`** del proyecto nuevo | Configuración del proyecto → Tus apps → **Añadir app → Android**, con el paquete **`app.secretgift`** | **Tarea 1** |
| **Clave VAPID** (cadena larga que empieza por `B`) | Configuración del proyecto → **Cloud Messaging** → Web Push certificates → Generar par de claves | **Tarea 7** |

**Las Tareas 2 a 6 no necesitan ninguna de las dos.** Todo el servidor, la
traducción y la pantalla de permiso se escriben, se prueban y se commitean
sin bloquearse.

## Por qué Android va primero

Hoy la app Android apunta al **proyecto viejo**: `android/app/google-services.json`
dice `santa-secreto-860c3`. Si se construyera el APK antes de arreglarlo,
los tokens de push se guardarían **en la base de datos equivocada, en
silencio** — el proyecto viejo sigue vivo y responde, así que no daría
ningún error.

Y el paquete es `com.example.santa_secreto`. `com.example` es el valor de
ejemplo de Flutter y **Google Play no lo acepta**, así que hay que
cambiarlo igualmente antes de publicar.

## Estructura de ficheros

| Fichero | Responsabilidad |
|---|---|
| `functions/push.js` **(nuevo)** | `tokensMuertos()` puro y `avisar()`. Aparte de `index.js` **a propósito**: Firebase despliega lo que encuentre exportado en `index.js`, y un helper exportado ahí sería un despliegue accidental. Además así el helper puro se prueba sin cargar nada de Firebase. |
| `functions/push.test.js` **(nuevo)** | Test unitario de `tokensMuertos` con `node:test`, que ya viene en Node 22. |
| `functions/index.js` | `guardarTokenPush` nueva, y los tres avisos enganchados en `canjearReemplazo`, `ejecutarSorteo` y `enviarMensaje`. |
| `android/app/build.gradle.kts`, `android/app/src/main/kotlin/**/MainActivity.kt`, `android/app/google-services.json` | El paquete pasa a `app.secretgift` y el proyecto al nuevo. |
| `android/app/src/main/AndroidManifest.xml` | Permiso `POST_NOTIFICATIONS`, que Android 13+ exige. |
| `web/firebase-messaging-sw.js` **(nuevo)** | *Service worker* de FCM. Segundo *service worker* de la app. Solo web. |
| `lib/push.dart` **(nuevo)** | Permiso, token, renovación, primer plano y toque de notificación. Único sitio que habla con `firebase_messaging`. **Sirve para web y Android**: `firebase_messaging` soporta las dos, así que no hace falta implementación condicional — solo un `kIsWeb` para la clave VAPID. |
| `lib/pantalla_permiso_avisos.dart` **(nuevo)** | La pantalla propia con «Sí, avísame» / «Ahora no». |
| `lib/almacen_local.dart` | Recuerda que ya se preguntó, para no preguntar en cada arranque. |
| `lib/pantalla_raiz.dart`, `lib/pantalla_crear_cuenta.dart`, `lib/pantalla_iniciar_sesion.dart` | Enganchan la pantalla de permiso tras verificar el correo. |
| `lib/pantalla_chat.dart` | Declara qué grupo se está mirando, para la supresión en primer plano. |
| `lib/l10n/app_es.arb`, `lib/l10n/app_en.arb` | Textos nuevos. |
| `scripts/probar.mjs` | Casos de `guardarTokenPush`. |

---

### Tarea 1: Android deja de apuntar al proyecto viejo

> **ESTA TAREA NECESITA AL HUMANO.** Hay que registrar la app Android en la
> consola de `secretgift-app` y bajar el `google-services.json`. Si no lo
> tienes, **para y pídelo**. No sirve editar a mano el fichero viejo: lleva
> dentro identificadores y claves de API que solo genera la consola.

**Ficheros:**
- Modificar: `android/app/build.gradle.kts` (líneas 9 y 23)
- Mover: `android/app/src/main/kotlin/com/example/santa_secreto/MainActivity.kt`
  → `android/app/src/main/kotlin/app/secretgift/MainActivity.kt`
- Reemplazar: `android/app/google-services.json`
- Modificar: `android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Consume: nada.
- Produce: una app Android cuyo `applicationId` es `app.secretgift` y que
  habla con el proyecto `secretgift-app`. Las Tareas 7 y 10 dependen de esto.

**Por qué esto va antes que nada:** hoy `android/app/google-services.json`
dice `"project_id": "santa-secreto-860c3"`. Un APK construido ahora
guardaría los tokens de push **en la base de datos del proyecto viejo, sin
dar ningún error** — ese proyecto sigue vivo y responde. Sería un fallo
silencioso, del peor tipo posible.

Y `com.example` es el paquete de ejemplo de Flutter: **Google Play no
acepta publicar con él**, así que el cambio hay que hacerlo igualmente.

- [ ] **Paso 1: Comprueba de dónde partes**

```bash
grep -o '"project_id": *"[^"]*"' android/app/google-services.json
grep -n "namespace\|applicationId" android/app/build.gradle.kts
find android -name "MainActivity.kt"
```

Esperado antes de tocar nada: `santa-secreto-860c3`, dos veces
`com.example.santa_secreto`, y el fichero en
`android/app/src/main/kotlin/com/example/santa_secreto/MainActivity.kt`.

- [ ] **Paso 2: Pon el `google-services.json` nuevo**

Sustituye `android/app/google-services.json` por el que dio el humano, y
**comprueba que es el correcto**:

```bash
grep -o '"project_id": *"[^"]*"' android/app/google-services.json
grep -o '"package_name": *"[^"]*"' android/app/google-services.json
```

Esperado: `secretgift-app` y `app.secretgift`. **Si el `package_name` no
coincide exactamente con el `applicationId` del paso siguiente, la
compilación falla** con un error del plugin de Google Services que no dice
cuál de los dos está mal.

- [ ] **Paso 3: Cambia el paquete en Gradle**

En `android/app/build.gradle.kts`, líneas 9 y 23:

```kotlin
    namespace = "app.secretgift"
```

```kotlin
        applicationId = "app.secretgift"
```

- [ ] **Paso 4: Mueve `MainActivity.kt` y cámbiale el paquete**

```bash
mkdir -p android/app/src/main/kotlin/app/secretgift
git mv android/app/src/main/kotlin/com/example/santa_secreto/MainActivity.kt \
       android/app/src/main/kotlin/app/secretgift/MainActivity.kt
rm -rf android/app/src/main/kotlin/com
```

Y dentro del fichero, la primera línea:

```kotlin
package app.secretgift
```

**La ruta de carpetas tiene que reflejar el paquete.** Kotlin no obliga a
ello como Java, pero Gradle sí lo espera y el fallo que da si no coinciden
no menciona la ruta.

- [ ] **Paso 5: Declara el permiso de notificaciones**

En `android/app/src/main/AndroidManifest.xml`, dentro de `<manifest>` y
**fuera** de `<application>`, junto a los otros `uses-permission` si los
hay:

```xml
    <!-- Android 13 (API 33) y superiores exigen pedir este permiso en
         tiempo de ejecución. Sin declararlo aquí, `requestPermission()`
         devuelve "denegado" sin llegar a enseñar el diálogo — y no da
         ningún aviso de que falta. -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

- [ ] **Paso 6: Limpia antes de compilar**

```bash
flutter clean && flutter pub get
```

**No te saltes el `clean`.** Este proyecto ya perdió una tarde con
artefactos rancios tras cambiar de plugins: `pub get` a secas no regenera
todo lo que un cambio de paquete invalida.

- [ ] **Paso 7: Compila el APK**

```bash
flutter build apk --debug
```

Esperado: compila. Si falla con algo del plugin `com.google.gms.google-services`,
casi siempre es que el `package_name` del JSON y el `applicationId` no
coinciden — vuelve al Paso 2.

- [ ] **Paso 8: Comprueba que web no se ha roto**

```bash
flutter analyze && flutter test && flutter build web --release
```

Esperado: `No issues found!`, todo verde, y la web compila. El cambio es de
Android, pero `flutter clean` toca a todos y conviene saberlo ahora y no
tres tareas después.

- [ ] **Paso 9: Commit**

```bash
git add android/
git commit -m "Android apunta al proyecto nuevo y deja el paquete de ejemplo"
```

### Tarea 2: El helper de envío y la limpieza de tokens muertos

**Ficheros:**
- Crear: `functions/push.js`
- Crear: `functions/push.test.js`

**Interfaces:**
- Consume: nada de tareas anteriores.
- Produce:
  - `tokensMuertos(respuesta, tokens) -> string[]` — función pura.
  - `avisar(uid, {titulo, cuerpo, datos}) -> Promise<void>` — nunca lanza.
  - `avisarAVarios(uids, {titulo, cuerpo, datos}) -> Promise<void>` — nunca
    lanza.

**Contexto que necesitas:** un token de FCM identifica **una instalación**,
no una persona. La misma cuenta en el móvil y en el portátil son dos
tokens, así que `usuarios/{uid}.tokensPush` es un **mapa** de
`token → timestamp`. Es un mapa y no un array por lo mismo que `grupos`
dejó de ser array: `arrayUnion` compara por igualdad y eso ya falló una vez
en este proyecto; con el mapa el duplicado no se puede ni escribir.

- [ ] **Paso 1: Escribe el test que falla**

Crea `functions/push.test.js`:

```js
const test = require("node:test");
const assert = require("node:assert");
const {tokensMuertos} = require("./push");

test("devuelve solo los tokens que FCM dice que ya no existen", () => {
  const tokens = ["vivo", "muerto", "otro-vivo"];
  const respuesta = {
    responses: [
      {success: true},
      {success: false, error: {code: "messaging/registration-token-not-registered"}},
      {success: true},
    ],
  };
  assert.deepStrictEqual(tokensMuertos(respuesta, tokens), ["muerto"]);
});

test("un fallo pasajero NO borra el token", () => {
  // Si se borrara, un corte de red de FCM desengancharía dispositivos
  // sanos y esa persona dejaría de recibir avisos para siempre sin
  // enterarse. Solo se borra ante la respuesta que dice que el token ya
  // no existe.
  const tokens = ["vivo"];
  const respuesta = {
    responses: [{success: false, error: {code: "messaging/server-unavailable"}}],
  };
  assert.deepStrictEqual(tokensMuertos(respuesta, tokens), []);
});

test("también borra el token con formato inválido", () => {
  const tokens = ["basura"];
  const respuesta = {
    responses: [{success: false, error: {code: "messaging/invalid-registration-token"}}],
  };
  assert.deepStrictEqual(tokensMuertos(respuesta, tokens), ["basura"]);
});

test("sin respuestas no borra nada y no revienta", () => {
  assert.deepStrictEqual(tokensMuertos({responses: []}, []), []);
  assert.deepStrictEqual(tokensMuertos({}, []), []);
});
```

- [ ] **Paso 2: Corre el test y comprueba que falla**

```bash
cd functions && node --test
```

Esperado: FALLA con `Cannot find module './push'`.

- [ ] **Paso 3: Escribe `functions/push.js`**

```js
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

/**
 * De una respuesta de `sendEachForMulticast`, qué tokens hay que borrar.
 *
 * Se separa en una función pura porque es la única parte de todo esto con
 * lógica de verdad, y porque probarla contra FCM de verdad exigiría un
 * dispositivo que se desregistra a voluntad.
 *
 * SOLO borra ante los dos códigos que significan "este token ya no
 * existe". Un fallo pasajero de FCM —servidor caído, cuota— NO borra
 * nada: si lo hiciera, un mal minuto de FCM desengancharía dispositivos
 * sanos y esa gente dejaría de recibir avisos para siempre sin enterarse.
 */
function tokensMuertos(respuesta, tokens) {
  const respuestas = respuesta?.responses || [];
  const muertos = [];
  respuestas.forEach((r, i) => {
    if (r.success) return;
    const codigo = r.error?.code;
    if (codigo === "messaging/registration-token-not-registered" ||
        codigo === "messaging/invalid-registration-token") {
      muertos.push(tokens[i]);
    }
  });
  return muertos;
}

/**
 * Manda un aviso a todos los dispositivos de una cuenta.
 *
 * NUNCA lanza. Quien la llama ya escribió en Firestore: un reemplazo que
 * funcionó no puede deshacerse porque una notificación no saliera. Todos
 * los fallos se registran y se siguen.
 *
 * Los tokens muertos se limpian aquí mismo, con la respuesta del envío.
 * Así el mapa no crece para siempre y no hace falta ningún trabajo
 * programado.
 */
async function avisar(uid, {titulo, cuerpo, datos}) {
  if (!uid) return;
  try {
    const db = getFirestore();
    const ref = db.collection("usuarios").doc(uid);
    const snap = await ref.get();
    const tokens = Object.keys(snap.data()?.tokensPush || {});
    if (tokens.length === 0) return;

    const respuesta = await getMessaging().sendEachForMulticast({
      tokens,
      notification: {title: titulo, body: cuerpo},
      data: datos || {},
    });

    const muertos = tokensMuertos(respuesta, tokens);
    if (muertos.length > 0) {
      const borrado = {};
      for (const t of muertos) borrado[t] = FieldValue.delete();
      await ref.set({tokensPush: borrado}, {merge: true});
    }
  } catch (e) {
    // A propósito: registrar y seguir.
    console.error(`aviso fallido para ${uid}:`, e);
  }
}

/**
 * Lo mismo para varias cuentas a la vez.
 *
 * `Promise.all` y no un bucle con await: el sorteo de un grupo de veinte
 * personas haría veinte viajes en serie y la función se pasaría el rato
 * esperando. Como `avisar` nunca lanza, aquí no hace falta capturar nada.
 */
async function avisarAVarios(uids, aviso) {
  const unicos = [...new Set((uids || []).filter(Boolean))];
  await Promise.all(unicos.map((uid) => avisar(uid, aviso)));
}

module.exports = {tokensMuertos, avisar, avisarAVarios};
```

- [ ] **Paso 4: Corre el test y comprueba que pasa**

```bash
cd functions && node --test
```

Esperado: los cuatro casos en verde.

- [ ] **Paso 5: (no hay lint que pasar)**

`functions/` **no tiene ESLint ni ningún script de npm** — comprobado el
2026-08-12: `functions/package.json` no trae `scripts` ni
`devDependencies`. Una versión anterior de este plan mandaba correr
`npm run lint`, que no existe.

**No instales ESLint para cumplir este paso.** Montar el lint del backend
es una decisión propia, no un detalle de esta tarea, y nadie la ha tomado.
`node --test` es toda la comprobación automática que hay aquí.

- [ ] **Paso 6: Commit**

```bash
git add functions/push.js functions/push.test.js
git commit -m "El helper de avisos, con la limpieza de tokens muertos probada"
```

---

### Tarea 3: `guardarTokenPush`

**Ficheros:**
- Modificar: `functions/index.js` (cabecera de imports, y una función nueva)

**Interfaces:**
- Consume: nada de la Tarea 2 todavía.
- Produce: función desplegada `guardarTokenPush({token})` que devuelve
  `{ok: true}`. Claves de error nuevas: `token_invalido`.

**Contexto:** el cliente no puede escribir en `usuarios/{uid}` —las reglas
lo tienen cerrado— así que el token entra por una función. La llama cuando
FCM le da uno y cada vez que lo renueva.

- [ ] **Paso 1: Comprueba que las reglas siguen cerradas para el cliente**

```bash
grep -n "usuarios" firestore.rules
```

Esperado: que el cliente **no** pueda escribir `usuarios/{uid}`. Si
resultara que sí puede, **para y dilo** — sería un agujero anterior a esta
tarea y hay que tratarlo aparte, no de pasada.

- [ ] **Paso 2: Añade el import de la Tarea 2 en la cabecera**

En `functions/index.js`, junto a los otros `require` de la cabecera:

```js
const {avisar, avisarAVarios} = require("./push");
```

- [ ] **Paso 3: Escribe la función**

Ponla junto a las otras funciones de cuenta (cerca de `cambiarPin`, sobre
la línea 255). Fíjate en que usa `uidDe(request)` a secas: es una función
de cuenta, no de grupo, así que **no** pasa por `autorizar`.

```js
/**
 * Guarda un token de FCM de esta instalación.
 *
 * Es un MAPA `token -> fecha`, no un array. Un array con `arrayUnion`
 * compara por igualdad, y esa comparación ya falló una vez en este
 * proyecto; con el mapa, guardar dos veces el mismo token no puede crear
 * un duplicado ni queriendo.
 *
 * La fecha sirve para limpiar más adelante: un token que lleva meses sin
 * renovarse es de un dispositivo que ya no existe. Hoy no hay nada que la
 * lea, y se guarda igual porque el dato no se puede reconstruir después.
 */
exports.guardarTokenPush = onCall(async (request) => {
  const uid = uidDe(request);
  const token = (request.data?.token || "").trim();

  // Un token de FCM ronda los 150-200 caracteres. El tope alto es para no
  // dejar que nadie llene el documento con basura: la clave de un mapa de
  // Firestore no puede pasar de 1500 bytes, y llegar a ese límite haría
  // fallar la escritura entera de esa persona.
  if (!token || token.length > 500) {
    throw new HttpsError("invalid-argument", "Token de avisos inválido.", {clave: "token_invalido"});
  }

  await usuarioRef(uid).set({
    tokensPush: {[token]: Date.now()},
  }, {merge: true});

  return {ok: true};
});
```

- [ ] **Paso 4: Comprueba que el módulo carga y la función existe**

```bash
cd functions && node -e "const f=require('./index.js'); console.log(typeof f.guardarTokenPush)"
```

Esperado: `function`. Comprobado el 2026-08-12 contra las funciones que
ya existen (`cambiarPin`, `guardarPerfil`, `misGrupos`): todas dan
`function`. Una versión anterior de este plan decía `object`, escrito de
memoria y sin comprobarlo.

Este paso no es ceremonia: durante la migración a `firebase-admin` v13 el
módulo entero dejó de cargar por un import mal puesto, y ninguna otra
comprobación lo detectó.

- [ ] **Paso 5: Lint y test de funciones**

```bash
cd functions && node --test
```

Esperado: ambos limpios.

- [ ] **Paso 6: Commit**

```bash
git add functions/index.js
git commit -m "Una función para guardar el token de avisos de cada instalación"
```

---

### Tarea 4: Los tres avisos, enganchados

**Ficheros:**
- Modificar: `functions/index.js` — `canjearReemplazo` (~línea 732),
  `ejecutarSorteo` (~1014), `enviarMensaje` (~1126)

**Interfaces:**
- Consume: `avisar` y `avisarAVarios` de la Tarea 2, ya importados en la 2.
- Produce: los tres avisos con `datos.codigo` puesto, que la Tarea 8 usa
  para abrir el grupo al tocar la notificación.

**Contexto crítico:** los tres avisos van **después** de que la escritura
esté confirmada. Antes sería avisar de algo que quizá no ocurrió.

- [ ] **Paso 1: El aviso del reemplazo**

En `canjearReemplazo`, **después** de `await batch.commit();`. La variable
`quienRegala` ya existe unas líneas antes y es el **id de la plaza** que
regala, **no un uid** — el uid está en el privado de esa plaza, en el campo
`cuenta`:

```js
  // El aviso va DESPUÉS del commit: antes sería avisar de un cambio que
  // todavía puede no llegar a escribirse.
  //
  // `quienRegala` es un id de PLAZA, no un uid. El uid está en el privado
  // de esa plaza, en `cuenta`. La guarda del `if` no sobra: una plaza de
  // un grupo viejo puede no tener cuenta, y `avisar(undefined)` sería un
  // viaje a Firestore para nada.
  if (quienRegala) {
    const privRegala = await participantePrivadoRef(codigo, quienRegala).get();
    const uidRegala = privRegala.data()?.cuenta;
    if (uidRegala) {
      await avisar(uidRegala, {
        titulo: "Tu amigo secreto cambió",
        cuerpo: `En «${nombreGrupo}». Ábrelo para ver quién es ahora.`,
        datos: {codigo},
      });
    }
  }
```

**Antes de escribirlo**, mira si en esa función ya hay a mano el nombre del
grupo. Si no lo hay, léelo del documento del grupo —`grupoRef(codigo).get()`,
campo `nombre`— y si viniera vacío usa el `codigo` como respaldo: un aviso
que dice «En «»» es peor que uno que dice el código.

- [ ] **Paso 2: El aviso del sorteo**

En `ejecutarSorteo`, después de `await batch.commit();` y antes del
`return`. Los uids salen de los privados que **esa función ya leyó** en
`privSnaps` — no vuelvas a leerlos:

```js
  // Los uids salen de `privSnaps`, que esta función ya leyó para sortear.
  // Volver a leer los privados aquí serían N lecturas de más por sorteo.
  await avisarAVarios(
      privSnaps.map((p) => p.data()?.cuenta),
      {
        titulo: "¡Ya hay amigo secreto!",
        cuerpo: `En «${nombreGrupo}». Entra a ver a quién te toca.`,
        datos: {codigo},
      });
```

Comprueba que `privSnaps` está en el alcance en ese punto y que el nombre
del grupo está disponible; si no, aplica lo mismo que en el Paso 1.

- [ ] **Paso 3: El aviso del chat**

En `enviarMensaje`, al final, después de las dos escrituras y antes del
`return`:

```js
  // A todo el grupo MENOS a quien acaba de escribir. Avisarle de su propio
  // mensaje sería absurdo, y en un grupo de veinte serían veinte avisos
  // por mensaje en vez de diecinueve.
  //
  // Que no se avise a quien está MIRANDO este chat no se decide aquí: eso
  // lo resuelve el cliente en primer plano (ver lib/push.dart). El
  // servidor no sabe ni tiene por qué saber quién está mirando qué, y
  // guardar presencia sería una escritura por persona y por segundo.
  const participantes = await grupoRef(codigo).collection("participantes").get();
  const privados = await Promise.all(
      participantes.docs.map((d) => participantePrivadoRef(codigo, d.id).get()));
  const otros = privados
      .filter((p) => p.id !== participanteId)
      .map((p) => p.data()?.cuenta);
  await avisarAVarios(otros, {
    // Ni quién escribió ni qué dice: esto se lee desde la pantalla de
    // bloqueo, con el teléfono en la mano de cualquiera. Decir el texto
    // filtraría la conversación del grupo, y decir la máscara ayudaría a
    // deducir quién es.
    titulo: "Nuevo mensaje",
    cuerpo: `En «${nombreGrupo}».`,
    datos: {codigo},
  });
```

Comprueba que el id que trae `privados[i]` es el del participante (los
privados cuelgan del mismo id); si no lo fuera, filtra por el índice
correspondiente de `participantes.docs` en vez de por `p.id`.

- [ ] **Paso 4: Comprueba que el módulo sigue cargando**

```bash
cd functions && node -e "require('./index.js'); console.log('carga bien')" && node --test
```

Esperado: los tres limpios.

- [ ] **Paso 5: Commit**

```bash
git add functions/index.js
git commit -m "Avisa del reemplazo, del sorteo y de los mensajes nuevos"
```

---

### Tarea 5: Los textos, en los dos idiomas

**Ficheros:**
- Modificar: `lib/l10n/app_en.arb` (plantilla), `lib/l10n/app_es.arb`
- Modificar: `lib/funciones.dart` (un `case` nuevo en el `switch`)
- Modificar (generados): `lib/l10n/app_localizations*.dart`

**Interfaces:**
- Produce: `t.avisosTitulo`, `t.avisosTexto`, `t.avisosSi`, `t.avisosAhoraNo`,
  `t.errorTokenInvalido`. La Tarea 6 los usa.

**Contexto:** `app_en.arb` es la plantilla y necesita, por cada clave, su
`@clave` con `description`. Los generados **están commiteados** y
`flutter test` **no** los regenera.

- [ ] **Paso 1: Añade las claves a `lib/l10n/app_en.arb`**

```json
  "avisosTitulo": "Shall we let you know?",
  "@avisosTitulo": {
    "description": "Title of the screen that asks, in our own words, whether the person wants notifications. Shown before the browser's own permission prompt."
  },
  "avisosTexto": "We'll tell you when your group draws names, when someone writes in the chat, and if your secret friend changes.",
  "@avisosTexto": {
    "description": "Explains what the notifications are for, so the decision is informed."
  },
  "avisosSi": "Yes, let me know",
  "@avisosSi": {
    "description": "Button that accepts. Only this one triggers the browser permission prompt."
  },
  "avisosAhoraNo": "Not now",
  "@avisosAhoraNo": {
    "description": "Button that declines for the moment. Deliberately not a permanent no: it must not touch the browser permission."
  },
  "errorTokenInvalido": "We couldn't set up notifications. Nothing else is affected.",
  "@errorTokenInvalido": {
    "description": "Shown if the server rejects the push token. Reassures that the rest of the app is unaffected."
  },
```

- [ ] **Paso 2: Añade las mismas claves a `lib/l10n/app_es.arb`**

`app_es.arb` **no** lleva las entradas `@clave`:

```json
  "avisosTitulo": "¿Te avisamos?",
  "avisosTexto": "Te diremos cuando tu grupo sortee, cuando escriban en el chat y si tu amigo secreto cambia de persona.",
  "avisosSi": "Sí, avísame",
  "avisosAhoraNo": "Ahora no",
  "errorTokenInvalido": "No pudimos activar los avisos. Lo demás sigue funcionando.",
```

- [ ] **Paso 3: Engancha la clave de error nueva**

En el `switch` de `lib/funciones.dart`, junto a los otros:

```dart
        'token_invalido' => t.errorTokenInvalido,
```

- [ ] **Paso 4: Regenera y comprueba la paridad**

```bash
flutter gen-l10n
git diff --stat lib/l10n/
```

Esperado: los tres `app_localizations*.dart` cambiados. Si no cambian, la
generación no corrió y **el fallo no aparecerá hasta ejecutar la app**.

Comprueba además que los dos ARB tienen el mismo conjunto de claves:

```bash
node -e "const a=require('./lib/l10n/app_en.arb'),b=require('./lib/l10n/app_es.arb');const k=o=>Object.keys(o).filter(x=>!x.startsWith('@')).sort();const ka=k(a),kb=k(b);const f=ka.filter(x=>!kb.includes(x)),s=kb.filter(x=>!ka.includes(x));console.log('solo en en:',f,'\nsolo en es:',s)"
```

Esperado: las dos listas vacías.

- [ ] **Paso 5: Analyze y tests**

```bash
flutter analyze && flutter test
```

Esperado: `No issues found!` y todo en verde.

- [ ] **Paso 6: Commit**

```bash
git add lib/l10n/ lib/funciones.dart
git commit -m "Los textos de los avisos, en los dos idiomas"
```

---

### Tarea 6: La pantalla que pregunta antes que el navegador

**Ficheros:**
- Crear: `lib/pantalla_permiso_avisos.dart`
- Modificar: `lib/almacen_local.dart`

**Interfaces:**
- Consume: los textos de la Tarea 5.
- Produce:
  - `PantallaPermisoAvisos({required Future<void> Function() alAceptar, required VoidCallback alSaltar})`
  - `Future<bool> yaSePreguntoPorAvisos()` y `Future<void> marcarPreguntadoPorAvisos()`
    en `almacen_local.dart`.

**Contexto — esto es lo más importante del diseño entero:** al navegador
solo se le puede preguntar **una vez en la práctica**. Si lo deniegan, queda
denegado para siempre y las llamadas siguientes no muestran nada. Por eso
esta pantalla existe: **«Ahora no» no debe llamar al navegador**. Si lo
llamara, la pantalla no serviría absolutamente para nada.

En esta tarea la pantalla **todavía no habla con FCM**: recibe por
constructor qué hacer al aceptar. Así se puede escribir y probar sin la
clave VAPID.

- [ ] **Paso 1: Escribe el test que falla**

Crea `test/pantalla_permiso_avisos_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santa_secreto/l10n/app_localizations.dart';
import 'package:santa_secreto/pantalla_permiso_avisos.dart';

Widget _envuelta(Widget hijo) => MaterialApp(
      localizationsDelegates: Textos.localizationsDelegates,
      supportedLocales: Textos.supportedLocales,
      home: hijo,
    );

void main() {
  testWidgets('ofrece las dos salidas', (tester) async {
    await tester.pumpWidget(_envuelta(PantallaPermisoAvisos(
      alAceptar: () async {},
      alSaltar: () {},
    )));
    await tester.pumpAndSettle();
    expect(find.text('Yes, let me know'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
  });

  testWidgets('«Ahora no» NO dispara el permiso', (tester) async {
    // Es LA prueba de esta pantalla. Si «Ahora no» acabara llamando al
    // navegador, el permiso quedaría quemado para siempre y la pantalla
    // no serviría para nada.
    var pidioPermiso = false;
    var salto = false;
    await tester.pumpWidget(_envuelta(PantallaPermisoAvisos(
      alAceptar: () async => pidioPermiso = true,
      alSaltar: () => salto = true,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(pidioPermiso, isFalse);
    expect(salto, isTrue);
  });

  testWidgets('«Sí, avísame» sí lo dispara', (tester) async {
    var pidioPermiso = false;
    await tester.pumpWidget(_envuelta(PantallaPermisoAvisos(
      alAceptar: () async => pidioPermiso = true,
      alSaltar: () {},
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, let me know'));
    await tester.pumpAndSettle();
    expect(pidioPermiso, isTrue);
  });
}
```

Si el nombre del paquete no fuera `santa_secreto`, míralo en `pubspec.yaml`
y ajusta los imports; mira también otro test de pantalla del proyecto para
copiar exactamente cómo envuelven el widget.

- [ ] **Paso 2: Corre el test y comprueba que falla**

```bash
flutter test test/pantalla_permiso_avisos_test.dart
```

Esperado: FALLA, no existe `pantalla_permiso_avisos.dart`.

- [ ] **Paso 3: Escribe la pantalla**

Crea `lib/pantalla_permiso_avisos.dart`. **Mira antes otra pantalla del
proyecto** (por ejemplo `lib/pantalla_verificar_correo.dart`) y copia su
estructura: `Scaffold` + `SafeArea` + `Center` + `SingleChildScrollView`.

```dart
import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';

/// Pregunta por los avisos ANTES que el navegador.
///
/// Existe por una sola razón: al navegador solo se le puede preguntar una
/// vez en la práctica. Si lo deniegan, queda denegado para siempre y las
/// llamadas siguientes no muestran nada — ni siquiera aparece el cuadro.
///
/// Y este momento —recién creada la cuenta— es el de más probabilidad de
/// un «no» por costumbre: la persona todavía no ha visto la app ni está en
/// ningún grupo. Preguntando nosotros primero, un «Ahora no» no gasta
/// nada y se le puede volver a ofrecer más adelante.
///
/// POR ESO `alSaltar` NO DEBE PEDIR EL PERMISO. Si algún día alguien lo
/// engancha ahí, esta pantalla deja de servir para nada.
class PantallaPermisoAvisos extends StatefulWidget {
  /// Qué hacer al aceptar. Es lo único que puede llamar al navegador.
  final Future<void> Function() alAceptar;

  /// Qué hacer al posponerlo. No toca el permiso.
  final VoidCallback alSaltar;

  const PantallaPermisoAvisos({
    super.key,
    required this.alAceptar,
    required this.alSaltar,
  });

  @override
  State<PantallaPermisoAvisos> createState() => _PantallaPermisoAvisosState();
}

class _PantallaPermisoAvisosState extends State<PantallaPermisoAvisos> {
  bool _pidiendo = false;

  Future<void> _aceptar() async {
    setState(() => _pidiendo = true);
    try {
      await widget.alAceptar();
    } finally {
      if (mounted) setState(() => _pidiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.notifications_active_outlined, size: 64),
                const SizedBox(height: 16),
                Text(t.avisosTitulo,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(t.avisosTexto, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _pidiendo ? null : _aceptar,
                  child: Text(t.avisosSi),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _pidiendo ? null : widget.alSaltar,
                  child: Text(t.avisosAhoraNo),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Paso 4: Corre el test y comprueba que pasa**

```bash
flutter test test/pantalla_permiso_avisos_test.dart
```

Esperado: los tres casos en verde.

- [ ] **Paso 5: Recuerda que ya se preguntó**

En `lib/almacen_local.dart`, siguiendo el estilo que ya tenga ese fichero
para leer y escribir preferencias:

```dart
const _clavePreguntadoAvisos = 'preguntado_avisos';

/// Si ya se le ofrecieron los avisos a quien usa este dispositivo.
///
/// Se guarda AQUÍ y no en el servidor a propósito: el permiso es del
/// navegador, no de la cuenta. La misma persona en el móvil y en el
/// portátil tiene que poder decidir en cada sitio.
Future<bool> yaSePreguntoPorAvisos() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_clavePreguntadoAvisos) ?? false;
}

Future<void> marcarPreguntadoPorAvisos() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_clavePreguntadoAvisos, true);
}
```

- [ ] **Paso 6: Analyze y toda la batería**

```bash
flutter analyze && flutter test
```

Esperado: `No issues found!` y todo verde.

- [ ] **Paso 7: Commit**

```bash
git add lib/pantalla_permiso_avisos.dart lib/almacen_local.dart test/pantalla_permiso_avisos_test.dart
git commit -m "Preguntamos nosotros antes que el navegador, para no quemar el permiso"
```

---

### Tarea 7: FCM de verdad — paquete, *service worker* y token

> **ESTA TAREA NECESITA LA CLAVE VAPID.** Si no la tienes, para y pídela:
> consola de Firebase → Configuración del proyecto → Cloud Messaging →
> Web Push certificates. **No pongas un valor de relleno.**

**Ficheros:**
- Modificar: `pubspec.yaml`
- Crear: `web/firebase-messaging-sw.js` (solo web)
- Crear: `lib/push.dart` (web **y** Android)

**Interfaces:**
- Consume: `guardarTokenPush` de la Tarea 3, y la app Android ya apuntando
  al proyecto nuevo (Tarea 1).
- Produce:
  - `Future<bool> pedirPermisoYRegistrar()` — true si quedó registrado.
  - `void mirandoGrupo(String? codigo)` — la Tarea 8 la usa.
  - `void alTocarAviso(void Function(String codigo) abrir)` — la Tarea 8.

**Contexto sobre los dos *service workers*:** la app **ya** registra el
suyo (Flutter web lo genera). El de FCM es un **segundo** *service worker*,
con su propio fichero y su propio ámbito, y **conviven sin tocarse**: el
navegador permite varios por origen mientras sean ficheros distintos.

Lo que sí hay que saber: `web/firebase-messaging-sw.js` **no pasa por el
compilador de Dart**. Es JavaScript suelto servido tal cual desde la raíz,
y por eso necesita **repetir** la configuración de Firebase que
`lib/main.dart` ya tiene dentro de su `if (kIsWeb)`. Es duplicación real y
molesta, y no hay forma de evitarla.

**Y un aviso que este proyecto ya pagó caro:** un *service worker* rancio
sirvió una versión vieja de la app durante horas esta semana. Cuando
pruebes, usa una ventana de incógnito o borra los *service workers* a mano
desde las herramientas del navegador. Una recarga forzada **no basta**.

- [ ] **Paso 1: Añade el paquete**

En `pubspec.yaml`, junto a las otras dependencias de Firebase:

```yaml
  firebase_messaging: ^16.0.0
```

Luego:

```bash
flutter pub get
```

Si la resolución falla por incompatibilidad con `firebase_core: ^4.3.0`,
**no fuerces la versión**: mira qué rango pide `pub` y usa el compatible.

- [ ] **Paso 2: Crea el *service worker***

Crea `web/firebase-messaging-sw.js`. **Los valores tienen que ser los de
`secretgift-app`**, los mismos que están en `lib/main.dart`:

```js
// Service worker de FCM. Es lo que recibe los avisos con la app cerrada:
// sin este fichero no hay push en web, y su ausencia no da ningún error
// visible — simplemente no llega nada.
//
// Es JavaScript suelto: NO pasa por el compilador de Dart, así que la
// configuración de Firebase hay que repetirla aquí. Está duplicada de
// lib/main.dart a la fuerza. SI CAMBIA ALLÍ, CÁMBIALA AQUÍ.
//
// Convive con el service worker propio de Flutter web sin tocarlo: son
// ficheros distintos y el navegador admite varios por origen.
importScripts("https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyD9F2V6ByG7p9yMoDOpa_p-v97_Ik5jZcI",
  authDomain: "secretgift-app.firebaseapp.com",
  projectId: "secretgift-app",
  storageBucket: "secretgift-app.firebasestorage.app",
  messagingSenderId: "997384680563",
  appId: "1:997384680563:web:de772ec4c11202e0f0a606",
});

firebase.messaging();
```

Comprueba que la versión del SDK que pones en los `importScripts` existe;
si `10.14.1` no estuviera disponible, usa la última estable de la rama 10 y
**anótalo en el commit**.

- [ ] **Paso 3: Escribe `lib/push.dart`**

**Un solo fichero para las dos plataformas.** No hace falta el patrón de
implementación condicional de `recarga_pagina.dart`: aquel existía porque
`sessionStorage` no existe fuera de web, mientras que `firebase_messaging`
soporta web y Android con la misma API. Lo único que se bifurca es la clave
VAPID, y para eso basta un `kIsWeb`.

```dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'funciones.dart';

/// Sacada de la consola: Configuración del proyecto → Cloud Messaging →
/// Web Push certificates. Es del proyecto `secretgift-app`; una del
/// proyecto viejo falla con un error genérico que no dice qué pasa.
///
/// SOLO sirve para web. En Android el dispositivo se identifica con
/// `google-services.json`, y pasarle una vapidKey a `getToken` allí no
/// hace nada.
const _vapid = 'PON_AQUI_LA_CLAVE_VAPID';

/// Qué grupo se está mirando ahora mismo, o null.
///
/// Lo escribe la pantalla de chat. Sirve para NO enseñar el aviso de un
/// mensaje a quien está leyendo ese mismo chat.
String? _grupoALaVista;

void mirandoGrupo(String? codigo) {
  _grupoALaVista = codigo;
}

/// Pide el permiso al navegador y registra el token.
///
/// SOLO debe llamarse desde el «Sí, avísame» de PantallaPermisoAvisos.
/// Llamarla en cualquier otro sitio gasta el permiso del navegador, que
/// solo se puede pedir una vez.
Future<bool> pedirPermisoYRegistrar() async {
  final messaging = FirebaseMessaging.instance;
  final ajustes = await messaging.requestPermission();
  if (ajustes.authorizationStatus != AuthorizationStatus.authorized &&
      ajustes.authorizationStatus != AuthorizationStatus.provisional) {
    return false;
  }

  // La vapidKey SOLO en web. En Android el dispositivo ya está
  // identificado por google-services.json.
  final token = await messaging.getToken(vapidKey: kIsWeb ? _vapid : null);
  if (token == null) return false;
  await llamarFuncion('guardarTokenPush', {'token': token});

  // El token puede cambiar sin que nadie haga nada (el navegador lo
  // renueva). Si no se vuelve a guardar, los avisos dejan de llegar sin
  // que nadie se entere.
  messaging.onTokenRefresh.listen((nuevo) {
    llamarFuncion('guardarTokenPush', {'token': nuevo}).catchError((_) {
      // Renovar en segundo plano no puede molestar a nadie con un error.
      return <String, dynamic>{};
    });
  });

  return true;
}

/// Qué hacer cuando alguien toca un aviso, y qué hacer con los que llegan
/// con la app abierta.
void alTocarAviso(void Function(String codigo) abrir) {
  // Con la app EN PRIMER PLANO, FCM no enseña nada por su cuenta —ni en
  // web ni en Android—: salta esto y decidimos nosotros. Por eso no hace
  // falta que el servidor sepa quién está mirando qué, que sería una
  // escritura de presencia por persona y por segundo.
  //
  // Y no enseñamos nada: si estás dentro de la app, ya ves el cambio.
  // Avisar a quien está leyendo el chat de que hay un mensaje en ese
  // mismo chat es la forma rápida de que apague los avisos para siempre.
  FirebaseMessaging.onMessage.listen((mensaje) {
    final codigo = mensaje.data['codigo'];
    if (codigo != null && codigo == _grupoALaVista) return;
    // El resto tampoco se enseña por ahora: la app está abierta y sus
    // pantallas ya se actualizan solas.
  });

  // Tocar el aviso con la app en segundo plano.
  FirebaseMessaging.onMessageOpenedApp.listen((mensaje) {
    final codigo = mensaje.data['codigo'];
    if (codigo != null) abrir(codigo);
  });
}
```

- [ ] **Paso 4: Comprueba que compila para las dos plataformas**

```bash
flutter analyze
flutter build web --release
flutter build apk --debug
```

Esperado: `No issues found!` y las dos compilaciones correctas. Compilar
**las dos** aquí no es celo: `firebase_messaging` arrastra dependencias
nativas en Android que no se manifiestan al compilar solo la web, y
descubrirlo en la Tarea 10 sería descubrirlo tarde.

- [ ] **Paso 5: Sobre el canal de notificación de Android**

En Android 8 y superiores, toda notificación pertenece a un **canal**. Si
no se declara ninguno, FCM crea uno por defecto y los avisos llegan — con
un nombre genérico en los ajustes del sistema («Miscellaneous») y con la
importancia por defecto.

**Se acepta así a propósito en esta primera versión.** Declarar un canal
propio obliga a añadir `flutter_local_notifications` y código nativo, y no
cambia si el aviso llega o no: solo cómo se ve su nombre en los ajustes de
Android. Es mejora, no requisito.

**Anótalo en tu informe** para que quede como pendiente conocido, y no lo
implementes aquí.

- [ ] **Paso 6: Commit**

```bash
git add pubspec.yaml pubspec.lock web/firebase-messaging-sw.js lib/push.dart android/
git commit -m "FCM en web y Android: paquete, service worker y registro del token"
```

---

### Tarea 8: Engancharlo todo en el arranque

**Ficheros:**
- Modificar: `lib/pantalla_raiz.dart`, `lib/pantalla_crear_cuenta.dart`,
  `lib/pantalla_iniciar_sesion.dart`
- Modificar: `lib/pantalla_chat.dart`

**Interfaces:**
- Consume: `PantallaPermisoAvisos` (Tarea 6), `yaSePreguntoPorAvisos` /
  `marcarPreguntadoPorAvisos` (Tarea 6), `pedirPermisoYRegistrar`,
  `mirandoGrupo`, `alTocarAviso` (Tarea 7).

**Contexto sobre CUÁNDO se pregunta:** el spec dice «al crear la cuenta».
En la práctica eso es **justo después de verificar el correo**, en el
primer momento en que la persona entra de verdad: antes de verificar no
puede hacer nada, y preguntarle mientras espera el correo sería pedirle
algo en mitad de otra cosa. Los tres sitios que hoy llaman a `_trasVerificar`
son el punto exacto.

- [ ] **Paso 1: Enseña la pantalla tras verificar**

En los tres ficheros, dentro de `_trasVerificar` y **antes** de seguir al
destino normal:

```dart
    // El permiso de avisos se ofrece aquí, en el primer momento en que
    // esta persona entra de verdad. Antes de verificar el correo no puede
    // hacer nada, y preguntárselo mientras espera sería interrumpirla en
    // mitad de otra cosa.
    //
    // `yaSePreguntoPorAvisos` es por DISPOSITIVO, no por cuenta: el
    // permiso es del navegador, así que la misma persona tiene que poder
    // decidirlo en el móvil y en el portátil por separado.
    if (!await yaSePreguntoPorAvisos()) {
      await marcarPreguntadoPorAvisos();
      if (!context.mounted) return;
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => PantallaPermisoAvisos(
          alAceptar: () async {
            await pedirPermisoYRegistrar();
            if (context.mounted) Navigator.pop(context);
          },
          alSaltar: () => Navigator.pop(context),
        ),
      ));
    }
```

Fíjate en que se marca **antes** de enseñarla: si se marcara después y la
persona cerrara la pestaña en mitad, se le volvería a preguntar en cada
arranque.

- [ ] **Paso 2: Engancha el toque de la notificación**

En `lib/pantalla_raiz.dart`, donde se inicializa el estado de la pantalla:

```dart
    // Tocar un aviso abre su grupo. Sin esto, el aviso lleva a la pantalla
    // de inicio y la persona tiene que buscar el grupo a mano — que es
    // justo la fricción que el aviso venía a quitar.
    alTocarAviso((codigo) {
      if (!mounted) return;
      // Reutiliza el mismo camino que ya usa la app para abrir un grupo
      // por su código; NO escribas una navegación nueva aquí.
    });
```

**Busca cómo abre la app un grupo a partir de su código** (mira
`lib/destino_inicial.dart` y `lib/invitacion_pendiente.dart`, que ya
resuelven entrar directo a un grupo desde una URL) y usa ese mismo camino.
Escribir una navegación paralela dejaría dos formas distintas de entrar a
un grupo, que se desincronizarían.

- [ ] **Paso 3: Declara qué chat se está mirando**

En `lib/pantalla_chat.dart`:

```dart
  @override
  void initState() {
    super.initState();
    // Mientras esta pantalla esté a la vista no se enseñan avisos de
    // mensajes de ESTE grupo: ya los estás leyendo.
    mirandoGrupo(widget.codigo);
  }

  @override
  void dispose() {
    mirandoGrupo(null);
    super.dispose();
  }
```

Ajusta `widget.codigo` al nombre real que tenga ahí el código del grupo. Si
la pantalla ya tiene `initState` o `dispose`, **añade la línea a los que
haya**, no crees otros.

- [ ] **Paso 4: Analyze y toda la batería**

```bash
flutter analyze && flutter test
```

Esperado: `No issues found!` y todo verde.

- [ ] **Paso 5: Commit**

```bash
git add lib/
git commit -m "Ofrece los avisos al entrar por primera vez y abre el grupo al tocarlos"
```

---

### Tarea 9: La batería de integración

**Ficheros:**
- Modificar: `scripts/probar.mjs`

**Interfaces:**
- Consume: `guardarTokenPush` desplegada (Tarea 3).

**Contexto:** `scripts/probar.mjs` tiene hoy 57 casos y corre contra el
proyecto de verdad. **Mira cómo está escrito antes de añadir nada** y copia
su estilo exacto: cómo entra con una cuenta, cómo llama a una función y
cómo afirma.

- [ ] **Paso 1: Añade los casos**

```js
// --- Avisos push -----------------------------------------------------
// Lo que se prueba aquí es el MAPA, que es donde estaba el riesgo: si
// `tokensPush` fuera un array, guardar dos veces el mismo token dejaría
// dos entradas. Con el mapa no puede pasar ni queriendo, y esta prueba es
// lo que impide que alguien lo convierta en array más adelante.
await paso('guardarTokenPush guarda el token', async () => {
  const r = await llamar(sesionA, 'guardarTokenPush', {token: 'token-de-prueba-A'});
  afirmar(r.ok === true, 'devuelve ok');
});

await paso('guardarlo dos veces deja UNA sola entrada', async () => {
  await llamar(sesionA, 'guardarTokenPush', {token: 'token-de-prueba-A'});
  const doc = await leerUsuario(sesionA.uid);
  const tokens = Object.keys(doc.tokensPush || {});
  afirmar(
      tokens.filter((t) => t === 'token-de-prueba-A').length === 1,
      `esperaba una sola entrada, hay ${tokens.length}`);
});

await paso('dos dispositivos distintos dejan dos entradas', async () => {
  await llamar(sesionA, 'guardarTokenPush', {token: 'token-de-prueba-B'});
  const doc = await leerUsuario(sesionA.uid);
  const tokens = Object.keys(doc.tokensPush || {});
  afirmar(tokens.includes('token-de-prueba-A') && tokens.includes('token-de-prueba-B'),
      'los dos tokens tienen que convivir: son dos dispositivos de la misma persona');
});

await paso('un token vacío se rechaza', async () => {
  await esperarError(
      () => llamar(sesionA, 'guardarTokenPush', {token: '   '}),
      'token_invalido');
});
```

Los nombres `paso`, `llamar`, `afirmar`, `esperarError`, `leerUsuario` y
`sesionA` son los que **suponemos** que usa el fichero: **ábrelo y usa los
que tenga de verdad**. Si no existe una forma de leer el documento de
usuario, mira cómo comprueban otros casos el estado en Firestore y sigue
ese camino.

- [ ] **Paso 2: Despliega las funciones y corre la batería**

```bash
firebase deploy --only functions
node scripts/probar.mjs
```

Esperado: **61/61** en verde (57 de antes más los 4 nuevos).

- [ ] **Paso 3: Commit**

```bash
git add scripts/probar.mjs
git commit -m "La batería comprueba que el mapa de tokens no admite duplicados"
```

---

### Tarea 10: Despliegue y comprobación en dispositivo

**Ficheros:** ninguno. Esta tarea es comprobar.

**Contexto:** todo lo anterior puede estar en verde y **el push no salir**.
Es el único subsistema del proyecto donde los tests automáticos no
demuestran nada de lo que importa.

- [ ] **Paso 1: Despliega todo**

```bash
flutter build web --release
firebase deploy --only hosting,functions
```

- [ ] **Paso 2: La prueba que sostiene el diseño entero**

Cuenta nueva. Al llegar a la pantalla de avisos, pulsa **«Ahora no»**.

Después, comprueba en el navegador que **el permiso sigue en «preguntar»**,
no en «denegado» (candado de la barra de direcciones → Notificaciones).

**Si sale «denegado», el diseño entero se cae** y hay que arreglarlo antes
de seguir: significaría que «Ahora no» está llamando al navegador.

- [ ] **Paso 3: Los tres avisos, con la app cerrada**

Dos cuentas, dos navegadores, un grupo sorteado. **Cierra la pestaña** de
quien recibe antes de cada prueba.

1. **Sorteo:** sortea el grupo → a todos les llega «¡Ya hay amigo secreto!»
2. **Chat:** escribe un mensaje → al resto le llega «Nuevo mensaje»
3. **Reemplazo:** reemplaza una plaza → a quien le regalaba le llega
   «Tu amigo secreto cambió»

- [ ] **Paso 4: La supresión del chat**

Con el chat de un grupo **abierto y a la vista**, que otra persona escriba.
**No debe aparecer ningún aviso.** Sal de ese chat, que escriba otra vez:
ahora tampoco debería salir, porque la app sigue en primer plano — lo que
importa es que **no molesta**.

- [ ] **Paso 5: Denegar el permiso no rompe nada**

Con una cuenta que haya **denegado** en el cuadro del navegador: comprueba
que sortear, escribir en el chat y reemplazar **siguen funcionando enteros
y sin errores visibles**. Es el caso más probable en la vida real.

- [ ] **Paso 6: Tocar el aviso abre el grupo**

Con la app en segundo plano, toca una notificación. Tiene que abrir **ese**
grupo, no la pantalla de inicio.

- [ ] **Paso 7: Lo mismo en Android, con el APK**

```bash
flutter build apk --release
```

Instálalo en un móvil y repite los Pasos 2 a 6. **No des por hecho que
funciona porque funcione en web**: son dos caminos distintos hasta FCM y
solo comparten el código Dart.

Dos cosas que en Android se comportan distinto y conviene mirar a
propósito:

1. **El diálogo de permiso es del sistema, no del navegador**, y solo sale
   en Android 13 o superior. En versiones anteriores el permiso se da por
   concedido al instalar, así que allí «Ahora no» no tiene nada que gastar
   — y la pantalla propia sigue estando bien, porque no da por supuesto en
   qué versión estás.
2. **Android sí da una segunda oportunidad** (dentro de un límite), al
   revés que el navegador. Aun así, la pantalla propia sigue mereciendo la
   pena: el mismo código sirve para las dos plataformas y no hay que
   razonar sobre cuál es cuál.

- [ ] **Paso 8: Comprueba que los tokens caen en el proyecto CORRECTO**

Tras registrar el token desde el APK, mira en la consola de Firebase de
**`secretgift-app`** que el documento `usuarios/{uid}` tiene su entrada en
`tokensPush`.

Este paso existe porque el fallo que se está evitando **es silencioso**: si
el `google-services.json` fuera el viejo, el token se guardaría en
`santa-secreto-860c3` sin dar ningún error, y todo parecería funcionar
hasta que a alguien no le llegara nada.

- [ ] **Paso 9: Actualiza la bitácora y cierra la rama**

Escribe `bitacora/2026-08-12-notificaciones-push.md` y usa
`superpowers:finishing-a-development-branch`.

---

## Notas de la auto-revisión

Repasado el spec contra el plan:

- **Tokens como mapa** → Tarea 3, y la Tarea 9 lo blinda con una prueba.
- **Limpieza de tokens muertos** → Tarea 2, con el test unitario que pedía
  el spec, más un caso que el spec no pedía: que un fallo pasajero **no**
  borre el token. Sin él, un mal minuto de FCM desengancharía dispositivos
  sanos.
- **`avisar` nunca falla** → Tarea 2, y se comprueba en la Tarea 10 Paso 5.
- **Permiso tras pantalla propia** → Tareas 6 y 8, y la prueba que lo
  sostiene es la Tarea 10 Paso 2.
- **Tres avisos** → Tarea 4, comprobados en la Tarea 10 Paso 3.
- **Sin nombres ni contenido** → escrito en los textos de la Tarea 4.
- **Supresión en el chat** → resuelta en el cliente (Tareas 7 y 8), no en
  el servidor. Es una desviación del spec **a favor de la simplicidad**: el
  spec no decía cómo hacerlo, y la alternativa —presencia en el servidor—
  costaría una escritura por persona y por segundo para el mismo
  resultado.
- **VAPID** → solo la Tarea 7; las cinco anteriores avanzan sin ella.

**Desviación del spec, decidida por el humano el 2026-08-12:** el spec
dejaba Android implícito y este plan lo pone **primero**, como Tarea 1. El
motivo no es de alcance sino de riesgo: mientras `google-services.json`
apunte al proyecto viejo, cualquier prueba en APK escribiría los tokens en
la base de datos equivocada **sin dar ningún error**, porque ese proyecto
sigue vivo. Hacerlo después habría significado depurar avisos que no
llegan sin ninguna pista de por qué.

**Tres huecos conocidos, abiertos a propósito:**

1. **Quien deniegue el permiso no recibirá nada, y ni esa persona ni el
   organizador lo sabrán.** Heredado del spec, que lo asume a sabiendas y
   deja el aviso dentro de la app fuera de alcance. Es la grieta conocida
   de todo el subsistema.
2. **El canal de notificación de Android es el que crea FCM por defecto**
   (Tarea 7, Paso 5). Los avisos llegan; solo se ve un nombre genérico en
   los ajustes del sistema. Declarar uno propio obliga a añadir
   `flutter_local_notifications` y código nativo.
3. **iOS sigue fuera**, como decía el spec. El push web en iOS exige tener
   la app instalada en la pantalla de inicio, y no se va a probar.
