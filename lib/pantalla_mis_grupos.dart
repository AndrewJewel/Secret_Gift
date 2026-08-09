import 'package:flutter/material.dart';

import 'acceso_cuenta.dart';
import 'glass.dart';
import 'l10n/app_localizations.dart';
import 'mi_vinculo.dart';
import 'ocasion.dart';
import 'pantalla_crear_grupo.dart';
import 'pantalla_unirse_grupo.dart';
import 'ruta_observer.dart';
import 'selector_idioma.dart';
import 'tematica.dart';
import 'pantalla_registro.dart';
import 'sesion.dart';

class PantallaMisGrupos extends StatefulWidget {
  final String nickname;
  final List<Map<String, dynamic>> grupos;

  const PantallaMisGrupos({super.key, required this.nickname, required this.grupos});

  @override
  State<PantallaMisGrupos> createState() => _PantallaMisGruposState();
}

class _PantallaMisGruposState extends State<PantallaMisGrupos> with RouteAware {
  late List<Map<String, dynamic>> _grupos = widget.grupos;

  /// Suscripción al observador global. `didPopNext` es lo único que avisa
  /// de verdad de que esta pantalla vuelve a ser visible; esperar al
  /// future del `push` no vale porque crear/unirse terminan en
  /// `pushReplacement` (ver ruta_observer.dart).
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ruta = ModalRoute.of(context);
    if (ruta is PageRoute) rutaObserver.subscribe(this, ruta);
  }

  @override
  void dispose() {
    rutaObserver.unsubscribe(this);
    super.dispose();
  }

  /// Se volvió aquí desde la pantalla que había encima: crear grupo,
  /// unirse o el propio grupo. En todos esos casos la lista puede haber
  /// cambiado.
  @override
  void didPopNext() {
    _recargar();
  }

  /// La lista llega como semilla desde el login para pintar sin espera,
  /// pero deja de valer en cuanto se crea o se entra a un grupo. Se
  /// recarga al volver de esas pantallas: si no, un grupo recién creado
  /// no aparecería hasta cerrar sesión y volver a entrar.
  Future<void> _recargar() async {
    final sesion = await leerSesion();
    if (sesion == null) return;
    try {
      final r = await entrarConCuenta(
          nickname: sesion.nickname, password: sesion.password, registrando: false);
      if (!mounted) return;
      setState(() => _grupos = r.grupos);
    } catch (_) {
      // Sin conexión se queda la lista que ya había, que es mejor que
      // vaciarla o mostrar un error por algo secundario.
    }
  }

  /// Solo apila. La recarga la dispara `didPopNext` cuando esta pantalla
  /// vuelve a verse, que es el único momento fiable.
  void _abrir(Widget pantalla) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
  }

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    return Theme(
      data: temaGlass(colorNeutro),
      child: FondoNeutro(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: GlassAppBar(
            title: Text(t.misGruposSaludo(widget.nickname)),
            color: colorNeutro,
            actions: [
              const IconoIdioma(),
              IconButton(
                icon: Icon(Icons.logout, color: colorNeutro.shade800),
                tooltip: t.misGruposCerrarSesion,
                onPressed: () async {
                  await cerrarSesion();
                  if (context.mounted) {
                    // Se vuelve a la raíz por nombre de ruta, no importando el portero.
                    // Importarlo aquí crearía un ciclo: el portero ya importa esta pantalla
                    // para navegar hacia ella. La raíz '/' es el `home:` de MaterialApp, o
                    // sea el propio portero, que al no encontrar sesión manda al registro
                    // con la callback correcta.
                    Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
                  }
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: _grupos.isEmpty
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
                        itemCount: _grupos.length,
                        itemBuilder: (context, index) {
                          final g = _grupos[index];
                          final ocasion = Ocasion.desdeId(g['ocasion'] as String);
                          final nombreGrupo = g['nombreGrupo'] as String? ?? '';
                          final esOrganizador = g['rol'] == 'organizador';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: GlassCard(
                              color: ocasion.colorBase,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: ListTile(
                                leading:
                                    Text(ocasion.emoji, style: const TextStyle(fontSize: 28)),
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
                                trailing: Icon(Icons.chevron_right,
                                    color: ocasion.colorBase.shade700),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PantallaRegistro(
                                      codigo: g['codigo'] as String,
                                      ocasion: ocasion,
                                      valorMinimo: g['valorMinimo'] as String? ?? '',
                                      nombreGrupo: nombreGrupo,
                                      vinculo: MiVinculo.desdeMapa(g),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    GlassButton(
                      color: colorNeutro.shade600,
                      icon: Icons.add_circle_outline,
                      label: t.misGruposCrear,
                      onPressed: () => _abrir(const PantallaCrearGrupo()),
                    ),
                    const SizedBox(height: 12),
                    GlassOutlineButton(
                      color: colorNeutro,
                      icon: Icons.groups_outlined,
                      label: t.misGruposUnirse,
                      onPressed: () => _abrir(const PantallaUnirseGrupo()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
