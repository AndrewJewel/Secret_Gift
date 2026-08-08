import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'almacen_local.dart';
import 'glass.dart';
import 'idioma.dart';
import 'l10n/app_localizations.dart';
import 'ocasion.dart';
import 'tematica.dart';
import 'pantalla_crear_grupo.dart';
import 'pantalla_cuenta.dart';
import 'pantalla_registro.dart';
import 'pantalla_unirse_grupo.dart';

class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  GrupoGuardado? _ultimoGrupo;

  @override
  void initState() {
    super.initState();
    // La pantalla se muestra de inmediato siempre (ver build()); estas dos
    // tareas corren en segundo plano y nunca bloquean la interfaz, aunque
    // se demoren, fallen o se cuelguen por completo.
    _cargarUltimoGrupo();
    _revisarEnlaceDirecto();
  }

  void _cargarUltimoGrupo() {
    leerUltimoGrupo().then((g) {
      if (mounted) setState(() => _ultimoGrupo = g);
    });
  }

  // Si llegaron por un link/QR con ?codigo=XXXX (compartido desde la
  // pantalla de un grupo), saltamos directo al registro de ese grupo.
  // Nunca bloquea la pantalla de inicio: si tarda o falla, la persona ya
  // está viendo la pantalla normal y puede seguir usándola igual.
  Future<void> _revisarEnlaceDirecto() async {
    if (!kIsWeb) return;
    final codigo = Uri.base.queryParameters['codigo']?.trim().toUpperCase();
    if (codigo == null || codigo.isEmpty) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('grupos')
          .doc(codigo)
          .get()
          .timeout(const Duration(seconds: 6));
      if (!doc.exists || !mounted) return;

      final data = doc.data()!;
      final nombreGrupo = data['nombreGrupo'] as String? ?? '';
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
          ),
        ),
      );
    } catch (_) {
      // Sin conexión, código inválido, o se demoró más de 6s: no pasa
      // nada, la persona ya está viendo la pantalla de inicio normal.
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    final ultimo = _ultimoGrupo;

    return Theme(
      data: temaGlass(colorNeutro),
      child: FondoNeutro(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: GlassAppBar(
            title: Text(t.appTitle),
            color: colorNeutro,
            actions: const [_SelectorIdioma()],
          ),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/logo.png', height: 132),
                  const SizedBox(height: 12),
                  GlassCard(
                    color: colorNeutro,
                    child: Text(
                      t.inicioSubtitulo,
                      textAlign: TextAlign.center,
                      style: tituloGlass(colorNeutro),
                    ),
                  ),
                  if (ultimo != null) ...[
                    const SizedBox(height: 24),
                    GlassButton(
                      color: Colors.green.shade700,
                      icon: Icons.history,
                      label: t.inicioContinuarEn(
                          ultimo.nombreGrupo.isNotEmpty ? ultimo.nombreGrupo : ultimo.codigo),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PantallaRegistro(
                            codigo: ultimo.codigo,
                            ocasion: Ocasion.desdeId(ultimo.ocasionId),
                            valorMinimo: ultimo.valorMinimo,
                            nombreGrupo: ultimo.nombreGrupo,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(t.inicioUltimoGrupoNota,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                  const SizedBox(height: 32),
                  ultimo == null
                      ? GlassButton(
                          color: colorNeutro.shade600,
                          icon: Icons.add_circle_outline,
                          label: t.inicioCrearGrupo,
                          onPressed: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const PantallaCrearGrupo())),
                        )
                      : GlassOutlineButton(
                          color: colorNeutro,
                          icon: Icons.add_circle_outline,
                          label: t.inicioCrearGrupo,
                          onPressed: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const PantallaCrearGrupo())),
                        ),
                  const SizedBox(height: 16),
                  GlassOutlineButton(
                    color: colorNeutro,
                    icon: Icons.groups_outlined,
                    label: t.inicioUnirse,
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const PantallaUnirseGrupo())),
                  ),
                  const SizedBox(height: 24),
                  TextButton.icon(
                    icon: Icon(Icons.account_circle_outlined, color: colorNeutro.shade700),
                    label: Text(t.inicioMiCuenta,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colorNeutro.shade700)),
                    onPressed: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => const PantallaCuenta())),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cambia el idioma de toda la app. Vive en la barra de la pantalla de
/// inicio, que es por donde pasa todo el mundo antes de entrar a un grupo.
class _SelectorIdioma extends StatelessWidget {
  const _SelectorIdioma();

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    final actual = Localizations.localeOf(context).languageCode;
    return PopupMenuButton<Locale>(
      icon: Icon(Icons.language, color: colorNeutro.shade800),
      tooltip: t.idioma,
      onSelected: Idioma.cambiar,
      itemBuilder: (context) => [
        for (final locale in Idioma.soportados)
          CheckedPopupMenuItem<Locale>(
            value: locale,
            checked: locale.languageCode == actual,
            child: Text(locale.languageCode == 'en' ? t.idiomaIngles : t.idiomaEspanol),
          ),
      ],
    );
  }
}
