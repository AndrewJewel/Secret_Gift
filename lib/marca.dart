import 'package:flutter/material.dart';

/// Paleta de la marca, sacada directamente del logo (Marca/Logo.png):
/// la caja de regalo es dorada y el lazo carmín.
///
/// El carmín manda en la interfaz y el oro acompaña, no al revés. No es
/// capricho: el oro sobre blanco da 4.8:1 de contraste, que pasa raspando
/// el mínimo de 4.5:1 y no deja margen para texto pequeño ni para bordes.
/// El carmín da 11.4:1 y sirve para todo.
///
/// Las escalas están escritas a mano (y no generadas) porque los valores
/// por defecto de los widgets tienen que ser constantes en tiempo de
/// compilación, y una escala generada en ejecución no puede serlo.

/// Carmín del lazo. Color principal: títulos, botones, iconos.
const MaterialColor rojoMarca = MaterialColor(0xFF9B1226, <int, Color>{
  50: Color(0xFFF3E3E5),
  100: Color(0xFFE9CBCF),
  200: Color(0xFFD9A5AD),
  300: Color(0xFFC87D88),
  400: Color(0xFFB44D5C),
  500: Color(0xFF9B1226),
  600: Color(0xFF881021),
  700: Color(0xFF760E1D),
  800: Color(0xFF630C18),
  900: Color(0xFF4E0913),
});

/// Oro de la caja. Acento: realces, la ocasión de Amigo Secreto, detalles.
/// Para texto, usar shade700 o más oscuro.
const MaterialColor oroMarca = MaterialColor(0xFFC08A2E, <int, Color>{
  50: Color(0xFFF7F1E6),
  100: Color(0xFFF1E5D1),
  200: Color(0xFFE7D3B0),
  300: Color(0xFFDCBF8C),
  400: Color(0xFFD0A762),
  500: Color(0xFFC08A2E),
  600: Color(0xFFA97928),
  700: Color(0xFF926923),
  800: Color(0xFF7B581D),
  900: Color(0xFF604517),
});
