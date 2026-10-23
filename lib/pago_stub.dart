/// Fuera de la web no hay Paddle: Android esperará a Google Play Billing.
/// Quien llama ya comprueba `kIsWeb`; esto solo deja compilar el resto.
Future<String> abrirPago({required String uid, required String correo, required String idioma}) async =>
    'no_disponible';
