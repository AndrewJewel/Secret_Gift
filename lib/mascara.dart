import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';

/// Máscaras del chat anónimo.
///
/// Del servidor llega un NÚMERO, no un nombre: así "Blue Fox" y "Zorro
/// Azul" son exactamente el mismo participante en los dos idiomas, y
/// cambiar de idioma no rompe el hilo de la conversación.
///
/// La máscara es a propósito independiente del personaje que la persona
/// eligió en un grupo temático: la gente le cuenta su personaje a sus
/// amigos, y ahí el chat dejaría de ser anónimo.
class Mascara {
  final String emoji;
  final Color color;

  const Mascara(this.emoji, this.color);

  static const todas = <Mascara>[
    Mascara('🦊', Color(0xFFE07A3E)),
    Mascara('🦉', Color(0xFF7B5E3B)),
    Mascara('🐻', Color(0xFF8D6748)),
    Mascara('🐱', Color(0xFFB0894E)),
    Mascara('🐺', Color(0xFF5F6B7A)),
    Mascara('🐰', Color(0xFFC98BA0)),
    Mascara('🦌', Color(0xFF9A6B4F)),
    Mascara('🐼', Color(0xFF4A4A4A)),
    Mascara('🐯', Color(0xFFD98C1F)),
    Mascara('🐧', Color(0xFF3C6E93)),
    Mascara('🐬', Color(0xFF2E8BA8)),
    Mascara('🦅', Color(0xFF6B4A2F)),
    Mascara('🐸', Color(0xFF4E8C42)),
    Mascara('🦔', Color(0xFF8A7B5C)),
    Mascara('🐨', Color(0xFF6E7B82)),
    Mascara('🦦', Color(0xFF7A5C3E)),
  ];

  /// Índice fuera de rango: se envuelve en vez de reventar. Un servidor
  /// más nuevo podría añadir máscaras que esta versión no conoce.
  static Mascara de(int indice) => todas[indice.abs() % todas.length];

  /// Nombre traducido. Si el grupo pasa de 16 personas se reutilizan
  /// máscaras, y la repetición las distingue: "Zorro Azul 2".
  static String nombre(Textos t, int indice, int repeticion) {
    final base = _nombres(t)[indice.abs() % todas.length];
    return repeticion > 0 ? '$base ${repeticion + 1}' : base;
  }

  static List<String> _nombres(Textos t) => [
        t.mascaraZorro,
        t.mascaraBuho,
        t.mascaraOso,
        t.mascaraGato,
        t.mascaraLobo,
        t.mascaraConejo,
        t.mascaraCiervo,
        t.mascaraPanda,
        t.mascaraTigre,
        t.mascaraPinguino,
        t.mascaraDelfin,
        t.mascaraAguila,
        t.mascaraRana,
        t.mascaraErizo,
        t.mascaraKoala,
        t.mascaraNutria,
      ];
}

/// Círculo con el emoji de la máscara, teñido de su color.
class InsigniaMascara extends StatelessWidget {
  final int indice;
  final double radio;

  const InsigniaMascara({super.key, required this.indice, this.radio = 18});

  @override
  Widget build(BuildContext context) {
    final mascara = Mascara.de(indice);
    return CircleAvatar(
      radius: radio,
      backgroundColor: mascara.color.withValues(alpha: 0.22),
      child: Text(mascara.emoji, style: TextStyle(fontSize: radio * 1.05)),
    );
  }
}
