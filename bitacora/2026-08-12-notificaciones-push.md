# 2026-08-12 — Notificaciones push, y tres fallos que solo se veían desde arriba

Día largo: once tareas ejecutadas, 23 commits, 2810 líneas. Y la lección
del día no está en lo que se construyó, sino en lo que encontró la
revisión final cuando ya parecía terminado.

**La rama `notificaciones-push` NO está fusionada.** Le falta una sola
cosa: la prueba en el móvil.

## Qué se construyó

Avisos push con FCM, **en web y en Android**, para tres sucesos:

| Suceso | A quién |
|---|---|
| Reemplazan a tu amigo secreto | A quien le regala a esa plaza |
| El grupo sortea | A todo el grupo |
| Alguien escribe en el chat | Al resto del grupo |

Más un interruptor en Configuración para encenderlos y apagarlos, y una
pantalla propia que pide el permiso **antes** de que lo haga el navegador.

### Por qué esa pantalla propia existe

Es la pieza central del diseño y conviene no perderla de vista: **al
navegador solo se le puede pedir el permiso una vez en la práctica**. Si lo
deniegan, queda denegado para siempre y las llamadas siguientes no muestran
nada — ni siquiera aparece el cuadro.

Y el momento en que se pide —recién creada la cuenta— es el de más
probabilidad de un «no» por costumbre. Con una pantalla nuestra delante, un
«Ahora no» **no gasta nada** y se puede volver a ofrecer.

### Android, primero y a propósito

El plan puso Android por delante de todo lo demás. No por orden estético:
`google-services.json` seguía apuntando al proyecto viejo, así que
cualquier prueba en APK habría guardado los tokens **en la base de datos
equivocada sin dar ningún error** — ese proyecto sigue vivo y responde.

De paso, el paquete pasó de `com.example.santa_secreto` a
**`app.secretgift`**, que hacía falta igualmente porque Google Play no
acepta `com.example`.

## Lo que encontró la revisión final, y por qué importa

Las once tareas se revisaron una a una y todas quedaron limpias. Luego una
revisión de **toda la rama junta** encontró **tres fallos críticos**. Los
tres eran invisibles desde una tarea suelta.

### 1. Abrir Configuración quemaba el permiso

`getToken()` del SDK de JavaScript **pide el permiso él mismo**. Verificado
en el bundle exacto que carga la app:

```js
if ("default" === Notification.permission && await Notification.requestPermission(),
    "granted" !== Notification.permission) throw B.create("permission-blocked")
```

Consecuencia: alguien que había pulsado «Ahora no» abría Configuración para
cambiar el idioma **y le saltaba el cuadro del navegador**, sin contexto. Si
lo denegaba ahí, permiso quemado para siempre.

**La rama entera existía para evitar exactamente eso, y estaba rota desde
dentro.** Y el comentario de nuestro propio código afirmaba lo contrario de
lo que el código hacía.

### 2. El token se escribía una vez y nadie lo reconciliaba

Tres caminos dejaban a alguien sin avisos, en silencio y para siempre:

- **En web, `onTokenRefresh` no emite nunca.** Es un *noop stream*; el
  paquete lo dice en un comentario. Nuestro código describía una protección
  que en web no existe.
- Un fallo de red al guardar el token **no se reintentaba jamás**, porque
  la marca de «ya se preguntó» ya estaba puesta.
- Al **cambiar de cuenta** en el mismo dispositivo, el token seguía
  colgando de la anterior.

Y el tercero además filtraba datos: la cuenta vieja seguía recibiendo
avisos en ese teléfono, y tocar uno **entregaba el código del grupo** a
quien ahora lo usa.

### 3. El aviso de reemplazo dejaba deducir quién regala a quién

```
Tu amigo secreto cambió
En «Navidad Oficina». Ábrelo para ver quién es ahora.
```

Ese aviso va **solo a quien le regala a esa plaza**, y quién ocupaba esa
plaza **es público dentro del grupo**. Quien viera ese móvil bloqueado
deducía el par sin desbloquear siquiera.

Esta app pone la asignación detrás de un PIN precisamente contra eso. El
aviso la estaba regalando por fuera. Ahora el texto es neutro.

## Los errores del plan, y quién los cazó

**Seis defectos del plan los encontró quien lo ejecutaba**, no quien lo
escribió. Todos por pararse a comprobar en vez de dar el plan por bueno:

| Defecto | Qué pasaba |
|---|---|
| `npm run lint` en `functions/` | No existe: ni scripts ni ESLint. Afectaba a tres tareas |
| `mandarMensaje` | La función se llama `enviarMensaje` |
| Una `onCall` es de tipo `object` | Es `function` |
| El nombre del grupo está en `nombre` | Está en `nombreGrupo` |
| El filtro del chat por `p.id` | Los privados **siempre** tienen el id literal `"data"`, así que el filtro nunca habría excluido a nadie: **cada persona se habría notificado sus propios mensajes** |
| El fragmento del enganche con `if (!mounted) return` | `PantallaRaiz` se destruye a los segundos: habría dejado **muerto** el enganche de las notificaciones justo para el caso real |

Los dos últimos habrían llegado a producción sin que ningún test los viera.

## El despliegue que no se hizo

La batería reventó con HTML en vez de JSON. Causa: **`guardarTokenPush`
daba 404 — nunca se había desplegado.** Una tarea anterior había subido
solo *su* función con `--only functions:borrarTokenPush`, y todo el trabajo
de servidor de dos tareas llevaba desde entonces sin subir.

**`firebase deploy --only functions:<una>` deja el resto atrás y no
avisa.** Lo cazó la batería porque corre contra el servidor de verdad;
ningún test local lo habría visto.

## Verificación

| | |
|---|---|
| `flutter analyze` | Limpio |
| `flutter test` | **78** (eran 47 al empezar el día) |
| `node --test` en `functions/` | **10** |
| Batería de integración | **46 casos, contra el servidor real** |
| Compilación | Web y APK |
| **Prueba en dispositivo** | **PENDIENTE** |

La batería se ejecutó con tres cuentas nuevas verificadas **pinchando
enlaces reales del buzón**, lo que de paso prueba que el correo sale y que
su enlace sirve.

### Las pruebas que se comprobaron por mutación

Varios revisores **revirtieron el arreglo a propósito** para ver si el test
lo detectaba. Resultados honestos:

- El test de «Ahora no no dispara el permiso»: **sí** lo detecta.
- El del texto del aviso y el de la función pura `avisosActivos`: **sí**.
- Los que decían cubrir el Crítico 1 y el mecanismo del Crítico 2: **no**.
  Revertir esos arreglos deja los 78 tests en verde.

Está anotado como deuda. Un test que pasa siempre no vale nada, y saberlo
es mejor que creerse la cuenta.

## Lo demás que se hizo

- **APK de prueba publicado** en **`https://secretgift.app/apk`**. Es una
  redirección y no una reescritura, para que el fichero conserve su
  extensión `.apk` — sin ella Android no lo reconoce como instalable.
- **Icono adaptativo de Android.** Salía con las esquinas rectas porque no
  existía la capa adaptativa. Ahora se genera con `flutter_launcher_icons`,
  fondo `#FBF6EE` (el mismo crema del icono de la web) y el logo encogido
  al 48,4% del lienzo — medido contra el 48,6% de la referencia.
- **Spec de eliminar cuenta**, escrita y commiteada. Sin implementar.

## Pendientes para mañana

### 1. La prueba en el móvil — es lo único que bloquea la fusión

Instalar desde **`https://secretgift.app/apk`** (con `https://` delante: sin
él Chrome bloquea la descarga por pasar por HTTP) y comprobar:

- [ ] El **icono** sale con la forma del launcher, no cuadrado
- [ ] **«Ahora no» NO dispara el cuadro del navegador** al abrir después
      Configuración *(esto en web)*
- [ ] Llega un aviso **con la app cerrada**
- [ ] **Tocar la notificación abre ese grupo** — **solo se puede probar en
      el APK**
- [ ] **Apagar los avisos se queda apagado** al reabrir Configuración
- [ ] **Cerrar sesión sigue siendo rápido**

**AVISO QUE CAMBIA CÓMO HAY QUE PROBAR:** en web,
`firebase_messaging_web` **no implementa `onMessageOpenedApp`** y
`getInitialMessage()` devuelve `null` siempre. Todo el camino de «tocar el
aviso abre el grupo» **solo funciona en Android**. Probarlo solo en Android
daría por bueno un camino que en web no existe.

Y los navegadores con el *service worker* viejo cacheado necesitan **cerrar
todas las pestañas del sitio** para tomar el nuevo (se pasó de firebase-js
10.14.1 a 12.17.0).

### 2. Fusionar la rama

23 commits, 50 ficheros. En cuanto la prueba salga bien.

### 3. Eliminar cuenta

**Spec escrita y sin revisar por el humano.** Dos decisiones de dentro que
conviene mirar antes de programar nada:

- **Los mensajes del chat NO se borran.** Van bajo máscara y no guardan
  vínculo con quién los escribió, así que borrarlos abriría agujeros en
  conversaciones ajenas sin aportar privacidad.
- **Estar en un grupo ya sorteado BLOQUEA** la eliminación hasta que te
  reemplacen. Sale de la regla que ya existe —después del sorteo no se saca
  a nadie— pero es el punto donde Google Play podría poner pegas, porque el
  bloqueo depende de que otra persona actúe.

Falta el plan de implementación.

### 4. Deuda anotada de esta rama, ninguna bloqueante

- `enviarMensaje` hace **2N+1 lecturas por mensaje** de chat, y avisa
  **dentro** de la llamada de quien pulsa enviar: es latencia visible, no
  solo coste. Primer sitio a tocar.
- **Carrera**: `reconciliarAvisos` va `unawaited`; si se apaga el
  interruptor en esos segundos, la reconciliación en vuelo vuelve a guardar
  el token. Queda el interruptor diciendo ENCENDIDO y avisos llegando.
- **Apagar sin red** marca el token como soltado aunque el borrado falle:
  el servidor se queda con un token vivo y nada lo reintenta.
- Los tests del Crítico 1 y del mecanismo del Crítico 2 **no cubren lo que
  dicen**.
- Ningún `.listen()` de FCM tiene `onError`.
- Cuatro copias casi idénticas de `ofrecerAvisosSiHaceFalta`.
- `debeAbrirseElAviso` trata el `null` como «abrir» pero no la cadena
  vacía.
- El canal de notificación de Android es el que crea FCM por defecto
  («Miscellaneous»).

### 5. Cosas de mantenimiento

- **El APK desaparece del hosting en el próximo despliegue normal.** No
  está en el repositorio a propósito: 60 MB en git serían para siempre.
  Hay que copiarlo a mano a `build/web` antes de subir.
  Si esto se repite, **Firebase App Distribution** lo resuelve de raíz.
- **El APK va firmado con la clave de depuración.** Sirve para probar, no
  para publicar. Antes de subir a Play hay que crear una clave propia y
  **guardarla muy bien: si se pierde, la app no se puede actualizar nunca
  más**.
- **`android2/`** sigue ahí, sin seguimiento y sin uso. El humano dijo que
  se ignora.
- Sigue pendiente de antes: **comprobar que cambiar el PIN rechaza una
  sesión de más de cinco minutos**, lo único de la migración a Auth que
  nunca se confirmó con los ojos.

## La lección del día

Once revisiones por tarea, todas limpias. Y la revisión del conjunto
encontró tres fallos críticos, uno de ellos una fuga del secreto que el
juego entero existe para proteger.

**Revisar cada pieza no es revisar el conjunto.** Los tres fallos vivían
justo en las costuras: entre la pantalla de permiso y Configuración, entre
el registro del token y el cierre de sesión, entre el servidor que manda el
aviso y la pantalla de bloqueo que lo enseña. Ninguna tarea suelta podía
verlos, y ninguna hizo nada mal.
