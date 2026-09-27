import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santa_secreto/acceso_cuenta.dart';
import 'package:santa_secreto/funciones.dart';
import 'package:santa_secreto/l10n/app_localizations.dart';
import 'package:santa_secreto/pantalla_verificar_correo.dart';

Widget _envoltorio(Widget hijo, {String idioma = 'en'}) => MaterialApp(
      locale: Locale(idioma),
      supportedLocales: const [Locale('en'), Locale('es')],
      localizationsDelegates: Textos.localizationsDelegates,
      home: hijo,
    );

void main() {
  testWidgets('modo enlace: pinta lo de siempre', (tester) async {
    await tester.pumpWidget(_envoltorio(PantallaVerificarCorreo(
      alVerificar: (_) async {},
      medio: MedioVerificacion.enlace,
      correo: 'a@x.com',
    )));
    await tester.pumpAndSettle();
    expect(find.text('Check your inbox'), findsOneWidget);
    expect(find.text("I've confirmed it"), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('modo código: al sexto dígito verifica solo y entra', (tester) async {
    final verificados = <String>[];
    var entro = false;
    await tester.pumpWidget(_envoltorio(PantallaVerificarCorreo(
      alVerificar: (_) async => entro = true,
      medio: MedioVerificacion.codigo,
      correo: 'a@x.com',
      verificar: (c) async => verificados.add(c),
    )));
    await tester.pump();
    expect(find.text('We sent a 6-digit code to a@x.com.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tester.pump();
    expect(verificados, ['123456']);
    expect(entro, isTrue);
    await tester.pump(const Duration(seconds: 61));
  });

  testWidgets('modo código: un código malo muestra el error en el idioma de la app',
      (tester) async {
    await tester.pumpWidget(_envoltorio(
      PantallaVerificarCorreo(
        alVerificar: (_) async {},
        medio: MedioVerificacion.codigo,
        correo: 'a@x.com',
        verificar: (c) async =>
            throw FuncionError('invalid-argument', 'codigo_incorrecto', 'x'),
      ),
      idioma: 'es',
    ));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '000000');
    await tester.pump();
    await tester.pump();
    expect(find.text('Código incorrecto. Revísalo e inténtalo otra vez.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 61));
  });

  testWidgets('sin medio: manda un código al abrir y cuenta atrás el reenvío',
      (tester) async {
    var mandados = 0;
    await tester.pumpWidget(_envoltorio(PantallaVerificarCorreo(
      alVerificar: (_) async {},
      correo: 'a@x.com',
      mandar: () async {
        mandados++;
        return MedioVerificacion.codigo;
      },
    )));
    await tester.pump();
    await tester.pump();
    expect(mandados, 1);
    expect(find.text('Send another code in 60s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 61));
    expect(find.text('Send another code'), findsOneWidget);
  });
}
