import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'acceso_cuenta.dart';
import 'auth.dart';
import 'destino_inicial.dart';
import 'funciones.dart';
import 'glass.dart';
import 'invitacion_pendiente.dart';
import 'l10n/app_localizations.dart';
import 'mi_vinculo.dart';
import 'ocasion.dart';
import 'oferta_avisos.dart';
import 'pantalla_completar_perfil.dart';
import 'pantalla_crear_cuenta.dart';
import 'pantalla_mis_grupos.dart';
import 'pantalla_registro.dart';
import 'pantalla_verificar_correo.dart';
import 'push.dart';
import 'tematica.dart';

/// Lo que trae un enlace de invitación (`?codigo=XXXX-YYYY`, con o sin
/// `&reemplazo=`), ya extraído del URI.
///
/// Es una clase aparte, y no una tupla de dos strings sueltos, por lo mismo
/// que `InvitacionPendiente` en `invitacion_pendiente.dart`: los nombres de
/// los campos documentan qué es cada cosa en el sitio donde se usa.
class EnlaceInvitacion {
  final String codigo;

  /// Token del enlace de reemplazo, si lo traía. Null en una invitación
  /// normal.
  final String? reemplazo;

  const EnlaceInvitacion(this.codigo, {this.reemplazo});
}

/// Extrae el código (y el token de reemplazo, si lo hay) de un URI de
/// invitación, o `null` si no trae ninguno.
///
/// Función PURA a propósito —sin Firestore, sin disco, sin plataforma—
/// para poder probarla suelta con un `Uri` cualquiera, igual que
/// `debeAbrirseElAviso` en `push.dart` prueba su propia decisión sin tocar
/// FCM. La comparten los dos caminos que leen un enlace de invitación: el
/// de web (`Uri.base`, ver `_capturarInvitacionDeLaUrl`) y el nativo de
/// Android (`app_links`, ver `_capturarInvitacionDeLaUrlNativa`), para que
/// los dos entiendan la URL exactamente de la misma forma.
EnlaceInvitacion? leerEnlaceInvitacion(Uri uri) {
  final codigo = uri.queryParameters['codigo']?.trim().toUpperCase();
  if (codigo == null || codigo.isEmpty) return null;
  final reemplazo = uri.queryParameters['reemplazo']?.trim();
  return EnlaceInvitacion(codigo, reemplazo: reemplazo);
}

/// Primera pantalla real de la app: decide a dónde va cada quien.
///
/// Normalmente solo muestra un indicador mientras lee disco y valida la
/// sesión. Se queda visible únicamente si el arranque falla por algo que
/// no invalida la sesión (sin red, servidor caído): entonces enseña el
/// error y un botón de reintentar, porque borrar la sesión en ese caso
/// sería irreversible.
class PantallaRaiz extends StatefulWidget {
  const PantallaRaiz({super.key});

  @override
  State<PantallaRaiz> createState() => _PantallaRaizState();
}

class _PantallaRaizState extends State<PantallaRaiz> {
  /// Error del último arranque, o null mientras va bien. Se guarda la
  /// excepción y no un texto ya traducido porque el idioma puede cambiar
  /// con la pantalla de error delante.
  Object? _errorArranque;

  /// Se completa cuando el primer `_arrancar()` termina de construir su
  /// pila (o de dejar puesta la pantalla de error). Sirve para que un
  /// aviso tocado justo al arrancar ESPERE a que esa primera
  /// reconstrucción termine antes de tocar la pila él mismo: los dos
  /// acaban en `pushAndRemoveUntil` sobre el mismo Navigator, y sin
  /// serializarlos gana el que responda antes, dejando una carrera entre
  /// dos pilas distintas.
  final Completer<void> _primerArranqueListo = Completer<void>();

  /// Último URI de invitación nativo ya procesado en lo que va de esta
  /// ejecución de la app, o null. Ver el comentario de
  /// `_capturarEnlaceNativoSiCorresponde` sobre por qué hace falta.
  Uri? _ultimoEnlaceNativoProcesado;

  @override
  void initState() {
    super.initState();
    // Se captura el Navigator ANTES de arrancar: `_arrancar` casi siempre
    // termina en un `pushReplacement` que saca esta pantalla de la pila y
    // destruye este State, así que a partir de ahí `context` deja de
    // servir. El NavigatorState, en cambio, sigue siendo el mismo durante
    // toda la vida de la app (es el mismo truco que usa `irADondeToque`
    // más abajo, ver su comentario). Sin capturarlo aquí, tocar un aviso
    // minutos después de arrancar no tendría dónde navegar: el callback
    // de `alTocarAviso` vería `mounted == false` y no haría nada nunca.
    final navegador = Navigator.of(context);
    // Tocar un aviso abre su grupo. Sin esto, el aviso lleva a la pantalla
    // de inicio y la persona tiene que buscar el grupo a mano — que es
    // justo la fricción que el aviso venía a quitar.
    alTocarAviso((codigo) => _abrirGrupoDesdeAviso(navegador, codigo));

    // Enlaces de invitación en Android con la app YA abierta (el caso
    // "app cerrada" se resuelve dentro de `_arrancar()`, más abajo, con
    // `_capturarInvitacionDeLaUrlNativa`). Se registra aquí —ANTES de
    // `_arrancar()`, y para toda la vida de la app, no solo mientras esta
    // pantalla esté montada— por la misma razón que `alTocarAviso`
    // arriba: es un suceso de toda la app, y esta pantalla, aunque su
    // widget se destruya enseguida, es el único sitio que existe una
    // única vez para engancharse a él. No se cancela la suscripción
    // (no hay `dispose()` en este State) por el mismo motivo por el que
    // `alTocarAviso` tampoco cancela las suyas: tiene que seguir viva
    // después de que este State desaparezca.
    if (!kIsWeb) {
      AppLinks().uriLinkStream.listen(
          (uri) => _alRecibirEnlaceNativoConAppAbierta(navegador, uri));
    }

    _arrancar();
  }

  /// Abre el grupo de un aviso tocado, reutilizando el MISMO camino que ya
  /// usa la app para resolver un código y llegar a la pantalla de un
  /// grupo (`_resolverGrupoPorCodigo` + `_apilarMisGruposConGrupo`, más
  /// abajo, que también usa `irADondeToque`). Escribir aquí una
  /// navegación paralela dejaría dos formas de abrir un grupo por código
  /// que acabarían desincronizándose.
  ///
  /// Lo que NO hace, a propósito, es tocar `guardarInvitacion` /
  /// `borrarInvitacion` / `marcarInvitacionConsumida`: esa contabilidad es
  /// del camino de la invitación por URL (un enlace de un solo uso). Un
  /// aviso no es una invitación — la persona que lo recibe ya está en el
  /// grupo, es justo por eso que le llegó el aviso—, así que no hay nada
  /// que consumir. Pisar esas claves con `guardarInvitacion(codigo, '')`
  /// destruía cualquier invitación de verdad que estuviera esperando en
  /// disco (por ejemplo, un token de reemplazo guardado porque la red
  /// falló al resolverlo — ver el comentario de `_entrarAlGrupo` sobre por
  /// qué esa invitación se conserva a propósito).
  Future<void> _abrirGrupoDesdeAviso(NavigatorState navegador, String codigo) async {
    // Espera a que el primer `_arrancar()` termine su propia
    // reconstrucción de la pila antes de tocar la suya. Con tope: si la
    // red está de verdad colgada (no solo lenta) y `_arrancar()` no
    // llegara nunca a completar, es mejor aceptar la carrera residual que
    // dejar el toque del aviso sin efecto para siempre.
    await _primerArranqueListo.future
        .timeout(const Duration(seconds: 8), onTimeout: () {});
    if (usuarioActual == null) return; // sin sesión no hay grupo que abrir
    try {
      final resultado = await cargarMisGrupos();
      if (resultado == null) return;
      // `contexto` es el del propio Navigator raíz, no el de esta
      // pantalla: sigue válido aunque `_PantallaRaizState` ya esté
      // destruida, por la misma razón explicada en `initState`.
      final contexto = navegador.context;
      if (!contexto.mounted) return;

      PantallaRegistro? registro;
      try {
        registro = await _resolverGrupoPorCodigo(codigo, resultado.grupos);
      } catch (_) {
        return; // sin conexión: no hay nada sensato que hacer con el toque
      }
      if (registro == null) return; // el grupo ya no existe
      if (!contexto.mounted) return;

      _apilarMisGruposConGrupo(contexto, resultado, registro);
    } catch (_) {
      // Cualquier otro fallo (p.ej. `cargarMisGrupos` sin red) se ignora:
      // es un toque sobre un aviso, no hay nada mejor que hacer que
      // dejarlo sin efecto.
    }
  }

  /// Si la URL trae ?codigo=XXXX se guarda como invitación ANTES de
  /// decidir destino.
  ///
  /// SOLO web: `Uri.base` lee `window.location.href` de la pestaña, que en
  /// Android no existe — ahí el enlace llega por el Intent de arranque (app
  /// cerrada, ver `_capturarInvitacionDeLaUrlNativa`) o por el flujo de
  /// `app_links` (app ya abierta, ver `_alRecibirEnlaceNativoConAppAbierta`
  /// en `initState`). Las tres rutas terminan en el mismo sitio,
  /// `_guardarInvitacionValidada`, que es quien de verdad valida contra
  /// Firestore y escribe en disco — para que web y Android entiendan un
  /// código exactamente de la misma forma y no puedan divergir.
  Future<void> _capturarInvitacionDeLaUrl() async {
    if (!kIsWeb) return;
    final enlace = leerEnlaceInvitacion(Uri.base);
    if (enlace == null) return;
    await _guardarInvitacionValidada(enlace.codigo, enlace.reemplazo);
  }

  /// El mismo `?codigo=`, pero para Android con la app CERRADA: el enlace
  /// que arrancó el proceso. No hay `Uri.base` en Android, así que se pide
  /// con `getInitialLink()` del paquete `app_links`, que lee el Intent de
  /// arranque que captura el intent-filter ya puesto en el manifiesto.
  ///
  /// Se llama desde `_arrancar()`, en el mismo punto donde web llama a
  /// `_capturarInvitacionDeLaUrl`, porque tiene que quedar guardada ANTES
  /// de `decidirDestino` — si no, el arranque en frío mandaría a "Mis
  /// grupos" o "crear cuenta" sin la invitación, que es justo el fallo que
  /// esto viene a cerrar.
  Future<void> _capturarInvitacionDeLaUrlNativa() async {
    if (kIsWeb) return;
    Uri? uri;
    try {
      uri = await AppLinks().getInitialLink();
    } catch (_) {
      return; // sin Intent de arranque, o plugin no disponible: arranque normal
    }
    await _capturarEnlaceNativoSiCorresponde(uri);
  }

  /// Valida y guarda un enlace nativo — pero solo la PRIMERA vez que se ve
  /// ESTE `uri` exacto en lo que dure esta ejecución de la app.
  ///
  /// Hace falta porque el propio plugin `app_links` puede entregar el
  /// enlace de arranque DOS veces: una por `getInitialLink()` (llamado
  /// desde `_capturarInvitacionDeLaUrlNativa`) y otra por el primer evento
  /// de `uriLinkStream` (comprobado en el código nativo del plugin:
  /// `AppLinksPlugin.onListen`, en Android, reenvía el enlace de arranque
  /// por el stream si nadie lo había recibido aún por ahí). Sin esta
  /// guarda, un solo toque de invitación con la app recién arrancada
  /// podría meter a la persona dos veces en el mismo grupo — es el mismo
  /// problema, y la misma idea de solución, que `ultimoIdAbierto` en
  /// `alTocarAviso` de `push.dart`: allí se compara por `messageId`, aquí
  /// no hay un identificador propio del enlace y el URI entero hace ese
  /// papel.
  ///
  /// Efecto secundario a sabiendas: si la MISMA persona toca el MISMO
  /// enlace dos veces de verdad (no el plugin duplicando el aviso, sino
  /// dos toques reales) dentro de una misma ejecución de la app, el
  /// segundo toque no vuelve a validar ni a guardar nada — pero
  /// `_alRecibirEnlaceNativoConAppAbierta` sigue llevando a la persona a
  /// la app igualmente. Distinguir "el plugin duplicó el aviso" de "dos
  /// toques reales" no es posible con lo que entrega el plugin (los dos
  /// llegan como el mismo URI), y el coste de tratarlos igual es mínimo:
  /// como mucho, una lectura de Firestore que no hacía falta repetir.
  Future<void> _capturarEnlaceNativoSiCorresponde(Uri? uri) async {
    if (uri == null) return;
    if (uri == _ultimoEnlaceNativoProcesado) return;
    _ultimoEnlaceNativoProcesado = uri;
    final enlace = leerEnlaceInvitacion(uri);
    if (enlace == null) return;
    await _guardarInvitacionValidada(enlace.codigo, enlace.reemplazo);
  }

  /// Enlace nativo (Android) recibido con la app YA abierta: llega por
  /// `uriLinkStream`, suscrito una sola vez en `initState`.
  ///
  /// A diferencia de un aviso tocado (`_abrirGrupoDesdeAviso`, arriba),
  /// aquí SÍ hay contabilidad de invitación que hacer: un enlace es de un
  /// solo uso, no la notificación de un grupo al que la cuenta ya
  /// pertenece. Por eso, tras guardarlo, se reutiliza el mismo camino que
  /// sigue el arranque normal para consumir una invitación —
  /// `cargarMisGrupos` + `irADondeToque`, la misma pareja que usan
  /// `_entrarConLaSesionDeAuth` y `_trasVerificar`— en vez del camino
  /// directo que usa `_abrirGrupoDesdeAviso`.
  ///
  /// Sin esto, tocar una invitación con la app abierta la dejaría guardada
  /// en disco sin ningún efecto visible hasta el siguiente arranque —justo
  /// el hueco que pedía cerrarse: "si solo haces [la app cerrada], tocar
  /// una invitación con la app abierta no hará nada".
  Future<void> _alRecibirEnlaceNativoConAppAbierta(
      NavigatorState navegador, Uri uri) async {
    await _capturarEnlaceNativoSiCorresponde(uri);

    // Mismo motivo y mismo tope que `_abrirGrupoDesdeAviso`: si el enlace
    // llegara en el instante mismo del arranque, sin esperar competirían
    // dos `pushAndRemoveUntil` sobre el mismo Navigator.
    await _primerArranqueListo.future
        .timeout(const Duration(seconds: 8), onTimeout: () {});
    if (usuarioActual == null) return; // sin sesión: queda guardada para cuando la haya
    try {
      final resultado = await cargarMisGrupos();
      if (resultado == null) return;
      // `contexto` es el del propio Navigator raíz, no el de esta
      // pantalla: sigue válido aunque `_PantallaRaizState` ya esté
      // destruida, por la misma razón explicada en `initState`.
      final contexto = navegador.context;
      if (!contexto.mounted) return;

      // `irADondeToque` ya sabe leer la invitación de disco (la que
      // acaba de guardar `_capturarEnlaceNativoSiCorresponde`, si el
      // enlace traía una válida y no estaba ya consumida) y consumirla.
      // Si no hubiera ninguna —enlace sin código, o ya gastado— igual
      // deja a la persona en "Mis grupos", que es un sitio razonable
      // para un toque sobre un enlace de la app que no abrió nada.
      await irADondeToque(contexto, resultado);
    } catch (_) {
      // Sin conexión: se deja como estaba, sin navegar. Si
      // `_guardarInvitacionValidada` llegó a guardar la invitación, sigue
      // en disco y el siguiente arranque la retoma solo.
    }
  }

  /// Único punto que de verdad valida un código contra Firestore y lo
  /// guarda como invitación pendiente. La comparten los tres caminos que
  /// leen un enlace —web, Android con la app cerrada y Android con la app
  /// abierta— para que ninguno pueda divergir en cómo se valida un
  /// código.
  Future<void> _guardarInvitacionValidada(
      String codigo, String? reemplazo) async {
    // Esta guarda nació para web: la URL de la pestaña nunca cambia (es el
    // enlace compartido), así que sin ella cada recarga volvería a
    // capturar el mismo código y a meter a la persona en ese grupo para
    // siempre. En Android no hay recargas —el enlace llega como un suceso,
    // no como un estado que persiste— así que esa razón concreta no
    // aplica. Pero la guarda SÍ sigue haciendo falta ahí también, por otra
    // razón: un enlace de invitación es de un solo uso, y sin esto tocar
    // uno viejo que ya sirvió (un WhatsApp de hace semanas, reenviado, o
    // vuelto a abrir por curiosidad) gastaría una lectura de Firestore
    // para llegar siempre a la misma conclusión — o, si la cuenta hubiera
    // salido del grupo mientras tanto, podría parecer que ese enlace
    // gastado vuelve a dar acceso. Va ANTES de Firestore para no gastar
    // tampoco esa lectura. Con token de reemplazo se deja pasar
    // igualmente: es un enlace distinto y con otro propósito, así que "ya
    // consumido" no aplica.
    if (reemplazo == null && await invitacionYaConsumida(codigo)) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('grupos')
          .doc(codigo)
          .get()
          .timeout(const Duration(seconds: 6));
      if (!doc.exists) return;
      await guardarInvitacion(
          codigo, doc.data()!['nombreGrupo'] as String? ?? '', reemplazo);
    } catch (_) {
      // Sin conexión o código inválido: se sigue el flujo normal. La
      // próxima apertura con el mismo enlace volverá a intentarlo.
    }
  }

  Future<void> _arrancar() async {
    try {
      await _capturarInvitacionDeLaUrl();
      await _capturarInvitacionDeLaUrlNativa();
      final u = usuarioActual;
      final invitacion = await leerInvitacion();
      if (!mounted) return;

      switch (decidirDestino(
          haySesion: u != null, hayInvitacion: invitacion != null)) {
        case DestinoInicial.crearCuenta:
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => PantallaCrearCuenta(
                  alEntrar: irADondeToque,
                  nombreGrupoInvitacion: invitacion?.nombreGrupo),
            ),
          );
        // Los dos destinos con sesión se tratan igual a propósito: se
        // entra con la cuenta UNA sola vez y es `irADondeToque` quien
        // decide si además hay que apilar el grupo de la invitación. Así
        // el camino del QR hereda el mismo tratamiento de errores que el
        // normal, y hay un único sitio que construye la pila.
        case DestinoInicial.grupo:
        case DestinoInicial.misGrupos:
          await _entrarConLaSesionDeAuth(u!);
      }
    } finally {
      // Pase lo que pase (éxito, error puesto, `return` temprano por
      // `!mounted`), la primera reconstrucción de la pila ya terminó: a
      // partir de aquí es seguro que un aviso tocado toque la suya sin
      // pisarse con esta.
      if (!_primerArranqueListo.isCompleted) _primerArranqueListo.complete();
    }
  }

  /// La sesión de Auth persiste sola, pero puede haber dejado de valer:
  /// cuenta borrada, contraseña cambiada desde otro sitio, o simplemente
  /// no hay red. Sin manejo de error la app se queda en el indicador de
  /// carga para siempre, que es la peor pantalla posible.
  Future<void> _entrarConLaSesionDeAuth(User u) async {
    if (!u.emailVerified) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PantallaVerificarCorreo(alVerificar: _trasVerificar),
        ),
      );
      return;
    }
    final ResultadoAcceso? resultado;
    try {
      resultado = await cargarMisGrupos();
    } on FuncionError catch (e) {
      // ÚNICAS claves que justifican echar a alguien de su sesión: el
      // servidor ha dicho que esta identidad no sirve. Cualquier otra
      // cosa —sin red, servidor caído, clave desconocida— la conserva.
      if (e.clave == 'sesion_invalida') {
        await _olvidarSesionEIrACrearCuenta();
        return;
      }
      if (!mounted) return;
      setState(() => _errorArranque = e);
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorArranque = e);
      return;
    }
    if (!mounted) return;
    if (resultado == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PantallaCompletarPerfil(alCompletar: _trasVerificar),
        ),
      );
      return;
    }

    // Mismo bloque que `_trasVerificar` de abajo (deuda: son ya CUATRO
    // copias del patrón completo —las otras dos en `_trasVerificar` de
    // `pantalla_crear_cuenta.dart` y `pantalla_iniciar_sesion.dart`—,
    // aparte de la extracción parcial que ya hizo la Tarea 8 en
    // `oferta_avisos.dart`; unificarlas es un cambio aparte, para no
    // mezclarlo con el agujero que esto tapa). Quien entra por AQUÍ ya
    // tenía sesión iniciada y NUNCA pasa por `_trasVerificar` — sin esta
    // llamada, a toda cuenta ya existente no se le preguntaría jamás por
    // los avisos.
    await ofrecerAvisosSiHaceFalta(context);
    if (!mounted) return;

    await irADondeToque(context, resultado);
  }

  /// Tras verificar, se cargan los grupos y se sigue el camino normal —
  /// el mismo que sigue quien entra con una cuenta ya verificada. No hay
  /// `widget.alEntrar` aquí (esto es el portero, no una de las puertas):
  /// el destino lo decide `irADondeToque` directamente.
  Future<void> _trasVerificar(BuildContext context) async {
    final r = await cargarMisGrupos();
    if (!context.mounted) return;
    if (r == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PantallaCompletarPerfil(alCompletar: _trasVerificar),
        ),
      );
      return;
    }

    await ofrecerAvisosSiHaceFalta(context);
    if (!context.mounted) return;

    await irADondeToque(context, r);
  }

  Future<void> _olvidarSesionEIrACrearCuenta() async {
    await salir();
    final invitacion = await leerInvitacion();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaCrearCuenta(
            alEntrar: irADondeToque, nombreGrupoInvitacion: invitacion?.nombreGrupo),
      ),
    );
  }

  void _reintentar() {
    setState(() => _errorArranque = null);
    _arrancar();
  }

  String _mensajeDeError(Textos t) {
    final e = _errorArranque;
    if (e is FuncionError) {
      // `texto()` ya traduce 'sin_conexion', pero se deja explícito
      // porque es el caso que más se va a ver aquí.
      return e.clave == 'sin_conexion' ? t.errorSinConexion : e.texto(t);
    }
    return t.errorInesperado(e.toString());
  }

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    return Theme(
      data: temaGlass(colorNeutro),
      child: FondoNeutro(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: _errorArranque == null
              ? Center(child: CircularProgressIndicator(color: colorNeutro.shade700))
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: GlassCard(
                      color: colorNeutro,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _mensajeDeError(t),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.black87, fontSize: 16),
                          ),
                          const SizedBox(height: 20),
                          GlassButton(
                            color: colorNeutro.shade600,
                            icon: Icons.refresh,
                            label: t.reintentar,
                            onPressed: _reintentar,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Resuelve un código de grupo contra Firestore y arma la pantalla de
/// registro que le corresponde (con vínculo si la cuenta ya tiene plaza
/// en `grupos`, sin él si no). Es la pieza reutilizable de verdad —
/// "resolver un código y llegar a la pantalla del grupo"— que comparten
/// `_entrarAlGrupo` (la invitación por URL, que ADEMÁS lleva su propia
/// contabilidad de un solo uso alrededor de esta llamada) y
/// `_abrirGrupoDesdeAviso` en `_PantallaRaizState` (un aviso, que NO debe
/// tocar esa contabilidad: no es una invitación, la persona ya está en el
/// grupo).
///
/// NO toca `guardarInvitacion` / `borrarInvitacion` /
/// `marcarInvitacionConsumida` — eso es responsabilidad de quien la llama,
/// no de esta función. Lanza si falla la red (quien llama decide qué
/// hacer con eso); devuelve `null` si el grupo ya no existe.
Future<PantallaRegistro?> _resolverGrupoPorCodigo(
    String codigo, List<Map<String, dynamic>> grupos, {String? reemplazo}) async {
  final doc = await FirebaseFirestore.instance
      .collection('grupos')
      .doc(codigo)
      .get()
      .timeout(const Duration(seconds: 6));
  if (!doc.exists) return null;
  final data = doc.data()!;
  // Si la cuenta ya tiene vínculo con este grupo se le pasa; si no, null,
  // que es lo que hace que la pantalla ofrezca el formulario de alta.
  //
  // Con un bucle y no con `firstOrNull`: esa extensión vive en
  // `package:collection`, que este proyecto no importa, y añadir una
  // dependencia por una línea no compensa.
  Map<String, dynamic>? entrada;
  for (final g in grupos) {
    if (g['codigo'] == codigo) {
      entrada = g;
      break;
    }
  }
  return PantallaRegistro(
    codigo: codigo,
    ocasion: Ocasion.desdeId(data['ocasion'] as String),
    valorMinimo: data['valorMinimo'] as String? ?? '',
    nombreGrupo: data['nombreGrupo'] as String? ?? '',
    vinculo: entrada == null ? null : MiVinculo.desdeMapa(entrada),
    reemplazo: reemplazo,
  );
}

/// Resuelve el grupo de una invitación y la consume. Devuelve la pantalla
/// que hay que apilar, o `null` si no se pudo: entre validar el código y
/// usarlo pueden pasar minutos (los que tarda alguien en rellenar el
/// formulario de cuenta), y en ese rato el grupo puede haberse borrado o
/// la red puede haber fallado.
///
/// NO navega. Antes hacía `pushReplacement`, y eso dejaba la pantalla de
/// registro como única ruta de la pila cuando se llegaba tras el
/// registro: sin botón atrás, sin Mis grupos, sin cerrar sesión y sin
/// selector de idioma. Ahora apila `irADondeToque`, que es quien sabe qué
/// forma debe tener la pila entera.
Future<PantallaRegistro?> _entrarAlGrupo(
    InvitacionPendiente i, List<Map<String, dynamic>> grupos) async {
  final PantallaRegistro? registro;
  try {
    // `i.reemplazo` se lee aquí, no después de borrar: es una variable en
    // memoria (no del disco), así que da igual el orden para ella, pero
    // así queda junto al resto de datos de la invitación que también se
    // leen antes de tocar el almacén.
    registro = await _resolverGrupoPorCodigo(i.codigo, grupos, reemplazo: i.reemplazo);
  } catch (_) {
    // Sin conexión o error de Firestore: la invitación puede seguir
    // siendo válida, así que NO se borra ni se marca como consumida.
    // Hacerlo aquí sería perder una invitación buena por un problema
    // pasajero; la próxima apertura reintenta con el mismo código.
    return null;
  }

  if (registro == null) {
    // El grupo ya no existe: la invitación está muerta. Se borra y además
    // se marca el código como consumido, porque ese código no va a volver
    // a servir jamás —los códigos identifican al documento del grupo, que
    // ya no está— y sin la marca cada recarga de la pestaña gastaría otra
    // lectura de Firestore para llegar a la misma conclusión.
    await borrarInvitacion();
    await marcarInvitacionConsumida(i.codigo);
    return null;
  }

  // Se va a entrar de verdad: se borra la invitación y se marca el código
  // como gastado. Lo segundo es lo que impide que una recarga de la
  // pestaña —que vuelve a leer el mismo ?codigo= de la URL— meta otra vez
  // a esa persona en ese grupo.
  await borrarInvitacion();
  await marcarInvitacionConsumida(i.codigo);
  return registro;
}

/// Apila "Mis grupos" como única ruta y raíz de todo lo demás y, encima
/// —si hay uno—, el grupo ya resuelto. Sacada de `irADondeToque` para que
/// también la use `_abrirGrupoDesdeAviso`, que resuelve su grupo por otro
/// camino (directo, sin pasar por invitaciones) pero necesita llegar a la
/// MISMA forma de pila.
///
/// Nunca deja el registro solo: es lo que da botón atrás, y lo que hace
/// que los `popUntil((r) => r.isFirst)` de la pantalla de grupo (cuando el
/// organizador lo elimina) aterricen en Mis grupos en vez de en un sitio
/// absurdo.
void _apilarMisGruposConGrupo(
    BuildContext context, ResultadoAcceso resultado, PantallaRegistro? registro) {
  // Se coge el Navigator antes de vaciar la pila: el context de quien
  // llama deja de servir en cuanto su ruta desaparece, pero el
  // NavigatorState sigue siendo el mismo.
  final navegador = Navigator.of(context);

  navegador.pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (_) =>
          PantallaMisGrupos(nombre: resultado.nombre, grupos: resultado.grupos),
    ),
    (r) => false,
  );

  // Va encima con push —no replace— para que haya vuelta atrás. Si no se
  // pudo resolver (grupo borrado, sin red) se queda en Mis grupos, que es
  // un sitio del que sí se puede salir.
  if (registro != null) {
    navegador.push(MaterialPageRoute(builder: (_) => registro));
  }
}

/// A dónde se va tras crear cuenta, iniciar sesión o validar la sesión
/// guardada. Lo usan las pantallas de cuenta y el portero para no
/// duplicar la decisión.
Future<void> irADondeToque(BuildContext context, ResultadoAcceso resultado) async {
  final invitacion = await leerInvitacion();
  if (!context.mounted) return;

  // El grupo se resuelve ANTES de tocar la pila. Al revés no funciona:
  // `pushAndRemoveUntil` desmonta a quien llama, y con el context muerto
  // ya no se podría apilar el registro encima.
  final registro =
      invitacion == null ? null : await _entrarAlGrupo(invitacion, resultado.grupos);
  if (!context.mounted) return;

  _apilarMisGruposConGrupo(context, resultado, registro);
}
