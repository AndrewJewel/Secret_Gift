import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'acceso_cuenta.dart';
import 'condiciones.dart';
import 'funciones.dart';
import 'glass.dart';
import 'grupo_a_la_vista.dart';
import 'l10n/app_localizations.dart';
import 'marca.dart';
import 'mascara.dart';
import 'mi_vinculo.dart';
import 'ocasion.dart';
import 'tematica.dart';

/// Chat grupal anónimo.
///
/// Cada persona aparece como una máscara asignada al azar por el
/// servidor, independiente del personaje que haya elegido en un grupo
/// temático (la gente le cuenta su personaje a sus amigos; la máscara
/// no la sabe nadie). El mensaje que llega del servidor solo trae el
/// número de máscara: aquí no hay forma de saber quién escribió qué.
class PantallaChat extends StatefulWidget {
  final String codigo;
  final Ocasion ocasion;
  final Tematica tematica;
  final Color? colorPersonal;

  /// Tu vínculo con el grupo: dice si eres organizador (para moderar) y
  /// qué participante eres (para resaltar tus mensajes).
  final MiVinculo? vinculo;

  const PantallaChat({
    super.key,
    required this.codigo,
    required this.ocasion,
    required this.tematica,
    this.colorPersonal,
    this.vinculo,
  });

  @override
  State<PantallaChat> createState() => _PantallaChatState();
}

class _PantallaChatState extends State<PantallaChat> with ConGrupoALaVista<PantallaChat> {
  final TextEditingController _mensajeController = TextEditingController();
  final ScrollController _scroll = ScrollController();

  int? _miMascara;
  bool _enviando = false;

  /// Máscaras que esta persona bloqueó en este grupo, como "mascara:repeticion".
  /// Sus mensajes no se pintan; solo ella lo sabe.
  Set<String> _bloqueadas = {};

  late final Query<Map<String, dynamic>> _chatRef = FirebaseFirestore.instance
      .collection('grupos')
      .doc(widget.codigo)
      .collection('chat')
      .orderBy('fecha', descending: true)
      .limit(200);

  MaterialColor get _color => widget.tematica.colorDe(widget.ocasion, widget.colorPersonal);

  // Mientras esta pantalla esté a la vista no se enseñan avisos de
  // mensajes de ESTE grupo: ya los estás leyendo. El ciclo completo
  // —cuándo se declara y cuándo se retira, incluida la salida "tapada por
  // otra pantalla sin destruirse"— vive en el mixin `ConGrupoALaVista`
  // (ver `grupo_a_la_vista.dart`), que también se encarga de `initState`,
  // `didChangeDependencies` y `dispose`.
  @override
  String get codigoDeGrupoALaVista => widget.codigo;

  @override
  void initState() {
    super.initState();
    _cargarMiMascara();
  }

  @override
  void dispose() {
    _mensajeController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _cargarMiMascara() async {
    if (widget.vinculo?.estoyDentro != true) return;
    try {
      final datos = await llamarFuncion('miMascara', {'codigo': widget.codigo});
      if (!mounted) return;
      setState(() {
        _miMascara = datos['mascara'] as int?;
        _bloqueadas = {...((datos['bloqueadas'] as List?) ?? const []).cast<String>()};
      });
    } catch (_) {
      // Sin máscara solo se pierde el resaltado de los propios mensajes;
      // leer el chat sigue funcionando.
    }
  }

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  // --- Enviar -----------------------------------------------------------

  Future<void> _enviar() async {
    final texto = _mensajeController.text.trim();
    if (texto.isEmpty || _enviando) return;

    setState(() => _enviando = true);
    try {
      final datos = await llamarFuncion('enviarMensaje', {'codigo': widget.codigo, 'texto': texto});
      _mensajeController.clear();
      if (!mounted) return;
      setState(() => _miMascara = datos['mascara'] as int?);
      // La lista va invertida, así que lo más nuevo está en el offset 0.
      if (_scroll.hasClients) {
        _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    } catch (e) {
      if (!mounted) return;
      final t = Textos.of(context);
      // Cuentas de antes de las condiciones: se aceptan aquí mismo y se
      // reintenta. Google Play exige aceptarlas antes de publicar.
      if (e is FuncionError && e.clave == 'condiciones_sin_aceptar') {
        final aceptado = await DialogoCondiciones.mostrar(
          context,
          salir: () async {
            await salir();
            if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
          },
        );
        if (aceptado && mounted) {
          setState(() => _enviando = false);
          return _enviar();
        }
        return;
      }
      _avisar(e is FuncionError ? e.texto(t) : t.errorInesperado(e.toString()));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  // --- Denunciar y bloquear ---------------------------------------------

  /// Menú de un mensaje ajeno (pulsación larga).
  Future<void> _menuMensaje(String mensajeId, int mascara, int repeticion) async {
    final t = Textos.of(context);
    final eleccion = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(t.chatDenunciar),
              onTap: () => Navigator.pop(c, 'denunciar'),
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: Text(t.chatBloquear),
              onTap: () => Navigator.pop(c, 'bloquear'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (eleccion == 'denunciar') await _denunciar(mensajeId, Mascara.nombre(t, mascara, repeticion));
    if (eleccion == 'bloquear') await _bloquear(mascara, repeticion, true);
  }

  Future<void> _denunciar(String mensajeId, String nombreMascara) async {
    final t = Textos.of(context);
    final motivos = {
      'ofensivo': t.motivoOfensivo,
      'sexual': t.motivoSexual,
      'spam': t.motivoSpam,
      'otro': t.motivoOtro,
    };
    final motivo = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text(t.chatDenunciarTitulo),
        children: [
          for (final m in motivos.entries)
            SimpleDialogOption(onPressed: () => Navigator.pop(c, m.key), child: Text(m.value)),
        ],
      ),
    );
    if (motivo == null) return;
    try {
      await llamarFuncion('denunciarMensaje', {
        'codigo': widget.codigo,
        'mensajeId': mensajeId,
        'motivo': motivo,
        // Solo para que el correo de la denuncia diga «Búho» y no «1:0».
        'nombreMascara': nombreMascara,
      });
      _avisar(t.chatDenunciado);
    } catch (e) {
      _avisar(e is FuncionError ? e.texto(t) : t.errorInesperado(e.toString()));
    }
  }

  Future<void> _bloquear(int mascara, int repeticion, bool bloquear) async {
    final t = Textos.of(context);
    final clave = '$mascara:$repeticion';
    try {
      await llamarFuncion('bloquearMascara', {
        'codigo': widget.codigo,
        'mascara': mascara,
        'repeticion': repeticion,
        'bloquear': bloquear,
      });
      if (!mounted) return;
      setState(() => bloquear ? _bloqueadas.add(clave) : _bloqueadas.remove(clave));
      if (bloquear) _avisar(t.chatBloqueada(Mascara.nombre(t, mascara, repeticion)));
    } catch (e) {
      _avisar(e is FuncionError ? e.texto(t) : t.errorInesperado(e.toString()));
    }
  }

  /// Lista de máscaras bloqueadas, para desbloquearlas.
  Future<void> _verBloqueadas() async {
    final t = Textos.of(context);
    await showModalBottomSheet<void>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, refrescar) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t.chatBloqueadas, style: const TextStyle(fontWeight: FontWeight.bold)),
                if (_bloqueadas.isEmpty)
                  Padding(padding: const EdgeInsets.all(16), child: Text(t.chatSinBloqueadas)),
                for (final clave in _bloqueadas.toList())
                  Builder(
                    builder: (_) {
                      final partes = clave.split(':');
                      final m = int.tryParse(partes.first) ?? 0;
                      final r = int.tryParse(partes.length > 1 ? partes[1] : '0') ?? 0;
                      return ListTile(
                        leading: InsigniaMascara(indice: m, radio: 16),
                        title: Text(Mascara.nombre(t, m, r)),
                        trailing: TextButton(
                          onPressed: () async {
                            await _bloquear(m, r, false);
                            refrescar(() {});
                          },
                          child: Text(t.chatDesbloquear),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _borrarMensaje(String mensajeId) async {
    final t = Textos.of(context);
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t.chatBorrarPregunta),
        content: Text(t.chatBorrarTexto),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t.cancelar)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(c, true),
            child: Text(t.chatBorrarMensaje),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    try {
      await llamarFuncion('borrarMensaje', {'codigo': widget.codigo, 'mensajeId': mensajeId});
    } catch (e) {
      if (!mounted) return;
      _avisar(e is FuncionError ? e.texto(t) : t.errorInesperado(e.toString()));
    }
  }

  // --- Interfaz ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    return Theme(
      data: temaGlass(_color),
      child: FondoTematico(
        tematica: widget.tematica,
        ocasion: widget.ocasion,
        colorPersonal: widget.colorPersonal,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          // Ver la nota en pantalla_registro.dart. Aquí el redactor no se
          // aparta con scroll: tiene que quedar SOBRE el teclado. Antes
          // se levantaba con un relleno inferior puesto a mano; ahora lo
          // hace el propio Scaffold al encoger, que es lo mismo pero sin
          // duplicar la cuenta del teclado. La Column sigue igual: la
          // lista en Expanded y el redactor al fondo del hueco visible.
          appBar: GlassAppBar(
            title: Text(t.chatTitulo),
            color: _color,
            actions: [
              if (widget.vinculo?.estoyDentro == true)
                IconButton(
                  icon: const Icon(Icons.block),
                  tooltip: t.chatBloqueadas,
                  onPressed: _verBloqueadas,
                ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                if (_miMascara != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _tarjetaMiMascara(t),
                  ),
                Expanded(child: _listaMensajes(t)),
                _redactor(t),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tarjetaMiMascara(Textos t) {
    final indice = _miMascara!;
    return GlassCard(
      color: _color,
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          InsigniaMascara(indice: indice, radio: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t.chatTuMascara(Mascara.nombre(t, indice, 0)),
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _listaMensajes(Textos t) {
    final colorSuelto = widget.tematica.fondoOscuro ? Colors.white70 : Colors.black54;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _chatRef.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: _color.shade700));
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                t.chatVacio,
                textAlign: TextAlign.center,
                style: TextStyle(color: colorSuelto),
              ),
            ),
          );
        }
        return ListView.builder(
          controller: _scroll,
          // Invertida: lo más reciente abajo y la vista arranca ahí, que
          // es lo que espera cualquiera que abre un chat.
          reverse: true,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            // Sin máscara ni autor: lo escribe el servidor cuando alguien
            // borra su cuenta en un grupo ya sorteado.
            if (data['sistema'] == 'abandono') {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  Textos.of(context).chatAbandono,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: Colors.black54,
                  ),
                ),
              );
            }
            final mascara = (data['mascara'] as num?)?.toInt() ?? 0;
            final repeticion = (data['repeticion'] as num?)?.toInt() ?? 0;
            if (_bloqueadas.contains('$mascara:$repeticion')) return const SizedBox.shrink();
            final esMia = _miMascara != null && _miMascara == mascara;
            return _Burbuja(
              texto: data['texto'] as String? ?? '',
              mascara: mascara,
              repeticion: repeticion,
              esMia: esMia,
              color: _color,
              onBorrar: widget.vinculo?.dirige == true ? () => _borrarMensaje(doc.id) : null,
              // Denunciar o bloquear: solo mensajes ajenos y solo si estás dentro.
              onMenu: !esMia && widget.vinculo?.estoyDentro == true
                  ? () => _menuMensaje(doc.id, mascara, repeticion)
                  : null,
            );
          },
        );
      },
    );
  }

  Widget _redactor(Textos t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: GlassTextField(
              color: _color,
              controller: _mensajeController,
              labelText: '',
              hintText: t.chatEscribe,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            height: 52,
            child: FilledButton(
              onPressed: (_enviando || widget.vinculo?.estoyDentro != true) ? null : _enviar,
              style: FilledButton.styleFrom(
                backgroundColor: legibleSobreBlanco(_color.shade600),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _enviando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Tooltip(message: t.chatEnviar, child: const Icon(Icons.send)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un mensaje. Los propios se alinean a la derecha para poder seguir la
/// conversación, pero se identifican por la MISMA máscara que ven los
/// demás: aquí no hay ningún dato extra sobre el autor.
class _Burbuja extends StatelessWidget {
  final String texto;
  final int mascara;
  final int repeticion;
  final bool esMia;
  final MaterialColor color;
  final VoidCallback? onBorrar;

  /// Denunciar o bloquear: pulsación larga, clic derecho o el ⋮ junto al
  /// nombre. Null en los propios.
  final VoidCallback? onMenu;

  const _Burbuja({
    required this.texto,
    required this.mascara,
    required this.repeticion,
    required this.esMia,
    required this.color,
    this.onBorrar,
    this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    final nombre = Mascara.nombre(t, mascara, repeticion);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: esMia ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!esMia) ...[InsigniaMascara(indice: mascara, radio: 16), const SizedBox(width: 8)],
          Flexible(
            child: GestureDetector(
              onLongPress: onMenu,
              onSecondaryTap: onMenu,
              child: GlassCard(
                color: color,
                radius: 16,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  crossAxisAlignment: esMia ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          esMia ? '$nombre (${t.chatTu})' : nombre,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Mascara.de(mascara).color,
                          ),
                        ),
                        if (onMenu != null)
                          Tooltip(
                            message: MaterialLocalizations.of(context).showMenuTooltip,
                            child: InkWell(
                              onTap: onMenu,
                              customBorder: const CircleBorder(),
                              child: const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: Icon(Icons.more_vert, size: 16, color: Colors.black45),
                              ),
                            ),
                          ),
                        if (onBorrar != null)
                          InkWell(
                            onTap: onBorrar,
                            customBorder: const CircleBorder(),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Icon(
                                Icons.delete_outline,
                                size: 16,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(texto, style: const TextStyle(color: Colors.black87, height: 1.35)),
                  ],
                ),
              ),
            ),
          ),
          if (esMia) ...[const SizedBox(width: 8), InsigniaMascara(indice: mascara, radio: 16)],
        ],
      ),
    );
  }
}
