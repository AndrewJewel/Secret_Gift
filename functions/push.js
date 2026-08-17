const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

/**
 * De una respuesta de `sendEachForMulticast`, qué tokens hay que borrar.
 *
 * Se separa en una función pura porque es la única parte de todo esto con
 * lógica de verdad, y porque probarla contra FCM de verdad exigiría un
 * dispositivo que se desregistra a voluntad.
 *
 * SOLO borra ante los dos códigos que significan "este token ya no
 * existe". Un fallo pasajero de FCM —servidor caído, cuota— NO borra
 * nada: si lo hiciera, un mal minuto de FCM desengancharía dispositivos
 * sanos y esa gente dejaría de recibir avisos para siempre sin enterarse.
 */
function tokensMuertos(respuesta, tokens) {
  const respuestas = respuesta?.responses || [];
  const muertos = [];
  respuestas.forEach((r, i) => {
    if (r.success) return;
    const codigo = r.error?.code;
    if (codigo === "messaging/registration-token-not-registered" ||
        codigo === "messaging/invalid-registration-token") {
      muertos.push(tokens[i]);
    }
  });
  return muertos;
}

/**
 * Manda un aviso a todos los dispositivos de una cuenta.
 *
 * NUNCA lanza. Quien la llama ya escribió en Firestore: un reemplazo que
 * funcionó no puede deshacerse porque una notificación no saliera. Todos
 * los fallos se registran y se siguen.
 *
 * Los tokens muertos se limpian aquí mismo, con la respuesta del envío.
 * Así el mapa no crece para siempre y no hace falta ningún trabajo
 * programado.
 */
async function avisar(uid, {titulo, cuerpo, datos} = {}) {
  if (!uid) return;
  try {
    const db = getFirestore();
    const ref = db.collection("usuarios").doc(uid);
    const snap = await ref.get();
    const tokens = Object.keys(snap.data()?.tokensPush || {});
    if (tokens.length === 0) return;

    const respuesta = await getMessaging().sendEachForMulticast({
      tokens,
      notification: {title: titulo, body: cuerpo},
      data: datos || {},
    });

    const muertos = tokensMuertos(respuesta, tokens);
    if (muertos.length > 0) {
      const borrado = {};
      for (const t of muertos) borrado[t] = FieldValue.delete();
      await ref.set({tokensPush: borrado}, {merge: true});
    }
  } catch (e) {
    // A propósito: registrar y seguir.
    console.error(`aviso fallido para ${uid}:`, e);
  }
}

/**
 * Lo mismo para varias cuentas a la vez.
 *
 * `Promise.all` y no un bucle con await: el sorteo de un grupo de veinte
 * personas haría veinte viajes en serie y la función se pasaría el rato
 * esperando. Como `avisar` nunca lanza, aquí no hace falta capturar nada.
 */
async function avisarAVarios(uids, aviso) {
  const unicos = [...new Set((uids || []).filter(Boolean))];
  await Promise.all(unicos.map((uid) => avisar(uid, aviso)));
}

module.exports = {tokensMuertos, avisar, avisarAVarios};
