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
  escrituras: [], // cada set() sobre usuarios/{uid}
  comportamientoFcm: null, // (request) => respuesta | lanza
};

function reiniciar() {
  estado.usuarios = {};
  estado.enviosFcm = [];
  estado.escrituras = [];
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
        async set(cambios) {
          estado.escrituras.push({uid, cambios});
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
const {AVISOS} = require("./avisos");

// Un aviso cualquiera, en los dos idiomas.
const T = {es: {titulo: "t-es", cuerpo: "c-es"}, en: {titulo: "t-en", cuerpo: "c-en"}};

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

  await assert.doesNotReject(() => avisar("u1", {textos: T}));
});

test("avisar no lanza si falla el envío de FCM", async (t) => {
  t.mock.method(console, "error", () => {});
  reiniciar();
  estado.usuarios["u2"] = {datos: {tokensPush: {tokA: 1}}};
  estado.comportamientoFcm = () => {
    throw new Error("FCM no responde");
  };

  await assert.doesNotReject(() => avisar("u2", {textos: T}));
});

test("avisar no manda nada ni revienta si la cuenta no tiene tokens", async () => {
  reiniciar();
  estado.usuarios["u3"] = {datos: {tokensPush: {}}};

  await assert.doesNotReject(() => avisar("u3", {textos: T}));
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

test("el aviso del reemplazo no deja deducir quién regala a quién", () => {
  // El aviso de `reemplazarParticipante` va SOLO a quien le regala a la
  // plaza que acaba de cambiar de manos, y quién ocupaba esa plaza es
  // público dentro del grupo. Un texto como «Tu amigo secreto cambió» en
  // la pantalla de bloqueo le entrega el par a cualquiera que mire el
  // móvil, sin desbloquear siquiera — justo lo que esta app protege
  // poniendo la asignación detrás de un PIN. En los DOS idiomas.
  const fs = require("node:fs");
  const path = require("node:path");
  const fuente = fs.readFileSync(path.join(__dirname, "index.js"), "utf8");
  const inicio = fuente.indexOf("avisar(uidRegala, {");
  assert.notStrictEqual(inicio, -1,
      "cambió el aviso del reemplazo: revisa este test antes de tocarlo");
  assert.ok(fuente.slice(inicio, fuente.indexOf("});", inicio)).includes("AVISOS.novedades("),
      "el aviso del reemplazo ya no usa AVISOS.novedades: revisa este test");

  const aviso = AVISOS.novedades("Familia Pérez");
  const prohibidos = ["amigo secreto", "te regala", "te toca",
    "secret friend", "secret santa", "gives you", "you got", "your match"];
  for (const idioma of ["es", "en"]) {
    const texto = `${aviso[idioma].titulo} ${aviso[idioma].cuerpo}`.toLowerCase();
    for (const prohibido of prohibidos) {
      assert.ok(!texto.includes(prohibido),
          `el aviso del reemplazo (${idioma}) menciona «${prohibido}»: revela el par`);
    }
  }
});

test("avisarAVarios no deja que un uid roto se lleve por delante a los demás", async (t) => {
  t.mock.method(console, "error", () => {});
  reiniciar();
  estado.usuarios["bueno1"] = {datos: {tokensPush: {tok1: 1}}};
  estado.usuarios["malo"] = {error: new Error("Firestore no responde")};
  estado.usuarios["bueno2"] = {datos: {tokensPush: {tok2: 1}}};

  await assert.doesNotReject(() =>
    avisarAVarios(["bueno1", "malo", "bueno2"], {textos: T}));

  // Los dos que sí tenían Firestore sano recibieron su envío igual; el
  // roto no se llevó a nadie por delante.
  const tokensEnviados = estado.enviosFcm.flatMap((r) => r.tokens);
  assert.ok(tokensEnviados.includes("tok1"));
  assert.ok(tokensEnviados.includes("tok2"));
  assert.strictEqual(estado.enviosFcm.length, 2);
});

test("cada aviso existe en los dos idiomas y lleva el nombre del grupo", () => {
  for (const [nombre, crear] of Object.entries(AVISOS)) {
    const aviso = crear("Oficina 2026");
    for (const idioma of ["es", "en"]) {
      assert.ok(aviso[idioma]?.titulo, `${nombre}.${idioma} sin título`);
      assert.ok(aviso[idioma]?.cuerpo.includes("Oficina 2026"), `${nombre}.${idioma} sin grupo`);
    }
    assert.notStrictEqual(aviso.es.titulo, aviso.en.titulo, `${nombre}: el inglés copia al español`);
  }
});

test("cada dispositivo recibe el aviso en su idioma", async () => {
  reiniciar();
  estado.usuarios["u"] = {datos: {
    tokensPush: {movilEs: 1, pcEn: 2, viejo: 3},
    idiomasPush: {movilEs: "es", pcEn: "en"},
  }};
  await avisar("u", {textos: T, datos: {codigo: "X"}});

  const porToken = {};
  for (const envio of estado.enviosFcm) {
    for (const token of envio.tokens) porToken[token] = envio.notification.title;
    assert.deepStrictEqual(envio.data, {codigo: "X"});
  }
  assert.deepStrictEqual(porToken, {movilEs: "t-es", pcEn: "t-en",
    // Guardado antes de que la app mandara el idioma: sigue en español,
    // como siempre recibió.
    viejo: "t-es"});
});

test("al limpiar un token muerto se borra también su idioma", async () => {
  reiniciar();
  estado.usuarios["u"] = {datos: {tokensPush: {muerto: 1}, idiomasPush: {muerto: "en"}}};
  estado.comportamientoFcm = () => ({responses: [
    {success: false, error: {code: "messaging/registration-token-not-registered"}}]});
  await avisar("u", {textos: T});

  assert.deepStrictEqual(estado.escrituras, [{uid: "u", cambios: {
    tokensPush: {muerto: "__campo_borrado__"},
    idiomasPush: {muerto: "__campo_borrado__"},
  }}]);
});
