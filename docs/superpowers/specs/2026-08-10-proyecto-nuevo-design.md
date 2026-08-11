# Diseño — Mudar SecretGift a un proyecto Firebase nuevo

**Fecha:** 2026-08-10
**Estado:** aprobado, pendiente de plan de implementación
**Proyecto destino:** `secretgift-app` — número 997384680563, creado el 2026-08-10
**Proyecto origen:** `santa-secreto-860c3`

## Qué se cambia y por qué

El identificador de un proyecto Firebase **no se puede cambiar nunca**. El
actual, `santa-secreto-860c3`, aparece en sitios que ve la gente:

| Dónde | Quién lo ve |
|---|---|
| El enlace del correo de verificación | Cualquiera que se registre |
| La URL de cada avatar | Está en el código de la página |
| El enlace de invitación que se comparte por QR | Quien recibe una invitación |
| Las llamadas a las funciones | Con herramientas de desarrollo |

**Lo que lo convierte en un problema y no en una fealdad:** el remitente del
correo es `noreply@secretgift.app` y el enlace lleva a
`santa-secreto-860c3.firebaseapp.com`. Remitente de un sitio, enlace a otro
— exactamente el patrón que a la gente le enseñan a desconfiar. Y la
verificación de correo es **bloqueante**: si no pinchan ese enlace, no entra
nadie.

Se intentó personalizar la URL de acción en la consola de Firebase y en
Google Cloud. Falla al guardar con un error genérico. Con un proyecto cuyo
identificador ya dice `secretgift`, **no hace falta personalizar nada**: el
valor por defecto ya es coherente con la marca.

**Se descartó generar el enlace con el Admin SDK** y mandarlo por un
proveedor propio. Ese camino solo arregla el correo —los avatares y las
funciones seguirían con el nombre viejo—, y a cambio deja tres piezas nuevas
que mantener para siempre: una función que genera y envía, un proveedor de
correo, y una pantalla propia que reciba el `oobCode`. Cambia un problema de
configuración por complejidad permanente. Sigue siendo la vía correcta el
día que se quieran correos con diseño propio; hoy no es el problema.

**No hay datos que migrar.** Las colecciones se vaciaron el 2026-08-09 y no
hay ninguna cuenta real. Es el momento más barato en que esto se podrá
hacer, y por bastante margen.

## El principio que ordena todo: el dominio se mueve al final

Se construye el proyecto nuevo entero y se prueba en su URL provisional
(`secretgift-app.web.app`). **Solo cuando funciona** se le quita
`secretgift.app` al proyecto viejo.

Así la app sigue viva mientras se trabaja, y si algo sale mal el proyecto
viejo está intacto y no se ha perdido nada.

**La excepción es el dominio del correo, y va primero.** Ver abajo.

## El dominio del correo va al principio, no al final

La verificación del dominio de correo **tardó cerca de un día** cuando se
montó en el proyecto viejo. Y **es probable que no se pueda tener en dos
proyectos a la vez**: dos de sus cinco registros son CNAME con nombre fijo
(`firebase1._domainkey` y `firebase2._domainkey`), y un CNAME solo puede
apuntar a un sitio.

Así que no se puede preparar por adelantado: hay que soltarlo del viejo y
montarlo en el nuevo, y ahí empieza el reloj.

**Por eso se hace lo primero**, en cuanto el proyecto exista, para que las
horas corran mientras se hace el código, el despliegue y las pruebas.

**La consecuencia, asumida:** durante hasta un día los correos saldrán de
`noreply@secretgift-app.firebaseapp.com` en vez de `noreply@secretgift.app`.
Hoy eso no le cuesta nada a nadie porque no hay usuarios. Dentro de un mes
sería un problema de verdad — es el mismo argumento que hace barata la
migración entera.

**Lo de los CNAME es una deducción, no algo comprobado.** Se sabrá al añadir
el dominio en el proyecto nuevo y ver qué registros pide. Si resultara que
usa nombres distintos, se podrían tener los dos a la vez y no habría ventana.

## Qué se toca en el código

**Siete sitios**, todos mecánicos:

| Fichero | Qué cambia |
|---|---|
| `.firebaserc` | El proyecto por defecto |
| `lib/main.dart` | `FirebaseOptions` de web: clave, dominio, proyecto, bucket, remitente y appId |
| `lib/funciones.dart` | `_baseUrl` de las Cloud Functions |
| `functions/index.js` | La constante `BUCKET` |
| `scripts/probar.mjs` | `BASE`, `API_KEY`, `FIRESTORE` y `BUCKET` |
| `android/app/google-services.json` | Se descarga del proyecto nuevo |
| `lib/pantalla_registro.dart` | `_urlUnirse` — ver abajo |

**Dos cosas que NO se tocan, y un buscar-y-reemplazar las destruiría:**

- **`lib/ocasion.dart`** usa `'santa_secreto'` como identificador de la
  ocasión «amigo secreto». Es el tipo de juego, **está guardado dentro de
  los documentos de cada grupo**, y cambiarlo rompería los datos.
- **`pubspec.yaml`** se llama `santa_secreto`. Es el nombre del paquete
  Dart: no lo ve ningún usuario jamás, y cambiarlo obliga a tocar el
  `import` de los diez ficheros de test sin ganar nada.

### El enlace de invitación, que ya estaba mal

`lib/pantalla_registro.dart` construye el enlace que se comparte por QR
apuntando a `https://santa-secreto-860c3.web.app/?codigo=...`.

**Eso lo ve quien recibe una invitación**, y es un fallo que existe hoy,
independiente de esta migración. Pasa a apuntar a **`https://secretgift.app`**,
que es el dominio de la marca.

**Ojo con el orden:** mientras se prueba en la fase 3, `secretgift.app`
todavía sirve el proyecto VIEJO. Así que el enlace de invitación no se puede
probar de verdad hasta que el dominio se haya movido (fase 4).

### El paquete de Android

`com.example.santa_secreto` pasa a **`app.secretgift`**. `com.example` es el
valor de ejemplo que pone Flutter y **Google Play no lo acepta**, así que
había que cambiarlo igualmente antes de publicar.

No es cambiar una cadena: toca la configuración de compilación, el
manifiesto y la estructura de carpetas del código nativo. Es mecánico, pero
hay que hacerlo con cuidado.

## Las fases

**1 — Crear y arrancar el reloj del correo.** Proyecto con plan Blaze,
Firestore, Storage y Auth con correo y contraseña. App web y app Android
registradas. **Y el dominio de correo montado inmediatamente**, para que
empiece a verificarse.

**2 — Apuntar el código al proyecto nuevo.** Los siete sitios de arriba.

**3 — Desplegar y probar en la URL provisional.** Reglas, funciones y app en
`secretgift-app.web.app`. Los 37 casos de `probar.mjs` y la prueba a mano
en el navegador. **Aquí se decide si se sigue**: si algo falla, el proyecto
viejo está intacto.

**4 — Mover el dominio del hosting.** Quitárselo al viejo, añadirlo al
nuevo, cambiar el registro `hosting-site=` y verificar. **Es la única fase
con la app fuera de servicio**, y dura lo que tarde la propagación — que con
el TTL de cinco minutos que tienen esos registros es poco.

**5 — Cerrar.** Comprobar todo de punta a punta, bitácora, y **el proyecto
viejo se queda apagado, no se borra**, por si hay que volver.

## Lo que hay que rehacer en la consola

Toda la configuración que costó la sesión del 2026-08-09:

- Habilitar **Email/Password**, sin «Email link»
- **Política de contraseñas**: exigir aplicación, mínimo 8, con mayúscula,
  minúscula, número y símbolo. **Sin** «forzar actualización durante el
  acceso» — la app no tiene esa pantalla y quien cayera ahí se quedaría
  atascado.
- Comprobar que la **protección de enumeración de correos** está activa (es
  el valor por defecto)
- **Dominios autorizados**: añadir `secretgift.app`
- **Dominio de correo personalizado**, con sus cinco registros DNS
- Plantillas de correo: asunto y mensaje **en español**, y nombre del
  remitente

## Verificación

- `flutter analyze` sin advertencias y todos los tests en verde.
- **Los 37 casos de `scripts/probar.mjs`** contra las funciones del proyecto
  nuevo, en sus dos pasos con la verificación de correo real.
- **Sondas contra Identity Toolkit del proyecto nuevo**, como se hizo el
  2026-08-09: que recuperar la contraseña de un correo inexistente devuelva
  200 fingiendo éxito, que entrar devuelva `INVALID_LOGIN_CREDENTIALS`, y
  que una contraseña floja se rechace con
  `PASSWORD_DOES_NOT_MEET_REQUIREMENTS`. Confirman que la configuración de
  consola quedó como en el proyecto viejo.
- **En dispositivo:** crear cuenta, verificar desde el buzón, **volver sin
  recargar** y entrar. Y comprobar que **el enlace del correo ya no nombra
  al proyecto viejo**, que es el motivo de toda esta migración.
- **El enlace de invitación por QR**, después de mover el dominio.

## Fuera de alcance

- **Borrar el proyecto viejo.** Se queda apagado un tiempo.
- **Renombrar el paquete Dart** (`pubspec.yaml`).
- **Tocar `lib/ocasion.dart`.**
- **Correos con diseño propio** vía Admin SDK y proveedor externo. Es la vía
  correcta para eso, pero es otro trabajo.
- **El despliegue automático desde GitHub**, que tiene su propia decisión ya
  aprobada y se hará después.
