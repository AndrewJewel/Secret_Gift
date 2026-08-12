// Prueba de integración contra las funciones DESPLEGADAS.
//
// Vive en el repo a propósito: la versión anterior era un .ps1 en un
// directorio de sesión sin trackear y se perdió, así que hubo que
// reescribirla de memoria.
//
// Usa TRES cuentas de prueba, no una: functions/index.js prohíbe que una
// misma cuenta tenga dos plazas vivas en el mismo grupo (clave
// `ya_estas_en_el_grupo`, ver agregarParticipante). Para ejercitar "sacar a
// alguien antes del sorteo" y "se necesitan dos para sortear" hace falta un
// segundo cuerpo real: la cuenta ORGANIZADORA crea el grupo y se apunta ella
// misma, y la cuenta PARTICIPANTE entra y sale para completar el aforo.
//
// La TERCERA cuenta existe por un motivo distinto: probar `canjearReemplazo`
// (reemplazar a alguien tras el sorteo) exige a alguien que NO tenga ya una
// plaza en el grupo — organizadora y participante la tienen las dos para
// cuando llega ese momento, así que ninguna de las dos sirve para "quien
// canjea". Hace falta un tercer cuerpo real, sin vínculo previo.
//
// La identidad ya no es apodo+contraseña: es Firebase Auth. El script pide
// tokens a la API REST de Identity Platform y los manda como
// `Authorization: Bearer <idToken>` a cada función, igual que hace la app.
//
// ⚠️ La verificación de correo es BLOQUEANTE, así que el script NO puede
// correr de un tirón. La API REST no deja marcar `emailVerified` sin el
// enlace, y el Admin SDK sí podría — pero exigiría credenciales de
// administrador que este script no tiene ni debería tener. Y una función de
// servidor que marcase cuentas como verificadas sería una puerta trasera
// permanente para ahorrarse dos clics, así que no existe. Se ejecuta en dos
// pasos, con una intervención humana en medio:
//
//   1. node scripts/probar.mjs --crear [--dominio <dominio o buzon>]
//      Sin --dominio usa example.com, que no recibe correo: hay que marcar
//      la verificación a mano. Con --dominio tucorreo@gmail.com se crean
//      direcciones con + y los enlaces LLEGAN de verdad al buzón, que es la
//      única forma de comprobar que el correo sale y que su enlace sirve.
//      Crea las tres cuentas de prueba, comprueba que SIN verificar el
//      servidor responde `correo_sin_verificar`, e imprime los tres correos
//      (y el comando exacto del paso 3).
//   2. Verificar las tres cuentas. Con un buzón real, pinchando los tres
//      enlaces que acaban de llegar — es el camino recomendado, porque
//      además prueba que el correo sale. Con example.com no hay enlace que
//      pinchar: hay que marcarlas a mano en GOOGLE CLOUD CONSOLE →
//      Identity Platform → Users → editar → Email verified. (En la consola
//      de Firebase ese interruptor ya no está; comprobado el 2026-08-09.)
//   3. node scripts/probar.mjs --seguir <correo1> <correo2> <correo3>
//      Entra con esas tres cuentas ya verificadas y ejecuta el resto de la
//      batería completa.
//
// Es más incómodo que antes y es el precio de que la verificación sea de
// verdad: si el script pudiera saltársela, no probaría nada sobre ella.
//
// Las TRES CUENTAS de prueba se quedan: no hay
// ninguna función que borre cuentas de Auth, y añadirla solo para esto
// abriría una superficie que nadie más necesita. Si molestan, se borran a
// mano desde la consola de Firebase (Authentication) — borrar solo el
// documento de Firestore no basta, la cuenta de Auth seguiría viva.
//
// El grupo de prueba SÍ se borra al terminar (eliminarGrupo), como antes.

const BASE = "https://us-central1-secretgift-app.cloudfunctions.net";

// La clave web del proyecto. No es un secreto: va incrustada en el cliente
// web (ver lib/main.dart) y sirve para identificar el proyecto, no para
// autorizar nada.
const API_KEY = "AIzaSyD9F2V6ByG7p9yMoDOpa_p-v97_Ik5jZcI";
const IDENTITY = "https://identitytoolkit.googleapis.com/v1";

async function authRest(metodo, cuerpo) {
  const r = await fetch(`${IDENTITY}/accounts:${metodo}?key=${API_KEY}`, {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({...cuerpo, returnSecureToken: true}),
  });
  const j = await r.json();
  if (!r.ok) throw new Error(`${metodo}: ${j.error?.message || r.status}`);
  return j;
}

const registrar = (email, password) => authRest("signUp", {email, password});
const entrar = (email, password) => authRest("signInWithPassword", {email, password});

// Para leer documentos directamente y comprobar lo que el servidor escribió,
// no solo lo que responde. `grupos/{codigo}` y sus participantes son de
// lectura pública por diseño (ver firestore.rules); la colección NO se puede
// listar, pero un documento concreto sí se puede pedir.
const BUCKET = "secretgift-app.firebasestorage.app";
const FIRESTORE =
  "https://firestore.googleapis.com/v1/projects/secretgift-app/databases/(default)/documents";

// Un JPEG de 1×1 píxel. Existe solo para que algo real pase por Cloud
// Storage: sin él, guardarAvatar y borrarAvatarPorUrl no los prueba nadie.
const JPEG_1PX =
  "/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRof" +
  "Hh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAAB" +
  "AAAAAAAAAAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AKp//2Q==";

const sufijo = Date.now().toString(36);

// Dominio de las cuentas de prueba. Por defecto `example.com`, que está
// reservado por la RFC 2606 y no entrega correo a nadie — con él hay que
// marcar la verificación a mano en la consola.
//
// Pasando `--dominio <algo>` se usa otro. Con un buzón real y direcciones
// con `+` —tucorreo+org@gmail.com— los enlaces de verificación LLEGAN, y
// eso prueba de punta a punta algo que ninguna otra comprobación toca: que
// el correo se manda de verdad y que su enlace funciona. Es más lento,
// pero es la única forma de saberlo.
const iDominio = process.argv.indexOf("--dominio");
const DOMINIO = iDominio > -1 ? process.argv[iDominio + 1] : "example.com";
// Con un buzón real hace falta el `+`: si no, las dos cuentas de prueba
// serían la misma dirección y la segunda chocaría con EMAIL_EXISTS.
const dir = (quien) => DOMINIO.includes("@") ?
  DOMINIO.replace("@", `+${quien}.${sufijo}@`) :
  `prueba.${quien}.${sufijo}@${DOMINIO}`;

// Organizadora: crea el grupo, se apunta como "Yo mismo" y es a quien se le
// comprueba el ciclo completo de PIN (revelación, cambio, bloqueo, rescate).
const EMAIL_ORGANIZADOR = dir("organizador");
// Participante: solo existe para dar cuerpo a "otra persona" — se le saca
// del grupo y se le vuelve a meter, pero nunca se le revela su amigo
// secreto, así que su PIN no importa más allá de cumplir el formato. Antes
// de tener perfil también hace de "cuenta autenticada sin vínculo": el
// primer uso que se le da tras verificar el correo es intentar entrar a un
// grupo SIN haber llamado a guardarPerfil todavía.
const EMAIL_PARTICIPANTE = dir("participante");
// Tercero: no crea el grupo ni se apunta a él con el flujo normal. Su único
// papel es canjear un reemplazo — la única acción de todo el fichero que
// exige una cuenta CON perfil pero SIN plaza previa en el grupo.
const EMAIL_TERCERO = dir("tercero");
const PASSWORD = "Prueba123!";
const PIN = "4321";
const PIN_PARTICIPANTE = "6789";
const PIN_TERCERO = "2468";
const PIN_NUEVO = "9876";
// El tercer PIN existe para probar la salida de emergencia: cambiarlo estando
// bloqueado tiene que levantar el bloqueo.
const PIN_RESCATE = "5555";

// Copiada de functions/index.js. Si allí cambia, aquí también: el bucle de
// abajo se apoya en ella para saber cuántos fallos hacen falta.
const MAX_INTENTOS_PIN = 5;

let fallos = 0;

// Igual que antes, pero ahora manda el idToken como bearer en vez de
// nickname/password en el cuerpo. `idToken` puede ser null (sin cabecera) o
// una cadena cualquiera (token roto): las dos formas de "no autoriza nada".
async function llamar(nombre, datos, idToken) {
  const headers = {"Content-Type": "application/json"};
  if (idToken) headers["Authorization"] = `Bearer ${idToken}`;
  const r = await fetch(`${BASE}/${nombre}`, {
    method: "POST",
    headers,
    body: JSON.stringify({data: datos}),
  });
  const j = await r.json();
  if (j.error) {
    const e = new Error(j.error.message);
    e.clave = j.error.details?.clave || "";
    e.status = j.error.status;
    throw e;
  }
  return j.result || {};
}

// Decodifica el payload de un JWT (la parte de en medio, JSON en base64url).
// Hace falta para leer `email_verified` de verdad: que entrar() devuelva un
// idToken no dice nada sobre si el correo está verificado — Identity
// Toolkit lo entrega igual de contento con la cuenta sin verificar, así que
// solo comprobar "hay token" da un OK falso y el fallo real aparece varios
// casos más tarde, con `correo_sin_verificar`, lejos de la causa.
const claims = (idToken) =>
  JSON.parse(Buffer.from(idToken.split(".")[1], "base64").toString());

// A diferencia de `grupos/{codigo}` y sus subcolecciones, `usuarios/{uid}`
// NO es de lectura pública (ver firestore.rules: solo la propia cuenta
// puede leer su documento), así que aquí sí hace falta el idToken.
async function leerUsuario(uid, idToken) {
  const r = await fetch(`${FIRESTORE}/usuarios/${uid}`, {
    headers: {Authorization: `Bearer ${idToken}`},
  });
  const j = await r.json();
  return campoAValor({mapValue: {fields: j.fields || {}}});
}

// Convierte un valor con la forma de la API REST de Firestore
// (`{mapValue: {fields: {...}}}`, `{stringValue: "..."}`, etc.) a su
// equivalente en JS. Hace falta para `tokensPush`: es un mapa de mapas, y
// sin desenvolver cada nivel las claves seguirían envueltas en
// `{integerValue: "..."}` en vez de quedar como un objeto plano con el que
// `Object.keys` sirva de algo.
function campoAValor(campo) {
  if (!campo) return undefined;
  if ("mapValue" in campo) {
    const obj = {};
    for (const [k, v] of Object.entries(campo.mapValue.fields || {})) obj[k] = campoAValor(v);
    return obj;
  }
  if ("stringValue" in campo) return campo.stringValue;
  if ("integerValue" in campo) return Number(campo.integerValue);
  if ("booleanValue" in campo) return campo.booleanValue;
  if ("nullValue" in campo) return null;
  return campo;
}

function ok(titulo, condicion, detalle = "") {
  if (condicion) {
    console.log(`  OK  ${titulo}`);
  } else {
    fallos++;
    console.error(`FALLO ${titulo} ${detalle}`);
  }
}

// Comprueba que una llamada falla CON la clave esperada. Que falle por
// otra razón no vale: sería pasar la prueba por accidente.
async function debeFallar(titulo, claveEsperada, fn) {
  try {
    await fn();
    fallos++;
    console.error(`FALLO ${titulo} — no lanzó`);
  } catch (e) {
    ok(titulo, e.clave === claveEsperada, `esperaba ${claveEsperada}, llegó ${e.clave}`);
  }
}

// --- Paso 1: crear las tres cuentas y probar lo que solo se puede probar
// ANTES de verificar el correo ------------------------------------------
async function crear() {
  console.log(`Cuenta organizadora: ${EMAIL_ORGANIZADOR}`);
  console.log(`Cuenta participante: ${EMAIL_PARTICIPANTE}`);
  console.log(`Cuenta tercero: ${EMAIL_TERCERO}`);

  const regOrg = await registrar(EMAIL_ORGANIZADOR, PASSWORD);
  const regPart = await registrar(EMAIL_PARTICIPANTE, PASSWORD);
  const regTercero = await registrar(EMAIL_TERCERO, PASSWORD);
  // Que la llamada no lance no prueba que Identity Toolkit haya creado de
  // verdad la cuenta: `idToken` y `localId` son los dos campos que solo
  // vienen si el registro cuajó.
  ok("las tres cuentas se registran en Firebase Auth",
      typeof regOrg.idToken === "string" && regOrg.idToken.length > 0 &&
      typeof regOrg.localId === "string" && regOrg.localId.length > 0 &&
      typeof regPart.idToken === "string" && regPart.idToken.length > 0 &&
      typeof regPart.localId === "string" && regPart.localId.length > 0 &&
      typeof regTercero.idToken === "string" && regTercero.idToken.length > 0 &&
      typeof regTercero.localId === "string" && regTercero.localId.length > 0,
      `organizadora: idToken=${typeof regOrg.idToken} localId=${typeof regOrg.localId}; ` +
      `participante: idToken=${typeof regPart.idToken} localId=${typeof regPart.localId}; ` +
      `tercero: idToken=${typeof regTercero.idToken} localId=${typeof regTercero.localId}`);

  // Con contraseña equivocada, Firebase Auth ni siquiera llega a darnos un
  // token: la comprobación pasa por su lado, no por el nuestro. Es la otra
  // mitad de "una contraseña equivocada no autoriza nada" — la mitad de
  // nuestro backend está en la sección --seguir, con el token roto.
  //
  // No basta con "lanzó algo": un fallo de red o una URL de la API rota
  // también lanzarían, y la prueba diría OK sin haber comprobado nada. Se
  // exige el mensaje concreto de credencial inválida de Identity Toolkit.
  // Cuál de los dos devuelve depende de si el proyecto tiene activada la
  // protección de enumeración de correos, así que se aceptan ambos — pero
  // solo esos dos, no cualquier mensaje.
  let mensajePasswordMala = "";
  try {
    await entrar(EMAIL_ORGANIZADOR, "OtraCosa456!");
  } catch (e) {
    mensajePasswordMala = e.message;
  }
  ok("una contraseña equivocada no autentica",
      /INVALID_LOGIN_CREDENTIALS|INVALID_PASSWORD/.test(mensajePasswordMala),
      `llegó "${mensajePasswordMala}"`);

  // Token de una cuenta recién creada: el correo TODAVÍA no está verificado.
  // Este es el único momento en que se puede probar `correo_sin_verificar`
  // de verdad — en cuanto se marque la cuenta como verificada en la
  // consola, cualquier entrar() nuevo trae un token que ya no sirve para
  // esta prueba.
  const {idToken: tokenSinVerificar} = await entrar(EMAIL_ORGANIZADOR, PASSWORD);
  await debeFallar("sin verificar el correo no se entra", "correo_sin_verificar",
      () => llamar("misGrupos", {}, tokenSinVerificar));

  // Con un dominio real, se mandan los enlaces de verificación de verdad.
  // Es la única parte de todo esto que prueba que el correo SALE y que su
  // enlace funciona; el resto de la batería da eso por hecho.
  if (DOMINIO !== "example.com") {
    for (const [quien, reg] of [["organizadora", regOrg], ["participante", regPart], ["tercero", regTercero]]) {
      await authRest("sendOobCode", {requestType: "VERIFY_EMAIL", idToken: reg.idToken});
      console.log(`  enlace de verificación mandado a la cuenta ${quien}`);
    }
    console.log("\nPincha los TRES enlaces que te han llegado al buzón y sigue con:\n");
  } else {
    console.log("\nEstas cuentas son de example.com y no reciben correo. Marca");
    console.log("las tres como verificadas a mano — Google Cloud Console →");
    console.log("Identity Platform → Users → editar → Email verified — o repite");
    console.log("con `--dominio tucorreo@gmail.com` para verificarlas de verdad.");
    console.log("Luego sigue con:\n");
  }
  console.log(`  node scripts/probar.mjs --seguir ${EMAIL_ORGANIZADOR} ${EMAIL_PARTICIPANTE} ${EMAIL_TERCERO}\n`);

  console.log(fallos === 0 ? "Paso 1 en verde." : `Paso 1: ${fallos} fallo(s).`);
  process.exit(fallos === 0 ? 0 : 1);
}

// --- Paso 2: el resto de la batería, con las tres cuentas ya verificadas -
async function seguir(emailOrganizador, emailParticipante, emailTercero) {
  if (!emailOrganizador || !emailParticipante || !emailTercero) {
    console.error("Uso: node scripts/probar.mjs --seguir <correoOrganizador> <correoParticipante> <correoTercero>");
    process.exit(1);
  }
  console.log(`Cuenta organizadora: ${emailOrganizador}`);
  console.log(`Cuenta participante: ${emailParticipante}`);
  console.log(`Cuenta tercero: ${emailTercero}`);

  // SIN NINGUNA cabecera de identidad: es la comprobación más importante de
  // todo el fichero. Si esta pasa a verde por accidente, la app entera está
  // abierta — cualquiera podría llamar a cualquier función sin haber
  // entrado nunca.
  await debeFallar("sin token no se autoriza", "sesion_invalida",
      () => llamar("misGrupos", {}, null));
  // Un token que no es un JWT válido rechaza la plataforma ANTES de llegar
  // a nuestro código. Sin cabecera responde NUESTRO código con "sesion_invalida";
  // con un token malformado responde la PLATAFORMA con "UNAUTHENTICATED" genérico.
  // Ambas rechacen, pero por vías distintas: defensa en dos capas.
  try {
    await llamar("misGrupos", {}, "esto-no-es-un-token");
    fallos++;
    console.error(`FALLO un token basura tampoco autoriza — no lanzó`);
  } catch (e) {
    ok("un token basura tampoco autoriza",
        e.status === "UNAUTHENTICATED",
        `esperaba UNAUTHENTICATED, llegó ${e.status}`);
  }

  const {idToken: tokenOrg, localId: uidOrg} = await entrar(emailOrganizador, PASSWORD);
  const {idToken: tokenPart} = await entrar(emailParticipante, PASSWORD);
  const {idToken: tokenTercero} = await entrar(emailTercero, PASSWORD);
  const verificadaOrg = claims(tokenOrg).email_verified === true;
  const verificadaPart = claims(tokenPart).email_verified === true;
  const verificadaTercero = claims(tokenTercero).email_verified === true;
  ok("las tres cuentas ya verificadas entran", verificadaOrg && verificadaPart && verificadaTercero,
      `organizadora ${emailOrganizador}: verificada=${verificadaOrg}; ` +
      `participante ${emailParticipante}: verificada=${verificadaPart}; ` +
      `tercero ${emailTercero}: verificada=${verificadaTercero}`);
  // Si alguna de las tres no está verificada, los treinta y tantos casos que
  // siguen fallarán en cascada por la misma causa (empezando por
  // `correo_sin_verificar`) y enterrarán el motivo real. Mejor cortar aquí
  // con un mensaje que diga cuál cuenta falta por confirmar.
  if (!verificadaOrg || !verificadaPart || !verificadaTercero) {
    console.error("\nFalta verificar el correo de:");
    if (!verificadaOrg) console.error(`  - organizadora: ${emailOrganizador}`);
    if (!verificadaPart) console.error(`  - participante: ${emailParticipante}`);
    if (!verificadaTercero) console.error(`  - tercero: ${emailTercero}`);
    console.error("Pincha el enlace de verificación de esa cuenta (o márcala a mano");
    console.error("en Google Cloud Console → Identity Platform → Users) y repite:");
    console.error(`\n  node scripts/probar.mjs --seguir ${emailOrganizador} ${emailParticipante} ${emailTercero}\n`);
    process.exit(1);
  }

  await debeFallar("guardarPerfil rechaza un PIN de 3 dígitos", "pin_formato",
      () => llamar("guardarPerfil", {nombre: "Organiza", apellido: "Dora", pin: "123"}, tokenOrg));

  const perfilOrg = await llamar("guardarPerfil", {nombre: "Organiza", apellido: "Dora", pin: PIN}, tokenOrg);
  ok("guardarPerfil con PIN de 4 dígitos", perfilOrg.ok === true, `llegó ${JSON.stringify(perfilOrg)}`);

  // guardarPerfil usa create(), no set(): una segunda llamada con datos
  // DISTINTOS tiene que ser un no-op silencioso, no reescribir el PIN. Se
  // comprueba aquí que responde `ok: true` igual que la primera vez (no
  // revienta) y más abajo (verAmigoSecreto con PIN, no con "0000") que de
  // verdad no se reescribió.
  const perfilOrgOtraVez = await llamar("guardarPerfil", {nombre: "Otro", apellido: "Nombre", pin: "0000"}, tokenOrg);
  ok("guardarPerfil es idempotente (no revienta la segunda vez)",
      perfilOrgOtraVez.ok === true, `llegó ${JSON.stringify(perfilOrgOtraVez)}`);

  // --- borrarTokenPush: apagar en un dispositivo no apaga el otro --------
  // Los tokens son por DISPOSITIVO, no por cuenta: la misma persona en el
  // móvil y en el portátil tiene dos tokens distintos. Es el caso que más
  // importa de toda esta tarea — apagar los avisos en uno no puede
  // apagárselos en el otro.
  await llamar("guardarTokenPush", {token: "token-apagar-1"}, tokenOrg);
  await llamar("guardarTokenPush", {token: "token-apagar-2"}, tokenOrg);
  await llamar("borrarTokenPush", {token: "token-apagar-1"}, tokenOrg);
  const usuarioOrg = await leerUsuario(uidOrg, tokenOrg);
  const tokensOrg = Object.keys(usuarioOrg.tokensPush || {});
  ok("borrarTokenPush quita solo ese token", !tokensOrg.includes("token-apagar-1"),
      `sigue presente: ${JSON.stringify(tokensOrg)}`);
  ok("el OTRO dispositivo de la misma persona NO se ve afectado",
      tokensOrg.includes("token-apagar-2"), `tokens restantes: ${JSON.stringify(tokensOrg)}`);

  // Borrar un token que ya no está (o que nunca estuvo) no puede reventar:
  // es justo lo que hace `apagarAvisos()` en el cliente si `getToken()`
  // devuelve null o si el token ya se había borrado antes.
  const otraVezBorrado = await llamar("borrarTokenPush", {token: "token-apagar-1"}, tokenOrg);
  ok("borrar un token ya borrado no revienta", otraVezBorrado.ok === true);

  // La cuenta participante, en cambio, TODAVÍA no ha llamado a
  // guardarPerfil. Es el estado exacto de alguien que se registró y
  // verificó el correo pero se fue antes de completar el perfil.
  const antesDePerfil = await llamar("misGrupos", {}, tokenPart);
  ok("misGrupos antes de completar el perfil no revienta",
      antesDePerfil.perfilCompleto === false && antesDePerfil.grupos.length === 0,
      `llegó ${JSON.stringify(antesDePerfil)}`);

  const {codigo} = await llamar("crearGrupo", {
    ocasion: "amigoSecreto", nombreGrupo: "Grupo de prueba",
    valorMinimo: "10", tematica: "", reglas: "",
  }, tokenOrg);
  ok("crearGrupo", typeof codigo === "string");

  // Con perfil pero sin haberse apuntado a NADA, agregarParticipante no
  // puede autorizar: `autorizar` lee usuarios/{uid} y, si el documento no
  // existe, lanza `perfil_incompleto` en vez de tratar a esa cuenta como
  // "sin vínculo". Es una distinción real: `misGrupos` (arriba) degrada sin
  // reventar porque no hace falta ningún vínculo para responder "no tienes
  // grupos"; `autorizar` sí necesita el documento para poder decir CUÁL es
  // tu vínculo, y sin documento no hay nada que decir.
  await debeFallar("autorizar exige perfil antes que vínculo", "perfil_incompleto",
      () => llamar("agregarParticipante",
          {codigo, nombre: "Sin perfil todavía", deseos: ""}, tokenPart));

  const perfilPart = await llamar("guardarPerfil", {nombre: "Partici", apellido: "Pante", pin: PIN_PARTICIPANTE}, tokenPart);
  ok("guardarPerfil de la cuenta participante", perfilPart.ok === true, `llegó ${JSON.stringify(perfilPart)}`);

  // La cuenta tercero también completa su perfil aquí, aunque no la use
  // nadie hasta la sección de reemplazo, al final: `canjearReemplazo` exige
  // perfil (con PIN) igual que cualquier otra función, y montar esto junto
  // al resto de altas de perfil es más fácil de seguir que dejarlo suelto
  // más abajo.
  const perfilTercero = await llamar("guardarPerfil", {nombre: "Terce", apellido: "Ro", pin: PIN_TERCERO}, tokenTercero);
  ok("guardarPerfil de la cuenta tercero", perfilTercero.ok === true, `llegó ${JSON.stringify(perfilTercero)}`);

  // EL BUG QUE ORIGINÓ TODO ESTO: crear un grupo y apuntarse a él lo sacaba
  // DOS veces en Mis grupos, porque arrayUnion guardaba dos entradas.
  const {id} = await llamar("agregarParticipante",
      {codigo, nombre: "Yo mismo", deseos: "Nada"}, tokenOrg);

  const misGruposOrg = await llamar("misGrupos", {}, tokenOrg);
  const deEsteGrupo = misGruposOrg.grupos.filter((g) => g.codigo === codigo);
  ok("el grupo sale UNA sola vez tras crearlo y apuntarse",
      deEsteGrupo.length === 1, `salió ${deEsteGrupo.length} veces`);
  ok("conserva el rol de organizador", deEsteGrupo[0]?.rol === "organizador");
  ok("trae el participanteId", deEsteGrupo[0]?.participanteId === id);
  ok("todavía sin sortear", deEsteGrupo[0]?.sorteado === false);

  // La cuenta participante SÍ tiene perfil ya, pero todavía no tiene
  // vínculo con ESTE grupo: `autorizar` no lanza (ver arriba), devuelve
  // `rol: null` / `participanteId: null`. Lo que hace que eso no sea un
  // agujero es que cada función que exige un rol concreto lo comprueba y
  // rechaza con SU clave — no falla en silencio ni deja pasar por defecto.
  await debeFallar("cuenta con perfil pero sin vínculo: rol null no es organizador",
      "no_eres_organizador",
      () => llamar("borrarParticipante", {codigo, participanteId: id}, tokenPart));
  await debeFallar("cuenta con perfil pero sin vínculo: participanteId null no está en el grupo",
      "no_estas_en_el_grupo",
      () => llamar("verAmigoSecreto", {codigo, pin: PIN}, tokenPart));

  await debeFallar("verAmigoSecreto rechaza un PIN equivocado", "pin_incorrecto",
      () => llamar("verAmigoSecreto", {codigo, pin: "0000"}, tokenOrg));

  // Antes del sorteo sí se puede sacar a alguien. La organizadora YA tiene
  // su plaza (arriba), así que quien entra aquí tiene que ser la cuenta
  // participante: reusar tokenOrg chocaría con "ya_estas_en_el_grupo".
  // Entra CON avatar, y es lo único de toda la batería que toca Cloud
  // Storage. Sin esto, `guardarAvatar` y `borrarAvatarPorUrl` no los
  // ejercita nadie: son las dos únicas funciones del fichero que salen de
  // Firestore, así que un fallo suyo pasaba entero por debajo de esta
  // prueba. Se destapó al migrar a firebase-admin v14, donde
  // `admin.storage()` cambió a `getStorage()`.
  const sobrante = await llamar("agregarParticipante", {
    codigo, nombre: "Sobrante", deseos: "", avatarBase64: JPEG_1PX,
  }, tokenPart);
  ok("agregarParticipante devuelve id con avatar", typeof sobrante.id === "string");

  // La URL tiene que existir de verdad, no solo estar guardada: que el
  // documento traiga una cadena no prueba que la imagen llegara al bucket
  // ni que sea pública.
  const conAvatar = await fetch(
      `${FIRESTORE}/grupos/${codigo}/participantes/${sobrante.id}`);
  const urlAvatar = (await conAvatar.json())?.fields?.avatarUrl?.stringValue || "";
  ok("el avatar se guardó en el bucket", urlAvatar.startsWith("https://storage.googleapis.com/"),
      `llegó "${urlAvatar}"`);
  const imagen = await fetch(urlAvatar);
  ok("la imagen es públicamente accesible", imagen.ok, `HTTP ${imagen.status}`);

  // Sacar a otra persona (no a uno mismo) exige ser organizador —
  // borrarParticipante lo comprueba— así que quien llama es tokenOrg.
  const borrado = await llamar("borrarParticipante",
      {codigo, participanteId: sobrante.id}, tokenOrg);
  ok("antes del sorteo se puede sacar a alguien", borrado.ok === true);

  // Borrar al participante tiene que llevarse su imagen del bucket.
  //
  // Con un parámetro que la caché no ha visto. Pedir la URL tal cual no
  // sirve: se guarda con `cacheControl: max-age=31536000` y esta prueba
  // acaba de descargarla, así que un borrado correcto seguiría devolviendo
  // 200 desde la caché de borde. (Los metadatos tampoco valen: el endpoint
  // JSON de GCS pide credenciales y responde 401, que no dice nada.)
  // Se comprueba que YA NO SE PUEDE DESCARGAR, no que dé un código
  // concreto. Este bucket responde 403 —no 404— a quien pide sin
  // credenciales un objeto que no existe, para no revelar qué hay dentro.
  // Comprobado con rutas inventadas: también dan 403. Exigir 404 haría
  // fallar esta prueba con el borrado funcionando perfectamente.
  const tras = await fetch(`${urlAvatar}?nocache=${Date.now()}`);
  ok("al borrar al participante se borra su avatar", tras.status !== 200,
      `sigue descargándose: HTTP ${tras.status}`);

  // Se necesitan dos para sortear. Al sacar a "Sobrante" el grupo se quedó
  // con una sola plaza (la organizadora); borrarParticipante limpió también
  // el vínculo de la cuenta participante con este grupo, así que puede
  // volver a apuntarse sin chocar con "ya_estas_en_el_grupo".
  //
  // Esta vez SÍ con avatar y guardando su id: es la plaza que la sección de
  // reemplazo, al final, le quita a esta cuenta y le da a la del tercero.
  // El avatar hace falta para poder comprobar allí que el avatar VIEJO deja
  // de estar accesible tras el canje.
  const nombreDeLaPlazaReemplazada = "Otra persona";
  const {id: idOtraPersona} = await llamar("agregarParticipante", {
    codigo, nombre: nombreDeLaPlazaReemplazada, deseos: "", avatarBase64: JPEG_1PX,
  }, tokenPart);
  // Plumbing, no una prueba: solo hace falta la URL para comprobar más
  // abajo que deja de servirse. Que `guardarAvatar` sube de verdad al
  // bucket ya lo comprueba, con sus propias aserciones, el caso de
  // "Sobrante" un poco más arriba.
  const docOtraPersona = await fetch(
      `${FIRESTORE}/grupos/${codigo}/participantes/${idOtraPersona}`);
  const urlAvatarOtraPersona = (await docOtraPersona.json())?.fields?.avatarUrl?.stringValue || "";

  const sorteo = await llamar("ejecutarSorteo", {codigo}, tokenOrg);
  ok("ejecutarSorteo por cuenta", sorteo.ok === true);

  const trasSorteo = await llamar("misGrupos", {}, tokenOrg);
  ok("el grupo queda marcado como sorteado",
      trasSorteo.grupos.find((g) => g.codigo === codigo)?.sorteado === true);

  const amigo = await llamar("verAmigoSecreto", {codigo, pin: PIN}, tokenOrg);
  ok("verAmigoSecreto con el PIN correcto (el que puso guardarPerfil la PRIMERA vez)",
      typeof amigo.nombreAmigo === "string");
  ok("devuelve tu propio nombre", amigo.nombre === "Yo mismo");

  await debeFallar("tras el sorteo NO se puede sacar a nadie", "grupo_ya_sorteado",
      () => llamar("borrarParticipante", {codigo, participanteId: id}, tokenOrg));

  // Las tres reglas del sorteo se sostienen entre sí, así que se prueban
  // juntas: la lista no cambia (ni sacando ni metiendo) y el sorteo no se
  // repite. Si cualquiera de las tres cede, las otras dos dejan de
  // significar nada.
  //
  // Quien entrase después del sorteo quedaría fuera de la cadena: sin
  // amigo asignado y sin nadie que le regale. No se ve hasta el día de la
  // entrega.
  //
  // Se usa la cuenta participante, que YA está dentro, y aun así la clave
  // esperada es `grupo_cerrado` y no `ya_estas_en_el_grupo`: la bandera
  // `sorteado` se mira antes de autorizar, porque el grupo está cerrado
  // para todo el mundo y no hace falta saber quién llama para decirlo. Si
  // esta comprobación devolviera `ya_estas_en_el_grupo`, significaría que
  // el guarda nuevo NO está donde se puso.
  await debeFallar("tras el sorteo NO se puede entrar al grupo", "grupo_cerrado",
      () => llamar("agregarParticipante", {codigo, nombre: "Tarde", deseos: ""}, tokenPart));

  // Repetirlo rebarajaría a gente que ya vio su asignación y quizá ya
  // compró el regalo.
  await debeFallar("el sorteo NO se puede repetir", "sorteo_ya_hecho",
      () => llamar("ejecutarSorteo", {codigo}, tokenOrg));

  // cambiarPin exige sesión RECIENTE (exigirReciente en functions/index.js):
  // el token de más arriba ya tiene un rato, así que hace falta un
  // entrar() fresco que renueve `auth_time` antes de cada cambio de PIN.
  const {idToken: tokenOrgReciente1} = await entrar(emailOrganizador, PASSWORD);
  const cambio = await llamar("cambiarPin", {pinNuevo: PIN_NUEVO}, tokenOrgReciente1);
  ok("cambiarPin con sesión reciente", cambio.ok === true);
  await debeFallar("el PIN viejo ya no vale", "pin_incorrecto",
      () => llamar("verAmigoSecreto", {codigo, pin: PIN}, tokenOrg));

  // NOTA: lo que NO se prueba aquí es que cambiarPin RECHACE una sesión de
  // más de MAX_EDAD_SESION_S (5 minutos). Haría falta esperar cinco minutos
  // reales dentro de una batería que por lo demás tarda segundos — un
  // `sleep` de cinco minutos es peor prueba que ninguna, porque nadie la
  // ejecutaría. Se verifica a mano en la Tarea 12 (Step 7, punto 6):
  // esperar sin refrescar el token y confirmar que cambiarPin responde
  // `requiere_reautenticacion`. Es una laguna real, anotada a propósito.

  // --- El bloqueo por intentos fallidos y su salida de emergencia -------
  //
  // Es la única parte del rediseño cuyo fallo es irreversible: si el bloqueo
  // se pusiera y no se levantara, esa cuenta se quedaría sin ver su amigo
  // secreto para siempre. Se ejerce entera, hasta el rescate. Todo este
  // bloque usa la cuenta organizadora: el PIN es una propiedad suya, la
  // cuenta participante nunca revela nada y no le corresponde este ciclo.
  //
  // El bucle no cuenta intentos exactos a propósito: el fallo de arriba ("el
  // PIN viejo ya no vale") ya gastó uno, y el intento que PROVOCA el bloqueo
  // todavía responde `pin_incorrecto` —el contador se mira antes de comparar,
  // así que el bloqueo no se ve hasta la llamada siguiente—. Se falla hasta
  // que el servidor lo dice, con un tope para no colgarse si nunca lo dice.
  let claveDelBloqueo = "";
  for (let i = 0; i <= MAX_INTENTOS_PIN + 1 && claveDelBloqueo !== "pin_bloqueado"; i++) {
    try {
      await llamar("verAmigoSecreto", {codigo, pin: "0000"}, tokenOrg);
      claveDelBloqueo = "entró con un PIN falso";
      break;
    } catch (e) {
      claveDelBloqueo = e.clave;
    }
  }
  ok("fallar el PIN repetidamente acaba bloqueando la revelación",
      claveDelBloqueo === "pin_bloqueado", `llegó ${claveDelBloqueo}`);

  // Lo que hace que el bloqueo sirva de algo: mientras dura, el PIN correcto
  // tampoco entra. Si entrara, adivinar seguiría siendo cuestión de insistir.
  await debeFallar("bloqueado, ni el PIN correcto entra", "pin_bloqueado",
      () => llamar("verAmigoSecreto", {codigo, pin: PIN_NUEVO}, tokenOrg));

  // Otro entrar() fresco: la sesión de arriba ya no cuenta como reciente
  // para efectos de este segundo cambiarPin.
  const {idToken: tokenOrgReciente2} = await entrar(emailOrganizador, PASSWORD);
  const rescate = await llamar("cambiarPin", {pinNuevo: PIN_RESCATE}, tokenOrgReciente2);
  ok("cambiarPin funciona estando bloqueado", rescate.ok === true);

  // LA PRUEBA QUE IMPORTA: cambiar el PIN con una sesión reciente levanta el
  // bloqueo en el acto, sin esperar los quince minutos. Sin esto, quien se
  // bloquea se queda fuera y la "salida de emergencia" del diseño sería una
  // promesa sin respaldo.
  const rescatado = await llamar("verAmigoSecreto", {codigo, pin: PIN_RESCATE}, tokenOrg);
  ok("el PIN nuevo levanta el bloqueo y entra",
      typeof rescatado.nombreAmigo === "string");

  // --- Reemplazar a alguien tras el sorteo -------------------------------
  // La salida que faltaba: la plaza no se borra, cambia de dueño. Va
  // DESPUÉS del rescate del PIN a propósito: "EL CASO QUE IMPORTA", más
  // abajo, revela el amigo secreto de la organizadora con `PIN_RESCATE`,
  // que es su PIN real en este punto del guion.

  await debeFallar("un token inventado no vale", "reemplazo_invalido",
      () => llamar("canjearReemplazo",
          {codigo, token: "inventado", nombre: "Nadie", deseos: ""}, tokenTercero));

  const {token: tokenR} = await llamar("generarReemplazo",
      {codigo, participanteId: idOtraPersona}, tokenOrg);
  ok("generarReemplazo devuelve un token", typeof tokenR === "string" && tokenR.length > 20,
      `llegó ${JSON.stringify(tokenR)}`);

  // Generar otro para la MISMA plaza invalida el anterior: eso es lo que
  // cumple "el organizador puede anularlo" sin un botón de anular.
  const {token: tokenR2} = await llamar("generarReemplazo",
      {codigo, participanteId: idOtraPersona}, tokenOrg);
  await debeFallar("generar otro token invalida el anterior", "reemplazo_invalido",
      () => llamar("canjearReemplazo",
          {codigo, token: tokenR, nombre: "Nadie", deseos: ""}, tokenTercero));

  // Quien YA tiene plaza en el grupo no puede coger otra. Se prueba con
  // tokenOrg, que sí tiene plaza propia ("Yo mismo") — tokenTercero es
  // justamente la única cuenta SIN plaza, así que no serviría para este
  // caso, y hace falta para el canje real de más abajo.
  //
  // OJO — esto quema tokenR2 igualmente: `canjearReemplazo` reserva (borra)
  // el token dentro de una transacción ANTES de comprobar si quien llama ya
  // tiene plaza (ver el comentario correspondiente en functions/index.js:
  // "si algo falla MÁS ADELANTE en esta función, el token ya quedó
  // gastado"). Así que una llamada que falla por `ya_estas_en_el_grupo`
  // igual invalida el token que usó. Se comprueba explícitamente para que
  // quede documentado y no como una sorpresa silenciosa, y el canje real
  // usa un TERCER token (tokenR3) generado después.
  await debeFallar("quien ya está dentro no puede canjear", "ya_estas_en_el_grupo",
      () => llamar("canjearReemplazo",
          {codigo, token: tokenR2, nombre: "Nadie", deseos: ""}, tokenOrg));
  await debeFallar("y ese intento fallido también gastó el token (comportamiento a propósito)",
      "reemplazo_invalido",
      () => llamar("canjearReemplazo",
          {codigo, token: tokenR2, nombre: "Nadie", deseos: ""}, tokenTercero));

  const {token: tokenR3} = await llamar("generarReemplazo",
      {codigo, participanteId: idOtraPersona}, tokenOrg);

  // verReemplazo: sin token, con token falso, y sin identidad.
  await debeFallar("verReemplazo exige el token", "faltan_datos",
      () => llamar("verReemplazo", {codigo}, tokenTercero));
  await debeFallar("verReemplazo con un token falso no revela nada", "reemplazo_invalido",
      () => llamar("verReemplazo", {codigo, token: "inventado"}, tokenTercero));
  await debeFallar("verReemplazo sin identidad no autoriza", "sesion_invalida",
      () => llamar("verReemplazo", {codigo, token: tokenR3}, null));

  const vista = await llamar("verReemplazo", {codigo, token: tokenR3}, tokenTercero);
  ok("verReemplazo muestra el nombre de la plaza a reemplazar",
      vista.nombre === nombreDeLaPlazaReemplazada, `llegó "${vista.nombre}"`);

  // Un mensaje al chat ANTES de canjear: es la única forma de tener una
  // máscara "de la plaza vieja" con la que comparar la del nuevo dueño.
  const mensajeViejo = await llamar("enviarMensaje", {codigo, texto: "Hola"}, tokenPart);

  // EL CASO QUE IMPORTA. Reemplazar cambia el nombre de una plaza, pero lo
  // que de verdad arregla es la de un TERCERO: quien le regala a esa plaza
  // tiene guardados el nombre y los deseos de quien ya no está, y compraría
  // para esa persona.
  //
  // Se comprueba revelando el amigo secreto de la organizadora. Si le toca
  // la plaza reemplazada, tiene que ver el nombre NUEVO. No se puede mirar
  // esto en Firestore: los documentos privados están cerrados a cero para
  // el cliente (ver firestore.rules), así que la única ventana es esta.
  const antes = await llamar("verAmigoSecreto",
      {codigo, pin: PIN_RESCATE}, tokenOrg);

  const canje = await llamar("canjearReemplazo",
      {codigo, token: tokenR3, nombre: "Persona Nueva", deseos: "Un libro", avatarBase64: JPEG_1PX},
      tokenTercero);
  ok("canjearReemplazo devuelve el id de la plaza — la plaza no cambia, cambia de dueño",
      canje.id === idOtraPersona, `esperaba ${idOtraPersona}, llegó ${canje.id}`);

  const despues = await llamar("verAmigoSecreto",
      {codigo, pin: PIN_RESCATE}, tokenOrg);

  if (antes.nombreAmigo === nombreDeLaPlazaReemplazada) {
    ok("quien le regalaba ve el nombre NUEVO",
        despues.nombreAmigo === "Persona Nueva",
        `esperaba "Persona Nueva", ve "${despues.nombreAmigo}"`);
    ok("y también los deseos nuevos",
        despues.deseosAmigo === "Un libro",
        `esperaba "Un libro", ve "${despues.deseosAmigo}"`);
  } else {
    // Con dos personas la cadena es circular y siempre toca, pero si el
    // montaje cambiara y no tocara, hay que DECIRLO en vez de dar por
    // probado algo que no se ejecutó.
    ok("AVISO: el caso clave no se ejercitó — la organizadora no le regala a la plaza reemplazada", false,
        `su amigo es "${antes.nombreAmigo}"`);
  }

  // La cadena SALIENTE también se conserva: quien entra (tercero) le sigue
  // regalando a quien ya recibía de la plaza anterior. Con solo dos
  // personas esa plaza es la de la propia organizadora ("Yo mismo").
  const amigoDelNuevo = await llamar("verAmigoSecreto", {codigo, pin: PIN_TERCERO}, tokenTercero);
  ok("quien entra por reemplazo regala a quien ya recibía antes",
      amigoDelNuevo.nombreAmigo === "Yo mismo", `regala a "${amigoDelNuevo.nombreAmigo}"`);

  // El token del canje real tampoco vale una segunda vez.
  await debeFallar("el token del canje ya no vale una segunda vez", "reemplazo_invalido",
      () => llamar("canjearReemplazo",
          {codigo, token: tokenR3, nombre: "Otra vez", deseos: ""}, tokenPart));

  // El avatar VIEJO deja de estar accesible: se subió con la plaza "Otra
  // persona" antes del sorteo, y canjearReemplazo tiene que haberlo borrado
  // del bucket al ponerle uno nuevo a la plaza.
  //
  // Con `?nocache=`: esta URL nunca se descargó en la prueba —solo se leyó
  // del documento de Firestore—, así que aquí no hay caché de borde que
  // esquivar. Se deja el parámetro igual, por si algo cambia de orden más
  // adelante y sí llega a descargarse antes de esta comprobación.
  // Se comprueba que YA NO SE DESCARGA, no un código concreto — este bucket
  // responde 403, no 404, a lo que no existe, para no revelar contenido.
  const avatarViejoTrasCanje = await fetch(`${urlAvatarOtraPersona}?nocache=${Date.now()}`);
  ok("el avatar viejo de la plaza reemplazada deja de estar accesible",
      avatarViejoTrasCanje.status !== 200,
      `sigue descargándose: HTTP ${avatarViejoTrasCanje.status}`);

  // El nuevo dueño recibe una máscara DISTINTA en el chat: canjearReemplazo
  // borra `mascara`/`mascaraRepeticion` de la plaza, así que el próximo
  // mensaje le asigna una nueva. No es un muestreo con suerte: las máscaras
  // ya usadas en el grupo (`mascarasUsadas`) se descartan al asignar, así
  // que la nueva NO PUEDE coincidir con la vieja mientras no se agoten las
  // 16 disponibles — con dos mensajes en todo el grupo, no pasa.
  const mensajeNuevo = await llamar("enviarMensaje", {codigo, texto: "Hola de nuevo"}, tokenTercero);
  ok("el nuevo dueño de la plaza recibe una máscara distinta en el chat",
      mensajeNuevo.mascara !== mensajeViejo.mascara,
      `las dos salieron con máscara ${mensajeNuevo.mascara}`);

  // --- Reemplazar la plaza de la ORGANIZADORA misma -----------------------
  // Este caso estuvo roto una vez: al perder su plaza, el rol de
  // organizador (que vive en la MISMA clave del mapa que el vínculo de
  // plaza) se borraba entero y el grupo quedaba ingobernable — sin nadie
  // que pudiera editarlo ni eliminarlo. La cuenta participante ya quedó SIN
  // vínculo con este grupo (el canje de arriba se lo limpió, porque su rol
  // no era "organizador"), así que es libre de canjear esta segunda plaza.
  const {token: tokenROrg} = await llamar("generarReemplazo",
      {codigo, participanteId: id}, tokenOrg);
  await llamar("canjearReemplazo",
      {codigo, token: tokenROrg, nombre: "Sustituta", deseos: "Sorpresa"}, tokenPart);

  const misGruposOrgTrasPerderPlaza = await llamar("misGrupos", {}, tokenOrg);
  const suGrupo = misGruposOrgTrasPerderPlaza.grupos.find((g) => g.codigo === codigo);
  ok("la organizadora conserva el rol tras perder su propia plaza",
      suGrupo?.rol === "organizador", `rol=${suGrupo?.rol}`);
  ok("y su participanteId queda null, no la clave entera borrada",
      suGrupo?.participanteId === null, `participanteId=${suGrupo?.participanteId}`);

  const edicion = await llamar("editarGrupo", {codigo, tematica: "Fin de fiesta"}, tokenOrg);
  ok("sigue pudiendo editar el grupo sin tener plaza propia", edicion.ok === true);

  // eliminarGrupo, un poco más abajo, es la MISMA comprobación con más
  // peso: si `exigirOrganizador` no reconociera a la organizadora sin
  // plaza, esa llamada fallaría con `no_eres_organizador` en vez de borrar
  // el grupo, y toda la limpieza final del script se vendría abajo con
  // ella.

  await llamar("eliminarGrupo", {codigo}, tokenOrg);
  const final = await llamar("misGrupos", {}, tokenOrg);
  ok("al eliminar el grupo desaparece de Mis grupos",
      final.grupos.every((g) => g.codigo !== codigo));

  console.log(fallos === 0 ? "\nTodo en verde." : `\n${fallos} fallo(s).`);
  process.exit(fallos === 0 ? 0 : 1);
}

async function main() {
  const modo = process.argv[2];
  if (modo === "--crear") {
    await crear();
  } else if (modo === "--seguir") {
    await seguir(process.argv[3], process.argv[4], process.argv[5]);
  } else {
    console.error("Uso:");
    console.error("  node scripts/probar.mjs --crear");
    console.error("  node scripts/probar.mjs --seguir <correoOrganizador> <correoParticipante> <correoTercero>");
    process.exit(1);
  }
}

main().catch((e) => {
  console.error("Reventó:", e.message, e.clave || "");
  process.exit(1);
});
