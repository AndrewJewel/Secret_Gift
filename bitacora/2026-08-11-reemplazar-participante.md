# 2026-08-11 — Reemplazar a un participante, y una caza de tres horas

Dos cosas muy distintas en un día: una función planeada que salió como
estaba escrita, y un fallo que apareció al probarla y costó cuatro
explicaciones, tres de ellas falsas.

## P4 — reemplazar a un participante en un grupo ya sorteado

### El agujero que tapa

Hasta hoy, si alguien se caía de un grupo **después** del sorteo, no había
salida. Su plaza quedaba muerta y quien le regalaba se quedaba regalando a
un fantasma. Y la sesión del 9 lo empeoró sin querer, al cerrar la entrada
tras el sorteo — que era el apaño improvisado que la gente usaba.

### Cómo funciona

El organizador ve un icono nuevo en la fila de cada participante, **solo si
el grupo ya sorteó**. Genera un enlace de un solo uso. Quien lo abre ocupa
la plaza: hereda su asignación saliente y cambia nombre, deseos, cuenta y
avatar.

Lo que hace que esto **sirva de algo**, y que era lo difícil: se actualiza
el nombre y los deseos que ve **la tercera persona que le regala a esa
plaza**. Sin eso, el reemplazo sería cosmético y alguien compraría un
regalo para quien ya no está.

Para lograrlo, el sorteo escribe además el puntero inverso `recibe_de`.
Los grupos sorteados antes de este cambio no lo tienen, así que hay un
barrido de respaldo.

### Detalles que costaron una revisión

- **`merge: true` NO borra las claves que omites.** El mapa de tokens se
  actualizaba sin limpiar el anterior, así que el enlace viejo de una plaza
  seguía siendo válido tras regenerarlo. Hace falta `FieldValue.delete()`
  explícito.
- **Reservar antes de comprobar.** Comprobar el token y luego marcarlo
  como usado deja la carrera abierta: dos personas podían canjear el mismo
  enlace. La transacción tiene que reservarlo primero y devolver un
  veredicto.
- **La foto se valida antes de la transacción**, no dentro: si no, un
  avatar inválido quemaba el token.
- **`canjearReemplazo` no puede usar `autorizar()`**, porque quien canjea
  todavía no tiene vínculo con el grupo. La autorización la lleva el token.

### Estado

Desplegado, **57/57** casos de integración en verde —incluido el que prueba
que la tercera persona ve el nombre nuevo— y verificado en un móvil de
principio a fin: el icono aparece tras sortear, el enlace se genera, se
canjea con una tercera cuenta, el nombre viene precargado y la cadena queda
al día.

## El otro fallo: la pestaña congelada

### El síntoma

Al pulsar **«Ya lo confirmé»** tras volver del buzón de correo:

```
Algo salió mal al entrar. Vuelve a intentarlo.
(código: unknown — An unknown error occurred: Error: Database is closing/hidden)
```

Bloqueante: sin verificar el correo no entra nadie.

### Lo que se probó y NO funcionó

| Intento | Resultado |
|---|---|
| Reintentar `reload()` | No sirvió |
| Reintentar `getIdToken()` | No sirvió |
| Cambiar la persistencia a `localStorage` | No sirvió |

Tres arreglos, tres fracasos. Se dejan puestos igualmente: los reintentos
valen contra cortes de red, y las marcas `reload:` / `token:` que se
añadieron para distinguir las dos rutas son ahora lo que dispara el arreglo
bueno.

### Lo que sí se estableció, y cómo

Ninguna de estas líneas salió de razonar. Todas salieron de una prueba.

| Pregunta | Respuesta | Cómo se supo |
|---|---|---|
| ¿Es el proyecto nuevo? | **No** | Falla idéntico en `santa-secreto-860c3`, que sigue vivo |
| ¿Es el código de hoy? | **No** | Ese proyecto sirve la versión del día 9 |
| ¿Es Chrome? | **No** | Edge, mismo motor Chromium, entra a la primera |
| ¿Influyen las pestañas? | **Sí** | Cerrando la mayoría, entra a la primera |
| ¿Se cura reintentando? | **No** | Dos pulsaciones seguidas fallaron; bloquear y desbloquear el móvil lo arregló |

**Causa:** el navegador congela las pestañas de segundo plano y al hacerlo
cierra su IndexedDB. Al volver, el almacén está roto y no se recupera solo.
La cadena `"Database is closing/hidden"` no está en nuestro código ni
documentada en el SDK de Firebase: la escribe el navegador.

### El arreglo

La app **se recarga sola, una vez**. Es exactamente lo que hacía a mano
quien lo sufría.

Dos decisiones que conviene no deshacer:

- **No se compara el texto del error.** Ese texto es del navegador, no está
  documentado y cambia entre navegadores; compararlo se rompería en
  silencio. Se dispara con la huella propia de la app: el comodín
  `auth_desconocido` más la marca `reload:` / `token:` que ponen los
  reintentos al agotarse.
- **Tope de una recarga**, marcado en `sessionStorage`. **Nunca
  `localStorage`**: dejaría la marca puesta para siempre y la recuperación
  no volvería a funcionar jamás. Una app que se recarga en bucle es peor
  que el fallo que arregla.

### La lección de método

Lo que resolvió esto no fue razonar mejor. Fue:

1. **Mirar git.** Desmintió mi afirmación de que «esa pantalla no existía
   antes» — existía desde el día 9.
2. **Buscar la cadena en el repo.** No era nuestra.
3. **Leer el camino completo del botón.** Había *dos* llamadas que podían
   fallar con el mismo mensaje, no una. Llevaba medio día parcheando una
   sola, a ciegas.
4. **Probar la app vieja, que seguía en pie.** Un A/B real en vez de una
   hipótesis.
5. **Preguntar qué se hizo exactamente.** El dato «bloqueé el móvil» valió
   más que todo lo anterior junto.

Y lo que no funcionó: cuatro explicaciones mías, tres falsas. El humano
repitió tres veces «pero antes funcionaba» y las tres primeras lo traté
como una impresión. Era el dato bueno. También le quité la razón sobre las
pestañas justo antes de que lo demostrara cerrándolas.

**Cuando alguien insiste en que antes funcionaba, eso es evidencia. Y si
el sistema viejo sigue vivo, compararlos vale más que cualquier hipótesis.**

## Estado del repositorio

Fusionado a `main` en local con los 47 tests en verde sobre el resultado
fusionado. La rama `reemplazar-participante` está borrada.

**`main` tiene 22 commits sin subir a GitHub.**

## Pendientes

### 1. ~~`secretgift.app` caído~~ — RESUELTO el mismo día

Estuvo un rato devolviendo *«Site Not Found»*: se había quitado del
proyecto viejo y no se había dado de alta en el nuevo, y al intentarlo la
consola fallaba al crear el dominio.

**Causa, comprobada por DNS:** el dominio tenía **dos** reclamaciones de
propiedad a la vez.

```
firebase=secretgift-app          <- el bueno
firebase=santa-secreto-860c3     <- el que sobraba
```

Firebase decide de quién es un dominio leyendo ese TXT, y con dos no sabía
a cuál dárselo. Borrado el segundo, el dominio se añadió sin problema.

Comprobado al cerrar: `secretgift.app/__/firebase/init.json` responde
`secretgift-app`, y en el DNS solo quedan los tres registros buenos.

Ese registro estaba en la lista de limpieza de ayer con la nota «ninguno
molesta, así que sin prisa». **Sí molestaba.** Se dio por inofensivo sin
comprobarlo, y costó un dominio caído.

**Y la verificación en dispositivo de P4 se hizo sobre `secretgift.app` ya
apuntando al proyecto nuevo**, así que vale.

### 2. Subir `main` a GitHub

22 commits esperando.

### 3. Lo que ya venía de antes

Sin cambios respecto a la bitácora del 10:

- **Android**: `google-services.json` sigue siendo del proyecto viejo y el
  paquete sigue siendo `com.example.santa_secreto`. La app web no se ve
  afectada, pero un APK compilado hoy apuntaría al proyecto anterior.
- **Limpieza de DNS**: los tres registros de Resend que sobran.
- **Qué hacer con `santa-secreto-860c3`**, que sigue entero y facturando.
  Hoy demostró su utilidad como banco de pruebas — conviene no tener prisa
  en apagarlo.
- **Notificaciones push (FCM)**: spec escrito, P4 es su primer cliente.
- **Despliegue automático desde GitHub**: diseño aprobado el 10.
- **Comprobar que cambiar el PIN rechaza una sesión de más de cinco
  minutos.** Sigue sin hacerse desde la migración a Auth.
- **P3**, **P1**, **idioma en la cuenta**, **A4 (App Check)**.
