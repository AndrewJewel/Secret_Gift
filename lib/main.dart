import 'package:flutter/foundation.dart'; // Para detectar si es Web
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

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
        apiKey: "AIzaSyC3rWS4cYcXpdrO2NCturmoiaoqmkzpjE8",
        authDomain: "santa-secreto-860c3.firebaseapp.com",
        projectId: "santa-secreto-860c3",
        storageBucket: "santa-secreto-860c3.firebasestorage.app",
        messagingSenderId: "176155117392",
        appId: "1:176155117392:web:c11dc9932050358cd08e55", // <--- ¡Listo!
      ),
    );
  } else {
    // 📱 CONFIGURACIÓN MÓVIL (Usa el archivo google-services.json)
    await Firebase.initializeApp();
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
