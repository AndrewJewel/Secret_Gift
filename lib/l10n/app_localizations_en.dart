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
  String get reintentar => 'Try again';

  @override
  String get idioma => 'Language';

  @override
  String get idiomaIngles => 'English';

  @override
  String get idiomaEspanol => 'Español';

  @override
  String get configuracion => 'Settings';

  @override
  String get configuracionCambiarPin => 'Change my PIN';

  @override
  String get cambiarPinTitulo => 'Change my PIN';

  @override
  String get cambiarPinTexto =>
      'Your account password is asked because it is the only way back if you forget the PIN.';

  @override
  String get cambiarPinPassword => 'Account password';

  @override
  String get cambiarPinNuevo => 'New 4-digit PIN';

  @override
  String get cambiarPinGuardar => 'Save the new PIN';

  @override
  String get cambiarPinGuardado => 'PIN changed';

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
      'The occasion or the group name is missing.';

  @override
  String get errorFaltanDatosParticipante =>
      'The group or the name is missing.';

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
  String get errorPinFormato => 'The PIN must be exactly 4 digits';

  @override
  String get errorNoEresOrganizador => 'Only the group organizer can do this';

  @override
  String get errorNoEstasEnElGrupo => 'You are not signed up in this group yet';

  @override
  String get errorYaEstasEnElGrupo => 'You already have a spot in this group';

  @override
  String get errorGrupoYaSorteado =>
      'The draw already happened. This person cannot be removed — they have to be replaced so the chain stays intact.';

  @override
  String get errorGrupoCerrado =>
      'The draw already happened, so this group is closed to new people. Ask the organiser to take someone\'s place instead.';

  @override
  String get errorSorteoYaHecho =>
      'This group has already drawn. The draw can\'t be run twice.';

  @override
  String get errorPinBloqueado =>
      'Too many wrong PINs. Wait a few minutes, or change your PIN from Settings.';

  @override
  String get errorCorreoSinVerificar => 'Verify your email to continue.';

  @override
  String get errorRequiereReautenticacion =>
      'For security, confirm your password again.';

  @override
  String get errorPerfilIncompleto =>
      'Your account has no profile yet. Sign in again to finish it.';

  @override
  String get errorCorreoInvalido => 'That email address doesn\'t look right.';

  @override
  String get errorCorreoEnUso =>
      'That email already has an account. Sign in instead.';

  @override
  String get errorDemasiadosIntentos =>
      'Too many attempts. Wait a few minutes and try again.';

  @override
  String get errorCuentaDeshabilitada => 'This account has been disabled.';

  @override
  String errorAuthDesconocido(String codigo, String mensaje) {
    return 'Something went wrong signing you in. Try again. (code: $codigo — $mensaje)';
  }

  @override
  String get errorDominioNoAutorizado =>
      'This app isn\'t set up correctly for this website. Let whoever manages it know.';

  @override
  String get errorNombreLargo =>
      'Your name and surname can\'t be longer than 40 characters each.';

  @override
  String get errorReemplazoInvalido =>
      'This link is no longer valid. Ask the organiser for a new one.';

  @override
  String get errorGrupoSinSortear =>
      'This group hasn\'t drawn yet. Remove this person and let someone else sign up.';

  @override
  String get crearTitulo => 'Create group';

  @override
  String get crearOcasion => 'Occasion';

  @override
  String get crearNombreGrupo => 'Group name';

  @override
  String get crearNombreGrupoPista => 'e.g. The Smiths, Office 2026';

  @override
  String get crearValorMinimo => 'Minimum gift value (optional)';

  @override
  String get crearValorMinimoPista => 'e.g. \$50';

  @override
  String get crearFaltanDatos => 'The group name is missing';

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
  String get cuentaCorreo => 'Email';

  @override
  String get cuentaNombre => 'First name';

  @override
  String get cuentaApellido => 'Last name';

  @override
  String get cuentaPassword => 'Password';

  @override
  String get cuentaPasswordAyuda =>
      'At least 8 characters: uppercase, lowercase, number and special character';

  @override
  String get cuentaConfirmar => 'Confirm password';

  @override
  String get cuentaFaltanDatos => 'Some required information is missing';

  @override
  String get cuentaNoCoinciden => 'The passwords do not match';

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
  String get cuentaPin => '4-digit PIN';

  @override
  String get cuentaPinAyuda =>
      'You will type it to reveal your secret friend, in every group. Only you know it.';

  @override
  String get cuentaPinConfirmar => 'Confirm PIN';

  @override
  String get cuentaPinNoCoinciden => 'The PINs do not match';

  @override
  String get recuperarEnlace => 'I forgot my password';

  @override
  String get recuperarTitulo => 'Recover your password';

  @override
  String get recuperarTexto =>
      'Type the email you signed up with and we\'ll send you a link to set a new password.';

  @override
  String get recuperarBoton => 'Send me the link';

  @override
  String get recuperarEnviado =>
      'If that address has an account, we\'ve sent it a link.';

  @override
  String get verificarTitulo => 'Check your inbox';

  @override
  String get verificarTexto =>
      'We sent you a link. Tap it to confirm your email, then come back here.';

  @override
  String get verificarComprobar => 'I\'ve confirmed it';

  @override
  String get verificarComprobando => 'Checking…';

  @override
  String get verificarReenviar => 'Send it again';

  @override
  String get verificarReenviando => 'Sending…';

  @override
  String get verificarReenviado => 'Link sent';

  @override
  String get verificarTodaviaNo =>
      'Not confirmed yet. Check your inbox — it may be in spam.';

  @override
  String get completarPerfilTitulo => 'One last step';

  @override
  String get completarPerfilTexto =>
      'Your account was created but your profile wasn\'t saved. Fill it in to continue.';

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
  String get registroBoton => 'ADD TO THE LIST';

  @override
  String get registroFaltaNombre => 'The name is missing';

  @override
  String get registroFaltaPersonaje => 'The character is missing';

  @override
  String get registroVacioNormal => 'No members yet.';

  @override
  String get registroVacioPersonaje => 'No characters yet.';

  @override
  String get registroYaTieneAmigo => 'Already has their secret friend';

  @override
  String get registroSalirGrupo => 'Leave the group';

  @override
  String get registroVerAmigo => 'SEE MY SECRET FRIEND';

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
  String get reemplazarTooltip => 'Replace this person';

  @override
  String reemplazarTitulo(String nombre) {
    return 'Replace $nombre';
  }

  @override
  String reemplazarAviso(String nombre) {
    return '$nombre\'s place will pass to someone else, who will keep giving to the same person.\n\n· Whoever gives to $nombre won\'t change, but will see a different name and wishes.\n· $nombre will lose access to the group.\n· What $nombre wrote in the chat stays, under their mask.';
  }

  @override
  String get reemplazarGenerar => 'Create link';

  @override
  String reemplazarCompartir(String nombre, String enlace) {
    return 'You\'re taking $nombre\'s place in our Secret Santa. Open this link: $enlace';
  }

  @override
  String reemplazarOcupasPlaza(String nombre) {
    return 'You\'re taking $nombre\'s place. Keep the name or change it to yours.';
  }

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
  String editarEliminarEscribeNombre(String grupo) {
    return 'To delete it, type the group name exactly: $grupo';
  }

  @override
  String get editarEliminado => 'Group deleted';

  @override
  String get verAmigoPinTitulo => 'Type your PIN';

  @override
  String get verAmigoPinTexto =>
      'Nobody else should see this. Your PIN is asked every time.';

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
