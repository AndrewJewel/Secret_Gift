import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'avatar.dart';
import 'funciones.dart';
import 'glass.dart';
import 'identidad_local.dart';
import 'l10n/app_localizations.dart';
import 'ocasion.dart';

/// Hoja para decir cuál de los participantes eres, con tu PIN.
///
/// La usan la pantalla del grupo (cuando llegas desde otro dispositivo y
/// ya estabas dentro) y el chat (antes del primer mensaje). Verifica
/// contra el servidor antes de dar nada por bueno: si el PIN no cuadra,
/// no te deja pasar.
class HojaIdentidad extends StatefulWidget {
  final String codigo;
  final MaterialColor color;

  const HojaIdentidad({super.key, required this.codigo, required this.color});

  /// Devuelve la identidad ya verificada, o null si se canceló.
  static Future<IdentidadGrupo?> mostrar(
      BuildContext context, String codigo, MaterialColor color) {
    return showModalBottomSheet<IdentidadGrupo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HojaIdentidad(codigo: codigo, color: color),
    );
  }

  @override
  State<HojaIdentidad> createState() => _HojaIdentidadState();
}

class _HojaIdentidadState extends State<HojaIdentidad> {
  String? _participanteId;
  String? _nombre;
  final _pinController = TextEditingController();
  bool _verificando = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    final id = _participanteId;
    final pin = _pinController.text.trim();
    if (id == null || pin.isEmpty) return;

    setState(() => _verificando = true);
    try {
      // iniciarSesion verifica el PIN PROPIO (nunca el maestro). Si pasa,
      // la identidad es buena.
      await llamarFuncion('iniciarSesion', {
        'codigo': widget.codigo,
        'participanteId': id,
        'pin': pin,
      });
      if (!mounted) return;
      Navigator.pop(context, IdentidadGrupo(id, pin));
    } catch (e) {
      if (!mounted) return;
      final t = Textos.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '⚠️ ${e is FuncionError ? e.texto(t) : t.errorInesperado(e.toString())}')));
    } finally {
      if (mounted) setState(() => _verificando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    final color = widget.color;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: color.shade50,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t.chatQuienEres,
                  textAlign: TextAlign.center, style: tituloGlass(color)),
              const SizedBox(height: 6),
              Text(t.chatQuienEresTexto,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('grupos')
                      .doc(widget.codigo)
                      .collection('participantes')
                      .orderBy('nombre')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(
                          child: CircularProgressIndicator(color: color.shade700));
                    }
                    final docs = snapshot.data!.docs;
                    return RadioGroup<String>(
                      groupValue: _participanteId,
                      onChanged: (v) => setState(() {
                        _participanteId = v;
                        _nombre =
                            docs.firstWhere((d) => d.id == v).data()['nombre'] as String? ?? '';
                      }),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data();
                          return RadioListTile<String>(
                            value: docs[index].id,
                            activeColor: color.shade700,
                            contentPadding: EdgeInsets.zero,
                            secondary: AvatarParticipante(
                              url: data['avatarUrl'] as String?,
                              color: color,
                              radio: 16,
                            ),
                            title: Text(data['nombre'] as String? ?? '',
                                style: const TextStyle(color: Colors.black87)),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                decoration: InputDecoration(
                  labelText:
                      _nombre == null ? t.registroTuPin : '${t.registroTuPin} · $_nombre',
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _confirmar(),
              ),
              const SizedBox(height: 16),
              GlassButton(
                color: color.shade600,
                onPressed: (_participanteId == null || _verificando) ? null : _confirmar,
                icon: Icons.check,
                label: _verificando ? t.unMomento : t.entrar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
