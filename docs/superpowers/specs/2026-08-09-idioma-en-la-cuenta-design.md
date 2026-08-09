# Diseño — El idioma va con la cuenta

**Fecha:** 2026-08-09
**Estado:** aprobado, pendiente de plan de implementación
**Rama prevista:** una nueva, **después** de fusionar `cuenta-como-identidad`.

## Qué se cambia y por qué

El idioma vive hoy en `shared_preferences` — `localStorage` en web — vía
`lib/idioma.dart`. Eso significa que la elección se recuerda **en ese
navegador**, no en la persona.

Lo destapó una prueba en dispositivo: alguien eligió español, entró a su
cuenta desde otro navegador, y la app arrancó en inglés. No era un fallo;
era el diseño funcionando como estaba escrito (`idioma.dart` lo dice
literalmente: *"la elección se recuerda en el dispositivo"*).

Pero ese diseño es de cuando las cuentas eran opcionales. Con la cuenta ya
obligatoria y siendo la identidad de la app —ver
`2026-08-09-cuenta-como-identidad-design.md`— el idioma es una preferencia
de la persona, no del cristal desde el que mira. Debe seguirla.

## El modelo

### Dónde vive

Campo `idioma` en `usuarios/{nick}`, con el mismo código de dos letras que
ya usa la app: `"en"` o `"es"`.

### Cuándo se escribe

- **`registrarCuenta`** pasa a recibir `idioma` y lo guarda con el resto
  del perfil. El valor es el que estuviera elegido en la pantalla de crear
  cuenta, que ya tiene su casilla de idioma.
- **`cambiarIdioma({nickname, password, idioma})`** — función nueva, para
  los cambios posteriores. Autoriza por cuenta como todo lo demás
  (`verificarCuenta`), y valida que el idioma sea uno de los soportados.

### Cuándo se lee

`iniciarSesionCuenta` lo devuelve junto al nickname y los grupos.
`ResultadoAcceso` (`lib/acceso_cuenta.dart`) gana el campo, y quien maneja
la entrada lo aplica.

### Dónde vive la lógica en el cliente

**En `Idioma.cambiar()`, no en el widget.** Fija el valor, guarda en disco
como ahora, y si hay sesión abierta intenta además escribirlo en la cuenta.

`CampoIdioma` (`lib/selector_idioma.dart`) **no se toca**. Se usa antes de
tener cuenta (crear cuenta, iniciar sesión) y después (Configuración), y
debe seguir funcionando igual en los dos sitios sin saber en cuál está.
Centralizar en `Idioma.cambiar()` es lo que lo permite.

### El disco no desaparece: cambia de papel

Sigue haciendo falta como **valor previo al login**. Las pantallas de crear
cuenta e iniciar sesión no tienen ninguna cuenta de la que leer, y quien no
entienda inglés necesita poder cambiarlo justo ahí — que es la razón por la
que `CampoIdioma` existe.

Pasa de ser la verdad a ser la caché y el punto de partida.

### Quién gana

La cuenta, al iniciar sesión. Como cambiar el idioma escribe en los dos
sitios, no divergen salvo si la escritura al servidor falla.

### Cuentas anteriores a este cambio

No tienen el campo. Si `iniciarSesionCuenta` lo devuelve vacío, **no se
toca nada** y se conserva el idioma del dispositivo. Se corrige solo la
primera vez que esa persona cambie el idioma. Sin migración.

## Si la escritura al servidor falla

**Se calla.** El idioma cambia en pantalla y se guarda en el dispositivo;
el fallo de red no se le muestra a nadie.

Es el mismo trato que `idioma.dart` ya le da a la escritura en disco, con
este comentario: *"El cambio ya se aplicó en pantalla aunque no se pueda
guardar."*

**La consecuencia conocida, escrita para que no sorprenda a nadie:** el
caso no se cura solo. Como el dispositivo sí guardó la elección, esa
persona sigue viendo su idioma y no tiene ningún motivo para volver a tocar
el selector — así que la cuenta se queda con el valor viejo hasta que lo
cambie otra vez por su cuenta. Lo descubriría al abrir otro navegador.

Se acepta a sabiendas: avisar de un fallo de red por una preferencia de
interfaz cuesta más atención de la que vale, y la tercera opción que se
consideró —no cambiar el idioma hasta que el servidor confirme— convertiría
un cambio instantáneo en uno que depende de la red y puede fallar del todo.

## Verificación

- `flutter analyze` sin advertencias y todos los tests en verde.
- Los dos ARB con el mismo conjunto de claves. **Este cambio no necesita
  ninguna clave nueva**: no hay mensajes nuevos que mostrar, precisamente
  porque el fallo se calla.
- Un caso nuevo en `scripts/probar.mjs`, contra el backend desplegado:
  registrar una cuenta con `idioma: "es"`, comprobar que
  `iniciarSesionCuenta` lo devuelve, llamar a `cambiarIdioma` con `"en"`, y
  comprobar que ahora devuelve `"en"`.
- En dispositivo: elegir español, cerrar sesión, entrar **desde otro
  navegador**, y ver que arranca en español. Ese es el caso que originó
  todo y el único que prueba de verdad el cambio.

## Fuera de alcance

- **Detectar el idioma del teléfono.** `idioma.dart` ya señala dónde se
  haría; sigue sin pedirse.
- **Más idiomas.** Siguen siendo dos.
- **Reintentar la escritura fallida**, o guardarla para mandarla luego.
- **Tocar `CampoIdioma`** o añadir pantallas.
