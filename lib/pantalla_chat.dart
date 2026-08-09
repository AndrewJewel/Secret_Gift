import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'funciones.dart';
import 'glass.dart';
import 'l10n/app_localizations.dart';
import 'mascara.dart';
import 'mi_vinculo.dart';
import 'ocasion.dart';
import 'sesion.dart';
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

  /// Tu vínculo con el grupo: dice si eres organizador (para moderar) y
  /// qué participante eres (para resaltar tus mensajes).
  final MiVinculo? vinculo;

  const PantallaChat({
    super.key,
    required this.codigo,
    required this.ocasion,
    required this.tematica,
    this.vinculo,
  });

  @override
  State<PantallaChat> createState() => _PantallaChatState();
}

class _PantallaChatState extends State<PantallaChat> {
  final TextEditingController _mensajeController = TextEditingController();
  final ScrollController _scroll = ScrollController();

  int? _miMascara;
  bool _enviando = false;

  late final Query<Map<String, dynamic>> _chatRef = FirebaseFirestore.instance
      .collection('grupos')
      .doc(widget.codigo)
      .collection('chat')
      .orderBy('fecha', descending: true)
      .limit(200);

  MaterialColor get _color => widget.tematica.colorDe(widget.ocasion);

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
    final sesion = await leerSesion();
    if (sesion == null) return;
    try {
      final datos = await llamarFuncion('miMascara', {
        'codigo': widget.codigo,
        'nickname': sesion.nickname,
        'password': sesion.password,
      });
      if (!mounted) return;
      setState(() => _miMascara = datos['mascara'] as int?);
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
    final sesion = await leerSesion();
    if (sesion == null || !mounted) return;

    setState(() => _enviando = true);
    try {
      final datos = await llamarFuncion('enviarMensaje', {
        'codigo': widget.codigo,
        'texto': texto,
        'nickname': sesion.nickname,
        'password': sesion.password,
      });
      _mensajeController.clear();
      if (!mounted) return;
      setState(() => _miMascara = datos['mascara'] as int?);
      // La lista va invertida, así que lo más nuevo está en el offset 0.
      if (_scroll.hasClients) {
        _scroll.animateTo(0,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    } catch (e) {
      if (!mounted) return;
      final t = Textos.of(context);
      _avisar('⚠️ ${e is FuncionError ? e.texto(t) : t.errorInesperado(e.toString())}');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
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
      final sesion = await leerSesion();
      if (sesion == null) return;
      await llamarFuncion('borrarMensaje', {
        'codigo': widget.codigo,
        'mensajeId': mensajeId,
        'nickname': sesion.nickname,
        'password': sesion.password,
      });
    } catch (e) {
      if (!mounted) return;
      _avisar('⚠️ ${e is FuncionError ? e.texto(t) : t.errorInesperado(e.toString())}');
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
              child: Text(t.chatVacio,
                  textAlign: TextAlign.center, style: TextStyle(color: colorSuelto)),
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
            final mascara = (data['mascara'] as num?)?.toInt() ?? 0;
            final repeticion = (data['repeticion'] as num?)?.toInt() ?? 0;
            return _Burbuja(
              texto: data['texto'] as String? ?? '',
              mascara: mascara,
              repeticion: repeticion,
              esMia: _miMascara != null && _miMascara == mascara,
              color: _color,
              onBorrar: widget.vinculo?.esOrganizador == true ? () => _borrarMensaje(doc.id) : null,
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
              onPressed: (_enviando || widget.vinculo?.estoyDentro != true)
                  ? null
                  : _enviar,
              style: FilledButton.styleFrom(
                backgroundColor: _color.shade600,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _enviando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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

  const _Burbuja({
    required this.texto,
    required this.mascara,
    required this.repeticion,
    required this.esMia,
    required this.color,
    this.onBorrar,
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
          if (!esMia) ...[
            InsigniaMascara(indice: mascara, radio: 16),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GlassCard(
              color: color,
              radius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment:
                    esMia ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(esMia ? '$nombre (${t.chatTu})' : nombre,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Mascara.de(mascara).color)),
                      if (onBorrar != null)
                        InkWell(
                          onTap: onBorrar,
                          customBorder: const CircleBorder(),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(Icons.delete_outline,
                                size: 16, color: Colors.red.shade700),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(texto,
                      style: const TextStyle(color: Colors.black87, height: 1.35)),
                ],
              ),
            ),
          ),
          if (esMia) ...[
            const SizedBox(width: 8),
            InsigniaMascara(indice: mascara, radio: 16),
          ],
        ],
      ),
    );
  }
}

