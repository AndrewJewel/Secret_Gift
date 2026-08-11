# Mudanza a `secretgift-app` — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mover SecretGift del proyecto Firebase `santa-secreto-860c3` al nuevo `secretgift-app`, para que el nombre viejo deje de salir en el enlace del correo de verificación, en las URLs de los avatares y en el enlace de invitación.

**Architecture:** El proyecto nuevo se construye y se prueba entero en su URL provisional antes de tocar el dominio. El dominio del **correo** se mueve al principio, porque tarda casi un día en verificarse; el del **hosting** al final, porque es el que deja la app inaccesible.

**Tech Stack:** Flutter 3.38.10 / Dart 3.10.9, Cloud Functions v2 (Node 22, `firebase-admin` 14 modular), Firestore, Storage, Firebase Auth.

**Spec:** `docs/superpowers/specs/2026-08-10-proyecto-nuevo-design.md`

**Rama prevista:** propia, a partir de `main`.

## Quién hace qué

Buena parte de esto **son clics en una consola y registros de DNS**, y no los puede hacer un agente. Cada tarea lleva una etiqueta:

- 👤 **HUMANO** — consola de Firebase, Google Cloud, o Cloudflare.
- 🤖 **AGENTE** — código, despliegue y pruebas.

Las tareas 🤖 no pueden empezar hasta que sus 👤 previas estén hechas.

## Datos del proyecto nuevo

| Campo | Valor |
|---|---|
| ID | `secretgift-app` |
| Número | `997384680563` |
| `apiKey` (web) | `AIzaSyD9F2V6ByG7p9yMoDOpa_p-v97_Ik5jZcI` |
| `authDomain` | `secretgift-app.firebaseapp.com` |
| `storageBucket` | `secretgift-app.firebasestorage.app` |
| `appId` (web) | `1:997384680563:web:de772ec4c11202e0f0a606` |
| Paquete Android | `app.secretgift` |

La `apiKey` **no es un secreto**: va incrustada en el cliente web e identifica el proyecto, no autoriza nada.

## Global Constraints

- **Dart 3.10.9 / Flutter 3.38.10.** Nada de sintaxis de Dart 3.12.
- **`flutter analyze` sin advertencias** y **`flutter test` en verde (36)** al cerrar cada tarea de código.
- **`firebase-admin` v14 es modular.** `admin.firestore()` y `admin.storage()` no existen; se importan de `firebase-admin/firestore` y `firebase-admin/storage`.
- **Los ficheros generados de l10n están trackeados.** Este plan no toca ARB, así que no debería hacer falta `flutter gen-l10n`.
- **NO SE TOCA `lib/ocasion.dart`.** Su `'santa_secreto'` es el identificador de la ocasión «amigo secreto» y está guardado dentro de los documentos de cada grupo. Cambiarlo rompe los datos.
- **NO SE TOCA `pubspec.yaml`.** El paquete Dart sigue llamándose `santa_secreto`; no lo ve ningún usuario y renombrarlo obliga a tocar el `import` de diez ficheros de test.
- **Nada de buscar-y-reemplazar global de `santa-secreto`.** Cada sitio se cambia a mano por lo anterior.
- **El proyecto viejo NO se borra.**
- Mensajes de commit en español, explicando el porqué.

---

### Task 1 👤 HUMANO — Arrancar el proyecto y el reloj del correo

Nada de esto lo puede hacer un agente. **La parte del correo es la más urgente**: tarda casi un día en verificarse y bloquea el cierre de la mudanza.

- [ ] **Step 1: Enlazar la facturación (plan Blaze)**

Firebase → `secretgift-app` → ⚙️ → Uso y facturación → Detalles y configuración → **Modificar plan** → Blaze.

Sin esto **no se pueden desplegar las Cloud Functions**, y la Tarea 5 se queda bloqueada.

- [ ] **Step 2: Crear Firestore y Storage**

- Firestore Database → Crear base de datos → **producción** → región `us-central` (la misma que las funciones, para no pagar tráfico entre regiones).
- Storage → Empezar → misma región.

- [ ] **Step 3: Habilitar el acceso con correo y contraseña**

Authentication → Sign-in method → **Email/Password: habilitado**. **NO** habilitar «Email link (passwordless)».

- [ ] **Step 4: Poner la política de contraseñas**

Authentication → Settings → Política de contraseñas:

| Ajuste | Valor |
|---|---|
| Modo de aplicación | **Exigir aplicación** |
| Mayúscula, minúscula, especial, numérico | Las cuatro marcadas |
| Forzar la actualización durante el acceso | **Sin marcar** |
| Longitud mínima | **8** |

La casilla de forzar actualización **debe quedar sin marcar**: la app no tiene esa pantalla y quien cayera ahí se quedaría atascado sin salida.

- [ ] **Step 5: Registrar la app Android**

⚙️ → General → Agregar app → Android. Nombre del paquete: **`app.secretgift`**.

Descargar el `google-services.json` que genera y **guardarlo en el escritorio o donde sea cómodo**. La Tarea 4 lo necesita.

- [ ] **Step 6: Soltar el dominio de correo del proyecto VIEJO**

En `santa-secreto-860c3` → Authentication → Templates → en el aviso del dominio personalizado, **Cancelar**.

Hay que hacerlo **antes** del paso siguiente: los registros DKIM son CNAME con nombre fijo y no pueden apuntar a dos proyectos a la vez.

- [ ] **Step 7: Montar el dominio de correo en el proyecto NUEVO**

En `secretgift-app` → Authentication → Templates → **Personalizar dominio** → `secretgift.app`.

Firebase dará una lista de registros DNS. En Cloudflare, **actualizar los que ya existen** en vez de crear duplicados:

| Registro | Qué hacer |
|---|---|
| TXT `@` con `firebase=santa-secreto-860c3` | **Editarlo** al valor nuevo que dé Firebase |
| TXT `@` con `v=spf1 include:_spf.firebasemail.com ~all` | Probablemente igual; comprobar |
| CNAME `firebase1._domainkey` | **Editarlo** al destino nuevo |
| CNAME `firebase2._domainkey` | **Editarlo** al destino nuevo |
| TXT `_dmarc` | No cambia |

**Los dos CNAME en «Solo DNS» (nube gris).**

**Aquí empieza el reloj.** Puede tardar hasta un día. Mientras, los correos saldrán de `noreply@secretgift-app.firebaseapp.com`, que es lo esperado y hoy no molesta a nadie.

- [ ] **Step 8: Avisar al agente**

Decirle que los pasos 1-7 están hechos y **dónde quedó el `google-services.json`**.

---

### Task 2 🤖 AGENTE — Comprobar que el proyecto nuevo está listo

Antes de tocar una línea de código, comprobar que la Tarea 1 quedó bien. **Sale más barato descubrir aquí que falta la facturación que a mitad del despliegue.**

**Files:** ninguno. Solo comprobaciones.

- [ ] **Step 1: Comprobar que la CLI ve el proyecto**

```bash
firebase projects:list | grep secretgift-app
```
Expected: una línea con `secretgift-app` y el número `997384680563`.

- [ ] **Step 2: Comprobar que Auth acepta correo y contraseña**

```bash
K="AIzaSyD9F2V6ByG7p9yMoDOpa_p-v97_Ik5jZcI"
curl -s -X POST "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$K" \
  -H "Content-Type: application/json" \
  -d '{"email":"sonda.arranque@example.com","password":"Prueba123!","returnSecureToken":true}'
```

Expected: un JSON con `idToken` y `localId`.

Si responde `OPERATION_NOT_ALLOWED`, **el proveedor no está habilitado**: parar y volver al Step 3 de la Tarea 1.

Guardar el `idToken` que devuelva: hace falta en el paso siguiente.

- [ ] **Step 3: Comprobar que la política de contraseñas está puesta**

```bash
K="AIzaSyD9F2V6ByG7p9yMoDOpa_p-v97_Ik5jZcI"
curl -s -X POST "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$K" \
  -H "Content-Type: application/json" \
  -d '{"email":"sonda.debil@example.com","password":"abc123","returnSecureToken":true}'
```

Expected: error `PASSWORD_DOES_NOT_MEET_REQUIREMENTS`.

Si en cambio **crea la cuenta**, la política no está: parar y volver al Step 4 de la Tarea 1.

- [ ] **Step 4: Comprobar la protección de enumeración de correos**

```bash
K="AIzaSyD9F2V6ByG7p9yMoDOpa_p-v97_Ik5jZcI"
curl -s -X POST "https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=$K" \
  -H "Content-Type: application/json" \
  -d '{"requestType":"PASSWORD_RESET","email":"no.existe.jamas@example.com"}'
```

Expected: **200 con un cuerpo que finge éxito**, sin `EMAIL_NOT_FOUND`.

Si devolviera `EMAIL_NOT_FOUND`, la protección está apagada: anotarlo y avisar al humano (Authentication → Settings → «Acciones del usuario»).

- [ ] **Step 5: Borrar las cuentas de sonda**

Con el `idToken` del Step 2:

```bash
K="AIzaSyD9F2V6ByG7p9yMoDOpa_p-v97_Ik5jZcI"
curl -s -X POST "https://identitytoolkit.googleapis.com/v1/accounts:delete?key=$K" \
  -H "Content-Type: application/json" -d '{"idToken":"<EL_TOKEN>"}'
```

No dejar basura en el proyecto nuevo.

- [ ] **Step 6: Anotar el resultado**

Escribir en el informe qué comprobación salió bien y cuál no. **Si alguna falló, no seguir a la Tarea 3.**

---

### Task 3 🤖 AGENTE — Apuntar el código al proyecto nuevo

**Files:**
- Modify: `.firebaserc`
- Modify: `lib/main.dart:19-25`
- Modify: `lib/funciones.dart:14`
- Modify: `lib/pantalla_registro.dart:395`
- Modify: `functions/index.js:43`
- Modify: `scripts/probar.mjs:55,60,81,83`

**Interfaces:**
- Produces: todo el código apuntando a `secretgift-app`. Las tareas 5 y 6 despliegan y prueban contra él.

- [ ] **Step 1: `.firebaserc`**

Sustituir el contenido entero por:

```json
{
  "projects": {
    "default": "secretgift-app"
  }
}
```

- [ ] **Step 2: `lib/main.dart`**

Sustituir el bloque `FirebaseOptions` por:

```dart
      options: const FirebaseOptions(
        apiKey: "AIzaSyD9F2V6ByG7p9yMoDOpa_p-v97_Ik5jZcI",
        authDomain: "secretgift-app.firebaseapp.com",
        projectId: "secretgift-app",
        storageBucket: "secretgift-app.firebasestorage.app",
        messagingSenderId: "997384680563",
        appId: "1:997384680563:web:de772ec4c11202e0f0a606",
      ),
```

Quitar el comentario `// <--- ¡Listo!` que hay al final del `appId`, que no dice nada.

- [ ] **Step 3: `lib/funciones.dart`**

```dart
const _baseUrl = 'https://us-central1-secretgift-app.cloudfunctions.net';
```

- [ ] **Step 4: `lib/pantalla_registro.dart` — el enlace de invitación**

Sustituir:
```dart
  String get _urlUnirse => 'https://santa-secreto-860c3.web.app/?codigo=${widget.codigo}';
```
por:
```dart
  // El dominio de la marca, no el que Firebase da por defecto: este enlace
  // es lo que recibe quien es invitado a un grupo, y es lo primero que ve
  // de la app. Apuntaba al dominio del proyecto viejo desde siempre.
  String get _urlUnirse => 'https://secretgift.app/?codigo=${widget.codigo}';
```

**Este enlace no se podrá probar de verdad hasta la Tarea 7**, cuando el dominio se haya movido: hasta entonces `secretgift.app` sigue sirviendo el proyecto viejo.

- [ ] **Step 5: `functions/index.js`**

```js
const BUCKET = "secretgift-app.firebasestorage.app";
```

- [ ] **Step 6: `scripts/probar.mjs` — las cuatro constantes**

```js
const BASE = "https://us-central1-secretgift-app.cloudfunctions.net";
```
```js
const API_KEY = "AIzaSyD9F2V6ByG7p9yMoDOpa_p-v97_Ik5jZcI";
```
```js
const BUCKET = "secretgift-app.firebasestorage.app";
```
```js
const FIRESTORE =
  "https://firestore.googleapis.com/v1/projects/secretgift-app/databases/(default)/documents";
```

- [ ] **Step 7: Comprobar que no queda nada del proyecto viejo donde no debe**

```bash
grep -rn "santa-secreto-860c3" --include="*.dart" --include="*.js" --include="*.mjs" --include="*.json" . 2>/dev/null | grep -v node_modules | grep -v "/build/" | grep -v ".dart_tool" | grep -v package-lock
```

Expected: **solo `android/app/google-services.json`**, que se cambia en la Tarea 4.

Si aparece `lib/ocasion.dart`, es un falso positivo distinto: ahí pone `santa_secreto` con guion bajo, y **no se toca**.

- [ ] **Step 8: Verificar**

```bash
flutter analyze && flutter test && cd functions && node --check index.js && cd ..
```
Expected: `No issues found!`, 36 tests en verde, y sin salida del `node --check`.

- [ ] **Step 9: Commit**

```bash
git add .firebaserc lib/ functions/index.js scripts/probar.mjs
git commit -m "Apunta el código al proyecto secretgift-app"
```

Con un cuerpo que explique el porqué: el identificador del proyecto viejo salía en el enlace del correo y en las URLs de los avatares, y no se podía cambiar.

---

### Task 4 🤖 AGENTE — Renombrar el paquete de Android

**Files:**
- Modify: `android/app/build.gradle.kts:9,23`
- Move: `android/app/src/main/kotlin/com/example/santa_secreto/MainActivity.kt` → `android/app/src/main/kotlin/app/secretgift/MainActivity.kt`
- Replace: `android/app/google-services.json`

**Contexto:** `com.example` es el valor de ejemplo que pone Flutter y **Google Play no lo acepta**, así que había que cambiarlo igualmente antes de publicar. Hoy la app se usa por web y la de Android no está publicada en ningún sitio, así que es gratis.

- [ ] **Step 1: `android/app/build.gradle.kts`**

Cambiar las dos líneas:

```kotlin
    namespace = "app.secretgift"
```
```kotlin
        applicationId = "app.secretgift"
```

- [ ] **Step 2: Mover el fichero de la actividad**

```bash
mkdir -p android/app/src/main/kotlin/app/secretgift
git mv android/app/src/main/kotlin/com/example/santa_secreto/MainActivity.kt \
       android/app/src/main/kotlin/app/secretgift/MainActivity.kt
```

Y borrar los directorios que queden vacíos bajo `com/`.

- [ ] **Step 3: Cambiar el paquete dentro del fichero**

La primera línea de `MainActivity.kt` pasa a:

```kotlin
package app.secretgift
```

- [ ] **Step 4: Poner el `google-services.json` nuevo**

Copiar encima de `android/app/google-services.json` el fichero que el humano descargó en el Step 5 de la Tarea 1.

- [ ] **Step 5: Comprobar que el fichero nuevo es el correcto**

```bash
grep -E "project_id|package_name|storage_bucket" android/app/google-services.json
```

Expected: `secretgift-app`, `app.secretgift` y `secretgift-app.firebasestorage.app`.

Si dice `com.example.santa_secreto`, es que el humano registró la app Android con el paquete viejo: **parar y avisar**, porque el paquete no se puede cambiar después de registrado — habría que registrar otra app.

- [ ] **Step 6: Comprobar que no queda rastro**

```bash
grep -rn "com.example.santa_secreto" android/ 2>/dev/null
```
Expected: sin resultados.

- [ ] **Step 7: Verificar**

```bash
flutter analyze && flutter test
```
Expected: limpio y 36 en verde.

**No hace falta compilar el APK**: la app se usa por web y compilar Android alargaría mucho esta tarea. Si se quisiera comprobar, sería `flutter build apk --debug`.

- [ ] **Step 8: Commit**

```bash
git add -A android/
git commit -m "El paquete de Android deja de ser el de ejemplo de Flutter"
```

---

### Task 5 🤖 AGENTE — Desplegar en el proyecto nuevo

**Files:** ninguno. Es despliegue.

**Contexto:** el proyecto nuevo está vacío. Esto sube reglas, funciones y la app a `secretgift-app.web.app`. **El proyecto viejo sigue intacto y sirviendo `secretgift.app`.**

- [ ] **Step 1: Confirmar a qué proyecto apunta la CLI**

```bash
firebase use
```
Expected: `secretgift-app`. Si no, `firebase use secretgift-app`.

- [ ] **Step 2: Desplegar reglas**

```bash
firebase deploy --only firestore:rules,storage:rules
```
Expected: `Deploy complete!`

- [ ] **Step 3: Desplegar funciones**

```bash
firebase deploy --only functions
```
Expected: las quince creadas. Es la primera vez, así que serán `create` y no `update`, y tardará más de lo habitual.

Si falla con que hace falta facturación, **parar**: el Step 1 de la Tarea 1 no está hecho.

- [ ] **Step 4: Compilar y desplegar la app**

```bash
flutter build web --release && firebase deploy --only hosting
```

**Si en algún momento algo se comporta raro, `flutter clean` antes de compilar.** Un registro de plugins caducado dejó la app inutilizable el 2026-08-10 con `analyze` limpio y los tests en verde; es un fallo que ninguna prueba ve.

- [ ] **Step 5: Comprobar que responde**

```bash
curl -s -o /dev/null -w "%{http_code}\n" https://secretgift-app.web.app
```
Expected: `200`.

- [ ] **Step 6: Anotar en el informe** la URL provisional, que la Tarea 6 necesita.

---

### Task 6 🤖 AGENTE + 👤 HUMANO — Probar el proyecto nuevo de verdad

**Aquí se decide si la mudanza sigue.** Si algo falla, el proyecto viejo está intacto y no se ha perdido nada.

- [ ] **Step 1: 👤 Añadir el dominio de la app a los dominios autorizados**

Authentication → Settings → Dominios autorizados → añadir **`secretgift.app`**.

Hace falta desde ya aunque el dominio todavía sirva el proyecto viejo: sin esto, cuando se mueva en la Tarea 7, Auth se negará a funcionar. Fue justo lo que rompió la app el 2026-08-10.

- [ ] **Step 2: 🤖 Comprobar que quedó añadido**

```bash
curl -s "https://identitytoolkit.googleapis.com/v1/projects?key=AIzaSyD9F2V6ByG7p9yMoDOpa_p-v97_Ik5jZcI"
```
Expected: `secretgift.app` dentro de `authorizedDomains`.

- [ ] **Step 3: 🤖 Primer tramo de la batería**

```bash
node scripts/probar.mjs --crear --dominio <correo real del humano>
```
Expected: 3 casos en verde, y dos correos enviados.

- [ ] **Step 4: 👤 Pinchar los dos enlaces del buzón**

Mirar también en spam. **Y fijarse en el remitente**: si el dominio de correo aún no ha terminado de verificarse, dirá `noreply@secretgift-app.firebaseapp.com`, y es lo esperado.

- [ ] **Step 5: 🤖 Segundo tramo de la batería**

```bash
node scripts/probar.mjs --seguir <correo1> <correo2>
```
Expected: **37/37 en verde**.

- [ ] **Step 6: 👤 Probar a mano en `secretgift-app.web.app`**

1. Crear una cuenta
2. Ir al buzón, pinchar el enlace
3. **Volver a la pestaña sin recargarla** y pulsar «Ya lo confirmé»
4. Crear un grupo, apuntarse, y revelar el amigo secreto con el PIN

El paso 3 es el que importa: es donde vivía el peor fallo de la migración anterior, y ninguna prueba automática lo cubre.

- [ ] **Step 7: 👤 Mirar el enlace del correo**

Que diga **`secretgift-app.firebaseapp.com`** y ya no `santa-secreto-860c3`. **Ese es el motivo de toda esta mudanza**, así que conviene verlo con los propios ojos.

---

### Task 7 👤 HUMANO + 🤖 AGENTE — Mover el dominio de la app

**La única fase con la app fuera de servicio.** No empezar hasta que la Tarea 6 esté toda en verde.

- [ ] **Step 1: 👤 Quitarle el dominio al proyecto viejo**

`santa-secreto-860c3` → Hosting → en `secretgift.app` → **Eliminar dominio**.

- [ ] **Step 2: 👤 Añadirlo al proyecto nuevo**

`secretgift-app` → Hosting → Agregar dominio personalizado → `secretgift.app`.

Dará un registro `A` (probablemente el mismo `199.36.158.100`) y un `TXT` con `hosting-site=secretgift-app`.

- [ ] **Step 3: 👤 Actualizar el TXT en Cloudflare**

**Editar** el TXT `@` que dice `hosting-site=santa-secreto-860c3` y ponerle el valor nuevo. No crear otro.

El registro `A` seguramente no cambia. **Comprobar que sigue en «Solo DNS», nube gris**: con el proxy activado Firebase no puede verificar, y eso ya costó una vuelta el 2026-08-10.

- [ ] **Step 4: 🤖 Comprobar la propagación antes de verificar**

```bash
nslookup -type=TXT secretgift.app 8.8.8.8
nslookup secretgift.app 8.8.8.8
```
Expected: el TXT con `hosting-site=secretgift-app`, y la `A` en `199.36.158.100` (no en IPs de Cloudflare, que empiezan por `104.` o `172.67.`).

- [ ] **Step 5: 👤 Pulsar «Verificar»** en Firebase, ya sabiendo que el DNS está bien.

- [ ] **Step 6: 🤖 Comprobar que el dominio sirve la app nueva**

```bash
curl -s -o /dev/null -w "%{http_code}\n" -L https://secretgift.app
```
Expected: `200`. El certificado puede tardar un rato en emitirse; si da error de TLS, esperar y repetir.

- [ ] **Step 7: 👤 Probar el enlace de invitación**

En la app, entrar a un grupo y compartir la invitación. El enlace debe decir **`https://secretgift.app/?codigo=...`**, y al abrirlo tiene que llevar al grupo.

Es lo que arregló el Step 4 de la Tarea 3 y **no se pudo probar hasta ahora**.

---

### Task 8 🤖 AGENTE — Cerrar

- [ ] **Step 1: Verificación final**

```bash
flutter analyze && flutter test && cd functions && node --check index.js && cd ..
```

- [ ] **Step 2: Comprobar que el correo ya sale del dominio propio**

Si el dominio de correo terminó de verificarse (empezó en la Tarea 1 y puede tardar un día), mandar uno de prueba y confirmar con el humano que el remitente es `noreply@secretgift.app`.

Si todavía no, **no bloquear el cierre**: anotarlo como pendiente.

- [ ] **Step 3: Escribir la bitácora**

`bitacora/2026-08-10-proyecto-nuevo.md`, con lo que costó y lo que enseñó — no el resumen de los pasos, que ya está en los commits.

- [ ] **Step 4: Commit y cierre de rama**

Usar la skill `superpowers:finishing-a-development-branch`.

- [ ] **Step 5: Anotar lo que queda pendiente**

- El proyecto viejo `santa-secreto-860c3` **sigue existiendo y no se borra**. Decidir más adelante.
- Rehacer las **plantillas de correo en español** en el proyecto nuevo, que se quedaron en inglés.
- **Quitar Resend** del proyecto viejo si seguía configurado, y borrar sus tres registros DNS sueltos (`send.secretgift.app` MX y TXT, y `resend._domainkey`).

## Fuera de alcance

- **Borrar el proyecto viejo.**
- **Renombrar el paquete Dart** de `pubspec.yaml`.
- **Tocar `lib/ocasion.dart`.**
- **Compilar y publicar la app de Android.**
- **El despliegue automático desde GitHub**, que tiene su propio diseño aprobado y va después.
