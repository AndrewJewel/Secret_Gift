# Diseño — Eliminar cuenta

**Fecha:** 2026-08-12
**Estado:** aprobado por el humano, pendiente de plan de implementación
**Rama prevista:** propia, después de cerrar `notificaciones-push` (usa los
avisos que esa rama construye).

## Por qué ahora

Dos motivos, y los dos son concretos:

1. **Google Play lo exige.** Cualquier app que permita crear cuentas tiene
   que ofrecer eliminarlas para poder publicarse. Sin esto no se puede
   subir la app a la tienda.
2. **Sin ello no se pueden repetir las pruebas.** La batería de integración
   necesita tres cuentas limpias, y hoy **no existe ninguna forma de dejar
   una cuenta virgen**: hay que crear tres direcciones nuevas y verificar
   tres correos a mano cada vez. Lo descubrió la Tarea 9 de push al
   bloquearse por esto mismo.

## La regla que lo condiciona todo

**Después del sorteo no se puede sacar a nadie de un grupo.** No es una
preferencia: `borrarParticipante` lo rechaza con `grupo_ya_sorteado`, y su
comentario explica el motivo — sacar a alguien deja a quien le regalaba
apuntando a un fantasma, y ese tercero no se entera hasta el día del
intercambio. Es exactamente el agujero que P4 vino a tapar.

Eliminar la cuenta no puede saltarse esa regla. De ahí sale todo lo demás.

## Cuándo se puede y cuándo no

| Situación | Qué pasa |
|---|---|
| Sin grupos, o solo en grupos **sin sortear** | Se elimina. Sus plazas salen de esos grupos |
| Tiene plaza en un grupo **ya sorteado** | **Se bloquea**, diciendo en qué grupos y qué hacer |
| **Organiza** grupos | Se eliminan con la cuenta, avisando antes y después |

Una misma persona puede estar en varias situaciones a la vez. **Si hay
aunque sea un grupo sorteado, manda el bloqueo** y no se borra nada: es
preferible no empezar a que se quede a medias.

### El bloqueo tiene que ser concreto y tener salida

Decidido a sabiendas, y con una advertencia asumida: si estar en un grupo
sorteado bloqueara la eliminación **sin fecha ni salida**, podría no bastar
para la revisión de Google Play.

Se acepta porque la salida existe y es corta: el organizador reemplaza a
esa persona con el enlace de un solo uso que ya existe (P4), y en cuanto lo
hace, ya puede borrarse. Para que sirva de algo, **el mensaje tiene que
nombrar los grupos concretos** que están bloqueando — no un «tienes grupos
pendientes» genérico que deja a la persona sin saber a quién escribir.

Por eso el error viaja con la lista de nombres, no solo con su clave.

## Qué se borra

- La cuenta de **Firebase Auth** (correo y contraseña)
- **`usuarios/{uid}`** entero: nombre, apellido, hash del PIN, el mapa
  `grupos` y los `tokensPush`
- Sus **plazas** en grupos sin sortear: el documento público y el privado
- Su **avatar** en cada una de esas plazas
- Los **grupos que organiza**, enteros

## Qué NO se borra, y por qué

**Sus mensajes del chat.** Van bajo máscara y el documento del mensaje **no
guarda ningún vínculo con quién lo escribió** — es deliberado, para que
nadie pueda rastrear al autor. Nadie puede saber que eran suyos.

Borrarlos abriría agujeros en conversaciones de otras personas y **no
aportaría privacidad**, porque ya son anónimos. Se quedan.

Es una decisión, no un olvido: quien lea esto dentro de seis meses no debe
«arreglarlo».

## Qué NO hace falta limpiar

**Los punteros que otras personas tienen a un grupo eliminado.**
`eliminarGrupo` no los toca hoy, y está bien así: `misGrupos` ignora los
grupos cuyo documento ya no existe, y la batería lo comprueba con el caso
«al eliminar el grupo desaparece de Mis grupos».

Se escribe aquí para que nadie añada una limpieza que no hace falta y que
costaría una escritura por participante.

## Cómo se protege

### Pide la contraseña otra vez

Con `exigirReciente(request)`, que ya existe y hoy usa `cambiarPin`: obliga
a que la sesión tenga menos de cinco minutos, y solo reautenticarse lo
renueva. Sin esto, quien coja un dispositivo desbloqueado podría borrar la
cuenta entera.

Borrar la cuenta es al menos tan serio como cambiar el PIN.

### Un diálogo que dice lo que se pierde

Nada de «¿estás seguro?». El diálogo enumera:

- que **no se puede deshacer**
- **los nombres de los grupos que se van a eliminar**, si organiza alguno
- que sus plazas desaparecerán de los grupos donde esté

### El orden importa: Auth se borra el ÚLTIMO

Primero Firestore y Storage, y **la cuenta de Auth al final**.

Si algo falla a mitad, queda una cuenta que **todavía puede entrar y
reintentar**. Al revés —borrando Auth primero— quedaría una persona sin
poder entrar, con sus datos a medio borrar y sin ninguna forma de
terminar el trabajo ni de pedir ayuda.

## Los avisos

Ahora que las notificaciones existen, se usan en los dos sentidos:

- **Al organizador, antes**: no es un aviso push, es el propio diálogo, que
  le dice qué grupos se van a llevar por delante.
- **A los participantes, después**: un push por cada grupo eliminado.
  Borrar el grupo de veinte personas en silencio dejaría a gente
  presentándose a un intercambio que ya no existe.

  > **El grupo se ha cerrado**
  > «Navidad Oficina» ya no existe.

  Sin nombres de personas, como todos los demás avisos de esta app.

  Los uids hay que **recogerlos ANTES de borrar el grupo**: después ya no
  hay a quién preguntar.

## Qué cambia en el código

### Servidor

- **`eliminarCuenta()`** — función nueva, sin argumentos. Hace, por este
  orden: exigir sesión reciente; leer sus vínculos; **comprobar los
  bloqueos y salir sin tocar nada si los hay**; recoger los uids de los
  participantes de los grupos que organiza; eliminar esos grupos;
  eliminar sus plazas y avatares en los grupos sin sortear; borrar
  `usuarios/{uid}`; borrar la cuenta de Auth; y **avisar a los
  participantes al final**, cuando ya no puede fallar nada que importe.
- Necesita **`getAuth`** de `firebase-admin/auth`, que todavía no se
  importa en `functions/index.js`.
- Para eliminar cada grupo, **reutiliza lo que ya hace `eliminarGrupo`**:
  `db.recursiveDelete(grupoRef(codigo))` más borrar `avatares/{codigo}/`
  del bucket. Conviene extraer eso a un helper que usen las dos, en vez de
  repetirlo.
- Para el avatar de una plaza suelta ya existe **`borrarAvatarPorUrl(url)`**.

### Cliente

- Opción **«Eliminar mi cuenta»** en `lib/hoja_configuracion.dart`, con el
  aspecto que la app dé a lo destructivo.
- El diálogo de confirmación, con la lista de grupos.
- La reautenticación **ya está en ese mismo fichero**: `reautenticar(...)`
  vive en `lib/acceso_cuenta.dart` y `hoja_configuracion.dart` ya la usa
  para cambiar el PIN, con su campo de contraseña. **No es una pantalla
  aparte** — se reutiliza ese mismo patrón unas líneas más abajo, no se
  escribe nada nuevo. (Comprobado el 2026-08-12, no supuesto.)
- `FuncionError` tiene que poder llevar **datos extra** del servidor —hoy
  solo lleva `clave` y `mensaje`—, para que el mensaje del bloqueo pueda
  enumerar los grupos.

### Textos

Claves nuevas en los dos ARB, con sus `@clave` y `description` en la
plantilla inglesa:

- el título y el cuerpo del diálogo
- `cuenta_con_grupos_sorteados`, que enumera los grupos que bloquean
- el aviso push del grupo cerrado

## Verificación

- `flutter analyze` limpio y todos los tests en verde.
- Los dos ARB con el mismo conjunto de claves, y los generados commiteados.
- **En `scripts/probar.mjs`**, y esto es lo que de verdad prueba el diseño:
  - eliminar una cuenta **sin grupos** funciona, y esa cuenta ya no entra
  - eliminar con una plaza en un grupo **sin sortear** funciona, y la plaza
    desaparece del grupo
  - eliminar con una plaza en un grupo **ya sorteado** se rechaza con
    `cuenta_con_grupos_sorteados`, **y el error trae el nombre del grupo**
  - un rechazo **no deja nada a medias**: la cuenta sigue entrando y sus
    grupos siguen intactos
  - eliminar siendo organizador **se lleva el grupo**, y ese grupo deja de
    existir para los demás participantes
  - **sin sesión reciente se rechaza** con `requiere_reautenticacion`
- **En dispositivo**: que el diálogo nombre los grupos de verdad, y que un
  participante de un grupo eliminado **reciba el aviso**.

## Fuera de alcance

- **Traspasar un grupo a otro organizador.** Resolvería el caso mejor que
  eliminarlo, pero no existe nada parecido hoy y es un subsistema propio.
- **Descargar tus datos antes de borrarlos.** Google Play lo pide para
  algunas categorías, no para ésta.
- **Un periodo de gracia** en el que la cuenta se pueda recuperar. Añade
  estado que mantener para siempre; se borra de verdad y se avisa de que no
  hay vuelta atrás.
- **Borrar los mensajes del chat**, por lo dicho más arriba.
