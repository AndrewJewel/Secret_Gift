// Prueba de integración contra las funciones DESPLEGADAS.
//
// Vive en el repo a propósito: la versión anterior era un .ps1 en un
// directorio de sesión sin trackear y se perdió, así que hubo que
// reescribirla de memoria.
//
// Uso:  node scripts/probar.mjs
// Crea un grupo de usar y tirar y lo borra al terminar. La CUENTA de prueba
// (prueba_<marca de tiempo>) se queda: no hay ninguna función que borre
// cuentas, y añadirla solo para esto abriría una superficie que nadie más
// necesita. Son documentos pequeños y con prefijo reconocible; si molestan,
// se limpian a mano desde la consola de Firebase.

const BASE = "https://us-central1-santa-secreto-860c3.cloudfunctions.net";

const sufijo = Date.now().toString(36);
const NICK = `prueba_${sufijo}`;
const PASSWORD = "Prueba123!";
const PIN = "4321";
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
  console.log(`Cuenta de prueba: ${NICK}`);

  await debeFallar("registrarCuenta rechaza un PIN de 3 dígitos", "pin_formato",
      () => llamar("registrarCuenta", {nickname: NICK, password: PASSWORD, pin: "123"}));

  const registro = await llamar("registrarCuenta", {nickname: NICK, password: PASSWORD, pin: PIN});
  ok("registrarCuenta con PIN de 4 dígitos", registro.nickname === NICK, `llegó ${registro.nickname}`);

  const cred = {nickname: NICK, password: PASSWORD};

  const {codigo} = await llamar("crearGrupo", {
    ...cred, ocasion: "amigoSecreto", nombreGrupo: "Grupo de prueba",
    valorMinimo: "10", tematica: "", reglas: "",
  });
  ok("crearGrupo sin PIN maestro", typeof codigo === "string");

  // EL BUG QUE ORIGINÓ TODO ESTO: crear un grupo y apuntarse a él lo sacaba
  // DOS veces en Mis grupos, porque arrayUnion guardaba dos entradas.
  const {id} = await llamar("agregarParticipante", {
    ...cred, codigo, nombre: "Yo mismo", deseos: "Nada",
  });

  const sesion = await llamar("iniciarSesionCuenta", cred);
  const deEsteGrupo = sesion.grupos.filter((g) => g.codigo === codigo);
  ok("el grupo sale UNA sola vez tras crearlo y apuntarse",
      deEsteGrupo.length === 1, `salió ${deEsteGrupo.length} veces`);
  ok("conserva el rol de organizador", deEsteGrupo[0]?.rol === "organizador");
  ok("trae el participanteId", deEsteGrupo[0]?.participanteId === id);
  ok("todavía sin sortear", deEsteGrupo[0]?.sorteado === false);

  await debeFallar("verAmigoSecreto rechaza un PIN equivocado", "pin_incorrecto",
      () => llamar("verAmigoSecreto", {...cred, codigo, pin: "0000"}));

  await debeFallar("una contraseña equivocada no autoriza nada", "sesion_invalida",
      () => llamar("ejecutarSorteo", {nickname: NICK, password: "Otra123!", codigo}));

  // Antes del sorteo sí se puede sacar a alguien.
  const segundo = await llamar("agregarParticipante", {
    ...cred, codigo, nombre: "Sobrante", deseos: "",
  });
  const borrado = await llamar("borrarParticipante", {...cred, codigo, participanteId: segundo.id});
  ok("antes del sorteo se puede sacar a alguien", borrado.ok === true);

  // Se necesitan dos para sortear.
  await llamar("agregarParticipante", {...cred, codigo, nombre: "Otra persona", deseos: ""});
  const sorteo = await llamar("ejecutarSorteo", {...cred, codigo});
  ok("ejecutarSorteo por cuenta", sorteo.ok === true);

  const trasSorteo = await llamar("iniciarSesionCuenta", cred);
  ok("el grupo queda marcado como sorteado",
      trasSorteo.grupos.find((g) => g.codigo === codigo)?.sorteado === true);

  const amigo = await llamar("verAmigoSecreto", {...cred, codigo, pin: PIN});
  ok("verAmigoSecreto con el PIN correcto", typeof amigo.nombreAmigo === "string");
  ok("devuelve tu propio nombre", amigo.nombre === "Yo mismo");

  await debeFallar("tras el sorteo NO se puede sacar a nadie", "grupo_ya_sorteado",
      () => llamar("borrarParticipante", {...cred, codigo, participanteId: id}));

  const cambio = await llamar("cambiarPin", {nickname: NICK, password: PASSWORD, pinNuevo: PIN_NUEVO});
  await debeFallar("el PIN viejo ya no vale", "pin_incorrecto",
      () => llamar("verAmigoSecreto", {...cred, codigo, pin: PIN}));
  ok("cambiarPin", cambio.ok === true);

  // --- El bloqueo por intentos fallidos y su salida de emergencia -------
  //
  // Es la única parte del rediseño cuyo fallo es irreversible: si el bloqueo
  // se pusiera y no se levantara, esa cuenta se quedaría sin ver su amigo
  // secreto para siempre. Se ejerce entera, hasta el rescate.
  //
  // El bucle no cuenta intentos exactos a propósito: el fallo de arriba ("el
  // PIN viejo ya no vale") ya gastó uno, y el intento que PROVOCA el bloqueo
  // todavía responde `pin_incorrecto` —el contador se mira antes de comparar,
  // así que el bloqueo no se ve hasta la llamada siguiente—. Se falla hasta
  // que el servidor lo dice, con un tope para no colgarse si nunca lo dice.
  let claveDelBloqueo = "";
  for (let i = 0; i <= MAX_INTENTOS_PIN + 1 && claveDelBloqueo !== "pin_bloqueado"; i++) {
    try {
      await llamar("verAmigoSecreto", {...cred, codigo, pin: "0000"});
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
      () => llamar("verAmigoSecreto", {...cred, codigo, pin: PIN_NUEVO}));

  const rescate = await llamar("cambiarPin",
      {nickname: NICK, password: PASSWORD, pinNuevo: PIN_RESCATE});
  ok("cambiarPin funciona estando bloqueado", rescate.ok === true);

  // LA PRUEBA QUE IMPORTA: cambiar el PIN con la contraseña de la cuenta
  // levanta el bloqueo en el acto, sin esperar los quince minutos. Sin esto,
  // quien se bloquea se queda fuera y la "salida de emergencia" del diseño
  // sería una promesa sin respaldo.
  const rescatado = await llamar("verAmigoSecreto", {...cred, codigo, pin: PIN_RESCATE});
  ok("el PIN nuevo levanta el bloqueo y entra",
      typeof rescatado.nombreAmigo === "string");

  await llamar("eliminarGrupo", {...cred, codigo});
  const final = await llamar("iniciarSesionCuenta", cred);
  ok("al eliminar el grupo desaparece de Mis grupos",
      final.grupos.every((g) => g.codigo !== codigo));

  console.log(fallos === 0 ? "\nTodo en verde." : `\n${fallos} fallo(s).`);
  process.exit(fallos === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error("Reventó:", e.message, e.clave || "");
  process.exit(1);
});
