// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class TextosEs extends Textos {
  TextosEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Regalo Secreto';

  @override
  String get cancelar => 'Cancelar';

  @override
  String get guardar => 'Guardar';

  @override
  String get cerrar => 'Cerrar';

  @override
  String get confirmar => 'Confirmar';

  @override
  String get continuar => 'Continuar';

  @override
  String get entrar => 'Entrar';

  @override
  String get salir => 'Volver';

  @override
  String get reintentar => 'Reintentar';

  @override
  String get idioma => 'Idioma';

  @override
  String get idiomaIngles => 'English';

  @override
  String get idiomaEspanol => 'Español';

  @override
  String get configuracion => 'Configuración';

  @override
  String get configuracionCambiarPin => 'Cambiar mi PIN';

  @override
  String get cambiarPinTitulo => 'Cambiar mi PIN';

  @override
  String get cambiarPinTexto =>
      'Se te pide la contraseña de la cuenta porque es la única salida si olvidas el PIN.';

  @override
  String get cambiarPinPassword => 'Contraseña de la cuenta';

  @override
  String get cambiarPinNuevo => 'PIN nuevo de 4 dígitos';

  @override
  String get cambiarPinGuardar => 'Guardar el PIN nuevo';

  @override
  String get cambiarPinGuardado => 'PIN cambiado';

  @override
  String errorInesperado(String detalle) {
    return 'Error inesperado: $detalle';
  }

  @override
  String get errorSinConexion => 'No se pudo conectar. Revisa tu internet.';

  @override
  String get errorPinIncorrecto => 'PIN incorrecto.';

  @override
  String get errorGrupoNoExiste => 'Ese grupo ya no existe.';

  @override
  String get errorParticipanteNoExiste => 'Esa persona ya no está en el grupo.';

  @override
  String get errorFaltanDatos => 'Falta información obligatoria.';

  @override
  String get errorFaltanDatosGrupo => 'Falta la ocasión o el nombre del grupo.';

  @override
  String get errorFaltanDatosParticipante => 'Falta el grupo o el nombre.';

  @override
  String get errorPasswordIncorrecta => 'Contraseña incorrecta.';

  @override
  String get errorPasswordDebil =>
      'La contraseña necesita mínimo 8 caracteres, una mayúscula, una minúscula, un número y un carácter especial.';

  @override
  String get errorMinimoDosPersonas =>
      'Se necesitan mínimo 2 personas para sortear.';

  @override
  String get errorNadaQueCambiar => 'No hay nada que cambiar.';

  @override
  String get errorNombreVacio => 'El nombre del grupo no puede quedar vacío.';

  @override
  String get errorReglasMuyLargas =>
      'Las reglas no pueden pasar de 2000 caracteres.';

  @override
  String get errorImagenInvalida => 'La imagen llegó vacía o dañada.';

  @override
  String get errorImagenMuyGrande => 'La imagen pesa demasiado.';

  @override
  String get errorCodigoNoGenerado =>
      'No se pudo crear el grupo, intenta de nuevo.';

  @override
  String get errorPinFormato => 'El PIN tiene que ser de 4 dígitos exactos';

  @override
  String get errorNoEresOrganizador =>
      'Solo el organizador del grupo puede hacer esto';

  @override
  String get errorNoEstasEnElGrupo => 'Todavía no estás inscrito en este grupo';

  @override
  String get errorYaEstasEnElGrupo => 'Ya tienes una plaza en este grupo';

  @override
  String get errorGrupoYaSorteado =>
      'El sorteo ya se hizo. A esta persona no se la puede sacar: hay que reemplazarla para que la cadena siga entera.';

  @override
  String get errorGrupoCerrado =>
      'El sorteo ya se hizo, así que este grupo está cerrado a gente nueva. Pídele al organizador que te dé el sitio de alguien.';

  @override
  String get errorSorteoYaHecho =>
      'Este grupo ya sorteó. El sorteo no se puede repetir.';

  @override
  String get errorPinBloqueado =>
      'Demasiados PIN incorrectos. Espera unos minutos, o cambia tu PIN desde Configuración.';

  @override
  String get errorCorreoSinVerificar => 'Verifica tu correo para continuar.';

  @override
  String get errorRequiereReautenticacion =>
      'Por seguridad, confirma otra vez tu contraseña.';

  @override
  String get errorPerfilIncompleto =>
      'Tu cuenta todavía no tiene perfil. Vuelve a entrar para terminarlo.';

  @override
  String get errorCorreoInvalido =>
      'Esa dirección de correo no parece correcta.';

  @override
  String get errorCorreoEnUso =>
      'Ese correo ya tiene cuenta. Entra en vez de crear una.';

  @override
  String get errorDemasiadosIntentos =>
      'Demasiados intentos. Espera unos minutos y vuelve a probar.';

  @override
  String get errorCuentaDeshabilitada => 'Esta cuenta ha sido deshabilitada.';

  @override
  String errorAuthDesconocido(String codigo, String mensaje) {
    return 'Algo salió mal al entrar. Vuelve a intentarlo. (código: $codigo — $mensaje)';
  }

  @override
  String get errorDominioNoAutorizado =>
      'Esta app no está bien configurada para este sitio. Avisa a quien la administra.';

  @override
  String get errorNombreLargo =>
      'El nombre y el apellido no pueden pasar de 40 caracteres cada uno.';

  @override
  String get errorReemplazoInvalido =>
      'Este enlace ya no vale. Pídele otro al organizador.';

  @override
  String get errorGrupoSinSortear =>
      'Este grupo todavía no ha sorteado. Saca a esta persona y que se apunte otra.';

  @override
  String get crearTitulo => 'Crear grupo';

  @override
  String get crearOcasion => 'Ocasión';

  @override
  String get crearNombreGrupo => 'Nombre del grupo';

  @override
  String get crearNombreGrupoPista => 'Ej: Familia Pérez, Oficina 2026';

  @override
  String get crearValorMinimo => 'Valor mínimo del regalo (opcional)';

  @override
  String get crearValorMinimoPista => 'Ej: \$50.000 COP';

  @override
  String get crearFaltanDatos => 'Falta el nombre del grupo';

  @override
  String get crearBoton => 'Crear grupo';

  @override
  String get crearCreando => 'Creando...';

  @override
  String get crearListoTitulo => '¡Grupo creado!';

  @override
  String get crearListoTexto =>
      'Comparte este código con tu grupo para que se unan:';

  @override
  String get unirseTitulo => 'Unirme a un grupo';

  @override
  String get unirseCodigo => 'Código del grupo';

  @override
  String get unirseCodigoPista => 'Ej: AZUL-7F3K';

  @override
  String get unirseBoton => 'Unirme';

  @override
  String get unirseBuscando => 'Buscando...';

  @override
  String get unirseNoExiste => 'Ese código no existe. Revísalo.';

  @override
  String get cuentaCrearTitulo => 'Crear cuenta';

  @override
  String get cuentaEntrarTitulo => 'Iniciar sesión';

  @override
  String get cuentaCorreo => 'Correo';

  @override
  String get cuentaNombre => 'Nombre';

  @override
  String get cuentaApellido => 'Apellido';

  @override
  String get cuentaPassword => 'Contraseña';

  @override
  String get cuentaPasswordAyuda =>
      'Mínimo 8 caracteres: mayúscula, minúscula, número y carácter especial';

  @override
  String get cuentaConfirmar => 'Confirmar contraseña';

  @override
  String get cuentaFaltanDatos => 'Falta información obligatoria';

  @override
  String get cuentaNoCoinciden => 'Las contraseñas no coinciden';

  @override
  String get cuentaFraseGancho =>
      'Crea tu cuenta para descubrir quién te envía los regalos secretos';

  @override
  String cuentaInvitadoA(String grupo) {
    return 'Te han invitado a «$grupo»';
  }

  @override
  String get cuentaYaTengoCuenta => '¿Ya tienes cuenta? Entra';

  @override
  String get cuentaNoTengoCuenta => '¿Aún no tienes cuenta? Crea una';

  @override
  String get cuentaPin => 'PIN de 4 dígitos';

  @override
  String get cuentaPinAyuda =>
      'Lo escribirás para ver tu amigo secreto, en todos tus grupos. Solo tú lo sabes.';

  @override
  String get cuentaPinConfirmar => 'Confirma el PIN';

  @override
  String get cuentaPinNoCoinciden => 'Los PIN no coinciden';

  @override
  String get recuperarEnlace => 'He olvidado mi contraseña';

  @override
  String get recuperarTitulo => 'Recupera tu contraseña';

  @override
  String get recuperarTexto =>
      'Escribe el correo con el que te registraste y te mandamos un enlace para poner una contraseña nueva.';

  @override
  String get recuperarBoton => 'Mándame el enlace';

  @override
  String get recuperarEnviado =>
      'Si esa dirección tiene cuenta, le hemos mandado un enlace.';

  @override
  String get verificarTitulo => 'Mira tu bandeja de entrada';

  @override
  String get verificarTexto =>
      'Te hemos mandado un enlace. Pínchalo para confirmar tu correo y vuelve aquí.';

  @override
  String get verificarComprobar => 'Ya lo confirmé';

  @override
  String get verificarComprobando => 'Comprobando…';

  @override
  String get verificarReenviar => 'Mandarlo otra vez';

  @override
  String get verificarReenviando => 'Mandando…';

  @override
  String get verificarReenviado => 'Enlace mandado';

  @override
  String get verificarTodaviaNo =>
      'Todavía no está confirmado. Mira tu bandeja, puede estar en el correo no deseado.';

  @override
  String get completarPerfilTitulo => 'Un último paso';

  @override
  String get completarPerfilTexto =>
      'Tu cuenta se creó pero tu perfil no se guardó. Rellénalo para continuar.';

  @override
  String misGruposSaludo(String nickname) {
    return 'Hola, $nickname';
  }

  @override
  String get misGruposVacio =>
      'Todavía no tienes grupos vinculados a esta cuenta.\nCrea o únete a uno y quedará guardado aquí.';

  @override
  String get misGruposOrganizador => 'Organizador';

  @override
  String get misGruposParticipante => 'Participante';

  @override
  String get misGruposCerrarSesion => 'Cerrar sesión';

  @override
  String get misGruposCrear => 'Crear un grupo nuevo';

  @override
  String get misGruposUnirse => 'Unirme con un código';

  @override
  String grupoCodigo(String codigo) {
    return 'Código: $codigo';
  }

  @override
  String grupoMinimo(String valor) {
    return 'Mínimo: $valor';
  }

  @override
  String get grupoCompartir => 'Compartir invitación';

  @override
  String get grupoQR => 'Código QR';

  @override
  String get grupoQRTitulo => 'Escanea para unirte';

  @override
  String grupoCompartirTexto(
    Object grupo,
    Object emoji,
    Object codigo,
    Object url,
  ) {
    return 'Únete a «$grupo» $emoji\nCódigo: $codigo\n$url';
  }

  @override
  String get grupoReglas => 'Reglas del juego';

  @override
  String get grupoEliminadoAviso =>
      'Este grupo fue eliminado por su organizador.';

  @override
  String get registroTituloNormal => 'Nuevo participante';

  @override
  String get registroTituloPersonaje => 'Únete con tu personaje';

  @override
  String get registroDeseos => 'Lista de deseos';

  @override
  String get registroDeseosAyudaNormal => 'Solo la verá quien te regale.';

  @override
  String get registroDeseosAyudaPersonaje =>
      'Nadie sabe quién eres, así que esta es la única pista que tendrá quien te regale.';

  @override
  String get registroBoton => 'AGREGAR A LA LISTA';

  @override
  String get registroFaltaNombre => 'Falta el nombre';

  @override
  String get registroFaltaPersonaje => 'Falta el personaje';

  @override
  String get registroVacioNormal => 'Todavía no hay participantes.';

  @override
  String get registroVacioPersonaje => 'Todavía no hay personajes.';

  @override
  String get registroYaTieneAmigo => 'Ya tiene su amigo secreto';

  @override
  String get registroSalirGrupo => 'Salir del grupo';

  @override
  String get registroVerAmigo => 'VER MI AMIGO SECRETO';

  @override
  String get organizadorEditarGrupo => 'Editar el grupo';

  @override
  String get organizadorCorregirNombre => 'Corregir el nombre';

  @override
  String get organizadorCorregirPersonaje => 'Corregir el personaje';

  @override
  String get organizadorSacar => 'Sacar del grupo';

  @override
  String organizadorSacarPregunta(String nombre) {
    return '¿Sacar a $nombre del grupo?';
  }

  @override
  String get organizadorSacarTexto =>
      'Se borra con su lista de deseos y su asignación.';

  @override
  String get organizadorSacarBoton => 'Sacar';

  @override
  String get reemplazarTooltip => 'Reemplazar a esta persona';

  @override
  String reemplazarTitulo(String nombre) {
    return 'Reemplazar a $nombre';
  }

  @override
  String reemplazarAviso(String nombre) {
    return 'La plaza de $nombre pasará a otra persona, que seguirá regalando a quien le tocaba.\n\n· Quien le regala a $nombre NO cambia, pero verá otro nombre y otros deseos.\n· $nombre perderá el acceso al grupo.\n· Lo que $nombre escribió en el chat se queda, con su máscara.';
  }

  @override
  String get reemplazarGenerar => 'Generar enlace';

  @override
  String reemplazarCompartir(String nombre, String enlace) {
    return 'Vas a ocupar el lugar de $nombre en nuestro amigo secreto. Abre este enlace: $enlace';
  }

  @override
  String get sorteoBoton => 'HACER EL SORTEO';

  @override
  String get sorteoTitulo => 'Hacer el sorteo';

  @override
  String get sorteoTexto =>
      'Se le asigna a cada participante su amigo secreto. Volver a sortear reemplaza las asignaciones anteriores.';

  @override
  String get sorteoConfirmar => 'Sortear';

  @override
  String get sorteoListo => '¡Sorteo realizado!';

  @override
  String get editarTitulo => 'Editar grupo';

  @override
  String get editarReglas => 'Reglas del juego';

  @override
  String get editarReglasAyuda =>
      'Las ve todo el grupo en la pantalla principal.';

  @override
  String get editarGuardar => 'Guardar cambios';

  @override
  String get editarGuardando => 'Guardando...';

  @override
  String get editarGuardado => 'Cambios guardados';

  @override
  String get editarZonaPeligro => 'Zona irreversible';

  @override
  String get editarZonaPeligroTexto =>
      'Eliminar el grupo borra a todos sus participantes y sus datos. No hay forma de recuperarlo.';

  @override
  String get editarEliminarBoton => 'Eliminar este grupo';

  @override
  String get editarEliminarTitulo => 'Eliminar el grupo';

  @override
  String editarEliminarTexto(String grupo) {
    return 'Se borra «$grupo» con todos sus participantes, sus listas de deseos y el sorteo si ya se hizo.\n\nEsto no se puede deshacer.';
  }

  @override
  String get editarEliminarConfirmar => 'Sí, eliminar';

  @override
  String editarEliminarEscribeNombre(String grupo) {
    return 'Para eliminarlo, escribe el nombre del grupo exactamente: $grupo';
  }

  @override
  String get editarEliminado => 'Grupo eliminado';

  @override
  String get verAmigoPinTitulo => 'Escribe tu PIN';

  @override
  String get verAmigoPinTexto =>
      'Nadie más debería ver esto. El PIN se pide cada vez.';

  @override
  String get secretaTitulo => 'Tu amigo secreto es...';

  @override
  String get secretaSinSorteo => 'Todavía no se ha hecho el sorteo';

  @override
  String get secretaRevelar => 'REVELAR';

  @override
  String secretaDesea(String deseos) {
    return 'Desea: $deseos';
  }

  @override
  String get secretaSinSugerencias => 'Sin sugerencias';

  @override
  String get ocasionAmigoSecreto => 'Amigo Secreto';

  @override
  String get ocasionSantaSecreto => 'Santa Secreto';

  @override
  String get avatarCambiar => 'Cambiar imagen';

  @override
  String get avatarQuitar => 'Quitar imagen';

  @override
  String avatarNoGaleria(String detalle) {
    return 'No se pudo abrir la galería: $detalle';
  }

  @override
  String get tematica => 'Temática';

  @override
  String get tematicaAyuda =>
      'Con temática, nadie usa su nombre real: cada quien se registra como el personaje que elija.';

  @override
  String get tematicaNombreNinguna => 'Sin temática';

  @override
  String get tematicaNombreCaricaturas => 'Caricaturas';

  @override
  String get tematicaNombreAlfombraRoja => 'Alfombra roja';

  @override
  String get tematicaNombreNavidad => 'Navidad';

  @override
  String get tematicaDescNinguna => 'Cada quien con su nombre y su foto';

  @override
  String get tematicaDescCaricaturas => 'Cada quien elige su personaje animado';

  @override
  String get tematicaDescAlfombraRoja => 'Cada quien elige una estrella famosa';

  @override
  String get tematicaDescNavidad => 'Cada quien elige un personaje navideño';

  @override
  String get tematicaNombreCampoNormal => 'Tu nombre';

  @override
  String get tematicaNombreCampoPersonaje => 'Nombre de tu personaje';

  @override
  String get tematicaImagenNormal => 'Tu foto';

  @override
  String get tematicaImagenPersonaje => 'Imagen de tu personaje';

  @override
  String get tematicaPistaNinguna => 'Ej: Andrés Chaves';

  @override
  String get tematicaPistaCaricaturas => 'Ej: El Conejo de la Suerte';

  @override
  String get tematicaPistaAlfombraRoja => 'Ej: La Diva del Cine';

  @override
  String get tematicaPistaNavidad => 'Ej: El Duende Travieso';

  @override
  String grupoYaDentro(String nombre) {
    return 'Ya estás en este grupo como $nombre';
  }

  @override
  String get grupoYaDentroAyuda =>
      'Tu entrada quedó guardada. Nadie tiene que registrarse dos veces.';

  @override
  String get grupoTuEtiqueta => 'tú';

  @override
  String get chatTitulo => 'Chat anónimo';

  @override
  String get chatAbrir => 'CHAT DEL GRUPO';

  @override
  String get chatVacio =>
      'Todavía no hay mensajes.\nEscribe el primero — nadie va a saber que fuiste tú.';

  @override
  String get chatEscribe => 'Escribe un mensaje...';

  @override
  String get chatEnviar => 'Enviar';

  @override
  String chatTuMascara(String mascara) {
    return 'En el chat eres $mascara. Nadie puede ver quién hay detrás — ni siquiera el organizador.';
  }

  @override
  String get chatTu => 'tú';

  @override
  String get chatBorrarMensaje => 'Borrar mensaje';

  @override
  String get chatBorrarPregunta => '¿Borrar este mensaje?';

  @override
  String get chatBorrarTexto =>
      'Desaparece para todo el grupo. No vas a enterarte de quién lo escribió.';

  @override
  String get errorMensajeVacio => 'El mensaje está vacío.';

  @override
  String get errorMensajeLargo => 'El mensaje es demasiado largo.';

  @override
  String get errorMuyRapido => 'Espera un momento antes de volver a escribir.';

  @override
  String get errorSesionInvalida =>
      'La sesión de tu cuenta ya no es válida. Vuelve a entrar.';

  @override
  String get mascaraZorro => 'Zorro';

  @override
  String get mascaraBuho => 'Búho';

  @override
  String get mascaraOso => 'Oso';

  @override
  String get mascaraGato => 'Gato';

  @override
  String get mascaraLobo => 'Lobo';

  @override
  String get mascaraConejo => 'Conejo';

  @override
  String get mascaraCiervo => 'Ciervo';

  @override
  String get mascaraPanda => 'Panda';

  @override
  String get mascaraTigre => 'Tigre';

  @override
  String get mascaraPinguino => 'Pingüino';

  @override
  String get mascaraDelfin => 'Delfín';

  @override
  String get mascaraAguila => 'Águila';

  @override
  String get mascaraRana => 'Rana';

  @override
  String get mascaraErizo => 'Erizo';

  @override
  String get mascaraKoala => 'Koala';

  @override
  String get mascaraNutria => 'Nutria';

  @override
  String get reglasNinguna =>
      'Regalo sorpresa para tu amigo secreto.\n\n• No le cuentes a nadie quién te tocó.\n• Escribe tu lista de deseos para que quien te regale tenga una pista.';

  @override
  String get reglasCaricaturas =>
      '¡Grupo de caricaturas! Nadie usa su nombre real.\n\n• Elige el personaje animado que más te guste y súbele su imagen.\n• Nadie sabe quién está detrás de cada personaje hasta el día del intercambio.\n• Escribe tu lista de deseos: es la única pista que tendrá quien te regale.';

  @override
  String get reglasAlfombraRoja =>
      '¡Noche de gala! Todos somos estrellas esta vez.\n\n• Elige a la celebridad que quieras ser y súbele su foto.\n• Nadie sabe qué estrella es cada quien hasta el día del intercambio.\n• Escribe tu lista de deseos: es la única pista que tendrá quien te regale.';

  @override
  String get reglasNavidad =>
      '¡Navidad en el grupo! Nadie usa su nombre real.\n\n• Elige tu personaje navideño y súbele su imagen.\n• Nadie sabe quién es quién hasta el día del intercambio.\n• Escribe tu lista de deseos: es la única pista que tendrá quien te regale.';
}
