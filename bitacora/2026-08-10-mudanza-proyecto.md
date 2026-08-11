# 2026-08-10 (tarde) — La mudanza a `secretgift-app`

Mover la app entera de un proyecto Firebase a otro, porque el identificador
del viejo no se podía cambiar y salía donde lo veía la gente.

## Por qué, y por qué no era estética

`santa-secreto-860c3` aparecía en el **enlace del correo de verificación**,
mientras el remitente decía `noreply@secretgift.app`.

Remitente de un sitio, enlace a otro. Es exactamente el patrón que a la
gente le enseñan a desconfiar — y la verificación de correo es
**bloqueante**: si no pinchan ese enlace, no entra nadie.

Yo lo llamé cosmético dos veces. **Me equivocaba**, y lo que zanjó la
discusión fue que el humano pegara el enlace real y se viera la
contradicción de un vistazo.

Se intentó personalizar la URL de acción en la consola de Firebase y en
Google Cloud: falla al guardar con un error genérico, sin decir qué rechaza.
Con un proyecto cuyo identificador ya dice `secretgift`, **no hay nada que
personalizar**: el valor por defecto ya es coherente.

## Lo que se descartó, y por qué

Se propuso generar el enlace con el Admin SDK y mandarlo por un proveedor
propio. Se descartó porque:

- **El enlace generado sigue llevando el dominio del proyecto.** El
  `actionCodeSettings.url` decide a dónde va la persona *después* de
  verificar, no el dominio del manejador.
- Solo habría arreglado el correo. **Las URLs de los avatares**
  —`santa-secreto-860c3.firebasestorage.app`, visibles en el código de la
  página— y las llamadas a las funciones seguirían igual.
- Y dejaba tres piezas nuevas que mantener para siempre: una función que
  genera y envía, un proveedor de correo, y una pantalla propia para el
  `oobCode`.

Cambiaba un problema de configuración por complejidad permanente, y a medias.

## La deducción que salió mal, y para bien

El diseño decía que el dominio del correo **no podría estar en dos proyectos
a la vez**, porque dos de sus registros son CNAME con nombre fijo. De ahí
salía una ventana prevista de hasta un día con el remitente sin marca.

**Era falso, y se vio mirando el valor con atención:**

```
mail-secretgift-app.dkim1._domainkey.firebasemail.com
```

Ese `mail-secretgift-app` sale del **dominio** `secretgift.app`, no del
proyecto. Los CNAME sirven para los dos.

De los cuatro registros que pedía el proyecto nuevo, **tres ya estaban
puestos e idénticos**. Solo hubo que añadir un TXT — y como los TXT admiten
varios valores, los dos `firebase=` convivieron sin pisarse.

**Resultado: cero ventana sin remitente de marca.** El correo funcionó sin
interrupción durante toda la mudanza.

La lección no es sobre DNS: es que una deducción razonable no es un hecho, y
comprobarla costó una consulta.

## El orden que sí se respetó

**El dominio del hosting se movió al final**, con el proyecto nuevo ya
desplegado y con los 37 casos de integración en verde. Así, mientras se
trabajaba, `secretgift.app` seguía sirviendo el proyecto viejo y volver
atrás era cambiar una línea.

## Lo que costó tiempo

- **Las reglas de Storage** fallaron con `firebase deploy --only
  storage:rules` («Could not find rules for the following storage targets»)
  y funcionaron con **`--only storage`** a secas.
- **El primer despliegue de funciones dio varios 409** al crear el bucket
  interno de las fuentes. La CLI reintentó sola y las quince se crearon.
- **El hosting devolvió 404 justo tras desplegar** y 200 un minuto después:
  era el sitio levantándose, no un fallo.
- **Firebase avisó de que faltaba política de limpieza** de imágenes de
  contenedor. Se puso con `firebase functions:artifacts:setpolicy --force`:
  sin ella se acumulan y generan factura.

## Lo que se arregló de paso

**El enlace de invitación del QR apuntaba a
`santa-secreto-860c3.web.app`.** Es lo primero que ve quien es invitado a un
grupo, y era un fallo que ya existía. Ahora apunta a `secretgift.app`.

## Lo que NO se tocó, y por qué

- **`lib/ocasion.dart`.** Su `'santa_secreto'` es el identificador de la
  ocasión «amigo secreto» y **vive dentro de los documentos de cada grupo**.
  Un buscar-y-reemplazar global lo habría cambiado y roto los datos. Por eso
  cada uno de los siete sitios se cambió a mano.
- **`pubspec.yaml`.** El paquete Dart sigue llamándose `santa_secreto`: no
  lo ve ningún usuario y renombrarlo obliga a tocar diez ficheros de test.

## Decisiones del correo

- **Las plantillas se quedan en inglés.** La app arranca en inglés, así que
  el correo en inglés no desentona. Consecuencia asumida: quien use la app
  en español también recibirá el correo en inglés, porque sin plantilla en
  español llega la inglesa igual.
- El nombre del proyecto se cambió a **Secret Gift** para que `%APP_NAME%`
  deje de firmar los correos como «secretgift-app».

## Estado

| | |
|---|---|
| Proyecto | `secretgift-app` (997384680563) |
| Reglas, 15 funciones, hosting | Desplegados |
| Integración | **37/37** contra el proyecto nuevo |
| `secretgift.app` | Sirve el proyecto nuevo, comprobado byte a byte |
| Dominio de correo | Verificado, sin interrupción |
| Proyecto viejo | **Sigue entero y no se borra** |

## Estado del repositorio al cerrar

Fusionado a `main` y empujado a GitHub el mismo día (`26c6d01`).

| | |
|---|---|
| `main` | Tiene el código apuntando a `secretgift-app`, sincronizado con GitHub |
| Producción | El proyecto nuevo, desplegado y sirviendo `secretgift.app` |
| Rama `mudanza-secretgift-app` | Contenida en `main`, se puede borrar |

**Se fusionó sin haber hecho la prueba en el navegador, y a propósito.** El
razonamiento: producción YA corría ese código —se había desplegado horas
antes—, así que fusionar no añadía riesgo. Lo que sí quitaba era una trampa
real: mientras `main` tuviera el código viejo, desplegar desde ahí habría
apuntado al proyecto anterior **sin dar ningún error**, porque sigue vivo y
responde. Habría escrito en la base de datos equivocada en silencio.

La prueba en el navegador sigue pendiente, pero ya solo confirma; no bloquea.

## Pendientes

### 1. ~~Probar en el navegador~~ — HECHO

Comprobado por el humano el 2026-08-11: la app funciona en
`https://secretgift.app` sobre el proyecto nuevo. Con esto la mudanza queda
cerrada.

### 2. ~~Fusionar y empujar~~ — HECHO

Fusionado y empujado el 2026-08-10 (`26c6d01`). La rama
`mudanza-secretgift-app` está contenida en `main` y se puede borrar.

### 3. Android — la versión móvil NO funcionaría

- `android/app/google-services.json` **sigue siendo del proyecto viejo**
- El paquete sigue siendo `com.example.santa_secreto`

No bloquea nada hoy porque la app se usa por web, pero si se compilara el
APK ahora, apuntaría al proyecto viejo.

Lo que habría que hacer: registrar la app Android en `secretgift-app` con el
paquete **`app.secretgift`**, descargar el `google-services.json` nuevo, y
cambiar `namespace` y `applicationId` en `android/app/build.gradle.kts`, el
`package` de `MainActivity.kt`, y mover ese fichero a
`android/app/src/main/kotlin/app/secretgift/`.

`com.example` es el valor de ejemplo de Flutter y **Google Play no lo
acepta**, así que hay que cambiarlo igualmente antes de publicar. Está
detallado en la Tarea 4 del plan.

### 4. Limpieza de DNS en Cloudflare

Cuatro registros que ya no sirven. **Ninguno molesta**, así que sin prisa:

| Registro | Por qué sobra |
|---|---|
| `send.secretgift.app` MX → `feedback-smtp.us-east-1.amazonses.com` | De Resend, que se descartó |
| `send.secretgift.app` TXT → `v=spf1 include:amazonses.com ~all` | De Resend |
| `resend._domainkey` TXT | De Resend |
| `secretgift.app` TXT → `firebase=santa-secreto-860c3` | Del proyecto viejo |

**No tocar** los otros: el `A`, los dos CNAME `firebase*._domainkey`, el
`v=spf1 include:_spf.firebasemail.com`, el `firebase=secretgift-app`, el
`hosting-site=secretgift-app` y el `_dmarc`.

Y la regla que costó dos vueltas: **todos en «Solo DNS», nube gris.** Con el
proxy de Cloudflare activado, Firebase no puede verificar el dominio ni
emitir el certificado.

### 5. Qué hacer con el proyecto viejo

`santa-secreto-860c3` sigue entero: quince funciones desplegadas, Firestore,
Storage y hosting. **Facturando lo que facture.**

Se dejó a propósito como vuelta atrás. Conviene decidir cuándo apagarlo —
pero no antes de que el paso 1 esté confirmado y hayan pasado unos días.

### 6. Detalles del correo

- **Las plantillas están en inglés**, decidido a sabiendas: la app arranca en
  inglés. Consecuencia: quien la use en español también recibirá el correo
  en inglés.
- Comprobar en el próximo correo que la firma ya dice **«Your Secret Gift
  team»** y no «secretgift-app» — se cambió el nombre del proyecto para eso
  pero no se ha visto un correo desde entonces.

### 7. Comprobación de seguridad que sigue sin hacerse

**Que cambiar el PIN rechaza una sesión de más de cinco minutos.** Es lo
único de la revisión de la migración a Auth que nunca se confirmó con los
ojos, y probarlo automáticamente exigiría un `sleep` de cinco minutos dentro
de una batería que tarda segundos.

Cómo: entrar en la app, esperar más de cinco minutos sin cerrar sesión, e
intentar cambiar el PIN desde Configuración. **Debe pedir la contraseña.**

### 8. Trabajo pendiente de antes de la mudanza

Por orden de valor:

1. **P4 — reemplazar participante.** Spec aprobado el 2026-08-09, sin plan
   todavía. **Es el único pendiente que arregla algo que le puede pasar a
   alguien usando la app**: hoy, si alguien se cae de un grupo ya sorteado,
   no hay ninguna salida. Y esta sesión lo empeoró indirectamente, porque se
   cerró la entrada tras el sorteo — que era el apaño improvisado.
2. **Notificaciones push (FCM).** Spec escrito. Va después de P4, que es su
   primer y único cliente.
3. **Despliegue automático desde GitHub.** Diseño aprobado y escrito el
   2026-08-10. Decidido: se despliegan la app y las reglas, no las
   funciones; se dispara en cada push a `main`; y hace falta añadirle un rol
   a la cuenta de servicio en Google Cloud.
4. **P3** (chat sin máscaras), **P1** (invitaciones QR), **idioma en la
   cuenta** (spec escrito).
5. **A4: App Check y limitación de peticiones.** Abierto desde la auditoría
   del 2026-08-09.
