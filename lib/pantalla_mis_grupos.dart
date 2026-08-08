import 'package:flutter/material.dart';

import 'glass.dart';
import 'l10n/app_localizations.dart';
import 'ocasion.dart';
import 'tematica.dart';
import 'pantalla_registro.dart';
import 'sesion.dart';

class PantallaMisGrupos extends StatelessWidget {
  final String nickname;
  final List<Map<String, dynamic>> grupos;

  const PantallaMisGrupos({super.key, required this.nickname, required this.grupos});

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    return Theme(
      data: temaGlass(colorNeutro),
      child: FondoNeutro(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: GlassAppBar(
            title: Text(t.misGruposSaludo(nickname)),
            color: colorNeutro,
            actions: [
              IconButton(
                icon: Icon(Icons.logout, color: colorNeutro.shade800),
                tooltip: t.misGruposCerrarSesion,
                onPressed: () async {
                  await cerrarSesion();
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          ),
          body: grupos.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: GlassCard(
                      color: colorNeutro,
                      child: Text(
                        t.misGruposVacio,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: grupos.length,
                  itemBuilder: (context, index) {
                    final g = grupos[index];
                    final ocasion = Ocasion.desdeId(g['ocasion'] as String);
                    final nombreGrupo = g['nombreGrupo'] as String? ?? '';
                    final esOrganizador = g['rol'] == 'organizador';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassCard(
                        color: ocasion.colorBase,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ListTile(
                          leading: Text(ocasion.emoji, style: const TextStyle(fontSize: 28)),
                          title: Text(
                            nombreGrupo.isNotEmpty
                                ? nombreGrupo
                                : '${ocasion.titulo(t)} — ${g['codigo']}',
                            style: const TextStyle(
                                color: Colors.black87, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${esOrganizador ? t.misGruposOrganizador : t.misGruposParticipante} · ${g['codigo']}',
                            style: const TextStyle(color: Colors.black54),
                          ),
                          trailing:
                              Icon(Icons.chevron_right, color: ocasion.colorBase.shade700),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PantallaRegistro(
                                codigo: g['codigo'] as String,
                                ocasion: ocasion,
                                valorMinimo: g['valorMinimo'] as String? ?? '',
                                nombreGrupo: nombreGrupo,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
