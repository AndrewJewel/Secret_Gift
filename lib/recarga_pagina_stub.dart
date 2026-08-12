/// Implementación de repuesto para Android/iOS.
///
/// Nunca se ejecuta de verdad: quien llama a estas funciones
/// (`pantalla_verificar_correo.dart`) ya comprueba `kIsWeb` antes de
/// hacerlo. Existe solo para que el árbol de imports compile fuera de web,
/// donde no hay `dart:js_interop` — ver el porqué de este fichero en
/// `recarga_pagina.dart`.
bool sesionYaRecargadaPorAlmacenRoto() => false;

void marcarSesionRecargadaYRecargarPagina() {}
