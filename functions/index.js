const {onCall, HttpsError} = require("firebase-functions/v2/https");
// firebase-admin v13 retiró la API con espacio de nombres (`admin.firestore()`,
// `admin.storage()`, `admin.firestore.FieldValue`). Ahora cada cosa se pide a
// su módulo.
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue, FieldPath} = require("firebase-admin/firestore");
const {getStorage} = require("firebase-admin/storage");
const bcrypt = require("bcryptjs");
// `Math.random` no sirve para nada de esto. V8 lo implementa con
// xorshift128+, que no es un generador criptográfico: a partir de unas
// pocas salidas consecutivas se puede reconstruir su estado interno y
// predecir las siguientes. Y aquí las tres cosas que se sortean son
// secretos: el código del grupo —que desde que se cerró el `list` de
// Firestore es la ÚNICA llave para llegar a él—, la cadena del sorteo, y
// la máscara que sostiene el anonimato del chat.
const {randomInt} = require("node:crypto");

initializeApp();
const db = getFirestore();

// Sin caracteres ambiguos (0/O, 1/I/L) para que sea fácil de dictar/escribir.
const ALFABETO_CODIGO = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";

function generarCodigo() {
  let letras = "";
  for (let i = 0; i < 4; i++) {
    letras += ALFABETO_CODIGO[randomInt(ALFABETO_CODIGO.length)];
  }
  let numeros = "";
  for (let i = 0; i < 4; i++) {
    numeros += ALFABETO_CODIGO[randomInt(ALFABETO_CODIGO.length)];
  }
  return `${letras}-${numeros}`;
}

// --- Avatares ---------------------------------------------------------
// Las imágenes entran por aquí, nunca directo del cliente al bucket: la
// app no usa Firebase Auth, así que unas reglas de Storage que permitan
// escribir dejarían el bucket abierto a cualquiera. Subiéndolas por la
// función, la cuenta vinculada al grupo es la autorización, igual que en
// el resto de la app.

const BUCKET = "santa-secreto-860c3.firebasestorage.app";
// El cliente ya redimensiona a 256px (unos 20KB). El tope generoso es
// solo para frenar un abuso, no para uso normal.
const MAX_AVATAR_BYTES = 400 * 1024;

// Sube la imagen y devuelve su URL pública. Devuelve null si no vino
// ninguna imagen — el avatar siempre es opcional.
async function guardarAvatar(codigo, participanteId, avatarBase64) {
  if (!avatarBase64) return null;

  // El cliente puede mandar "data:image/jpeg;base64,XXXX" o solo "XXXX".
  const limpio = String(avatarBase64).replace(/^data:image\/\w+;base64,/, "");
  const buffer = Buffer.from(limpio, "base64");

  if (buffer.length === 0) {
    throw new HttpsError("invalid-argument", "La imagen llegó vacía o dañada.", {clave: "imagen_invalida"});
  }
  if (buffer.length > MAX_AVATAR_BYTES) {
    throw new HttpsError("invalid-argument", "La imagen pesa demasiado.", {clave: "imagen_muy_grande"});
  }

  // Nombre con marca de tiempo: al cambiar de avatar cambia la URL, así
  // ningún caché del navegador se queda mostrando la imagen vieja.
  const ruta = `avatares/${codigo}/${participanteId}-${Date.now()}.jpg`;
  const archivo = getStorage().bucket(BUCKET).file(ruta);
  await archivo.save(buffer, {
    contentType: "image/jpeg",
    metadata: {cacheControl: "public, max-age=31536000"},
  });
  await archivo.makePublic();
  return `https://storage.googleapis.com/${BUCKET}/${ruta}`;
}

// Borra del bucket el archivo al que apunta una URL nuestra. Si falla, se
// ignora: dejar una imagen huérfana es mucho menos grave que romper la
// acción que el usuario pidió.
async function borrarAvatarPorUrl(url) {
  if (!url || typeof url !== "string") return;
  const prefijo = `https://storage.googleapis.com/${BUCKET}/`;
  if (!url.startsWith(prefijo)) return;
  try {
    await getStorage().bucket(BUCKET).file(url.slice(prefijo.length)).delete();
  } catch (e) {
    console.warn("No se pudo borrar el avatar viejo:", e.message);
  }
}

// --- Chat grupal anónimo ---------------------------------------------
// El mensaje público SOLO lleva el número de máscara. La relación
// máscara↔persona vive en el privado del participante, al que el cliente
// no tiene ningún acceso (ver firestore.rules). Así el chat se puede
// seguir (cada quien es siempre la misma máscara) sin que nadie pueda
// saber quién está detrás.

const TOTAL_MASCARAS = 16;
const MAX_MENSAJE = 500;
// Un mensaje cada 2s por persona: frena el spam sin estorbar a nadie
// escribiendo normal.
const ESPERA_ENTRE_MENSAJES_MS = 2000;

function grupoRef(codigo) {
  return db.collection("grupos").doc(codigo);
}

function grupoPrivadoRef(codigo) {
  return grupoRef(codigo).collection("privado").doc("data");
}

function participanteRef(codigo, participanteId) {
  return grupoRef(codigo).collection("participantes").doc(participanteId);
}

function participantePrivadoRef(codigo, participanteId) {
  return participanteRef(codigo, participanteId).collection("privado").doc("data");
}

// --- Cuentas (Firebase Auth + PIN) ------------------------------------
// La identidad la pone Firebase Auth: el cliente manda su ID token en la
// cabecera Authorization y el protocolo callable rellena `request.auth`.
// Aquí ya no se verifica ninguna contraseña — no la tenemos ni queremos
// tenerla.
//
// El PIN de 4 dígitos sobrevive: es la segunda barrera para una sola
// acción —revelar tu amigo secreto— y sigue siendo nuestro, con bcrypt.
// `bcryptjs` se queda EXCLUSIVAMENTE para eso.

const REGEX_PIN = /^\d{4}$/;

// Cinco intentos y quince minutos de espera convierten 10.000 combinaciones en
// semanas de trabajo. No deja a nadie fuera para siempre: quien se bloquee
// cambia su PIN reautenticándose y sigue.
const MAX_INTENTOS_PIN = 5;
const BLOQUEO_PIN_MS = 15 * 60 * 1000;

// Cuánto vale una reautenticación. Cinco minutos dan de sobra para teclear
// un PIN nuevo y son demasiado poco para que le sirvan a quien coja el
// dispositivo más tarde.
const MAX_EDAD_SESION_S = 5 * 60;

function validarPin(pin) {
  if (!REGEX_PIN.test(pin || "")) {
    throw new HttpsError("invalid-argument", "El PIN debe ser de 4 dígitos exactos.", {clave: "pin_formato"});
  }
}

/**
 * El uid de quien llama, ya verificado por Firebase.
 *
 * `exigirVerificado` es false SOLO en `guardarPerfil`: se llama justo
 * después de registrarse, cuando el correo todavía no puede estar
 * verificado. Exigirlo ahí dejaría a todo el mundo sin poder completar su
 * perfil jamás.
 */
function uidDe(request, {exigirVerificado = true} = {}) {
  const auth = request.auth;
  if (!auth || !auth.uid) {
    throw new HttpsError("unauthenticated", "Tienes que entrar en tu cuenta.", {clave: "sesion_invalida"});
  }
  if (exigirVerificado && auth.token.email_verified !== true) {
    throw new HttpsError("permission-denied", "Verifica tu correo para continuar.", {clave: "correo_sin_verificar"});
  }
  return auth.uid;
}

/**
 * Exige que la sesión sea RECIENTE, no solo válida.
 *
 * Sin esto, reautenticarse sería puro teatro: quien tenga el dispositivo
 * desbloqueado tiene un token válido y puede llamar a la función directa,
 * saltándose la pantalla que pide la contraseña. `auth_time` es el único
 * dato del token que el cliente no puede falsear, y reautenticarse es lo
 * único que lo actualiza.
 */
function exigirReciente(request) {
  const authTime = request.auth?.token?.auth_time;
  if (typeof authTime !== "number") {
    throw new HttpsError("permission-denied", "Vuelve a confirmar tu contraseña.", {clave: "requiere_reautenticacion"});
  }
  const edad = Math.floor(Date.now() / 1000) - authTime;
  if (edad > MAX_EDAD_SESION_S) {
    throw new HttpsError("permission-denied", "Vuelve a confirmar tu contraseña.", {clave: "requiere_reautenticacion"});
  }
}

function usuarioRef(uid) {
  return db.collection("usuarios").doc(uid);
}

const MAX_NOMBRE = 40;

/**
 * Crea el documento de perfil de una cuenta de Auth recién registrada.
 *
 * Se eligió una llamada explícita del cliente en vez de un disparador de
 * Auth: es más simple de probar y no depende de la semántica de triggers
 * entre v1 y v2.
 *
 * Usa `create()`, no `set()`: así una cuenta que ya tiene perfil no puede
 * reescribirse el PIN desde una sesión sin verificar. Y hace la llamada
 * idempotente de cara al cliente, que puede reintentar sin miedo.
 */
exports.guardarPerfil = onCall(async (request) => {
  const uid = uidDe(request, {exigirVerificado: false});
  const nombre = (request.data?.nombre || "").trim();
  const apellido = (request.data?.apellido || "").trim();
  const pin = (request.data?.pin || "").trim();

  if (!nombre || !apellido) {
    throw new HttpsError("invalid-argument", "Faltan el nombre o el apellido.", {clave: "faltan_datos"});
  }
  if (nombre.length > MAX_NOMBRE || apellido.length > MAX_NOMBRE) {
    throw new HttpsError("invalid-argument", `El nombre y el apellido no pueden pasar de ${MAX_NOMBRE} caracteres.`, {clave: "nombre_largo"});
  }
  validarPin(pin);

  try {
    await usuarioRef(uid).create({
      nombre,
      apellido,
      correo: request.auth.token.email || "",
      pinHash: bcrypt.hashSync(pin, 10),
      fecha: FieldValue.serverTimestamp(),
      grupos: {},
    });
  } catch (e) {
    // Ya existía: es un reintento del cliente. No es un error para quien
    // llama, y sobre todo NO se reescribe el PIN.
    if (e.code === 6 || e.code === "already-exists") return {ok: true};
    throw e;
  }
  return {ok: true};
});

/**
 * Cambiar el PIN exige una sesión RECIENTE, no solo válida — ver
 * `exigirReciente`. Es también la salida de emergencia de quien olvidó el
 * PIN o se bloqueó intentándolo: su hash es nuestro y nadie puede releerlo,
 * así que la única vuelta es fijar uno nuevo demostrando la contraseña.
 */
exports.cambiarPin = onCall(async (request) => {
  const uid = uidDe(request);
  exigirReciente(request);
  const pinNuevo = (request.data?.pinNuevo || "").trim();
  validarPin(pinNuevo);

  await usuarioRef(uid).update({
    pinHash: bcrypt.hashSync(pinNuevo, 10),
    // Cambiar el PIN levanta el bloqueo. Sin esto, quien fija un PIN nuevo
    // seguiría bloqueado quince minutos con el PIN correcto.
    pinFallos: 0,
    pinBloqueadoHasta: 0,
  });
  return {ok: true};
});

/**
 * El perfil y los grupos de quien llama.
 *
 * Sigue siendo una Cloud Function y no una lectura directa de Firestore
 * aunque las reglas nuevas dejarían leer `usuarios/{uid}`: limpiar los
 * grupos que ya no existen es una ESCRITURA, y la escritura sigue cerrada
 * al cliente.
 *
 * `perfilCompleto: false` significa que hay cuenta de Auth pero no
 * documento de perfil — pasa si `guardarPerfil` falló por red justo
 * después de registrarse. El cliente lo usa para mandar a completar el
 * perfil en vez de dejar a esa persona en una app medio rota.
 */
exports.misGrupos = onCall(async (request) => {
  const uid = uidDe(request);

  const snap = await usuarioRef(uid).get();
  if (!snap.exists) {
    return {perfilCompleto: false, nombre: "", apellido: "", grupos: []};
  }
  const datos = snap.data();

  const grupos = datos.grupos || {};
  const codigos = Object.keys(grupos);
  const detalles = (await Promise.all(codigos.map(async (codigo) => {
    const gs = await grupoRef(codigo).get();
    if (!gs.exists) return null;
    return {
      codigo,
      rol: grupos[codigo].rol,
      // Null hasta que esa persona se da de alta en el grupo. Es lo que
      // el cliente usa para saber si ofrecerte el formulario de alta.
      participanteId: grupos[codigo].participanteId || null,
      ocasion: gs.data().ocasion,
      valorMinimo: gs.data().valorMinimo,
      nombreGrupo: gs.data().nombreGrupo || "",
      tematica: gs.data().tematica || "",
      sorteado: gs.data().sorteado === true,
    };
  }))).filter(Boolean);

  // Si algún grupo vinculado ya no existe (su organizador lo eliminó), se
  // borra aquí su clave del mapa. Así eliminarGrupo no tiene que recorrer
  // toda la colección de usuarios buscando a quién avisar.
  //
  // Se borra con FieldPath y no con la cadena `grupos.${codigo}`: los
  // códigos llevan guion (ABCD-2345) y una ruta en texto se parsea.
  if (detalles.length !== codigos.length) {
    const vivos = new Set(detalles.map((d) => d.codigo));
    for (const codigo of codigos) {
      if (vivos.has(codigo)) continue;
      await usuarioRef(uid).update(
          new FieldPath("grupos", codigo),
          FieldValue.delete(),
      );
    }
  }

  return {
    perfilCompleto: true,
    nombre: datos.nombre || "",
    apellido: datos.apellido || "",
    grupos: detalles,
  };
});

/**
 * Verifica la cuenta y devuelve tu vínculo con ese grupo.
 *
 * Lo importante no es que sustituya a tres funciones, es de dónde sale el
 * `participanteId`: antes lo mandaba el cliente y el servidor comprobaba
 * que el PIN cuadrara; ahora el servidor lo DERIVA del vínculo. El cliente
 * ya no puede decir que es otro participante, así que suplantar deja de
 * ser cuestión de adivinar cuatro cifras guardadas en texto plano.
 */
/** Solo comprueba la cuenta. La usa `crearGrupo`, donde todavía no hay
 * grupo con el que tener vínculo. */
async function verificarCuenta(nickname, password) {
  const clave = normalizarNickname(nickname);
  if (!clave || !password) {
    throw new HttpsError("unauthenticated", "Faltan las credenciales de tu cuenta.", {clave: "sesion_invalida"});
  }
  const snap = await usuarioRef(clave).get();
  if (!snap.exists || !bcrypt.compareSync(password, snap.data().hash)) {
    throw new HttpsError("unauthenticated", "La sesión de tu cuenta no es válida. Vuelve a entrar.", {clave: "sesion_invalida"});
  }
  return {clave, datos: snap.data()};
}

async function autorizar(codigo, nickname, password) {
  const {clave, datos} = await verificarCuenta(nickname, password);
  const vinculo = (datos.grupos || {})[codigo] || null;
  return {
    clave,
    rol: vinculo ? vinculo.rol : null,
    participanteId: vinculo ? (vinculo.participanteId || null) : null,
    datos,
  };
}

function exigirOrganizador(sesion) {
  if (sesion.rol !== "organizador") {
    throw new HttpsError("permission-denied", "Solo el organizador del grupo puede hacer esto.", {clave: "no_eres_organizador"});
  }
}

function exigirParticipante(sesion) {
  if (!sesion.participanteId) {
    throw new HttpsError("permission-denied", "Todavía no estás inscrito en este grupo.", {clave: "no_estas_en_el_grupo"});
  }
}

/**
 * Al crear un grupo. La plaza de participante todavía no existe: quien
 * crea el grupo se inscribe después, como todo el mundo.
 */
async function vincularComoOrganizador(clave, codigo) {
  if (!clave) return;
  await usuarioRef(clave).set(
      {grupos: {[codigo]: {rol: "organizador", participanteId: null}}},
      {merge: true},
  );
}

/**
 * Al inscribirse en un grupo.
 *
 * `merge` hace una fusión PROFUNDA de mapas, así que esto rellena tu
 * `participanteId` sin crear una entrada nueva. Quien creó el grupo y
 * luego se apunta conserva su rol de organizador y queda UNA sola
 * entrada.
 *
 * Antes `grupos` era un array y esto se hacía con arrayUnion, que compara
 * por igualdad profunda: `{codigo, rol}` y `{codigo, participanteId, rol}`
 * son distintos, así que quedaban los DOS y el grupo salía duplicado en
 * "Mis grupos". Con el mapa indexado por código, ese bug no se puede ni
 * escribir.
 */
async function vincularComoParticipante(clave, codigo, participanteId) {
  if (!clave) return;
  const ref = usuarioRef(clave);
  // Se lee para saber si ya había rol: si no lo hubiera y no lo
  // pusiéramos, la entrada quedaría sin rol y "Mis grupos" no sabría si
  // eres organizador.
  const snap = await ref.get();
  const rol = (snap.data()?.grupos || {})[codigo]?.rol || "participante";
  await ref.set({grupos: {[codigo]: {rol, participanteId}}}, {merge: true});
}

exports.crearGrupo = onCall(async (request) => {
  const ocasion = (request.data?.ocasion || "").trim();
  const valorMinimo = (request.data?.valorMinimo || "").trim();
  const nombreGrupo = (request.data?.nombreGrupo || "").trim();
  // Vacío = grupo sin temática: cada quien se registra con su nombre y su
  // foto. Con temática, se registra con un personaje y su imagen.
  const tematica = (request.data?.tematica || "").trim();
  const reglas = (request.data?.reglas || "").trim();

  if (!ocasion || !nombreGrupo) {
    throw new HttpsError("invalid-argument", "Falta la ocasión o el nombre del grupo.", {clave: "faltan_datos_grupo"});
  }

  // La cuenta ya no es opcional: sin ella el grupo quedaría huérfano, sin
  // organizador y sin aparecer en "Mis grupos" de nadie. Aquí se usa
  // `verificarCuenta` y no `autorizar` porque el grupo todavía no existe:
  // no hay vínculo que consultar.
  const {clave} = await verificarCuenta(request.data?.nickname, request.data?.password);

  // Reintenta si el código generado (poco probable) ya existe.
  for (let intento = 0; intento < 5; intento++) {
    const codigo = generarCodigo();
    const ref = grupoRef(codigo);
    try {
      await db.runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        if (snap.exists) {
          throw new HttpsError("already-exists", "código repetido, reintentar");
        }
        tx.set(ref, {
          ocasion,
          valorMinimo,
          nombreGrupo,
          tematica,
          reglas,
          fecha: FieldValue.serverTimestamp(),
        });
      });
      await vincularComoOrganizador(clave, codigo);
      return {codigo};
    } catch (e) {
      if (e instanceof HttpsError && e.message === "código repetido, reintentar") {
        continue;
      }
      throw e;
    }
  }
  throw new HttpsError("internal", "No se pudo generar un código único, intenta de nuevo.", {clave: "codigo_no_generado"});
});

exports.agregarParticipante = onCall(async (request) => {
  const codigo = (request.data?.codigo || "").trim();
  const nombre = (request.data?.nombre || "").trim();
  const deseos = (request.data?.deseos || "").trim();

  if (!codigo || !nombre) {
    throw new HttpsError("invalid-argument", "Falta el grupo o el nombre.", {clave: "faltan_datos_participante"});
  }

  const grupoSnap = await grupoRef(codigo).get();
  if (!grupoSnap.exists) {
    throw new HttpsError("not-found", "Ese grupo ya no existe.", {clave: "grupo_no_existe"});
  }

  // Tras el sorteo no entra nadie más. Quien se apuntara después quedaría
  // FUERA de la cadena: sin amigo asignado y sin nadie que le regale a
  // él. No es un error que se vea al momento —el grupo parece normal— sino
  // el día de la entrega, cuando esa persona se queda sin regalo.
  //
  // Es la otra mitad de la regla que ya cumple `borrarParticipante`: una
  // vez sorteado, la lista no cambia. Si alguien no puede seguir, se le
  // reemplaza conservando su plaza en la cadena.
  //
  // Clave propia y no `grupo_ya_sorteado`: ese texto dice "a esta persona
  // no se la puede sacar", que es lo que necesita `borrarParticipante` y
  // no tiene ningún sentido para quien acaba de escanear un QR.
  if (grupoSnap.data().sorteado === true) {
    throw new HttpsError(
        "failed-precondition",
        "Este grupo ya sorteó: no se puede entrar.",
        {clave: "grupo_cerrado"},
    );
  }

  // Se verifica antes de subir el avatar: si las credenciales no valen,
  // no queda un avatar huérfano en Storage ni un participante inscrito.
  const sesion = await autorizar(codigo, request.data?.nickname, request.data?.password);

  // Una cuenta, una plaza por grupo. Sin esto, volver a entrar por el
  // código a un grupo donde ya estás creaba un SEGUNDO documento y
  // sobrescribía el puntero de la cuenta: la plaza vieja quedaba huérfana
  // y nadie podía borrarla —tú ya no, porque para el servidor había
  // dejado de ser la tuya— y si el grupo ya había sorteado se quedaba
  // dentro de la cadena como un fantasma.
  //
  // No basta con mirar si el campo está relleno: hay que comprobarlo
  // contra Firestore. Si el vínculo apunta a un participante que ya no
  // existe, volver a entrar DEBE funcionar — es justo el caso de alguien
  // a quien sacaron del grupo y quiere volver.
  if (sesion.participanteId) {
    const plaza = await participanteRef(codigo, sesion.participanteId).get();
    if (plaza.exists) {
      throw new HttpsError(
          "already-exists",
          "Ya tienes una plaza en este grupo.",
          {clave: "ya_estas_en_el_grupo"},
      );
    }
  }

  const ref = grupoRef(codigo).collection("participantes").doc();
  // La imagen se sube antes de escribir en Firestore: si falla, no queda
  // un participante a medias apuntando a un avatar que no existe.
  const avatarUrl = await guardarAvatar(codigo, ref.id, request.data?.avatarBase64);

  const batch = db.batch();
  batch.set(ref, {
    nombre,
    avatarUrl: avatarUrl || "",
    fecha: FieldValue.serverTimestamp(),
    tieneAmigo: false,
  });
  batch.set(participantePrivadoRef(codigo, ref.id), {
    // De qué cuenta es esta plaza. Sin este dato, borrarParticipante no
    // puede limpiar el puntero de usuarios/{x}.grupos —no sabría de
    // quién— y el grupo seguiría saliendo en su "Mis grupos" apuntando a
    // un participante que ya no existe. Este documento está cerrado a
    // cero para el cliente (ver firestore.rules).
    cuenta: sesion.clave,
    deseos: deseos || "¡Sorpréndeme!",
    asignado_a: "",
    nombre_asignado: "",
    deseos_asignado: "",
  });
  await batch.commit();
  await vincularComoParticipante(sesion.clave, codigo, ref.id);
  return {id: ref.id};
});

async function obtenerPrivado(codigo, participanteId) {
  const privSnap = await participantePrivadoRef(codigo, participanteId).get();
  if (!privSnap.exists) {
    throw new HttpsError("not-found", "Ese participante ya no existe.", {clave: "participante_no_existe"});
  }
  return privSnap.data();
}

exports.borrarParticipante = onCall(async (request) => {
  const codigo = (request.data?.codigo || "").trim();
  const participanteId = request.data?.participanteId;
  if (!codigo || !participanteId) {
    throw new HttpsError("invalid-argument", "Falta el grupo o el participante.", {clave: "faltan_datos"});
  }

  const sesion = await autorizar(codigo, request.data?.nickname, request.data?.password);
  // O es tu propia plaza, o eres el organizador.
  if (sesion.participanteId !== participanteId) exigirOrganizador(sesion);

  // Tras el sorteo, sacar a alguien deja a quien le regalaba apuntando a
  // un fantasma —su nombre_asignado sigue ahí pero ya no hay nadie— y ese
  // tercero no se entera hasta el día del intercambio. La salida es
  // reemplazar a la persona conservando su plaza en la cadena (P4), no
  // borrarla.
  const grupoSnap = await grupoRef(codigo).get();
  if (grupoSnap.data()?.sorteado === true) {
    throw new HttpsError(
        "failed-precondition",
        "El sorteo ya se hizo: a esta persona hay que reemplazarla, no sacarla.",
        {clave: "grupo_ya_sorteado"},
    );
  }

  const publico = await participanteRef(codigo, participanteId).get();
  const privado = await participantePrivadoRef(codigo, participanteId).get();
  const cuentaDeLaPlaza = privado.data()?.cuenta;

  const batch = db.batch();
  batch.delete(participanteRef(codigo, participanteId));
  batch.delete(participantePrivadoRef(codigo, participanteId));
  await batch.commit();

  // Se limpia el puntero en su "Mis grupos". Sin esto el grupo quedaría
  // listado apuntando a un participante que ya no existe — era un fallo
  // conocido que no se podía arreglar porque nadie sabía de qué cuenta
  // era la plaza.
  //
  // Pero el ROL vive en esa misma clave, y borrarla entera al organizador
  // que se saca a sí mismo le quitaba el mando de su propio grupo para
  // siempre: sin rol no puede sortear, ni editar, ni sacar a nadie, ni
  // siquiera eliminar el grupo, que quedaba ingobernable e imborrable. Y
  // nada lo frenaba, porque salir uno mismo no pasa por
  // `exigirOrganizador`.
  //
  // Así que al organizador se le conserva la entrada con
  // `participanteId: null`: vuelve al estado de "organizador que todavía
  // no se ha inscrito", que es exactamente lo que es. Al resto sí se le
  // borra la clave, porque para ellos el vínculo entero era la plaza.
  if (cuentaDeLaPlaza) {
    const refCuenta = usuarioRef(cuentaDeLaPlaza);
    const snapCuenta = await refCuenta.get();
    // Si la cuenta ya no existe no hay puntero que limpiar, y `update`
    // sobre un documento ausente lanzaría después de haber borrado ya al
    // participante.
    if (snapCuenta.exists) {
      const vinculo = (snapCuenta.data().grupos || {})[codigo];
      await refCuenta.update(
          new FieldPath("grupos", codigo),
          vinculo?.rol === "organizador" ?
            {rol: "organizador", participanteId: null} :
            FieldValue.delete(),
      );
    }
  }

  await borrarAvatarPorUrl(publico.data()?.avatarUrl);
  return {ok: true};
});

// Cambiar la propia imagen, o quitarle una inapropiada a alguien si eres
// el organizador: `autorizar` ya sabe si eres una cosa o la otra.
// Mandar avatarBase64 vacío o nulo equivale a quitar la imagen.
exports.cambiarAvatar = onCall(async (request) => {
  const codigo = (request.data?.codigo || "").trim();
  const participanteId = request.data?.participanteId;
  if (!codigo || !participanteId) {
    throw new HttpsError("invalid-argument", "Falta el grupo o el participante.", {clave: "faltan_datos"});
  }

  const sesion = await autorizar(codigo, request.data?.nickname, request.data?.password);
  if (sesion.participanteId !== participanteId) exigirOrganizador(sesion);

  const ref = participanteRef(codigo, participanteId);
  const anterior = (await ref.get()).data()?.avatarUrl;
  const nuevaUrl = await guardarAvatar(codigo, participanteId, request.data?.avatarBase64);

  await ref.update({avatarUrl: nuevaUrl || ""});
  await borrarAvatarPorUrl(anterior);
  return {ok: true, avatarUrl: nuevaUrl || ""};
});

// Solo el organizador puede corregir el nombre de un participante (p.ej.
// un error de tipeo) — es una acción del responsable de la actividad.
exports.editarParticipante = onCall(async (request) => {
  const codigo = (request.data?.codigo || "").trim();
  const participanteId = request.data?.participanteId;
  const nuevoNombre = (request.data?.nuevoNombre || "").trim();
  if (!codigo || !participanteId || !nuevoNombre) {
    throw new HttpsError("invalid-argument", "Falta el grupo, el participante o el nuevo nombre.", {clave: "faltan_datos"});
  }

  exigirOrganizador(await autorizar(codigo, request.data?.nickname, request.data?.password));

  const ref = participanteRef(codigo, participanteId);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Ese participante ya no existe.", {clave: "participante_no_existe"});
  }
  await ref.update({nombre: nuevoNombre});
  return {ok: true};
});

// Antes se llamaba `iniciarSesion`, que se confundía con
// `iniciarSesionCuenta` y ya no describe lo que hace: no inicia ninguna
// sesión, revela una asignación.
exports.verAmigoSecreto = onCall(async (request) => {
  const codigo = (request.data?.codigo || "").trim();
  const pin = (request.data?.pin || "").trim();
  if (!codigo) {
    throw new HttpsError("invalid-argument", "Falta el grupo.", {clave: "faltan_datos"});
  }

  const sesion = await autorizar(codigo, request.data?.nickname, request.data?.password);
  exigirParticipante(sesion);

  // El PIN es la segunda barrera: la cuenta ya demostró quién eres. Este
  // protege de que alguien con tu teléfono desbloqueado vea tu
  // asignación. Una vez visto, se vio.
  //
  // El intento SE RESERVA ANTES DE COMPROBARLO, y ese orden es el arreglo.
  //
  // Contar después de comprobar no frena nada aunque el contador fuese
  // atómico: cien peticiones en paralelo leen todas el mismo contador a
  // cero, pasan todas la comprobación de bloqueo, ejecutan todas su
  // bcrypt, y el atacante ya tiene cien respuestas antes de que la primera
  // haya escrito nada. Reservando primero, las cien se serializan en la
  // transacción: cinco se llevan un intento y las otras noventa y cinco
  // salen bloqueadas sin llegar a comparar nada.
  //
  // Cuesta una escritura de más en cada revelación acertada —se incrementa
  // y luego se limpia—. Revelar tu amigo secreto se hace una vez por
  // grupo; el límite de intentos tiene que ser de verdad.
  const ahora = Date.now();
  const refUsuario = usuarioRef(sesion.clave);

  // La transacción DEVUELVE el veredicto en vez de lanzarlo. Lanzar desde
  // dentro haría depender el comportamiento de cómo clasifique el SDK ese
  // error para decidir si reintenta la transacción, que no es una promesa
  // que nos haya hecho nadie.
  const reserva = await db.runTransaction(async (tx) => {
    const snap = await tx.get(refUsuario);
    const datos = snap.data() || {};

    if (ahora < (datos.pinBloqueadoHasta || 0)) {
      return {bloqueado: true, pinHash: ""};
    }

    // Al llegar al tope se bloquea y se reinicia el contador, para que al
    // expirar el bloqueo haya cinco intentos nuevos y no uno solo.
    const fallos = (datos.pinFallos || 0) + 1;
    tx.update(refUsuario, fallos >= MAX_INTENTOS_PIN ?
      {pinFallos: 0, pinBloqueadoHasta: ahora + BLOQUEO_PIN_MS} :
      {pinFallos: fallos});

    // El hash sale de la lectura de DENTRO de la transacción, no del que
    // trajo `autorizar`: si acabas de cambiar tu PIN desde otro
    // dispositivo, el viejo ya no vale.
    return {bloqueado: false, pinHash: datos.pinHash || ""};
  });

  if (reserva.bloqueado) {
    throw new HttpsError(
        "resource-exhausted",
        "Demasiados intentos. Espera un rato o cambia tu PIN desde Configuración.",
        {clave: "pin_bloqueado"},
    );
  }

  if (!reserva.pinHash || !bcrypt.compareSync(pin, reserva.pinHash)) {
    throw new HttpsError("permission-denied", "PIN incorrecto.", {clave: "pin_incorrecto"});
  }

  // Acertó: se devuelve el intento reservado y se limpia el rastro.
  await refUsuario.update({pinFallos: 0, pinBloqueadoHasta: 0});

  const privado = await obtenerPrivado(codigo, sesion.participanteId);
  const publico = await participanteRef(codigo, sesion.participanteId).get();
  return {
    // Tu propio nombre en el grupo. Antes lo sacaba el cliente de la lista
    // de participantes que mostraba PantallaLogin, que desaparece.
    nombre: publico.data()?.nombre || "",
    nombreAmigo: privado.nombre_asignado || "",
    // Vacío y no "Sin sugerencias": el texto por defecto lo pone el
    // cliente traducido, y aquí saldría siempre en español.
    deseosAmigo: privado.deseos_asignado || "",
  };
});

exports.ejecutarSorteo = onCall(async (request) => {
  const codigo = (request.data?.codigo || "").trim();
  if (!codigo) {
    throw new HttpsError("invalid-argument", "Falta el grupo.", {clave: "faltan_datos"});
  }

  exigirOrganizador(await autorizar(codigo, request.data?.nickname, request.data?.password));

  // Se sortea UNA vez. Volver a hacerlo rebaraja a gente que ya vio su
  // asignación y quizá ya compró el regalo: se quedarían con un regalo
  // para alguien que ha dejado de tocarles, y sin saber que ha pasado
  // nada. No hay forma de deshacerlo ni de avisar.
  //
  // Es también lo que sostiene las otras dos reglas del sorteo:
  // `borrarParticipante` y `agregarParticipante` se cierran cuando
  // `sorteado` es true, y esa bandera no valdría de nada si el propio
  // sorteo pudiera volver a correr.
  const grupoSnap = await grupoRef(codigo).get();
  if (!grupoSnap.exists) {
    throw new HttpsError("not-found", "Ese grupo ya no existe.", {clave: "grupo_no_existe"});
  }
  if (grupoSnap.data().sorteado === true) {
    throw new HttpsError(
        "failed-precondition",
        "Este grupo ya sorteó. El sorteo no se puede repetir.",
        {clave: "sorteo_ya_hecho"},
    );
  }

  const snap = await grupoRef(codigo).collection("participantes").get();
  const docs = snap.docs;
  if (docs.length < 2) {
    throw new HttpsError("failed-precondition", "Se necesitan mínimo 2 personas.", {clave: "minimo_dos_personas"});
  }

  const privSnaps = await Promise.all(
      docs.map((d) => participantePrivadoRef(codigo, d.id).get()),
  );

  // Derangement por ciclo aleatorio: nadie se regala a sí mismo.
  const indices = docs.map((_, i) => i);
  for (let i = indices.length - 1; i > 0; i--) {
    const j = randomInt(i + 1);
    [indices[i], indices[j]] = [indices[j], indices[i]];
  }

  const batch = db.batch();
  for (let i = 0; i < indices.length; i++) {
    const iRegala = indices[i];
    const iRecibe = indices[(i + 1) % indices.length];
    const docRecibe = docs[iRecibe];
    const deseosRecibe = privSnaps[iRecibe].data()?.deseos || "¡Sorpréndeme!";
    batch.set(participantePrivadoRef(codigo, docs[iRegala].id), {
      asignado_a: docRecibe.id,
      nombre_asignado: docRecibe.data().nombre,
      deseos_asignado: deseosRecibe,
    }, {merge: true});
    batch.update(docs[iRegala].ref, {tieneAmigo: true});
  }
  // Marca en el documento del grupo, que el cliente ya escucha en vivo.
  // Sin esto, saber si el grupo sorteó exigiría leer todos los
  // participantes buscando un tieneAmigo:true.
  batch.update(grupoRef(codigo), {sorteado: true});
  await batch.commit();
  return {ok: true};
});

// Devuelve la máscara del participante, asignándole una la primera vez.
//
// El sorteo es aleatorio entre las libres, NO por orden de llegada: si
// fuera secuencial, el primero en escribir sería siempre la máscara 0 y
// eso ya es una pista de quién es.
async function obtenerMascara(codigo, participanteId) {
  const privRef = participantePrivadoRef(codigo, participanteId);

  return db.runTransaction(async (tx) => {
    const priv = await tx.get(privRef);
    const datos = priv.data() || {};
    if (typeof datos.mascara === "number") {
      return {mascara: datos.mascara, repeticion: datos.mascaraRepeticion || 0};
    }

    const grupoPrivRef = grupoPrivadoRef(codigo);
    const grupoPriv = await tx.get(grupoPrivRef);
    const usadas = grupoPriv.data()?.mascarasUsadas || [];

    const libres = [];
    for (let i = 0; i < TOTAL_MASCARAS; i++) {
      if (!usadas.includes(i)) libres.push(i);
    }
    // Si el grupo pasa de 16 personas se reutilizan máscaras, y la
    // repetición las distingue ("Zorro Azul 2").
    const mascara = libres.length > 0 ?
      libres[randomInt(libres.length)] :
      randomInt(TOTAL_MASCARAS);
    const repeticion = Math.floor(usadas.length / TOTAL_MASCARAS);

    tx.set(privRef, {mascara, mascaraRepeticion: repeticion}, {merge: true});
    tx.set(grupoPrivRef, {mascarasUsadas: [...usadas, mascara]}, {merge: true});
    return {mascara, repeticion};
  });
}

exports.enviarMensaje = onCall(async (request) => {
  const codigo = (request.data?.codigo || "").trim();
  const texto = (request.data?.texto || "").trim();

  if (!codigo) {
    throw new HttpsError("invalid-argument", "Falta el grupo.", {clave: "faltan_datos"});
  }
  if (!texto) {
    throw new HttpsError("invalid-argument", "El mensaje está vacío.", {clave: "mensaje_vacio"});
  }
  if (texto.length > MAX_MENSAJE) {
    throw new HttpsError("invalid-argument", "El mensaje es demasiado largo.", {clave: "mensaje_largo"});
  }

  const sesion = await autorizar(codigo, request.data?.nickname, request.data?.password);
  exigirParticipante(sesion);
  const participanteId = sesion.participanteId;
  const privado = await obtenerPrivado(codigo, participanteId);

  const ahora = Date.now();
  if (privado.ultimoMensajeMs && ahora - privado.ultimoMensajeMs < ESPERA_ENTRE_MENSAJES_MS) {
    throw new HttpsError("resource-exhausted", "Espera un momento antes de volver a escribir.", {clave: "muy_rapido"});
  }

  const {mascara, repeticion} = await obtenerMascara(codigo, participanteId);

  // El documento público NO lleva participanteId ni nada que permita
  // rastrear al autor. Solo la máscara.
  await grupoRef(codigo).collection("chat").add({
    mascara,
    repeticion,
    texto,
    fecha: FieldValue.serverTimestamp(),
  });
  await participantePrivadoRef(codigo, participanteId).set({ultimoMensajeMs: ahora}, {merge: true});

  return {ok: true, mascara, repeticion};
});

// Moderación: solo el organizador puede borrar un mensaje.
exports.borrarMensaje = onCall(async (request) => {
  const codigo = (request.data?.codigo || "").trim();
  const mensajeId = request.data?.mensajeId;
  if (!codigo || !mensajeId) {
    throw new HttpsError("invalid-argument", "Falta el grupo o el mensaje.", {clave: "faltan_datos"});
  }
  exigirOrganizador(await autorizar(codigo, request.data?.nickname, request.data?.password));
  await grupoRef(codigo).collection("chat").doc(mensajeId).delete();
  return {ok: true};
});

// Le dice al cliente qué máscara le tocó, para poder resaltar sus propios
// mensajes. Se la asigna si todavía no escribía.
exports.miMascara = onCall(async (request) => {
  const codigo = (request.data?.codigo || "").trim();
  if (!codigo) {
    throw new HttpsError("invalid-argument", "Falta el grupo.", {clave: "faltan_datos"});
  }
  const sesion = await autorizar(codigo, request.data?.nickname, request.data?.password);
  exigirParticipante(sesion);
  return await obtenerMascara(codigo, sesion.participanteId);
});

// --- Acciones de organizador -----------------------------------------
// Cada una comprueba `exigirOrganizador` por su cuenta: no hay ya un PIN
// maestro que desbloquee un "modo organizador" en el cliente, así que no
// hay nada que memorizar entre acciones.

// Campos del grupo que el organizador puede cambiar después de crearlo.
const CAMPOS_EDITABLES = ["nombreGrupo", "valorMinimo", "tematica", "reglas"];
const MAX_REGLAS = 2000;

exports.editarGrupo = onCall(async (request) => {
  const codigo = (request.data?.codigo || "").trim();
  if (!codigo) {
    throw new HttpsError("invalid-argument", "Falta el grupo.", {clave: "faltan_datos"});
  }
  exigirOrganizador(await autorizar(codigo, request.data?.nickname, request.data?.password));

  // Solo se tocan los campos que vengan en la petición: así la pantalla
  // puede mandar un cambio suelto sin pisar los demás.
  const cambios = {};
  for (const campo of CAMPOS_EDITABLES) {
    if (typeof request.data?.[campo] === "string") {
      cambios[campo] = request.data[campo].trim();
    }
  }

  if (Object.keys(cambios).length === 0) {
    throw new HttpsError("invalid-argument", "No hay nada que cambiar.", {clave: "nada_que_cambiar"});
  }
  if (cambios.nombreGrupo === "") {
    throw new HttpsError("invalid-argument", "El nombre del grupo no puede quedar vacío.", {clave: "nombre_vacio"});
  }
  if ((cambios.reglas || "").length > MAX_REGLAS) {
    throw new HttpsError(
        "invalid-argument",
        `Las reglas no pueden pasar de ${MAX_REGLAS} caracteres.`,
        {clave: "reglas_muy_largas"},
    );
  }

  await grupoRef(codigo).update(cambios);
  return {ok: true, cambios};
});

// Irreversible: borra el grupo y todos los participantes con sus datos
// privados. Las referencias que queden en las cuentas
// (usuarios/{nickname}.grupos) se limpian solas al siguiente inicio de
// sesión — ver iniciarSesionCuenta.
exports.eliminarGrupo = onCall(async (request) => {
  const codigo = (request.data?.codigo || "").trim();
  if (!codigo) {
    throw new HttpsError("invalid-argument", "Falta el grupo.", {clave: "faltan_datos"});
  }
  exigirOrganizador(await autorizar(codigo, request.data?.nickname, request.data?.password));

  // recursiveDelete baja por las subcolecciones (participantes y cada
  // privado/data) y parte el trabajo en lotes por dentro.
  await db.recursiveDelete(grupoRef(codigo));

  // recursiveDelete ya se llevó la subcolección chat/ con lo demás.
  // Y los avatares del grupo, que viven en Storage y no en Firestore.
  try {
    await getStorage().bucket(BUCKET).deleteFiles({prefix: `avatares/${codigo}/`});
  } catch (e) {
    console.warn("No se pudieron borrar los avatares del grupo:", e.message);
  }
  return {ok: true};
});
