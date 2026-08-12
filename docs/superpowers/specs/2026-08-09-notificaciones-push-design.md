# Diseño — Notificaciones push (FCM)

**Fecha:** 2026-08-09
**Estado:** aprobado. **Revisado el 2026-08-12** antes de escribir el plan:
tres correcciones técnicas por cosas que cambiaron después (API modular de
`firebase-admin`, proyecto nuevo, y `recibe_de` que da una plaza y no un
uid) y un cambio de alcance decidido por el humano (el permiso se pide al
crear la cuenta, tras una pantalla propia, y sirve para tres avisos en vez
de uno). Los cambios van marcados en su sitio.
**Rama prevista:** propia, **después** de Firebase Auth y **después** de
reemplazar participante (`2026-08-09-reemplazar-participante-design.md`),
que es su primer y único cliente.

## Qué se construye y por qué

Cuando a alguien le reemplazan su amigo secreto, quien le regalaba tiene
guardado el nombre y los deseos de una persona que ya no está — y puede
haber comprado el regalo. Necesita enterarse.

**Y no puede enterarse por el camino obvio.** Los documentos públicos de
participantes los lee cualquiera que tenga el código del grupo. Marcar ahí
«tu amigo cambió» revelaría el par: la plaza de Beatriz pasa a llamarse
Carlos, se enciende una marca en la plaza de Ana, y cualquiera cruza las dos
cosas y deduce que **Ana le regala a Carlos**. Es justo lo que el juego
existe para esconder.

El aviso tiene que viajar por un canal que solo lea su destinatario. Push
es ese canal.

## Por qué push y no un aviso dentro de la app

Se consideró un aviso en vivo dentro de la app, escuchando `usuarios/{uid}`
—que con Auth solo puede leer su dueño—. Se descartó a favor de push
porque el aviso tiene que llegar aunque la app esté cerrada, que es
exactamente el caso: alguien que ya vio su amigo secreto y no tiene motivo
para volver a abrir la app hasta el día del intercambio.

**El riesgo de esta elección, escrito para que no sorprenda a nadie:**
quien deniegue el permiso de notificaciones **no recibirá nada, y ni esa
persona ni el organizador lo sabrán**. Mucha gente lo deniega por costumbre.
Con push a secas, la promesa «le llega inmediatamente» falla en silencio
para esa parte del grupo.

Se asume a sabiendas. La red de seguridad —un aviso dentro de la app para
quien no tenga push— queda **fuera de alcance** y sería barata de añadir
después: con Auth ya existe la regla que deja a cada quien leer su propio
documento, que es el canal privado que haría falta.

## El modelo

### Dónde viven los tokens

Un token de FCM identifica **una instalación**, no una persona: la misma
cuenta en el móvil y en el portátil son dos tokens. Así que es una lista.

Campo `tokensPush` en `usuarios/{uid}`, como mapa de `token → fecha`:

```
usuarios/{uid}.tokensPush = { "<token>": <timestamp> }
```

**Mapa y no array** por lo mismo que `grupos` dejó de ser array en P2:
añadir dos veces el mismo token con `arrayUnion` es una comparación por
igualdad que ya falló una vez en este proyecto. Con el mapa el duplicado no
se puede ni escribir.

La fecha sirve para limpiar: un token que lleva meses sin renovarse es de
un dispositivo que ya no existe.

### Cómo se guarda

Función nueva `guardarTokenPush({token})`, que el cliente llama cuando FCM
le da uno y cada vez que lo renueva (`onTokenRefresh`). Escribe en
`usuarios/{uid}` por el Admin SDK, porque la escritura del cliente sobre
ese documento sigue cerrada.

**Los tokens muertos se limpian solos:** al enviar, FCM contesta
`messaging/registration-token-not-registered` para los que ya no valen, y
el servidor los borra del mapa en esa misma respuesta. Sin trabajo
programado y sin que crezca para siempre.

### Cómo se envía

Un helper en `functions/index.js`:

```
async function avisar(uid, {titulo, cuerpo, datos})
```

Lee los tokens de ese uid, los manda, y borra del mapa los que FCM rechace
por no estar registrados.

**CORREGIDO el 2026-08-12: `admin.messaging()` ya no existe.** Este proyecto
usa `firebase-admin` v14, que retiró la API con espacio de nombres — es lo
mismo que tumbó el módulo entero durante la migración a Node 22. Va
`const {getMessaging} = require("firebase-admin/messaging")` y luego
`getMessaging().sendEachForMulticast(...)`. Ese método sí sigue existiendo
en la v14.2.0 instalada; está comprobado, no supuesto.

**Nunca hace fallar a quien la llama.** Si el envío truena, se registra y se
sigue. Un reemplazo que funcionó no puede deshacerse porque una notificación
no salió — y el reemplazo ya está escrito en Firestore cuando se llama a
esto.

### El permiso, y cuándo se pide

**REVISADO el 2026-08-12.** El diseño original lo pedía al apuntarse a un
grupo. Eso dejaba fuera precisamente a quien más lo necesita: **quien ya
está dentro de un grupo nunca sería preguntado**, y en los grupos que ya
existen no llegaría ningún aviso — sin que ni esa persona ni el organizador
lo supieran.

Se pide **al crear la cuenta**, que es el único momento por el que pasa
todo el mundo.

**Con una condición que no es opcional: primero se pregunta en una pantalla
nuestra, y solo si dicen que sí se llama al navegador.**

El motivo es que **al navegador solo se le puede preguntar una vez en la
práctica**: si lo deniegan, queda denegado para siempre y las siguientes
llamadas no muestran nada. Y al crear la cuenta la persona todavía no ha
visto la app ni está en ningún grupo — es el momento con más probabilidad
de un «no» por costumbre.

Con la pantalla propia delante, un «ahora no» **no gasta nada**, y se puede
volver a ofrecer más tarde (al entrar a un grupo, por ejemplo). Sin ella,
un «no» automático deja a esa persona sin avisos para siempre.

Texto de la pantalla propia:

> **¿Te avisamos?**
> Te diremos cuando tu grupo sortee, cuando escriban en el chat y si tu
> amigo secreto cambia de persona.
> [Sí, avísame] [Ahora no]

### De qué se avisa

**REVISADO el 2026-08-12.** El diseño original avisaba solo del reemplazo y
dejaba el resto fuera de alcance. Como el permiso ahora se pide una vez y
sirve para todo, entran tres:

| Suceso | Aviso |
|---|---|
| Reemplazo de una plaza | A quien le regala a esa plaza |
| El grupo sortea | A todos los participantes |
| Mensaje en el chat | Al resto del grupo |

**El chat lleva una regla propia:** no se avisa a quien está mirando ese
chat en ese momento. Avisar de cada mensaje a quien lo está leyendo es la
forma rápida de que la gente apague los avisos para siempre.

### Qué dice el aviso

**Sin nombres.** La notificación la puede ver quien tenga el teléfono en la
mano, así que no lleva ni el nombre del amigo secreto ni el de nadie:

> **Tu amigo secreto cambió**
> En «Navidad Oficina». Ábrelo para ver quién es ahora.

El del chat tampoco dice quién escribió ni qué: eso volvería a filtrar por
la pantalla de bloqueo lo que el grupo se está diciendo.

> **Nuevo mensaje**
> En «Navidad Oficina».

Los datos (`data`) llevan el código del grupo, para que tocar la
notificación abra ese grupo.

## Qué cambia en el código

### Servidor

- **`guardarTokenPush({token})`** — función nueva.
- **`avisar(uid, {...})`** — helper interno.
- **`canjearReemplazo`** avisa a quien le regala a la plaza, **después** de
  `batch.commit()`.

  **CORREGIDO el 2026-08-12:** el diseño decía «con el uid de quien regala».
  `recibe_de` **no da un uid**: da el **id de la plaza** que regala. El uid
  está en el privado de esa plaza, en el campo `cuenta`. Es una lectura más,
  y hace falta una guarda por si esa plaza no tiene cuenta.
- **`ejecutarSorteo`** avisa a todos los participantes del grupo, después de
  escribir el sorteo.
- **`mandarMensaje`** avisa al resto del grupo, con la regla de no avisar a
  quien esté mirando ese chat.

### Cliente

- **`firebase_messaging`** en `pubspec.yaml`.
- **`web/firebase-messaging-sw.js`** — el *service worker*. Sin él no hay
  push en web, y es el trozo que más suele fallar en silencio: se sirve
  desde la raíz del dominio y necesita su propia configuración de Firebase,
  que en este proyecto está incrustada en `lib/main.dart` y habrá que
  repetir ahí.
- **`lib/push.dart`** — nuevo. Pedir permiso, obtener el token, renovarlo,
  y qué hacer al tocar la notificación.
- La clave VAPID del proyecto, necesaria para web.

  **CORREGIDO el 2026-08-12:** tanto la clave VAPID como la configuración
  del *service worker* tienen que salir de **`secretgift-app`**. Este
  diseño se escribió antes de la mudanza de proyecto, y una clave del
  proyecto viejo fallaría sin decir por qué.

- **La pantalla propia de permiso** (ver «El permiso»), que sale al crear
  la cuenta y es la que decide si se llega a llamar al navegador.

## Verificación

- `flutter analyze` sin advertencias y todos los tests en verde.
- Los dos ARB con el mismo conjunto de claves.
- **Un test unitario del helper de limpieza**: dada una respuesta de FCM
  con un token rechazado por `registration-token-not-registered`, ese token
  y solo ese desaparece del mapa. Es la parte con lógica de verdad.
- `scripts/probar.mjs`: `guardarTokenPush` guarda, y guardarlo dos veces
  deja **una sola** entrada.
- **En dispositivo, y no hay atajo:** dos cuentas, dos navegadores, un
  grupo sorteado. Reemplazar una plaza y comprobar que a quien le regalaba
  **le llega la notificación con la app cerrada**. Es lo único que prueba
  que esto funciona; todo lo demás puede estar verde y el push no salir.
- **Los otros dos avisos, también en dispositivo:** que al sortear les
  llega a todos, y que un mensaje de chat avisa al resto **pero no a quien
  está mirando ese chat**.
- **Que «Ahora no» no gasta el permiso.** Pulsarlo al crear la cuenta y
  comprobar después que el navegador **sigue pudiendo preguntar**. Si esta
  falla, la pantalla propia no sirve para nada y el diseño entero se cae.
- **Probar también denegando el permiso** en el cuadro del navegador, y
  comprobar que el reemplazo, el sorteo y el chat siguen funcionando
  enteros y sin errores visibles.

## Fuera de alcance

- **El aviso dentro de la app** para quien no tenga push. Es la red de
  seguridad del riesgo asumido arriba, y va aparte.
- ~~Cualquier otra notificación~~ — **REVISADO el 2026-08-12.** El sorteo y
  los mensajes de chat **entran** (ver «De qué se avisa»). Siguen fuera los
  **recordatorios de fecha**, que necesitan trabajo programado y no tienen
  ninguno de los dos disparadores que ya existen.
- **Preferencias de notificación.** No hay nada que apagar todavía.
- **iOS.** La app es web y Android; el push web en iOS exige que la app
  esté instalada en la pantalla de inicio y no se va a probar.
