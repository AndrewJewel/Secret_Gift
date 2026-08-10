# 2026-08-10 — Firebase Auth, y las cosas que solo se ven mirando entero

La migración a Firebase Auth, ejecutada tarea por tarea con implementador y
revisor independientes. Doce tareas, veintitrés commits, desplegada y
probada contra producción.

Lo que sigue no es el resumen de lo que se hizo —eso está en el plan y en
los mensajes de commit— sino lo que costó y lo que enseñó.

## Lo que ninguna revisión por tarea podía ver

La revisión final de toda la rama encontró **un fallo crítico** que las once
revisiones anteriores no podían haber encontrado, porque cada una miraba
solo su propio diff.

`correoVerificado()` llamaba a `reload()`, que refresca el registro de
usuario pero **no el ID token**. El token en memoria seguía diciendo
`email_verified: false` durante una hora. El efecto para una persona real:
pincha el enlace del correo, vuelve, pulsa «Ya lo confirmé» — y la app le
responde *«verifica tu correo»*. Y otra vez. Por la única puerta que tiene
la app y por la que pasa el 100% de los registros.

**Lo instructivo es de dónde venía.** La Tarea 9 tropezó con exactamente el
mismo mecanismo en `reautenticar()`, lo entendió, lo arregló y dejó escrito
un comentario explicándolo. Nadie llevó esa lección de vuelta a la Tarea 6.
Dos tareas correctas por separado, rotas juntas.

**Y hay un segundo filo:** `scripts/probar.mjs` **no puede cazarlo por
construcción**. La batería marca el correo como verificado y luego inicia
sesión de nuevo, lo que emite un token fresco — así que el escenario del
fallo (token emitido antes de verificar, usado después) nunca se ejecuta.
Por eso quedó en la lista de verificación manual: hay fallos que ninguna
prueba automática de esta forma puede ver.

La revisión final encontró además cuatro Important y nueve Minor. Todos
arreglados en una sola ronda y re-revisados.

## Tres veces la misma trampa en el mismo fichero

`scripts/probar.mjs` es la **única** prueba que tiene el backend: no hay
tests unitarios de servidor. En esta sesión acumuló **tres** aserciones que
no comprobaban lo que su nombre prometía, y las tres estaban en verde:

1. Cuatro `ok(titulo, true)` con una constante literal. Ninguna miraba la
   respuesta del servidor.
2. Un `catch` que daba por bueno cualquier error — incluido un fallo de red
   o una URL rota.
3. «Las dos cuentas ya verificadas entran», que solo comprobaba que el
   inicio de sesión devolviera un token. **Pasó en verde con una cuenta sin
   verificar**, y la batería reventó cinco casos más adelante, lejos de la
   causa.

Las dos primeras las cazó un revisor. La tercera la cazó la realidad.

**Conclusión para futuras sesiones: mirar expresamente la higiene de las
aserciones cada vez que se toque este script.** Una prueba complaciente
aquí es peor que no tenerla, porque da permiso para desplegar.

## Lo que se midió en vez de suponerse

**La protección de enumeración de correos ya estaba activada** — es el valor
por defecto, y por eso no se encontraba la casilla que el plan mandaba
encender. Vive en Authentication → Settings → «Acciones del usuario».

Pero la duda que el revisor final dejó abierta se resolvió midiendo, y la
respuesta corrigió el spec:

| Sonda sin credenciales | Respuesta |
|---|---|
| Recuperar contraseña de un correo inexistente | 200, fingiendo éxito |
| Entrar con un correo inexistente | `INVALID_LOGIN_CREDENTIALS` |
| **Registrarse con un correo que ya existe** | **`EMAIL_EXISTS`** |

**La protección cubre dos de los tres caminos, no los tres.** Y el que falta
no se puede cerrar desde nuestro lado: la clave web va incrustada en el
cliente, así que cualquiera pregunta a Identity Toolkit directamente sin
pasar por nuestra interfaz. Un mensaje genérico en la app costaría
usabilidad sin comprar seguridad.

**La política de contraseñas estaba en nada.** La Tarea 2 borró
`validarPassword` del servidor —la contraseña la guarda Firebase ahora— y
eso dejó rigiendo el valor por defecto: seis caracteres y ninguna otra
exigencia, mientras la app seguía prometiendo ocho con mayúscula, número y
símbolo. Un comentario del código lo afirmaba y era falso.

Se activó la política en la consola para que coincida con lo que la app
pide. Y **la sonda destapó un hueco que ese cambio creaba**: el error
`PASSWORD_DOES_NOT_MEET_REQUIREMENTS` no estaba en el traductor, así que
alguien con una contraseña floja habría visto «algo salió mal» en vez de
qué le faltaba. Mapeado antes de desplegar.

## El despliegue

- Reglas, funciones y cliente desplegados.
- **`registrarCuenta` e `iniciarSesionCuenta` borradas de producción.** La
  CLI no las borra sola: hay que pedirlo explícitamente. Eso abre una
  ventana en la que la app vieja queda rota hasta desplegar el cliente.
- Colecciones `usuarios` y `grupos` **vaciadas**, y cero cuentas de Auth.
  Verificado: un grupo conocido de las pruebas devuelve 404.
- **37/37 de integración en verde** contra las funciones desplegadas.
- `flutter analyze` limpio, 36 tests unitarios.

Lo que la batería demuestra y antes no probaba nadie: que sin token y con
token falso ninguna función autoriza; que el rechazo llega por **dos capas
distintas** —sin cabecera responde nuestro código con su clave, con un token
mal formado responde la plataforma antes de llegar a nosotros—; y que el
avatar llega a Storage, es accesible y **desaparece** al borrar la plaza.

## La batería ya no se puede saltar la verificación

El paso manual entre los dos tramos era marcar `emailVerified` en la
consola. Resultó que **ese interruptor ya no está en la consola de
Firebase** —solo en Google Cloud Console → Identity Platform— y, sobre todo,
marcarlo a mano se saltaba lo único que nadie comprobaba: **que el correo
de verificación sale y que su enlace funciona**.

Ahora `--dominio tucorreo@gmail.com` crea las cuentas con direcciones `+`
sobre un buzón real y manda los enlaces de verdad. Más lento, y la única
forma de saber que esa parte funciona.

## El dominio: secretgift.app

Conectado a Hosting. El fallo que costó más vueltas fue **el proxy de
Cloudflare**: con la nube naranja, quien pregunta por el dominio recibe la
IP de Cloudflare y no la de Firebase, así que Firebase no reconocía el suyo
y no verificaba. La nube en gris —«Solo DNS»— lo resolvió al instante.

**El correo sigue cayendo en spam, y eso importa más de lo que parece.** La
verificación es bloqueante por decisión de diseño: si el enlace no llega,
no se entra. La entregabilidad dejó de ser pulido y es parte de que la app
funcione — y eso no estaba en el spec.

Se montó Resend y **empeoró**: el remitente seguía siendo el de Firebase
mientras el envío salía por Resend, así que la firma no cuadraba con quien
decía mandar el correo. Es el patrón exacto de una suplantación.

Se cambió al sistema propio de Firebase, con sus cinco registros DNS
puestos y verificados desde fuera:

- SPF `v=spf1 include:_spf.firebasemail.com ~all` en la raíz — **uno solo**,
  dos habrían invalidado los dos
- `firebase=santa-secreto-860c3` en la raíz
- Los dos CNAME de DKIM (`firebase1`/`firebase2._domainkey`)
- DMARC en `p=none`

**Queda esperando a que Firebase verifique.** Sabremos que terminó cuando el
campo «De» deje de decir `@santa-secreto-860c3.firebaseapp.com`.

Sobre autoalojar el envío, que se planteó: se descartó con datos. Las IPs de
VPS están en listas negras por defecto, un servidor nuevo empieza con
reputación cero, y desde noviembre de 2025 Gmail **rechaza** en el SMTP lo
mal autenticado en vez de mandarlo a spam. Autoalojar habría empeorado el
problema que veníamos a resolver.

## La prueba en dispositivo, y el fallo que ninguna prueba podía ver

Con todo desplegado y 37/37 en verde, la app **no dejaba crear una cuenta**.
Tres causas distintas, encadenadas, y ninguna era código nuestro.

**1. El dominio no estaba autorizado.** Al conectar `secretgift.app` a
Hosting se me pasó añadirlo a la lista de dominios autorizados de
Authentication. Firebase Auth se niega a trabajar desde un dominio que no
esté en esa lista. Se comprobó consultando la configuración pública del
proyecto —`authorizedDomains`— en vez de suponerlo.

**2. El fallo gordo: el registro de plugins de web estaba caducado.**

Flutter genera un fichero que dice qué plugins activar en web. Los que había
eran del 8 y el 9 de agosto — de **antes** de añadir `firebase_auth`— y
ninguno registraba `FirebaseAuthWeb`. Así que la app se compiló una y otra
vez sin la implementación web de Auth, y cada llamada se iba a una interfaz
sin nada detrás. Síntoma: `channel-error`.

`flutter clean` lo regeneró.

**La lección, que es lo que importa:** añadir una dependencia con parte
nativa o de web **no basta con `pub get`**. Hay que limpiar antes de
compilar, o se arrastra el registro viejo.

Y lo que lo hace peligroso: **`flutter analyze` estaba limpio y los 36 tests
en verde con la app completamente rota.** Ninguna de las dos cosas ejecuta
la app en un navegador, así que ninguna podía verlo. Tampoco los 37 casos de
integración, que hablan con el servidor por HTTP y no pasan por el cliente
Flutter.

Lo encontró el humano abriendo la app, en dos minutos. Es la justificación
más clara que ha dado esta sesión de por qué la verificación en dispositivo
no es un trámite.

**3. Un `unknown` al volver de verificar el correo**, que dejó de aparecer
con la sesión ya creada por la compilación limpia. La explicación más
probable es que fuera una sesión heredada de la compilación rota. Se
verificó después el camino completo —crear cuenta, ir al buzón, volver a la
misma pestaña sin recargar y confirmar— y entra correctamente.

**De paso quedaron dos mejoras en los mensajes de error**, salidas de lo mal
que se diagnosticó todo esto:

- `unauthorized-domain` tiene ahora su propio texto. Es un fallo de
  configuración, no del usuario: decirle «vuelve a intentarlo» era mentirle.
- El comodín de códigos desconocidos **enseña el código y el mensaje de
  Firebase**. Sin eso, «algo salió mal» no se puede diagnosticar a distancia
  — que es exactamente lo que pasó durante media hora.

## Estado y pendientes

**Verificado en dispositivo y fusionado a `main`.**

Queda pendiente **una** comprobación manual que no se llegó a hacer: que
cambiar el PIN rechaza una sesión de más de cinco minutos. Es el único
punto de la revisión que sigue sin confirmar con los ojos, y probarlo
automáticamente exigiría un `sleep` de cinco minutos.

1. **Terminar la verificación del dominio de correo** y comprobar si sale
   de spam. Después, quitar Resend de «Configuración del SMTP» y borrar sus
   tres registros DNS sueltos (`send.secretgift.app` MX y TXT, y
   `resend._domainkey`), que hoy no molestan.
4. **La plantilla del correo está solo en inglés.** El código pide el idioma
   de cada persona con `setLanguageCode`, pero sin plantilla en español
   llega la inglesa igual. No se tocó a propósito: no está claro si el
   selector de la consola elige qué versión editas o cambia el idioma por
   defecto de todos, y no era momento de cambiar dos cosas a la vez.
5. **P4 (reemplazar participante) y notificaciones push** — specs escritos
   el 2026-08-09, sin plan todavía. P4 sigue siendo el hueco que deja a un
   grupo sorteado sin salida si alguien se cae.
6. **A4: App Check y limitación de peticiones.** Sigue abierto.
