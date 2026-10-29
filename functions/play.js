// Llamadas a la Google Play Developer API (androidpublisher v3). Sin
// secretos: se autentica la cuenta de servicio de las funciones, que el
// usuario invita en Play Console → Usuarios y permisos.
// Diseño: locker/docs/superpowers/specs/2026-10-28-cobro-google-play-design.md
const {GoogleAuth} = require("google-auth-library");

const PAQUETE = "app.secretgift";
const PRODUCTO = "grupo_extra";
const BASE = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PAQUETE}`;

const auth = new GoogleAuth({scopes: ["https://www.googleapis.com/auth/androidpublisher"]});

async function pedir(url, method = "GET") {
  const cliente = await auth.getClient();
  return (await cliente.request({url, method})).data;
}

const urlCompra = (token) => `${BASE}/purchases/products/${PRODUCTO}/tokens/${encodeURIComponent(token)}`;

/** `purchases.products.get`. */
const obtenerCompra = (token) => pedir(urlCompra(token));

/** `purchases.products.consume`: también reconoce la compra (sin eso,
 * Google la devuelve sola a los 3 días) y deja volver a comprar. */
const consumir = (token) => pedir(`${urlCompra(token)}:consume`, "POST");

/** `voidedpurchases.list` desde `desdeMs`, solo compras únicas (type=0).
 * ponytail: una sola página (hasta 1000). Con una revisión diaria sobra; si
 * algún día hay más devoluciones que eso por día, seguir `tokenPagination`. */
async function anuladas(desdeMs) {
  const datos = await pedir(`${BASE}/purchases/voidedpurchases?startTime=${desdeMs}&type=0&maxResults=1000`);
  return datos.voidedPurchases || [];
}

module.exports = {obtenerCompra, consumir, anuladas};
