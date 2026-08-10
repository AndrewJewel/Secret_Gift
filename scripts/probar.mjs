// Prueba de integración contra las funciones DESPLEGADAS.
//
// Vive en el repo a propósito: la versión anterior era un .ps1 en un
// directorio de sesión sin trackear y se perdió, así que hubo que
// reescribirla de memoria.
//
// Usa DOS cuentas de prueba, no una: functions/index.js prohíbe que una
// misma cuenta tenga dos plazas vivas en el mismo grupo (clave
// `ya_estas_en_el_grupo`, ver agregarParticipante). Para ejercitar "sacar a
// alguien antes del sorteo" y "se necesitan dos para sortear" hace falta un
// segundo cuerpo real: la cuenta ORGANIZADORA crea el grupo y se apunta ella
// misma, y la cuenta PARTICIPANTE entra y sale para completar el aforo.
//
// Uso:  node scripts/probar.mjs
// Crea un grupo de usar y tirar y lo borra al terminar. Las DOS CUENTAS de
// prueba (prueba_<marca de tiempo> y prueba2_<marca de tiempo>) se quedan:
// no hay ninguna función que borre cuentas, y añadirla solo para esto
// abriría una superficie que nadie más necesita. Son documentos pequeños y
// con prefijo reconocible; si molestan, se limpian a mano desde la consola
// de Firebase.

const BASE = "https://us-central1-santa-secreto-860c3.cloudfunctions.net";
// Para leer documentos directamente y comprobar lo que el servidor escribió,
// no solo lo que responde. `grupos/{codigo}` y sus participantes son de
// lectura pública por diseño (ver firestore.rules); la colección NO se puede
// listar, pero un documento concreto sí se puede pedir.
const BUCKET = "santa-secreto-860c3.firebasestorage.app";
const FIRESTORE =
  "https://firestore.googleapis.com/v1/projects/santa-secreto-860c3/databases/(default)/documents";

// Un JPEG de 1×1 píxel. Existe solo para que algo real pase por Cloud
// Storage: sin él, guardarAvatar y borrarAvatarPorUrl no los prueba nadie.
const JPEG_1PX =
  "/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRof" +
  "Hh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAAB" +
  "AAAAAAAAAAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AKp//2Q==";

const sufijo = Date.now().toString(36);
// Organizadora: crea el grupo, se apunta como "Yo mismo" y es a quien se le
// comprueba el ciclo completo de PIN (revelación, cambio, bloqueo, rescate).
const NICK_ORGANIZADOR = `prueba_${sufijo}`;
// Participante: solo existe para dar cuerpo a "otra persona" — se le saca
// del grupo y se le vuelve a meter, pero nunca se le revela su amigo
// secreto, así que su PIN no importa más allá de cumplir el formato.
const NICK_PARTICIPANTE = `prueba2_${sufijo}`;
const PASSWORD = "Prueba123!";
const PIN = "4321";
const PIN_PARTICIPANTE = "6789";
const PIN_NUEVO = "9876";
// El tercer PIN existe para probar la salida de emergencia: cambiarlo estando
// bloqueado tiene que levantar el bloqueo.
const PIN_RESCATE = "5555";

// Copiada de functions/index.js. Si allí cambia, aquí también: el bucle de
// abajo se apoya en ella para saber cuántos fallos hacen falta.
const MAX_INTENTOS_PIN = 5;

let fallos = 0;

async function llamar(nombre, datos) {
  const resp = await fetch(`${BASE}/${nombre}`, {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({data: datos}),
  });
  const body = await resp.json();
  if (body.error) {
    const err = new Error(body.error.message);
    err.clave = body.error.details?.clave;
    throw err;
  }
  return body.result;
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

async function main() {
  console.log(`Cuenta organizadora: ${NICK_ORGANIZADOR}`);
  console.log(`Cuenta participante: ${NICK_PARTICIPANTE}`);

  await debeFallar("registrarCuenta rechaza un PIN de 3 dígitos", "pin_formato",
      () => llamar("registrarCuenta", {nickname: NICK_ORGANIZADOR, password: PASSWORD, pin: "123"}));

  const registro = await llamar("registrarCuenta",
      {nickname: NICK_ORGANIZADOR, password: PASSWORD, pin: PIN});
  ok("registrarCuenta con PIN de 4 dígitos", registro.nickname === NICK_ORGANIZADOR, `llegó ${registro.nickname}`);

  // Segunda cuenta, la que hará de "otra persona" más abajo.
  const registroParticipante = await llamar("registrarCuenta",
      {nickname: NICK_PARTICIPANTE, password: PASSWORD, pin: PIN_PARTICIPANTE});
  ok("registrarCuenta de la segunda cuenta (participante)",
      registroParticipante.nickname === NICK_PARTICIPANTE, `llegó ${registroParticipante.nickname}`);

  const credOrganizador = {nickname: NICK_ORGANIZADOR, password: PASSWORD};
  const credParticipante = {nickname: NICK_PARTICIPANTE, password: PASSWORD};

  const {codigo} = await llamar("crearGrupo", {
    ...credOrganizador, ocasion: "amigoSecreto", nombreGrupo: "Grupo de prueba",
    valorMinimo: "10", tematica: "", reglas: "",
  });
  ok("crearGrupo sin PIN maestro", typeof codigo === "string");

  // EL BUG QUE ORIGINÓ TODO ESTO: crear un grupo y apuntarse a él lo sacaba
  // DOS veces en Mis grupos, porque arrayUnion guardaba dos entradas.
  const {id} = await llamar("agregarParticipante", {
    ...credOrganizador, codigo, nombre: "Yo mismo", deseos: "Nada",
  });

  const sesion = await llamar("iniciarSesionCuenta", credOrganizador);
  const deEsteGrupo = sesion.grupos.filter((g) => g.codigo === codigo);
  ok("el grupo sale UNA sola vez tras crearlo y apuntarse",
      deEsteGrupo.length === 1, `salió ${deEsteGrupo.length} veces`);
  ok("conserva el rol de organizador", deEsteGrupo[0]?.rol === "organizador");
  ok("trae el participanteId", deEsteGrupo[0]?.participanteId === id);
  ok("todavía sin sortear", deEsteGrupo[0]?.sorteado === false);

  await debeFallar("verAmigoSecreto rechaza un PIN equivocado", "pin_incorrecto",
      () => llamar("verAmigoSecreto", {...credOrganizador, codigo, pin: "0000"}));

  await debeFallar("una contraseña equivocada no autoriza nada", "sesion_invalida",
      () => llamar("ejecutarSorteo", {nickname: NICK_ORGANIZADOR, password: "Otra123!", codigo}));

  // Antes del sorteo sí se puede sacar a alguien. La organizadora YA tiene
  // su plaza (arriba), así que quien entra aquí tiene que ser la segunda
  // cuenta: reusar credOrganizador chocaría con "ya_estas_en_el_grupo".
  // Entra CON avatar, y es lo único de toda la batería que toca Cloud
  // Storage. Sin esto, `guardarAvatar` y `borrarAvatarPorUrl` no los
  // ejercita nadie: son las dos únicas funciones del fichero que salen de
  // Firestore, así que un fallo suyo pasaba entero por debajo de esta
  // prueba. Se destapó al migrar a firebase-admin v14, donde
  // `admin.storage()` cambió a `getStorage()`.
  const sobrante = await llamar("agregarParticipante", {
    ...credParticipante, codigo, nombre: "Sobrante", deseos: "",
    avatarBase64: JPEG_1PX,
  });
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
  // borrarParticipante lo comprueba— así que quien llama es credOrganizador.
  const borrado = await llamar("borrarParticipante",
      {...credOrganizador, codigo, participanteId: sobrante.id});
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
  await llamar("agregarParticipante", {...credParticipante, codigo, nombre: "Otra persona", deseos: ""});
  const sorteo = await llamar("ejecutarSorteo", {...credOrganizador, codigo});
  ok("ejecutarSorteo por cuenta", sorteo.ok === true);

  const trasSorteo = await llamar("iniciarSesionCuenta", credOrganizador);
  ok("el grupo queda marcado como sorteado",
      trasSorteo.grupos.find((g) => g.codigo === codigo)?.sorteado === true);

  const amigo = await llamar("verAmigoSecreto", {...credOrganizador, codigo, pin: PIN});
  ok("verAmigoSecreto con el PIN correcto", typeof amigo.nombreAmigo === "string");
  ok("devuelve tu propio nombre", amigo.nombre === "Yo mismo");

  await debeFallar("tras el sorteo NO se puede sacar a nadie", "grupo_ya_sorteado",
      () => llamar("borrarParticipante", {...credOrganizador, codigo, participanteId: id}));

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
      () => llamar("agregarParticipante",
          {...credParticipante, codigo, nombre: "Tarde", deseos: ""}));

  // Repetirlo rebarajaría a gente que ya vio su asignación y quizá ya
  // compró el regalo.
  await debeFallar("el sorteo NO se puede repetir", "sorteo_ya_hecho",
      () => llamar("ejecutarSorteo", {...credOrganizador, codigo}));

  const cambio = await llamar("cambiarPin", {nickname: NICK_ORGANIZADOR, password: PASSWORD, pinNuevo: PIN_NUEVO});
  await debeFallar("el PIN viejo ya no vale", "pin_incorrecto",
      () => llamar("verAmigoSecreto", {...credOrganizador, codigo, pin: PIN}));
  ok("cambiarPin", cambio.ok === true);

  // --- El bloqueo por intentos fallidos y su salida de emergencia -------
  //
  // Es la única parte del rediseño cuyo fallo es irreversible: si el bloqueo
  // se pusiera y no se levantara, esa cuenta se quedaría sin ver su amigo
  // secreto para siempre. Se ejerce entera, hasta el rescate. Todo este
  // bloque usa credOrganizador: el PIN es una propiedad de la organizadora,
  // la cuenta participante nunca revela nada y no le corresponde este ciclo.
  //
  // El bucle no cuenta intentos exactos a propósito: el fallo de arriba ("el
  // PIN viejo ya no vale") ya gastó uno, y el intento que PROVOCA el bloqueo
  // todavía responde `pin_incorrecto` —el contador se mira antes de comparar,
  // así que el bloqueo no se ve hasta la llamada siguiente—. Se falla hasta
  // que el servidor lo dice, con un tope para no colgarse si nunca lo dice.
  let claveDelBloqueo = "";
  for (let i = 0; i <= MAX_INTENTOS_PIN + 1 && claveDelBloqueo !== "pin_bloqueado"; i++) {
    try {
      await llamar("verAmigoSecreto", {...credOrganizador, codigo, pin: "0000"});
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
      () => llamar("verAmigoSecreto", {...credOrganizador, codigo, pin: PIN_NUEVO}));

  const rescate = await llamar("cambiarPin",
      {nickname: NICK_ORGANIZADOR, password: PASSWORD, pinNuevo: PIN_RESCATE});
  ok("cambiarPin funciona estando bloqueado", rescate.ok === true);

  // LA PRUEBA QUE IMPORTA: cambiar el PIN con la contraseña de la cuenta
  // levanta el bloqueo en el acto, sin esperar los quince minutos. Sin esto,
  // quien se bloquea se queda fuera y la "salida de emergencia" del diseño
  // sería una promesa sin respaldo.
  const rescatado = await llamar("verAmigoSecreto", {...credOrganizador, codigo, pin: PIN_RESCATE});
  ok("el PIN nuevo levanta el bloqueo y entra",
      typeof rescatado.nombreAmigo === "string");

  await llamar("eliminarGrupo", {...credOrganizador, codigo});
  const final = await llamar("iniciarSesionCuenta", credOrganizador);
  ok("al eliminar el grupo desaparece de Mis grupos",
      final.grupos.every((g) => g.codigo !== codigo));

  console.log(fallos === 0 ? "\nTodo en verde." : `\n${fallos} fallo(s).`);
  process.exit(fallos === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error("Reventó:", e.message, e.clave || "");
  process.exit(1);
});
