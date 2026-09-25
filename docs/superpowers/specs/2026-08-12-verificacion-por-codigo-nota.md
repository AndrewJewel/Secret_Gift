# Nota — Por qué el enlace de verificación no se puede poner en nuestro dominio

**Fecha:** 2026-08-12
**Estado:** callejón sin salida confirmado. NO volver a intentarlo.

## Qué se quiso hacer, y por qué

El correo de verificación manda un enlace largo que empieza por
`secretgift-app.firebaseapp.com`, un dominio que quien recibe el correo
**no reconoce**. Mucha gente es precavida con los enlaces largos de
dominios raros y no pincha — y como la verificación es **bloqueante**,
quien no pincha **no entra en la app**. No es estética: es gente que se
queda fuera.

La idea era usar la opción de Firebase «Personalizar URL de acción» para
que el enlace empezara por `secretgift.app`, el mismo dominio del
remitente y de la app. Seguiría siendo largo, pero el principio —que es
lo único que la gente mira— sería reconocible.

## Por qué no se puede

**La consola no deja guardar ninguna URL de acción.** Probado el
2026-08-12 con dos valores distintos:

- `https://secretgift.app/__/auth/action` (el manejador de Firebase
  servido en nuestro dominio) → error
- `https://secretgift.app/verificar` (una ruta cualquiera, para
  descartar que el problema fuera la ruta reservada `/__/`) → **el mismo
  error**

Como fallan las dos, no es la ruta: es que no deja guardar nada.

**Y ya había fallado antes**, en el proyecto anterior
`santa-secreto-860c3`, con el mismo error genérico y sin decir qué
rechaza (ver la bitácora del 2026-08-10). Dos proyectos distintos, dos
intentos, el mismo resultado.

Lo que SÍ está comprobado es que el destino funcionaría:
`https://secretgift.app/__/auth/action` responde 200 y sirve el
manejador real de Firebase, con su `action.js`. El problema es
exclusivamente que la consola no guarda el ajuste.

## Qué queda como salida

**Sustituir el enlace por un código de un solo uso**, que se teclea
dentro de la app y nunca obliga a salir de ella. Idea del humano, y
resuelve el problema de raíz: sin enlace no hay desconfianza que valga.

Beneficio añadido, que no es menor: **elimina de golpe toda una familia
de fallos que costó dos días** —la pestaña que el navegador congela al
salir al buzón, y el flujo de correos entero— porque todos venían de lo
mismo: salir de la app y volver.

Lo que arrastra, para no engañarse:

- **Un proveedor de correo propio.** Firebase solo manda sus plantillas
  con enlace; no deja enviar un correo con contenido nuestro.
- Generar y guardar el código cifrado, con caducidad.
- **Protección contra fuerza bruta**: seis dígitos son un millón de
  combinaciones. Ya existe ese patrón en el proyecto para el PIN.
- Marcar la cuenta como verificada desde el servidor con el Admin SDK.
  Eso sí se puede.

El contador hacia atrás que pedía el humano es lo barato de todo esto,
una vez existe el código con caducidad.

**Pendiente de diseñar con calma.** No se hace sobre la marcha: toca el
camino de entrada a la app, que es justo lo que se acaba de estabilizar.
