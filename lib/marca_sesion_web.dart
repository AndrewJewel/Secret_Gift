import 'package:web/web.dart' as web;

/// Clave que lee el script del `<head>` de web/landing.html.
const _clave = 'sg_sesion';

void marcarSesion(bool conSesion) {
  try {
    if (conSesion) {
      web.window.localStorage.setItem(_clave, '1');
    } else {
      web.window.localStorage.removeItem(_clave);
    }
  } catch (_) {
    // Almacén bloqueado (incógnito estricto): la landing se ve y su botón
    // lleva a /app igual. No vale la pena tumbar nada por esto.
  }
}
