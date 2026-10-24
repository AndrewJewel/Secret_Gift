// Smoke contra producción: lo que no puede romperse sin que nos enteremos.
//
//   node scripts/smoke.mjs
//
// Lo corre GitHub Actions cada día (smoke.yml) y después de cada despliegue
// (desplegar.yml). Si algo falla sale con código 1 y GitHub manda un correo.
// Existe porque el 22-oct la app pasó un tiempo caída (facturación cerrada)
// sin que nadie lo supiera.
//
// Las funciones se comprueban llamándolas SIN sesión: si están vivas
// responden `sesion_invalida`; si el servidor está caído, 500 o «Rate
// exceeded». Tras un despliegue tardan en arrancar, así que se reintenta
// (SMOKE_REINTENTOS, cada 30 s).
// El webhook de Paddle, que no es callable, debe responder 401 sin firma.

const WEB = "https://secretgift.app";
const FUNCIONES = "https://us-central1-secretgift-app.cloudfunctions.net";
const HUELLA_PROPIA = "34:F8:5F:C0";
const REINTENTOS = Number(process.env.SMOKE_REINTENTOS || 3);

const fallos = [];
let pasadas = 0;

function ok(titulo, condicion, detalle = "") {
  if (condicion) {
    pasadas++;
    console.log(`OK    ${titulo}`);
  } else {
    fallos.push(titulo);
    console.log(`FALLO ${titulo}${detalle ? ` — ${detalle}` : ""}`);
  }
}

async function texto(ruta) {
  const r = await fetch(`${WEB}${ruta}${ruta.includes("?") ? "&" : "?"}cb=${Date.now()}`);
  return {estado: r.status, cuerpo: await r.text()};
}

/** Las páginas legales se reconocen por su título: el 200 no basta, la
 * reescritura de la app devuelve 200 con index.html para cualquier ruta. */
async function pagina(ruta, titulo) {
  const {estado, cuerpo} = await texto(ruta);
  ok(`${ruta} sirve «${titulo}»`, estado === 200 && cuerpo.includes(`<title>${titulo}`), `estado ${estado}`);
}

async function funcion(nombre, datos = {}) {
  let ultima = "";
  for (let intento = 1; intento <= REINTENTOS; intento++) {
    try {
      const r = await fetch(`${FUNCIONES}/${nombre}`, {
        method: "POST",
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify({data: datos}),
      });
      ultima = (await r.text()).slice(0, 120);
      if (ultima.includes("sesion_invalida")) return ok(`función ${nombre} viva`, true);
    } catch (e) {
      ultima = e.message;
    }
    if (intento < REINTENTOS) await new Promise((res) => setTimeout(res, 30000));
  }
  ok(`función ${nombre} viva`, false, ultima);
}

const portada = await texto("/");
ok("/ sirve la landing", portada.estado === 200 && portada.cuerpo.includes("<title>Secret Gift") &&
    !portada.cuerpo.includes("flutter_bootstrap.js"), `estado ${portada.estado}`);
// Las invitaciones viejas (/?codigo=…) dependen de este salto, que va en el <head>.
ok("la landing manda las invitaciones a /app", portada.cuerpo.includes("location.replace('/app'"));
const app = await texto("/app");
ok("/app sirve la app", app.estado === 200 && app.cuerpo.includes("flutter_bootstrap.js"), `estado ${app.estado}`);

await pagina("/privacidad", "Privacidad");
await pagina("/terminos", "Condiciones de uso");
await pagina("/precios", "Precios");
await pagina("/eliminar-cuenta", "Eliminar cuenta");

const apk = await fetch(`${WEB}/apk`, {method: "HEAD", redirect: "follow"});
ok("/apk entrega el APK", apk.status === 200 &&
    apk.headers.get("content-type") === "application/vnd.android.package-archive",
`estado ${apk.status}, ${apk.headers.get("content-type")}`);

const enlaces = await texto("/.well-known/assetlinks.json");
ok("assetlinks.json con la huella de la app", enlaces.estado === 200 &&
    enlaces.cuerpo.includes("app.secretgift") && enlaces.cuerpo.includes(HUELLA_PROPIA));

await funcion("misGrupos");
await funcion("verificarCodigo", {codigo: "000000"});
await funcion("aceptarCondiciones");
await funcion("denunciarMensaje", {codigo: "X", mensajeId: "m", motivo: "spam"});

// El webhook de Paddle no es callable: sin firma debe responder 401. Un 500
// o «Rate exceeded» sería que está caído; se reintenta como las demás.
async function webhookCerrado() {
  let ultima = "";
  for (let intento = 1; intento <= REINTENTOS; intento++) {
    try {
      const r = await fetch(`${FUNCIONES}/webhookPaddle`, {method: "POST", body: "{}"});
      if (r.status === 401) return ok("webhookPaddle rechaza lo que no viene firmado", true);
      ultima = `estado ${r.status}`;
    } catch (e) {
      ultima = e.message;
    }
    if (intento < REINTENTOS) await new Promise((res) => setTimeout(res, 30000));
  }
  ok("webhookPaddle rechaza lo que no viene firmado", false, ultima);
}
await webhookCerrado();

console.log(`\nsmoke ${WEB}: ${pasadas}/${pasadas + fallos.length} comprobaciones`);
if (fallos.length) {
  console.log(`Fallaron: ${fallos.join("; ")}`);
  process.exit(1);
}
