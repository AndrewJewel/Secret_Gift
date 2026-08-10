# Diseño — Reemplazar a un participante tras el sorteo (P4)

**Fecha:** 2026-08-09
**Estado:** aprobado, pendiente de plan de implementación
**Rama prevista:** propia, **después** de la migración a Firebase Auth
(`2026-08-09-firebase-auth-design.md`).

## Qué se cambia y por qué

Tras el sorteo, la lista de un grupo no cambia. `borrarParticipante` lanza
`grupo_ya_sorteado` y `agregarParticipante` lanza `grupo_cerrado` — este
último cerrado el 2026-08-09.

Las dos reglas son correctas y se sostienen entre sí: sacar a alguien deja
a quien le regalaba apuntando a un fantasma, y meter a alguien nuevo lo
deja fuera de la cadena, sin amigo y sin nadie que le regale. Los dos
fallos se ven el día del intercambio, cuando ya no hay arreglo.

Pero juntas dejan un **grupo sorteado sin ninguna salida** si alguien no
puede seguir jugando. Hoy la única opción es eliminar el grupo entero y
volver a empezar.

Esta es la salida que faltaba: **la plaza no se borra, cambia de dueño.**

## El modelo

### La plaza es lo que persiste, no la persona

La cadena vive en `grupos/{codigo}/participantes/{id}/privado/data`. El
`{id}` es la plaza. Reemplazar es **cambiar quién ocupa esa plaza sin
tocar el `{id}`**, así que la cadena del sorteo no se entera de nada.

| Campo | Qué pasa al reemplazar |
|---|---|
| `asignado_a`, `nombre_asignado`, `deseos_asignado` | **Se heredan.** Quien entra regala a la misma persona. Es lo que mantiene la cadena entera. |
| `cuenta` | Pasa a ser el uid de quien entra. |
| `deseos` | Los suyos, escritos por quien entra. |
| `mascara`, `mascaraRepeticion`, `ultimoMensajeMs` | **Se borran.** Máscara nueva. |
| `recibe_de` | Se conserva: quién le regala a esta plaza no cambia. |
| Documento público: `nombre`, `avatarUrl` | Los suyos. El avatar anterior se borra del bucket. |
| `tieneAmigo` | Sigue `true`. La plaza siempre tuvo amigo. |

### El puntero inverso `recibe_de`

`nombre_asignado` y `deseos_asignado` son **copias denormalizadas**. Si la
plaza B cambia de persona, quien le regala a B tiene guardado el nombre y
los deseos de quien ya no está — y compraría para esa persona. Actualizar
esos dos campos **es el arreglo del problema real**, no un detalle.

Para eso hay que saber quién regala a B. Hoy no hay forma directa: habría
que leer los privados de todos los participantes buscando cuál tiene
`asignado_a === B`.

**Se añade el puntero inverso.** `ejecutarSorteo` escribe también
`recibe_de` en el privado de quien recibe, apuntando a quien le regala. Es
una línea en el bucle del sorteo —ya conoce las dos puntas— y convierte la
búsqueda en una lectura directa.

**Sin migración.** La migración a Auth vacía `grupos` entera, y P4 va
después, así que todo grupo existente cuando esto llegue se habrá sorteado
con el código nuevo. **Aun así `canjearReemplazo` cae al barrido** si
`recibe_de` no está: un grupo sin el campo no puede quedarse sin poder
reemplazar, y el barrido de 16 lecturas es barato.

### El enlace de un solo uso

El token vive en `grupos/{codigo}/privado/data`, en un mapa
`reemplazos: {<token>: <participanteId>}`. Ese documento está **cerrado a
cero para el cliente** (`firestore.rules`), así que el token solo se
canjea a través de la Cloud Function.

- **Token:** `crypto.randomBytes(24).toString("base64url")`. No sale de
  `Math.random` por la misma razón que el código de grupo: es una llave.
- **Un solo uso:** canjearlo borra su clave del mapa.
- **Anularlo:** generar otro token para la misma plaza **borra el
  anterior**. Una plaza tiene como mucho un token vivo. Eso es lo que
  cumple «el organizador puede anularlo» sin añadir un botón de anular.
- **No caduca por tiempo.** Buscar sustituto puede llevar días y un reloj
  solo daría fricción cuando el organizador ya va apurado.

**La URL** reutiliza la forma que ya existe (`?codigo=ABCD-2345`) más un
parámetro: `?codigo=ABCD-2345&reemplazo=<token>`.

## El flujo

### Quién puede y cuándo

Un icono de reemplazar en la fila de cada participante, en
`pantalla_registro.dart`. **Solo lo ve el organizador, y solo si el grupo
ya sorteó** — antes del sorteo la salida correcta es borrar, que ya existe.

### El aviso de consecuencias

Antes de generar nada, un diálogo que dice lo que va a pasar, en concreto:

> **Reemplazar a Beatriz**
>
> Su plaza pasará a otra persona, que heredará a quién le regala Beatriz.
>
> - Quien le regala a Beatriz **seguirá siendo el mismo**, pero verá otro
>   nombre y otros deseos.
> - Beatriz perderá el acceso al grupo.
> - Lo que Beatriz escribió en el chat se queda, con su máscara.
>
> [Cancelar] [Generar enlace]

### Las dos funciones

**`generarReemplazo({codigo, participanteId})`** — la llama el organizador.
Autoriza con `autorizar` + `exigirOrganizador`, exige que el grupo esté
sorteado, y devuelve `{token}`. Borra del mapa cualquier token anterior de
esa misma plaza.

**`canjearReemplazo({codigo, token, nombre, deseos, avatarBase64})`** — la
llama quien entra.

**Ojo, porque rompe el patrón de todas las demás:** quien canjea **todavía
no tiene vínculo con el grupo**, así que `canjearReemplazo` **no puede usar
`autorizar()`** — devolvería `rol: null` y `participanteId: null` para
alguien perfectamente legítimo. Usa `uidDe(request)` a secas: basta con ser
una cuenta verificada, porque **la autorización la lleva el token**, igual
que en el alta normal la lleva el código del grupo.

### El canje, paso a paso

1. **El token existe** en el mapa → sale el `participanteId` de la plaza.
   Si no, `reemplazo_invalido`.
2. **La plaza sigue existiendo.** Si el grupo se eliminó o la plaza
   desapareció, `participante_no_existe`.
3. **Quien canjea no tiene ya plaza viva en este grupo** — la misma regla
   que `agregarParticipante`, y por el mismo motivo: una cuenta, una plaza.
   Si la tiene, `ya_estas_en_el_grupo`.
4. Se sube el avatar **antes** de escribir en Firestore, como ya hace
   `agregarParticipante`: si falla, no queda una plaza a medias apuntando
   a una imagen que no existe.
5. En un lote:
   - Público de la plaza: `nombre`, `avatarUrl`.
   - Privado de la plaza: `cuenta`, `deseos`; se borran `mascara`,
     `mascaraRepeticion` y `ultimoMensajeMs`.
   - Privado de **quien regala a esta plaza** (`recibe_de`, o el barrido):
     `nombre_asignado` y `deseos_asignado` al día.
   - Se borra el token del mapa.
6. Se despega la cuenta anterior y se pega la nueva. **La cuenta anterior
   se trata igual que en `borrarParticipante`**: si era el organizador se
   le conserva la entrada con `participanteId: null` —quitarle la clave
   entera le quitaría el rol y dejaría el grupo ingobernable—, y al resto
   se le borra.
7. Se borra el avatar viejo del bucket.

### El formulario de quien entra

El mismo de alta (`pantalla_registro.dart`) con una diferencia: **el nombre
viene ya escrito con el de la plaza.**

Eso resuelve los grupos temáticos sin añadir ningún modo: si la plaza es
«Gandalf», quedarse con Gandalf es no tocar nada, y cambiarlo es escribir
encima. En un grupo sin temática, quien entra borra el nombre anterior y
pone el suyo.

## Lo que NO hace, dicho a propósito

**Avisar a quien regalaba.** Es lo que hace falta para que el reemplazo se
entere alguien, y es un subsistema aparte —notificaciones push— con su
propio diseño: `2026-08-09-notificaciones-push-design.md`. **P4 se puede
usar sin él**: el diálogo de consecuencias le dice al organizador que avise
a quien corresponda.

**Reordenar la cadena.** Quien entra hereda la asignación tal cual.

## Consecuencias asumidas

**Quien se va sabe a quién regala quien entra.** Vio su asignación antes de
irse, y esa asignación se hereda entera. Evitarlo obligaría a rehacer parte
de la cadena y arrastraría a terceros que no tienen nada que ver.

**Se planteó explícitamente y se aceptó explícitamente** (2026-08-09): en el
caso real —alguien que no puede seguir jugando— esa persona no es un
atacante. No es un descuido: no reabrir sin un motivo nuevo.

**El nombre de quien se fue queda en el chat.** Bajo su máscara, que ya no
es de nadie. Se eligió sobre borrar sus mensajes porque borrarlos dejaría
agujeros en conversaciones donde otros le respondieron.

**Quien entra ve el nombre anterior de la plaza** en el formulario. En un
grupo sin temática eso le dice a quién ha sustituido. Es inevitable si se
quiere que los grupos temáticos funcionen sin un modo aparte, y no revela
ninguna asignación.

## Verificación

- `flutter analyze` sin advertencias y todos los tests en verde.
- Los dos ARB con el mismo conjunto de claves.
- **Casos nuevos en `scripts/probar.mjs`**, contra el backend desplegado:
  1. Un token inventado no vale (`reemplazo_invalido`).
  2. Canjear con una cuenta que ya tiene plaza falla
     (`ya_estas_en_el_grupo`).
  3. Canjear cambia el nombre de la plaza **y actualiza el
     `nombre_asignado` de quien le regala** — se comprueba revelando el
     amigo secreto de esa tercera persona y viendo el nombre nuevo. **Este
     es el caso que prueba que P4 sirve para algo**; sin él, todo lo demás
     puede pasar y el problema seguir ahí.
  4. El mismo token no vale dos veces.
  5. Generar un token nuevo para la plaza invalida el anterior.
  6. La plaza conserva su `asignado_a`: quien entra regala al mismo.
- En dispositivo: reemplazar en un grupo temático conservando el personaje,
  y en uno sin temática cambiando el nombre.

## Fuera de alcance

- **Notificar a quien regalaba** — su propio spec.
- **Que la persona reemplazada se entere por la app.** Se supone que es
  quien pidió salir.
- **Reemplazar antes del sorteo.** Ahí se borra y se vuelve a apuntar, que
  ya funciona.
- **Un historial de quién ocupó cada plaza.**
- **P3 (chat sin máscaras).** Cuando llegue, cambiará qué significa «máscara
  nueva» aquí; no se adelanta trabajo.
