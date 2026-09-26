// Textos de los avisos push, en los dos idiomas de la app (es y en).
//
// Cada dispositivo guarda su idioma junto a su token (`idiomasPush` en
// usuarios/{uid}, lo manda la app en `guardarTokenPush`) y `avisar` le manda
// el texto que toca. Todo aviso nuevo va aquí, con sus dos idiomas: la
// prueba «cada aviso existe en los dos idiomas» de push.test.js lo exige.
//
// Se leen en la pantalla de bloqueo, con el teléfono en la mano de
// cualquiera: nunca dicen quién escribió, qué dice un mensaje ni quién le
// regala a quién.

const IDIOMAS = ["es", "en"];

// Tokens guardados antes de que la app mandara el idioma: siguen recibiendo
// español, que es lo que siempre recibieron, hasta que la app lo mande.
const IDIOMA_POR_DEFECTO = "es";

function idiomaValido(idioma) {
  return IDIOMAS.includes(idioma);
}

const AVISOS = {
  sorteo: (grupo) => ({
    es: {titulo: "¡Ya hay amigo secreto!", cuerpo: `En «${grupo}». Entra a ver a quién te toca.`},
    en: {titulo: "The draw is done!", cuerpo: `In “${grupo}”. Open it to see who you got.`},
  }),
  mensaje: (grupo) => ({
    es: {titulo: "Nuevo mensaje", cuerpo: `En «${grupo}».`},
    en: {titulo: "New message", cuerpo: `In “${grupo}”.`},
  }),
  // Va solo a quien le regala a la plaza que cambió de manos: no puede
  // decir nada del par (ver la prueba del reemplazo en push.test.js).
  novedades: (grupo) => ({
    es: {titulo: "Novedades en tu grupo", cuerpo: `Algo cambió en «${grupo}». Ábrelo para verlo.`},
    en: {titulo: "News in your group", cuerpo: `Something changed in “${grupo}”. Open it to see.`},
  }),
};

module.exports = {AVISOS, IDIOMAS, IDIOMA_POR_DEFECTO, idiomaValido};
