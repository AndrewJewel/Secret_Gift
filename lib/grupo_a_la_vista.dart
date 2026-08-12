import 'package:flutter/material.dart';

import 'push.dart';
import 'ruta_observer.dart';

/// Mixin para pantallas que representan "estar mirando un grupo": declara
/// ese grupo en `push.dart` (`mirandoGrupo`) mientras —y solo mientras—
/// la pantalla está de verdad a la vista.
///
/// "A la vista" no es lo mismo que "montada": una pantalla puede seguir
/// viva, sin `dispose`, tapada por otra que se apiló encima. `dispose` no
/// se entera de eso —solo de que la ruta se destruyó de verdad—, así que
/// el aviso de "dejé de mirar este grupo" tiene que salir por otro sitio:
/// el `RouteObserver` que ya usa `pantalla_mis_grupos.dart` para el mismo
/// tipo de problema (ver `ruta_observer.dart`).
///
/// Las cuatro formas de salir de una pantalla que le importan a este
/// mixin —su propio botón de volver, el gesto del sistema, un `pop`
/// programático, o quedar tapada sin destruirse— se reducen, en Flutter,
/// a solo dos: o la ruta se destruye de verdad (cubierto por `dispose`) o
/// sigue viva pero tapada (cubierto por `didPushNext`/`didPopNext`). No
/// hay un tercer estado, así que entre los dos quedan cubiertas todas.
///
/// Vive en su propio fichero, sin depender de Firestore ni de nada
/// específico de una pantalla de chat, para poder probar el ciclo
/// completo (entrar, que te tapen, volver, salir) con un `WidgetTester`
/// normal y una pantalla de prueba cualquiera — la única pantalla que hoy
/// usa este mixin sí depende de Firestore, pero el ciclo en sí no debería.
mixin ConGrupoALaVista<T extends StatefulWidget> on State<T> implements RouteAware {
  /// El código del grupo que representa esta pantalla.
  String get codigoDeGrupoALaVista;

  @override
  void initState() {
    super.initState();
    mirandoGrupo(codigoDeGrupoALaVista);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ruta = ModalRoute.of(context);
    if (ruta is PageRoute) rutaObserver.subscribe(this, ruta);
  }

  @override
  void dispose() {
    rutaObserver.unsubscribe(this);
    // Red de seguridad para todas las formas de cerrar esta pantalla que
    // SÍ la destruyen —botón atrás propio, gesto de volver del sistema,
    // pop programático—: todas terminan pasando por aquí. Si este valor
    // se quedara pegado, a quien lo sufra no le llegaría NUNCA MÁS un
    // aviso de este grupo, y nadie se enteraría.
    mirandoGrupo(null);
    super.dispose();
  }

  /// Esta pantalla queda tapada por otra que se apila encima: deja de
  /// estar "a la vista" sin destruirse, así que hay que apagarlo aquí y no
  /// esperar a `dispose`.
  @override
  void didPushNext() => mirandoGrupo(null);

  /// Vuelve a estar a la vista tras cerrarse la pantalla que la tapaba.
  @override
  void didPopNext() => mirandoGrupo(codigoDeGrupoALaVista);

  // El resto de `RouteAware` no hace falta aquí: `didPush` no aporta nada
  // que no haga ya `initState` (que corre antes) y `didPop` tampoco (lo
  // cubre `dispose`, que siempre se llama al destruirse la ruta).
  @override
  void didPush() {}

  @override
  void didPop() {}
}
