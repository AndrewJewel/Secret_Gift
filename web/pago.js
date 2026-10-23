// Pago con Paddle (Paddle.js v2). Lo llama lib/pago_web.dart.
// Paddle se descarga solo cuando alguien va a pagar, no en cada visita.
(function () {
  var cargado = null;
  var alTerminar = null;

  function cargar(token, entorno) {
    if (cargado) return cargado;
    cargado = new Promise(function (ok, mal) {
      var s = document.createElement('script');
      s.src = 'https://cdn.paddle.com/paddle/v2/paddle.js';
      s.onload = function () {
        if (entorno === 'sandbox') Paddle.Environment.set('sandbox');
        Paddle.Initialize({
          token: token,
          eventCallback: function (e) {
            if (!alTerminar) return;
            if (e.name === 'checkout.completed') {
              alTerminar('completado');
              alTerminar = null;
              Paddle.Checkout.close();
            } else if (e.name === 'checkout.closed') {
              alTerminar('cerrado');
              alTerminar = null;
            }
          },
        });
        ok();
      };
      s.onerror = function () {
        cargado = null;
        mal(new Error('paddle_no_cargo'));
      };
      document.head.appendChild(s);
    });
    return cargado;
  }

  window.sgPagar = function (token, entorno, priceId, uid, correo, idioma) {
    return cargar(token, entorno).then(function () {
      return new Promise(function (ok) {
        alTerminar = ok;
        Paddle.Checkout.open({
          items: [{priceId: priceId, quantity: 1}],
          customData: {uid: uid},
          customer: correo ? {email: correo} : undefined,
          settings: {displayMode: 'overlay', locale: idioma},
        });
      });
    });
  };
})();
