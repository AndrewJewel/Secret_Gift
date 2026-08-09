# Diseño — La cuenta como identidad

**Fecha:** 2026-08-09
**Estado:** aprobado, pendiente de plan de implementación
**Rama prevista:** una nueva a partir de `flujo-cuenta`. `main` sigue en
`44bc51b` y **producción corre código que solo existe en `flujo-cuenta`**,
así que partir de `main` trabajaría sobre lo viejo.

## Qué se cambia y por qué

La app tiene hoy **tres credenciales** que conviven sin que ninguna mande:

| Credencial | Dónde vive | Qué prueba |
|---|---|---|
| Cuenta | `usuarios/{nick}.hash`, bcrypt | quién eres, globalmente |
| PIN propio | `…/participantes/{id}/privado/data.pin`, **texto plano** | que eres *ese* participante |
| PIN maestro | `grupos/{cod}/privado/data.pinMaestro`, **texto plano** | que eres el organizador |

Las dos últimas son un fósil. Se diseñaron cuando **no existían las
cuentas** y el par código-de-grupo + PIN era la única credencial posible.
Las cuentas llegaron en la sesión del 2026-08-08, se volvieron
obligatorias, y nadie revisó si los PIN seguían haciendo falta.

Lo delata el propio código: las claves de disco de la identidad por grupo
se llaman `chat_{codigo}_participante` y `chat_{codigo}_pin`
(`lib/identidad_local.dart`). El prefijo `chat_` es de cuando aquello se
construyó para el chat.

Es el mismo patrón que la bitácora del 2026-08-08 documenta con el parche
del teclado, y merece la misma frase: **un apaño que sobrevive a su bug se
convierte en el siguiente bug.**

### El síntoma que lo destapó

Con la cuenta ya obligatoria, la app te pide **elegir tu nombre de una
lista y teclear un PIN por grupo** cuando abres un grupo desde un
dispositivo nuevo (`lib/hoja_identidad.dart`, `lib/pantalla_login.dart`).
Eso contradice de plano la promesa de la cuenta: *entra con tu nickname y
tu contraseña y ve todos tus grupos desde cualquier sitio*.

Y contradice al propio servidor, que **ya sabe la respuesta**:
`vincularCuenta` guarda `{codigo, participanteId, rol}` en
`usuarios/{nick}.grupos` (`functions/index.js:320`). El dato existe. Lo
que pasa es que `iniciarSesionCuenta` lo tira al responder: arma
`detalles` con `{codigo, rol, ocasion, valorMinimo, nombreGrupo,
tematica}` y descarta el `participanteId` (`functions/index.js:173-184`).

### El bug que apareció al trazarlo

`crearGrupo` vincula `{codigo, rol:'organizador'}` — sin `participanteId`,
porque en ese momento aún no eres participante (`functions/index.js:267`).
Cuando después te apuntas a tu propio grupo, `agregarParticipante` vincula
`{codigo, participanteId, rol:'participante'}` (`functions/index.js:320`).

`vincularCuenta` usa `arrayUnion`, que compara por igualdad profunda. Los
dos objetos son distintos, así que **quedan los dos**. Y
`iniciarSesionCuenta` mapea el array entero sin agrupar por código, así
que devuelve el mismo grupo dos veces. `lib/pantalla_mis_grupos.dart:126`
pinta un `ListView` sobre esa lista tal cual, sin deduplicar.

**Crear un grupo y luego apuntarte a él lo muestra duplicado en Mis
grupos.** Es el flujo más común de la app y está en producción. No es el
"`agregarParticipante` no deduplica" ya triado en la bitácora — aquel
necesita un reintento tras error; este pasa siempre.

## El modelo nuevo

### Una sola credencial de autorización: la cuenta

Más un **PIN global de 4 dígitos** que protege una única acción: ver tu
amigo secreto. Ver §"El PIN global".

### `usuarios/{nick}.grupos`: de lista a mapa

```js
// Hoy — dos entradas para el mismo grupo, y de ahí el duplicado
grupos: [ {codigo:'ABCD', rol:'organizador'},
          {codigo:'ABCD', participanteId:'x7k', rol:'participante'} ]

// Nuevo — una entrada por grupo, imposible duplicar
grupos: { ABCD: { rol:'organizador', participanteId:'x7k' } }
```

El duplicado no se *arregla*: se vuelve **inexpresable**. Crear el grupo
escribe `{rol:'organizador', participanteId:null}`; apuntarte después solo
rellena `participanteId` sin tocar el `rol`.

- Las escrituras usan `FieldPath('grupos', codigo)` en vez de concatenar
  la ruta con puntos, para no depender de que los códigos nunca traigan un
  carácter que Firestore interprete.
- La limpieza de grupos muertos (hoy filtra el array,
  `functions/index.js:189-192`) pasa a borrar claves del mapa con
  `FieldValue.delete()`.
- `rol` solo puede ser `'organizador'` o `'participante'`.
- `participanteId` es `null` hasta que esa persona se da de alta en el
  grupo.

### Un solo verificador

`verificarPinPropio`, `verificarPinOAdmin` y `verificarPinMaestro`
desaparecen. En su lugar:

```js
// Verifica la cuenta y devuelve tu vínculo con ese grupo, o lanza.
async function autorizar(codigo, nickname, password) → {clave, rol, participanteId}
```

con dos guardas encima:

- `exigirOrganizador(...)` — lanza si `rol !== 'organizador'`
  (clave `no_eres_organizador`).
- `exigirParticipante(...)` — lanza si `participanteId == null`
  (clave `no_estas_en_el_grupo`).

**Lo importante no es que sean menos funciones, es de dónde sale el
`participanteId`.** Hoy lo manda el cliente y el servidor comprueba que el
PIN cuadre; a partir de ahora el servidor **lo deriva del vínculo** y el
cliente ya no puede nombrar a otro participante. Suplantar deja de ser
cuestión de adivinar cuatro cifras guardadas en claro.

### Reparto de autorización, función por función

| Función | Hoy | Después |
|---|---|---|
| `crearGrupo` | `pinMaestro` obligatorio, cuenta opcional | cuenta obligatoria, sin PIN |
| `agregarParticipante` | `pin` propio obligatorio, cuenta opcional | cuenta obligatoria, sin PIN |
| `iniciarSesion` (ver amigo) | `participanteId` + `pin` del cliente | **se renombra a `verAmigoSecreto`**: cuenta + PIN global; el `participanteId` lo pone el servidor |
| `enviarMensaje` | PIN propio | cuenta, `exigirParticipante` |
| `miMascara` | PIN propio | *(se borra en P3)* |
| `borrarParticipante` | PIN propio **o** maestro | cuenta: o es el tuyo, o eres organizador |
| `cambiarAvatar` | PIN propio **o** maestro | cuenta: o es el tuyo, o eres organizador |
| `editarParticipante` | PIN maestro | cuenta, `exigirOrganizador` |
| `ejecutarSorteo` | PIN maestro | cuenta, `exigirOrganizador` |
| `editarGrupo` | PIN maestro | cuenta, `exigirOrganizador` |
| `eliminarGrupo` | PIN maestro | cuenta, `exigirOrganizador` |
| `borrarMensaje` | PIN maestro | cuenta, `exigirOrganizador` |
| `verificarOrganizador` | confirma el PIN maestro | **se borra** |

`verificarOrganizador` se cae entera porque su único trabajo era canjear
el PIN maestro por un permiso en memoria. Con el rol viniendo ya en
`iniciarSesionCuenta`, la pantalla sabe si eres el organizador **antes de
dibujar el primer frame** — sin diálogo, sin llamada, sin PIN. El "modo
organizador" deja de ser un modo que se activa: los controles de
organizador simplemente están ahí para quien lo es.

**`iniciarSesion` se renombra a `verAmigoSecreto`.** Su nombre actual se
confunde con `iniciarSesionCuenta`, y ya no inicia ninguna sesión: revela
una asignación. Recibe `{codigo, nickname, password, pin}` y devuelve
`{nombre, nombreAmigo, deseosAmigo}` — el `nombre` es el tuyo propio de
participante, lo único que `PantallaSecreta` necesitaba de la lista que
`PantallaLogin` mostraba.

**El anti-spam del chat sigue en pie durante P2.** `enviarMensaje`
conserva la espera entre mensajes y el campo `ultimoMensajeMs`; solo
cambia de dónde saca el `participanteId`. Quitarlo es una decisión de P3.

### Campos que desaparecen de Firestore

- `grupos/{cod}/participantes/{id}/privado/data.pin`
- `grupos/{cod}/privado/data.pinMaestro`

El resto de esos documentos (`deseos`, `asignado_a`, `nombre_asignado`,
`deseos_asignado`, `mascara`, `mascaraRepeticion`, `ultimoMensajeMs`,
`mascarasUsadas`) se queda como está en P2. Lo que sobra de ahí lo limpia
P3.

## El PIN global

`usuarios/{nick}` gana un campo `pinHash`.

- **Cuatro dígitos exactos**, validado en cliente y servidor (clave de
  error `pin_formato`).
- **Con bcrypt**, igual que la contraseña. Son 10.000 combinaciones y este
  diseño existe precisamente para sacar dos secretos en claro de
  Firestore; meter uno nuevo sería repetir el error del que salimos.
- Se pide en **tres momentos y solo tres**: al crear la cuenta, al ver un
  amigo secreto, y al cambiarlo.

**No se cachea. Se pide cada vez que revelas.** Si se guardara en disco
como hacía el PIN por grupo, dejaría de ser una segunda barrera y volvería
a ser decorado — que es exactamente el problema del que venimos. Revelar
tu amigo secreto se hace una vez por grupo y temporada, no cada rato.

**Para qué sirve, dicho claro:** la contraseña de la cuenta ya demuestra
quién eres. El PIN protege de otra cosa — de que alguien que coge tu
teléfono con la sesión abierta vea tu asignación. Una vez visto, se vio:
es la única acción de la app cuyo daño es irreversible.

**Cambiarlo pide la contraseña de la cuenta.** No es burocracia: es la
única salida si lo olvidas. Sin ella, olvidar cuatro dígitos te dejaría
sin ver tu amigo secreto para siempre, y ya hay bastante con que no exista
recuperación de contraseña.

## El cliente

### Archivos que desaparecen enteros

- **`lib/identidad_local.dart`** — guardaba `(participanteId, pin)` por
  grupo en disco. La identidad la da ahora la sesión.
- **`lib/hoja_identidad.dart`** — la hoja de "¿cuál de estos eres?". Sin
  sentido cuando el servidor ya lo sabe.
- **`lib/pantalla_login.dart`** — listaba a todos los participantes para
  que eligieras tu nombre y tecleases tu PIN antes de ver tu amigo
  secreto. Sus dos pasos se evaporan.

### `MiVinculo`

Clase nueva y pequeña: `{rol, participanteId}`. Viaja como parámetro a
`PantallaRegistro`. Sus dos puertas de entrada ya tienen el dato sin pedir
nada: Mis grupos lo tiene en su lista, y el portero lo tiene en
`resultado.grupos`. `null` significa "todavía no estás dentro" → se ofrece
el alta.

Es el papel que hoy juega `_yo`, pero sin disco y sin PIN.

### `lib/pantalla_registro.dart`

Es donde más se nota.

**Fuera:** el campo PIN del formulario de alta; el estado `_pinMaestro`;
el diálogo que lo pedía; la llamada a `verificarOrganizador`;
`_decirQuienSoy`; `_dejarDeSerYo`; el toggle de modo organizador.

**Cambia:** `_esOrganizador` pasa a ser `_vinculo?.rol == 'organizador'`,
conocido antes de dibujar. *Ver mi amigo secreto* pide el PIN global en un
diálogo y empuja `PantallaSecreta` directamente, sin pasar por
`PantallaLogin`.

**Sobrevive, con su razonamiento intacto:** la revisión contra el stream
de participantes (`lib/pantalla_registro.dart:199-223`). Si tu
`participanteId` desaparece de la lista, el organizador te sacó y hay que
volver a ofrecerte el alta. Esa lógica solo pierde el `olvidarIdentidad`
del disco; el resto —incluida la consulta al servidor por tu documento
concreto antes de darte por fuera— se conserva tal cual, porque resuelve
un problema real que sigue existiendo.

### Otras pantallas

- **`lib/pantalla_crear_grupo.dart`** — fuera el campo del PIN maestro.
- **`lib/pantalla_editar_grupo.dart`** — fuera el parámetro `pinMaestro`.
- **`lib/pantalla_chat.dart`** — fuera `HojaIdentidad`, fuera
  `identidad_local`, fuera el parámetro `pinMaestro`. **Esto entra en P2
  aunque el rediseño del chat sea P3**, porque `hoja_identidad.dart` se
  borra aquí y el chat es su otro consumidor. P2 deja el chat funcionando
  con autorización por cuenta y con las máscaras todavía puestas; P3 quita
  las máscaras.

### Configuración en Mis grupos

Icono nuevo en la barra de `PantallaMisGrupos` que abre una hoja con:

1. **Idioma** — el `CampoIdioma` que ya existe.
2. **Cambiar PIN** — pide contraseña de la cuenta y PIN nuevo.
3. **Cerrar sesión** — se muda aquí.

El `IconoIdioma` suelto de la barra desaparece: se muda dentro. Y *Cerrar
sesión* entra en la hoja porque dejar un icono de salir suelto al lado de
uno de ajustes que no lo contiene queda incoherente.

### Textos (ARB)

**Mueren** (verificado contra `lib/l10n/app_en.arb`):

`crearPinMaestro`, `crearPinMaestroAyuda`, `registroPin`,
`registroPinAyuda`, `registroTuPin`, `organizadorPinTexto`,
`organizadorPinCampo`, `organizadorEntrar`, `organizadorSalir`,
`organizadorActivado`, `organizadorDesactivado`, `loginTitulo`,
`loginHola`, `chatQuienEres`, `chatQuienEresTexto`, `chatCambiarPersona`.

**Se reescriben:** `registroFaltaNombre` y `registroFaltaPersonaje` dicen
hoy "falta el nombre **o el PIN**"; el PIN ya no está en ese formulario.

**Se conserva:** `errorPinIncorrecto`, que pasa a servir al PIN global.

**Nacen:** el campo de PIN en crear cuenta y su ayuda; el diálogo que pide
el PIN al revelar; el título y los campos de la hoja de configuración y de
cambiar PIN; y las claves de error `pin_formato`, `no_eres_organizador`,
`no_estas_en_el_grupo`.

Los dos ARB deben quedar con **el mismo número de claves entre sí**, que es
la invariante que importa. El total cambiará respecto a los 206 de hoy:
mueren 16 y nacen las nuevas.

## Seguridad

**Lo que mejora.** Desaparecen dos secretos en texto plano de Firestore. Y
el cliente deja de poder declarar qué participante dice ser: el servidor
lo deriva del vínculo.

**Lo que no mejora, y no hay que vender como que sí.** La contraseña de la
cuenta seguirá viajando en cada llamada, igual que hoy en `crearGrupo` y
`agregarParticipante`. No empeora, pero esto no es un modelo de tokens.
Serlo es otro proyecto.

**Lo que empeora, y es una decisión consciente.** Sin PIN maestro, la
cuenta es la única llave de tus grupos. Como no hay recuperación de
contraseña —el riesgo abierto en la bitácora del 2026-08-08— olvidarla ya
no significa solo perder el acceso a la lista: significa perder el mando
de los grupos que creaste. Antes el PIN maestro era una segunda llave.

**El anonimato del chat no cambia en P2.** El servidor siempre supo quién
escribe (lo necesita para la máscara y el anti-spam) y el documento
público sigue sin llevar nada que identifique al autor.

## Migración

**Ninguna.** No hay datos reales en producción: solo grupos de prueba del
propio desarrollador. Se borran las colecciones `grupos` y `usuarios` de
Firestore y se arranca con el modelo nuevo.

Cero código de compatibilidad, cero rutas de rescate, cero campos
opcionales "por si acaso". Si esta decisión cambia, el diseño cambia con
ella.

## Verificación

- `flutter analyze` sin advertencias.
- `flutter test`. Los tests de identidad local se van con su archivo; los
  de `destino_inicial`, `invitacion_pendiente` y `selector_idioma` no se
  tocan. Hacen falta tests nuevos para el formato del PIN y para la forma
  del mapa `grupos`.
- **Reescribir `scratchpad/probar.ps1`**, la prueba de integración contra
  producción: hoy crea el grupo con `pinMaestro` y verifica el modo
  organizador con él. Debe cubrir el camino nuevo de punta a punta,
  incluido el caso que provocó todo esto: **crear un grupo, apuntarse a
  él, y comprobar que sale UNA sola vez en la lista de la cuenta.**
- En dispositivo: crear cuenta con PIN, crear grupo, apuntarse, ver el
  grupo una vez en Mis grupos, revelar el amigo secreto con el PIN,
  cambiar el PIN desde Configuración, y comprobar que un participante que
  no es organizador no ve los controles de organizador.

## Decisiones conscientes

Quedan escritas para que nadie las lea dentro de tres meses como un
descuido:

1. **El PIN maestro desaparece del todo**, en vez de quedarse como
   alternativa para grupos sin cuenta vinculada. Coste aceptado: se pierde
   la posibilidad de pasarle el mando a otra persona compartiéndole el
   PIN, y se rompe cualquier grupo anterior — que no los hay.
2. **El PIN global no se cachea.** Se teclea en cada revelación. La
   fricción es el punto, no un efecto secundario.
3. **Cerrar sesión se muda dentro de Configuración.**

## Fuera de alcance

- **P3 — el chat sin máscaras.** Documento del mensaje de
  `{mascara, repeticion, texto, fecha}` a `{texto, color, fecha}`; color
  elegido una vez por grupo y guardado en
  `usuarios/{nick}.grupos.{cod}.colorChat`; sin espera entre mensajes;
  escribir exige ser miembro. Se lleva `lib/mascara.dart` (86 líneas),
  `obtenerMascara`, `miMascara`, `mascarasUsadas`, `ultimoMensajeMs` y 21
  claves ARB por idioma. **Decisión consciente ya tomada:** quitar el
  anti-spam deja el chat sin freno de ritmo, y como es anónimo no hay a
  quién pedirle cuentas — solo queda que el organizador borre mensaje a
  mensaje.
- **P1 — las invitaciones QR.** Borrar la lista `invitaciones_consumidas`
  y su filtro; la regla queda en "si la URL trae un código válido, se abre
  ese grupo".
- **Recuperación de contraseña.** Sigue sin existir y este diseño la hace
  más urgente, no menos.
- **Modelo de tokens** en lugar de mandar la contraseña en cada llamada.

## Orden

**P2** (este documento) → **P3** (chat) → **P1** (invitaciones QR).

P3 depende de P2 porque necesita saber quién puede escribir. P1 es
independiente de los dos y es el más pequeño.
