import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';

/// «Este grupo cuesta 5 USD». La casilla es obligatoria: deja constancia de
/// que el grupo se crea al confirmarse el pago. El reembolso (14 días, en
/// paddle.net) va solo en /terminos, no aquí: decisión del usuario.
class DialogoPago extends StatefulWidget {
  const DialogoPago({super.key});

  /// `true` si aceptó y pulsó «Pagar y crear».
  static Future<bool> mostrar(BuildContext context) async =>
      await showDialog<bool>(context: context, builder: (_) => const DialogoPago()) ?? false;

  @override
  State<DialogoPago> createState() => _DialogoPagoState();
}

class _DialogoPagoState extends State<DialogoPago> {
  bool _acepta = false;

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    return AlertDialog(
      title: Text(t.pagoTitulo),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(t.pagoTexto),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _acepta,
            onChanged: (v) => setState(() => _acepta = v ?? false),
            title: Text(t.pagoCasilla, style: const TextStyle(fontSize: 13)),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancelar)),
        FilledButton(
          onPressed: _acepta ? () => Navigator.pop(context, true) : null,
          child: Text(t.pagoBoton),
        ),
      ],
    );
  }
}
