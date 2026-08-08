import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'avatar.dart';
import 'funciones.dart';
import 'glass.dart';
import 'l10n/app_localizations.dart';
import 'ocasion.dart';
import 'tematica.dart';
import 'pantalla_secreta.dart';

class PantallaLogin extends StatelessWidget {
  final String codigo;
  final Ocasion ocasion;
  final Tematica tematica;

  const PantallaLogin({
    super.key,
    required this.codigo,
    required this.ocasion,
    this.tematica = Tematica.ninguna,
  });

  MaterialColor get _color => tematica.colorDe(ocasion);

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    return Theme(
      data: temaGlass(_color),
      child: FondoTematico(
        tematica: tematica,
        ocasion: ocasion,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: GlassAppBar(title: Text(t.loginTitulo), color: _color),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('grupos')
                .doc(codigo)
                .collection('participantes')
                .orderBy('nombre')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(child: CircularProgressIndicator(color: _color.shade700));
              }
              final docs = snapshot.data!.docs;
              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: docs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final nombre = data['nombre'] as String? ?? '';
                  return GlassCard(
                    color: _color,
                    radius: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: AvatarParticipante(
                        url: data['avatarUrl'] as String?,
                        color: _color,
                      ),
                      title: Text(nombre,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.black87)),
                      trailing: Icon(Icons.chevron_right, color: _color.shade700),
                      onTap: () => _pedirPinYEntrar(context, docs[index].id, nombre),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _pedirPinYEntrar(
      BuildContext context, String participanteId, String nombre) async {
    final t = Textos.of(context);
    final pinInput = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t.loginHola(nombre)),
        content: TextField(
          controller: pinInput,
          keyboardType: TextInputType.number,
          obscureText: true,
          autofocus: true,
          textAlign: TextAlign.center,
          decoration: InputDecoration(labelText: t.registroTuPin),
          onSubmitted: (v) => Navigator.pop(c, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t.cancelar)),
          FilledButton(
            onPressed: () => Navigator.pop(c, pinInput.text.trim()),
            child: Text(t.entrar),
          ),
        ],
      ),
    );
    if (pin == null || pin.isEmpty || !context.mounted) return;

    try {
      final data = await llamarFuncion('iniciarSesion', {
        'codigo': codigo,
        'participanteId': participanteId,
        'pin': pin,
      });
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PantallaSecreta(
            ocasion: ocasion,
            tematica: tematica,
            nombre: nombre,
            nombreAmigo: data['nombreAmigo'] as String? ?? '',
            deseosAmigo: (data['deseosAmigo'] as String?)?.isNotEmpty == true
                ? data['deseosAmigo'] as String
                : t.secretaSinSugerencias,
          ),
        ),
      );
    } on FuncionError catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('⚠️ ${e.texto(t)}')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('⚠️ ${t.errorInesperado(e.toString())}')));
    }
  }
}
