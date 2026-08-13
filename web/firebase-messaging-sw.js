// Service worker de FCM. Es lo que recibe los avisos con la app cerrada:
// sin este fichero no hay push en web, y su ausencia no da ningún error
// visible — simplemente no llega nada.
//
// Es JavaScript suelto: NO pasa por el compilador de Dart, así que la
// configuración de Firebase hay que repetirla aquí. Está duplicada de
// lib/main.dart a la fuerza. SI CAMBIA ALLÍ, CÁMBIALA AQUÍ.
//
// Convive con el service worker propio de Flutter web porque el SDK de FCM
// lo registra en un SCOPE propio (`/firebase-cloud-messaging-push-scope`),
// distinto del `/` que usa Flutter. No es que "el navegador admita varios
// por origen": admite varios SCOPES, y dos con el mismo scope se pisarían
// —el último registrado se queda con el control—.
//
// LA VERSIÓN TIENE QUE SER LA MISMA QUE CARGA LA PÁGINA. La pone
// `firebase_core_web` (hoy 3.10.0 → firebase-js 12.17.0, ver
// `supportedFirebaseJsSdkVersion` en ese paquete). Las dos comparten
// origen y la misma base de datos de IndexedDB (`firebase-messaging-database`),
// así que dos versiones distintas leen y escriben el mismo almacén con
// esquemas que nadie garantiza compatibles. SI SUBE firebase_core_web,
// SUBE ESTAS DOS LÍNEAS.
importScripts("https://www.gstatic.com/firebasejs/12.17.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/12.17.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyD9F2V6ByG7p9yMoDOpa_p-v97_Ik5jZcI",
  authDomain: "secretgift-app.firebaseapp.com",
  projectId: "secretgift-app",
  storageBucket: "secretgift-app.firebasestorage.app",
  messagingSenderId: "997384680563",
  appId: "1:997384680563:web:de772ec4c11202e0f0a606",
});

firebase.messaging();
