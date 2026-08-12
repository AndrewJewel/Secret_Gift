// Service worker de FCM. Es lo que recibe los avisos con la app cerrada:
// sin este fichero no hay push en web, y su ausencia no da ningún error
// visible — simplemente no llega nada.
//
// Es JavaScript suelto: NO pasa por el compilador de Dart, así que la
// configuración de Firebase hay que repetirla aquí. Está duplicada de
// lib/main.dart a la fuerza. SI CAMBIA ALLÍ, CÁMBIALA AQUÍ.
//
// Convive con el service worker propio de Flutter web sin tocarlo: son
// ficheros distintos y el navegador admite varios por origen.
importScripts("https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyD9F2V6ByG7p9yMoDOpa_p-v97_Ik5jZcI",
  authDomain: "secretgift-app.firebaseapp.com",
  projectId: "secretgift-app",
  storageBucket: "secretgift-app.firebasestorage.app",
  messagingSenderId: "997384680563",
  appId: "1:997384680563:web:de772ec4c11202e0f0a606",
});

firebase.messaging();
