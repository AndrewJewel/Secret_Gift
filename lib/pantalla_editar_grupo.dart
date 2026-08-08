import 'package:flutter/material.dart';

import 'funciones.dart';
import 'glass.dart';
import 'l10n/app_localizations.dart';
import 'ocasion.dart';
import 'tematica.dart';

/// Pantalla de organizador: cambiar nombre, valor mínimo, temática y
/// reglas del grupo, o eliminarlo entero.
///
/// Solo se llega aquí con el modo organizador ya desbloqueado, así que el
/// PIN maestro llega verificado y no se vuelve a pedir para cada cambio.
/// La única excepción es eliminar el grupo, que sí pide confirmación
/// aparte por ser irreversible.
class PantallaEditarGrupo extends StatefulWidget {
  final String codigo;
  final String pinMaestro;
  final Ocasion ocasion;
  final String nombreGrupo;
  final String valorMinimo;
  final Tematica tematica;
  final String reglas;

  const PantallaEditarGrupo({
    super.key,
    required this.codigo,
    required this.pinMaestro,
    required this.ocasion,
    required this.nombreGrupo,
    required this.valorMinimo,
    required this.tematica,
    required this.reglas,
  });

  @override
  State<PantallaEditarGrupo> createState() => _PantallaEditarGrupoState();
}

/// Lo que le devolvemos a la pantalla del grupo al salir.
enum ResultadoEdicion { guardado, eliminado }

class _PantallaEditarGrupoState extends State<PantallaEditarGrupo> {
  late final TextEditingController _nombre = TextEditingController(text: widget.nombreGrupo);
  late final TextEditingController _valorMinimo = TextEditingController(text: widget.valorMinimo);
  late final TextEditingController _reglas = TextEditingController(text: widget.reglas);
  late Tematica _tematica = widget.tematica;
  bool _guardando = false;

  @override
  void dispose() {
    _nombre.dispose();
    _valorMinimo.dispose();
    _reglas.dispose();
    super.dispose();
  }

  MaterialColor get _color => _tematica.colorDe(widget.ocasion);

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  /// Al cambiar de temática, si las reglas siguen siendo las que traía por
  /// defecto alguna temática (o están vacías), las reemplazamos por las de
  /// la nueva. Si el organizador ya las escribió a mano, no se tocan: su
  /// texto siempre gana.
  ///
  /// Se comparan contra los textos por defecto en AMBOS idiomas: si creó
  /// el grupo en inglés y ahora edita en español, sus reglas siguen siendo
  /// las de fábrica aunque no coincidan con el idioma actual.
  void _cambiarTematica(Tematica nueva, Textos t) {
    final textoActual = _reglas.text.trim();
    final porDefecto = <String>{
      for (final locale in Textos.supportedLocales)
        for (final tema in Tematica.values) tema.reglasPorDefecto(lookupTextos(locale)),
    };
    final eraPorDefecto = textoActual.isEmpty || porDefecto.contains(textoActual);
    setState(() {
      _tematica = nueva;
      if (eraPorDefecto) _reglas.text = nueva.reglasPorDefecto(t);
    });
  }

  Future<void> _guardar() async {
    final t = Textos.of(context);
    final nombre = _nombre.text.trim();
    if (nombre.isEmpty) {
      _avisar('⚠️ ${t.errorNombreVacio}');
      return;
    }

    setState(() => _guardando = true);
    try {
      await llamarFuncion('editarGrupo', {
        'codigo': widget.codigo,
        'pinMaestro': widget.pinMaestro,
        'nombreGrupo': nombre,
        'valorMinimo': _valorMinimo.text.trim(),
        'tematica': _tematica.id,
        'reglas': _reglas.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context, ResultadoEdicion.guardado);
    } on FuncionError catch (e) {
      _avisar('⚠️ ${e.texto(t)}');
    } catch (e) {
      _avisar('⚠️ ${t.errorInesperado(e.toString())}');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _confirmarEliminar() async {
    final t = Textos.of(context);
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 40),
        title: Text(t.editarEliminarTitulo),
        content: Text(t.editarEliminarTexto(widget.nombreGrupo)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t.cancelar)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(c, true),
            child: Text(t.editarEliminarConfirmar),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    setState(() => _guardando = true);
    try {
      await llamarFuncion('eliminarGrupo', {
        'codigo': widget.codigo,
        'pinMaestro': widget.pinMaestro,
      });
      if (!mounted) return;
      Navigator.pop(context, ResultadoEdicion.eliminado);
    } on FuncionError catch (e) {
      _avisar('⚠️ ${e.texto(t)}');
      if (mounted) setState(() => _guardando = false);
    } catch (e) {
      _avisar('⚠️ ${t.errorInesperado(e.toString())}');
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    return Theme(
      data: temaGlass(_color),
      child: FondoTematico(
        tematica: _tematica,
        ocasion: widget.ocasion,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          // Ver la nota en pantalla_registro.dart: el teclado encoge el
          // Scaffold y el campo enfocado sube solo.
          appBar: GlassAppBar(title: Text(t.editarTitulo), color: _color),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              children: [
                GlassTextField(
                  color: _color,
                  controller: _nombre,
                  labelText: t.crearNombreGrupo,
                  icon: Icons.label_outline,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                GlassTextField(
                  color: _color,
                  controller: _valorMinimo,
                  labelText: t.crearValorMinimo,
                  hintText: t.crearValorMinimoPista,
                  icon: Icons.attach_money,
                ),
                const SizedBox(height: 16),
                SelectorTematica(
                  seleccionada: _tematica,
                  color: _color,
                  onCambio: (nueva) => _cambiarTematica(nueva, t),
                ),
                const SizedBox(height: 16),
                GlassTextField(
                  color: _color,
                  controller: _reglas,
                  labelText: t.editarReglas,
                  helperText: t.editarReglasAyuda,
                  icon: Icons.rule,
                  maxLines: 8,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 24),
                GlassButton(
                  color: _color.shade600,
                  onPressed: _guardando ? null : _guardar,
                  icon: Icons.check,
                  label: _guardando ? t.editarGuardando : t.editarGuardar,
                ),
                const SizedBox(height: 40),
                // Zona peligrosa, separada a propósito del resto: eliminar
                // el grupo no debe quedar al lado de "guardar".
                GlassCard(
                  color: _color,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 8),
                          Text(t.editarZonaPeligro,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(t.editarZonaPeligroTexto,
                          style: const TextStyle(color: Colors.black87, fontSize: 13)),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _guardando ? null : _confirmarEliminar,
                          icon: const Icon(Icons.delete_forever),
                          label: Text(t.editarEliminarBoton),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            side: BorderSide(color: Colors.red.shade300),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
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
}

/// Selector de temática, compartido entre crear grupo y editar grupo.
class SelectorTematica extends StatelessWidget {
  final Tematica seleccionada;
  final MaterialColor color;
  final ValueChanged<Tematica> onCambio;

  const SelectorTematica({
    super.key,
    required this.seleccionada,
    required this.color,
    required this.onCambio,
  });

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    return GlassCard(
      color: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.tematica,
              style: TextStyle(fontWeight: FontWeight.bold, color: color.shade800)),
          const SizedBox(height: 4),
          Text(t.tematicaAyuda,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 8),
          RadioGroup<Tematica>(
            groupValue: seleccionada,
            onChanged: (nueva) => onCambio(nueva!),
            child: Column(
              children: Tematica.values
                  .map((tema) => RadioListTile<Tematica>(
                        value: tema,
                        contentPadding: EdgeInsets.zero,
                        activeColor: color.shade700,
                        secondary: Icon(tema.icono, color: color.shade700),
                        title: Text(tema.titulo(t),
                            style: const TextStyle(
                                color: Colors.black87, fontWeight: FontWeight.w600)),
                        subtitle: Text(tema.descripcion(t),
                            style: const TextStyle(color: Colors.black54, fontSize: 12)),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
