import 'package:flutter/material.dart';

import 'almacen_local.dart';
import 'funciones.dart';
import 'glass.dart';
import 'l10n/app_localizations.dart';
import 'ocasion.dart';
import 'pantalla_editar_grupo.dart' show SelectorTematica;
import 'pantalla_registro.dart';
import 'sesion.dart';
import 'tematica.dart';

class PantallaCrearGrupo extends StatefulWidget {
  const PantallaCrearGrupo({super.key});

  @override
  State<PantallaCrearGrupo> createState() => _PantallaCrearGrupoState();
}

class _PantallaCrearGrupoState extends State<PantallaCrearGrupo> {
  Ocasion _ocasion = Ocasion.amigoSecreto;
  Tematica _tematica = Tematica.ninguna;
  final TextEditingController _nombreGrupoController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _valorMinimoController = TextEditingController();
  bool _creando = false;

  /// El color y el fondo los manda la temática; sin temática, la ocasión.
  MaterialColor get _color => _tematica.colorDe(_ocasion);

  @override
  void dispose() {
    _nombreGrupoController.dispose();
    _pinController.dispose();
    _valorMinimoController.dispose();
    super.dispose();
  }

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _crearGrupo() async {
    final t = Textos.of(context);
    final nombreGrupo = _nombreGrupoController.text.trim();
    final pin = _pinController.text.trim();
    final valorMinimo = _valorMinimoController.text.trim();

    if (nombreGrupo.isEmpty || pin.isEmpty) {
      _avisar('⚠️ ${t.crearFaltanDatos}');
      return;
    }

    setState(() => _creando = true);
    try {
      final sesion = await leerSesion();
      final datos = await llamarFuncion('crearGrupo', {
        'ocasion': _ocasion.id,
        'nombreGrupo': nombreGrupo,
        'pinMaestro': pin,
        'valorMinimo': valorMinimo,
        'tematica': _tematica.id,
        // Arranca con las reglas propias de la temática; el organizador
        // las puede reescribir después desde "Editar grupo".
        'reglas': _tematica.reglasPorDefecto(t),
        if (sesion != null) 'nickname': sesion.nickname,
        if (sesion != null) 'password': sesion.password,
      });
      final codigo = datos['codigo'] as String;
      if (!mounted) return;
      await _mostrarCodigoYContinuar(codigo);
    } on FuncionError catch (e) {
      _avisar('⚠️ ${e.texto(t)}');
    } catch (e) {
      _avisar('⚠️ ${t.errorInesperado(e.toString())}');
    } finally {
      if (mounted) setState(() => _creando = false);
    }
  }

  Future<void> _mostrarCodigoYContinuar(String codigo) async {
    final t = Textos.of(context);
    await guardarUltimoGrupo(
        codigo, _ocasion.id, _valorMinimoController.text.trim(), _nombreGrupoController.text.trim());
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: Text('🎉 ${t.crearListoTitulo}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.crearListoTexto),
            const SizedBox(height: 16),
            SelectableText(codigo,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(c), child: Text(t.continuar)),
        ],
      ),
    );
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaRegistro(
          codigo: codigo,
          ocasion: _ocasion,
          valorMinimo: _valorMinimoController.text.trim(),
          nombreGrupo: _nombreGrupoController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    return Theme(
      data: temaGlass(_color),
      child: FondoTematico(
        tematica: _tematica,
        ocasion: _ocasion,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          // Ver la nota en pantalla_registro.dart: el teclado encoge el
          // Scaffold y el campo enfocado sube solo. Nada de rellenos
          // manuales con viewInsets: contarían el teclado dos veces.
          appBar: GlassAppBar(title: Text(t.crearTitulo), color: _color),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: ListView(
              padding: const EdgeInsets.only(top: 20, bottom: 20),
              children: [
                GlassCard(
                  color: _color,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(t.crearOcasion,
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: _color.shade800)),
                      RadioGroup<Ocasion>(
                        groupValue: _ocasion,
                        onChanged: (v) => setState(() => _ocasion = v!),
                        child: Column(
                          children: Ocasion.values
                              .map((o) => RadioListTile<Ocasion>(
                                    title: Text('${o.emoji} ${o.titulo(t)}',
                                        style: const TextStyle(color: Colors.black87)),
                                    value: o,
                                    contentPadding: EdgeInsets.zero,
                                    activeColor: _color.shade700,
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SelectorTematica(
                  seleccionada: _tematica,
                  color: _color,
                  onCambio: (nueva) => setState(() => _tematica = nueva),
                ),
                const SizedBox(height: 16),
                GlassTextField(
                  color: _color,
                  controller: _nombreGrupoController,
                  labelText: t.crearNombreGrupo,
                  hintText: t.crearNombreGrupoPista,
                  icon: Icons.label_outline,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                GlassTextField(
                  color: _color,
                  controller: _pinController,
                  labelText: t.crearPinMaestro,
                  helperText: t.crearPinMaestroAyuda,
                  icon: Icons.lock_outline,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                GlassTextField(
                  color: _color,
                  controller: _valorMinimoController,
                  labelText: t.crearValorMinimo,
                  hintText: t.crearValorMinimoPista,
                  icon: Icons.attach_money,
                ),
                const SizedBox(height: 24),
                GlassButton(
                  color: _color.shade600,
                  onPressed: _creando ? null : _crearGrupo,
                  label: _creando ? t.crearCreando : t.crearBoton,
                  icon: Icons.check,
                  trailing: _creando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
