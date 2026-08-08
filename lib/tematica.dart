import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'glass.dart';
import 'l10n/app_localizations.dart';
import 'marca.dart';
import 'ocasion.dart';

/// Una temática es la piel completa del grupo: su paleta, su fondo y su
/// modo de registro.
///
/// - [Tematica.ninguna]: cada quien se registra con su nombre real y su
///   foto. La paleta la pone la ocasión (azul o rojo), como hasta ahora.
/// - Cualquier otra: cada quien se registra con un personaje y la imagen
///   de ese personaje, y la paleta la manda la temática.
///
/// Los fondos se dibujan con código, no con imágenes: pesan cero, se ven
/// nítidos en cualquier pantalla y —lo importante— tienen formas y color
/// detrás del vidrio esmerilado, que es lo único que hace visible el
/// desenfoque. Sobre un fondo blanco plano, el BackdropFilter no se nota.
enum Tematica {
  ninguna,
  caricaturas,
  alfombraRoja,
  navidad;

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
      };

  String titulo(Textos t) => switch (this) {
        Tematica.ninguna => t.tematicaNombreNinguna,
        Tematica.caricaturas => t.tematicaNombreCaricaturas,
        Tematica.alfombraRoja => t.tematicaNombreAlfombraRoja,
        Tematica.navidad => t.tematicaNombreNavidad,
      };

  String descripcion(Textos t) => switch (this) {
        Tematica.ninguna => t.tematicaDescNinguna,
        Tematica.caricaturas => t.tematicaDescCaricaturas,
        Tematica.alfombraRoja => t.tematicaDescAlfombraRoja,
        Tematica.navidad => t.tematicaDescNavidad,
      };

  IconData get icono => switch (this) {
        Tematica.ninguna => Icons.groups_outlined,
        Tematica.caricaturas => Icons.auto_awesome_motion_outlined,
        Tematica.alfombraRoja => Icons.star_outline,
        Tematica.navidad => Icons.ac_unit_outlined,
      };

  /// Con temática, nadie usa su nombre real: se registra como su personaje.
  bool get usaPersonajes => this != Tematica.ninguna;

  /// Etiquetas del formulario de registro. Es la misma pantalla; solo
  /// cambian las palabras según el grupo sea temático o no.
  String etiquetaNombre(Textos t) =>
      usaPersonajes ? t.tematicaNombreCampoPersonaje : t.tematicaNombreCampoNormal;

  String pistaNombre(Textos t) => switch (this) {
        Tematica.ninguna => t.tematicaPistaNinguna,
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
      };

  /// El color que tiñe el vidrio, los títulos y los botones. Sin temática
  /// manda la ocasión; con temática manda la temática.
  MaterialColor colorDe(Ocasion ocasion) => switch (this) {
        Tematica.ninguna => ocasion.colorBase,
        Tematica.caricaturas => _swatch(const Color(0xFF1565C0)),
        Tematica.alfombraRoja => rojoMarca,
        // Rojo, no verde: el verde queda solo para los abetos del fondo.
        Tematica.navidad => rojoMarca,
      };

  /// Degradado de base del fondo. Encima va el dibujo de [pintorFondo].
  List<Color> gradienteDe(Ocasion ocasion) => switch (this) {
        Tematica.ninguna => ocasion.gradiente,
        Tematica.caricaturas => const [Color(0xFFFFF1C4), Color(0xFFFFD84D)],
        // Noche de estreno: negro. El único rojo de la escena es la
        // alfombra, no el fondo.
        Tematica.alfombraRoja => const [Color(0xFF07070B), Color(0xFF16121C)],
        // Rojo y blanco, los colores de Santa. El verde se reserva para
        // los abetos, que es donde toca.
        Tematica.navidad => const [Color(0xFFFFFFFF), Color(0xFFF6D9DC)],
      };

  /// Los fondos oscuros (alfombra roja) necesitan texto claro en lo que va
  /// suelto sobre el fondo; el texto dentro del vidrio siempre va oscuro,
  /// porque el vidrio es claro en todas las temáticas.
  bool get fondoOscuro => this == Tematica.alfombraRoja;

  /// El [tamano] se le entrega al pintor SOLO para que pueda decidir en
  /// shouldRepaint si hace falta redibujar. Sin él, el fondo se quedaba
  /// cacheado del tamaño anterior y al abrirse el teclado del celular
  /// aparecía estirado y con huecos sin pintar.
  CustomPainter pintorFondo(Ocasion ocasion, Size tamano) => switch (this) {
        Tematica.ninguna => _FondoBlobs(ocasion.colorBase, tamano),
        Tematica.caricaturas => _FondoCaricaturas(tamano),
        Tematica.alfombraRoja => _FondoAlfombraRoja(tamano),
        Tematica.navidad => _FondoNavidad(tamano),
      };
}

/// Genera una escala Material completa a partir de un color de marca, para
/// poder usar colores propios con los widgets de vidrio (que piden
/// shade50/shade200/shade800). Los tonos claros se acercan al blanco y los
/// oscuros al negro.
MaterialColor _swatch(Color base) {
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
  final Widget child;

  const FondoTematico({
    super.key,
    required this.tematica,
    required this.ocasion,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: tematica.gradienteDe(ocasion),
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
              child: LayoutBuilder(
                builder: (context, restricciones) => CustomPaint(
                  painter: tematica.pintorFondo(ocasion, restricciones.biggest),
                ),
              ),
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

/// Caricaturas: pop-art de cómic. Rayos diagonales saliendo de una esquina,
/// puntos de medio tono (los Ben-Day de las viñetas impresas) y un estallido
/// de estrella. Primarios saturados, sin medias tintas.
class _FondoCaricaturas extends CustomPainter {
  final Size tamano;

  const _FondoCaricaturas(this.tamano);

  static const _rojo = Color(0xFFFF5252);
  static const _cyan = Color(0xFF26C6DA);
  static const _azul = Color(0xFF1565C0);

  @override
  void paint(Canvas canvas, Size size) {
    // Rayos que salen desde arriba a la izquierda, como una viñeta de acción.
    final origen = Offset(size.width * 0.08, -size.height * 0.05);
    final largo = size.longestSide * 1.6;
    final rayo = Paint()..color = Colors.white.withValues(alpha: 0.38);
    for (int i = 0; i < 11; i++) {
      final desde = (i * 15.5 + 8) * math.pi / 180;
      final hasta = desde + 6.5 * math.pi / 180;
      canvas.drawPath(
        Path()
          ..moveTo(origen.dx, origen.dy)
          ..lineTo(origen.dx + largo * math.cos(desde), origen.dy + largo * math.sin(desde))
          ..lineTo(origen.dx + largo * math.cos(hasta), origen.dy + largo * math.sin(hasta))
          ..close,
        rayo,
      );
    }

    _puntosMedioTono(canvas, size);

    // Estallido de estrella abajo a la derecha, el "¡POW!" de las viñetas.
    _estallido(
      canvas,
      Offset(size.width * 0.86, size.height * 0.80),
      size.shortestSide * 0.24,
      _rojo.withValues(alpha: 0.75),
    );
    _estallido(
      canvas,
      Offset(size.width * 0.86, size.height * 0.80),
      size.shortestSide * 0.17,
      Colors.white.withValues(alpha: 0.85),
    );

    // Franja de color al pie, anclada al borde: da peso abajo sin que
    // ninguna forma quede flotando suelta en medio de la pantalla, donde
    // se leería como un elemento de la interfaz y no como fondo.
    final franja = Path()
      ..moveTo(0, size.height * 0.88)
      ..quadraticBezierTo(
          size.width * 0.30, size.height * 0.82, size.width * 0.62, size.height * 0.90)
      ..lineTo(size.width * 0.62, size.height)
      ..lineTo(0, size.height)
      ..close;
    canvas.drawPath(franja, Paint()..color = _cyan.withValues(alpha: 0.45));
  }

  /// Retícula de puntos que se van encogiendo, como la trama de impresión
  /// de un cómic viejo.
  void _puntosMedioTono(Canvas canvas, Size size) {
    final paso = size.shortestSide * 0.052;
    final pintura = Paint()..color = _azul.withValues(alpha: 0.20);
    for (int fila = 0; fila < 7; fila++) {
      for (int col = 0; col < 7; col++) {
        final x = size.width - paso * (col + 0.8);
        final y = paso * (fila + 0.8);
        final radio = paso * 0.30 * (1 - (fila + col) / 16);
        if (radio > 0.6) canvas.drawCircle(Offset(x, y), radio, pintura);
      }
    }
  }

  void _estallido(Canvas canvas, Offset centro, double radio, Color color) {
    const puntas = 12;
    final path = Path();
    for (int i = 0; i < puntas * 2; i++) {
      final r = i.isEven ? radio : radio * 0.62;
      final a = i * math.pi / puntas - math.pi / 2;
      final p = Offset(centro.dx + r * math.cos(a), centro.dy + r * math.sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path..close, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _FondoCaricaturas old) => old.tamano != tamano;
}

/// Alfombra roja: noche de estreno. Negro, focos, luces desenfocadas y
/// flashes de prensa. **Lo único rojo de la escena es la alfombra**, con
/// sus cordones dorados a los lados.
class _FondoAlfombraRoja extends CustomPainter {
  final Size tamano;

  const _FondoAlfombraRoja(this.tamano);

  static const _oro = Color(0xFFE8C56A);
  static const _rojoAlfombra = Color(0xFFA5122A);
  static const _rojoAlfombraCerca = Color(0xFFD22440);

  /// Dónde empieza la alfombra y cuánto se abre en perspectiva.
  static const _yLejos = 0.68;
  static const _xLejosIzq = 0.37;
  static const _xLejosDer = 0.63;
  static const _xCercaIzq = -0.10;
  static const _xCercaDer = 1.10;

  @override
  void paint(Canvas canvas, Size size) {
    _bokeh(canvas, size);
    _reflectores(canvas, size);
    _alfombra(canvas, size);
    _cordones(canvas, size);
    _flashes(canvas, size);
  }

  /// Luces desenfocadas del fondo: el público y los carteles del estreno,
  /// fuera de foco. Son lo que da sensación de noche con gente.
  void _bokeh(Canvas canvas, Size size) {
    final azar = math.Random(2026);
    for (int i = 0; i < 22; i++) {
      final centro = Offset(
        azar.nextDouble() * size.width,
        size.height * (0.05 + azar.nextDouble() * 0.60),
      );
      final radio = size.shortestSide * (0.02 + azar.nextDouble() * 0.055);
      final calido = azar.nextBool();
      canvas.drawCircle(
        centro,
        radio,
        Paint()
          ..color = (calido ? _oro : Colors.white)
              .withValues(alpha: 0.06 + azar.nextDouble() * 0.10)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radio * 0.75),
      );
    }
  }

  /// Conos de luz desde arriba. Sobre negro pueden ser mucho más
  /// marcados que sobre un fondo claro sin quemar nada.
  void _reflectores(Canvas canvas, Size size) {
    final focos = [
      (0.16, 0.02, 0.46),
      (0.52, 0.30, 0.76),
      (0.84, 0.62, 1.10),
    ];
    final alto = size.height * _yLejos + size.height * 0.12;
    for (final (origen, izq, der) in focos) {
      final cono = Path()
        ..moveTo(size.width * origen, -size.height * 0.03)
        ..lineTo(size.width * izq, alto)
        ..lineTo(size.width * der, alto)
        ..close;
      canvas.drawPath(
        cono,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.20),
              _oro.withValues(alpha: 0.07),
              Colors.transparent,
            ],
            stops: const [0.0, 0.40, 1.0],
          ).createShader(Rect.fromLTWH(0, 0, size.width, alto)),
      );
    }
  }

  /// La alfombra en perspectiva: cuerpo con degradado (más oscura al
  /// fondo, más viva cerca), franja lateral más oscura como ribete, filo
  /// dorado y los charcos de luz que le caen encima de los focos.
  void _alfombra(Canvas canvas, Size size) {
    Offset borde(double t, bool izquierda) {
      final y = size.height * (_yLejos + (1 - _yLejos) * t);
      final xLejos = izquierda ? _xLejosIzq : _xLejosDer;
      final xCerca = izquierda ? _xCercaIzq : _xCercaDer;
      return Offset(size.width * (xLejos + (xCerca - xLejos) * t), y);
    }

    final cuerpo = Path()
      ..moveTo(borde(0, true).dx, borde(0, true).dy)
      ..lineTo(borde(0, false).dx, borde(0, false).dy)
      ..lineTo(borde(1, false).dx, borde(1, false).dy)
      ..lineTo(borde(1, true).dx, borde(1, true).dy)
      ..close;

    final arriba = size.height * _yLejos;
    canvas.drawPath(
      cuerpo,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_rojoAlfombra, _rojoAlfombraCerca],
        ).createShader(Rect.fromLTWH(0, arriba, size.width, size.height - arriba)),
    );

    // Ribete interior más oscuro a cada lado, como el borde cosido de una
    // alfombra de verdad.
    for (final izquierda in [true, false]) {
      final desplazamiento = size.width * (izquierda ? 0.045 : -0.045);
      final ribete = Path()
        ..moveTo(borde(0, izquierda).dx, borde(0, izquierda).dy)
        ..lineTo(borde(0, izquierda).dx + desplazamiento * 0.35, borde(0, izquierda).dy)
        ..lineTo(borde(1, izquierda).dx + desplazamiento, borde(1, izquierda).dy)
        ..lineTo(borde(1, izquierda).dx, borde(1, izquierda).dy)
        ..close;
      canvas.drawPath(ribete, Paint()..color = Colors.black.withValues(alpha: 0.22));
    }

    // Filo dorado.
    final filo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.008
      ..color = _oro.withValues(alpha: 0.9);
    canvas.drawLine(borde(0, true), borde(1, true), filo);
    canvas.drawLine(borde(0, false), borde(1, false), filo);
    canvas.drawLine(borde(0, true), borde(0, false), filo);

    // Charcos de luz de los focos sobre la alfombra.
    canvas.save();
    canvas.clipPath(cuerpo);
    for (final (cx, cy, rx) in [(0.30, 0.80, 0.26), (0.62, 0.92, 0.32)]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * cx, size.height * cy),
          width: size.width * rx * 2,
          height: size.height * 0.10,
        ),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.10)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.shortestSide * 0.05),
      );
    }
    canvas.restore();
  }

  /// Los postes con cordón dorado a los lados. Es el detalle que hace que
  /// se lea "alfombra roja" y no "rampa roja".
  void _cordones(Canvas canvas, Size size) {
    final poste = Paint()
      ..color = _oro.withValues(alpha: 0.85)
      ..strokeCap = StrokeCap.round;
    final cuerda = Paint()
      ..style = PaintingStyle.stroke
      ..color = _oro.withValues(alpha: 0.55)
      ..strokeCap = StrokeCap.round;

    for (final izquierda in [true, false]) {
      final cabezas = <Offset>[];
      for (final t in [0.10, 0.45, 0.85]) {
        final y = size.height * (_yLejos + (1 - _yLejos) * t);
        final xLejos = izquierda ? _xLejosIzq : _xLejosDer;
        final xCerca = izquierda ? _xCercaIzq : _xCercaDer;
        // Un pelo por fuera del borde de la alfombra.
        final fuera = size.width * (izquierda ? -0.03 : 0.03);
        final x = size.width * (xLejos + (xCerca - xLejos) * t) + fuera;
        // Los de adelante son más altos y más gruesos: perspectiva.
        final alto = size.height * (0.045 + 0.075 * t);
        final grosor = size.shortestSide * (0.006 + 0.008 * t);

        poste.strokeWidth = grosor;
        canvas.drawLine(Offset(x, y), Offset(x, y - alto), poste);
        canvas.drawCircle(Offset(x, y - alto), grosor * 1.5, poste);
        cabezas.add(Offset(x, y - alto));
      }

      // Cuerda colgando entre postes, con su curva.
      cuerda.strokeWidth = size.shortestSide * 0.006;
      for (int i = 0; i < cabezas.length - 1; i++) {
        final a = cabezas[i];
        final b = cabezas[i + 1];
        final caida = (b.dy - a.dy).abs() * 0.25 + size.height * 0.022;
        canvas.drawPath(
          Path()
            ..moveTo(a.dx, a.dy)
            ..quadraticBezierTo(
                (a.dx + b.dx) / 2, (a.dy + b.dy) / 2 + caida, b.dx, b.dy),
          cuerda,
        );
      }
    }
  }

  /// Flashes de prensa: destellos de cuatro puntas, blancos, arriba.
  /// Posiciones fijas (semilla constante) para que no bailen.
  void _flashes(Canvas canvas, Size size) {
    final azar = math.Random(7733);
    for (int i = 0; i < 30; i++) {
      final centro = Offset(
        azar.nextDouble() * size.width,
        azar.nextDouble() * size.height * (_yLejos - 0.02),
      );
      final radio = size.shortestSide * (0.006 + azar.nextDouble() * 0.020);
      final blanco = azar.nextDouble() > 0.35;
      _brillo(
        canvas,
        centro,
        radio,
        (blanco ? Colors.white : _oro).withValues(alpha: 0.45 + azar.nextDouble() * 0.5),
      );
    }
  }

  void _brillo(Canvas canvas, Offset c, double r, Color color) {
    final path = Path();
    for (int i = 0; i < 8; i++) {
      // Puntas largas en las diagonales principales, cortas entre ellas:
      // es lo que le da la forma de destello y no de estrella redonda.
      final largo = i.isEven ? r : r * 0.20;
      final a = i * math.pi / 4 - math.pi / 2;
      final p = Offset(c.dx + largo * math.cos(a), c.dy + largo * math.sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path..close, Paint()..color = color);
    // Halo suave alrededor, como el resplandor de un flash real.
    canvas.drawCircle(
      c,
      r * 0.9,
      Paint()
        ..color = color.withValues(alpha: 0.18)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r),
    );
  }

  @override
  bool shouldRepaint(covariant _FondoAlfombraRoja old) => old.tamano != tamano;
}

/// Navidad en rojo y blanco: bastones de caramelo al fondo, Santa
/// cruzando en su trineo con sus renos, y los abetos —los únicos verdes
/// de la escena— sobre la nieve.
class _FondoNavidad extends CustomPainter {
  final Size tamano;

  const _FondoNavidad(this.tamano);

  static const _rojo = Color(0xFFB3122A);
  static const _verdeAbeto = Color(0xFF1B6B3A);

  /// Altura del trineo. A 0.19 quedaba partido por la tarjeta de
  /// cabecera, que en la pantalla del grupo está siempre arriba; aquí
  /// cae en la franja despejada entre el formulario y los abetos.
  static const _yTrineo = 0.33;

  @override
  void paint(Canvas canvas, Size size) {
    final azar = math.Random(1225);
    _franjasCaramelo(canvas, size);
    _luna(canvas, size);
    _trineoDeSanta(canvas, size);
    _nieve(canvas, size);
    _abetos(canvas, size, azar);
    _copos(canvas, size, azar);
  }

  /// Franjas diagonales anchas y suaves: el bastón de caramelo, que es LA
  /// figura de "rojo y blanco" en Navidad.
  void _franjasCaramelo(Canvas canvas, Size size) {
    final paso = size.shortestSide * 0.30;
    final pintura = Paint()..color = _rojo.withValues(alpha: 0.055);
    final diagonal = size.width + size.height;
    for (double d = -diagonal; d < diagonal; d += paso * 2) {
      canvas.drawPath(
        Path()
          ..moveTo(d, 0)
          ..lineTo(d + paso, 0)
          ..lineTo(d + paso - size.height, size.height)
          ..lineTo(d - size.height, size.height)
          ..close,
        pintura,
      );
    }
  }

  /// El disco detrás del reno que va punteando. En rojo claro y no en
  /// blanco: sobre un fondo casi blanco, una luna blanca no se vería.
  void _luna(Canvas canvas, Size size) {
    final centro = Offset(size.width * 0.60, size.height * _yTrineo + size.height * 0.02);
    final radio = size.shortestSide * 0.16;
    canvas.drawCircle(centro, radio, Paint()..color = _rojo.withValues(alpha: 0.16));
    canvas.drawCircle(
      centro,
      radio,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * 0.006
        ..color = _rojo.withValues(alpha: 0.30),
    );
  }

  /// Manto de nieve al pie, sobre el que se apoyan los abetos.
  void _nieve(Canvas canvas, Size size) {
    final base = size.height * 0.80;
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height)
        ..lineTo(0, base + size.height * 0.06)
        ..quadraticBezierTo(size.width * 0.22, base - size.height * 0.02,
            size.width * 0.48, base + size.height * 0.03)
        ..quadraticBezierTo(size.width * 0.74, base + size.height * 0.08,
            size.width, base + size.height * 0.01)
        ..lineTo(size.width, size.height)
        ..close,
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );
  }

  /// Santa con su trineo y tres renos, subiendo en diagonal.
  ///
  /// Todo el grupo se dibuja opaco dentro de un saveLayer y es la CAPA la
  /// que lleva la transparencia. Si cada figura se pintara translúcida por
  /// separado, los solapes (Santa dentro del trineo, la cornamenta sobre
  /// la cabeza) se verían más oscuros y delatarían el truco.
  void _trineoDeSanta(Canvas canvas, Size size) {
    final s = size.width * 0.13;
    final base = Offset(size.width * 0.05, size.height * _yTrineo);

    canvas.saveLayer(
      Offset.zero & size,
      Paint()..color = Colors.black.withValues(alpha: 0.80),
    );

    final relleno = Paint()..color = _rojo;
    final trazo = Paint()
      ..color = _rojo
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Cada reno va un poco más arriba que el anterior: el tiro entero
    // sube, como despegando.
    Offset pos(double avance) => base + Offset(avance * s, -avance * s * 0.12);

    // Riendas primero, para que las figuras las tapen en los extremos.
    // Llegan a la altura del pecho del primer reno, no por encima del
    // lomo: si van más arriba parecen un cable atravesando a los renos.
    trazo.strokeWidth = s * 0.022;
    canvas.drawLine(pos(0) + Offset(s * 0.74, s * 0.30),
        pos(1.55) + Offset(s * 0.30, s * 0.40), trazo);

    _trineo(canvas, relleno, trazo, pos(0), s);
    for (final avance in [1.55, 2.55, 3.55]) {
      _reno(canvas, relleno, trazo, pos(avance), s);
    }

    canvas.restore();
  }

  void _trineo(Canvas canvas, Paint relleno, Paint trazo, Offset o, double s) {
    Offset p(double x, double y) => o + Offset(x * s, y * s);
    void trazar(List<Offset> puntos) {
      final path = Path()..moveTo(puntos.first.dx, puntos.first.dy);
      for (final punto in puntos.skip(1)) {
        path.lineTo(punto.dx, punto.dy);
      }
      canvas.drawPath(path, trazo);
    }

    // Santa va antes que el trineo: así el casco lo tapa de la cintura
    // para abajo y queda sentado dentro, no encima. Las proporciones van
    // exageradas a propósito (barriga ancha, gorro largo, barba marcada):
    // a este tamaño, una silueta realista se vuelve un borrón.
    canvas.drawOval(
        Rect.fromCenter(center: p(0.38, 0.30), width: s * 0.38, height: s * 0.40), relleno);
    canvas.drawCircle(p(0.42, 0.04), s * 0.13, relleno); // cabeza
    canvas.drawOval(
        Rect.fromCenter(center: p(0.40, 0.15), width: s * 0.26, height: s * 0.20), relleno); // barba
    canvas.drawPath(
      Path()
        ..moveTo(p(0.30, -0.02).dx, p(0.30, -0.02).dy)
        ..lineTo(p(0.54, -0.02).dx, p(0.54, -0.02).dy)
        ..quadraticBezierTo(
            p(0.66, -0.16).dx, p(0.66, -0.16).dy, p(0.70, -0.30).dx, p(0.70, -0.30).dy)
        ..quadraticBezierTo(
            p(0.52, -0.22).dx, p(0.52, -0.22).dy, p(0.30, -0.10).dx, p(0.30, -0.10).dy)
        ..close,
      relleno,
    ); // gorro, con caída hacia atrás
    canvas.drawCircle(p(0.72, -0.32), s * 0.07, relleno); // borla
    trazo.strokeWidth = s * 0.09;
    trazar([p(0.52, 0.24), p(0.72, 0.06)]); // brazo saludando

    // Casco del trineo: respaldo alto y enroscado atrás, frente abierto.
    canvas.drawPath(
      Path()
        ..moveTo(p(0.10, 0.58).dx, p(0.10, 0.58).dy)
        ..lineTo(p(0.07, 0.26).dx, p(0.07, 0.26).dy)
        ..quadraticBezierTo(
            p(0.03, 0.04).dx, p(0.03, 0.04).dy, p(0.24, 0.07).dx, p(0.24, 0.07).dy)
        ..quadraticBezierTo(
            p(0.13, 0.17).dx, p(0.13, 0.17).dy, p(0.19, 0.32).dx, p(0.19, 0.32).dy)
        ..lineTo(p(0.72, 0.42).dx, p(0.72, 0.42).dy)
        ..lineTo(p(0.76, 0.58).dx, p(0.76, 0.58).dy)
        ..close,
      relleno,
    );

    // Patín, con la punta curvada hacia arriba adelante.
    trazo.strokeWidth = s * 0.05;
    canvas.drawPath(
      Path()
        ..moveTo(p(0.03, 0.64).dx, p(0.03, 0.64).dy)
        ..lineTo(p(0.78, 0.64).dx, p(0.78, 0.64).dy)
        ..quadraticBezierTo(
            p(0.94, 0.64).dx, p(0.94, 0.64).dy, p(0.92, 0.46).dx, p(0.92, 0.46).dy),
      trazo,
    );
  }

  void _reno(Canvas canvas, Paint relleno, Paint trazo, Offset o, double s) {
    Offset p(double x, double y) => o + Offset(x * s, y * s);
    void trazar(List<Offset> puntos) {
      final path = Path()..moveTo(puntos.first.dx, puntos.first.dy);
      for (final punto in puntos.skip(1)) {
        path.lineTo(punto.dx, punto.dy);
      }
      canvas.drawPath(path, trazo);
    }

    // Patas en pleno galope: las dos de adelante estiradas al frente y
    // las de atrás hacia atrás. Es la pose que lee como "volando".
    trazo.strokeWidth = s * 0.05;
    trazar([p(0.58, 0.50), p(0.76, 0.60), p(0.88, 0.53)]);
    trazar([p(0.54, 0.52), p(0.67, 0.67)]);
    trazar([p(0.27, 0.50), p(0.09, 0.60), p(-0.03, 0.53)]);
    trazar([p(0.31, 0.52), p(0.17, 0.67)]);

    canvas.drawPath(
      Path()
        ..moveTo(p(0.19, 0.34).dx, p(0.19, 0.34).dy)
        ..lineTo(p(0.08, 0.24).dx, p(0.08, 0.24).dy)
        ..lineTo(p(0.15, 0.38).dx, p(0.15, 0.38).dy)
        ..close,
      relleno,
    ); // cola

    canvas.drawOval(
        Rect.fromCenter(center: p(0.42, 0.40), width: s * 0.56, height: s * 0.29), relleno);
    trazo.strokeWidth = s * 0.11;
    trazar([p(0.62, 0.34), p(0.79, 0.15)]); // cuello
    canvas.drawOval(
        Rect.fromCenter(center: p(0.86, 0.12), width: s * 0.25, height: s * 0.15), relleno);

    // Cornamenta: un tronco por lado con dos puntas cada uno.
    trazo.strokeWidth = s * 0.033;
    trazar([p(0.80, 0.06), p(0.77, -0.13)]);
    trazar([p(0.785, -0.03), p(0.68, -0.09)]);
    trazar([p(0.775, -0.09), p(0.86, -0.15)]);
    trazar([p(0.88, 0.05), p(0.93, -0.10)]);
    trazar([p(0.905, -0.02), p(0.99, -0.06)]);
  }

  /// Los abetos son lo ÚNICO verde de esta temática, a propósito: el
  /// resto es rojo y blanco.
  void _abetos(Canvas canvas, Size size, math.Random azar) {
    final base = size.height * 0.95;
    for (int i = 0; i < 9; i++) {
      final x = size.width * (i / 8.0);
      final alto = size.height * (0.11 + azar.nextDouble() * 0.09);
      final ancho = alto * 0.60;
      // Tres cuerpos escalonados: se lee mucho más como abeto que un
      // triángulo suelto.
      for (int piso = 0; piso < 3; piso++) {
        final t = piso / 2.0;
        final cima = base - alto * (1 - t * 0.42);
        final medio = base - alto * (0.42 - t * 0.36);
        final anchoPiso = ancho * (0.55 + t * 0.45);
        canvas.drawPath(
          Path()
            ..moveTo(x, cima)
            ..lineTo(x - anchoPiso / 2, medio)
            ..lineTo(x + anchoPiso / 2, medio)
            ..close,
          Paint()..color = _verdeAbeto.withValues(alpha: 0.55),
        );
      }
      // Tronco.
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset(x, base + alto * 0.03),
            width: ancho * 0.10,
            height: alto * 0.12),
        Paint()..color = const Color(0xFF6B4A2F).withValues(alpha: 0.55),
      );
    }
  }

  /// Copos cayendo. Van con un borde rojo tenue porque sobre un fondo
  /// casi blanco un círculo blanco sin más sería invisible.
  void _copos(Canvas canvas, Size size, math.Random azar) {
    for (int i = 0; i < 30; i++) {
      final centro =
          Offset(azar.nextDouble() * size.width, azar.nextDouble() * size.height * 0.76);
      final radio = size.shortestSide * (0.005 + azar.nextDouble() * 0.013);
      // Relleno blanco con un halo rojo MUY tenue alrededor: sin el halo
      // el copo desaparece sobre las franjas blancas, y con el halo
      // marcado parecía una burbuja en vez de nieve.
      canvas.drawCircle(
        centro,
        radio * 1.7,
        Paint()
          ..color = _rojo.withValues(alpha: 0.10)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radio),
      );
      canvas.drawCircle(centro, radio, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _FondoNavidad old) => old.tamano != tamano;
}
