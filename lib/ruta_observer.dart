import 'package:flutter/material.dart';

/// Observador global de rutas, registrado en el `MaterialApp`.
///
/// Existe para que "Mis grupos" se entere de cuándo vuelve a estar visible
/// y recargue su lista. Esperar al future de `Navigator.push` NO sirve:
/// las pantallas de crear y unirse terminan en `pushReplacement`, que
/// completa ese future en el acto, así que la recarga corría al ENTRAR en
/// la pantalla del grupo, no al volver. El resultado era que un grupo al
/// que acababas de unirte —cuyo vínculo lo crea `agregarParticipante`
/// después, ya dentro del registro— no aparecía nunca en esa sesión.
///
/// Se declara en su propio archivo para que lo puedan importar tanto
/// `main.dart` (que lo registra) como la pantalla (que se suscribe) sin
/// que ninguna dependa de la otra.
final RouteObserver<PageRoute<dynamic>> rutaObserver = RouteObserver<PageRoute<dynamic>>();
