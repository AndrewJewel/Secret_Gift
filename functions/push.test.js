const test = require("node:test");
const assert = require("node:assert");
const {tokensMuertos} = require("./push");

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
