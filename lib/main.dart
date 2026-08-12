import 'package:flutter/foundation.dart'; // Para detectar si es Web
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'glass.dart';
import 'idioma.dart';
import 'l10n/app_localizations.dart';
import 'ocasion.dart';
import 'pantalla_raiz.dart';
import 'ruta_observer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    // 🌐 CONFIGURACIÓN WEB (Sincronizada con tu App)
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyD9F2V6ByG7p9yMoDOpa_p-v97_Ik5jZcI",
        authDomain: "secretgift-app.firebaseapp.com",
        projectId: "secretgift-app",
        storageBucket: "secretgift-app.firebasestorage.app",
        messagingSenderId: "997384680563",
        appId: "1:997384680563:web:de772ec4c11202e0f0a606",
      ),
    );

    // Firebase Auth en web guarda la sesión, por defecto, en IndexedDB. Los
    // navegadores móviles CIERRAN IndexedDB cuando la pestaña pasa a segundo
    // plano para ahorrar memoria — justo lo que pasa al salir al buzón de
    // correo a pinchar el enlace de confirmación y volver a la app. Esa
    // conexión se queda rota y NO se cura sola: los reintentos de
    // `reload()` y `getIdToken()` (ver correoVerificado() en
    // acceso_cuenta.dart y tokenActual() en auth.dart) no arreglaban este
    // fallo porque no es un corte de red pasajero, es el almacén mismo el
    // que quedó cerrado — reintentar sobre un recurso roto no lo repara.
    //
    // localStorage, en cambio, ningún navegador lo cierra nunca. Por eso se
    // fuerza esa persistencia (Persistence.LOCAL) aquí, apenas arranca la
    // app y ANTES de que nada más toque Auth. Antes de migrar a Firebase
    // Auth, esta app guardaba la sesión en localStorage a mano y este fallo
    // no existía: apareció con la migración, sin que nadie decidiera
    // cambiar de almacén.
    //
    // Se fija con `setPersistence()` y no con
    // `FirebaseAuth.instanceFor(persistence: ...)` (la forma recomendada
    // para evitar el fallo conocido del SDK de JS que borra sesiones
    // previas al llamar a setPersistence tras construir, ver
    // https://github.com/firebase/firebase-js-sdk/issues/9319) porque esa
    // sobrecarga de `instanceFor` NO EXISTE en el plugin de Flutter
    // (firebase_auth 6.5.7, la última publicada en pub.dev al escribir
    // esto): solo acepta el parámetro `app`. `setPersistence()` de
    // instancia es la única vía que expone el plugin. El riesgo de ese
    // issue aparece con VARIAS pestañas abiertas a la vez compitiendo por
    // el mismo almacén; aquí se llama una sola vez, lo primero que toca
    // Auth en toda la app, con `FirebaseAuth.instance` — el mismo getter
    // que usan auth.dart y acceso_cuenta.dart — así que no hay una segunda
    // instancia con otra persistencia rondando.
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  } else {
    // 📱 CONFIGURACIÓN MÓVIL (Usa el archivo google-services.json)
    await Firebase.initializeApp();
    // La persistencia nativa de Android/iOS no pasa por IndexedDB, así que
    // este fallo no aplica ahí. Y no es solo que sobre: `setPersistence()`
    // lanza UnimplementedError fuera de web (el plugin solo lo implementa
    // para web), así que dejarlo dentro del `if (kIsWeb)` es obligatorio,
    // no un detalle de estilo — llamarlo aquí tumbaría el arranque en
    // Android/iOS.
  }

  // El idioma guardado se lee en segundo plano a propósito: la app se
  // muestra de inmediato en inglés y, si había español guardado, cambia
  // sola en cuanto llega. Nunca se queda esperando.
  Idioma.cargar();

  runApp(const SantaApp());
}

class SantaApp extends StatelessWidget {
  const SantaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: Idioma.actual,
      builder: (context, locale, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        onGenerateTitle: (context) => Textos.of(context).appTitle,
        locale: locale,
        supportedLocales: Idioma.soportados,
        localizationsDelegates: Textos.localizationsDelegates,
        theme: temaGlass(colorNeutro),
        // Sin registrarlo aquí, `rutaObserver` no recibe nada y "Mis
        // grupos" nunca se enteraría de que vuelve a estar visible.
        navigatorObservers: [rutaObserver],
        home: const PantallaRaiz(),
      ),
    );
  }
}
