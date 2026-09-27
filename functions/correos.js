// functions/correos.js
// Correos propios (Resend). Lógica pura: sin Firestore ni Auth, para
// probarla sin emulador. index.js la conecta con la base de datos.
const {randomInt} = require("node:crypto");

const REMITENTE = "Secret Gift <no-reply@secretgift.app>";
const LOGO = "https://secretgift.app/assets/assets/logo.png";
const MINUTO_MS = 60 * 1000;
const CADUCIDAD_CODIGO_MS = 10 * MINUTO_MS;
const MAX_ENVIOS_DIA = 5;
const MAX_INTENTOS = 5;

function generarCodigo6() {
  return String(randomInt(0, 1000000)).padStart(6, "0");
}

function escapar(s) {
  const tabla = {"&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#39;"};
  return String(s).replace(/[&<>"']/g, (ch) => tabla[ch]);
}

const TEXTOS = {
  es: {
    codigoAsunto: "Tu código de Secret Gift",
    codigoTitulo: "Tu código de verificación",
    codigoTexto: "Escríbelo en la app para confirmar",
    codigoPie: "Caduca en 10 minutos. Si no creaste una cuenta, ignora este correo.",
    claveAsunto: "Cambia tu contraseña de Secret Gift",
    claveTitulo: "Cambia tu contraseña",
    claveTexto: "Pediste una contraseña nueva para",
    claveBoton: "Elegir contraseña nueva",
    clavePie: "Si no lo pediste tú, ignora este correo: tu contraseña no cambia.",
  },
  en: {
    codigoAsunto: "Your Secret Gift code",
    codigoTitulo: "Your verification code",
    codigoTexto: "Type it in the app to confirm",
    codigoPie: "It expires in 10 minutes. If you didn't create an account, ignore this email.",
    claveAsunto: "Reset your Secret Gift password",
    claveTitulo: "Reset your password",
    claveTexto: "You asked for a new password for",
    claveBoton: "Choose a new password",
    clavePie: "If you didn't ask for this, ignore this email: your password stays the same.",
  },
};

const textosDe = (idioma) => TEXTOS[idioma] || TEXTOS.en;
const SANS = "Arial,Helvetica,sans-serif";

function marco(idioma, cuerpo) {
  return `<!doctype html><html lang="${idioma}"><body style="margin:0">
<div style="background:#EDE6DA;padding:32px 12px;font-family:Georgia,'Times New Roman',serif">
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:480px;margin:0 auto;background:#F4EFE5;border-radius:20px;border:1px solid #E2D8C6">
<tr><td style="padding:36px 36px 28px;text-align:center">
<img src="${LOGO}" width="56" height="56" alt="Secret Gift" style="display:block;margin:0 auto 20px">
${cuerpo}
</td></tr></table>
<p style="max-width:480px;margin:16px auto 0;text-align:center;font-family:${SANS};font-size:11px;letter-spacing:2px;color:#8A7F74">SECRET GIFT · SECRETGIFT.APP</p>
</div></body></html>`;
}

function encabezado(titulo, texto, correo) {
  return `<h1 style="margin:0 0 10px;font-size:26px;font-weight:normal;color:#181818">${titulo}</h1>
<p style="margin:0 0 24px;font-family:${SANS};font-size:15px;line-height:1.5;color:#6B6158">${texto} <b style="color:#181818">${escapar(correo)}</b>.</p>`;
}

function pie(texto) {
  return `<p style="margin:22px 0 0;font-family:${SANS};font-size:13px;color:#8A7F74">${texto}</p>`;
}

function correoCodigo(idioma, correo, codigo) {
  const t = textosDe(idioma);
  const html = marco(idioma, encabezado(t.codigoTitulo, t.codigoTexto, correo) +
    `<div style="display:inline-block;padding:16px 26px;background:#FFFFFF;border:1px solid #E2D8C6;border-radius:14px;font-family:'Courier New',monospace;font-size:34px;letter-spacing:10px;color:#181818;font-weight:bold">${codigo}</div>` +
    pie(t.codigoPie));
  const texto = `${t.codigoTitulo}: ${codigo}\n\n${t.codigoTexto} ${correo}.\n${t.codigoPie}`;
  return {asunto: t.codigoAsunto, html, texto};
}

function correoRecuperacion(idioma, correo, enlace) {
  const t = textosDe(idioma);
  const html = marco(idioma, encabezado(t.claveTitulo, t.claveTexto, correo) +
    `<table role="presentation" cellspacing="0" cellpadding="0" style="margin:0 auto"><tr><td style="background:#181818;border-radius:999px">` +
    `<a href="${escapar(enlace)}" style="display:inline-block;padding:15px 34px;font-family:${SANS};font-size:15px;font-weight:bold;color:#FFFFFF;text-decoration:none;border-radius:999px">${t.claveBoton}</a></td></tr></table>` +
    pie(t.clavePie));
  const texto = `${t.claveTitulo}\n\n${t.claveTexto} ${correo}.\n${t.claveBoton}: ${enlace}\n\n${t.clavePie}`;
  return {asunto: t.claveAsunto, html, texto};
}

/** 1 envío por minuto y 5 por día UTC. `limite` es lo guardado la vez anterior. */
function decidirEnvio(limite, ahoraMs) {
  const dia = new Date(ahoraMs).toISOString().slice(0, 10);
  const previo = limite || {};
  const enviadosHoy = previo.dia === dia ? (previo.enviadosHoy || 0) : 0;
  if (previo.enviadoEn && ahoraMs - previo.enviadoEn < MINUTO_MS) return {permitido: false};
  if (enviadosHoy >= MAX_ENVIOS_DIA) return {permitido: false};
  return {permitido: true, limite: {dia, enviadosHoy: enviadosHoy + 1, enviadoEn: ahoraMs}};
}

/** Qué hacer con un intento, antes de comparar el código (bcrypt es aparte). */
function evaluarIntento(doc, ahoraMs) {
  if (!doc || !doc.hash || !(ahoraMs <= doc.expira)) return "caducado";
  if ((doc.intentos || 0) >= MAX_INTENTOS) return "agotado";
  return "comparar";
}

async function enviarConResend(clave, {para, asunto, html, texto}, fetchFn = fetch) {
  const r = await fetchFn("https://api.resend.com/emails", {
    method: "POST",
    headers: {"Authorization": `Bearer ${clave}`, "Content-Type": "application/json"},
    body: JSON.stringify({from: REMITENTE, to: [para], subject: asunto, html, text: texto}),
  });
  if (!r.ok) {
    const cuerpo = r.text ? await r.text().catch(() => "") : "";
    throw new Error(`Resend ${r.status}: ${String(cuerpo).slice(0, 300)}`);
  }
}

module.exports = {
  generarCodigo6, correoCodigo, correoRecuperacion, decidirEnvio, evaluarIntento,
  enviarConResend, CADUCIDAD_CODIGO_MS, MAX_INTENTOS,
};
