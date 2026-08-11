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

## Pendientes

1. **`android/app/google-services.json` sigue siendo del proyecto viejo**, y
   el paquete sigue en `com.example.santa_secreto`. No bloquea nada porque
   la app se usa por web, pero **la versión Android no funcionaría** hasta
   hacerlo. `com.example` es el valor de ejemplo de Flutter y Google Play no
   lo acepta, así que habrá que cambiarlo igualmente antes de publicar.
2. **Tres registros DNS huérfanos de Resend**: `send.secretgift.app` MX y
   TXT, y `resend._domainkey`. No molestan.
3. **El TXT `firebase=santa-secreto-860c3`** ya no hace falta.
4. **Decidir qué hacer con el proyecto viejo.** Sigue con sus funciones
   desplegadas y facturando lo que facture.
5. **El despliegue automático desde GitHub**, con diseño aprobado y sin
   hacer.
6. **P4 — reemplazar participante.** Sigue siendo el único pendiente que
   arregla algo que le puede pasar a alguien usando la app.
