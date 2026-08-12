import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';

/// Pregunta por los avisos ANTES que el navegador.
///
/// Existe por una sola razón: al navegador solo se le puede preguntar una
/// vez en la práctica. Si lo deniegan, queda denegado para siempre y las
/// llamadas siguientes no muestran nada — ni siquiera aparece el cuadro.
///
/// Y este momento —recién creada la cuenta— es el de más probabilidad de
/// un «no» por costumbre: la persona todavía no ha visto la app ni está en
/// ningún grupo. Preguntando nosotros primero, un «Ahora no» no gasta
/// nada y se le puede volver a ofrecer más adelante.
///
/// POR ESO `alSaltar` NO DEBE PEDIR EL PERMISO. Si algún día alguien lo
/// engancha ahí, esta pantalla deja de servir para nada.
class PantallaPermisoAvisos extends StatefulWidget {
  /// Qué hacer al aceptar. Es lo único que puede llamar al navegador.
  final Future<void> Function() alAceptar;

  /// Qué hacer al posponerlo. No toca el permiso.
  final VoidCallback alSaltar;

  const PantallaPermisoAvisos({
    super.key,
    required this.alAceptar,
    required this.alSaltar,
  });

  @override
  State<PantallaPermisoAvisos> createState() => _PantallaPermisoAvisosState();
}

class _PantallaPermisoAvisosState extends State<PantallaPermisoAvisos> {
  bool _pidiendo = false;

  Future<void> _aceptar() async {
    setState(() => _pidiendo = true);
    try {
      await widget.alAceptar();
    } finally {
      if (mounted) setState(() => _pidiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.notifications_active_outlined, size: 64),
                const SizedBox(height: 16),
                Text(t.avisosTitulo,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(t.avisosTexto, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _pidiendo ? null : _aceptar,
                  child: Text(t.avisosSi),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _pidiendo ? null : widget.alSaltar,
                  child: Text(t.avisosAhoraNo),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
