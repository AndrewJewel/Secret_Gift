# Diseño — La cuenta como puerta de entrada

**Fecha:** 2026-08-08
**Estado:** aprobado, pendiente de plan de implementación

## Qué se cambia y por qué

Hoy la app abre en `PantallaInicio`, que ofrece *Crear grupo*, *Unirme con
un código* y, abajo del todo en letra pequeña, *Mi cuenta*. La cuenta es
opcional y parece un extra.

El problema no es el orden de las pantallas: **esa pantalla no se
explica**. No se entiende qué es "Mi cuenta", si hace falta, ni cuándo.
Y como consecuencia casi nadie crea una, así que los grupos se quedan
atados al dispositivo.

La decisión es hacer la cuenta obligatoria y convertirla en la primera
pantalla. Quien abre la app crea su cuenta o entra con la suya, y de ahí
pasa a gestionar sus grupos.

## Flujo

```
PORTERO (raíz de la app)
   │
   ├─ ¿hay sesión guardada?
   │     │
   │     ├─ sí ──→ ¿hay invitación pendiente?
   │     │            ├─ sí ──→ dentro del grupo  (y se borra la invitación)
   │     │            └─ no ──→ Mis grupos
   │     │
   │     └─ no ──→ CREAR CUENTA  ←──────────→  INICIAR SESIÓN
   │                     └────────┬────────────────┘
   │                              └──→ grupo (si hay invitación) o Mis grupos
   │
   └─ Si la URL trae ?codigo=XXXX, se guarda como invitación pendiente
      ANTES de decidir destino.
```

## Las invitaciones

Compartir un grupo genera `https://…/?codigo=XXXX-XXXX` (QR o enlace).
Quien lo abre **sí pasa por la creación de cuenta** — es una decisión
explícita del producto—, pero la invitación no se pierde: sobrevive al
registro y al terminar entra directamente al grupo a crear su nombre de
juego.

**La invitación se guarda en `shared_preferences`, no en memoria.** Entre
que la persona llega y termina de crear la cuenta puede recargar la
página o el navegador puede descartar el estado. Si viviera en memoria,
se perdería la invitación y acabaría en un "Mis grupos" vacío sin
entender qué pasó.

**Se borra en cuanto se usa.** Si no, la siguiente apertura de la app
volvería a meter a esa persona en ese grupo para siempre.

**Se valida antes de guardar.** El portero lee el documento del grupo
para comprobar que el código existe. De paso obtiene el nombre del grupo,
que se usa en la pantalla de cuenta.

## Pantallas

### Crear cuenta — la que se abre por defecto

```
┌───────────────────────────────────────┐
│              [ logo ]                 │
│             Secret Gift               │
│                                       │
│  Create your account to discover      │
│  who sends you the secret gifts       │
│                                       │
│  Language            [ English  ▾ ]   │
│  Nickname            [__________]     │
│  Password            [__________]     │
│  Confirm password    [__________]     │
│                                       │
│         ( Create account )            │
│                                       │
│   Already have an account? Sign in    │
└───────────────────────────────────────┘
```

El idioma es **una casilla más del formulario**, no un icono en la
esquina. Cambia el idioma de toda la app al instante y se guarda, como
hasta ahora.

Cuando se llega por invitación, la frase larga se sustituye por
**"You've been invited to *«nombre del grupo»*"**. Sin eso, quien escanea
un QR ve un formulario de registro sin contexto y abandona.

### Iniciar sesión

Misma cabecera (logo y nombre), sin la frase larga y **sin selector de
idioma**: quien vuelve ya tiene su idioma guardado, y quien llega desde
un dispositivo nuevo pasa antes por "crear cuenta", donde sí está la
casilla. Solo nickname, contraseña y el enlace inverso a crear cuenta.

### Mis grupos

Gana lo que hoy vive en `PantallaInicio` y le falta para ser autónoma:

- **Crear un grupo nuevo**
- **Unirme con un código**
- **Icono de cambio de idioma** en la barra superior — es el único sitio
  donde se puede cambiar una vez dentro
- Cerrar sesión (ya existe), que ahora devuelve a *Crear cuenta*

**Debe recargar la lista al volver** de crear o unirse a un grupo. Hoy
recibe los grupos como una lista fija que nunca se actualiza, así que un
grupo recién creado no aparecería.

### `PantallaInicio` se elimina

Su única función no cubierta es *"Continuar en X"* (el último grupo de
este dispositivo), redundante ahora que Mis grupos lista todos.

## Identidad: dos cosas separadas

Esta separación **ya existe en la base de datos y no se toca**. Se
documenta porque el cambio la hace más visible:

```
usuarios/{nickname_normalizado}          ← LA CUENTA (una, global)
    nickname   "Andres"                    tal como se escribió
    hash       bcrypt, coste 10            la contraseña nunca se guarda
    fecha      timestamp del servidor
    grupos     [ {codigo, participanteId, rol}, … ]   punteros

grupos/{codigo}/participantes/{id}       ← EL PERSONAJE (uno por grupo)
    nombre     "Papá Noel"
    avatarUrl
    tieneAmigo
```

**El nickname sirve solo para entrar.** El nombre de juego se pide
siempre, en blanco, en cada grupo — nunca se propone el nickname. En un
grupo con temática eres tu personaje; en el de la oficina, tu nombre.

Esto también protege el chat anónimo: los mensajes llevan solo el número
de máscara. Si el nombre de juego fuera el nickname, el anonimato se
rompería solo.

**La unión es un puntero, no una copia.** Desde
`grupos/{codigo}/participantes/{id}` no hay forma de llegar a una cuenta.

## Cambio en el backend

`vincularCuentaSiAplica` (`functions/index.js`) hoy **falla en silencio**:
si las credenciales no cuadran, registra a la persona en el grupo igual y
no lo vincula. Con la cuenta opcional era lo correcto — no romper el alta
por un extra.

Con la cuenta obligatoria deja de serlo: el grupo no aparecería en "Mis
grupos" y nadie sabría por qué. Pasa a lanzar un error visible.

## Manejo de errores

| Situación | Qué pasa |
|---|---|
| Nickname ya en uso | Error del servidor, ya existe (`nickname_en_uso`) |
| Contraseña débil | Se valida en el cliente antes de llamar |
| Las contraseñas no coinciden | Se valida en el cliente |
| Código de invitación inexistente | No se guarda invitación; sigue el flujo normal |
| Sin conexión en el portero | Va a crear cuenta / Mis grupos según sesión; la invitación se reintenta la próxima vez |
| Vinculación de cuenta fallida | Error visible (cambio nuevo) |

## Pruebas

- El portero enruta bien en los cuatro casos: con/sin sesión × con/sin
  invitación pendiente.
- La invitación sobrevive a una recarga en mitad del registro.
- La invitación se borra tras usarse y no reaparece.
- Mis grupos muestra un grupo recién creado sin salir y volver a entrar.
- Cambiar el idioma en la casilla afecta a toda la app y persiste.

## Fuera de alcance, anotado

1. **Recuperación de contraseña.** No existe: las cuentas son nickname +
   contraseña, sin correo ni teléfono. Con la cuenta ya obligatoria, una
   contraseña olvidada es perder el acceso a los grupos de esa cuenta.
   Es el riesgo más serio que abre este cambio.
2. **La exigencia de la contraseña.** Hoy pide 8+ caracteres con
   mayúscula, minúscula, número y símbolo. Para una app de amigo secreto
   familiar es exigente, y ahora es obligatorio para todos. Combinado con
   el punto 1, cada contraseña olvidada es una cuenta perdida.
