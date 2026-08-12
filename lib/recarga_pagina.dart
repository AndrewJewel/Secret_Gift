// Recarga la página y recuerda haberlo hecho, usando `sessionStorage`.
//
// Se usa `sessionStorage` y NO `localStorage` a propósito: la marca tiene
// que sobrevivir a la recarga (si no, no hay protección contra bucles)
// pero NO a cerrar la pestaña (si no, la próxima vez que a esta persona le
// tocara el mismo fallo —en otra sesión, quizá en otro móvil— la
// recuperación automática se habría quedado desactivada para siempre sin
// que nadie lo decidiera).
//
// Fichero con implementación condicional porque `dart:js_interop` (lo que
// usa `package:web` por debajo) no existe fuera de compilación a web: sin
// separar esto, Android/iOS dejarían de compilar. `dart.library.js_interop`
// es verdad solo compilando a web, así que el import de abajo elige la
// implementación real (`recarga_pagina_web.dart`) ahí y el repuesto que no
// hace nada (`recarga_pagina_stub.dart`) en cualquier otro caso.
export 'recarga_pagina_stub.dart'
    if (dart.library.js_interop) 'recarga_pagina_web.dart';
