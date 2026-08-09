# Diseño — Firebase Auth como identidad

**Fecha:** 2026-08-09
**Estado:** aprobado, pendiente de plan de implementación
**Rama prevista:** propia, **después** de fusionar `cuenta-como-identidad` y
**después** de los cuatro arreglos de seguridad baratos (ver §Orden).

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

**Dos caminos:**

- **Google.** Un toque en Android, que es donde vive esta app. Google ya
  verificó el correo, así que Firebase lo marca verificado solo.
- **Correo y contraseña.** Para quien no tenga cuenta de Google o prefiera
  no vincularla. La recuperación la cubre `sendPasswordResetEmail`.

Se descartó el modelo sin contraseña (enlace por correo) porque obliga a ir
al buzón **en el momento de escanear un QR**, que es el peor sitio posible
para meter fricción en esta app. Y se descartó "solo Google" por dejar
fuera a quien no quiera vincular su cuenta.

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

**Por qué la fricción es asumible.** Con Google no ocurre nunca. Y el camino
del QR **ya sobrevive a una interrupción**: la invitación se persiste en
disco y el código sigue en la URL — se construyó en P2 justamente para que
alguien pudiera recargar a mitad del registro sin perder el grupo. Ir al
buzón y volver es ese mismo caso.

## El modelo de identidad

### La cuenta es el `uid`

`usuarios/{nicknameNormalizado}` pasa a ser **`usuarios/{uid}`**, con:

| Campo | De dónde sale |
|---|---|
| `nombre`, `apellido` | del formulario, o de `displayName` con Google |
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
PIN exige **reautenticarse**: `reauthenticateWithCredential` en el cliente
—teclear la contraseña de nuevo, o un Google fresco—.

**Y el servidor tiene que comprobarlo, o no sirve de nada.** Un atacante con
el dispositivo tiene un token válido y puede llamar a `cambiarPin`
directamente, saltándose la pantalla: si la reautenticación vive solo en el
cliente, es teatro. Así que `cambiarPin` verifica en el servidor que la
sesión sea **reciente**, leyendo el claim `auth_time` del token y exigiendo
que no supere unos minutos. Reautenticarse actualiza ese claim; el token
viejo del atacante no lo tiene.

Esa comprobación del servidor es lo que cierra de verdad el hallazgo que la
auditoría marcó como el más grave.

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
  nombre, apellido y PIN, más el botón de Google.
- **Pantalla nueva de espera de verificación**, con reenviar y comprobar.
- **`lib/hoja_configuracion.dart`**: cambiar el PIN pasa por
  reautenticación.

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
  pantalla de verificación, el botón de Google, los campos de nombre y
  apellido, la reautenticación, y los errores de Auth traducidos.
- **`scripts/probar.mjs` hay que rehacerlo.** Hoy autentica con apodo y
  contraseña. Con Auth tiene que pedir tokens a la API REST de Firebase Auth
  (`signUp` / `signInWithPassword` con la clave web del proyecto) y mandarlos
  como *bearer*. Se puede sin dependencias nuevas, pero es trabajo real —
  y es la única prueba de verdad que tiene el backend, así que no es
  opcional.
- En dispositivo: registrarse con correo, **comprobar que no se entra sin
  verificar**, verificar y entrar; registrarse con Google y comprobar que no
  pide verificación; recuperar la contraseña desde el enlace; y cambiar el
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
- **La enumeración de correos.** Firebase Auth distingue por defecto entre
  "ese correo no existe" y "contraseña incorrecta". Se puede cerrar
  activando la protección contra enumeración en la consola; conviene, y es
  configuración, no código.

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
3. **Dos métodos de entrada en vez de uno**, con el mantenimiento que
   implica, para no dejar fuera a quien no quiera vincular Google.
4. **El perfil se crea con una llamada explícita**, no con un disparador de
   Auth.

## Fuera de alcance

- **Más proveedores** (Apple, teléfono).
- **Segundo factor.**
- **Exponer el nombre real al organizador** — el dato queda disponible, la
  decisión no está tomada.
- **Migrar `funciones.dart` al paquete `cloud_functions`**; el bug de
  dart2js sigue ahí.
