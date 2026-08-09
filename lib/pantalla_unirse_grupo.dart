import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'acceso_cuenta.dart';
import 'almacen_local.dart';
import 'funciones.dart';
import 'glass.dart';
import 'l10n/app_localizations.dart';
import 'mi_vinculo.dart';
import 'ocasion.dart';
import 'sesion.dart';
import 'tematica.dart';
import 'pantalla_registro.dart';

class PantallaUnirseGrupo extends StatefulWidget {
  const PantallaUnirseGrupo({super.key});

  @override
  State<PantallaUnirseGrupo> createState() => _PantallaUnirseGrupoState();
}

class _PantallaUnirseGrupoState extends State<PantallaUnirseGrupo> {
  final TextEditingController _codigoController = TextEditingController();
  bool _buscando = false;

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  Future<void> _unirse() async {
    final t = Textos.of(context);
    final codigo = _codigoController.text.trim().toUpperCase();
    if (codigo.isEmpty) return;

    setState(() => _buscando = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('grupos').doc(codigo).get();
      if (!mounted) return;
      if (!doc.exists) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('⚠️ ${t.unirseNoExiste}')));
        return;
      }
      final data = doc.data()!;
      final nombreGrupo = data['nombreGrupo'] as String? ?? '';

      // El vínculo con este grupo lo sabe la CUENTA, no el documento del
      // grupo: `usuarios/{nick}` está cerrado al cliente (ver
      // firestore.rules), así que se pregunta por la única puerta que hay,
      // `iniciarSesionCuenta`. Sin este dato la pantalla ofrecía el
      // formulario de alta a quien ya tiene plaza, y apuntarse otra vez le
      // duplicaba la plaza dejando la vieja huérfana.
      final sesion = await leerSesion();
      if (!mounted) return;
      if (sesion == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('⚠️ ${t.errorSesionInvalida}')));
        return;
      }
      final acceso = await entrarConCuenta(
          nickname: sesion.nickname, password: sesion.password, registrando: false);
      // Con un bucle y no con `firstOrNull`, por la misma razón que en
      // pantalla_raiz.dart: esa extensión vive en `package:collection`,
      // que este proyecto no importa.
      Map<String, dynamic>? entrada;
      for (final g in acceso.grupos) {
        if (g['codigo'] == codigo) {
          entrada = g;
          break;
        }
      }

      await guardarUltimoGrupo(
          codigo, data['ocasion'] as String, data['valorMinimo'] as String? ?? '', nombreGrupo);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PantallaRegistro(
            codigo: codigo,
            ocasion: Ocasion.desdeId(data['ocasion'] as String),
            valorMinimo: data['valorMinimo'] as String? ?? '',
            nombreGrupo: nombreGrupo,
            vinculo: entrada == null ? null : MiVinculo.desdeMapa(entrada),
          ),
        ),
      );
    } on FuncionError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('⚠️ ${e.texto(t)}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('⚠️ ${t.errorInesperado(e.toString())}')));
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    return Theme(
      data: temaGlass(colorNeutro),
      child: FondoNeutro(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          // Ver la nota en pantalla_registro.dart: el teclado encoge el
          // Scaffold y el campo enfocado sube solo.
          appBar: GlassAppBar(title: Text(t.unirseTitulo), color: colorNeutro),
          // Era una Column fija: sin scroll, con el teclado abierto no
          // había forma de apartar el campo.
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            children: [
              GlassTextField(
                color: colorNeutro,
                controller: _codigoController,
                textCapitalization: TextCapitalization.characters,
                labelText: t.unirseCodigo,
                hintText: t.unirseCodigoPista,
                icon: Icons.key,
              ),
              const SizedBox(height: 20),
              GlassButton(
                color: colorNeutro.shade600,
                onPressed: _buscando ? null : _unirse,
                label: _buscando ? t.unirseBuscando : t.unirseBoton,
                icon: Icons.login,
                trailing: _buscando
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
    );
  }
}
