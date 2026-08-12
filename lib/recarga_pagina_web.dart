import 'package:web/web.dart' as web;

/// Clave de `sessionStorage` (no `localStorage`, ver `recarga_pagina.dart`)
/// que marca que esta pestaña ya recargó una vez por almacén roto.
const _claveMarca = 'sg_recarga_por_almacen_roto';

bool sesionYaRecargadaPorAlmacenRoto() =>
    web.window.sessionStorage.getItem(_claveMarca) != null;

void marcarSesionRecargadaYRecargarPagina() {
  web.window.sessionStorage.setItem(_claveMarca, '1');
  web.window.location.reload();
}
