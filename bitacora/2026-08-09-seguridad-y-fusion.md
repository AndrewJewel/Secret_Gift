# 2026-08-09 — El agujero de verdad, cuatro arreglos, y `main` al día

Sesión que empezó puliendo un diseño y acabó cerrando la puerta que llevaba
meses abierta.

## Lo primero, porque es lo que importaba

`firestore.rules` tenía `allow read: if true` en `grupos`. **`read` son dos
permisos**: `get` (un documento) y `list` (la colección entera). Sin
Firebase Auth, ese `true` es literalmente cualquiera en internet.

Lo comprobé contra producción con un GET sin token y volvieron documentos
reales. Con los códigos de todos los grupos vienen detrás los nombres, los
avatares y los chats "anónimos" de cada uno.

El arreglo estaba commiteado desde ayer y **sin desplegar**, que es lo mismo
que no tenerlo. Hoy se desplegó y se verificó en vivo:

| Petición sin credenciales | Antes | Ahora |
|---|---|---|
| `LIST /grupos` | 200, la colección entera | **403** |
| `GET /grupos/GS7S-DNA7` | 200 | 200 (la app lo necesita) |
| `LIST /usuarios` | 403 | 403 |

Los cinco accesos del cliente son `.doc(codigo)`, así que cerrar `list` no
le quita nada. El código del grupo vuelve a ser lo que debía ser: la única
llave para llegar a él.

**La lección, escrita para no repetirla:** un arreglo commiteado no protege
a nadie. Entre `git commit` y `firebase deploy` no hay nada automático.

## Los cuatro arreglos baratos

Los cuatro salían de la auditoría de ayer y llevaban todo el día vivos en
producción. Antes de tocarlos volví a leer el código para confirmar que
seguían ahí — una auditoría no es una excusa para no mirar.

**1. Se podía entrar a un grupo ya sorteado.** `agregarParticipante` no
miraba `sorteado`. Quien entrara quedaba fuera de la cadena: sin amigo
asignado y sin nadie que le regalara. El grupo parece normal y el fallo se
ve el día de la entrega, cuando ya no hay arreglo.

Necesitó clave de error propia. Reutilizar `grupo_ya_sorteado` habría
enseñado *«a esta persona no se la puede sacar»* a quien acaba de escanear
un QR.

**2. El sorteo se podía repetir.** Rebarajaría a gente que ya vio su
asignación y quizá ya compró el regalo, sin que se enterara nadie. Y era lo
que sostenía las otras dos reglas: la bandera `sorteado` no significa nada
si el sorteo puede volver a correr.

**3. El contador del PIN.** Este es el que más se resistió a un arreglo
correcto.

El problema obvio era que el contador se leía en `autorizar` y se escribía
después: cien peticiones en paralelo leían todas cero y escribían todas uno.
Pero **ponerlo en una transacción no bastaba**: contando *después* de
comparar, esas cien peticiones ya habrían pasado la comprobación de bloqueo
con el mismo dato viejo y ejecutado sus cien `bcrypt`. El atacante se lleva
cien respuestas antes de que la primera escriba nada — el contador quedaría
perfecto y la puerta abierta igual.

Así que se invierte el orden: **el intento se reserva antes de
comprobarlo**. Las cien se serializan en la transacción, cinco se llevan un
intento y noventa y cinco salen bloqueadas sin llegar a comparar.

Detalle que también se decidió a conciencia: el veredicto sale de la
transacción como valor de retorno, no como excepción. Lanzar desde dentro
haría depender el resultado de cómo clasifique el SDK ese error para decidir
si reintenta la transacción, y eso no nos lo ha prometido nadie.

Cuesta una escritura de más por revelación acertada. Revelar tu amigo
secreto se hace una vez por grupo.

**4. `Math.random()`.** V8 lo implementa con xorshift128+: con unas pocas
salidas consecutivas se reconstruye su estado interno. De ahí salían tres
cosas y las tres son secretos — el código del grupo (ocho llamadas
seguidas, así que quien cree un par de grupos propios tiene material de
sobra), la cadena del sorteo, y las máscaras del chat.

El del código de grupo **subió de gravedad hoy mismo**: mientras la
colección entera era descargable, predecir códigos era un agujero al lado de
otro mayor. Cerrado el `list`, el código pasó a ser la única llave.

Los cinco usos van ahora por `crypto.randomInt`.

## Verificación

`scripts/probar.mjs` ganó los dos casos de los guardas nuevos, porque un
guarda que nadie comprueba es una suposición. El de "no se puede entrar"
usa a propósito la cuenta que **ya está dentro** y espera `grupo_cerrado`,
no `ya_estas_en_el_grupo`: la bandera se mira antes de autorizar, así que si
saliera la otra clave sería que el guarda no está donde se puso.

**25/25 en verde** contra las funciones desplegadas, incluida toda la
secuencia de bloqueo del PIN, que es la que ejercita la transacción nueva.
Más `flutter analyze` limpio y 30 tests.

**Un susto que no lo era:** el primer `firebase deploy --only functions`
falló con *"User code failed to load. Cannot determine backend
specification. Timeout after 10000"*. Antes de tocar nada comprobé que el
módulo carga localmente en 180 ms, lo que descartaba el `require("node:crypto")`
recién añadido. Era el tiempo de espera de descubrimiento de la CLI. El
segundo intento pasó.

## `main` al día

`main` llevaba 65 commits de retraso: producción corría código que solo
existía en una rama. Fusionado con `--no-ff` para que quede un punto
identificable y revertible.

Antes de fusionar: `flutter analyze` limpio, 30 tests, 25/25 de
integración. Después: `git diff main cuenta-como-identidad` vacío y las tres
verificaciones repetidas sobre `main`.

`flujo-cuenta` resultó ser ancestro de `cuenta-como-identidad`, así que ya
está contenida y se puede borrar.

## Diseño: Firebase Auth pierde a Google

Se quitó el acceso con Google del spec. Con un solo proveedor desaparecen la
ramificación por `providerData`, el manejo de ventana emergente con su
alternativa por redirección, y dos caminos que mantener.

**El precio, escrito donde se vea:** Google era el camino que se saltaba la
verificación del correo. Ahora el enlace al buzón lo recibe el 100% de los
registros, incluido quien escanea un QR en una fiesta. La justificación que
yo mismo había dado a esa fricción —«con Google esto no ocurre nunca»— quedó
sin valor, y se dijo en vez de dejarla caer.

Recuperar la contraseña ganó sección propia, siendo ya el único camino de
vuelta a una cuenta. Tres decisiones que no son opcionales: la misma
respuesta exista o no la cuenta (o recreamos el oráculo de existencia que
veníamos a cerrar), `setLanguageCode` antes de mandar el correo, y que el
PIN no se recupera pero se cambia con la contraseña — **los dos secretos no
se pueden perder a la vez**, y eso es lo que hace que el diseño se sostenga.

## Plan de Auth: 12 tareas

`docs/superpowers/plans/2026-08-09-firebase-auth.md`.

El troceado no sale de la arquitectura sino de una restricción concreta:
`flutter analyze` tiene que quedar limpio al cerrar cada tarea. Eso obliga a
que las pantallas suelten `sesion.dart` **antes** de que nadie lo borre, así
que el fichero muere en la Tarea 9 —la última que lo importa— y no en la que
lo deja obsoleto.

Las tres tareas de servidor se cierran con revisión, no con ejecución: el
backend no tiene tests unitarios y su única prueba real es `probar.mjs`
contra lo desplegado. Queda escrito para que nadie lo lea como cobertura.

Escribiendo el plan comprobé contra el código todo lo que iba a dar por
supuesto, y **ocho suposiciones eran falsas**: `Idioma.actual` es un
`ValueNotifier<Locale>` y no un getter plano; `t.cerrarSesion` y `t.volver`
no existen (son `misGruposCerrarSesion` y `cerrar`); las claves
`errorNickname*` solo viven en el `switch` de `funciones.dart`, no en las
pantallas; `debeFallar` ya existía en `probar.mjs`; y `cambiarPinTexto`
sigue siendo literalmente cierto con Auth, así que la reautenticación no
necesita ni una clave ARB nueva.

## Qué queda

1. **Empujar `main` a GitHub.** Va 71 commits por delante de `origin/main` y
   no se ha hecho: no se pidió.
2. **Ejecutar el plan de Auth.** Sus dos requisitos previos ya están
   cumplidos. Antes de la Tarea 12 hay que habilitar Email/Password en la
   consola y activar la protección de enumeración de correos.
3. **Borrar las colecciones** `usuarios` y `grupos` — parte de la Tarea 12.
4. **P4**: reemplazar participante. Sigue siendo el hueco que bloquea a un
   grupo sorteado si alguien se cae, y hoy se cerró la única salida que
   quedaba (entrar tarde). Es ahora más urgente que ayer.
5. **P3** (chat sin máscaras), **P1** (invitaciones QR), **idioma en la
   cuenta** (spec escrito).
6. **A4**: App Check y limitación de peticiones. Sigue abierto.
7. **Node 20 se retira el 2026-10-30.** Aviso en cada despliegue.
