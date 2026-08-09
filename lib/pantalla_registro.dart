import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'avatar.dart';
import 'funciones.dart';
import 'glass.dart';
import 'hoja_identidad.dart';
import 'identidad_local.dart';
import 'l10n/app_localizations.dart';
import 'ocasion.dart';
import 'pantalla_chat.dart';
import 'pantalla_editar_grupo.dart';
import 'pantalla_login.dart';
import 'sesion.dart';
import 'tematica.dart';

/// Los datos del grupo que se muestran en pantalla. Llegan primero como
/// semilla desde quien nos navegó aquí (para pintar al instante, sin
/// spinner) y después se refrescan solos desde Firestore, así los cambios
/// del organizador aparecen en vivo para todo el grupo.
class InfoGrupo {
  final Ocasion ocasion;
  final String nombreGrupo;
  final String valorMinimo;
  final Tematica tematica;
  final String reglas;

  const InfoGrupo({
    required this.ocasion,
    required this.nombreGrupo,
    required this.valorMinimo,
    required this.tematica,
    required this.reglas,
  });

  factory InfoGrupo.desdeDoc(Map<String, dynamic> d) => InfoGrupo(
        ocasion: Ocasion.desdeId(d['ocasion'] as String? ?? ''),
        nombreGrupo: d['nombreGrupo'] as String? ?? '',
        valorMinimo: d['valorMinimo'] as String? ?? '',
        tematica: Tematica.desdeId(d['tematica'] as String?),
        reglas: d['reglas'] as String? ?? '',
      );

  MaterialColor get color => tematica.colorDe(ocasion);
}

class PantallaRegistro extends StatefulWidget {
  final String codigo;
  final Ocasion ocasion;
  final String valorMinimo;
  final String nombreGrupo;

  const PantallaRegistro({
    super.key,
    required this.codigo,
    required this.ocasion,
    required this.valorMinimo,
    this.nombreGrupo = '',
  });

  @override
  State<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends State<PantallaRegistro> {
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _deseosController = TextEditingController();

  late final DocumentReference<Map<String, dynamic>> _grupoRef =
      FirebaseFirestore.instance.collection('grupos').doc(widget.codigo);

  late final CollectionReference participantesRef = _grupoRef.collection('participantes');

  /// Un solo stream para los dos usos: pintar la lista y vigilar que la
  /// identidad guardada siga siendo válida. `snapshots()` devuelve un
  /// stream de difusión, así que escucharlo dos veces no abre dos
  /// suscripciones contra Firestore. Si cada uno pidiera el suyo, se
  /// pagarían las lecturas por duplicado.
  late final Stream<QuerySnapshot> _streamParticipantes =
      participantesRef.orderBy('fecha', descending: true).snapshots();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _suscripcionGrupo;
  StreamSubscription<QuerySnapshot>? _suscripcionParticipantes;

  /// Última lista recibida, para poder revisar la identidad en cuanto
  /// termine de leerse del disco aunque el stream ya hubiera emitido.
  List<QueryDocumentSnapshot>? _ultimosParticipantes;

  /// Evita lanzar varias comprobaciones contra el servidor a la vez.
  bool _comprobandoIdentidad = false;

  /// Semilla desde el constructor: la pantalla se pinta completa desde el
  /// primer frame y nunca muestra un spinner de carga inicial.
  late InfoGrupo _info = InfoGrupo(
    ocasion: widget.ocasion,
    nombreGrupo: widget.nombreGrupo,
    valorMinimo: widget.valorMinimo,
    tematica: Tematica.ninguna,
    reglas: '',
  );

  /// Modo organizador: se desbloquea UNA vez con el PIN maestro y desde
  /// ahí todos los controles de creador quedan a la mano, en vez de que
  /// cada acción vuelva a pedir el mismo PIN.
  bool _esOrganizador = false;
  String _pinMaestro = '';

  bool _reglasAbiertas = false;

  /// Imagen elegida para el registro, todavía sin subir. Viaja junto con
  /// el resto del formulario en una sola llamada.
  String? _avatarBase64;

  /// Quién eres TÚ en este grupo, si ya te registraste. Mientras sea
  /// null se ofrece el formulario de alta; en cuanto hay identidad, el
  /// formulario desaparece.
  ///
  /// Sin esto la pantalla le ofrecía darse de alta a todo el mundo
  /// siempre, y quien entrara desde otro dispositivo se registraba dos
  /// veces y salía duplicado en el sorteo.
  IdentidadGrupo? _yo;
  bool _identidadCargada = false;

  @override
  void initState() {
    super.initState();
    _cargarIdentidad();
    _suscripcionGrupo = _grupoRef.snapshots().listen((snap) {
      if (!mounted) return;
      // El grupo dejó de existir: su organizador lo eliminó mientras
      // alguien lo tenía abierto.
      if (!snap.exists) {
        _avisar(Textos.of(context).grupoEliminadoAviso);
        Navigator.of(context).popUntil((r) => r.isFirst);
        return;
      }
      setState(() => _info = InfoGrupo.desdeDoc(snap.data()!));
    }, onError: (_) {
      // Sin conexión: nos quedamos con la semilla, la pantalla sigue viva.
    });
    // La revisión de identidad va aquí y NO dentro de build(): antes se
    // llamaba en cada reconstrucción —al abrirse el teclado, al escribir
    // una letra— y ahora consulta al servidor. Así corre solo cuando la
    // lista cambia de verdad.
    _suscripcionParticipantes = _streamParticipantes.listen((snap) {
      _ultimosParticipantes = snap.docs;
      _revisarIdentidadContraLista(snap.docs);
    }, onError: (_) {
      // Sin conexión no se revisa nada: se conserva lo guardado.
    });
  }

  @override
  void dispose() {
    _suscripcionGrupo?.cancel();
    _suscripcionParticipantes?.cancel();
    _nombreController.dispose();
    _pinController.dispose();
    _deseosController.dispose();
    super.dispose();
  }

  MaterialColor get _color => _info.color;

  Future<void> _cargarIdentidad() async {
    final guardada = await leerIdentidad(widget.codigo);
    if (!mounted) return;
    setState(() {
      _yo = guardada;
      _identidadCargada = true;
    });
    // El disco y el stream corren en paralelo: si la lista llegó primero,
    // aquella emisión se revisó sin identidad cargada. Se repasa ahora.
    final ultimos = _ultimosParticipantes;
    if (ultimos != null) _revisarIdentidadContraLista(ultimos);
  }

  /// Si el organizador te sacó del grupo, la identidad guardada apunta a
  /// alguien que ya no existe. Se descarta para no dejar la pantalla
  /// bloqueada sin formulario ni participante.
  ///
  /// La decisión NO puede tomarse desde la lista: va por detrás de las
  /// altas recién hechas. Al crear un grupo y registrarte el primero, la
  /// lista que la app tiene en ese instante está VACÍA, así que no
  /// encontrarse a uno mismo no prueba nada — y se borraba la identidad
  /// de quien acababa de entrar. El síntoma era desconcertante: tu
  /// nombre aparecía en la lista (el servidor te tenía) pero el
  /// formulario de alta seguía delante (tu dispositivo ya no sabía cuál
  /// de esos participantes eras). Y no se recuperaba ni recargando,
  /// porque olvidarIdentidad borra de shared_preferences.
  ///
  /// Por eso, cuando faltas de la lista, se le pregunta al servidor por
  /// tu documento concreto. Solo si de verdad no existe se olvida.
  Future<void> _revisarIdentidadContraLista(List<QueryDocumentSnapshot> docs) async {
    final yo = _yo;
    if (yo == null || _comprobandoIdentidad) return;
    if (docs.any((d) => d.id == yo.participanteId)) return;

    _comprobandoIdentidad = true;
    try {
      final doc = await participantesRef
          .doc(yo.participanteId)
          .get(const GetOptions(source: Source.server));
      // Sigue dentro: la lista simplemente iba atrasada.
      if (doc.exists) return;
      await olvidarIdentidad(widget.codigo);
      // Puede haber cambiado mientras se preguntaba (otro registro, o
      // "dejar de ser yo"): solo se borra si sigue siendo la misma.
      if (!mounted || _yo?.participanteId != yo.participanteId) return;
      setState(() => _yo = null);
    } catch (_) {
      // Sin red no se decide nada y se conserva la identidad.
      // Equivocarse hacia "sigues dentro" se corrige en la siguiente
      // emisión; borrar la nota no tiene vuelta atrás.
    } finally {
      _comprobandoIdentidad = false;
    }
  }

  Future<void> _decirQuienSoy() async {
    final identidad = await HojaIdentidad.mostrar(context, widget.codigo, _color);
    if (identidad == null || !mounted) return;
    await guardarIdentidad(widget.codigo, identidad);
    if (!mounted) return;
    setState(() => _yo = identidad);
  }

  Future<void> _dejarDeSerYo() async {
    await olvidarIdentidad(widget.codigo);
    if (!mounted) return;
    setState(() => _yo = null);
  }

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  void _avisarError(Object e) {
    if (!mounted) return;
    final t = Textos.of(context);
    _avisar('⚠️ ${e is FuncionError ? e.texto(t) : t.errorInesperado(e.toString())}');
  }

  // --- Registro de participantes --------------------------------------

  Future<void> _agregar() async {
    final t = Textos.of(context);
    final nombreLimpio = _nombreController.text.trim();
    final pinLimpio = _pinController.text.trim();
    final deseosLimpios = _deseosController.text.trim();

    if (nombreLimpio.isEmpty || pinLimpio.isEmpty) {
      _avisar('⚠️ ${_info.tematica.usaPersonajes ? t.registroFaltaPersonaje : t.registroFaltaNombre}');
      return;
    }

    try {
      final sesion = await leerSesion();
      final creado = await llamarFuncion('agregarParticipante', {
        'codigo': widget.codigo,
        'nombre': nombreLimpio,
        'pin': pinLimpio,
        'deseos': deseosLimpios,
        if (_avatarBase64 != null) 'avatarBase64': _avatarBase64,
        if (sesion != null) 'nickname': sesion.nickname,
        if (sesion != null) 'password': sesion.password,
      });
      // A partir de aquí esta persona YA está dentro: se recuerda para
      // que no le vuelva a aparecer el formulario de alta ni se registre
      // dos veces.
      final identidad = IdentidadGrupo(creado['id'] as String, pinLimpio);
      await guardarIdentidad(widget.codigo, identidad);
      _nombreController.clear();
      _pinController.clear();
      _deseosController.clear();
      if (!mounted) return;
      setState(() {
        _avatarBase64 = null;
        _yo = identidad;
      });
      FocusScope.of(context).unfocus();
    } catch (e) {
      _avisarError(e);
    }
  }

  Future<void> _elegirAvatar() async {
    try {
      final base64 = await elegirAvatarBase64();
      if (base64 == null || !mounted) return;
      setState(() => _avatarBase64 = base64);
    } catch (e) {
      if (!mounted) return;
      _avisar('⚠️ ${Textos.of(context).avatarNoGaleria(e.toString())}');
    }
  }

  // --- Modo organizador -----------------------------------------------

  Future<void> _desbloquearOrganizador() async {
    final t = Textos.of(context);
    final pinController = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        icon: Icon(Icons.shield_outlined, color: _color.shade700, size: 36),
        title: Text(t.organizadorEntrar),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.organizadorPinTexto, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              autofocus: true,
              textAlign: TextAlign.center,
              decoration: InputDecoration(labelText: t.organizadorPinCampo),
              onSubmitted: (v) => Navigator.pop(c, v.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t.cancelar)),
          FilledButton(
            onPressed: () => Navigator.pop(c, pinController.text.trim()),
            child: Text(t.entrar),
          ),
        ],
      ),
    );
    if (pin == null || pin.isEmpty) return;

    try {
      await llamarFuncion('verificarOrganizador', {
        'codigo': widget.codigo,
        'pinMaestro': pin,
      });
      if (!mounted) return;
      setState(() {
        _esOrganizador = true;
        _pinMaestro = pin;
      });
      _avisar('✅ ${t.organizadorActivado}');
    } catch (e) {
      _avisarError(e);
    }
  }

  void _salirDeOrganizador() {
    final t = Textos.of(context);
    setState(() {
      _esOrganizador = false;
      _pinMaestro = '';
    });
    _avisar(t.organizadorDesactivado);
  }

  Future<void> _abrirEdicionGrupo() async {
    final t = Textos.of(context);
    final resultado = await Navigator.push<ResultadoEdicion>(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaEditarGrupo(
          codigo: widget.codigo,
          pinMaestro: _pinMaestro,
          ocasion: _info.ocasion,
          nombreGrupo: _info.nombreGrupo,
          valorMinimo: _info.valorMinimo,
          tematica: _info.tematica,
          reglas: _info.reglas,
        ),
      ),
    );
    if (!mounted) return;
    if (resultado == ResultadoEdicion.eliminado) {
      // El stream del grupo ya no va a emitir nada útil: salimos al inicio.
      Navigator.of(context).popUntil((r) => r.isFirst);
      _avisar(t.editarEliminado);
    } else if (resultado == ResultadoEdicion.guardado) {
      _avisar('✅ ${t.editarGuardado}');
    }
  }

  Future<void> _sortear() async {
    final t = Textos.of(context);
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: Icon(Icons.casino_outlined, color: _color.shade700, size: 36),
        title: Text(t.sorteoTitulo),
        content: Text(t.sorteoTexto),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t.cancelar)),
          FilledButton(
              onPressed: () => Navigator.pop(c, true), child: Text(t.sorteoConfirmar)),
        ],
      ),
    );
    if (confirmado != true) return;

    try {
      await llamarFuncion('ejecutarSorteo', {
        'codigo': widget.codigo,
        'pinMaestro': _pinMaestro,
      });
      _avisar('🎲 ${t.sorteoListo}');
    } catch (e) {
      _avisarError(e);
    }
  }

  // --- Compartir -------------------------------------------------------

  String get _urlUnirse => 'https://santa-secreto-860c3.web.app/?codigo=${widget.codigo}';

  void _compartir() {
    final t = Textos.of(context);
    final nombre =
        _info.nombreGrupo.isNotEmpty ? _info.nombreGrupo : _info.ocasion.titulo(t);
    SharePlus.instance.share(ShareParams(
      text: t.grupoCompartirTexto(nombre, _info.ocasion.emoji, widget.codigo, _urlUnirse),
    ));
  }

  void _mostrarQR() {
    final t = Textos.of(context);
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t.grupoQRTitulo),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(data: _urlUnirse, size: 220),
            const SizedBox(height: 12),
            Text(widget.codigo,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t.cerrar)),
        ],
      ),
    );
  }

  // --- Acciones sobre un participante ----------------------------------

  Future<void> _borrarComoOrganizador(String participanteId, String nombre) async {
    final t = Textos.of(context);
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t.organizadorSacarPregunta(nombre)),
        content: Text(t.organizadorSacarTexto),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t.cancelar)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(c, true),
            child: Text(t.organizadorSacarBoton),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    try {
      await llamarFuncion('borrarParticipante', {
        'codigo': widget.codigo,
        'participanteId': participanteId,
        'pin': _pinMaestro,
      });
    } catch (e) {
      _avisarError(e);
    }
  }

  /// Para quien NO es organizador: puede sacarse a sí mismo con su PIN.
  Future<void> _borrarConPinPropio(String participanteId) async {
    final t = Textos.of(context);
    final pinController = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t.registroSalirGrupo),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(labelText: t.registroTuPin),
          onSubmitted: (v) => Navigator.pop(c, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t.cancelar)),
          FilledButton(
            onPressed: () => Navigator.pop(c, pinController.text.trim()),
            child: Text(t.confirmar),
          ),
        ],
      ),
    );
    if (pin == null || pin.isEmpty) return;

    try {
      await llamarFuncion('borrarParticipante', {
        'codigo': widget.codigo,
        'participanteId': participanteId,
        'pin': pin,
      });
    } catch (e) {
      _avisarError(e);
    }
  }

  Future<void> _editarNombre(String participanteId, String nombreActual) async {
    final t = Textos.of(context);
    final usaPersonajes = _info.tematica.usaPersonajes;
    final controller = TextEditingController(text: nombreActual);
    final nuevo = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
            usaPersonajes ? t.organizadorCorregirPersonaje : t.organizadorCorregirNombre),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: _info.tematica.etiquetaNombre(t)),
          onSubmitted: (v) => Navigator.pop(c, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t.cancelar)),
          FilledButton(
            onPressed: () => Navigator.pop(c, controller.text.trim()),
            child: Text(t.guardar),
          ),
        ],
      ),
    );
    if (nuevo == null || nuevo.isEmpty || nuevo == nombreActual) return;

    try {
      await llamarFuncion('editarParticipante', {
        'codigo': widget.codigo,
        'participanteId': participanteId,
        'nuevoNombre': nuevo,
        'pinMaestro': _pinMaestro,
      });
    } catch (e) {
      _avisarError(e);
    }
  }

  // --- Interfaz ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    return Theme(
      data: temaGlass(_color),
      child: FondoTematico(
        tematica: _info.tematica,
        ocasion: _info.ocasion,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          // El teclado SÍ encoge el Scaffold (comportamiento por defecto).
          //
          // Aquí estuvo `resizeToAvoidBottomInset: false` con un relleno
          // inferior del alto del teclado puesto a mano. Se hizo para
          // esquivar las franjas blancas que dejaba el motor en web al
          // cerrarse el teclado — que resultaron ser flutter#175074, una
          // regresión del engine, corregida al subir a 3.38.10.
          //
          // Ese apaño tenía un efecto secundario peor que el problema:
          // el relleno daba SITIO para subir, pero nada subía. Flutter
          // desplaza el campo enfocado comparándolo contra el viewport, y
          // con el Scaffold sin encoger el viewport seguía midiendo la
          // pantalla entera. Un campo a 600px "ya era visible" aunque el
          // teclado lo tapara desde los 344. Resultado: escribías a
          // ciegas.
          //
          // Al dejar que el Scaffold encoja, el viewport mide lo que de
          // verdad se ve y el desplazamiento automático funciona solo.
          // NO volver a poner el relleno manual: contaría el teclado dos
          // veces y dejaría un hueco enorme abajo.
          appBar: GlassAppBar(
            color: _color,
            title: Text(_info.nombreGrupo.isNotEmpty
                ? '${_info.ocasion.emoji} ${_info.nombreGrupo}'
                : '${_info.ocasion.emoji} ${_info.ocasion.titulo(t)}'),
            actions: [
              if (_esOrganizador) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: t.organizadorEditarGrupo,
                  onPressed: _abrirEdicionGrupo,
                ),
                IconButton(
                  icon: const Icon(Icons.lock_open),
                  tooltip: t.organizadorSalir,
                  onPressed: _salirDeOrganizador,
                ),
              ] else
                IconButton(
                  icon: const Icon(Icons.shield_outlined),
                  tooltip: t.organizadorEntrar,
                  onPressed: _desbloquearOrganizador,
                ),
            ],
          ),
          // Todo el cuerpo scrollea en una sola lista. Antes era una
          // columna con la lista en Expanded y el resto de alto fijo: al
          // crecer el formulario (el selector de avatar), en un celular
          // dejaba de caber y se desbordaba por abajo.
          body: SafeArea(
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _tarjetaCabecera(t),
                ),
                if (_info.reglas.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: _tarjetaReglas(t),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  // El formulario de alta solo aparece si NO estás dentro.
                  // Mientras se lee la identidad guardada no se muestra
                  // nada: enseñarlo y quitarlo medio segundo después es
                  // peor que esperar ese instante.
                  child: !_identidadCargada
                      ? const SizedBox.shrink()
                      : (_yo == null ? _formularioRegistro(t) : _tarjetaYaDentro(t)),
                ),
                _listaParticipantes(t),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      if (_esOrganizador) ...[
                        GlassButton(
                          color: Colors.orange.shade800,
                          onPressed: _sortear,
                          icon: Icons.casino,
                          label: t.sorteoBoton,
                        ),
                        const SizedBox(height: 10),
                      ],
                      GlassOutlineButton(
                        color: _color,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (c) => PantallaLogin(
                              codigo: widget.codigo,
                              ocasion: _info.ocasion,
                              tematica: _info.tematica,
                            ),
                          ),
                        ),
                        icon: Icons.visibility,
                        label: t.registroVerAmigo,
                      ),
                      const SizedBox(height: 10),
                      GlassOutlineButton(
                        color: _color,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (c) => PantallaChat(
                              codigo: widget.codigo,
                              ocasion: _info.ocasion,
                              tematica: _info.tematica,
                              esOrganizador: _esOrganizador,
                              pinMaestro: _pinMaestro,
                            ),
                          ),
                        ),
                        icon: Icons.forum_outlined,
                        label: t.chatAbrir,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tarjetaCabecera(Textos t) {
    return GlassCard(
      color: _color,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      radius: 16,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.key, color: _color.shade800, size: 16),
            const SizedBox(width: 4),
            Text(t.grupoCodigo(widget.codigo),
                style: TextStyle(color: _color.shade900, fontWeight: FontWeight.bold)),
            IconButton(
              icon: Icon(Icons.share, color: _color.shade800, size: 20),
              tooltip: t.grupoCompartir,
              onPressed: _compartir,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.only(left: 8),
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: Icon(Icons.qr_code, color: _color.shade800, size: 20),
              tooltip: t.grupoQR,
              onPressed: _mostrarQR,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.only(left: 4),
              visualDensity: VisualDensity.compact,
            ),
          ]),
          if (_info.valorMinimo.isNotEmpty)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.attach_money, color: _color.shade800, size: 16),
              Text(t.grupoMinimo(_info.valorMinimo),
                  style: TextStyle(color: _color.shade900, fontWeight: FontWeight.bold)),
            ]),
          if (_info.tematica.usaPersonajes)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_info.tematica.icono, color: _color.shade800, size: 16),
              const SizedBox(width: 4),
              Text(_info.tematica.titulo(t),
                  style: TextStyle(color: _color.shade900, fontWeight: FontWeight.bold)),
            ]),
        ],
      ),
    );
  }

  /// Las reglas las ve todo el grupo. Arrancan plegadas para no empujar el
  /// formulario fuera de pantalla en celulares.
  Widget _tarjetaReglas(Textos t) {
    return GlassCard(
      color: _color,
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 12),
          initiallyExpanded: _reglasAbiertas,
          onExpansionChanged: (v) => _reglasAbiertas = v,
          leading: Icon(Icons.rule, color: _color.shade800, size: 20),
          iconColor: _color.shade800,
          collapsedIconColor: _color.shade800,
          title: Text(t.grupoReglas,
              style: TextStyle(
                  color: _color.shade900, fontWeight: FontWeight.bold, fontSize: 15)),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(_info.reglas,
                  style: const TextStyle(color: Colors.black87, height: 1.5, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  /// Lo que ve quien YA está dentro, en el sitio donde antes salía el
  /// formulario de alta.
  Widget _tarjetaYaDentro(Textos t) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: participantesRef
          .doc(_yo!.participanteId)
          .snapshots()
          .cast<DocumentSnapshot<Map<String, dynamic>>>(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final nombre = data?['nombre'] as String? ?? '';
        return GlassCard(
          color: _color,
          child: Column(
            children: [
              Row(
                children: [
                  AvatarParticipante(
                      url: data?['avatarUrl'] as String?, color: _color, radio: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.grupoYaDentro(nombre),
                            style: TextStyle(
                                fontWeight: FontWeight.bold, color: _color.shade900)),
                        const SizedBox(height: 2),
                        Text(t.grupoYaDentroAyuda,
                            style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _dejarDeSerYo,
                  child: Text(t.grupoNoEresTu,
                      style: TextStyle(color: _color.shade700, fontSize: 12)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _formularioRegistro(Textos t) {
    final tematica = _info.tematica;
    return GlassCard(
      color: _color,
      child: Column(
        children: [
          Text(tematica.usaPersonajes ? t.registroTituloPersonaje : t.registroTituloNormal,
              style: tituloGlass(_color)),
          const SizedBox(height: 12),
          SelectorAvatar(
            base64: _avatarBase64,
            etiqueta: tematica.etiquetaImagen(t),
            color: _color,
            onElegir: _elegirAvatar,
            onQuitar: () => setState(() => _avatarBase64 = null),
          ),
          const SizedBox(height: 12),
          GlassTextField(
            color: _color,
            controller: _nombreController,
            labelText: tematica.etiquetaNombre(t),
            hintText: tematica.pistaNombre(t),
            icon: tematica.usaPersonajes ? Icons.theater_comedy_outlined : Icons.person,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 10),
          GlassTextField(
            color: _color,
            controller: _deseosController,
            labelText: t.registroDeseos,
            // Con personajes nadie sabe a quién le regala: la lista de
            // deseos deja de ser un adorno y pasa a ser la única pista.
            helperText: tematica.usaPersonajes
                ? t.registroDeseosAyudaPersonaje
                : t.registroDeseosAyudaNormal,
            icon: Icons.card_giftcard,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 10),
          GlassTextField(
            color: _color,
            controller: _pinController,
            labelText: t.registroPin,
            helperText: t.registroPinAyuda,
            icon: Icons.lock,
            keyboardType: TextInputType.number,
            obscureText: true,
          ),
          const SizedBox(height: 12),
          GlassButton(
            color: Colors.green.shade700,
            onPressed: _agregar,
            icon: Icons.save,
            label: t.registroBoton,
          ),
          // Salida para quien ya se dio de alta en otro dispositivo o
          // limpió el navegador. Sin esto se registraría otra vez y
          // saldría duplicado en el sorteo.
          TextButton.icon(
            onPressed: _decirQuienSoy,
            icon: Icon(Icons.how_to_reg_outlined, size: 18, color: _color.shade700),
            label: Text(t.grupoYaEstoyDentro,
                textAlign: TextAlign.center,
                style: TextStyle(color: _color.shade700, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _listaParticipantes(Textos t) {
    final colorTextoSuelto = _info.tematica.fondoOscuro ? Colors.white70 : Colors.black54;
    return StreamBuilder<QuerySnapshot>(
      // El mismo stream que vigila la identidad en initState. La revisión
      // vive allí: build() solo pinta, no decide ni escribe.
      stream: _streamParticipantes,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(color: _color.shade700)),
          );
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                _info.tematica.usaPersonajes ? t.registroVacioPersonaje : t.registroVacioNormal,
                textAlign: TextAlign.center,
                style: TextStyle(color: colorTextoSuelto),
              ),
            ),
          );
        }
        // Va dentro de la lista exterior, así que no scrollea por su
        // cuenta: se deja medir por su contenido.
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final id = docs[index].id;
            final nombre = data['nombre'] as String? ?? '';
            final yaTieneAmigo = data['tieneAmigo'] == true;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                color: _color,
                radius: 16,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: AvatarParticipante(
                    url: data['avatarUrl'] as String?,
                    color: _color,
                    yaTieneAmigo: yaTieneAmigo,
                  ),
                  title: Text(
                      id == _yo?.participanteId ? '$nombre (${t.grupoTuEtiqueta})' : nombre,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.black87)),
                  subtitle: yaTieneAmigo
                      ? Text(t.registroYaTieneAmigo,
                          style: const TextStyle(fontSize: 12, color: Colors.black54))
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _esOrganizador
                        ? [
                            IconButton(
                              icon: Icon(Icons.edit_outlined, color: _color.shade700),
                              tooltip: t.organizadorCorregirNombre,
                              onPressed: () => _editarNombre(id, nombre),
                            ),
                            IconButton(
                              icon: Icon(Icons.person_remove_outlined,
                                  color: Colors.red.shade700),
                              tooltip: t.organizadorSacar,
                              onPressed: () => _borrarComoOrganizador(id, nombre),
                            ),
                          ]
                        : [
                            IconButton(
                              icon: Icon(Icons.logout, color: _color.shade700),
                              tooltip: t.registroSalirGrupo,
                              onPressed: () => _borrarConPinPropio(id),
                            ),
                          ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
