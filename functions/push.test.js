const test = require("node:test");
const assert = require("node:assert");
const Module = require("node:module");

// `avisar`/`avisarAVarios` hablan con Firestore y con FCM a través de
// `firebase-admin`, y ese es justo el contrato que hay que probar: que
// pase lo que pase ahí fuera, la promesa que ve quien llama SIEMPRE se
// resuelve. No hay emulador aquí, así que se sustituyen los dos módulos
// de `firebase-admin` por dobles ANTES de la primera vez que se cargue
// `./push` — Node cachea `require`, así que si `push.js` ya cargó la
// versión real no hay forma de cambiarla después. Se inyecta el doble
// directamente en `require.cache`, indexado por la misma ruta resuelta
// que usaría el `require` real, así ambos módulos ven exactamente el
// mismo objeto.
function sustituirModulo(especificador, exportaciones) {
  const resuelto = require.resolve(especificador);
  const modulo = new Module(resuelto);
  modulo.exports = exportaciones;
  modulo.loaded = true;
  require.cache[resuelto] = modulo;
}

// Estado compartido y mutable que los dobles leen en cada llamada. Cada
// test lo deja como lo necesita antes de invocar `avisar`/`avisarAVarios`
// y lo limpia con `reiniciar()` al terminar.
const estado = {
  usuarios: {}, // uid -> {datos} | {error}
  enviosFcm: [], // cada llamada real a sendEachForMulticast
  comportamientoFcm: null, // (request) => respuesta | lanza
};

function reiniciar() {
  estado.usuarios = {};
  estado.enviosFcm = [];
  estado.comportamientoFcm = null;
}

sustituirModulo("firebase-admin/firestore", {
  FieldValue: {delete: () => "__campo_borrado__"},
  getFirestore: () => ({
    collection: () => ({
      doc: (uid) => ({
        async get() {
          const config = estado.usuarios[uid] || {};
          if (config.error) throw config.error;
          return {data: () => config.datos};
        },
        async set() {
          // No hace falta grabar esto: la limpieza de tokens muertos ya
          // la cubren los tests de `tokensMuertos`. Aquí solo importa que
          // no reviente.
        },
      }),
    }),
  }),
});

sustituirModulo("firebase-admin/messaging", {
  getMessaging: () => ({
    async sendEachForMulticast(request) {
      estado.enviosFcm.push(request);
      if (estado.comportamientoFcm) return estado.comportamientoFcm(request);
      return {responses: request.tokens.map(() => ({success: true}))};
    },
  }),
});

const {tokensMuertos, avisar, avisarAVarios} = require("./push");

test("devuelve solo los tokens que FCM dice que ya no existen", () => {
  const tokens = ["vivo", "muerto", "otro-vivo"];
  const respuesta = {
    responses: [
      {success: true},
      {success: false, error: {code: "messaging/registration-token-not-registered"}},
      {success: true},
    ],
  };
  assert.deepStrictEqual(tokensMuertos(respuesta, tokens), ["muerto"]);
});

test("un fallo pasajero NO borra el token", () => {
  // Si se borrara, un corte de red de FCM desengancharía dispositivos
  // sanos y esa persona dejaría de recibir avisos para siempre sin
  // enterarse. Solo se borra ante la respuesta que dice que el token ya
  // no existe.
  const tokens = ["vivo"];
  const respuesta = {
    responses: [{success: false, error: {code: "messaging/server-unavailable"}}],
  };
  assert.deepStrictEqual(tokensMuertos(respuesta, tokens), []);
});

test("también borra el token con formato inválido", () => {
  const tokens = ["basura"];
  const respuesta = {
    responses: [{success: false, error: {code: "messaging/invalid-registration-token"}}],
  };
  assert.deepStrictEqual(tokensMuertos(respuesta, tokens), ["basura"]);
});

test("sin respuestas no borra nada y no revienta", () => {
  assert.deepStrictEqual(tokensMuertos({responses: []}, []), []);
  assert.deepStrictEqual(tokensMuertos({}, []), []);
});

test("avisar no lanza si falla la lectura de Firestore", async (t) => {
  // Quien llama a `avisar` ya escribió en Firestore. Si esta promesa se
  // rechazara, un reemplazo que sí funcionó le saldría a esa persona como
  // un error y podría rehacerlo sin necesidad.
  t.mock.method(console, "error", () => {});
  reiniciar();
  estado.usuarios["u1"] = {error: new Error("Firestore no responde")};

  await assert.doesNotReject(() => avisar("u1", {titulo: "t", cuerpo: "c"}));
});

test("avisar no lanza si falla el envío de FCM", async (t) => {
  t.mock.method(console, "error", () => {});
  reiniciar();
  estado.usuarios["u2"] = {datos: {tokensPush: {tokA: 1}}};
  estado.comportamientoFcm = () => {
    throw new Error("FCM no responde");
  };

  await assert.doesNotReject(() => avisar("u2", {titulo: "t", cuerpo: "c"}));
});

test("avisar no manda nada ni revienta si la cuenta no tiene tokens", async () => {
  reiniciar();
  estado.usuarios["u3"] = {datos: {tokensPush: {}}};

  await assert.doesNotReject(() => avisar("u3", {titulo: "t", cuerpo: "c"}));
  assert.strictEqual(estado.enviosFcm.length, 0);
});

test("avisar no lanza si la llaman sin el segundo argumento", async (t) => {
  // Punto ciego real: `avisar(uid)` desestructuraba un `undefined` en la
  // propia firma y, al ser `async`, eso devolvía una promesa rechazada
  // ANTES de entrar al try/catch — justo lo contrario del contrato de
  // esta función.
  t.mock.method(console, "error", () => {});
  reiniciar();
  estado.usuarios["u4"] = {datos: {tokensPush: {}}};

  await assert.doesNotReject(() => avisar("u4"));
});

test("avisarAVarios no deja que un uid roto se lleve por delante a los demás", async (t) => {
  t.mock.method(console, "error", () => {});
  reiniciar();
  estado.usuarios["bueno1"] = {datos: {tokensPush: {tok1: 1}}};
  estado.usuarios["malo"] = {error: new Error("Firestore no responde")};
  estado.usuarios["bueno2"] = {datos: {tokensPush: {tok2: 1}}};

  await assert.doesNotReject(() =>
    avisarAVarios(["bueno1", "malo", "bueno2"], {titulo: "t", cuerpo: "c"}));

  // Los dos que sí tenían Firestore sano recibieron su envío igual; el
  // roto no se llevó a nadie por delante.
  const tokensEnviados = estado.enviosFcm.flatMap((r) => r.tokens);
  assert.ok(tokensEnviados.includes("tok1"));
  assert.ok(tokensEnviados.includes("tok2"));
  assert.strictEqual(estado.enviosFcm.length, 2);
});
