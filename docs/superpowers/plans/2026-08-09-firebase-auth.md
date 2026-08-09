# Firebase Auth como identidad — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sustituir las cuentas caseras (`usuarios/{nicknameNormalizado}` + bcrypt + contraseña en `localStorage`) por Firebase Auth con correo y contraseña, verificación de correo obligatoria y recuperación.

**Architecture:** El servidor deja de recibir credenciales: las quince Cloud Functions leen `request.auth.uid`, que el protocolo *callable* rellena a partir de la cabecera `Authorization: Bearer <idToken>`. El helper `autorizar()` construido en P2 se conserva entero — solo cambia de dónde saca la clave de la cuenta. En el cliente, `lib/sesion.dart` desaparece y el SDK de Auth pasa a ser la única fuente de sesión.

**Tech Stack:** Flutter 3.38.10 / Dart 3.10.9, `firebase_auth`, Cloud Functions v2 (Node 20), Firestore, proyecto `santa-secreto-860c3`.

**Spec:** `docs/superpowers/specs/2026-08-09-firebase-auth-design.md`

**Rama:** una nueva a partir de `main`. **Los dos requisitos previos ya están cumplidos** (2026-08-09): la rama `cuenta-como-identidad` está fusionada en `main` (commit de fusión `19c23a2`) y los cuatro arreglos baratos de seguridad están hechos, desplegados y probados.

## Global Constraints

- **Dart 3.10.9 / Flutter 3.38.10.** Nada de sintaxis de Dart 3.12 (parámetros nombrados privados, constructores primarios): no compila.
- **`flutter analyze` sin advertencias al terminar CADA tarea.** No se cierra una tarea con el análisis roto.
- **Los ficheros generados de l10n están trackeados en git.** Al tocar `lib/l10n/app_*.arb` hay que ejecutar `flutter gen-l10n` y commitear también `lib/l10n/app_localizations.dart`, `app_localizations_en.dart` y `app_localizations_es.dart`. `flutter test` NO los regenera.
- **Los dos ARB con exactamente el mismo conjunto de claves.** `test/arb_paridad_test.dart` lo verifica.
- **`app_en.arb` es la plantilla**: toda clave nueva necesita su `@clave` con `description` ahí, y solo la traducción en `app_es.arb`.
- **El servidor no tiene tests unitarios.** Su verificación es `scripts/probar.mjs` contra las funciones desplegadas (Tarea 11) y el despliegue (Tarea 12). Las tareas 2, 3 y 4 se cierran con revisión de código, no con ejecución.
- **`lib/funciones.dart` NO usa el paquete `cloud_functions`** — llama por HTTP crudo por el bug dart2js [flutterfire#17924](https://github.com/firebase/flutterfire/issues/17924). Cualquier cambio de transporte se hace ahí.
- **Toda cadena visible pasa por `Textos.of(context)`.** Cero texto literal en la interfaz.
- **Mensajes de commit en español**, describiendo el porqué, no el qué.
- **No se despliega nada hasta la Tarea 12.**

## Estructura de ficheros

**Servidor**

| Fichero | Responsabilidad |
|---|---|
| `functions/index.js` | Las quince funciones. Pierde `registrarCuenta`, `iniciarSesionCuenta`, `verificarCuenta`, `normalizarNickname`, `validarPassword`, `REGEX_PASSWORD`. Gana `uidDe()`, `exigirReciente()`, `guardarPerfil`, `misGrupos`. |
| `firestore.rules` | `usuarios/{uid}` legible por su dueño. |

**Cliente**

| Fichero | Responsabilidad |
|---|---|
| `lib/auth.dart` | **Nuevo.** Envoltura fina sobre `FirebaseAuth`: entrar, registrarse, reautenticar, token, y traducción de `FirebaseAuthException.code` a nuestras claves de error. |
| `lib/acceso_cuenta.dart` | **Reescrito.** Orquesta registro/entrada/perfil sobre `auth.dart` + `funciones.dart`. |
| `lib/funciones.dart` | Gana la cabecera `Authorization: Bearer`. |
| `lib/sesion.dart` | **Se borra** (Tarea 9). |
| `lib/pantalla_crear_cuenta.dart` | Campos nuevos: correo, contraseña, nombre, apellido, PIN. |
| `lib/pantalla_iniciar_sesion.dart` | Correo en vez de apodo + enlace de recuperación. |
| `lib/pantalla_verificar_correo.dart` | **Nueva.** Pantalla de espera bloqueante. |
| `lib/pantalla_recuperar_password.dart` | **Nueva.** Pide el correo y manda el enlace. |
| `lib/pantalla_raiz.dart` | El portero pasa a leer el estado de Auth. |
| `lib/pantalla_completar_perfil.dart` | **Nueva.** Red de seguridad: cuenta de Auth sin documento de perfil. |
| `lib/hoja_configuracion.dart` | Cambiar el PIN pasa por reautenticación. |
| `lib/pantalla_{registro,chat,crear_grupo,editar_grupo,unirse_grupo,mis_grupos}.dart` | Dejan de mandar credenciales. |

**Pruebas**

| Fichero | Responsabilidad |
|---|---|
| `test/auth_errores_test.dart` | **Nuevo.** La traducción de códigos de Auth. |
| `test/arb_paridad_test.dart` | Ya existe; sigue verde. |
| `scripts/probar.mjs` | **Reescrito** sobre la API REST de Auth. |

---

### Task 1: Dependencia de Auth y la envoltura `lib/auth.dart`

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/auth.dart`
- Test: `test/auth_errores_test.dart`

**Interfaces:**
- Consumes: `FuncionError(codigo, clave, mensaje)` de `lib/funciones.dart`.
- Produces:
  - `String claveDeAuth(String code)` — traduce `FirebaseAuthException.code` a una clave nuestra.
  - `FuncionError comoFuncionError(FirebaseAuthException e)` — envuelve la excepción de Auth en el mismo tipo que ya sabe traducir la interfaz.
  - `Future<String?> tokenActual()` — el *ID token* del usuario actual, o `null`.
  - `User? get usuarioActual`, `Stream<User?> get cambiosDeUsuario`.

**Contexto:** hoy toda la interfaz traduce errores con `e.texto(t)` sobre un `FuncionError`. Auth lanza `FirebaseAuthException`, de otro tipo. En vez de enseñar a cada pantalla dos formas de traducir, se convierte en el borde: Auth entra, `FuncionError` sale. Una sola forma de traducir en toda la app.

- [ ] **Step 1: Añadir la dependencia**

En `pubspec.yaml`, bajo `dependencies:`, junto a `firebase_core`:

```yaml
  firebase_auth: ^6.1.0
```

Ejecutar `flutter pub get`.

- [ ] **Step 2: Escribir el test que falla**

Crear `test/auth_errores_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:santa_secreto/auth.dart';

void main() {
  group('claveDeAuth', () {
    test('traduce los códigos que la app sabe mostrar', () {
      expect(claveDeAuth('invalid-email'), 'correo_invalido');
      expect(claveDeAuth('email-already-in-use'), 'correo_en_uso');
      expect(claveDeAuth('weak-password'), 'password_debil');
      expect(claveDeAuth('invalid-credential'), 'password_incorrecta');
      expect(claveDeAuth('wrong-password'), 'password_incorrecta');
      expect(claveDeAuth('user-not-found'), 'password_incorrecta');
      expect(claveDeAuth('too-many-requests'), 'demasiados_intentos');
      expect(claveDeAuth('network-request-failed'), 'sin_conexion');
      expect(claveDeAuth('requires-recent-login'), 'requiere_reautenticacion');
    });

    test('user-not-found y wrong-password dan la MISMA clave', () {
      // Distinguirlas le diría a cualquiera si un correo está registrado.
      // Es el oráculo de existencia que esta migración viene a cerrar.
      expect(claveDeAuth('user-not-found'), claveDeAuth('wrong-password'));
    });

    test('un código desconocido cae en una clave genérica', () {
      expect(claveDeAuth('algo-que-firebase-invente-mañana'), 'auth_desconocido');
    });
  });
}
```

(`santa_secreto` es el `name:` de `pubspec.yaml`, ya verificado.)

- [ ] **Step 3: Ejecutar el test y verificar que falla**

Run: `flutter test test/auth_errores_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'santa_secreto'` o `auth.dart` no existe.

- [ ] **Step 4: Escribir `lib/auth.dart`**

```dart
import 'package:firebase_auth/firebase_auth.dart';

import 'funciones.dart';

/// Traduce el código de un [FirebaseAuthException] a una de nuestras claves
/// de error, las mismas que ya usa `MensajeLocalizado.texto()`.
///
/// `user-not-found` y `wrong-password` dan A PROPÓSITO la misma clave: si
/// dijéramos "ese correo no existe", habríamos recreado el oráculo de
/// existencia que esta migración vino a cerrar. Firebase ya empuja en esa
/// dirección devolviendo `invalid-credential` para los dos casos cuando la
/// protección de enumeración de correos está activada; esto lo garantiza
/// también si estuviera apagada.
String claveDeAuth(String code) => switch (code) {
      'invalid-email' => 'correo_invalido',
      'email-already-in-use' => 'correo_en_uso',
      'weak-password' => 'password_debil',
      'invalid-credential' || 'wrong-password' || 'user-not-found' => 'password_incorrecta',
      'user-disabled' => 'cuenta_deshabilitada',
      'too-many-requests' => 'demasiados_intentos',
      'network-request-failed' => 'sin_conexion',
      'requires-recent-login' => 'requiere_reautenticacion',
      _ => 'auth_desconocido',
    };

/// Envuelve la excepción de Auth en el tipo que la interfaz ya sabe
/// traducir. Es el borde: a partir de aquí, en la app solo hay
/// [FuncionError].
FuncionError comoFuncionError(FirebaseAuthException e) =>
    FuncionError('auth', claveDeAuth(e.code), e.message ?? e.code);

FirebaseAuth get _auth => FirebaseAuth.instance;

User? get usuarioActual => _auth.currentUser;

Stream<User?> get cambiosDeUsuario => _auth.userChanges();

/// El *ID token* del usuario actual. Lo necesita [llamarFuncion] para la
/// cabecera `Authorization: Bearer`. Devuelve null si no hay sesión.
///
/// No se cachea: el SDK ya lo hace y lo refresca solo cuando caduca.
Future<String?> tokenActual() async {
  final u = _auth.currentUser;
  if (u == null) return null;
  return u.getIdToken();
}
```

- [ ] **Step 5: Ejecutar el test y verificar que pasa**

Run: `flutter test test/auth_errores_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 6: Comprobar el análisis**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/auth.dart test/auth_errores_test.dart
git commit -m "Auth entra por un solo borde: Firebase habla, sale FuncionError"
```

- [ ] **Step 8: Habilitar el proveedor en la consola (acción humana)**

Escribir en el informe de la tarea que **antes de la Tarea 12 alguien tiene que**, en la consola de Firebase del proyecto `santa-secreto-860c3`:

1. Authentication → Sign-in method → habilitar **Email/Password**. **No** habilitar "Email link (passwordless)".
2. Authentication → Settings → **Email enumeration protection: activada**.
3. Authentication → Settings → Authorized domains: comprobar que está el dominio de Hosting.

No es un paso de código y no bloquea las tareas siguientes, pero sin él la Tarea 12 falla entera.

---

### Task 2: Servidor — cimientos de autenticación y las funciones de cuenta

**Files:**
- Modify: `functions/index.js`

**Interfaces:**
- Produces:
  - `function uidDe(request, {exigirVerificado = true})` → `string`. Lanza `HttpsError('unauthenticated', …, {clave: 'sesion_invalida'})` si no hay `request.auth`, y `{clave: 'correo_sin_verificar'}` si `exigirVerificado` y el token no trae `email_verified`.
  - `function exigirReciente(request)` → `void`. Lanza `{clave: 'requiere_reautenticacion'}` si `auth_time` tiene más de `MAX_EDAD_SESION_S`.
  - `function usuarioRef(uid)` — misma firma, otro significado del argumento.
  - `exports.guardarPerfil` — `{nombre, apellido, pin}` → `{ok: true}`.
  - `exports.misGrupos` — `{}` → `{nombre, apellido, grupos: [...]}`, con la misma forma de `grupos` que devolvía `iniciarSesionCuenta`.
  - `exports.cambiarPin` — `{pinNuevo}` → `{ok: true}`. Ya no recibe credenciales.

**Contexto crítico:** `guardarPerfil` se llama **justo después de registrarse, cuando el correo TODAVÍA no está verificado**. Si exigiera verificación, nadie podría completar su perfil nunca. Es la única función que pasa `exigirVerificado: false`.

- [ ] **Step 1: Añadir los helpers de identidad**

En `functions/index.js`, **sustituir** el bloque que va desde el comentario `// --- Cuentas (nickname + contraseña + PIN) ---` hasta el final de `function usuarioRef(...)` por:

```js
// --- Cuentas (Firebase Auth + PIN) ------------------------------------
// La identidad la pone Firebase Auth: el cliente manda su ID token en la
// cabecera Authorization y el protocolo callable rellena `request.auth`.
// Aquí ya no se verifica ninguna contraseña — no la tenemos ni queremos
// tenerla.
//
// El PIN de 4 dígitos sobrevive: es la segunda barrera para una sola
// acción —revelar tu amigo secreto— y sigue siendo nuestro, con bcrypt.
// `bcryptjs` se queda EXCLUSIVAMENTE para eso.

const REGEX_PIN = /^\d{4}$/;

// Cinco intentos y quince minutos de espera convierten 10.000 combinaciones en
// semanas de trabajo. No deja a nadie fuera para siempre: quien se bloquee
// cambia su PIN reautenticándose y sigue.
const MAX_INTENTOS_PIN = 5;
const BLOQUEO_PIN_MS = 15 * 60 * 1000;

// Cuánto vale una reautenticación. Cinco minutos dan de sobra para teclear
// un PIN nuevo y son demasiado poco para que le sirvan a quien coja el
// dispositivo más tarde.
const MAX_EDAD_SESION_S = 5 * 60;

function validarPin(pin) {
  if (!REGEX_PIN.test(pin || "")) {
    throw new HttpsError("invalid-argument", "El PIN debe ser de 4 dígitos exactos.", {clave: "pin_formato"});
  }
}

/**
 * El uid de quien llama, ya verificado por Firebase.
 *
 * `exigirVerificado` es false SOLO en `guardarPerfil`: se llama justo
 * después de registrarse, cuando el correo todavía no puede estar
 * verificado. Exigirlo ahí dejaría a todo el mundo sin poder completar su
 * perfil jamás.
 */
function uidDe(request, {exigirVerificado = true} = {}) {
  const auth = request.auth;
  if (!auth || !auth.uid) {
    throw new HttpsError("unauthenticated", "Tienes que entrar en tu cuenta.", {clave: "sesion_invalida"});
  }
  if (exigirVerificado && auth.token.email_verified !== true) {
    throw new HttpsError("permission-denied", "Verifica tu correo para continuar.", {clave: "correo_sin_verificar"});
  }
  return auth.uid;
}

/**
 * Exige que la sesión sea RECIENTE, no solo válida.
 *
 * Sin esto, reautenticarse sería puro teatro: quien tenga el dispositivo
 * desbloqueado tiene un token válido y puede llamar a la función directa,
 * saltándose la pantalla que pide la contraseña. `auth_time` es el único
 * dato del token que el cliente no puede falsear, y reautenticarse es lo
 * único que lo actualiza.
 */
function exigirReciente(request) {
  const authTime = request.auth?.token?.auth_time;
  if (typeof authTime !== "number") {
    throw new HttpsError("permission-denied", "Vuelve a confirmar tu contraseña.", {clave: "requiere_reautenticacion"});
  }
  const edad = Math.floor(Date.now() / 1000) - authTime;
  if (edad > MAX_EDAD_SESION_S) {
    throw new HttpsError("permission-denied", "Vuelve a confirmar tu contraseña.", {clave: "requiere_reautenticacion"});
  }
}

function usuarioRef(uid) {
  return db.collection("usuarios").doc(uid);
}
```

Con esto desaparecen `REGEX_PASSWORD`, `normalizarNickname`, `validarPassword` y la constante de longitud del apodo.

- [ ] **Step 2: Sustituir `registrarCuenta` por `guardarPerfil`**

Borrar entero `exports.registrarCuenta` y poner en su lugar:

```js
const MAX_NOMBRE = 40;

/**
 * Crea el documento de perfil de una cuenta de Auth recién registrada.
 *
 * Se eligió una llamada explícita del cliente en vez de un disparador de
 * Auth: es más simple de probar y no depende de la semántica de triggers
 * entre v1 y v2.
 *
 * Usa `create()`, no `set()`: así una cuenta que ya tiene perfil no puede
 * reescribirse el PIN desde una sesión sin verificar. Y hace la llamada
 * idempotente de cara al cliente, que puede reintentar sin miedo.
 */
exports.guardarPerfil = onCall(async (request) => {
  const uid = uidDe(request, {exigirVerificado: false});
  const nombre = (request.data?.nombre || "").trim();
  const apellido = (request.data?.apellido || "").trim();
  const pin = (request.data?.pin || "").trim();

  if (!nombre || !apellido) {
    throw new HttpsError("invalid-argument", "Faltan el nombre o el apellido.", {clave: "faltan_datos"});
  }
  if (nombre.length > MAX_NOMBRE || apellido.length > MAX_NOMBRE) {
    throw new HttpsError("invalid-argument", `El nombre y el apellido no pueden pasar de ${MAX_NOMBRE} caracteres.`, {clave: "nombre_largo"});
  }
  validarPin(pin);

  try {
    await usuarioRef(uid).create({
      nombre,
      apellido,
      correo: request.auth.token.email || "",
      pinHash: bcrypt.hashSync(pin, 10),
      fecha: admin.firestore.FieldValue.serverTimestamp(),
      grupos: {},
    });
  } catch (e) {
    // Ya existía: es un reintento del cliente. No es un error para quien
    // llama, y sobre todo NO se reescribe el PIN.
    if (e.code === 6 || e.code === "already-exists") return {ok: true};
    throw e;
  }
  return {ok: true};
});
```

- [ ] **Step 3: Reescribir `cambiarPin`**

Sustituir entero `exports.cambiarPin` por:

```js
/**
 * Cambiar el PIN exige una sesión RECIENTE, no solo válida — ver
 * `exigirReciente`. Es también la salida de emergencia de quien olvidó el
 * PIN o se bloqueó intentándolo: su hash es nuestro y nadie puede releerlo,
 * así que la única vuelta es fijar uno nuevo demostrando la contraseña.
 */
exports.cambiarPin = onCall(async (request) => {
  const uid = uidDe(request);
  exigirReciente(request);
  const pinNuevo = (request.data?.pinNuevo || "").trim();
  validarPin(pinNuevo);

  await usuarioRef(uid).update({
    pinHash: bcrypt.hashSync(pinNuevo, 10),
    // Cambiar el PIN levanta el bloqueo. Sin esto, quien fija un PIN nuevo
    // seguiría bloqueado quince minutos con el PIN correcto.
    pinFallos: 0,
    pinBloqueadoHasta: 0,
  });
  return {ok: true};
});
```

- [ ] **Step 4: Sustituir `iniciarSesionCuenta` por `misGrupos`**

Sustituir entero `exports.iniciarSesionCuenta` por lo siguiente. **El cuerpo que calcula `detalles` y limpia los grupos muertos se copia tal cual del original** — solo cambian la cabecera, de dónde sale `datos`, y el `return`:

```js
/**
 * El perfil y los grupos de quien llama.
 *
 * Sigue siendo una Cloud Function y no una lectura directa de Firestore
 * aunque las reglas nuevas dejarían leer `usuarios/{uid}`: limpiar los
 * grupos que ya no existen es una ESCRITURA, y la escritura sigue cerrada
 * al cliente.
 *
 * `perfilCompleto: false` significa que hay cuenta de Auth pero no
 * documento de perfil — pasa si `guardarPerfil` falló por red justo
 * después de registrarse. El cliente lo usa para mandar a completar el
 * perfil en vez de dejar a esa persona en una app medio rota.
 */
exports.misGrupos = onCall(async (request) => {
  const uid = uidDe(request);

  const snap = await usuarioRef(uid).get();
  if (!snap.exists) {
    return {perfilCompleto: false, nombre: "", apellido: "", grupos: []};
  }
  const datos = snap.data();

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
      await usuarioRef(uid).update(
          new admin.firestore.FieldPath("grupos", codigo),
          admin.firestore.FieldValue.delete(),
      );
    }
  }

  return {
    perfilCompleto: true,
    nombre: datos.nombre || "",
    apellido: datos.apellido || "",
    grupos: detalles,
  };
});
```

- [ ] **Step 5: Comprobar que no queda nada del modelo viejo**

Run:
```bash
cd functions && node --check index.js && cd ..
grep -n "nickname\|normalizarNickname\|validarPassword\|REGEX_PASSWORD\|verificarCuenta" functions/index.js
```
Expected: `node --check` sin salida (sintaxis correcta). El `grep` **sí** encontrará todavía `verificarCuenta` y `nickname` en las doce funciones de grupo — se migran en la Tarea 3. Anotar en el informe cuántas apariciones quedan, para que la Tarea 3 tenga un número contra el que cerrar.

- [ ] **Step 6: Commit**

```bash
git add functions/index.js
git commit -m "El servidor deja de recibir contraseñas: la identidad la pone Auth"
```

---

### Task 3: Servidor — las doce funciones de grupo pasan a `uid`

**Files:**
- Modify: `functions/index.js`

**Interfaces:**
- Consumes: `uidDe(request)` y `usuarioRef(uid)` de la Tarea 2.
- Produces: `async function autorizar(codigo, uid)` → `{uid, rol, participanteId, datos}`.

**Contexto:** el helper `autorizar()` se conserva entero — es el diseño de P2 y sigue siendo correcto. Lo único que cambia es que ya no verifica una contraseña: recibe un `uid` que Firebase ya validó. `exigirOrganizador` y `exigirParticipante` **no se tocan**.

Ojo: el campo del resultado se llamaba `clave` (el apodo normalizado). Pasa a llamarse `uid`. Hay que renombrar sus usos.

- [ ] **Step 1: Reescribir `verificarCuenta` + `autorizar`**

Sustituir el bloque que va desde el comentario `/** Solo comprueba la cuenta...` hasta el cierre de `async function autorizar(...)` por:

```js
/**
 * Tu vínculo con un grupo.
 *
 * Lo importante sigue siendo de dónde sale el `participanteId`: el
 * servidor lo DERIVA del vínculo, nunca se lo cree al cliente. Lo que
 * cambia con Auth es solo el primer paso — la identidad ya viene
 * verificada por Firebase, así que `verificarCuenta` desapareció.
 */
async function autorizar(codigo, uid) {
  const snap = await usuarioRef(uid).get();
  if (!snap.exists) {
    throw new HttpsError("unauthenticated", "Tu cuenta no tiene perfil. Vuelve a entrar.", {clave: "perfil_incompleto"});
  }
  const datos = snap.data();
  const vinculo = (datos.grupos || {})[codigo] || null;
  return {
    uid,
    rol: vinculo ? vinculo.rol : null,
    participanteId: vinculo ? (vinculo.participanteId || null) : null,
    datos,
  };
}
```

- [ ] **Step 2: Renombrar `clave` a `uid` en los vinculadores**

En `vincularComoOrganizador` y `vincularComoParticipante`, renombrar el parámetro `clave` a `uid`. El cuerpo no cambia salvo el nombre del argumento que se pasa a `usuarioRef`. Los comentarios largos de ambas funciones **se conservan íntegros**: explican el bug del grupo duplicado y siguen siendo ciertos.

- [ ] **Step 3: Migrar `crearGrupo`**

Sustituir:
```js
  const {clave} = await verificarCuenta(request.data?.nickname, request.data?.password);
```
por:
```js
  // Aquí no se usa `autorizar` porque el grupo todavía no existe: no hay
  // vínculo que consultar. Solo hace falta saber quién eres.
  const uid = uidDe(request);
```
Y renombrar los usos posteriores de `clave` en esa función a `uid` (la llamada a `vincularComoOrganizador`).

- [ ] **Step 4: Migrar las once funciones restantes**

En cada una, sustituir la línea de autorización por su equivalente con `uid`:

| Función | Antes | Después |
|---|---|---|
| `agregarParticipante` | `const sesion = await autorizar(codigo, request.data?.nickname, request.data?.password);` | `const sesion = await autorizar(codigo, uidDe(request));` |
| `borrarParticipante` | idem | idem |
| `cambiarAvatar` | idem | idem |
| `editarParticipante` | `exigirOrganizador(await autorizar(codigo, request.data?.nickname, request.data?.password));` | `exigirOrganizador(await autorizar(codigo, uidDe(request)));` |
| `verAmigoSecreto` | `const sesion = await autorizar(...);` | `const sesion = await autorizar(codigo, uidDe(request));` |
| `ejecutarSorteo` | `exigirOrganizador(await autorizar(...));` | `exigirOrganizador(await autorizar(codigo, uidDe(request)));` |
| `enviarMensaje` | `const sesion = await autorizar(...);` | `const sesion = await autorizar(codigo, uidDe(request));` |
| `borrarMensaje` | `exigirOrganizador(await autorizar(...));` | `exigirOrganizador(await autorizar(codigo, uidDe(request)));` |
| `miMascara` | `const sesion = await autorizar(...);` | `const sesion = await autorizar(codigo, uidDe(request));` |
| `editarGrupo` | `exigirOrganizador(await autorizar(...));` | `exigirOrganizador(await autorizar(codigo, uidDe(request)));` |
| `eliminarGrupo` | `exigirOrganizador(await autorizar(...));` | `exigirOrganizador(await autorizar(codigo, uidDe(request)));` |

Dentro de cada función, renombrar cualquier uso de `sesion.clave` a `sesion.uid`.

- [ ] **Step 5: Actualizar el comentario obsoleto de avatares**

En el bloque `// --- Avatares ---`, la frase «la app no usa Firebase Auth, así que unas reglas de Storage que permitan escribir dejarían el bucket abierto a cualquiera» ya no es cierta. Sustituir ese párrafo por:

```js
// Las imágenes entran por aquí, nunca directo del cliente al bucket. Con
// Auth ya se podrían escribir reglas de Storage que digan "tú", pero no
// sabrían decir "y además estás en ESTE grupo": eso vive en el mapa
// `grupos` del usuario, que las reglas de Storage no pueden leer. Subirlas
// por la función mantiene la misma autorización que el resto de la app.
```

- [ ] **Step 6: Verificar que no queda rastro del modelo viejo**

Run:
```bash
cd functions && node --check index.js && cd ..
grep -c "nickname\|password\|verificarCuenta\|sesion\.clave" functions/index.js
```
Expected: `node --check` limpio y el `grep -c` devuelve **0**. Si devuelve algo distinto de 0, la migración está incompleta: listar las líneas y arreglarlas antes de commitear.

- [ ] **Step 7: Commit**

```bash
git add functions/index.js
git commit -m "Las quince funciones autorizan con el uid que verificó Firebase"
```

---

### Task 4: Reglas de Firestore

**Files:**
- Modify: `firestore.rules`

**Contexto:** primera vez que las reglas pueden decir "tú". La escritura sigue cerrada: el `pinHash` y el mapa `grupos` los toca solo el Admin SDK. El `allow list: if false` de `grupos` **no se toca** — se cerró el 2026-08-09 y sigue siendo el arreglo más importante del fichero.

- [ ] **Step 1: Abrir la lectura del propio perfil**

Sustituir:
```
    match /usuarios/{nickname} {
      allow read, write: if false;
    }
```
por:
```
    match /usuarios/{uid} {
      // Primera regla de esta app que puede decir "tú". La escritura sigue
      // cerrada: el pinHash y el mapa `grupos` los toca solo el Admin SDK.
      allow read: if request.auth != null && request.auth.uid == uid;
      allow write: if false;
    }
```

- [ ] **Step 2: Actualizar el comentario de cabecera**

Sustituir el párrafo que empieza por `// usuarios/{nickname}: cuentas (nickname + hash de contraseña...` por:

```
// usuarios/{uid}: el perfil de una cuenta de Firebase Auth (nombre,
// apellido, correo, hash bcrypt del PIN de 4 dígitos, y el mapa de grupos
// vinculados). Cada quien lee SOLO el suyo; escribe solo el Admin SDK
// desde las Cloud Functions. La contraseña ya no está aquí ni en ninguna
// parte nuestra: la guarda Firebase Auth.
```

Y en el párrafo de `grupos/{codigo}/privado/data`, la frase «El PIN maestro que vivía aquí desapareció: ser organizador lo dice tu cuenta» sigue siendo cierta — no se toca.

- [ ] **Step 3: Comprobar que compilan**

Run: `firebase deploy --only firestore:rules --dry-run`
Expected: `rules file firestore.rules compiled successfully`.

Si `--dry-run` no está disponible en esta versión de la CLI, saltar este paso y anotarlo en el informe: la compilación se verificará en la Tarea 12, que despliega de verdad.

- [ ] **Step 4: Commit**

```bash
git add firestore.rules
git commit -m "Las reglas ya pueden decir tú: cada quien lee su propio perfil"
```

---

### Task 5: El transporte manda el token

**Files:**
- Modify: `lib/funciones.dart`

**Interfaces:**
- Consumes: `tokenActual()` de `lib/auth.dart`.
- Produces: `llamarFuncion(nombre, datos)` con la misma firma; ahora adjunta `Authorization: Bearer <idToken>` cuando hay sesión.

**Esta es la tarea que rompe todo si sale mal.** `lib/funciones.dart` no usa el paquete `cloud_functions` por el bug dart2js [flutterfire#17924](https://github.com/firebase/flutterfire/issues/17924), así que la cabecera hay que ponerla a mano. Sin ella, las quince funciones ven `request.auth` vacío y la app entera deja de autorizar — de golpe, no gradualmente.

- [ ] **Step 1: Añadir la cabecera**

En `lib/funciones.dart`, añadir el import:
```dart
import 'auth.dart';
```

Y sustituir el cuerpo de `llamarFuncion` desde `final http.Response resp;` hasta el `catch` del `http.post` por:

```dart
  // El protocolo callable saca la identidad de esta cabecera. Como no
  // usamos el paquete `cloud_functions` (ver la nota de arriba), nadie la
  // pone por nosotros: hay que adjuntarla a mano. Si falta, las quince
  // funciones ven `request.auth` vacío y la app entera deja de autorizar.
  final headers = <String, String>{'Content-Type': 'application/json'};
  final token = await tokenActual();
  if (token != null) headers['Authorization'] = 'Bearer $token';

  final http.Response resp;
  try {
    resp = await http.post(
      Uri.parse('$_baseUrl/$nombre'),
      headers: headers,
      body: jsonEncode({'data': datos}),
    );
  } catch (e) {
    throw FuncionError('unavailable', 'sin_conexion', 'No se pudo conectar: $e');
  }
```

- [ ] **Step 2: Añadir las claves de error nuevas al traductor**

En el `switch (clave)` de `MensajeLocalizado.texto`, junto a las que ya hay:

```dart
        'correo_sin_verificar' => t.errorCorreoSinVerificar,
        'requiere_reautenticacion' => t.errorRequiereReautenticacion,
        'perfil_incompleto' => t.errorPerfilIncompleto,
        'correo_invalido' => t.errorCorreoInvalido,
        'correo_en_uso' => t.errorCorreoEnUso,
        'demasiados_intentos' => t.errorDemasiadosIntentos,
        'cuenta_deshabilitada' => t.errorCuentaDeshabilitada,
        'auth_desconocido' => t.errorAuthDesconocido,
        'nombre_largo' => t.errorNombreLargo,
```

Y **quitar** las tres que mueren con el apodo:
```dart
        'nickname_largo' => t.errorNicknameLargo,
        'nickname_en_uso' => t.errorNicknameEnUso,
        'nickname_no_existe' => t.errorNicknameNoExiste,
```

- [ ] **Step 3: Añadir las claves a los dos ARB**

En `lib/l10n/app_en.arb`, junto a los demás `error*`:

```json
  "errorCorreoSinVerificar": "Verify your email to continue.",
  "@errorCorreoSinVerificar": {"description": "Server rejected the call because the account's email is not verified yet"},
  "errorRequiereReautenticacion": "For security, confirm your password again.",
  "@errorRequiereReautenticacion": {"description": "The action needs a recent sign-in and the session is too old"},
  "errorPerfilIncompleto": "Your account has no profile yet. Sign in again to finish it.",
  "@errorPerfilIncompleto": {"description": "There is an Auth account but no profile document"},
  "errorCorreoInvalido": "That email address doesn't look right.",
  "@errorCorreoInvalido": {"description": "Malformed email address"},
  "errorCorreoEnUso": "That email already has an account. Sign in instead.",
  "@errorCorreoEnUso": {"description": "Email already registered"},
  "errorDemasiadosIntentos": "Too many attempts. Wait a few minutes and try again.",
  "@errorDemasiadosIntentos": {"description": "Firebase Auth rate limit hit"},
  "errorCuentaDeshabilitada": "This account has been disabled.",
  "@errorCuentaDeshabilitada": {"description": "Account disabled from the Firebase console"},
  "errorAuthDesconocido": "Something went wrong signing you in. Try again.",
  "@errorAuthDesconocido": {"description": "Fallback for an Auth error code this version doesn't know"},
  "errorNombreLargo": "Your name and surname can't be longer than 40 characters each.",
  "@errorNombreLargo": {"description": "Name or surname over the server limit"},
```

En `lib/l10n/app_es.arb`, **sin bloques `@`**:

```json
  "errorCorreoSinVerificar": "Verifica tu correo para continuar.",
  "errorRequiereReautenticacion": "Por seguridad, confirma otra vez tu contraseña.",
  "errorPerfilIncompleto": "Tu cuenta todavía no tiene perfil. Vuelve a entrar para terminarlo.",
  "errorCorreoInvalido": "Esa dirección de correo no parece correcta.",
  "errorCorreoEnUso": "Ese correo ya tiene cuenta. Entra en vez de crear una.",
  "errorDemasiadosIntentos": "Demasiados intentos. Espera unos minutos y vuelve a probar.",
  "errorCuentaDeshabilitada": "Esta cuenta ha sido deshabilitada.",
  "errorAuthDesconocido": "Algo salió mal al entrar. Vuelve a intentarlo.",
  "errorNombreLargo": "El nombre y el apellido no pueden pasar de 40 caracteres cada uno.",
```

**No borrar todavía de los ARB** `errorNicknameLargo`, `errorNicknameEnUso` ni `errorNicknameNoExiste`. Quitarlas del `switch` ya las deja sin uso, pero una clave ARB huérfana no rompe nada, mientras que `cuentaNickname` —que sigue viva hasta la Tarea 6— sí. Toda la limpieza del apodo se hace de una vez en la Tarea 10, cuando ninguna esté en uso.

- [ ] **Step 4: Regenerar y comprobar**

Run:
```bash
flutter gen-l10n && flutter analyze && flutter test
```
Expected: `No issues found!` y todos los tests en verde, incluido `test/arb_paridad_test.dart`.

- [ ] **Step 5: Commit**

```bash
git add lib/funciones.dart lib/l10n/
git commit -m "Sin esta cabecera el servidor no sabe quién llama"
```

---

### Task 6: El flujo de entrada — registro, verificación y portero

**Files:**
- Rewrite: `lib/acceso_cuenta.dart`
- Modify: `lib/pantalla_crear_cuenta.dart`, `lib/pantalla_iniciar_sesion.dart`, `lib/pantalla_raiz.dart`
- Create: `lib/pantalla_verificar_correo.dart`, `lib/pantalla_completar_perfil.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_es.arb`

**Interfaces:**
- Consumes: `lib/auth.dart` (Tarea 1), `llamarFuncion` con bearer (Tarea 5), `guardarPerfil` y `misGrupos` (Tarea 2).
- Produces:
  - `class ResultadoAcceso { final String nombre; final String apellido; final List<Map<String,dynamic>> grupos; }`
  - `Future<void> crearCuenta({required String correo, required String password, required String nombre, required String apellido, required String pin})`
  - `Future<void> entrar({required String correo, required String password})`
  - `Future<ResultadoAcceso?> cargarMisGrupos()` — devuelve `null` si el perfil no existe.
  - `Future<void> mandarVerificacion()`
  - `Future<bool> correoVerificado()` — recarga el usuario y devuelve `emailVerified`.

**Estos cinco ficheros son una sola unidad**: el portero y las dos puertas. Separarlos dejaría `flutter analyze` roto entre tareas.

- [ ] **Step 1: Reescribir `lib/acceso_cuenta.dart`**

```dart
import 'package:firebase_auth/firebase_auth.dart';

import 'auth.dart';
import 'funciones.dart';
import 'idioma.dart';

/// El perfil y los grupos de quien ha entrado.
class ResultadoAcceso {
  final String nombre;
  final String apellido;
  final List<Map<String, dynamic>> grupos;
  const ResultadoAcceso(this.nombre, this.apellido, this.grupos);
}

/// Convierte cualquier fallo de Auth en el [FuncionError] que la interfaz
/// ya sabe traducir. Todo lo de este fichero pasa por aquí.
Future<T> _traduciendo<T>(Future<T> Function() accion) async {
  try {
    return await accion();
  } on FirebaseAuthException catch (e) {
    throw comoFuncionError(e);
  }
}

/// Registra la cuenta, guarda el perfil y manda el correo de verificación.
///
/// El orden importa: si `guardarPerfil` fallara después de mandar el
/// correo, quedaría alguien verificado y sin PIN. Primero el perfil.
Future<void> crearCuenta({
  required String correo,
  required String password,
  required String nombre,
  required String apellido,
  required String pin,
}) async {
  await _traduciendo(() => FirebaseAuth.instance
      .createUserWithEmailAndPassword(email: correo.trim(), password: password));
  await llamarFuncion('guardarPerfil', {
    'nombre': nombre.trim(),
    'apellido': apellido.trim(),
    'pin': pin.trim(),
  });
  await mandarVerificacion();
}

Future<void> entrar({required String correo, required String password}) =>
    _traduciendo(() => FirebaseAuth.instance
        .signInWithEmailAndPassword(email: correo.trim(), password: password));

/// Manda (o reenvía) el enlace de verificación.
///
/// `setLanguageCode` va ANTES de mandarlo: es lo único que decide el idioma
/// del correo, y sin esto le llega en inglés a todo el mundo.
Future<void> mandarVerificacion() async {
  final u = FirebaseAuth.instance.currentUser;
  if (u == null) return;
  await FirebaseAuth.instance.setLanguageCode(Idioma.actual.value.languageCode);
  await _traduciendo(() => u.sendEmailVerification());
}

/// Recarga al usuario desde el servidor y dice si ya verificó.
///
/// Hace falta recargar: `emailVerified` es una foto del token, y el token
/// se hizo antes de que esa persona pinchara el enlace.
Future<bool> correoVerificado() async {
  final u = FirebaseAuth.instance.currentUser;
  if (u == null) return false;
  await _traduciendo(() => u.reload());
  return FirebaseAuth.instance.currentUser?.emailVerified ?? false;
}

/// El perfil y los grupos. Devuelve null si la cuenta de Auth existe pero
/// su documento de perfil no — pasa si `guardarPerfil` falló por red justo
/// después de registrarse.
Future<ResultadoAcceso?> cargarMisGrupos() async {
  final r = await llamarFuncion('misGrupos', {});
  if (r['perfilCompleto'] != true) return null;
  return ResultadoAcceso(
    r['nombre'] as String? ?? '',
    r['apellido'] as String? ?? '',
    List<Map<String, dynamic>>.from(
        (r['grupos'] as List).map((g) => Map<String, dynamic>.from(g as Map))),
  );
}

/// Completa el perfil de una cuenta que se quedó a medias.
Future<void> completarPerfil({
  required String nombre,
  required String apellido,
  required String pin,
}) =>
    llamarFuncion('guardarPerfil', {
      'nombre': nombre.trim(),
      'apellido': apellido.trim(),
      'pin': pin.trim(),
    });

Future<void> salir() => FirebaseAuth.instance.signOut();
```

`Idioma.actual` es un `ValueNotifier<Locale>` (ver `lib/idioma.dart:17`), de ahí el `.value.languageCode`.

- [ ] **Step 2: Crear `lib/pantalla_verificar_correo.dart`**

Pantalla sin salida hacia dentro: solo se avanza verificando.

```dart
import 'package:flutter/material.dart';

import 'acceso_cuenta.dart';
import 'funciones.dart';
import 'glass.dart';
import 'l10n/app_localizations.dart';

/// Pantalla de espera tras registrarse. Bloquea a propósito: un correo sin
/// verificar es un camino de recuperación que quizá no existe, y la
/// recuperación es medio motivo de que exista esta pantalla.
class PantallaVerificarCorreo extends StatefulWidget {
  /// Qué hacer cuando el correo queda verificado.
  final Future<void> Function(BuildContext) alVerificar;
  const PantallaVerificarCorreo({super.key, required this.alVerificar});

  @override
  State<PantallaVerificarCorreo> createState() => _PantallaVerificarCorreoState();
}

class _PantallaVerificarCorreoState extends State<PantallaVerificarCorreo> {
  bool _comprobando = false;
  bool _reenviando = false;

  void _avisar(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _comprobar() async {
    final t = Textos.of(context);
    setState(() => _comprobando = true);
    try {
      if (await correoVerificado()) {
        if (!mounted) return;
        await widget.alVerificar(context);
        return;
      }
      _avisar('⚠️ ${t.verificarTodaviaNo}');
    } catch (e) {
      _avisar('⚠️ ${e is FuncionError ? e.texto(t) : t.errorInesperado(e.toString())}');
    } finally {
      if (mounted) setState(() => _comprobando = false);
    }
  }

  Future<void> _reenviar() async {
    final t = Textos.of(context);
    setState(() => _reenviando = true);
    try {
      await mandarVerificacion();
      _avisar('✅ ${t.verificarReenviado}');
    } catch (e) {
      _avisar('⚠️ ${e is FuncionError ? e.texto(t) : t.errorInesperado(e.toString())}');
    } finally {
      if (mounted) setState(() => _reenviando = false);
    }
  }

  Future<void> _salir() async {
    await salir();
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
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
                const Icon(Icons.mark_email_unread_outlined, size: 64),
                const SizedBox(height: 16),
                Text(t.verificarTitulo,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(t.verificarTexto, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _comprobando ? null : _comprobar,
                  child: Text(_comprobando ? t.verificarComprobando : t.verificarComprobar),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _reenviando ? null : _reenviar,
                  child: Text(_reenviando ? t.verificarReenviando : t.verificarReenviar),
                ),
                const SizedBox(height: 8),
                TextButton(onPressed: _salir, child: Text(t.misGruposCerrarSesion)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

`t.misGruposCerrarSesion` es la clave que ya usa `pantalla_mis_grupos.dart`; se reutiliza en vez de crear una nueva. El import de `glass.dart` solo hace falta si se usa: si no, quitarlo para que el análisis quede limpio.

- [ ] **Step 3: Crear `lib/pantalla_completar_perfil.dart`**

```dart
import 'package:flutter/material.dart';

import 'acceso_cuenta.dart';
import 'funciones.dart';
import 'l10n/app_localizations.dart';

/// Red de seguridad: hay cuenta de Auth pero no documento de perfil.
/// Pasa si `guardarPerfil` falló por red justo después de registrarse.
/// Sin esta pantalla, esa persona se quedaría con una app medio rota y sin
/// forma de arreglarla.
class PantallaCompletarPerfil extends StatefulWidget {
  final Future<void> Function(BuildContext) alCompletar;
  const PantallaCompletarPerfil({super.key, required this.alCompletar});

  @override
  State<PantallaCompletarPerfil> createState() => _PantallaCompletarPerfilState();
}

class _PantallaCompletarPerfilState extends State<PantallaCompletarPerfil> {
  final _nombre = TextEditingController();
  final _apellido = TextEditingController();
  final _pin = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() {
    _nombre.dispose();
    _apellido.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final t = Textos.of(context);
    if (_nombre.text.trim().isEmpty ||
        _apellido.text.trim().isEmpty ||
        _pin.text.trim().length != 4) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('⚠️ ${t.cuentaFaltanDatos}')));
      return;
    }
    setState(() => _guardando = true);
    try {
      await completarPerfil(
          nombre: _nombre.text, apellido: _apellido.text, pin: _pin.text);
      if (!mounted) return;
      await widget.alCompletar(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '⚠️ ${e is FuncionError ? e.texto(t) : t.errorInesperado(e.toString())}')));
      setState(() => _guardando = false);
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
                Text(t.completarPerfilTitulo,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(t.completarPerfilTexto, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                TextField(
                    controller: _nombre,
                    decoration: InputDecoration(labelText: t.cuentaNombre)),
                const SizedBox(height: 12),
                TextField(
                    controller: _apellido,
                    decoration: InputDecoration(labelText: t.cuentaApellido)),
                const SizedBox(height: 12),
                TextField(
                  controller: _pin,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  decoration: InputDecoration(labelText: t.cuentaPin),
                ),
                const SizedBox(height: 16),
                FilledButton(
                    onPressed: _guardando ? null : _guardar,
                    child: Text(t.guardar)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

`t.cuentaPin` y `t.guardar` ya existen en los dos ARB; solo son nuevas `completarPerfilTitulo` y `completarPerfilTexto`, que se añaden en el Step 7.

- [ ] **Step 4: Cambiar los campos de `pantalla_crear_cuenta.dart`**

- Sustituir el controlador `_nickname` por `_correo`, y añadir `_nombre` y `_apellido`. Todos con su `dispose()`.
- El campo de correo: `keyboardType: TextInputType.emailAddress`, etiqueta `t.cuentaCorreo`.
- El campo de nombre: etiqueta `t.cuentaNombre`. El de apellido: `t.cuentaApellido`.
- Sustituir la llamada `entrarConCuenta(...)` por:

```dart
      await crearCuenta(
        correo: _correo.text,
        password: _password.text,
        nombre: _nombre.text,
        apellido: _apellido.text,
        pin: _pin.text,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PantallaVerificarCorreo(alVerificar: _trasVerificar),
        ),
      );
```

Y añadir al State:

```dart
  /// Tras verificar, se cargan los grupos y se sigue el camino normal —
  /// el mismo que sigue quien entra con una cuenta ya verificada.
  Future<void> _trasVerificar(BuildContext context) async {
    final r = await cargarMisGrupos();
    if (!context.mounted) return;
    if (r == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PantallaCompletarPerfil(alCompletar: _trasVerificar),
        ),
      );
      return;
    }
    await widget.alEntrar(context, r);
  }
```

- La validación local de campos añade nombre y apellido no vacíos al `if` que ya comprueba que no falten datos.
- Ampliar la validación existente para que el correo no esté vacío. **No** validar el formato del correo a mano: lo hace Auth y devuelve `invalid-email`, que ya se traduce.

- [ ] **Step 5: Cambiar `pantalla_iniciar_sesion.dart`**

- Sustituir `_nickname` por `_correo` con `keyboardType: TextInputType.emailAddress` y etiqueta `t.cuentaCorreo`.
- Sustituir la llamada por:

```dart
      await entrar(correo: _correo.text, password: _password.text);
      final u = usuarioActual;
      if (u != null && !u.emailVerified) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PantallaVerificarCorreo(alVerificar: _trasVerificar),
          ),
        );
        return;
      }
      await _trasVerificar(context);
```

Con el mismo `_trasVerificar` del paso anterior (repetido en este State — son dos pantallas independientes).

- Dejar preparado el hueco del enlace de recuperación con un `const SizedBox.shrink()` y un comentario `// El enlace de recuperación llega en la Tarea 7.` **No** inventar la pantalla aquí.

- [ ] **Step 6: Cambiar el portero `pantalla_raiz.dart`**

- Sustituir `final sesion = await leerSesion();` por `final u = usuarioActual;`
- `decidirDestino(haySesion: sesion != null, …)` pasa a `decidirDestino(haySesion: u != null, …)`. **`lib/destino_inicial.dart` no se toca** — su lógica es la misma.
- Sustituir `_entrarConLaSesionGuardada(Sesion sesion)` por:

```dart
  /// La sesión de Auth persiste sola, pero puede haber dejado de valer:
  /// cuenta borrada, contraseña cambiada desde otro sitio, o simplemente
  /// no hay red. Sin manejo de error la app se queda en el indicador de
  /// carga para siempre, que es la peor pantalla posible.
  Future<void> _entrarConLaSesionDeAuth(User u) async {
    if (!u.emailVerified) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PantallaVerificarCorreo(alVerificar: _trasVerificar),
        ),
      );
      return;
    }
    final ResultadoAcceso? resultado;
    try {
      resultado = await cargarMisGrupos();
    } on FuncionError catch (e) {
      // ÚNICAS claves que justifican echar a alguien de su sesión: el
      // servidor ha dicho que esta identidad no sirve. Cualquier otra
      // cosa —sin red, servidor caído, clave desconocida— la conserva.
      if (e.clave == 'sesion_invalida') {
        await _olvidarSesionEIrACrearCuenta();
        return;
      }
      if (!mounted) return;
      setState(() => _errorArranque = e);
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorArranque = e);
      return;
    }
    if (!mounted) return;
    if (resultado == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PantallaCompletarPerfil(alCompletar: (c) async {
            final r = await cargarMisGrupos();
            if (!c.mounted || r == null) return;
            await irADondeToque(c, r);
          }),
        ),
      );
      return;
    }
    await irADondeToque(context, resultado);
  }
```

Añadir `_trasVerificar` al State de `pantalla_raiz.dart`, con el mismo cuerpo que en el Step 4 de esta tarea.

- En `_olvidarSesionEIrACrearCuenta`, sustituir `await cerrarSesion();` por `await salir();`.
- Añadir el import `import 'package:firebase_auth/firebase_auth.dart';` por el tipo `User`.
- **No borrar todavía** `import 'sesion.dart';` de los ficheros que aún lo usan; en `pantalla_raiz.dart` sí se quita, porque ya no lo usa.

- [ ] **Step 7: Añadir las claves nuevas a los dos ARB**

En `lib/l10n/app_en.arb` (con sus `@`) y `lib/l10n/app_es.arb` (sin ellos):

| Clave | Inglés | Español |
|---|---|---|
| `cuentaCorreo` | `Email` | `Correo` |
| `cuentaNombre` | `First name` | `Nombre` |
| `cuentaApellido` | `Last name` | `Apellido` |
| `verificarTitulo` | `Check your inbox` | `Mira tu bandeja de entrada` |
| `verificarTexto` | `We sent you a link. Tap it to confirm your email, then come back here.` | `Te hemos mandado un enlace. Pínchalo para confirmar tu correo y vuelve aquí.` |
| `verificarComprobar` | `I've confirmed it` | `Ya lo confirmé` |
| `verificarComprobando` | `Checking…` | `Comprobando…` |
| `verificarReenviar` | `Send it again` | `Mandarlo otra vez` |
| `verificarReenviando` | `Sending…` | `Mandando…` |
| `verificarReenviado` | `Link sent` | `Enlace mandado` |
| `verificarTodaviaNo` | `Not confirmed yet. Check your inbox — it may be in spam.` | `Todavía no está confirmado. Mira tu bandeja, puede estar en el correo no deseado.` |
| `completarPerfilTitulo` | `One last step` | `Un último paso` |
| `completarPerfilTexto` | `Your account was created but your profile wasn't saved. Fill it in to continue.` | `Tu cuenta se creó pero tu perfil no se guardó. Rellénalo para continuar.` |

Descripciones de ejemplo para los bloques `@` de `app_en.arb`: `{"description": "Label of the email field on the account screens"}`, y equivalentes.

- [ ] **Step 8: Regenerar, analizar y probar**

Run:
```bash
flutter gen-l10n && flutter analyze && flutter test
```
Expected: `No issues found!` y todos los tests en verde.

`test/pantallas_cuenta_test.dart` probablemente falle: comprobaba el campo del apodo, que ya no existe. **Actualizarlo para que compruebe los campos nuevos** (correo, contraseña, nombre, apellido, PIN). No borrarlo ni vaciarlo — es la única cobertura de estas pantallas.

- [ ] **Step 9: Commit**

```bash
git add lib/ test/
git commit -m "La cuenta se abre con un correo verificado, no con un apodo"
```

---

### Task 7: Recuperar la contraseña

**Files:**
- Create: `lib/pantalla_recuperar_password.dart`
- Modify: `lib/pantalla_iniciar_sesion.dart`, `lib/acceso_cuenta.dart`, `lib/l10n/app_en.arb`, `lib/l10n/app_es.arb`

**Interfaces:**
- Produces: `Future<void> mandarRecuperacion(String correo)` en `acceso_cuenta.dart`.

**Contexto:** siendo el único método de entrada, este es el único camino de vuelta a una cuenta. Dos cosas que no son opcionales: `setLanguageCode` antes de mandar, o el correo llega en inglés a todo el mundo; y **la misma respuesta exista o no la cuenta**, o recrearíamos en una pantalla nueva el oráculo de existencia que esta migración vino a cerrar.

- [ ] **Step 1: Añadir la función a `acceso_cuenta.dart`**

```dart
/// Manda el enlace para poner una contraseña nueva.
///
/// **Nunca dice si ese correo tiene cuenta.** `user-not-found` se traga a
/// propósito: distinguirlo sería un oráculo de existencia — cualquiera
/// podría averiguar quién está registrado probando direcciones. Quien
/// llama debe enseñar SIEMPRE el mismo mensaje.
Future<void> mandarRecuperacion(String correo) async {
  await FirebaseAuth.instance.setLanguageCode(Idioma.actual.value.languageCode);
  try {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: correo.trim());
  } on FirebaseAuthException catch (e) {
    if (e.code == 'user-not-found') return;
    throw comoFuncionError(e);
  }
}
```

- [ ] **Step 2: Crear `lib/pantalla_recuperar_password.dart`**

```dart
import 'package:flutter/material.dart';

import 'acceso_cuenta.dart';
import 'funciones.dart';
import 'l10n/app_localizations.dart';

class PantallaRecuperarPassword extends StatefulWidget {
  const PantallaRecuperarPassword({super.key});

  @override
  State<PantallaRecuperarPassword> createState() => _PantallaRecuperarPasswordState();
}

class _PantallaRecuperarPasswordState extends State<PantallaRecuperarPassword> {
  final _correo = TextEditingController();
  bool _mandando = false;
  bool _mandado = false;

  @override
  void dispose() {
    _correo.dispose();
    super.dispose();
  }

  Future<void> _mandar() async {
    final t = Textos.of(context);
    if (_correo.text.trim().isEmpty) return;
    setState(() => _mandando = true);
    try {
      await mandarRecuperacion(_correo.text);
      if (!mounted) return;
      // El mismo mensaje exista o no la cuenta: ver mandarRecuperacion.
      setState(() => _mandado = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '⚠️ ${e is FuncionError ? e.texto(t) : t.errorInesperado(e.toString())}')));
    } finally {
      if (mounted) setState(() => _mandando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.recuperarTitulo)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _mandado
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.mark_email_read_outlined, size: 64),
                    const SizedBox(height: 16),
                    Text(t.recuperarEnviado, textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(t.cerrar)),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(t.recuperarTexto),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _correo,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(labelText: t.cuentaCorreo),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                        onPressed: _mandando ? null : _mandar,
                        child: Text(t.recuperarBoton)),
                  ],
                ),
        ),
      ),
    );
  }
}
```

`t.cerrar` ya existe en los dos ARB; no hace falta clave nueva.

- [ ] **Step 3: Poner el enlace en `pantalla_iniciar_sesion.dart`**

Sustituir el `const SizedBox.shrink()` con el comentario de la Tarea 6 por:

```dart
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PantallaRecuperarPassword()),
                  ),
                  child: Text(t.recuperarEnlace),
                ),
```

- [ ] **Step 4: Añadir las claves a los dos ARB**

| Clave | Inglés | Español |
|---|---|---|
| `recuperarEnlace` | `I forgot my password` | `He olvidado mi contraseña` |
| `recuperarTitulo` | `Recover your password` | `Recupera tu contraseña` |
| `recuperarTexto` | `Type the email you signed up with and we'll send you a link to set a new password.` | `Escribe el correo con el que te registraste y te mandamos un enlace para poner una contraseña nueva.` |
| `recuperarBoton` | `Send me the link` | `Mándame el enlace` |
| `recuperarEnviado` | `If that address has an account, we've sent it a link.` | `Si esa dirección tiene cuenta, le hemos mandado un enlace.` |

**`recuperarEnviado` está redactado así a propósito**: «si esa dirección tiene cuenta» es lo que impide que la pantalla confirme quién está registrado. No cambiarlo por algo más directo.

- [ ] **Step 5: Regenerar, analizar y probar**

Run: `flutter gen-l10n && flutter analyze && flutter test`
Expected: `No issues found!` y verde.

- [ ] **Step 6: Commit**

```bash
git add lib/ && git commit -m "El único camino de vuelta a una cuenta, sin decir quién tiene una"
```

---

### Task 8: Las pantallas de grupo dejan de mandar credenciales

**Files:**
- Modify: `lib/pantalla_registro.dart`, `lib/pantalla_chat.dart`, `lib/pantalla_crear_grupo.dart`, `lib/pantalla_editar_grupo.dart`, `lib/pantalla_unirse_grupo.dart`, `lib/pantalla_mis_grupos.dart`

**Contexto:** ahora el token viaja en la cabecera (Tarea 5). Mandar además `nickname` y `password` en el cuerpo es, en el mejor caso, ruido que el servidor ignora — y en el peor, la contraseña viajando sin motivo. Se quitan todos.

- [ ] **Step 1: `pantalla_registro.dart`**

- Borrar el método `_credenciales()` entero.
- En las **cinco** llamadas que usaban `...cred` (`verAmigoSecreto`, `ejecutarSorteo`, dos de `borrarParticipante`, `editarParticipante`), quitar el bloque `final cred = await _credenciales(); if (cred == null) {...}` y el `...cred` del mapa.
- En la llamada a `agregarParticipante` (línea ~251), quitar `nickname` y `password` del mapa y el `leerSesion()` que los obtenía.
- Quitar el import de `sesion.dart`.

- [ ] **Step 2: `pantalla_chat.dart`**

Las tres llamadas (`miMascara`, `enviarMensaje`, `borrarMensaje`) pierden `nickname` y `password`; los tres `final sesion = await leerSesion();` desaparecen con sus comprobaciones de null. Quitar el import de `sesion.dart`.

- [ ] **Step 3: `pantalla_crear_grupo.dart`, `pantalla_editar_grupo.dart`, `pantalla_unirse_grupo.dart`**

Lo mismo: fuera `leerSesion()`, fuera `nickname`/`password` de los mapas, fuera el import.

- [ ] **Step 4: `pantalla_mis_grupos.dart` — y el saludo que ya no tiene apodo**

- Fuera `leerSesion()` y su import.
- Sustituir `await cerrarSesion();` por `await salir();` (de `acceso_cuenta.dart`).
- **Renombrar el parámetro `final String nickname` a `final String nombre`** (`lib/pantalla_mis_grupos.dart:17-20`), y con él la llamada `t.misGruposSaludo(widget.nickname)` → `t.misGruposSaludo(widget.nombre)`.
- **Ese renombrado sale de esta pantalla**: `irADondeToque` en `lib/pantalla_raiz.dart:279` construye `PantallaMisGrupos` a partir de `ResultadoAcceso`. Cambiar ahí el argumento a `nombre: resultado.nombre`. La clave ARB `misGruposSaludo` **no cambia de nombre** — sigue tomando un parámetro y ahora recibe el nombre real en vez del apodo.

- [ ] **Step 5: Verificar que no queda ninguna credencial en vuelo**

Run:
```bash
grep -rn "'nickname'\|'password'\|leerSesion\|guardarSesion\|cerrarSesion" lib/
```
Expected: **cero resultados fuera de `lib/sesion.dart`** (que todavía existe y se borra en la Tarea 9) y de `lib/hoja_configuracion.dart` (Tarea 9). Si aparece cualquier otro fichero, la limpieza está incompleta.

- [ ] **Step 6: Analizar y probar**

Run: `flutter analyze && flutter test`
Expected: `No issues found!` y verde.

- [ ] **Step 7: Commit**

```bash
git add lib/ && git commit -m "La contraseña deja de viajar en el cuerpo de cada petición"
```

---

### Task 9: Cambiar el PIN exige reautenticarse (y muere `sesion.dart`)

**Files:**
- Modify: `lib/hoja_configuracion.dart`, `lib/acceso_cuenta.dart`, `lib/l10n/app_en.arb`, `lib/l10n/app_es.arb`
- Delete: `lib/sesion.dart`
- Test: `test/hoja_configuracion_test.dart`

**Interfaces:**
- Produces: `Future<void> reautenticar(String password)` en `acceso_cuenta.dart`.

**Contexto:** el servidor ya exige una sesión reciente (`exigirReciente`, Tarea 2). Esta tarea pone la mitad del cliente. Sin ella, cambiar el PIN falla siempre con `requiere_reautenticacion`.

**`lib/hoja_configuracion.dart` es el último fichero que importa `lib/sesion.dart`.** Esta tarea lo borra.

- [ ] **Step 1: Añadir `reautenticar` a `acceso_cuenta.dart`**

```dart
/// Vuelve a demostrar la contraseña. Actualiza el claim `auth_time` del
/// token, que es lo ÚNICO que el servidor mira para saber si la sesión es
/// reciente — ver `exigirReciente` en functions/index.js.
Future<void> reautenticar(String password) async {
  final u = FirebaseAuth.instance.currentUser;
  if (u == null || u.email == null) {
    throw FuncionError('auth', 'sesion_invalida', 'No hay sesión.');
  }
  await _traduciendo(() => u.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: u.email!, password: password)));
  // El token en memoria todavía lleva el auth_time viejo. Sin forzar el
  // refresco, la llamada siguiente iría con el token de antes y el
  // servidor la rechazaría — con la contraseña ya tecleada correctamente.
  await u.getIdToken(true);
}
```

- [ ] **Step 2: Cambiar `hoja_configuracion.dart`**

Sustituir el bloque que va de `final sesion = await leerSesion();` hasta la llamada a `llamarFuncion('cambiarPin', {...})` por:

```dart
      await reautenticar(password.text);
      await llamarFuncion('cambiarPin', {'pinNuevo': pinNuevo.text.trim()});
```

Quitar el import de `sesion.dart` y añadir `import 'acceso_cuenta.dart';` si no estaba.

El campo de contraseña que ya existe en el diálogo **se conserva tal cual**: ahora es literalmente la reautenticación.

**Ninguna clave ARB nueva.** `cambiarPinTexto` dice hoy *«Se te pide la contraseña de tu cuenta porque es la única vuelta si olvidas el PIN»* — y con Auth **sigue siendo verdad**: el hash del PIN es nuestro y nadie puede releerlo, así que fijar uno nuevo demostrando la contraseña sigue siendo la única salida. `cambiarPinPassword` («Contraseña de la cuenta») también vale igual. No inventar textos donde los que hay ya dicen lo correcto.

- [ ] **Step 3: Borrar `lib/sesion.dart`**

```bash
git rm lib/sesion.dart
```

- [ ] **Step 4: Comprobar que nadie lo echa de menos**

Run:
```bash
grep -rn "sesion.dart\|leerSesion\|guardarSesion\|cerrarSesion\|Sesion(" lib/ test/
```
Expected: **cero resultados.**

- [ ] **Step 5: Actualizar el test de la hoja**

`test/hoja_configuracion_test.dart` puede referirse a la sesión guardada. Ajustarlo para que siga comprobando lo mismo que comprobaba —que la hoja enseña el selector de idioma y el botón de cambiar PIN— sin `sesion.dart`. Recordar el patrón que ya usa el repo: envolver el hijo en `home: Scaffold(body: hijo)`, **no** meter un `Material` dentro del widget de producción.

- [ ] **Step 6: Regenerar, analizar y probar**

Run: `flutter gen-l10n && flutter analyze && flutter test`
Expected: `No issues found!` y verde.

- [ ] **Step 7: Commit**

```bash
git add -A lib/ test/ && git commit -m "Reautenticarse deja de ser teatro: el servidor mira auth_time"
```

---

### Task 10: Limpieza de los ARB

**Files:**
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_es.arb`

**Contexto:** se hace al final a propósito. Borrar una clave todavía usada rompe `flutter analyze`, y esa lección ya costó una tarea entera en el plan de P2.

- [ ] **Step 1: Encontrar las claves muertas**

Run:
```bash
grep -o '^  "[a-zA-Z][a-zA-Z0-9]*":' lib/l10n/app_en.arb | tr -d ' ":' | sort -u | while read -r k; do
  grep -rq "t\.$k\b" lib/ --include='*.dart' || echo "MUERTA: $k"
done
```

Se esperan al menos: `cuentaNickname`, `errorNicknameLargo`, `errorNicknameEnUso`, `errorNicknameNoExiste`.

**Comprobar una a una las demás que salgan.** El `grep` busca `t.<clave>`, así que no ve las que se usen por otra vía; una clave puede aparecer en la lista y estar viva. Borrar solo tras verlo con los propios ojos.

- [ ] **Step 2: Borrar las confirmadas**

Quitar de `app_en.arb` la clave **y su bloque `@`**; de `app_es.arb` solo la clave.

- [ ] **Step 3: Regenerar, analizar y probar**

Run: `flutter gen-l10n && flutter analyze && flutter test`
Expected: `No issues found!` y verde, con `test/arb_paridad_test.dart` confirmando que los dos ficheros tienen el mismo conjunto de claves.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/ && git commit -m "Se van los textos del apodo, que ya no nombra a nadie"
```

---

### Task 11: Reescribir `scripts/probar.mjs` sobre la API REST de Auth

**Files:**
- Modify: `scripts/probar.mjs`

**Contexto:** es la **única** prueba real que tiene el backend — no hay tests unitarios de servidor. Hoy autentica con apodo y contraseña. Con Auth tiene que pedir tokens a la API REST de Firebase Auth y mandarlos como *bearer*. Se puede sin dependencias nuevas (`fetch` está en Node 20), pero es trabajo real.

La estructura de dos cuentas **se conserva**: `functions/index.js` prohíbe que una misma cuenta tenga dos plazas vivas en el mismo grupo, así que hace falta un segundo cuerpo para ejercitar "sacar a alguien antes del sorteo".

- [ ] **Step 1: Añadir el cliente de Auth REST**

Al principio del fichero, tras la constante `BASE`:

```js
// La clave web del proyecto. No es un secreto: va incrustada en el cliente
// web (ver lib/main.dart) y sirve para identificar el proyecto, no para
// autorizar nada.
const API_KEY = "AIzaSyC3rWS4cYcXpdrO2NCturmoiaoqmkzpjE8";
const IDENTITY = "https://identitytoolkit.googleapis.com/v1";

async function authRest(metodo, cuerpo) {
  const r = await fetch(`${IDENTITY}/accounts:${metodo}?key=${API_KEY}`, {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({...cuerpo, returnSecureToken: true}),
  });
  const j = await r.json();
  if (!r.ok) throw new Error(`${metodo}: ${j.error?.message || r.status}`);
  return j;
}

const registrar = (email, password) => authRest("signUp", {email, password});
const entrar = (email, password) => authRest("signInWithPassword", {email, password});
```

- [ ] **Step 2: Verificar el correo sin buzón**

La verificación es bloqueante en la app, así que el script tiene que marcarla. La API REST no deja marcar `emailVerified` sin el enlace, y el Admin SDK sí — pero el script no tiene credenciales de administrador.

**Solución: una función de servidor solo para pruebas es demasiada superficie.** En su lugar, el script se salta la verificación **pidiendo un token y comprobando que las funciones lo rechazan con `correo_sin_verificar`**, y luego marca la cuenta como verificada a mano desde la consola de Firebase (Authentication → el usuario → editar).

Escribir esto en el encabezado del script como instrucción para quien lo ejecute:

```js
// ⚠️ La verificación de correo es BLOQUEANTE y este script no tiene buzón.
// Ejecutarlo en dos pasos:
//
//   1. node scripts/probar.mjs --crear
//      Crea las dos cuentas, comprueba que sin verificar el servidor
//      responde `correo_sin_verificar`, e imprime los dos correos.
//   2. Marcarlos como verificados en la consola de Firebase
//      (Authentication → usuario → ⋮ → editar → Email verified).
//   3. node scripts/probar.mjs --seguir <correo1> <correo2>
//      Ejecuta el resto de la batería.
//
// Es más incómodo que antes y es el precio de que la verificación sea de
// verdad. La alternativa —una función de servidor que marque cuentas como
// verificadas— sería una puerta trasera permanente para ahorrar dos clics.
```

- [ ] **Step 3: Mandar el token en cada llamada**

Sustituir el helper que hace las peticiones a las funciones para que acepte un token:

```js
async function llamar(nombre, datos, idToken) {
  const headers = {"Content-Type": "application/json"};
  if (idToken) headers["Authorization"] = `Bearer ${idToken}`;
  const r = await fetch(`${BASE}/${nombre}`, {
    method: "POST",
    headers,
    body: JSON.stringify({data: datos}),
  });
  const j = await r.json();
  if (j.error) {
    const e = new Error(j.error.message);
    e.clave = j.error.details?.clave || "";
    throw e;
  }
  return j.result || {};
}
```

Y en cada caso de prueba, quitar `nickname`/`password` de los datos y pasar el token como tercer argumento.

- [ ] **Step 4: Adaptar los casos que cambian de nombre**

| Antes | Ahora |
|---|---|
| `registrarCuenta` | `registrar()` (REST) + `guardarPerfil` |
| `iniciarSesionCuenta` | `entrar()` (REST) + `misGrupos` |
| `cambiarPin` con `password` | `cambiarPin` con solo `pinNuevo`, tras un `entrar()` fresco que renueva `auth_time` |

- [ ] **Step 5: Añadir el comprobador de fallos esperados y los casos nuevos**

El script **ya tiene** `ok(titulo, condicion, detalle)` y `debeFallar(titulo, claveEsperada, fn)`. No hay que escribirlos: se reutilizan tal cual. Estos son los tres casos que antes no podían existir:

```js
// 1. Sin token: TODAS las funciones tienen que rechazar. Es la comprobación
//    más importante del fichero — si esta pasa a verde por accidente, la
//    app entera está abierta.
await debeFallar("sin token no se autoriza", "sesion_invalida",
    () => llamar("misGrupos", {}, null));

// 2. Con token válido pero correo sin verificar: rechaza con su clave.
await debeFallar("sin verificar el correo no se entra", "correo_sin_verificar",
    () => llamar("misGrupos", {}, tokenSinVerificar));

// 3. Con token verificado, cambiarPin funciona si la sesión es RECIENTE.
await llamar("cambiarPin", {pinNuevo: PIN_NUEVO}, tokenRecien);
ok("cambiar el PIN con sesión reciente", true);
```

**El caso que falta y por qué:** comprobar que `cambiarPin` **rechaza** una sesión de más de `MAX_EDAD_SESION_S` exigiría esperar cinco minutos reales, y un `sleep` de cinco minutos dentro de una batería que por lo demás tarda segundos es peor prueba que ninguna — nadie la ejecutaría. Se verifica a mano en la Tarea 12 Step 7 punto 6. **Anotarlo como comentario en el script**, no dejarlo implícito: una laguna sin escribir se lee como cobertura.

- [ ] **Step 6: Ejecutar el paso 1 (requiere las funciones desplegadas)**

Este paso **no se puede completar hasta la Tarea 12**, que despliega. Anotarlo en el informe: la tarea se cierra con el script escrito y revisado, y su ejecución real es parte de la Tarea 12.

- [ ] **Step 7: Commit**

```bash
git add scripts/probar.mjs
git commit -m "La única prueba real del backend habla el idioma de Auth"
```

---

### Task 12: Desplegar, vaciar y verificar en dispositivo

**Files:** ninguno de código. Es la tarea de puesta en producción.

**Contexto:** hasta aquí no se ha desplegado nada. Este es el punto de no retorno: se borran las colecciones, así que todas las cuentas y grupos de prueba anteriores dejan de existir.

- [ ] **Step 1: Comprobar que el proveedor está habilitado**

En la consola de Firebase (`santa-secreto-860c3`), confirmar los tres puntos de la Tarea 1 Step 8:
1. Authentication → Sign-in method → **Email/Password** habilitado, **sin** "Email link".
2. Authentication → Settings → **Email enumeration protection** activada.
3. El dominio de Hosting entre los autorizados.

**Si falta cualquiera, parar aquí.** Desplegar sin el proveedor habilitado deja la app inutilizable.

- [ ] **Step 2: Verificación final antes de desplegar**

Run:
```bash
flutter analyze && flutter test && cd functions && node --check index.js && cd ..
```
Expected: todo limpio y verde.

- [ ] **Step 3: Desplegar reglas y funciones**

Run:
```bash
firebase deploy --only firestore:rules
firebase deploy --only functions
```

`firebase deploy --only functions` puede quedar bloqueado por el clasificador de permisos del entorno. Si pasa, **pedirle a la persona que lo ejecute ella** y esperar su confirmación; no buscar una forma de rodearlo.

- [ ] **Step 4: Vaciar las colecciones**

En la consola de Firebase → Firestore → borrar las colecciones **`usuarios`** y **`grupos`** enteras. Y en Authentication → borrar los usuarios que hubiera.

No hay migración a propósito: no hay datos reales, solo grupos de prueba, y es el momento más barato en que esto se podía hacer.

- [ ] **Step 5: Ejecutar la prueba de integración**

Run: `node scripts/probar.mjs --crear`
Luego marcar los dos correos como verificados en la consola.
Luego: `node scripts/probar.mjs --seguir <correo1> <correo2>`

Expected: todos los casos en verde. **Si alguno falla, arreglarlo antes de seguir** — es la única cobertura automática que tiene el servidor.

- [ ] **Step 6: Desplegar el cliente**

Run:
```bash
flutter build web --release
firebase deploy --only hosting
```

- [ ] **Step 7: Verificar en dispositivo**

Cada punto se comprueba de verdad, no se supone:

1. Crear una cuenta con un correo real. **Comprobar que NO se entra sin verificar.**
2. Verificar desde el buzón, volver, pulsar "ya lo confirmé" y comprobar que entra.
3. Cerrar sesión, entrar de nuevo: debe pasar directo, sin pedir verificación.
4. Pulsar "he olvidado mi contraseña" con un correo **que no existe**: comprobar que sale el mismo mensaje que con uno que sí.
5. Recuperar de verdad la contraseña de la cuenta creada y entrar con la nueva.
6. Cambiar el PIN: comprobar que **pide la contraseña** y que con una equivocada falla.
7. Crear un grupo, apuntarse, invitar desde otro navegador con una segunda cuenta, sortear y revelar el amigo secreto con el PIN.
8. **El camino del QR completo con una cuenta nueva**: escanear, registrarse, ir al buzón, volver — y comprobar que la invitación **sigue ahí** y lleva al grupo correcto. Es el caso que más sufre con la verificación bloqueante y el que hay que ver funcionando con los propios ojos.

- [ ] **Step 8: Escribir la bitácora**

Crear `bitacora/2026-08-09-auth.md` con lo que se hizo, lo que se decidió por el camino y lo que quedó pendiente. Commitear.

- [ ] **Step 9: Cerrar la rama**

Usar la skill `superpowers:finishing-a-development-branch`.

---

## Fuera de alcance

- **Google y cualquier otro proveedor.** Decisión consciente del spec.
- **App Check y limitación de peticiones** (hallazgo A4 de la auditoría). Sigue abierto.
- **Los cuatro arreglos baratos de seguridad** (entrar tras el sorteo, sorteo repetible, contador del PIN sin transacción, `Math.random()`). **Hechos el 2026-08-09**, antes de esta rama, con sus casos en `probar.mjs`.
- **El idioma en la cuenta** — tiene su propio spec (`2026-08-09-idioma-en-la-cuenta-design.md`) y su propia rama.
- **Enseñar el nombre real al organizador.** El dato queda disponible; exponerlo no es parte de esto.
- **P3 (chat sin máscaras), P4 (reemplazar participante), P1 (invitaciones QR).**
