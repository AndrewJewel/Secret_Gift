import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of Textos
/// returned by `Textos.of(context)`.
///
/// Applications need to include `Textos.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: Textos.localizationsDelegates,
///   supportedLocales: Textos.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the Textos.supportedLocales
/// property.
abstract class Textos {
  Textos(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static Textos of(BuildContext context) {
    return Localizations.of<Textos>(context, Textos)!;
  }

  static const LocalizationsDelegate<Textos> delegate = _TextosDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Secret Gift'**
  String get appTitle;

  /// No description provided for @cancelar.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelar;

  /// No description provided for @guardar.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get guardar;

  /// No description provided for @cerrar.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get cerrar;

  /// No description provided for @confirmar.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmar;

  /// No description provided for @continuar.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continuar;

  /// No description provided for @entrar.
  ///
  /// In en, this message translates to:
  /// **'Enter'**
  String get entrar;

  /// No description provided for @salir.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get salir;

  /// No description provided for @unMomento.
  ///
  /// In en, this message translates to:
  /// **'One moment...'**
  String get unMomento;

  /// No description provided for @reintentar.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get reintentar;

  /// No description provided for @idioma.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get idioma;

  /// No description provided for @idiomaIngles.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get idiomaIngles;

  /// No description provided for @idiomaEspanol.
  ///
  /// In en, this message translates to:
  /// **'Español'**
  String get idiomaEspanol;

  /// No description provided for @configuracion.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get configuracion;

  /// No description provided for @configuracionIdioma.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get configuracionIdioma;

  /// No description provided for @configuracionCambiarPin.
  ///
  /// In en, this message translates to:
  /// **'Change my PIN'**
  String get configuracionCambiarPin;

  /// No description provided for @cambiarPinTitulo.
  ///
  /// In en, this message translates to:
  /// **'Change my PIN'**
  String get cambiarPinTitulo;

  /// No description provided for @cambiarPinTexto.
  ///
  /// In en, this message translates to:
  /// **'Your account password is asked because it is the only way back if you forget the PIN.'**
  String get cambiarPinTexto;

  /// No description provided for @cambiarPinPassword.
  ///
  /// In en, this message translates to:
  /// **'Account password'**
  String get cambiarPinPassword;

  /// No description provided for @cambiarPinNuevo.
  ///
  /// In en, this message translates to:
  /// **'New 4-digit PIN'**
  String get cambiarPinNuevo;

  /// No description provided for @cambiarPinGuardar.
  ///
  /// In en, this message translates to:
  /// **'Save the new PIN'**
  String get cambiarPinGuardar;

  /// No description provided for @cambiarPinGuardado.
  ///
  /// In en, this message translates to:
  /// **'PIN changed'**
  String get cambiarPinGuardado;

  /// No description provided for @errorInesperado.
  ///
  /// In en, this message translates to:
  /// **'Unexpected error: {detalle}'**
  String errorInesperado(String detalle);

  /// No description provided for @errorSinConexion.
  ///
  /// In en, this message translates to:
  /// **'Could not connect. Check your internet.'**
  String get errorSinConexion;

  /// No description provided for @errorPinIncorrecto.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN.'**
  String get errorPinIncorrecto;

  /// No description provided for @errorGrupoNoExiste.
  ///
  /// In en, this message translates to:
  /// **'This group no longer exists.'**
  String get errorGrupoNoExiste;

  /// No description provided for @errorParticipanteNoExiste.
  ///
  /// In en, this message translates to:
  /// **'That person is no longer in the group.'**
  String get errorParticipanteNoExiste;

  /// No description provided for @errorFaltanDatos.
  ///
  /// In en, this message translates to:
  /// **'Some required information is missing.'**
  String get errorFaltanDatos;

  /// No description provided for @errorFaltanDatosGrupo.
  ///
  /// In en, this message translates to:
  /// **'The occasion or the group name is missing.'**
  String get errorFaltanDatosGrupo;

  /// No description provided for @errorFaltanDatosParticipante.
  ///
  /// In en, this message translates to:
  /// **'The group or the name is missing.'**
  String get errorFaltanDatosParticipante;

  /// No description provided for @errorNicknameLargo.
  ///
  /// In en, this message translates to:
  /// **'The nickname must be between 3 and 24 characters.'**
  String get errorNicknameLargo;

  /// No description provided for @errorNicknameEnUso.
  ///
  /// In en, this message translates to:
  /// **'That nickname is taken. Pick another one.'**
  String get errorNicknameEnUso;

  /// No description provided for @errorNicknameNoExiste.
  ///
  /// In en, this message translates to:
  /// **'That nickname does not exist.'**
  String get errorNicknameNoExiste;

  /// No description provided for @errorPasswordIncorrecta.
  ///
  /// In en, this message translates to:
  /// **'Wrong password.'**
  String get errorPasswordIncorrecta;

  /// No description provided for @errorPasswordDebil.
  ///
  /// In en, this message translates to:
  /// **'The password needs at least 8 characters, one uppercase, one lowercase, one number and one special character.'**
  String get errorPasswordDebil;

  /// No description provided for @errorMinimoDosPersonas.
  ///
  /// In en, this message translates to:
  /// **'You need at least 2 people to draw names.'**
  String get errorMinimoDosPersonas;

  /// No description provided for @errorNadaQueCambiar.
  ///
  /// In en, this message translates to:
  /// **'Nothing to change.'**
  String get errorNadaQueCambiar;

  /// No description provided for @errorNombreVacio.
  ///
  /// In en, this message translates to:
  /// **'The group name cannot be empty.'**
  String get errorNombreVacio;

  /// No description provided for @errorReglasMuyLargas.
  ///
  /// In en, this message translates to:
  /// **'The rules cannot be longer than 2000 characters.'**
  String get errorReglasMuyLargas;

  /// No description provided for @errorImagenInvalida.
  ///
  /// In en, this message translates to:
  /// **'The image arrived empty or damaged.'**
  String get errorImagenInvalida;

  /// No description provided for @errorImagenMuyGrande.
  ///
  /// In en, this message translates to:
  /// **'The image is too large.'**
  String get errorImagenMuyGrande;

  /// No description provided for @errorCodigoNoGenerado.
  ///
  /// In en, this message translates to:
  /// **'Could not create the group, please try again.'**
  String get errorCodigoNoGenerado;

  /// No description provided for @errorPinFormato.
  ///
  /// In en, this message translates to:
  /// **'The PIN must be exactly 4 digits'**
  String get errorPinFormato;

  /// No description provided for @errorNoEresOrganizador.
  ///
  /// In en, this message translates to:
  /// **'Only the group organizer can do this'**
  String get errorNoEresOrganizador;

  /// No description provided for @errorNoEstasEnElGrupo.
  ///
  /// In en, this message translates to:
  /// **'You are not signed up in this group yet'**
  String get errorNoEstasEnElGrupo;

  /// No description provided for @errorYaEstasEnElGrupo.
  ///
  /// In en, this message translates to:
  /// **'You already have a spot in this group'**
  String get errorYaEstasEnElGrupo;

  /// No description provided for @errorGrupoYaSorteado.
  ///
  /// In en, this message translates to:
  /// **'The draw already happened. This person cannot be removed — they have to be replaced so the chain stays intact.'**
  String get errorGrupoYaSorteado;

  /// Someone tried to join a group whose draw already ran
  ///
  /// In en, this message translates to:
  /// **'The draw already happened, so this group is closed to new people. Ask the organiser to take someone\'s place instead.'**
  String get errorGrupoCerrado;

  /// The organiser tried to run the draw on a group that already drew
  ///
  /// In en, this message translates to:
  /// **'This group has already drawn. The draw can\'t be run twice.'**
  String get errorSorteoYaHecho;

  /// No description provided for @errorPinBloqueado.
  ///
  /// In en, this message translates to:
  /// **'Too many wrong PINs. Wait a few minutes, or change your PIN from Settings.'**
  String get errorPinBloqueado;

  /// Server rejected the call because the account's email is not verified yet
  ///
  /// In en, this message translates to:
  /// **'Verify your email to continue.'**
  String get errorCorreoSinVerificar;

  /// The action needs a recent sign-in and the session is too old
  ///
  /// In en, this message translates to:
  /// **'For security, confirm your password again.'**
  String get errorRequiereReautenticacion;

  /// There is an Auth account but no profile document
  ///
  /// In en, this message translates to:
  /// **'Your account has no profile yet. Sign in again to finish it.'**
  String get errorPerfilIncompleto;

  /// Malformed email address
  ///
  /// In en, this message translates to:
  /// **'That email address doesn\'t look right.'**
  String get errorCorreoInvalido;

  /// Email already registered
  ///
  /// In en, this message translates to:
  /// **'That email already has an account. Sign in instead.'**
  String get errorCorreoEnUso;

  /// Firebase Auth rate limit hit
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a few minutes and try again.'**
  String get errorDemasiadosIntentos;

  /// Account disabled from the Firebase console
  ///
  /// In en, this message translates to:
  /// **'This account has been disabled.'**
  String get errorCuentaDeshabilitada;

  /// Fallback for an Auth error code this version doesn't know
  ///
  /// In en, this message translates to:
  /// **'Something went wrong signing you in. Try again.'**
  String get errorAuthDesconocido;

  /// Name or surname over the server limit
  ///
  /// In en, this message translates to:
  /// **'Your name and surname can\'t be longer than 40 characters each.'**
  String get errorNombreLargo;

  /// No description provided for @inicioSubtitulo.
  ///
  /// In en, this message translates to:
  /// **'Group Manager'**
  String get inicioSubtitulo;

  /// No description provided for @inicioContinuarEn.
  ///
  /// In en, this message translates to:
  /// **'Continue in \"{grupo}\"'**
  String inicioContinuarEn(String grupo);

  /// No description provided for @inicioUltimoGrupoNota.
  ///
  /// In en, this message translates to:
  /// **'(your last group\'s code, saved on this device)'**
  String get inicioUltimoGrupoNota;

  /// No description provided for @inicioCrearGrupo.
  ///
  /// In en, this message translates to:
  /// **'Create a new group'**
  String get inicioCrearGrupo;

  /// No description provided for @inicioUnirse.
  ///
  /// In en, this message translates to:
  /// **'Join with a code'**
  String get inicioUnirse;

  /// No description provided for @inicioMiCuenta.
  ///
  /// In en, this message translates to:
  /// **'My account (find my groups from any device)'**
  String get inicioMiCuenta;

  /// No description provided for @crearTitulo.
  ///
  /// In en, this message translates to:
  /// **'Create group'**
  String get crearTitulo;

  /// No description provided for @crearOcasion.
  ///
  /// In en, this message translates to:
  /// **'Occasion'**
  String get crearOcasion;

  /// No description provided for @crearNombreGrupo.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get crearNombreGrupo;

  /// No description provided for @crearNombreGrupoPista.
  ///
  /// In en, this message translates to:
  /// **'e.g. The Smiths, Office 2026'**
  String get crearNombreGrupoPista;

  /// No description provided for @crearValorMinimo.
  ///
  /// In en, this message translates to:
  /// **'Minimum gift value (optional)'**
  String get crearValorMinimo;

  /// No description provided for @crearValorMinimoPista.
  ///
  /// In en, this message translates to:
  /// **'e.g. \$50'**
  String get crearValorMinimoPista;

  /// No description provided for @crearFaltanDatos.
  ///
  /// In en, this message translates to:
  /// **'The group name is missing'**
  String get crearFaltanDatos;

  /// No description provided for @crearBoton.
  ///
  /// In en, this message translates to:
  /// **'Create group'**
  String get crearBoton;

  /// No description provided for @crearCreando.
  ///
  /// In en, this message translates to:
  /// **'Creating...'**
  String get crearCreando;

  /// No description provided for @crearListoTitulo.
  ///
  /// In en, this message translates to:
  /// **'Group created!'**
  String get crearListoTitulo;

  /// No description provided for @crearListoTexto.
  ///
  /// In en, this message translates to:
  /// **'Share this code so your group can join:'**
  String get crearListoTexto;

  /// No description provided for @unirseTitulo.
  ///
  /// In en, this message translates to:
  /// **'Join a group'**
  String get unirseTitulo;

  /// No description provided for @unirseCodigo.
  ///
  /// In en, this message translates to:
  /// **'Group code'**
  String get unirseCodigo;

  /// No description provided for @unirseCodigoPista.
  ///
  /// In en, this message translates to:
  /// **'e.g. BLUE-7F3K'**
  String get unirseCodigoPista;

  /// No description provided for @unirseBoton.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get unirseBoton;

  /// No description provided for @unirseBuscando.
  ///
  /// In en, this message translates to:
  /// **'Searching...'**
  String get unirseBuscando;

  /// No description provided for @unirseNoExiste.
  ///
  /// In en, this message translates to:
  /// **'That code does not exist. Check it.'**
  String get unirseNoExiste;

  /// No description provided for @cuentaCrearTitulo.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get cuentaCrearTitulo;

  /// No description provided for @cuentaEntrarTitulo.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get cuentaEntrarTitulo;

  /// No description provided for @cuentaNickname.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get cuentaNickname;

  /// Label of the email field on the account screens
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get cuentaCorreo;

  /// Label of the first name field on the account screens
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get cuentaNombre;

  /// Label of the last name field on the account screens
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get cuentaApellido;

  /// No description provided for @cuentaPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get cuentaPassword;

  /// No description provided for @cuentaPasswordAyuda.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters: uppercase, lowercase, number and special character'**
  String get cuentaPasswordAyuda;

  /// No description provided for @cuentaConfirmar.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get cuentaConfirmar;

  /// No description provided for @cuentaFaltanDatos.
  ///
  /// In en, this message translates to:
  /// **'Some required information is missing'**
  String get cuentaFaltanDatos;

  /// No description provided for @cuentaNoCoinciden.
  ///
  /// In en, this message translates to:
  /// **'The passwords do not match'**
  String get cuentaNoCoinciden;

  /// No description provided for @cuentaCambiarAEntrar.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get cuentaCambiarAEntrar;

  /// No description provided for @cuentaCambiarACrear.
  ///
  /// In en, this message translates to:
  /// **'No account yet? Create one'**
  String get cuentaCambiarACrear;

  /// No description provided for @cuentaFraseGancho.
  ///
  /// In en, this message translates to:
  /// **'Create your account to discover who sends you the secret gifts'**
  String get cuentaFraseGancho;

  /// No description provided for @cuentaInvitadoA.
  ///
  /// In en, this message translates to:
  /// **'You\'ve been invited to “{grupo}”'**
  String cuentaInvitadoA(String grupo);

  /// No description provided for @cuentaYaTengoCuenta.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get cuentaYaTengoCuenta;

  /// No description provided for @cuentaNoTengoCuenta.
  ///
  /// In en, this message translates to:
  /// **'No account yet? Create one'**
  String get cuentaNoTengoCuenta;

  /// No description provided for @cuentaPin.
  ///
  /// In en, this message translates to:
  /// **'4-digit PIN'**
  String get cuentaPin;

  /// No description provided for @cuentaPinAyuda.
  ///
  /// In en, this message translates to:
  /// **'You will type it to reveal your secret friend, in every group. Only you know it.'**
  String get cuentaPinAyuda;

  /// No description provided for @cuentaPinConfirmar.
  ///
  /// In en, this message translates to:
  /// **'Confirm PIN'**
  String get cuentaPinConfirmar;

  /// No description provided for @cuentaPinNoCoinciden.
  ///
  /// In en, this message translates to:
  /// **'The PINs do not match'**
  String get cuentaPinNoCoinciden;

  /// Link on the sign-in screen that opens the password recovery screen
  ///
  /// In en, this message translates to:
  /// **'I forgot my password'**
  String get recuperarEnlace;

  /// Title of the password recovery screen
  ///
  /// In en, this message translates to:
  /// **'Recover your password'**
  String get recuperarTitulo;

  /// Body text of the password recovery screen
  ///
  /// In en, this message translates to:
  /// **'Type the email you signed up with and we\'ll send you a link to set a new password.'**
  String get recuperarTexto;

  /// Button that sends the password recovery email
  ///
  /// In en, this message translates to:
  /// **'Send me the link'**
  String get recuperarBoton;

  /// Confirmation shown after requesting recovery, identical whether or not the account exists, to avoid revealing which emails are registered
  ///
  /// In en, this message translates to:
  /// **'If that address has an account, we\'ve sent it a link.'**
  String get recuperarEnviado;

  /// Title of the blocking email-verification screen
  ///
  /// In en, this message translates to:
  /// **'Check your inbox'**
  String get verificarTitulo;

  /// Body text of the blocking email-verification screen
  ///
  /// In en, this message translates to:
  /// **'We sent you a link. Tap it to confirm your email, then come back here.'**
  String get verificarTexto;

  /// Button that checks whether the email is now verified
  ///
  /// In en, this message translates to:
  /// **'I\'ve confirmed it'**
  String get verificarComprobar;

  /// Loading label for the button that checks verification
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get verificarComprobando;

  /// Button that resends the verification email
  ///
  /// In en, this message translates to:
  /// **'Send it again'**
  String get verificarReenviar;

  /// Loading label for the button that resends the verification email
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get verificarReenviando;

  /// Confirmation shown after resending the verification email
  ///
  /// In en, this message translates to:
  /// **'Link sent'**
  String get verificarReenviado;

  /// Shown when the person taps 'I've confirmed it' but the email is still unverified
  ///
  /// In en, this message translates to:
  /// **'Not confirmed yet. Check your inbox — it may be in spam.'**
  String get verificarTodaviaNo;

  /// Title of the screen that completes a profile left unfinished after signing up
  ///
  /// In en, this message translates to:
  /// **'One last step'**
  String get completarPerfilTitulo;

  /// Body text of the screen that completes a profile left unfinished after signing up
  ///
  /// In en, this message translates to:
  /// **'Your account was created but your profile wasn\'t saved. Fill it in to continue.'**
  String get completarPerfilTexto;

  /// No description provided for @misGruposSaludo.
  ///
  /// In en, this message translates to:
  /// **'Hi, {nickname}'**
  String misGruposSaludo(String nickname);

  /// No description provided for @misGruposVacio.
  ///
  /// In en, this message translates to:
  /// **'You have no groups linked to this account yet.\nCreate or join one and it will show up here.'**
  String get misGruposVacio;

  /// No description provided for @misGruposOrganizador.
  ///
  /// In en, this message translates to:
  /// **'Organizer'**
  String get misGruposOrganizador;

  /// No description provided for @misGruposParticipante.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get misGruposParticipante;

  /// No description provided for @misGruposCerrarSesion.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get misGruposCerrarSesion;

  /// No description provided for @misGruposCrear.
  ///
  /// In en, this message translates to:
  /// **'Create a new group'**
  String get misGruposCrear;

  /// No description provided for @misGruposUnirse.
  ///
  /// In en, this message translates to:
  /// **'Join with a code'**
  String get misGruposUnirse;

  /// No description provided for @grupoCodigo.
  ///
  /// In en, this message translates to:
  /// **'Code: {codigo}'**
  String grupoCodigo(String codigo);

  /// No description provided for @grupoMinimo.
  ///
  /// In en, this message translates to:
  /// **'Minimum: {valor}'**
  String grupoMinimo(String valor);

  /// No description provided for @grupoCompartir.
  ///
  /// In en, this message translates to:
  /// **'Share invitation'**
  String get grupoCompartir;

  /// No description provided for @grupoQR.
  ///
  /// In en, this message translates to:
  /// **'QR code'**
  String get grupoQR;

  /// No description provided for @grupoQRTitulo.
  ///
  /// In en, this message translates to:
  /// **'Scan to join'**
  String get grupoQRTitulo;

  /// No description provided for @grupoCompartirTexto.
  ///
  /// In en, this message translates to:
  /// **'Join \"{grupo}\" {emoji}\nCode: {codigo}\n{url}'**
  String grupoCompartirTexto(
    Object grupo,
    Object emoji,
    Object codigo,
    Object url,
  );

  /// No description provided for @grupoReglas.
  ///
  /// In en, this message translates to:
  /// **'Game rules'**
  String get grupoReglas;

  /// No description provided for @grupoEliminadoAviso.
  ///
  /// In en, this message translates to:
  /// **'This group was deleted by its organizer.'**
  String get grupoEliminadoAviso;

  /// No description provided for @registroTituloNormal.
  ///
  /// In en, this message translates to:
  /// **'New member'**
  String get registroTituloNormal;

  /// No description provided for @registroTituloPersonaje.
  ///
  /// In en, this message translates to:
  /// **'Join with your character'**
  String get registroTituloPersonaje;

  /// No description provided for @registroDeseos.
  ///
  /// In en, this message translates to:
  /// **'Wish list'**
  String get registroDeseos;

  /// No description provided for @registroDeseosAyudaNormal.
  ///
  /// In en, this message translates to:
  /// **'Only the person giving you a gift will see it.'**
  String get registroDeseosAyudaNormal;

  /// No description provided for @registroDeseosAyudaPersonaje.
  ///
  /// In en, this message translates to:
  /// **'Nobody knows who you are, so this is the only clue your gift giver will have.'**
  String get registroDeseosAyudaPersonaje;

  /// No description provided for @registroBoton.
  ///
  /// In en, this message translates to:
  /// **'ADD TO THE LIST'**
  String get registroBoton;

  /// No description provided for @registroFaltaNombre.
  ///
  /// In en, this message translates to:
  /// **'The name is missing'**
  String get registroFaltaNombre;

  /// No description provided for @registroFaltaPersonaje.
  ///
  /// In en, this message translates to:
  /// **'The character is missing'**
  String get registroFaltaPersonaje;

  /// No description provided for @registroVacioNormal.
  ///
  /// In en, this message translates to:
  /// **'No members yet.'**
  String get registroVacioNormal;

  /// No description provided for @registroVacioPersonaje.
  ///
  /// In en, this message translates to:
  /// **'No characters yet.'**
  String get registroVacioPersonaje;

  /// No description provided for @registroYaTieneAmigo.
  ///
  /// In en, this message translates to:
  /// **'Already has their secret friend'**
  String get registroYaTieneAmigo;

  /// No description provided for @registroSalirGrupo.
  ///
  /// In en, this message translates to:
  /// **'Leave the group'**
  String get registroSalirGrupo;

  /// No description provided for @registroVerAmigo.
  ///
  /// In en, this message translates to:
  /// **'SEE MY SECRET FRIEND'**
  String get registroVerAmigo;

  /// No description provided for @organizadorEditarGrupo.
  ///
  /// In en, this message translates to:
  /// **'Edit the group'**
  String get organizadorEditarGrupo;

  /// No description provided for @organizadorCorregirNombre.
  ///
  /// In en, this message translates to:
  /// **'Fix the name'**
  String get organizadorCorregirNombre;

  /// No description provided for @organizadorCorregirPersonaje.
  ///
  /// In en, this message translates to:
  /// **'Fix the character'**
  String get organizadorCorregirPersonaje;

  /// No description provided for @organizadorSacar.
  ///
  /// In en, this message translates to:
  /// **'Remove from the group'**
  String get organizadorSacar;

  /// No description provided for @organizadorSacarPregunta.
  ///
  /// In en, this message translates to:
  /// **'Remove {nombre} from the group?'**
  String organizadorSacarPregunta(String nombre);

  /// No description provided for @organizadorSacarTexto.
  ///
  /// In en, this message translates to:
  /// **'They will be deleted along with their wish list and their assignment.'**
  String get organizadorSacarTexto;

  /// No description provided for @organizadorSacarBoton.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get organizadorSacarBoton;

  /// No description provided for @sorteoBoton.
  ///
  /// In en, this message translates to:
  /// **'DRAW NAMES'**
  String get sorteoBoton;

  /// No description provided for @sorteoTitulo.
  ///
  /// In en, this message translates to:
  /// **'Draw names'**
  String get sorteoTitulo;

  /// No description provided for @sorteoTexto.
  ///
  /// In en, this message translates to:
  /// **'Each member gets their secret friend. Drawing again replaces the previous assignments.'**
  String get sorteoTexto;

  /// No description provided for @sorteoConfirmar.
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get sorteoConfirmar;

  /// No description provided for @sorteoListo.
  ///
  /// In en, this message translates to:
  /// **'Names drawn!'**
  String get sorteoListo;

  /// No description provided for @editarTitulo.
  ///
  /// In en, this message translates to:
  /// **'Edit group'**
  String get editarTitulo;

  /// No description provided for @editarReglas.
  ///
  /// In en, this message translates to:
  /// **'Game rules'**
  String get editarReglas;

  /// No description provided for @editarReglasAyuda.
  ///
  /// In en, this message translates to:
  /// **'The whole group sees them on the main screen.'**
  String get editarReglasAyuda;

  /// No description provided for @editarGuardar.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get editarGuardar;

  /// No description provided for @editarGuardando.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get editarGuardando;

  /// No description provided for @editarGuardado.
  ///
  /// In en, this message translates to:
  /// **'Changes saved'**
  String get editarGuardado;

  /// No description provided for @editarZonaPeligro.
  ///
  /// In en, this message translates to:
  /// **'Point of no return'**
  String get editarZonaPeligro;

  /// No description provided for @editarZonaPeligroTexto.
  ///
  /// In en, this message translates to:
  /// **'Deleting the group removes every member and all their data. There is no way to get it back.'**
  String get editarZonaPeligroTexto;

  /// No description provided for @editarEliminarBoton.
  ///
  /// In en, this message translates to:
  /// **'Delete this group'**
  String get editarEliminarBoton;

  /// No description provided for @editarEliminarTitulo.
  ///
  /// In en, this message translates to:
  /// **'Delete the group'**
  String get editarEliminarTitulo;

  /// No description provided for @editarEliminarTexto.
  ///
  /// In en, this message translates to:
  /// **'\"{grupo}\" will be deleted with all its members, their wish lists and the draw if it already happened.\n\nThis cannot be undone.'**
  String editarEliminarTexto(String grupo);

  /// No description provided for @editarEliminarConfirmar.
  ///
  /// In en, this message translates to:
  /// **'Yes, delete it'**
  String get editarEliminarConfirmar;

  /// No description provided for @editarEliminarEscribeNombre.
  ///
  /// In en, this message translates to:
  /// **'To delete it, type the group name exactly: {grupo}'**
  String editarEliminarEscribeNombre(String grupo);

  /// No description provided for @editarEliminado.
  ///
  /// In en, this message translates to:
  /// **'Group deleted'**
  String get editarEliminado;

  /// No description provided for @verAmigoPinTitulo.
  ///
  /// In en, this message translates to:
  /// **'Type your PIN'**
  String get verAmigoPinTitulo;

  /// No description provided for @verAmigoPinTexto.
  ///
  /// In en, this message translates to:
  /// **'Nobody else should see this. Your PIN is asked every time.'**
  String get verAmigoPinTexto;

  /// No description provided for @secretaTitulo.
  ///
  /// In en, this message translates to:
  /// **'Your secret friend is...'**
  String get secretaTitulo;

  /// No description provided for @secretaSinSorteo.
  ///
  /// In en, this message translates to:
  /// **'The draw has not happened yet'**
  String get secretaSinSorteo;

  /// No description provided for @secretaRevelar.
  ///
  /// In en, this message translates to:
  /// **'REVEAL'**
  String get secretaRevelar;

  /// No description provided for @secretaDesea.
  ///
  /// In en, this message translates to:
  /// **'Wishes: {deseos}'**
  String secretaDesea(String deseos);

  /// No description provided for @secretaSinSugerencias.
  ///
  /// In en, this message translates to:
  /// **'No suggestions'**
  String get secretaSinSugerencias;

  /// No description provided for @ocasionAmigoSecreto.
  ///
  /// In en, this message translates to:
  /// **'Secret Friend'**
  String get ocasionAmigoSecreto;

  /// No description provided for @ocasionSantaSecreto.
  ///
  /// In en, this message translates to:
  /// **'Secret Santa'**
  String get ocasionSantaSecreto;

  /// No description provided for @avatarCambiar.
  ///
  /// In en, this message translates to:
  /// **'Change image'**
  String get avatarCambiar;

  /// No description provided for @avatarQuitar.
  ///
  /// In en, this message translates to:
  /// **'Remove image'**
  String get avatarQuitar;

  /// No description provided for @avatarNoGaleria.
  ///
  /// In en, this message translates to:
  /// **'Could not open the gallery: {detalle}'**
  String avatarNoGaleria(String detalle);

  /// No description provided for @tematica.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get tematica;

  /// No description provided for @tematicaAyuda.
  ///
  /// In en, this message translates to:
  /// **'With a theme, nobody uses their real name: everyone signs up as the character they pick.'**
  String get tematicaAyuda;

  /// No description provided for @tematicaNombreNinguna.
  ///
  /// In en, this message translates to:
  /// **'No theme'**
  String get tematicaNombreNinguna;

  /// No description provided for @tematicaNombreCaricaturas.
  ///
  /// In en, this message translates to:
  /// **'Cartoons'**
  String get tematicaNombreCaricaturas;

  /// No description provided for @tematicaNombreAlfombraRoja.
  ///
  /// In en, this message translates to:
  /// **'Red carpet'**
  String get tematicaNombreAlfombraRoja;

  /// No description provided for @tematicaNombreNavidad.
  ///
  /// In en, this message translates to:
  /// **'Christmas'**
  String get tematicaNombreNavidad;

  /// No description provided for @tematicaDescNinguna.
  ///
  /// In en, this message translates to:
  /// **'Everyone with their own name and photo'**
  String get tematicaDescNinguna;

  /// No description provided for @tematicaDescCaricaturas.
  ///
  /// In en, this message translates to:
  /// **'Everyone picks their cartoon character'**
  String get tematicaDescCaricaturas;

  /// No description provided for @tematicaDescAlfombraRoja.
  ///
  /// In en, this message translates to:
  /// **'Everyone picks a famous star'**
  String get tematicaDescAlfombraRoja;

  /// No description provided for @tematicaDescNavidad.
  ///
  /// In en, this message translates to:
  /// **'Everyone picks a Christmas character'**
  String get tematicaDescNavidad;

  /// No description provided for @tematicaNombreCampoNormal.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get tematicaNombreCampoNormal;

  /// No description provided for @tematicaNombreCampoPersonaje.
  ///
  /// In en, this message translates to:
  /// **'Your character\'s name'**
  String get tematicaNombreCampoPersonaje;

  /// No description provided for @tematicaImagenNormal.
  ///
  /// In en, this message translates to:
  /// **'Your photo'**
  String get tematicaImagenNormal;

  /// No description provided for @tematicaImagenPersonaje.
  ///
  /// In en, this message translates to:
  /// **'Your character\'s image'**
  String get tematicaImagenPersonaje;

  /// No description provided for @tematicaPistaNinguna.
  ///
  /// In en, this message translates to:
  /// **'e.g. Andrew Chaves'**
  String get tematicaPistaNinguna;

  /// No description provided for @tematicaPistaCaricaturas.
  ///
  /// In en, this message translates to:
  /// **'e.g. The Lucky Rabbit'**
  String get tematicaPistaCaricaturas;

  /// No description provided for @tematicaPistaAlfombraRoja.
  ///
  /// In en, this message translates to:
  /// **'e.g. The Movie Diva'**
  String get tematicaPistaAlfombraRoja;

  /// No description provided for @tematicaPistaNavidad.
  ///
  /// In en, this message translates to:
  /// **'e.g. The Naughty Elf'**
  String get tematicaPistaNavidad;

  /// No description provided for @grupoYaDentro.
  ///
  /// In en, this message translates to:
  /// **'You are in this group as {nombre}'**
  String grupoYaDentro(String nombre);

  /// No description provided for @grupoYaDentroAyuda.
  ///
  /// In en, this message translates to:
  /// **'Your entry is saved. Nobody has to sign up twice.'**
  String get grupoYaDentroAyuda;

  /// No description provided for @grupoTuEtiqueta.
  ///
  /// In en, this message translates to:
  /// **'you'**
  String get grupoTuEtiqueta;

  /// No description provided for @chatTitulo.
  ///
  /// In en, this message translates to:
  /// **'Anonymous chat'**
  String get chatTitulo;

  /// No description provided for @chatAbrir.
  ///
  /// In en, this message translates to:
  /// **'GROUP CHAT'**
  String get chatAbrir;

  /// No description provided for @chatVacio.
  ///
  /// In en, this message translates to:
  /// **'No messages yet.\nBe the first to write — nobody will know it was you.'**
  String get chatVacio;

  /// No description provided for @chatEscribe.
  ///
  /// In en, this message translates to:
  /// **'Write a message...'**
  String get chatEscribe;

  /// No description provided for @chatEnviar.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatEnviar;

  /// No description provided for @chatTuMascara.
  ///
  /// In en, this message translates to:
  /// **'In the chat you are {mascara}. Nobody can see who is behind it — not even the organizer.'**
  String chatTuMascara(String mascara);

  /// No description provided for @chatTu.
  ///
  /// In en, this message translates to:
  /// **'you'**
  String get chatTu;

  /// No description provided for @chatBorrarMensaje.
  ///
  /// In en, this message translates to:
  /// **'Delete message'**
  String get chatBorrarMensaje;

  /// No description provided for @chatBorrarPregunta.
  ///
  /// In en, this message translates to:
  /// **'Delete this message?'**
  String get chatBorrarPregunta;

  /// No description provided for @chatBorrarTexto.
  ///
  /// In en, this message translates to:
  /// **'It disappears for the whole group. You will not find out who wrote it.'**
  String get chatBorrarTexto;

  /// No description provided for @errorMensajeVacio.
  ///
  /// In en, this message translates to:
  /// **'The message is empty.'**
  String get errorMensajeVacio;

  /// No description provided for @errorMensajeLargo.
  ///
  /// In en, this message translates to:
  /// **'The message is too long.'**
  String get errorMensajeLargo;

  /// No description provided for @errorMuyRapido.
  ///
  /// In en, this message translates to:
  /// **'Wait a moment before writing again.'**
  String get errorMuyRapido;

  /// No description provided for @errorSesionInvalida.
  ///
  /// In en, this message translates to:
  /// **'Your account session is no longer valid. Please sign in again.'**
  String get errorSesionInvalida;

  /// No description provided for @mascaraZorro.
  ///
  /// In en, this message translates to:
  /// **'Fox'**
  String get mascaraZorro;

  /// No description provided for @mascaraBuho.
  ///
  /// In en, this message translates to:
  /// **'Owl'**
  String get mascaraBuho;

  /// No description provided for @mascaraOso.
  ///
  /// In en, this message translates to:
  /// **'Bear'**
  String get mascaraOso;

  /// No description provided for @mascaraGato.
  ///
  /// In en, this message translates to:
  /// **'Cat'**
  String get mascaraGato;

  /// No description provided for @mascaraLobo.
  ///
  /// In en, this message translates to:
  /// **'Wolf'**
  String get mascaraLobo;

  /// No description provided for @mascaraConejo.
  ///
  /// In en, this message translates to:
  /// **'Rabbit'**
  String get mascaraConejo;

  /// No description provided for @mascaraCiervo.
  ///
  /// In en, this message translates to:
  /// **'Deer'**
  String get mascaraCiervo;

  /// No description provided for @mascaraPanda.
  ///
  /// In en, this message translates to:
  /// **'Panda'**
  String get mascaraPanda;

  /// No description provided for @mascaraTigre.
  ///
  /// In en, this message translates to:
  /// **'Tiger'**
  String get mascaraTigre;

  /// No description provided for @mascaraPinguino.
  ///
  /// In en, this message translates to:
  /// **'Penguin'**
  String get mascaraPinguino;

  /// No description provided for @mascaraDelfin.
  ///
  /// In en, this message translates to:
  /// **'Dolphin'**
  String get mascaraDelfin;

  /// No description provided for @mascaraAguila.
  ///
  /// In en, this message translates to:
  /// **'Eagle'**
  String get mascaraAguila;

  /// No description provided for @mascaraRana.
  ///
  /// In en, this message translates to:
  /// **'Frog'**
  String get mascaraRana;

  /// No description provided for @mascaraErizo.
  ///
  /// In en, this message translates to:
  /// **'Hedgehog'**
  String get mascaraErizo;

  /// No description provided for @mascaraKoala.
  ///
  /// In en, this message translates to:
  /// **'Koala'**
  String get mascaraKoala;

  /// No description provided for @mascaraNutria.
  ///
  /// In en, this message translates to:
  /// **'Otter'**
  String get mascaraNutria;

  /// No description provided for @reglasNinguna.
  ///
  /// In en, this message translates to:
  /// **'A surprise gift for your secret friend.\n\n• Don\'t tell anyone who you got.\n• Write your wish list so whoever gives you a gift has a clue.'**
  String get reglasNinguna;

  /// No description provided for @reglasCaricaturas.
  ///
  /// In en, this message translates to:
  /// **'Cartoon group! Nobody uses their real name.\n\n• Pick the cartoon character you like most and upload their image.\n• Nobody knows who is behind each character until the gift exchange.\n• Write your wish list: it is the only clue your gift giver will have.'**
  String get reglasCaricaturas;

  /// No description provided for @reglasAlfombraRoja.
  ///
  /// In en, this message translates to:
  /// **'Gala night! We are all stars this time.\n\n• Pick the celebrity you want to be and upload their photo.\n• Nobody knows which star is who until the gift exchange.\n• Write your wish list: it is the only clue your gift giver will have.'**
  String get reglasAlfombraRoja;

  /// No description provided for @reglasNavidad.
  ///
  /// In en, this message translates to:
  /// **'Christmas in the group! Nobody uses their real name.\n\n• Pick your Christmas character and upload their image.\n• Nobody knows who is who until the gift exchange.\n• Write your wish list: it is the only clue your gift giver will have.'**
  String get reglasNavidad;
}

class _TextosDelegate extends LocalizationsDelegate<Textos> {
  const _TextosDelegate();

  @override
  Future<Textos> load(Locale locale) {
    return SynchronousFuture<Textos>(lookupTextos(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_TextosDelegate old) => false;
}

Textos lookupTextos(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return TextosEn();
    case 'es':
      return TextosEs();
  }

  throw FlutterError(
    'Textos.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
