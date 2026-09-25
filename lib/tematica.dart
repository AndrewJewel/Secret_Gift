import 'package:flutter/material.dart';

import 'glass.dart';
import 'l10n/app_localizations.dart';
import 'marca.dart';
import 'ocasion.dart';

/// Una temática es la piel completa del grupo: su paleta, su fondo y su
/// modo de registro.
///
/// - [Tematica.ninguna]: cada quien con su nombre real y su foto. La
///   paleta la pone la ocasión, o el color que elija el organizador.
/// - [Tematica.empresarial]: también con nombre real y foto, pero con
///   paleta y fondo corporativos.
/// - Las demás: cada quien se registra con un personaje y la imagen de
///   ese personaje, y la paleta la manda la temática.
///
/// Los fondos de las temáticas son ilustraciones (assets/fondos), en una
/// versión horizontal para PC y otra vertical para móvil. Sin temática se
/// dibujan manchas por código, para que tomen el color que se elija.
enum Tematica {
  ninguna,
  caricaturas,
  alfombraRoja,
  navidad,
  empresarial;

  static Tematica desdeId(String? id) {
    return Tematica.values.firstWhere(
      (t) => t.id == id,
      orElse: () => Tematica.ninguna,
    );
  }

  String get id => switch (this) {
        Tematica.ninguna => '',
        Tematica.caricaturas => 'caricaturas',
        Tematica.alfombraRoja => 'alfombra_roja',
        Tematica.navidad => 'navidad',
        Tematica.empresarial => 'empresarial',
      };

  String titulo(Textos t) => switch (this) {
        Tematica.ninguna => t.tematicaNombreNinguna,
        Tematica.caricaturas => t.tematicaNombreCaricaturas,
        Tematica.alfombraRoja => t.tematicaNombreAlfombraRoja,
        Tematica.navidad => t.tematicaNombreNavidad,
        Tematica.empresarial => t.tematicaNombreEmpresarial,
      };

  String descripcion(Textos t) => switch (this) {
        Tematica.ninguna => t.tematicaDescNinguna,
        Tematica.caricaturas => t.tematicaDescCaricaturas,
        Tematica.alfombraRoja => t.tematicaDescAlfombraRoja,
        Tematica.navidad => t.tematicaDescNavidad,
        Tematica.empresarial => t.tematicaDescEmpresarial,
      };

  IconData get icono => switch (this) {
        Tematica.ninguna => Icons.groups_outlined,
        Tematica.caricaturas => Icons.auto_awesome_motion_outlined,
        Tematica.alfombraRoja => Icons.star_outline,
        Tematica.navidad => Icons.ac_unit_outlined,
        Tematica.empresarial => Icons.business_center_outlined,
      };

  /// Con personajes, nadie usa su nombre real. Empresarial no: en una
  /// oficina todos se conocen por su nombre.
  bool get usaPersonajes => this != Tematica.ninguna && this != Tematica.empresarial;

  /// Etiquetas del formulario de registro. Es la misma pantalla; solo
  /// cambian las palabras según el grupo sea temático o no.
  String etiquetaNombre(Textos t) =>
      usaPersonajes ? t.tematicaNombreCampoPersonaje : t.tematicaNombreCampoNormal;

  String pistaNombre(Textos t) => switch (this) {
        Tematica.ninguna || Tematica.empresarial => t.tematicaPistaNinguna,
        Tematica.caricaturas => t.tematicaPistaCaricaturas,
        Tematica.alfombraRoja => t.tematicaPistaAlfombraRoja,
        Tematica.navidad => t.tematicaPistaNavidad,
      };

  String etiquetaImagen(Textos t) =>
      usaPersonajes ? t.tematicaImagenPersonaje : t.tematicaImagenNormal;

  /// Texto que aparece en la caja de reglas cuando se crea el grupo. El
  /// organizador lo puede reescribir completo desde el modo organizador.
  String reglasPorDefecto(Textos t) => switch (this) {
        Tematica.ninguna => t.reglasNinguna,
        Tematica.caricaturas => t.reglasCaricaturas,
        Tematica.alfombraRoja => t.reglasAlfombraRoja,
        Tematica.navidad => t.reglasNavidad,
        Tematica.empresarial => t.reglasEmpresarial,
      };

  /// El color que tiñe el vidrio, los títulos y los botones. Sin temática
  /// manda el color que eligió el organizador ([personal]) o, si no eligió
  /// ninguno, la ocasión. Con temática manda la temática y [personal] se
  /// ignora.
  MaterialColor colorDe(Ocasion ocasion, [Color? personal]) => switch (this) {
        Tematica.ninguna => personal != null ? escalaDe(personal) : ocasion.colorBase,
        Tematica.caricaturas => escalaDe(const Color(0xFF1565C0)),
        Tematica.alfombraRoja => rojoMarca,
        Tematica.navidad => rojoMarca,
        Tematica.empresarial => escalaDe(const Color(0xFF1F3A5F)),
      };

  /// Degradado de base: es todo el fondo sin temática, y lo que se ve
  /// detrás de la ilustración mientras carga. Por eso va en el tono
  /// dominante de cada ilustración.
  List<Color> gradienteDe(Ocasion ocasion, [Color? personal]) => switch (this) {
        Tematica.ninguna => [Colors.white, colorDe(ocasion, personal).shade50],
        Tematica.caricaturas => const [Color(0xFFFFF8E1), Color(0xFFFFEFC2)],
        Tematica.alfombraRoja => const [Color(0xFF07070B), Color(0xFF2A0A0E)],
        Tematica.navidad => const [Color(0xFFFBF1EF), Color(0xFFF6E1DF)],
        Tematica.empresarial => const [Color(0xFFF3F5F9), Color(0xFFE2E7EF)],
      };

  /// Los fondos oscuros (alfombra roja) necesitan texto claro en lo que va
  /// suelto sobre el fondo; el texto dentro del vidrio siempre va oscuro,
  /// porque el vidrio es claro en todas las temáticas.
  bool get fondoOscuro => this == Tematica.alfombraRoja;

  /// Ilustración de fondo, o null sin temática. [vertical] elige la
  /// versión 9:16 (móvil) en vez de la 16:9 (PC).
  String? imagenFondo({required bool vertical}) =>
      this == Tematica.ninguna ? null : 'assets/fondos/${id}_${vertical ? 'v' : 'h'}.jpg';
}

/// El color propio del grupo viaja a Firestore como '#RRGGBB'. Vacío o
/// mal formado = sin color propio.
Color? colorDesdeHex(String? hex) {
  if (hex == null || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(hex)) return null;
  return Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
}

String hexDe(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Genera una escala Material completa a partir de un color de marca, para
/// poder usar colores propios con los widgets de vidrio (que piden
/// shade50/shade200/shade800). Los tonos claros se acercan al blanco y los
/// oscuros al negro.
MaterialColor escalaDe(Color base) {
  Color mezclar(Color otro, double t) => Color.lerp(base, otro, t)!;
  return MaterialColor(base.toARGB32(), {
    50: mezclar(Colors.white, 0.88),
    100: mezclar(Colors.white, 0.78),
    200: mezclar(Colors.white, 0.62),
    300: mezclar(Colors.white, 0.45),
    400: mezclar(Colors.white, 0.25),
    500: base,
    600: mezclar(Colors.black, 0.12),
    700: mezclar(Colors.black, 0.24),
    800: mezclar(Colors.black, 0.36),
    900: mezclar(Colors.black, 0.50),
  });
}

/// Pinta el fondo de la temática detrás de todo el contenido. Es estático:
/// se dibuja una vez y no se repinta al hacer scroll ni al escribir.
class FondoTematico extends StatelessWidget {
  final Tematica tematica;
  final Ocasion ocasion;

  /// Color propio del grupo; solo cuenta sin temática.
  final Color? colorPersonal;
  final Widget child;

  const FondoTematico({
    super.key,
    required this.tematica,
    required this.ocasion,
    this.colorPersonal,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: tematica.gradienteDe(ocasion, colorPersonal),
        ),
      ),
      child: EstiloFondo(
        // Le avisa a todo el vidrio de abajo si está sobre fondo oscuro,
        // para que suba su opacidad y aclare las etiquetas.
        oscuro: tematica.fondoOscuro,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // RepaintBoundary para que el fondo no se redibuje cada vez
            // que cambia lo de encima (scroll, chat en vivo). Y
            // LayoutBuilder para que el pintor reciba el tamaño: es lo
            // que le permite CADUCAR la caché cuando la ventana cambia.
            // Sin eso, al abrirse el teclado el fondo quedaba estirado.
            RepaintBoundary(
              child: LayoutBuilder(builder: (context, restricciones) {
                final tamano = restricciones.biggest;
                final imagen = tematica.imagenFondo(vertical: tamano.height > tamano.width);
                if (imagen == null) {
                  return CustomPaint(
                    painter: _FondoBlobs(tematica.colorDe(ocasion, colorPersonal), tamano),
                  );
                }
                // cover: llena la pantalla recortando lo que sobre. Las
                // ilustraciones tienen el detalle en los bordes y el centro
                // despejado, así que el recorte nunca se come lo importante.
                return Image.asset(imagen, fit: BoxFit.cover, gaplessPlayback: true);
              }),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

/// Fondo de las pantallas que no pertenecen a ningún grupo (inicio,
/// cuenta, unirse, mis grupos): las mismas manchas suaves, en el color de
/// la marca.
///
/// No es decoración: sin algo con forma detrás, el BackdropFilter del
/// vidrio esmerilado desenfoca un color plano y no se percibe nada.
class FondoNeutro extends StatelessWidget {
  final Widget child;

  const FondoNeutro({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradienteNeutro,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: LayoutBuilder(
              builder: (context, restricciones) =>
                  CustomPaint(painter: _FondoBlobs(colorNeutro, restricciones.biggest)),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

// --- Fondos -----------------------------------------------------------
// Todos guardan el tamaño con el que se dibujaron y lo comparan en
// shouldRepaint. Son estáticos MIENTRAS la ventana no cambie: si cambia
// hay que redibujarlos, o queda el dibujo anterior estirado con huecos
// (que es justo lo que pasaba al abrirse el teclado en el celular).

/// Sin temática: manchas suaves del color de la ocasión. Discreto, pero le
/// da al vidrio algo que desenfocar.
class _FondoBlobs extends CustomPainter {
  final MaterialColor color;
  final Size tamano;

  const _FondoBlobs(this.color, this.tamano);

  @override
  void paint(Canvas canvas, Size size) {
    // Manchas contenidas y pegadas a las esquinas, con el centro
    // despejado. El vidrio necesita CONTRASTE detrás, no color: manchas
    // enormes y muy desenfocadas se funden en un tinte plano y uniforme
    // que deja el fondo tan liso como si no hubiera nada —justo lo que
    // se venía a evitar— y además ensucia el blanco.
    final manchas = [
      (Offset(size.width * 0.02, size.height * 0.08), size.shortestSide * 0.26, 0.42),
      (Offset(size.width * 1.00, size.height * 0.24), size.shortestSide * 0.22, 0.34),
      (Offset(size.width * 0.04, size.height * 0.90), size.shortestSide * 0.28, 0.30),
      (Offset(size.width * 0.98, size.height * 1.00), size.shortestSide * 0.24, 0.40),
    ];
    for (final (centro, radio, opacidad) in manchas) {
      canvas.drawCircle(
        centro,
        radio,
        Paint()
          ..color = color.shade200.withValues(alpha: opacidad)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radio * 0.35),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FondoBlobs old) =>
      old.color != color || old.tamano != tamano;
}
