# 2026-08-17 — Lo que solo se ve en un móvil

Día de probar en dispositivo lo construido el 12, y de arreglar lo que
salió. Cuatro fallos, ninguno detectable desde el escritorio.

**La rama `ajustes-android` NO está fusionada.** Le falta la prueba en el
móvil, que hoy pesa más que de costumbre: uno de los arreglos no tiene
ninguna red automática.

## Lo que encontró probar en el móvil

Las notificaciones push se fusionaron con **88 pruebas automáticas, 46
casos de integración contra el servidor real y once revisiones
independientes**. Todo en verde.

La primera vez que alguien instaló el APK y lo usó, aparecieron **cuatro
fallos**.

| | Fallo | Causa |
|---|---|---|
| 1 | Pantallas oscuras en el flujo de cuenta | Cuatro pantallas sin envoltorio de fondo |
| 2 | El enlace de invitación abría el navegador | Sin intent-filter, y sin huella de firma |
| 3 | Los cambios de la web no se veían | Conexión de Firestore muerta al congelar la app |
| 4 | «No puedes salirte» sin decir qué hacer | Un solo texto para dos personas distintas |

## 1 y 4 — arreglados y fusionados

### Las pantallas oscuras las escondía la web

`pantalla_verificar_correo`, `pantalla_recuperar_password`,
`pantalla_completar_perfil` y `pantalla_permiso_avisos` usaban un
`Scaffold` pelado. Todas las demás se envuelven en `FondoNeutro`, que es
quien pinta el fondo.

**En web no se notaba porque `index.html` pinta `#F3E3E5` y la página
tapaba el agujero.** En Android no hay página HTML debajo, y salía el
gris de Material.

El fallo llevaba ahí desde siempre. **Solo un APK podía enseñarlo.**

Y una parte fue propia: al encargar la pantalla de permisos el 12 se dijo
que copiara la estructura de `pantalla_verificar_correo.dart`. Copió
también el fallo.

### Un mensaje escrito para la persona equivocada

`borrarParticipante` sirve a dos personas —el organizador sacando a
alguien, y un participante saliéndose— y tras el sorteo les daba el mismo
texto, escrito para el organizador.

El código **ya había resuelto esto en otro sitio**: `agregarParticipante`
tiene una clave propia con un comentario que explica que el texto
genérico «no tiene ningún sentido para quien acaba de escanear un QR». Se
aplicó el mismo patrón.

**La revisión encontró un tercer caso que se había escapado:** la guarda
distinguía «yo mismo» de «otro», no «organizador» de «participante». El
organizador que se sacara a sí mismo recibía «pídele al organizador que
te reemplace» — que se preguntase a sí mismo. Y es alcanzable: la app le
muestra el icono de sacar también en su propia fila.

## 2 — Los enlaces de invitación: dos fallos encadenados

**Faltaban las dos mitades**, y arreglar solo una habría empeorado las
cosas:

1. El manifiesto solo tenía el intent-filter de lanzador → Android nunca
   ofrecía la app.
2. `_capturarInvitacionDeLaUrl()` empezaba con `if (!kIsWeb) return;` →
   aunque la app se abriera, **perdía el código**.

Con solo la primera, la app se abriría y tiraría la invitación, cuando el
navegador al menos funcionaba.

### El arreglo que era peor que el fallo

El enlace de arranque llega **por dos caminos a la vez**. El implementador
lo descubrió leyendo el código Java del plugin, y lo dedujo — pero solo a
medias: cortaba la *captura*, y el segundo camino seguía ejecutando su
mitad de *navegación*.

Resultado, con sesión iniciada y la app matada:

1. El arranque entra al grupo y **consume la invitación**.
2. Un segundo después, el eco del enlace navega otra vez, ya sin
   invitación, y vacía la pila.
3. **La pantalla del grupo desaparece.**

Esa persona veía su grupo aparecer y esfumarse, y se quedaba **fuera del
grupo, sin ningún error, con la invitación gastada**. Volver a tocar el
enlace no hacía nada. Con un token de reemplazo, la plaza se perdía para
siempre.

Hicieron falta **dos rondas**: la primera cortó el eco, la segunda
serializó de verdad los dos caminos —una única captura en vuelo que el
arranque espera— en vez de una bandera.

### Y la huella de firma

`assetlinks.json` devolvía `[]`. Firebase lo genera solo, pero **no había
ninguna huella registrada**. Sin ella Android no verifica y —desde
Android 12— manda el enlace al navegador sin preguntar.

**No se puso a mano**: `firebase.json` ignora todo lo que empieza por
punto, así que un `.well-known/` puesto a mano no se subiría nunca y
nadie se enteraría.

**Android verifica los enlaces AL INSTALAR**: hay que reinstalar el APK
después de publicar la huella.

## 3 — La conexión que muere al congelar la app

El síntoma: un participante añadido desde la web no aparecía hasta salir
del grupo y volver a entrar.

**La primera hipótesis —que faltaba escuchar en vivo— era falsa**: esa
pantalla ya escucha con `snapshots()` y está bien escrita.

Lo zanjó una prueba de treinta segundos: con el móvil **en la mano,
despierto y con la pantalla del grupo delante**, el participante aparece
**al instante**.

Lo que lo rompe es tenerla de fondo o con la pantalla apagada: el Samsung
la congela y le mata las conexiones. Al volver, Firestore no se entera de
que su conexión está muerta.

**Es el mismo culpable que el 11**, cuando la pestaña congelada mataba
IndexedDB. Otro sitio, misma causa.

Arreglado con un observador **único y central** del ciclo de vida —no
había ninguno en toda la app— que fuerza la reconexión al volver. El
revisor comprobó **contra el código fuente del paquete** que las escuchas
vivas siguen funcionando durante el corte, que era el riesgo principal.

**De paso, los `onError` mudos.** Las dos escuchas se tragaban cualquier
fallo en silencio: permisos, un índice ausente, la conexión muerta. La
pantalla se habría quedado con datos viejos sin que nadie se enterara
jamás. Ahora dejan rastro.

## El enlace de verificación: callejón cerrado

El humano preguntó si se podía sustituir por un código de un solo uso, **y
el motivo era bueno**: mucha gente desconfía de un enlace largo de un
dominio que no reconoce, y como la verificación es bloqueante, quien no
pincha **no entra**.

Se intentó primero lo barato: que el enlace llevara `secretgift.app`. **La
consola rechaza guardar cualquier URL de acción** — probado con dos
valores distintos, y ya había fallado en el proyecto anterior.
Documentado aparte para que no se intente una tercera vez.

Se evaluaron dos soluciones propuestas desde fuera. **Las dos caían al
comprobarlas:**

- Una decía registrar el dominio en Hosting. **Ya estaba registrado**, y
  la consola seguía rechazando: su premisa ya se cumplía.
- La otra usaba `actionCodeSettings` con `handleCodeInApp`. Se apoya en
  los **Firebase Dynamic Links, apagados el 25 de agosto de 2025**. Y
  además `url` es el *continue URL* —a dónde vas DESPUÉS— no el dominio
  del enlace.

Sonaban razonables las dos. La única forma de saberlo fue comprobarlas.

## Verificación

| | |
|---|---|
| `flutter analyze` | Limpio |
| `flutter test` | **98** (78 al empezar el día) |
| `node --test` | 10 |
| Compilaciones | Web y APK |
| **Prueba en dispositivo** | **PENDIENTE** |

### El agujero honesto de la cobertura

**El arreglo del fallo más grave no tiene ninguna prueba automática.** El
revisor lo comprobó por mutación: borró el arreglo y los 90 tests
siguieron en verde.

Se intentó escribir el test y no se pudo sin un andamiaje
desproporcionado: el `initState` toca Firebase y se cae antes de llegar a
la lógica, y aun simulándolo, el código mutado y el correcto comparten la
misma salida temprana — un mock no los distingue.

**Se documentó en vez de escribir un test que pasara siempre.** Un test
verde que no prueba nada es peor que no tenerlo. Esta rama ya tuvo una
tautología —un test que comparaba una cadena consigo misma— y se
reescribió.

**Consecuencia: la prueba en el móvil es el portero de verdad.**

## Lo demás que se hizo

- **Fusionado a `main` y desplegado** todo lo del 12 más los arreglos 1 y
  4. 26 commits.
- **APK de prueba** en `https://secretgift.app/apk`, con atajo por
  redirección para que conserve la extensión `.apk` — sirviéndolo bajo
  `/apk` a secas, Android no lo reconocería como instalable.
- **Se verificó el APK por contenido, no por peso.** Pesaba exactamente
  lo mismo que el anterior pese a llevar código nuevo, lo que no cuadraba.
  Se abrió el binario compilado y se confirmó que dentro están
  `observarReconexionFirestoreAlVolver`, `reconexion_firestore`,
  `reportarFalloDeEscucha` y `AppLinks`.

## Pendientes

### 1. La prueba en el móvil — bloquea la fusión

Desde `https://secretgift.app/apk`, **desinstalando primero**:

- [ ] **Enlace con la app matada**: abre, entra al grupo y **se queda**.
      Mirar 3-4 segundos. **Si aparece y se esfuma, parar y no volver a
      tocar ese enlace** — se habría gastado.
- [ ] **Reconexión**: grupo abierto, pantalla apagada unos minutos,
      añadir un participante desde la web, volver. Debe aparecer solo.
- [ ] **Sin sesión**: crear cuenta debe decir «Te han invitado a X».
- [ ] **Con la app abierta**: el enlace lleva directo al grupo.
- [ ] Las pantallas del flujo de cuenta ya no salen oscuras.
- [ ] Salirse de un grupo sorteado dice que hable con el organizador.

### 2. Fusionar `ajustes-android`

5 commits, en cuanto la prueba salga bien.

### 3. Verificación por código de un solo uso

**Sin diseñar.** Es la única salida al problema de confianza. Arrastra un
proveedor de correo propio, generación y caducidad del código, y
protección contra fuerza bruta —seis dígitos son un millón de
combinaciones—. El contador hacia atrás es lo barato una vez existe lo
demás.

Beneficio añadido: **se lleva por delante toda la familia de fallos que
vienen de salir de la app al buzón y volver**, que ha costado dos días.

### 4. Eliminar cuenta

Spec escrita el 12 y **sin revisar por el humano**. Falta el plan.

### 5. Deuda anotada hoy

- `_enCurso` es una sola ranura, no un mapa.
- `esEnlaceDeArranque` es una ventana de tiempo, no una prueba. Se
  auto-repara.
- `_arrancar()` tiene `try/finally` sin `catch`.
- `android:path="/"` no captura el dominio pelado sin barra final.
- Sin tests de `borrarParticipante` en el servidor.
- Firma con la clave de depuración. **Antes de publicar en Play hay que
  crear una propia y guardarla muy bien: si se pierde, la app no se puede
  actualizar nunca más.**

## La lección del día

Ochenta y ocho pruebas automáticas, cuarenta y seis casos de integración
contra el servidor de verdad, once revisiones independientes. Todo en
verde, todo fusionado, todo en producción.

**Y la primera persona que instaló la app encontró cuatro fallos en una
tarde.** Dos llevaban meses ahí, escondidos porque la web los tapaba.

No es que las pruebas fueran malas. Es que **ninguna pinta píxeles en un
móvil, ni congela un proceso, ni toca un enlace desde WhatsApp**. Hay una
clase entera de fallos que solo existe en el dispositivo.

Y el corolario del mismo día: cuando se arregló el más grave, **el primer
arreglo era peor que el fallo**. Lo cazó una revisión que recorrió los
caminos uno por uno. Sin ella habría entrado en producción algo que
dejaba a la gente fuera de sus grupos en silencio.
