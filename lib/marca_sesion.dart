// La landing (web/landing.html) vive en la raíz. Si esta marca existe,
// manda directo a /app: así quien ya usa la app, o toca una notificación
// (que abre la raíz), no ve la landing. Import condicional como en
// recarga_pagina.dart: package:web no existe fuera de web.
export 'marca_sesion_stub.dart' if (dart.library.js_interop) 'marca_sesion_web.dart';
