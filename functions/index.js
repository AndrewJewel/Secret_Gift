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

// --- Cuentas (nickname + contraseña + PIN) ---------------------------
// La cuenta es la ÚNICA credencial de autorización de la app. El PIN de 4
// dígitos es una segunda barrera para una sola acción —revelar tu amigo
// secreto— y no autoriza nada más.
//
// Antes había un PIN por participante y un PIN maestro por grupo, los dos
// en texto plano. Eran de cuando no existían las cuentas.

const REGEX_PASSWORD = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}$/;

// El PIN es la SEGUNDA barrera, no la primera: la cuenta ya demostró
// quién eres. Este protege de que alguien con tu teléfono desbloqueado
// vea tu asignación, que es lo único irreversible de la app.
const REGEX_PIN = /^\d{4}$/;

// Cinco intentos y quince minutos de espera convierten 10.000 combinaciones en
// semanas de trabajo. No deja a nadie fuera para siempre: quien se bloquee
// cambia su PIN con la contraseña de la cuenta y sigue.
const MAX_INTENTOS_PIN = 5;
const BLOQUEO_PIN_MS = 15 * 60 * 1000;

function validarPin(pin) {
  if (!REGEX_PIN.test(pin || "")) {
    throw new HttpsError("invalid-argument", "El PIN debe ser de 4 dígitos exactos.", {clave: "pin_formato"});
  }
}

function normalizarNickname(nickname) {
  return (nickname || "").trim().toLowerCase();
}

function validarPassword(password) {
  if (!REGEX_PASSWORD.test(password || "")) {
    throw new HttpsError(
        "invalid-argument",
        "La contraseña debe tener mínimo 8 caracteres, una mayúscula, una minúscula, un número y un carácter especial.",
        {clave: "password_debil"},
    );
  }
}

function usuarioRef(nicknameNormalizado) {
  return db.collection("usuarios").doc(nicknameNormalizado);
}

exports.registrarCuenta = onCall(async (request) => {
  const nickname = (request.data?.nickname || "").trim();
  const password = request.data?.password || "";
  const clave = normalizarNickname(nickname);

  if (clave.length < 3 || clave.length > 24) {
    throw new HttpsError("invalid-argument", "El nickname debe tener entre 3 y 24 caracteres.", {clave: "nickname_largo"});
  }
  validarPassword(password);

  const pin = (request.data?.pin || "").trim();
  validarPin(pin);

  const hash = bcrypt.hashSync(password, 10);
  try {
    await usuarioRef(clave).create({
      nickname,
      hash,
      // Con bcrypt igual que la contraseña. Son 10.000 combinaciones: este
      // rediseño existe justamente para sacar secretos en claro de
      // Firestore, no para meter uno nuevo.
      pinHash: bcrypt.hashSync(pin, 10),
      fecha: FieldValue.serverTimestamp(),
      grupos: {},
    });
  } catch (e) {
    if (e.code === 6 || e.code === "already-exists") {
      throw new HttpsError("already-exists", "Ese nickname ya está en uso. Elige otro.", {clave: "nickname_en_uso"});
    }
    throw e;
  }
  return {ok: true, nickname};
});

// Cambiar el PIN pide la contraseña de la cuenta. No es burocracia: es la
// ÚNICA salida si lo olvidas. Sin ella, cuatro dígitos olvidados te
// dejarían sin ver tu amigo secreto para siempre — y esta app tampoco
// tiene recuperación de contraseña.
exports.cambiarPin = onCall(async (request) => {
  const clave = normalizarNickname(request.data?.nickname);
  const password = request.data?.password || "";
  const pinNuevo = (request.data?.pinNuevo || "").trim();

  validarPin(pinNuevo);

  const snap = await usuarioRef(clave).get();
  if (!snap.exists || !bcrypt.compareSync(password, snap.data().hash)) {
    throw new HttpsError("unauthenticated", "La contraseña no es correcta.", {clave: "password_incorrecta"});
  }

  await usuarioRef(clave).update({
    pinHash: bcrypt.hashSync(pinNuevo, 10),
    // Cambiar el PIN levanta el bloqueo: es la salida de emergencia de quien se
    // quedó fuera intentándolo. Sin esto, quien acierta su contraseña y fija un
    // PIN nuevo seguiría bloqueado quince minutos con el PIN correcto.
    pinFallos: 0,
    pinBloqueadoHasta: 0,
  });
  return {ok: true};
});

exports.iniciarSesionCuenta = onCall(async (request) => {
  const nickname = (request.data?.nickname || "").trim();
  const password = request.data?.password || "";
  const clave = normalizarNickname(nickname);

  const snap = await usuarioRef(clave).get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Ese nickname no existe.", {clave: "nickname_no_existe"});
  }
  const datos = snap.data();
  if (!bcrypt.compareSync(password, datos.hash)) {
    throw new HttpsError("permission-denied", "Contraseña incorrecta.", {clave: "password_incorrecta"});
  }

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
      await usuarioRef(clave).update(
          new FieldPath("grupos", codigo),
          FieldValue.delete(),
      );
    }
  }

  return {nickname: datos.nickname, grupos: detalles};
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
