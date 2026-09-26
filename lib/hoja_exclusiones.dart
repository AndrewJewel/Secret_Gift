import 'package:flutter/material.dart';

import 'exclusiones.dart';
import 'l10n/app_localizations.dart';
import 'marca.dart';

typedef Persona = ({String id, String nombre});

/// Hoja «Excluir participante»: a quién no le puede tocar [personaId].
///
/// Cada casilla que, sumada a lo ya marcado, dejaría el grupo sin sorteo
/// posible se deshabilita al instante. Desmarcar nunca se bloquea: quitar
/// una exclusión solo da más opciones.
///
/// No llama al servidor: devuelve con `Navigator.pop` la lista de ids
/// excluidos (o null si se cancela), y quien la abrió la guarda.
class HojaExclusiones extends StatefulWidget {
  final String personaId;

  /// Todos los participantes, incluida la persona.
  final List<Persona> participantes;

  /// Parejas vigentes del grupo, como claves de [clavePareja].
  final Set<String> parejas;
  final MaterialColor color;

  const HojaExclusiones({
    super.key,
    required this.personaId,
    required this.participantes,
    required this.parejas,
    required this.color,
  });

  @override
  State<HojaExclusiones> createState() => _HojaExclusionesState();
}

class _HojaExclusionesState extends State<HojaExclusiones> {
  late final Set<String> _marcados = {
    for (final p in widget.participantes)
      if (p.id != widget.personaId &&
          widget.parejas.contains(clavePareja(widget.personaId, p.id)))
        p.id,
  };

  late final List<String> _ids = [for (final p in widget.participantes) p.id];

  /// Las parejas del grupo si se guardara la hoja con [marcados].
  Set<String> _borrador(Set<String> marcados) => {
        for (final clave in widget.parejas)
          if (!clave.split('|').contains(widget.personaId)) clave,
        for (final id in marcados) clavePareja(widget.personaId, id),
      };

  bool _bloqueada(String id) =>
      !_marcados.contains(id) && !hayCadenaConIds(_ids, _borrador({..._marcados, id}));

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.exclusionesTitulo,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: widget.color.shade800, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final p in widget.participantes)
                    if (p.id != widget.personaId)
                      Builder(builder: (context) {
                        final bloqueada = _bloqueada(p.id);
                        return CheckboxListTile(
                          value: _marcados.contains(p.id),
                          activeColor: widget.color.shade700,
                          contentPadding: EdgeInsets.zero,
                          title: Text(p.nombre),
                          subtitle: bloqueada
                              ? Text(t.exclusionesHariaImposible,
                                  style: TextStyle(color: Colors.red.shade700, fontSize: 12))
                              : null,
                          onChanged: bloqueada
                              ? null
                              : (marcar) => setState(() => marcar == true
                                  ? _marcados.add(p.id)
                                  : _marcados.remove(p.id)),
                        );
                      }),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancelar)),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: legibleSobreBlanco(widget.color.shade600)),
                  onPressed: () => Navigator.pop(context, _marcados.toList()),
                  child: Text(t.guardar),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
