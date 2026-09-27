// functions/correos.test.js
const test = require("node:test");
const assert = require("node:assert");
const c = require("./correos");

test("el código son 6 cifras", () => {
  for (let i = 0; i < 200; i++) assert.match(c.generarCodigo6(), /^\d{6}$/);
});

test("plantilla de código: idioma, código y correo escapado", () => {
  const es = c.correoCodigo("es", "a<b>@x.com", "042913");
  assert.match(es.asunto, /código/i);
  assert.ok(es.html.includes("042913"));
  assert.ok(es.html.includes("a&lt;b&gt;@x.com"));
  assert.ok(!es.html.includes("#9B1226"), "sin carmín");
  assert.ok(es.texto.includes("042913"));
  const en = c.correoCodigo("en", "a@x.com", "111111");
  assert.match(en.asunto, /code/i);
});

test("plantilla de recuperación: botón con el enlace escapado", () => {
  const r = c.correoRecuperacion("en", "a@x.com", "https://x/?a=1&b=2");
  assert.ok(r.html.includes('href="https://x/?a=1&amp;b=2"'));
  assert.ok(r.html.includes("Choose a new password"));
  assert.ok(r.texto.includes("https://x/?a=1&b=2"));
});

test("límite: 1 por minuto y 5 al día", () => {
  const t0 = Date.UTC(2026, 8, 26, 12);
  let d = c.decidirEnvio(undefined, t0);
  assert.strictEqual(d.permitido, true);
  assert.strictEqual(c.decidirEnvio(d.limite, t0 + 30000).permitido, false);
  let limite = d.limite;
  for (let i = 1; i < 5; i++) {
    d = c.decidirEnvio(limite, t0 + i * 61000);
    assert.strictEqual(d.permitido, true, `envío ${i + 1}`);
    limite = d.limite;
  }
  assert.strictEqual(c.decidirEnvio(limite, t0 + 10 * 61000).permitido, false, "sexto del día");
  assert.strictEqual(c.decidirEnvio(limite, t0 + 24 * 3600000).permitido, true, "día nuevo");
});

test("evaluarIntento", () => {
  const ahora = 1000000;
  assert.strictEqual(c.evaluarIntento(undefined, ahora), "caducado");
  assert.strictEqual(c.evaluarIntento({hash: "h", expira: ahora - 1, intentos: 0}, ahora), "caducado");
  assert.strictEqual(c.evaluarIntento({hash: "h", expira: ahora + 1, intentos: 5}, ahora), "agotado");
  assert.strictEqual(c.evaluarIntento({hash: "h", expira: ahora + 1, intentos: 4}, ahora), "comparar");
});

test("enviarConResend manda lo esperado y lanza si Resend falla", async () => {
  let pedido;
  await c.enviarConResend("k", {para: "a@x.com", asunto: "S", html: "<p>h</p>", texto: "h"},
      async (url, opciones) => {
        pedido = {url, opciones};
        return {ok: true};
      });
  assert.strictEqual(pedido.url, "https://api.resend.com/emails");
  assert.strictEqual(pedido.opciones.headers.Authorization, "Bearer k");
  const cuerpo = JSON.parse(pedido.opciones.body);
  assert.strictEqual(cuerpo.from, "Secret Gift <no-reply@secretgift.app>");
  assert.deepStrictEqual(cuerpo.to, ["a@x.com"]);
  await assert.rejects(c.enviarConResend("k", {para: "a", asunto: "", html: "", texto: ""},
      async () => ({ok: false, status: 403, text: async () => "no"})), /403/);
});
