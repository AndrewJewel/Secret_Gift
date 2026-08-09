// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class TextosEn extends Textos {
  TextosEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Secret Gift';

  @override
  String get cancelar => 'Cancel';

  @override
  String get guardar => 'Save';

  @override
  String get cerrar => 'Close';

  @override
  String get confirmar => 'Confirm';

  @override
  String get continuar => 'Continue';

  @override
  String get entrar => 'Enter';

  @override
  String get salir => 'Back';

  @override
  String get unMomento => 'One moment...';

  @override
  String get idioma => 'Language';

  @override
  String get idiomaIngles => 'English';

  @override
  String get idiomaEspanol => 'Español';

  @override
  String errorInesperado(String detalle) {
    return 'Unexpected error: $detalle';
  }

  @override
  String get errorSinConexion => 'Could not connect. Check your internet.';

  @override
  String get errorPinIncorrecto => 'Wrong PIN.';

  @override
  String get errorGrupoNoExiste => 'This group no longer exists.';

  @override
  String get errorParticipanteNoExiste =>
      'That person is no longer in the group.';

  @override
  String get errorFaltanDatos => 'Some required information is missing.';

  @override
  String get errorFaltanDatosGrupo =>
      'The occasion, group name or master PIN is missing.';

  @override
  String get errorFaltanDatosParticipante => 'The name or the PIN is missing.';

  @override
  String get errorNicknameLargo =>
      'The nickname must be between 3 and 24 characters.';

  @override
  String get errorNicknameEnUso => 'That nickname is taken. Pick another one.';

  @override
  String get errorNicknameNoExiste => 'That nickname does not exist.';

  @override
  String get errorPasswordIncorrecta => 'Wrong password.';

  @override
  String get errorPasswordDebil =>
      'The password needs at least 8 characters, one uppercase, one lowercase, one number and one special character.';

  @override
  String get errorMinimoDosPersonas =>
      'You need at least 2 people to draw names.';

  @override
  String get errorNadaQueCambiar => 'Nothing to change.';

  @override
  String get errorNombreVacio => 'The group name cannot be empty.';

  @override
  String get errorReglasMuyLargas =>
      'The rules cannot be longer than 2000 characters.';

  @override
  String get errorImagenInvalida => 'The image arrived empty or damaged.';

  @override
  String get errorImagenMuyGrande => 'The image is too large.';

  @override
  String get errorCodigoNoGenerado =>
      'Could not create the group, please try again.';

  @override
  String get inicioSubtitulo => 'Group Manager';

  @override
  String inicioContinuarEn(String grupo) {
    return 'Continue in \"$grupo\"';
  }

  @override
  String get inicioUltimoGrupoNota =>
      '(your last group\'s code, saved on this device)';

  @override
  String get inicioCrearGrupo => 'Create a new group';

  @override
  String get inicioUnirse => 'Join with a code';

  @override
  String get inicioMiCuenta => 'My account (find my groups from any device)';

  @override
  String get crearTitulo => 'Create group';

  @override
  String get crearOcasion => 'Occasion';

  @override
  String get crearNombreGrupo => 'Group name';

  @override
  String get crearNombreGrupoPista => 'e.g. The Smiths, Office 2026';

  @override
  String get crearPinMaestro => 'Group master PIN';

  @override
  String get crearPinMaestroAyuda =>
      'You will need it to draw names and to edit the group. You choose it.';

  @override
  String get crearValorMinimo => 'Minimum gift value (optional)';

  @override
  String get crearValorMinimoPista => 'e.g. \$50';

  @override
  String get crearFaltanDatos => 'The group name or the master PIN is missing';

  @override
  String get crearBoton => 'Create group';

  @override
  String get crearCreando => 'Creating...';

  @override
  String get crearListoTitulo => 'Group created!';

  @override
  String get crearListoTexto => 'Share this code so your group can join:';

  @override
  String get unirseTitulo => 'Join a group';

  @override
  String get unirseCodigo => 'Group code';

  @override
  String get unirseCodigoPista => 'e.g. BLUE-7F3K';

  @override
  String get unirseBoton => 'Join';

  @override
  String get unirseBuscando => 'Searching...';

  @override
  String get unirseNoExiste => 'That code does not exist. Check it.';

  @override
  String get cuentaCrearTitulo => 'Create account';

  @override
  String get cuentaEntrarTitulo => 'Sign in';

  @override
  String get cuentaNickname => 'Nickname';

  @override
  String get cuentaPassword => 'Password';

  @override
  String get cuentaPasswordAyuda =>
      'At least 8 characters: uppercase, lowercase, number and special character';

  @override
  String get cuentaConfirmar => 'Confirm password';

  @override
  String get cuentaFaltanDatos => 'The nickname or the password is missing';

  @override
  String get cuentaNoCoinciden => 'The passwords do not match';

  @override
  String get cuentaCambiarAEntrar => 'Already have an account? Sign in';

  @override
  String get cuentaCambiarACrear => 'No account yet? Create one';

  @override
  String get cuentaFraseGancho =>
      'Create your account to discover who sends you the secret gifts';

  @override
  String cuentaInvitadoA(String grupo) {
    return 'You\'ve been invited to “$grupo”';
  }

  @override
  String get cuentaYaTengoCuenta => 'Already have an account? Sign in';

  @override
  String get cuentaNoTengoCuenta => 'No account yet? Create one';

  @override
  String misGruposSaludo(String nickname) {
    return 'Hi, $nickname';
  }

  @override
  String get misGruposVacio =>
      'You have no groups linked to this account yet.\nCreate or join one and it will show up here.';

  @override
  String get misGruposOrganizador => 'Organizer';

  @override
  String get misGruposParticipante => 'Member';

  @override
  String get misGruposCerrarSesion => 'Sign out';

  @override
  String get misGruposCrear => 'Create a new group';

  @override
  String get misGruposUnirse => 'Join with a code';

  @override
  String grupoCodigo(String codigo) {
    return 'Code: $codigo';
  }

  @override
  String grupoMinimo(String valor) {
    return 'Minimum: $valor';
  }

  @override
  String get grupoCompartir => 'Share invitation';

  @override
  String get grupoQR => 'QR code';

  @override
  String get grupoQRTitulo => 'Scan to join';

  @override
  String grupoCompartirTexto(
    Object grupo,
    Object emoji,
    Object codigo,
    Object url,
  ) {
    return 'Join \"$grupo\" $emoji\nCode: $codigo\n$url';
  }

  @override
  String get grupoReglas => 'Game rules';

  @override
  String get grupoEliminadoAviso => 'This group was deleted by its organizer.';

  @override
  String get registroTituloNormal => 'New member';

  @override
  String get registroTituloPersonaje => 'Join with your character';

  @override
  String get registroDeseos => 'Wish list';

  @override
  String get registroDeseosAyudaNormal =>
      'Only the person giving you a gift will see it.';

  @override
  String get registroDeseosAyudaPersonaje =>
      'Nobody knows who you are, so this is the only clue your gift giver will have.';

  @override
  String get registroPin => 'Secret PIN';

  @override
  String get registroPinAyuda =>
      'With this PIN you will see who you have to give a gift to.';

  @override
  String get registroBoton => 'ADD TO THE LIST';

  @override
  String get registroFaltaNombre => 'The name or the PIN is missing';

  @override
  String get registroFaltaPersonaje => 'The character or the PIN is missing';

  @override
  String get registroVacioNormal => 'No members yet.';

  @override
  String get registroVacioPersonaje => 'No characters yet.';

  @override
  String get registroYaTieneAmigo => 'Already has their secret friend';

  @override
  String get registroSalirGrupo => 'Leave the group (with your PIN)';

  @override
  String get registroTuPin => 'Your secret PIN';

  @override
  String get registroVerAmigo => 'SEE MY SECRET FRIEND';

  @override
  String get organizadorEntrar => 'Organizer mode';

  @override
  String get organizadorSalir => 'Exit organizer mode';

  @override
  String get organizadorPinTexto =>
      'Type the master PIN you chose when you created the group. It is asked only once.';

  @override
  String get organizadorPinCampo => 'Master PIN';

  @override
  String get organizadorActivado => 'Organizer mode on';

  @override
  String get organizadorDesactivado => 'Organizer mode off';

  @override
  String get organizadorEditarGrupo => 'Edit the group';

  @override
  String get organizadorCorregirNombre => 'Fix the name';

  @override
  String get organizadorCorregirPersonaje => 'Fix the character';

  @override
  String get organizadorSacar => 'Remove from the group';

  @override
  String organizadorSacarPregunta(String nombre) {
    return 'Remove $nombre from the group?';
  }

  @override
  String get organizadorSacarTexto =>
      'They will be deleted along with their wish list and their assignment.';

  @override
  String get organizadorSacarBoton => 'Remove';

  @override
  String get sorteoBoton => 'DRAW NAMES';

  @override
  String get sorteoTitulo => 'Draw names';

  @override
  String get sorteoTexto =>
      'Each member gets their secret friend. Drawing again replaces the previous assignments.';

  @override
  String get sorteoConfirmar => 'Draw';

  @override
  String get sorteoListo => 'Names drawn!';

  @override
  String get editarTitulo => 'Edit group';

  @override
  String get editarReglas => 'Game rules';

  @override
  String get editarReglasAyuda =>
      'The whole group sees them on the main screen.';

  @override
  String get editarGuardar => 'Save changes';

  @override
  String get editarGuardando => 'Saving...';

  @override
  String get editarGuardado => 'Changes saved';

  @override
  String get editarZonaPeligro => 'Point of no return';

  @override
  String get editarZonaPeligroTexto =>
      'Deleting the group removes every member and all their data. There is no way to get it back.';

  @override
  String get editarEliminarBoton => 'Delete this group';

  @override
  String get editarEliminarTitulo => 'Delete the group';

  @override
  String editarEliminarTexto(String grupo) {
    return '\"$grupo\" will be deleted with all its members, their wish lists and the draw if it already happened.\n\nThis cannot be undone.';
  }

  @override
  String get editarEliminarConfirmar => 'Yes, delete it';

  @override
  String get editarEliminado => 'Group deleted';

  @override
  String get loginTitulo => 'Who are you?';

  @override
  String loginHola(String nombre) {
    return 'Hi $nombre';
  }

  @override
  String get secretaTitulo => 'Your secret friend is...';

  @override
  String get secretaSinSorteo => 'The draw has not happened yet';

  @override
  String get secretaRevelar => 'REVEAL';

  @override
  String secretaDesea(String deseos) {
    return 'Wishes: $deseos';
  }

  @override
  String get secretaSinSugerencias => 'No suggestions';

  @override
  String get ocasionAmigoSecreto => 'Secret Friend';

  @override
  String get ocasionSantaSecreto => 'Secret Santa';

  @override
  String get avatarCambiar => 'Change image';

  @override
  String get avatarQuitar => 'Remove image';

  @override
  String avatarNoGaleria(String detalle) {
    return 'Could not open the gallery: $detalle';
  }

  @override
  String get tematica => 'Theme';

  @override
  String get tematicaAyuda =>
      'With a theme, nobody uses their real name: everyone signs up as the character they pick.';

  @override
  String get tematicaNombreNinguna => 'No theme';

  @override
  String get tematicaNombreCaricaturas => 'Cartoons';

  @override
  String get tematicaNombreAlfombraRoja => 'Red carpet';

  @override
  String get tematicaNombreNavidad => 'Christmas';

  @override
  String get tematicaDescNinguna => 'Everyone with their own name and photo';

  @override
  String get tematicaDescCaricaturas =>
      'Everyone picks their cartoon character';

  @override
  String get tematicaDescAlfombraRoja => 'Everyone picks a famous star';

  @override
  String get tematicaDescNavidad => 'Everyone picks a Christmas character';

  @override
  String get tematicaNombreCampoNormal => 'Your name';

  @override
  String get tematicaNombreCampoPersonaje => 'Your character\'s name';

  @override
  String get tematicaImagenNormal => 'Your photo';

  @override
  String get tematicaImagenPersonaje => 'Your character\'s image';

  @override
  String get tematicaPistaNinguna => 'e.g. Andrew Chaves';

  @override
  String get tematicaPistaCaricaturas => 'e.g. The Lucky Rabbit';

  @override
  String get tematicaPistaAlfombraRoja => 'e.g. The Movie Diva';

  @override
  String get tematicaPistaNavidad => 'e.g. The Naughty Elf';

  @override
  String grupoYaDentro(String nombre) {
    return 'You are in this group as $nombre';
  }

  @override
  String get grupoYaDentroAyuda =>
      'Your entry is saved. Nobody has to sign up twice.';

  @override
  String get grupoYaEstoyDentro => 'I already signed up on another device';

  @override
  String get grupoNoEresTu => 'Not you?';

  @override
  String get grupoTuEtiqueta => 'you';

  @override
  String get chatTitulo => 'Anonymous chat';

  @override
  String get chatAbrir => 'GROUP CHAT';

  @override
  String get chatVacio =>
      'No messages yet.\nBe the first to write — nobody will know it was you.';

  @override
  String get chatEscribe => 'Write a message...';

  @override
  String get chatEnviar => 'Send';

  @override
  String get chatQuienEres => 'Who are you?';

  @override
  String get chatQuienEresTexto =>
      'Pick your name and type your PIN. It is asked only once on this device.';

  @override
  String chatTuMascara(String mascara) {
    return 'In the chat you are $mascara. Nobody can see who is behind it — not even the organizer.';
  }

  @override
  String get chatTu => 'you';

  @override
  String get chatBorrarMensaje => 'Delete message';

  @override
  String get chatBorrarPregunta => 'Delete this message?';

  @override
  String get chatBorrarTexto =>
      'It disappears for the whole group. You will not find out who wrote it.';

  @override
  String get chatCambiarPersona => 'I am someone else';

  @override
  String get errorMensajeVacio => 'The message is empty.';

  @override
  String get errorMensajeLargo => 'The message is too long.';

  @override
  String get errorMuyRapido => 'Wait a moment before writing again.';

  @override
  String get errorSesionInvalida =>
      'Your account session is no longer valid. Please sign in again.';

  @override
  String get mascaraZorro => 'Fox';

  @override
  String get mascaraBuho => 'Owl';

  @override
  String get mascaraOso => 'Bear';

  @override
  String get mascaraGato => 'Cat';

  @override
  String get mascaraLobo => 'Wolf';

  @override
  String get mascaraConejo => 'Rabbit';

  @override
  String get mascaraCiervo => 'Deer';

  @override
  String get mascaraPanda => 'Panda';

  @override
  String get mascaraTigre => 'Tiger';

  @override
  String get mascaraPinguino => 'Penguin';

  @override
  String get mascaraDelfin => 'Dolphin';

  @override
  String get mascaraAguila => 'Eagle';

  @override
  String get mascaraRana => 'Frog';

  @override
  String get mascaraErizo => 'Hedgehog';

  @override
  String get mascaraKoala => 'Koala';

  @override
  String get mascaraNutria => 'Otter';

  @override
  String get reglasNinguna =>
      'A surprise gift for your secret friend.\n\n• Don\'t tell anyone who you got.\n• Write your wish list so whoever gives you a gift has a clue.';

  @override
  String get reglasCaricaturas =>
      'Cartoon group! Nobody uses their real name.\n\n• Pick the cartoon character you like most and upload their image.\n• Nobody knows who is behind each character until the gift exchange.\n• Write your wish list: it is the only clue your gift giver will have.';

  @override
  String get reglasAlfombraRoja =>
      'Gala night! We are all stars this time.\n\n• Pick the celebrity you want to be and upload their photo.\n• Nobody knows which star is who until the gift exchange.\n• Write your wish list: it is the only clue your gift giver will have.';

  @override
  String get reglasNavidad =>
      'Christmas in the group! Nobody uses their real name.\n\n• Pick your Christmas character and upload their image.\n• Nobody knows who is who until the gift exchange.\n• Write your wish list: it is the only clue your gift giver will have.';
}
