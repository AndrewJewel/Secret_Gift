const {onCall, HttpsError} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const bcrypt = require("bcryptjs");

admin.initializeApp();
const db = admin.firestore();

// Sin caracteres ambiguos (0/O, 1/I/L) para que sea fácil de dictar/escribir.
const ALFABETO_CODIGO = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";

function generarCodigo() {
  let letras = "";
  for (let i = 0; i < 4; i++) {
    letras += ALFABETO_CODIGO[Math.floor(Math.random() * ALFABETO_CODIGO.length)];
  }
  let numeros = "";
  for (let i = 0; i < 4; i++) {
    numeros += ALFABETO_CODIGO[Math.floor(Math.random() * ALFABETO_CODIGO.length)];
  }
  return `${letras}-${numeros}`;
}

// --- Avatares ---------------------------------------------------------
// Las imágenes entran por aquí, nunca directo del cliente al bucket: la
// app no usa Firebase Auth, así que unas reglas de Storage que permitan
// escribir dejarían el bucket abierto a cualquiera. Subiéndolas por la
// función, el PIN del participante es la autorización, igual que en el
// resto de la app.

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
  const archivo = admin.storage().bucket(BUCKET).file(ruta);
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
    await admin.storage().bucket(BUCKET).file(url.slice(prefijo.length)).delete();
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

// --- Cuentas (nickname + contraseña) ---------------------------------
// Independientes del PIN de cada grupo: sirven solo para que una persona
// encuentre "mis grupos" desde cualquier dispositivo. El PIN de grupo
// sigue siendo lo único que revela el amigo secreto.

const REGEX_PASSWORD = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}$/;

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

  const hash = bcrypt.hashSync(password, 10);
  try {
    await usuarioRef(clave).create({
      nickname,
      hash,
      fecha: admin.firestore.FieldValue.serverTimestamp(),
      grupos: [],
    });
  } catch (e) {
    if (e.code === 6 || e.code === "already-exists") {
      throw new HttpsError("already-exists", "Ese nickname ya está en uso. Elige otro.", {clave: "nickname_en_uso"});
    }
    throw e;
  }
  return {ok: true, nickname};
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

  const grupos = datos.grupos || [];
  const detalles = (await Promise.all(grupos.map(async (g) => {
    const gs = await grupoRef(g.codigo).get();
    if (!gs.exists) return null;
    return {
      codigo: g.codigo,
      rol: g.rol,
      ocasion: gs.data().ocasion,
      valorMinimo: gs.data().valorMinimo,
      nombreGrupo: gs.data().nombreGrupo || "",
      tematica: gs.data().tematica || "",
    };
  }))).filter(Boolean);

  // Si algún grupo vinculado ya no existe (su organizador lo eliminó), se
  // limpia aquí la referencia muerta. Así eliminarGrupo no tiene que
  // recorrer toda la colección de usuarios buscando a quién avisarle.
  if (detalles.length !== grupos.length) {
    const vivos = new Set(detalles.map((d) => d.codigo));
    await usuarioRef(clave).update({grupos: grupos.filter((g) => vivos.has(g.codigo))});
  }

  return {nickname: datos.nickname, grupos: detalles};
});

// Verifica nickname+password (si vienen) y vincula un grupo a esa cuenta.
// Si no vienen credenciales, no hace nada — vincular cuenta es opcional.
async function vincularCuentaSiAplica(nickname, password, entrada) {
  if (!nickname || !password) return;
  const clave = normalizarNickname(nickname);
  const ref = usuarioRef(clave);
  const snap = await ref.get();
  if (!snap.exists || !bcrypt.compareSync(password, snap.data().hash)) {
    // Antes se ignoraba en silencio para no romper el alta por un extra.
    // Con la cuenta ya obligatoria eso deja de valer: el grupo no
    // aparecería en "Mis grupos" y nadie sabría por qué.
    throw new HttpsError("unauthenticated", "La sesión de tu cuenta no es válida. Vuelve a entrar.", {clave: "sesion_invalida"});
  }
  await ref.update({grupos: admin.firestore.FieldValue.arrayUnion(entrada)});
}

exports.crearGrupo = onCall(async (request) => {
  const ocasion = (request.data?.ocasion || "").trim();
  const pinMaestro = (request.data?.pinMaestro || "").trim();
  const valorMinimo = (request.data?.valorMinimo || "").trim();
  const nombreGrupo = (request.data?.nombreGrupo || "").trim();
  // Vacío = grupo sin temática: cada quien se registra con su nombre y su
  // foto. Con temática, se registra con un personaje y su imagen.
  const tematica = (request.data?.tematica || "").trim();
  const reglas = (request.data?.reglas || "").trim();
  const nickname = request.data?.nickname;
  const password = request.data?.password;

  if (!ocasion || !pinMaestro || !nombreGrupo) {
    throw new HttpsError("invalid-argument", "Falta la ocasión, el nombre del grupo o el PIN maestro.", {clave: "faltan_datos_grupo"});
  }

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
          fecha: admin.firestore.FieldValue.serverTimestamp(),
        });
        tx.set(grupoPrivadoRef(codigo), {pinMaestro});
      });
      await vincularCuentaSiAplica(nickname, password, {codigo, rol: "organizador"});
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
  const pin = (request.data?.pin || "").trim();
  const deseos = (request.data?.deseos || "").trim();
  const nickname = request.data?.nickname;
  const password = request.data?.password;

  if (!codigo || !nombre || !pin) {
    throw new HttpsError("invalid-argument", "Falta el grupo, el nombre o el PIN.", {clave: "faltan_datos_participante"});
  }

  const grupoSnap = await grupoRef(codigo).get();
  if (!grupoSnap.exists) {
    throw new HttpsError("not-found", "Ese grupo ya no existe.", {clave: "grupo_no_existe"});
  }

  const ref = grupoRef(codigo).collection("participantes").doc();
  // La imagen se sube antes de escribir en Firestore: si falla, no queda
  // un participante a medias apuntando a un avatar que no existe.
  const avatarUrl = await guardarAvatar(codigo, ref.id, request.data?.avatarBase64);

  const batch = db.batch();
  batch.set(ref, {
    nombre,
    avatarUrl: avatarUrl || "",
    fecha: admin.firestore.FieldValue.serverTimestamp(),
    tieneAmigo: false,
  });
  batch.set(participantePrivadoRef(codigo, ref.id), {
    pin,
    deseos: deseos || "¡Sorpréndeme!",
    asignado_a: "",
    nombre_asignado: "",
    deseos_asignado: "",
  });
  await batch.commit();
  await vincularCuentaSiAplica(nickname, password, {codigo, participanteId: ref.id, rol: "participante"});
  return {id: ref.id};
});

async function obtenerPrivado(codigo, participanteId) {
  const privSnap = await participantePrivadoRef(codigo, participanteId).get();
  if (!privSnap.exists) {
    throw new HttpsError("not-found", "Ese participante ya no existe.", {clave: "participante_no_existe"});
  }
  return privSnap.data();
}

// El PIN maestro identifica a quien creó el grupo. Es la credencial de
// TODAS las acciones de organizador (editar el grupo, corregir nombres,
// sortear, eliminar) y nunca sirve para ver el amigo secreto de nadie.
async function verificarPinMaestro(codigo, pinIngresado) {
  const snap = await grupoPrivadoRef(codigo).get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Ese grupo ya no existe.", {clave: "grupo_no_existe"});
  }
  if ((pinIngresado || "").trim() !== snap.data().pinMaestro) {
    throw new HttpsError("permission-denied", "PIN incorrecto.", {clave: "pin_incorrecto"});
  }
  return snap.data();
}

// Para acciones administrativas (borrar): el PIN propio o el PIN maestro
// del responsable de la actividad sirven por igual.
async function verificarPinOAdmin(codigo, participanteId, pinIngresado) {
  const privado = await obtenerPrivado(codigo, participanteId);
  if (pinIngresado === privado.pin) return privado;

  const grupoPrivSnap = await grupoPrivadoRef(codigo).get();
  if (pinIngresado === grupoPrivSnap.data()?.pinMaestro) return privado;

  throw new HttpsError("permission-denied", "PIN incorrecto.", {clave: "pin_incorrecto"});
}

// Para revelar el amigo secreto: SOLO el PIN propio, nunca el maestro. El
// responsable de la actividad no debe poder espiar asignaciones ajenas.
async function verificarPinPropio(codigo, participanteId, pinIngresado) {
  const privado = await obtenerPrivado(codigo, participanteId);
  if (pinIngresado === privado.pin) return privado;
  throw new HttpsError("permission-denied", "PIN incorrecto.", {clave: "pin_incorrecto"});
}

exports.borrarParticipante = onCall(async (request) => {
  const codigo = (request.data?.codigo || "").trim();
  const participanteId = request.data?.participanteId;
  const pin = (request.data?.pin || "").trim();
  if (!codigo || !participanteId) {
    throw new HttpsError("invalid-argument", "Falta el grupo o el participante.", {clave: "faltan_datos"});
  }

  await verificarPinOAdmin(codigo, participanteId, pin);

  const publico = await participanteRef(codigo, participanteId).get();
  const batch = db.batch();
  batch.delete(participanteRef(codigo, participanteId));
  batch.delete(participantePrivadoRef(codigo, participanteId));
  await batch.commit();
  await borrarAvatarPorUrl(publico.data()?.avatarUrl);
  return {ok: true};
});

// Cambiar la propia imagen (con el PIN propio) o quitarle una inapropiada
// a alguien (con el PIN maestro): verificarPinOAdmin acepta las dos.
// Mandar avatarBase64 vacío o nulo equivale a quitar la imagen.
exports.cambiarAvatar = onCall(async (request) => {
  const codigo = (request.data?.codigo || "").trim();
  const participanteId = request.data?.participanteId;
  const pin = (request.data?.pin || "").trim();
  if (!codigo || !participanteId) {
    throw new HttpsError("invalid-argument", "Falta el grupo o el participante.", {clave: "faltan_datos"});
  }

  await verificarPinOAdmin(codigo, participanteId, pin);

  const ref = participanteRef(codigo, participanteId);
  const anterior = (await ref.get()).data()?.avatarUrl;
  const nuevaUrl = await guardarAvatar(codigo, participanteId, request.data?.avatarBase64);

  await ref.update({avatarUrl: nuevaUrl || ""});
  await borrarAvatarPorUrl(anterior);
  return {ok: true, avatarUrl: nuevaUrl || ""};
});

// Solo el PIN maestro puede corregir el nombre de un participante (p.ej.
// un error de tipeo) — es una acción del responsable de la actividad.
exports.editarParticipante = onCall(async (request) => {
  const codigo = (request.data?.codigo || "").trim();
  const participanteId = request.data?.participanteId;
  const nuevoNombre = (request.data?.nuevoNombre || "").trim();
  const pinMaestro = (request.data?.pinMaestro || "").trim();
  if (!codigo || !participanteId || !nuevoNombre) {
    throw new HttpsError("invalid-argument", "Falta el grupo, el participante o el nuevo nombre.", {clave: "faltan_datos"});
  }

  await verificarPinMaestro(codigo, pinMaestro);

  const ref = participanteRef(codigo, participanteId);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Ese participante ya no existe.", {clave: "participante_no_existe"});
  }
  await ref.update({nombre: nuevoNombre});
  return {ok: true};
});

exports.iniciarSesion = onCall(async (request) => {
  const codigo = (request.data?.codigo || "").trim();
  const participanteId = request.data?.participanteId;
  const pin = (request.data?.pin || "").trim();
  if (!codigo || !participanteId) {
    throw new HttpsError("invalid-argument", "Falta el grupo o el participante.", {clave: "faltan_datos"});
  }

  const privado = await verificarPinPropio(codigo, participanteId, pin);
  return {
    nombreAmigo: privado.nombre_asignado || "",
    deseosAmigo: privado.deseos_asignado || "Sin sugerencias",
  };
});

exports.ejecutarSorteo = onCall(async (request) => {
  const codigo = (request.data?.codigo || "").trim();
  const pin = (request.data?.pinMaestro || "").trim();
  if (!codigo) {
    throw new HttpsError("invalid-argument", "Falta el grupo.", {clave: "faltan_datos"});
  }

  await verificarPinMaestro(codigo, pin);

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
    const j = Math.floor(Math.random() * (i + 1));
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
      libres[Math.floor(Math.random() * libres.length)] :
      Math.floor(Math.random() * TOTAL_MASCARAS);
    const repeticion = Math.floor(usadas.length / TOTAL_MASCARAS);

    tx.set(privRef, {mascara, mascaraRepeticion: repeticion}, {merge: true});
    tx.set(grupoPrivRef, {mascarasUsadas: [...usadas, mascara]}, {merge: true});
    return {mascara, repeticion};
  });
}

exports.enviarMensaje = onCall(async (request) => {
  const codigo = (request.data?.codigo || "").trim();
  const participanteId = request.data?.participanteId;
  const pin = (request.data?.pin || "").trim();
  const texto = (request.data?.texto || "").trim();

  if (!codigo || !participanteId) {
    throw new HttpsError("invalid-argument", "Falta el grupo o el participante.", {clave: "faltan_datos"});
  }
  if (!texto) {
    throw new HttpsError("invalid-argument", "El mensaje está vacío.", {clave: "mensaje_vacio"});
  }
  if (texto.length > MAX_MENSAJE) {
    throw new HttpsError("invalid-argument", "El mensaje es demasiado largo.", {clave: "mensaje_largo"});
  }

  // PIN propio, nunca el maestro: el organizador no debe poder escribir
  // suplantando a otra persona.
  const privado = await verificarPinPropio(codigo, participanteId, pin);

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
    fecha: admin.firestore.FieldValue.serverTimestamp(),
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
  await verificarPinMaestro(codigo, request.data?.pinMaestro);
  await grupoRef(codigo).collection("chat").doc(mensajeId).delete();
  return {ok: true};
});

// Le dice al cliente qué máscara le tocó, para poder resaltar sus propios
// mensajes. Se la asigna si todavía no escribía.
exports.miMascara = onCall(async (request) => {
  const codigo = (request.data?.codigo || "").trim();
  const participanteId = request.data?.participanteId;
  if (!codigo || !participanteId) {
    throw new HttpsError("invalid-argument", "Falta el grupo o el participante.", {clave: "faltan_datos"});
  }
  await verificarPinPropio(codigo, participanteId, (request.data?.pin || "").trim());
  return await obtenerMascara(codigo, participanteId);
});

// --- Acciones de organizador -----------------------------------------
// Quien creó el grupo desbloquea el "modo organizador" una sola vez con el
// PIN maestro y desde ahí edita todo, en vez de que cada acción suelta le
// vuelva a pedir el PIN.

// Solo confirma que el PIN maestro es correcto: es lo que desbloquea los
// controles de organizador en la pantalla del grupo.
exports.verificarOrganizador = onCall(async (request) => {
  const codigo = (request.data?.codigo || "").trim();
  if (!codigo) {
    throw new HttpsError("invalid-argument", "Falta el grupo.", {clave: "faltan_datos"});
  }
  await verificarPinMaestro(codigo, request.data?.pinMaestro);
  return {ok: true};
});

// Campos del grupo que el organizador puede cambiar después de crearlo.
const CAMPOS_EDITABLES = ["nombreGrupo", "valorMinimo", "tematica", "reglas"];
const MAX_REGLAS = 2000;

exports.editarGrupo = onCall(async (request) => {
  const codigo = (request.data?.codigo || "").trim();
  if (!codigo) {
    throw new HttpsError("invalid-argument", "Falta el grupo.", {clave: "faltan_datos"});
  }
  await verificarPinMaestro(codigo, request.data?.pinMaestro);

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

// Irreversible: borra el grupo, su PIN maestro, y todos los participantes
// con sus datos privados. Las referencias que queden en las cuentas
// (usuarios/{nickname}.grupos) se limpian solas al siguiente inicio de
// sesión — ver iniciarSesionCuenta.
exports.eliminarGrupo = onCall(async (request) => {
  const codigo = (request.data?.codigo || "").trim();
  if (!codigo) {
    throw new HttpsError("invalid-argument", "Falta el grupo.", {clave: "faltan_datos"});
  }
  await verificarPinMaestro(codigo, request.data?.pinMaestro);

  // recursiveDelete baja por las subcolecciones (participantes y cada
  // privado/data) y parte el trabajo en lotes por dentro.
  await db.recursiveDelete(grupoRef(codigo));

  // recursiveDelete ya se llevó la subcolección chat/ con lo demás.
  // Y los avatares del grupo, que viven en Storage y no en Firestore.
  try {
    await admin.storage().bucket(BUCKET).deleteFiles({prefix: `avatares/${codigo}/`});
  } catch (e) {
    console.warn("No se pudieron borrar los avatares del grupo:", e.message);
  }
  return {ok: true};
});
