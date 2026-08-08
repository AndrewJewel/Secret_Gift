import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'l10n/app_localizations.dart';
import 'marca.dart';

/// Cada ocasión define el degradado de fondo y los textos del grupo.
/// Para agregar una ocasión nueva: un caso más en el enum + sus getters.
enum Ocasion {
  amigoSecreto,
  santaSecreto;

  static Ocasion desdeId(String id) {
    return Ocasion.values.firstWhere(
      (o) => o.id == id,
      orElse: () => Ocasion.amigoSecreto,
    );
  }

  String get id => switch (this) {
        Ocasion.amigoSecreto => 'amigo_secreto',
        Ocasion.santaSecreto => 'santa_secreto',
      };

  String titulo(Textos t) => switch (this) {
        Ocasion.amigoSecreto => t.ocasionAmigoSecreto,
        Ocasion.santaSecreto => t.ocasionSantaSecreto,
      };

  String get emoji => switch (this) {
        Ocasion.amigoSecreto => '🎁',
        Ocasion.santaSecreto => '🎅',
      };

  /// Las dos ocasiones se distinguen con los dos colores del logo: oro
  /// para Amigo Secreto, carmín para Santa Secreto. Antes eran azul y
  /// rojo genéricos, ajenos a la marca.
  MaterialColor get colorBase => switch (this) {
        Ocasion.amigoSecreto => oroMarca,
        Ocasion.santaSecreto => rojoMarca,
      };

  /// El blanco manda: fondo casi blanco, con apenas un toque del color de
  /// la ocasión hacia abajo. El color vive en las tarjetas y los títulos,
  /// no en el fondo.
  List<Color> get gradiente => [Colors.white, colorBase.shade50];

  ThemeData get tema => temaGlass(colorBase);
}

/// Degradado blanco neutro para pantallas sin ocasión (inicio, cuenta).
List<Color> get gradienteNeutro => [Colors.white, rojoMarca.shade50];

/// Estilo de título de tarjeta, pedido por color en vez de por contexto.
///
/// Existe para esquivar una trampa de Flutter: dentro de build(),
/// Theme.of(context) devuelve el tema ANCESTRO, no el Theme que ese mismo
/// build está insertando más abajo. El resultado es un título pintado con
/// el color equivocado sin que nada falle ni avise.
TextStyle tituloGlass(MaterialColor color) => GoogleFonts.fredoka(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: color.shade800,
    );

/// Fredoka para títulos/botones (redondeado, festivo), Nunito para el
/// cuerpo del texto (legible, amigable). Fondo claro, texto oscuro.
ThemeData temaGlass(MaterialColor colorBase) {
  final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
  return base.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    textTheme: GoogleFonts.nunitoTextTheme(base.textTheme).copyWith(
      titleLarge: GoogleFonts.fredoka(fontSize: 22, fontWeight: FontWeight.w600, color: colorBase.shade800),
      titleMedium: GoogleFonts.fredoka(fontSize: 18, fontWeight: FontWeight.w600, color: colorBase.shade800),
      bodyLarge: GoogleFonts.nunito(color: Colors.black87),
      bodyMedium: GoogleFonts.nunito(color: Colors.black54),
    ),
    colorScheme: ColorScheme.fromSeed(seedColor: colorBase, brightness: Brightness.light),
  );
}
