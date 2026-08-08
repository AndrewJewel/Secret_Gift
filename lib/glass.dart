import 'dart:ui';
import 'package:flutter/material.dart';

import 'marca.dart';

/// Widgets del look Glassmorphism: fondo blanco + vidrio esmerilado teñido
/// con el color de cada ocasión (azul o rojo) para tarjetas, campos y barras.

/// Color de las pantallas sin ocasión asignada (inicio, cuenta, unirse):
/// el carmín del logo, para que la marca se vea desde el primer segundo.
const colorNeutro = rojoMarca;

/// Avisa al vidrio si el fondo de la temática es oscuro. Lo pone
/// FondoTematico una sola vez arriba del árbol y lo leen todos los
/// widgets de vidrio, sin tener que pasar la bandera pantalla por
/// pantalla.
///
/// Importa por dos cosas:
///  - Las etiquetas de los campos van FUERA del vidrio, así que su color
///    lo manda el fondo. Sobre rojo oscuro tienen que ser claras.
///  - Sobre un fondo oscuro el vidrio necesita más cuerpo, o el texto
///    negro de adentro se queda sin contraste.
class EstiloFondo extends InheritedWidget {
  final bool oscuro;

  const EstiloFondo({super.key, required this.oscuro, required super.child});

  static bool esOscuro(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EstiloFondo>()?.oscuro ?? false;

  @override
  bool updateShouldNotify(EstiloFondo anterior) => anterior.oscuro != oscuro;
}

// --- Receta del vidrio ------------------------------------------------
// Las tres piezas que hacen que un rectángulo translúcido se lea como un
// panel de vidrio y no como una tarjeta pintada:
//   1. relleno BLANCO y muy translúcido (no un color casi opaco),
//   2. un filo claro que simula la luz pegando en el canto,
//   3. una sombra difusa que lo despega del fondo.
// Falta cualquiera de las tres y el efecto se cae.

const _desenfoqueVidrio = 16.0;

/// Relleno: blanco dominante con un toque del color del tema.
///
/// Sobre fondo oscuro sube la opacidad. No es capricho: al 45% sobre
/// negro queda un gris medio y el texto oscuro de dentro se cae por
/// debajo del mínimo de contraste. Al 62% sigue viéndose el fondo a
/// través, que es lo que importa.
Color _rellenoVidrio(MaterialColor color, bool sobreOscuro) =>
    Color.lerp(Colors.white, color.shade100, 0.30)!
        .withValues(alpha: sobreOscuro ? 0.62 : 0.45);

/// Filo claro del canto. Es la pieza que más aporta a la ilusión.
BorderSide _ladoVidrio(MaterialColor color, bool sobreOscuro) => BorderSide(
      color: Color.lerp(Colors.white, color.shade200, 0.35)!
          .withValues(alpha: sobreOscuro ? 0.55 : 0.80),
      width: 1.5,
    );

Border _bordeVidrio(MaterialColor color, bool sobreOscuro) =>
    Border.fromBorderSide(_ladoVidrio(color, sobreOscuro));

/// Sombra difusa, teñida del color de la marca en vez de negro puro:
/// sobre fondos claros un negro plano se ve sucio.
List<BoxShadow> _sombraVidrio(MaterialColor color) => [
      BoxShadow(
        color: color.shade900.withValues(alpha: 0.10),
        blurRadius: 25,
        spreadRadius: -5,
        offset: const Offset(0, 6),
      ),
    ];

/// Fondo base: casi blanco, con un toque muy sutil del color de la
/// ocasión — el blanco manda, el color solo acentúa.
class FondoDegradado extends StatelessWidget {
  final List<Color> colores;
  final Widget child;

  const FondoDegradado({super.key, required this.colores, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colores,
        ),
      ),
      child: child,
    );
  }
}

/// Tarjeta de vidrio esmerilado: blur + tinte de color + borde sutil.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final MaterialColor color;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.color = colorNeutro,
  });

  @override
  Widget build(BuildContext context) {
    final sobreOscuro = EstiloFondo.esOscuro(context);
    // La sombra va FUERA del ClipRRect a propósito. Dentro, el recorte se
    // la come y no se ve nada — es el error clásico de este patrón.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: _sombraVidrio(color),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _desenfoqueVidrio, sigmaY: _desenfoqueVidrio),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: _rellenoVidrio(color, sobreOscuro),
              borderRadius: BorderRadius.circular(radius),
              border: _bordeVidrio(color, sobreOscuro),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// AppBar de vidrio: blanco translúcido + blur, título/íconos en el color
/// de la ocasión.
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final List<Widget>? actions;
  final Widget? leading;
  final MaterialColor color;

  const GlassAppBar(
      {super.key, required this.title, this.actions, this.leading, this.color = colorNeutro});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: AppBar(
          title: DefaultTextStyle.merge(
            style: TextStyle(color: color.shade800, fontWeight: FontWeight.w600),
            child: title,
          ),
          actions: actions,
          leading: leading,
          backgroundColor: Colors.white.withValues(alpha: 0.6),
          foregroundColor: color.shade800,
          iconTheme: IconThemeData(color: color.shade800),
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
      ),
    );
  }
}

/// Campo de texto con acabado de vidrio: etiqueta SIEMPRE fija arriba (no
/// flotante) a propósito — combinar BackdropFilter con la etiqueta
/// flotante estándar de Flutter la recorta a la mitad, es un problema
/// conocido. Con etiqueta fija se evita el bug por completo.
class GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final String? helperText;
  final IconData? icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final Widget? suffixIcon;
  final MaterialColor color;
  final int maxLines;

  /// Alto inicial en líneas. Sin esto, un campo con maxLines: 4 nace ya
  /// con 4 líneas de alto en vez de crecer a medida que se escribe.
  final int minLines;

  const GlassTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.helperText,
    this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.suffixIcon,
    this.color = colorNeutro,
    this.maxLines = 1,
    this.minLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    // La etiqueta y el texto de ayuda van fuera del vidrio, sobre el fondo
    // de la temática: si el fondo es oscuro tienen que ir claros.
    final sobreOscuro = EstiloFondo.esOscuro(context);
    final colorEtiqueta = sobreOscuro ? Colors.white : color.shade800;
    final colorAyuda = sobreOscuro ? Colors.white70 : Colors.black54;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sin etiqueta no se reserva su renglón: en el redactor del chat
        // dejaba un hueco muerto encima del campo.
        if (labelText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(labelText,
                style: TextStyle(color: colorEtiqueta, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: _sombraVidrio(color),
          ),
          child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: _desenfoqueVidrio, sigmaY: _desenfoqueVidrio),
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              // Un campo de varias líneas necesita teclado multilínea para
              // que el Enter salte de renglón en vez de cerrar el teclado.
              keyboardType: maxLines > 1 ? TextInputType.multiline : keyboardType,
              maxLines: obscureText ? 1 : maxLines,
              minLines: obscureText ? 1 : minLines,
              textCapitalization: textCapitalization,
              style: const TextStyle(color: Colors.black87),
              cursorColor: color.shade600,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(color: Colors.black38),
                prefixIcon: icon != null ? Icon(icon, color: color.shade700) : null,
                suffixIcon: suffixIcon,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                filled: true,
                fillColor: _rellenoVidrio(color, sobreOscuro),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: _ladoVidrio(color, sobreOscuro),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: _ladoVidrio(color, sobreOscuro),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: color.shade600, width: 2),
                ),
              ),
            ),
          ),
          ),
        ),
        if (helperText != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Text(helperText!, style: TextStyle(color: colorAyuda, fontSize: 12)),
          ),
      ],
    );
  }
}

/// Botón principal: relleno sólido del color de la ocasión, para que
/// destaque como acento sobre el fondo blanco.
class GlassButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color color;
  final Widget? trailing;

  const GlassButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    required this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: trailing ?? (icon != null ? Icon(icon) : const SizedBox.shrink()),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: color.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

/// Botón secundario, de solo vidrio (borde y texto del color de la ocasión).
class GlassOutlineButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final MaterialColor color;

  const GlassOutlineButton(
      {super.key, required this.label, this.icon, required this.onPressed, this.color = colorNeutro});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: _sombraVidrio(color),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: _desenfoqueVidrio, sigmaY: _desenfoqueVidrio),
            child: OutlinedButton.icon(
              onPressed: onPressed,
              icon: icon != null ? Icon(icon, color: color.shade700) : const SizedBox.shrink(),
              label:
                  Text(label, style: TextStyle(color: color.shade700, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                backgroundColor: _rellenoVidrio(color, EstiloFondo.esOscuro(context)),
                side: _ladoVidrio(color, EstiloFondo.esOscuro(context)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
