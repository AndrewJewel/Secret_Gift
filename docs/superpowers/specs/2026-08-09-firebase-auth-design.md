# Diseño — Firebase Auth como identidad

**Fecha:** 2026-08-09
**Estado:** aprobado, con plan de implementación en
`docs/superpowers/plans/2026-08-09-firebase-auth.md`
**Rama prevista:** propia. Sus dos requisitos previos se cumplieron el
2026-08-09: `cuenta-como-identidad` fusionada en `main` y los cuatro
arreglos baratos de seguridad hechos, desplegados y probados.

## Qué se cambia y por qué

La app no usa Firebase Auth. Las cuentas son `usuarios/{nicknameNormalizado}`
con un hash bcrypt de la contraseña, el cliente guarda **nickname y
contraseña** en `shared_preferences` —`localStorage` en web— y las quince
Cloud Functions autorizan recibiendo `{nickname, password}` en cada llamada.

Ese modelo se construyó cuando no había cuentas y creció por encima. La
auditoría de seguridad del 2026-08-09 puso número a lo que cuesta:

1. **La contraseña vive en `localStorage`, en claro.** Quien tenga tu
   navegador la lee con las herramientas de desarrollo, y con ella se fija
   un PIN nuevo y ve tu amigo secreto. El PIN existe para frenar
   exactamente a ese atacante y contra él no aporta nada.
2. **No hay recuperación de contraseña.** Riesgo abierto desde que las
   cuentas se volvieron obligatorias: olvidarla es perder el mando de tus
   grupos para siempre.
3. **Las reglas de Firestore no pueden decir "tú"**, porque no hay identidad
   de cliente. Cada regla es `if true` o `if false`, sin término medio.
4. **No hay límite de intentos** contra el inicio de sesión.
5. **Se puede averiguar si un apodo está registrado** por la diferencia
   entre `nickname_no_existe` y `password_incorrecta`.

**No hay datos reales que migrar** — solo grupos de prueba del
desarrollador. Es el momento más barato en que esto se podrá hacer: con
gente dentro sería una migración de cuentas cuyas contraseñas nadie puede
releer.

## Con qué se entra

**Un solo camino: correo y contraseña.** La recuperación la cubre
`sendPasswordResetEmail`, que es lo que hoy no existe y el motivo principal
de toda esta migración.

**Se descartó añadir Google a propósito**, aun siendo un toque en Android.
Un segundo proveedor trae ramificación por `providerData` en cada sitio que
reautentique, manejo de ventana emergente con su alternativa por
redirección, y dos caminos que mantener y probar en vez de uno. No compensa
para una app de este tamaño.

También se descartó el modelo sin contraseña (enlace por correo) porque
obliga a ir al buzón **en el momento de escanear un QR**, que es el peor
sitio posible para meter fricción aquí.

**La consecuencia de quedarse con un solo método, dicha claramente:** Google
era el camino que se saltaba la verificación del correo, porque Google ya la
ha hecho. Sin él, **el enlace de verificación lo recibe el 100% de los
registros**, incluido quien escanea un QR en una fiesta. Se asume: es el
precio de que la recuperación funcione de verdad, y añadir Google más
adelante sigue siendo posible sin rehacer nada de lo demás.

### La verificación del correo es obligatoria y bloqueante

Quien se registra con correo y contraseña ve una pantalla de espera: *"te
hemos enviado un enlace"*, con botón de reenviar y de comprobar. **No entra
a la app hasta pinchar.**

**Por qué obligatoria.** El correo entra en el diseño para poder recuperar
la cuenta. Un correo sin verificar es un camino de recuperación que quizá no
existe: si alguien se registra con una dirección inventada, hemos añadido el
campo, la fricción y el código, y esa persona sigue sin poder recuperar
nada — el problema que veníamos a resolver, intacto.

**Por qué bloqueante y no parcial.** Un estado intermedio ("puedes entrar
pero no revelar tu amigo") es un estado más que mantener y probar, y deja a
gente a medias durante semanas sin enterarse.

**Por qué la fricción es asumible.** El camino del QR **ya sobrevive a una
interrupción**: la invitación se persiste en
disco y el código sigue en la URL — se construyó en P2 justamente para que
alguien pudiera recargar a mitad del registro sin perder el grupo. Ir al
buzón y volver es ese mismo caso.

## El modelo de identidad

### La cuenta es el `uid`

`usuarios/{nicknameNormalizado}` pasa a ser **`usuarios/{uid}`**, con:

| Campo | De dónde sale |
|---|---|
| `nombre`, `apellido` | del formulario de registro |
| `correo` | de Auth |
| `pinHash` | bcrypt, como hoy |
| `grupos` | el mapa por código que ya existe, sin cambios |

**Desaparecen** el `hash` de la contraseña —lo guarda Firebase— y la
unicidad del apodo. Con ella se va el oráculo de "este apodo existe".

### El apodo desaparece; se piden nombre y apellido

Hoy el apodo **es** la cuenta: identifica, es único, y se muestra como
*"Hola, Andres"*. Pasa a no existir.

**Es una escalada de privacidad y se asume a sabiendas.** La app pedía un
apodo; ahora pide nombre y apellido reales. La diferencia que la hace
aceptable: ese nombre es **de la cuenta, no del grupo**. Dentro de cada
grupo cada quien sigue registrándose con el nombre o el personaje que
quiera, y eso es lo único que ven los demás participantes. **El nombre real
no se muestra a nadie más que a su dueño.**

De paso deja resuelto el dato que pide un pendiente abierto desde el
2026-08-07 —*"nombre real visible solo para el organizador"*—, que existía
porque en un grupo temático el organizador no puede saber si ya se apuntaron
todos los que invitó. **Exponerlo al organizador NO es parte de este
diseño**; solo queda el dato disponible para cuando se decida.

### El PIN sobrevive, y protegerlo mejora

El PIN sigue teniendo trabajo: el token de Auth persiste en el dispositivo
igual que persistía la contraseña, así que quien coja tu móvil desbloqueado
sigue teniendo sesión abierta.

Lo que cambia es **cómo se protege cambiarlo**. Hoy basta la contraseña, que
está en `localStorage` al alcance del mismo atacante. Con Auth, cambiar el
PIN exige **reautenticarse**: `reauthenticateWithCredential` en el cliente,
tecleando la contraseña de nuevo. Y ahora la contraseña **no** está guardada
en ningún sitio del que el atacante pueda sacarla.

**Y el servidor tiene que comprobarlo, o no sirve de nada.** Un atacante con
el dispositivo tiene un token válido y puede llamar a `cambiarPin`
directamente, saltándose la pantalla: si la reautenticación vive solo en el
cliente, es teatro. Así que `cambiarPin` verifica en el servidor que la
sesión sea **reciente**, leyendo el claim `auth_time` del token y exigiendo
que no supere unos minutos. Reautenticarse actualiza ese claim; el token
viejo del atacante no lo tiene.

Esa comprobación del servidor es lo que cierra de verdad el hallazgo que la
auditoría marcó como el más grave.

**Con un solo proveedor, la pantalla no ramifica:** siempre es un campo de
contraseña. Esa simplicidad es parte de por qué se descartó Google — con
dos proveedores habría que mirar `providerData` en cada sitio que
reautentique y ofrecer un botón distinto a cada quien.

Si algún día se añade Google, **este es uno de los sitios a revisar**: quien
entre por ahí no tendrá contraseña que teclear y necesitará un botón de
*"confirma con Google"* en su lugar.

## Qué cambia en el código

### Servidor

- **Las quince funciones dejan de recibir `{nickname, password}`** y leen
  `request.auth.uid`. **El `autorizar()` construido en P2 se conserva
  entero** — solo cambia de dónde saca la clave de la cuenta. Las guardas
  `exigirOrganizador` y `exigirParticipante` no se tocan.
- **`registrarCuenta` e `iniciarSesionCuenta` desaparecen.** El registro lo
  hace Auth; el perfil lo crea una función nueva **`guardarPerfil({nombre,
  apellido, pin})`**, que el cliente llama una vez tras registrarse. Se
  eligió una llamada explícita en vez de un disparador de Auth por ser más
  simple de probar y no depender de la semántica de triggers entre v1 y v2.
- **La lista de grupos sigue necesitando una función**, renombrada a
  **`misGrupos()`** y autorizada por `uid`. Es lo que hoy hace la segunda
  mitad de `iniciarSesionCuenta`: resolver cada código contra `grupos/`,
  descartar los que ya no existen, y **borrar del mapa las claves muertas**.
  Esa limpieza es una escritura sobre `usuarios/{uid}`, que sigue cerrada al
  cliente, así que no puede hacerse desde la app por mucho que ahora pueda
  leer su propio documento.
- **Lo que el cliente sí gana con las reglas nuevas** es leer su perfil
  —nombre, apellido, correo— sin gastar una llamada. Los grupos no.
- **`bcryptjs` se queda, pero solo para el PIN.**
- **`verificarCuenta` desaparece**; `autorizar` recibe el `uid` ya
  verificado por Firebase.

### Reglas de Firestore

`usuarios/{uid}` pasa de `read, write: if false` a:

```
match /usuarios/{uid} {
  allow read: if request.auth != null && request.auth.uid == uid;
  allow write: if false;   // sigue escribiendo solo el Admin SDK
}
```

Primera vez que estas reglas pueden expresar "tú". La escritura sigue
cerrada: el `pinHash` y el mapa `grupos` los toca solo el servidor.

El resto de reglas **no cambia**, incluido el `allow list: if false` de
`grupos` que se cerró hoy.

### Cliente

- **`lib/sesion.dart` desaparece entero.** El SDK de Auth persiste la sesión
  y refresca el token solo. No hay nada que guardar ni que leer.
- **`lib/acceso_cuenta.dart` se reescribe** contra `FirebaseAuth`.
- **La pantalla de crear cuenta cambia de campos**: correo, contraseña,
  nombre, apellido y PIN.
- **Pantalla nueva de espera de verificación**, con reenviar y comprobar.
- **Enlace *"he olvidado mi contraseña"* en la pantalla de entrar** (ver
  abajo).
- **`lib/hoja_configuracion.dart`**: cambiar el PIN pasa por
  reautenticación.

### Recuperar la contraseña

Siendo el único método de entrada, **este es el único camino de vuelta a
una cuenta**. No es un extra: es la mitad del motivo de migrar.

- Un enlace *"he olvidado mi contraseña"* bajo el formulario de entrar,
  que pide el correo y llama a `sendPasswordResetEmail`.
- **La respuesta es siempre la misma**, exista la cuenta o no: *"si esa
  dirección tiene cuenta, te hemos mandado un enlace"*. Decir *"ese correo
  no está registrado"* recrearía el oráculo de existencia que la migración
  viene a cerrar — el mismo fallo que hoy tiene `iniciarSesionCuenta`, en
  una pantalla nueva.
- **La pantalla de poner la contraseña nueva la aloja Firebase.** No hay
  que construirla. Su idioma sale de `FirebaseAuth.instance.setLanguageCode`,
  así que hay que fijarlo con el idioma elegido antes de mandar el correo o
  el mensaje llega en inglés a todo el mundo.

**Lo que la recuperación NO recupera: el PIN.** Su hash lo guardamos
nosotros y nadie puede releerlo. Quien olvide el PIN lo cambia
reautenticándose —es decir, con la contraseña—, que es justo lo que sigue
teniendo tras recuperarla. **Los dos secretos no se pueden perder a la
vez**, y eso es lo que hace que el diseño se sostenga.

### El detalle que rompe tarde si no se ve pronto

`lib/funciones.dart` **no usa el paquete `cloud_functions`** — llama a las
funciones por HTTP crudo, porque su implementación web tiene un bug conocido
en dart2js ([flutterfire#17924](https://github.com/firebase/flutterfire/issues/17924)).

Eso sigue funcionando con Auth, pero hay que **añadir a mano la cabecera
`Authorization: Bearer <idToken>`**. El protocolo *callable* la verifica y es
lo que rellena `request.auth` en el servidor. **Si se olvida, las quince
funciones ven `request.auth` vacío y la app entera deja de autorizar** — y
fallaría de golpe, no gradualmente.

## Migración

**Ninguna.** Se borran `usuarios` y `grupos` en Firestore y se arranca
limpio, igual que se hizo en P2. Cero código de compatibilidad.

## Verificación

- `flutter analyze` sin advertencias y todos los tests en verde.
- Los dos ARB con el mismo conjunto de claves. Habrá claves nuevas: la
  pantalla de verificación, los campos de nombre y apellido, la
  recuperación de contraseña, la reautenticación, y los errores de Auth
  traducidos.
- **`scripts/probar.mjs` hay que rehacerlo.** Hoy autentica con apodo y
  contraseña. Con Auth tiene que pedir tokens a la API REST de Firebase Auth
  (`signUp` / `signInWithPassword` con la clave web del proyecto) y mandarlos
  como *bearer*. Se puede sin dependencias nuevas, pero es trabajo real —
  y es la única prueba de verdad que tiene el backend, así que no es
  opcional.
- En dispositivo: registrarse, **comprobar que no se entra sin verificar**,
  verificar y entrar; recuperar la contraseña desde el enlace; y cambiar el
  PIN comprobando que **exige reautenticarse**.

## Lo que esta migración NO arregla

Dicho para que no haya sorpresas:

- **La lista de participantes y el chat siguen siendo legibles por quien
  tenga el código del grupo.** Es el mecanismo de invitación: quien recibe
  una invitación tiene que poder ver el grupo antes de entrar. Con Auth lo
  más que se gana es exigir sesión iniciada, y crear cuenta es gratis.
- **Los cuatro arreglos baratos de la auditoría** (entrar a un grupo ya
  sorteado, repetir el sorteo, el contador del PIN sin transacción,
  `Math.random()`). Van antes, no después — ver abajo.
- **La enumeración de correos al REGISTRARSE.** Este párrafo decía antes que
  la protección de la consola lo cerraba todo. **Se midió contra el proyecto
  real el 2026-08-09 y no es así**, así que queda corregido:

  | Sonda sin credenciales contra Identity Toolkit | Respuesta |
  |---|---|
  | `sendOobCode` (recuperar) con correo inexistente | 200, fingiendo éxito |
  | `signInWithPassword` con correo inexistente | `INVALID_LOGIN_CREDENTIALS` |
  | **`signUp` con un correo que ya existe** | **`EMAIL_EXISTS`** |

  Entrar y recuperar sí quedan cerrados por la protección contra
  enumeración —que en este proyecto **ya estaba activada**, es el valor por
  defecto—. Registrarse no.

  **Y no se puede cerrar desde nuestro lado.** La clave web va incrustada en
  el cliente, así que cualquiera llama a `signUp` directamente y pregunta
  por el correo que quiera; nuestra interfaz no está en ese camino. Poner un
  mensaje genérico en la app escondería el dato a un curioso y a nadie más:
  se pagaría usabilidad —quien ya tiene cuenta merece que se le diga— sin
  comprar nada de seguridad.

  Se asume. Lo que se gana con Auth en este frente son dos de los tres
  caminos, no los tres.

## Orden

1. **Fusionar `cuenta-como-identidad` a `main`.** Sigue 53 commits por
   detrás y producción corre código que solo existe en la rama.
2. **Los cuatro arreglos de seguridad baratos.** Quince líneas cada uno y
   están en producción hoy. No tiene sentido dejarlos abiertos mientras se
   construye algo de días.
3. **Esta migración.**

Los otros pendientes (P4 reemplazar participante, P3 chat sin máscaras, P1
invitaciones QR, el idioma en la cuenta) son independientes de esta y se
ordenan aparte.

## Decisiones conscientes

Quedan escritas para que nadie las lea dentro de tres meses como un
descuido:

1. **Se piden nombre y apellido reales**, en una app que antes solo pedía un
   apodo y cuyas temáticas existen para no usar el nombre real. Se acepta
   porque el nombre es de la cuenta y nunca se muestra a otros
   participantes.
2. **La verificación del correo bloquea el acceso**, con la fricción que eso
   mete en el camino del QR.
3. **Un solo método de entrada.** Se renunció a Google —un toque en
   Android— por no mantener dos caminos. El coste es que ya nadie se salta
   la verificación del correo.
4. **El perfil se crea con una llamada explícita**, no con un disparador de
   Auth.

## Fuera de alcance

- **Google y cualquier otro proveedor** (Apple, teléfono). Añadir Google
  más adelante no obliga a rehacer nada, pero sí a revisar los sitios que
  reautentican.
- **Segundo factor.**
- **Exponer el nombre real al organizador** — el dato queda disponible, la
  decisión no está tomada.
- **Migrar `funciones.dart` al paquete `cloud_functions`**; el bug de
  dart2js sigue ahí.
