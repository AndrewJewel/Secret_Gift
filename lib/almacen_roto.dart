import 'funciones.dart';

/// Dice si [error] es el fallo de "almacén de sesión roto tras volver de
/// segundo plano".
///
/// El diagnóstico, con pruebas: los navegadores móviles congelan una
/// pestaña en segundo plano para ahorrar memoria y, al congelarla, cierran
/// su IndexedDB — donde Firebase Auth guarda la sesión en web. Es justo lo
/// que pasa al salir al buzón de correo a pinchar el enlace de
/// verificación y volver. Al volver, ese almacén queda roto y NO se cura
/// solo: reintentar sobre un recurso roto no lo repara (se probó con
/// `u.reload()`, con `u.getIdToken()` y con forzar `Persistence.LOCAL`, y
/// el fallo persistió los tres intentos). Lo único que lo repara es
/// restaurar el contexto de la página — recargarla, que es lo que la
/// persona hacía a mano bloqueando y desbloqueando el móvil.
///
/// A propósito NO se compara contra el texto del error (p.ej. "Database is
/// closing/hidden"): ese texto lo pone el navegador, no Firebase, no está
/// documentado en ningún sitio y cambiará entre navegadores y versiones —
/// atarse a él se rompería en silencio en el próximo Chrome. En su lugar
/// se usa una señal propia y estable: `correoVerificado()` (reload) y
/// `tokenActual()` (token) son las DOS ÚNICAS llamadas de toda la app que
/// tocan esa sesión justo en este punto, cada una ya reintenta una vez
/// internamente (dca42d6, 211da13), y si aun así fallan anteponen su
/// propia marca ('reload: ' / 'token: ') al mensaje antes de convertirlo en
/// [FuncionError] con clave 'auth_desconocido' — la clave comodín para
/// códigos de Firebase que la app no reconoce. Esa combinación (comodín +
/// marca nuestra) es justo la huella de "una de las dos llamadas que tocan
/// el almacén de sesión, ya reintentada, sigue fallando con algo que no
/// sabemos nombrar": el perfil exacto de un almacén roto, sin depender de
/// ninguna cadena de ningún navegador.
bool esFalloDeAlmacenRoto(Object error) =>
    error is FuncionError &&
    error.clave == 'auth_desconocido' &&
    (error.mensaje.startsWith('reload: ') ||
        error.mensaje.startsWith('token: '));

/// Combina la clasificación del error con si esta pestaña ya recargó una
/// vez por este motivo, y decide si toca recargar ahora.
///
/// Separada de [esFalloDeAlmacenRoto] y del acceso a `sessionStorage` a
/// propósito, para que la protección contra bucles —lo más importante de
/// todo esto, ver comentario en `pantalla_verificar_correo.dart`— sea una
/// función pura, testable sin necesitar un navegador de verdad.
bool debeRecargarPorAlmacenRoto({
  required bool esFalloDeAlmacen,
  required bool yaRecargadaEstaSesion,
}) => esFalloDeAlmacen && !yaRecargadaEstaSesion;
