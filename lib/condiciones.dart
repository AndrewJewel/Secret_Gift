import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'funciones.dart';
import 'idioma.dart';
import 'l10n/app_localizations.dart';

/// Versión vigente de cada documento. Debe coincidir con
/// functions/condiciones.js: el servidor rechaza cualquier otra.
const versionTerminos = '2026-10-22';
const versionPrivacidad = '2026-10-22';

/// Las dos aceptaciones, por separado, en la versión vigente.
bool condicionesAlDia(Map<String, dynamic>? aceptaciones) {
  final a = aceptaciones ?? const {};
  return (a['terminos'] as Map?)?['version'] == versionTerminos &&
      (a['privacidad'] as Map?)?['version'] == versionPrivacidad;
}

/// Guarda en el servidor, con versión y fecha, las dos aceptaciones.
Future<void> aceptarCondicionesEnServidor(
        {Future<Map<String, dynamic>> Function(String, Map<String, dynamic>) llamar =
            llamarFuncion}) =>
    llamar('aceptarCondiciones', {'terminos': versionTerminos, 'privacidad': versionPrivacidad});

bool get _enIngles => Idioma.actual.value.languageCode == 'en';

Future<void> _abrir(String es, String en) => launchUrl(
      Uri.parse('https://secretgift.app/${_enIngles ? en : es}'),
      mode: LaunchMode.externalApplication,
    );

/// Dos casillas separadas y obligatorias: en Latinoamérica la autorización
/// de tratamiento de datos tiene que ser expresa y aparte de las condiciones.
class CasillasCondiciones extends StatefulWidget {
  /// Se llama cada vez que cambia una casilla, con true si están las dos.
  final ValueChanged<bool> onCambio;
  const CasillasCondiciones({super.key, required this.onCambio});

  @override
  State<CasillasCondiciones> createState() => _CasillasCondicionesState();
}

class _CasillasCondicionesState extends State<CasillasCondiciones> {
  bool _terminos = false;
  bool _privacidad = false;

  Widget _casilla({
    required bool valor,
    required ValueChanged<bool> cambiar,
    required String texto,
    required String leer,
    required VoidCallback abrir,
  }) =>
      CheckboxListTile(
        value: valor,
        onChanged: (v) => cambiar(v ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(texto, style: const TextStyle(fontSize: 14)),
        subtitle: Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: abrir,
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
            child: Text(leer, style: const TextStyle(decoration: TextDecoration.underline)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _casilla(
          valor: _terminos,
          cambiar: (v) {
            setState(() => _terminos = v);
            widget.onCambio(_terminos && _privacidad);
          },
          texto: t.condicionesAceptoTerminos,
          leer: t.condicionesLeerTerminos,
          abrir: () => _abrir('terminos', 'terms'),
        ),
        _casilla(
          valor: _privacidad,
          cambiar: (v) {
            setState(() => _privacidad = v);
            widget.onCambio(_terminos && _privacidad);
          },
          texto: t.condicionesAutorizoDatos,
          leer: t.condicionesLeerPrivacidad,
          abrir: () => _abrir('privacidad', 'privacy'),
        ),
      ],
    );
  }
}

/// Para cuentas que ya existían o cuando cambia una versión. No se puede
/// cerrar sin elegir: aceptar, o salir de la cuenta.
class DialogoCondiciones extends StatefulWidget {
  /// Guarda la aceptación. Se inyecta en las pruebas.
  final Future<void> Function() aceptar;
  final Future<void> Function() salir;
  const DialogoCondiciones({super.key, required this.aceptar, required this.salir});

  /// Devuelve true si aceptó.
  static Future<bool> mostrar(BuildContext context,
      {Future<void> Function()? aceptar, required Future<void> Function() salir}) async {
    final r = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: DialogoCondiciones(aceptar: aceptar ?? aceptarCondicionesEnServidor, salir: salir),
      ),
    );
    return r == true;
  }

  @override
  State<DialogoCondiciones> createState() => _DialogoCondicionesState();
}

class _DialogoCondicionesState extends State<DialogoCondiciones> {
  bool _ambas = false;
  bool _guardando = false;

  Future<void> _aceptar() async {
    final t = Textos.of(context);
    setState(() => _guardando = true);
    try {
      await widget.aceptar();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is FuncionError ? e.texto(t) : t.errorInesperado(e.toString()))));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    return AlertDialog(
      title: Text(t.condicionesTitulo),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.condicionesTexto),
            const SizedBox(height: 12),
            CasillasCondiciones(onCambio: (v) => setState(() => _ambas = v)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando
              ? null
              : () async {
                  Navigator.of(context).pop(false);
                  await widget.salir();
                },
          child: Text(t.misGruposCerrarSesion),
        ),
        FilledButton(
          onPressed: _ambas && !_guardando ? _aceptar : null,
          child: Text(t.condicionesAceptar),
        ),
      ],
    );
  }
}
