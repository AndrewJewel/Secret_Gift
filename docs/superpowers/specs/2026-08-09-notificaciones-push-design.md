# Diseño — Notificaciones push (FCM)

**Fecha:** 2026-08-09
**Estado:** aprobado, pendiente de plan de implementación
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

Lee los tokens de ese uid, manda con `admin.messaging().sendEachForMulticast`,
y borra del mapa los que FCM rechace por no estar registrados.

**Nunca hace fallar a quien la llama.** Si el envío truena, se registra y se
sigue. Un reemplazo que funcionó no puede deshacerse porque una notificación
no salió — y el reemplazo ya está escrito en Firestore cuando se llama a
esto.

### El permiso, y cuándo se pide

**No al entrar.** Pedir notificaciones nada más abrir la app es la forma
más segura de que la denieguen. Se pide **la primera vez que alguien se
apunta a un grupo**, junto a una frase que dice para qué:

> Te avisaremos si algo cambia en tu grupo — por ejemplo, si tu amigo
> secreto cambia de persona.

Si lo deniega, no se le vuelve a preguntar: el navegador recuerda la
decisión y volver a pedirlo no la cambia.

### Qué dice el aviso

**Sin nombres.** La notificación la puede ver quien tenga el teléfono en la
mano, así que no lleva ni el nombre del amigo secreto ni el de nadie:

> **Tu amigo secreto cambió**
> En «Navidad Oficina». Ábrelo para ver quién es ahora.

Los datos (`data`) llevan el código del grupo, para que tocar la
notificación abra ese grupo.

## Qué cambia en el código

### Servidor

- **`guardarTokenPush({token})`** — función nueva.
- **`avisar(uid, {...})`** — helper interno.
- **`canjearReemplazo`** llama a `avisar` con el uid de quien regala a la
  plaza, **después** de que el lote se haya escrito.

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
- **Probar también denegando el permiso**, y comprobar que el reemplazo
  sigue funcionando entero y sin errores visibles.

## Fuera de alcance

- **El aviso dentro de la app** para quien no tenga push. Es la red de
  seguridad del riesgo asumido arriba, y va aparte.
- **Cualquier otra notificación**: que el grupo sorteó, mensajes de chat,
  recordatorios de fecha. Este subsistema los hará posibles; ninguno se
  construye aquí.
- **Preferencias de notificación.** No hay nada que apagar todavía.
- **iOS.** La app es web y Android; el push web en iOS exige que la app
  esté instalada en la pantalla de inicio y no se va a probar.
