# Plan de implementación — La cuenta como puerta de entrada

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que la app abra en "crear cuenta" en vez de en la pantalla de inicio, que las invitaciones por QR sobrevivan al registro, y que "Mis grupos" pase a ser la pantalla principal.

**Architecture:** Una pantalla-portero en la raíz lee la sesión guardada y el parámetro `?codigo=` de la URL, y decide destino con una función pura y testeable. La invitación se persiste en `shared_preferences` para sobrevivir a recargas. El registro y el inicio de sesión se separan en dos pantallas.

**Tech Stack:** Flutter 3.38.10 · Dart 3.10.9 · `shared_preferences` · `cloud_firestore` · Cloud Functions (Node 20) · l10n por ARB con clase generada `Textos`.

**Spec:** `docs/superpowers/specs/2026-08-08-flujo-cuenta-design.md`

## Global Constraints

- **Dart 3.10.9.** No usar features de Dart 3.12 (private named parameters, primary constructors): no compilan.
- **Todo texto de interfaz pasa por ARB**, en `lib/l10n/app_en.arb` y `lib/l10n/app_es.arb`. Hoy hay 198 claves. Ninguna puede faltar en un idioma y sobrar en el otro.
- **`app_en.arb` es la plantilla** (`l10n.yaml`). La clase generada se llama `Textos`, se accede con `Textos.of(context)`, y `flutter gen-l10n` corre solo durante `flutter build` / `flutter run`.
- **Inglés es el idioma por defecto.**
- **Frase exacta, sin cambiar una palabra:** `Create your account to discover who sends you the secret gifts`
- **Estilo:** reutilizar los widgets existentes de `lib/glass.dart` (`GlassCard`, `GlassAppBar`, `GlassTextField`, `GlassButton`, `GlassOutlineButton`), el fondo `FondoNeutro` (`lib/tematica.dart`), el tema `temaGlass(colorNeutro)` (`lib/ocasion.dart`) y el color `colorNeutro` (`lib/glass.dart`).
- **La barra es `flutter analyze` sin una sola advertencia.** El proyecto está así hoy y debe seguir.
- **Comentarios en español**, explicando el *porqué*, como el resto del código.
- **`SharedPreferences` nunca debe tumbar la app**: todo acceso va envuelto en `try/catch`, como en `identidad_local.dart`.

### Dos cosas del spec que NO llevan tarea

**El nombre de juego ya se pide en blanco.** El spec insiste en que el nickname no se proponga nunca como nombre de participante. Eso ya es el comportamiento actual: `pantalla_registro.dart` arranca con el controlador vacío y nadie lo rellena. **No hay nada que cambiar** — se documenta para que quien implemente no vaya a "arreglarlo".

**Las importaciones circulares aquí son correctas.** `pantalla_crear_cuenta.dart` importa `pantalla_raiz.dart` (por `irADondeToque`) y `pantalla_raiz.dart` importa `pantalla_crear_cuenta.dart` (por la pantalla). Dart permite ciclos entre librerías y esto compila. No hay que reorganizarlo.

---

### Task 1: Módulo de invitación pendiente

Guarda el código de grupo que llega por QR para que sobreviva al registro.

**Files:**
- Create: `lib/invitacion_pendiente.dart`
- Test: `test/invitacion_pendiente_test.dart`

**Interfaces:**
- Consumes: nada.
- Produces:
  - `class InvitacionPendiente { final String codigo; final String nombreGrupo; const InvitacionPendiente(this.codigo, this.nombreGrupo); }`
  - `Future<void> guardarInvitacion(String codigo, String nombreGrupo)`
  - `Future<InvitacionPendiente?> leerInvitacion()`
  - `Future<void> borrarInvitacion()`

- [ ] **Step 1: Escribir el test que falla**

Crear `test/invitacion_pendiente_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:santa_secreto/invitacion_pendiente.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('sin invitación guardada devuelve null', () async {
    expect(await leerInvitacion(), isNull);
  });

  test('guarda y recupera código y nombre', () async {
    await guardarInvitacion('RJV2-HN8R', 'Navidad Familia');
    final i = await leerInvitacion();
    expect(i!.codigo, 'RJV2-HN8R');
    expect(i.nombreGrupo, 'Navidad Familia');
  });

  test('borrar la deja en null', () async {
    await guardarInvitacion('RJV2-HN8R', 'Navidad Familia');
    await borrarInvitacion();
    expect(await leerInvitacion(), isNull);
  });

  test('un grupo sin nombre se recupera con cadena vacía, no null', () async {
    await guardarInvitacion('ABCD-1234', '');
    final i = await leerInvitacion();
    expect(i!.codigo, 'ABCD-1234');
    expect(i.nombreGrupo, '');
  });
}
```

- [ ] **Step 2: Ejecutar el test y verificar que falla**

Run: `flutter test test/invitacion_pendiente_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:santa_secreto/invitacion_pendiente.dart'`

- [ ] **Step 3: Escribir la implementación mínima**

Crear `lib/invitacion_pendiente.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

/// Invitación a un grupo que llegó por enlace o QR (`?codigo=XXXX`) y que
/// todavía no se ha usado.
///
/// Se guarda en disco y no en memoria a propósito: entre que la persona
/// llega y termina de crear su cuenta puede recargar la página, y una
/// invitación en memoria se perdería. Acabaría en un "Mis grupos" vacío
/// sin entender por qué.
class InvitacionPendiente {
  final String codigo;

  /// Solo para mostrar "Te han invitado a X" en la pantalla de registro.
  /// Puede venir vacío: hay grupos sin nombre.
  final String nombreGrupo;

  const InvitacionPendiente(this.codigo, this.nombreGrupo);
}

const _claveCodigo = 'invitacion_codigo';
const _claveNombre = 'invitacion_nombre';

Future<void> guardarInvitacion(String codigo, String nombreGrupo) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveCodigo, codigo);
    await prefs.setString(_claveNombre, nombreGrupo);
  } catch (_) {
    // Sin almacenamiento la invitación se pierde, pero la app sigue viva.
  }
}

Future<InvitacionPendiente?> leerInvitacion() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final codigo = prefs.getString(_claveCodigo);
    if (codigo == null) return null;
    return InvitacionPendiente(codigo, prefs.getString(_claveNombre) ?? '');
  } catch (_) {
    return null;
  }
}

/// Se llama en cuanto la invitación se usa. Sin esto, cada apertura de la
/// app volvería a meter a esa persona en ese grupo para siempre.
Future<void> borrarInvitacion() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_claveCodigo);
    await prefs.remove(_claveNombre);
  } catch (_) {
    // Nada que hacer.
  }
}
```

- [ ] **Step 4: Ejecutar el test y verificar que pasa**

Run: `flutter test test/invitacion_pendiente_test.dart`
Expected: PASS — 4 tests

- [ ] **Step 5: Commit**

```bash
git add lib/invitacion_pendiente.dart test/invitacion_pendiente_test.dart
git commit -m "Añade el módulo de invitación pendiente

Guarda en disco el código que llega por QR para que sobreviva al
registro. En memoria no: una recarga a mitad del registro perdería la
invitación."
```

---

### Task 2: La decisión de destino, como función pura

El portero necesita decidir a dónde mandar a cada persona. Esa decisión se extrae a una función sin dependencias para poder probarla; el widget solo la obedece.

**Files:**
- Create: `lib/destino_inicial.dart`
- Test: `test/destino_inicial_test.dart`

**Interfaces:**
- Consumes: nada.
- Produces:
  - `enum DestinoInicial { crearCuenta, misGrupos, grupo }`
  - `DestinoInicial decidirDestino({required bool haySesion, required bool hayInvitacion})`

- [ ] **Step 1: Escribir el test que falla**

Crear `test/destino_inicial_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:santa_secreto/destino_inicial.dart';

void main() {
  test('sin sesión y sin invitación: a crear cuenta', () {
    expect(decidirDestino(haySesion: false, hayInvitacion: false),
        DestinoInicial.crearCuenta);
  });

  test('sin sesión pero con invitación: a crear cuenta, la invitación espera', () {
    expect(decidirDestino(haySesion: false, hayInvitacion: true),
        DestinoInicial.crearCuenta);
  });

  test('con sesión y sin invitación: a mis grupos', () {
    expect(decidirDestino(haySesion: true, hayInvitacion: false),
        DestinoInicial.misGrupos);
  });

  test('con sesión y con invitación: directo al grupo', () {
    expect(decidirDestino(haySesion: true, hayInvitacion: true),
        DestinoInicial.grupo);
  });
}
```

- [ ] **Step 2: Ejecutar el test y verificar que falla**

Run: `flutter test test/destino_inicial_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:santa_secreto/destino_inicial.dart'`

- [ ] **Step 3: Escribir la implementación mínima**

Crear `lib/destino_inicial.dart`:

```dart
/// A dónde manda el portero a quien abre la app.
enum DestinoInicial { crearCuenta, misGrupos, grupo }

/// La decisión vive aquí, separada del widget, para poder probarla sin
/// Firebase ni navegación. El portero solo la obedece.
///
/// Sin sesión siempre se va a crear cuenta, incluso habiendo invitación:
/// la invitación no se descarta, queda guardada y se usa en cuanto la
/// cuenta esté lista.
DestinoInicial decidirDestino({
  required bool haySesion,
  required bool hayInvitacion,
}) {
  if (!haySesion) return DestinoInicial.crearCuenta;
  return hayInvitacion ? DestinoInicial.grupo : DestinoInicial.misGrupos;
}
```

- [ ] **Step 4: Ejecutar el test y verificar que pasa**

Run: `flutter test test/destino_inicial_test.dart`
Expected: PASS — 4 tests

- [ ] **Step 5: Commit**

```bash
git add lib/destino_inicial.dart test/destino_inicial_test.dart
git commit -m "Extrae la decisión de destino a una función pura

El portero tiene cuatro rutas según haya sesión e invitación. Sacarla del
widget permite probar las cuatro sin Firebase ni navegación."
```

---

### Task 3: Claves de texto nuevas

Todas las cadenas que necesitan las pantallas nuevas, en los dos idiomas, antes de escribir las pantallas. Si se hace después, se escriben las pantallas con texto en duro y luego hay que volver.

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_es.arb`

**Interfaces:**
- Consumes: nada.
- Produces: en la clase `Textos`, los getters `cuentaFraseGancho`, `cuentaInvitadoA`, `cuentaYaTengoCuenta`, `cuentaNoTengoCuenta`, `misGruposCrear`, `misGruposUnirse`.

- [ ] **Step 1: Añadir las claves a `lib/l10n/app_en.arb`**

Insertar junto a las demás claves `cuenta*` y `misGrupos*`:

```json
"cuentaFraseGancho": "Create your account to discover who sends you the secret gifts",
"cuentaInvitadoA": "You've been invited to “{grupo}”",
"@cuentaInvitadoA": {
  "placeholders": { "grupo": { "type": "String" } }
},
"cuentaYaTengoCuenta": "Already have an account? Sign in",
"cuentaNoTengoCuenta": "No account yet? Create one",
"misGruposCrear": "Create a new group",
"misGruposUnirse": "Join with a code",
```

- [ ] **Step 2: Añadir las mismas claves a `lib/l10n/app_es.arb`**

```json
"cuentaFraseGancho": "Crea tu cuenta para descubrir quién te envía los regalos secretos",
"cuentaInvitadoA": "Te han invitado a «{grupo}»",
"cuentaYaTengoCuenta": "¿Ya tienes cuenta? Entra",
"cuentaNoTengoCuenta": "¿Aún no tienes cuenta? Crea una",
"misGruposCrear": "Crear un grupo nuevo",
"misGruposUnirse": "Unirme con un código",
```

Nota: los bloques `@clave` con `placeholders` van solo en la plantilla (`app_en.arb`), no en la traducción.

- [ ] **Step 3: Verificar que las dos listas coinciden**

Run:
```bash
python -c "
import json,io
en=json.load(io.open('lib/l10n/app_en.arb',encoding='utf-8'))
es=json.load(io.open('lib/l10n/app_es.arb',encoding='utf-8'))
ken={k for k in en if not k.startswith('@')}
kes={k for k in es if not k.startswith('@')}
print('solo en EN:', sorted(ken-kes))
print('solo en ES:', sorted(kes-ken))
print('total:', len(ken))
"
```
Expected: las dos listas vacías, total 204.

- [ ] **Step 4: Regenerar y comprobar que compila**

Run: `flutter gen-l10n && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_es.arb
git commit -m "Añade los textos del flujo de cuenta en inglés y español"
```

---

### Task 4: Selector de idioma reutilizable

Hoy el selector es privado dentro de `pantalla_inicio.dart`, que se va a borrar. Se extrae, y se añade la variante de casilla de formulario que pide el spec.

**Files:**
- Create: `lib/selector_idioma.dart`
- Test: `test/selector_idioma_test.dart`

**Interfaces:**
- Consumes: `Idioma.actual`, `Idioma.cambiar(Locale)`, `Idioma.soportados` (`lib/idioma.dart`).
- Produces:
  - `class IconoIdioma extends StatelessWidget { const IconoIdioma({super.key}); }` — el menú de la barra superior.
  - `class CampoIdioma extends StatelessWidget { const CampoIdioma({super.key}); }` — la casilla del formulario.

- [ ] **Step 1: Escribir el test que falla**

Crear `test/selector_idioma_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santa_secreto/l10n/app_localizations.dart';
import 'package:santa_secreto/selector_idioma.dart';

Widget _envoltorio(Widget hijo) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('es')],
      localizationsDelegates: Textos.localizationsDelegates,
      home: Scaffold(body: hijo),
    );

void main() {
  testWidgets('la casilla muestra el idioma actual', (tester) async {
    await tester.pumpWidget(_envoltorio(const CampoIdioma()));
    await tester.pumpAndSettle();
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('la casilla ofrece los dos idiomas al desplegarse', (tester) async {
    await tester.pumpWidget(_envoltorio(const CampoIdioma()));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<Locale>));
    await tester.pumpAndSettle();
    expect(find.text('Español'), findsOneWidget);
  });

  testWidgets('el icono se dibuja', (tester) async {
    await tester.pumpWidget(_envoltorio(const IconoIdioma()));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.language), findsOneWidget);
  });
}
```

- [ ] **Step 2: Ejecutar el test y verificar que falla**

Run: `flutter test test/selector_idioma_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:santa_secreto/selector_idioma.dart'`

- [ ] **Step 3: Escribir la implementación mínima**

Crear `lib/selector_idioma.dart`:

```dart
import 'package:flutter/material.dart';

import 'glass.dart';
import 'idioma.dart';
import 'l10n/app_localizations.dart';

String _nombre(Textos t, Locale l) =>
    l.languageCode == 'en' ? t.idiomaIngles : t.idiomaEspanol;

/// Menú de idioma para la barra superior. Vive en "Mis grupos", que es el
/// único sitio donde se puede cambiar una vez hay sesión.
class IconoIdioma extends StatelessWidget {
  const IconoIdioma({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    final actual = Localizations.localeOf(context).languageCode;
    return PopupMenuButton<Locale>(
      icon: Icon(Icons.language, color: colorNeutro.shade800),
      tooltip: t.idioma,
      onSelected: Idioma.cambiar,
      itemBuilder: (context) => [
        for (final locale in Idioma.soportados)
          CheckedPopupMenuItem<Locale>(
            value: locale,
            checked: locale.languageCode == actual,
            child: Text(_nombre(t, locale)),
          ),
      ],
    );
  }
}

/// Casilla de idioma para el formulario de registro. Es la primera
/// pantalla de la app, así que tiene que poder cambiarse ahí mismo: quien
/// no entienda inglés no llegaría a ningún otro sitio.
class CampoIdioma extends StatelessWidget {
  const CampoIdioma({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    final actual = Localizations.localeOf(context);
    return DropdownButtonFormField<Locale>(
      initialValue: Idioma.soportados
          .firstWhere((l) => l.languageCode == actual.languageCode),
      decoration: InputDecoration(
        labelText: t.idioma,
        prefixIcon: Icon(Icons.language, color: colorNeutro.shade700),
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white70,
      ),
      items: [
        for (final locale in Idioma.soportados)
          DropdownMenuItem<Locale>(value: locale, child: Text(_nombre(t, locale))),
      ],
      onChanged: (locale) {
        if (locale != null) Idioma.cambiar(locale);
      },
    );
  }
}
```

- [ ] **Step 4: Ejecutar el test y verificar que pasa**

Run: `flutter test test/selector_idioma_test.dart`
Expected: PASS — 3 tests

Si `initialValue` da error de parámetro no definido, es que esta versión de Flutter usa `value:` en `DropdownButtonFormField`. Cambiarlo y volver a ejecutar.

- [ ] **Step 5: Commit**

```bash
git add lib/selector_idioma.dart test/selector_idioma_test.dart
git commit -m "Extrae el selector de idioma y añade la variante de casilla

Vivía privado en pantalla_inicio.dart, que se va a borrar. La casilla es
para el formulario de registro: es la primera pantalla, y quien no
entienda inglés no llegaría a ningún otro sitio para cambiarlo."
```

---

### Task 5: Pantallas de cuenta separadas

Hoy `pantalla_cuenta.dart` es una sola pantalla con un interruptor `_modoCrear`. Se parte en dos, con la lógica de acceso compartida en un helper.

**Files:**
- Create: `lib/acceso_cuenta.dart`
- Create: `lib/pantalla_crear_cuenta.dart`
- Create: `lib/pantalla_iniciar_sesion.dart`
- Test: `test/pantallas_cuenta_test.dart`

**Interfaces:**
- Consumes: `llamarFuncion` y `FuncionError` (`lib/funciones.dart`), `guardarSesion` (`lib/sesion.dart`), `CampoIdioma` (Task 4), `cuentaFraseGancho` / `cuentaInvitadoA` / `cuentaYaTengoCuenta` / `cuentaNoTengoCuenta` (Task 3).
- Produces:
  - `Future<ResultadoAcceso> entrarConCuenta({required String nickname, required String password, required bool registrando})`
  - `class ResultadoAcceso { final String nickname; final List<Map<String, dynamic>> grupos; }`
  - `class PantallaCrearCuenta extends StatefulWidget { final String? nombreGrupoInvitacion; const PantallaCrearCuenta({super.key, this.nombreGrupoInvitacion}); }`
  - `class PantallaIniciarSesion extends StatefulWidget { const PantallaIniciarSesion({super.key}); }`

**Nota sobre la navegación posterior:** ambas pantallas, al terminar, llaman a `irADondeToque(context, resultado)` — definida en Task 6. **Implementar Task 6 antes de compilar esta**, o dejar el import y aceptar que `flutter analyze` falle hasta que Task 6 exista.

- [ ] **Step 1: Escribir el test que falla**

Crear `test/pantallas_cuenta_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santa_secreto/l10n/app_localizations.dart';
import 'package:santa_secreto/pantalla_crear_cuenta.dart';

Widget _envoltorio(Widget hijo) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('es')],
      localizationsDelegates: Textos.localizationsDelegates,
      home: hijo,
    );

void main() {
  testWidgets('sin invitación muestra la frase gancho', (tester) async {
    await tester.pumpWidget(_envoltorio(const PantallaCrearCuenta()));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Create your account to discover who sends you the secret gifts'),
        findsOneWidget);
  });

  testWidgets('con invitación muestra el grupo en vez de la frase', (tester) async {
    await tester.pumpWidget(
        _envoltorio(const PantallaCrearCuenta(nombreGrupoInvitacion: 'Navidad Familia')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Navidad Familia'), findsOneWidget);
    expect(
        find.text(
            'Create your account to discover who sends you the secret gifts'),
        findsNothing);
  });

  testWidgets('tiene los tres campos y la casilla de idioma', (tester) async {
    await tester.pumpWidget(_envoltorio(const PantallaCrearCuenta()));
    await tester.pumpAndSettle();
    expect(find.text('Nickname'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Ejecutar el test y verificar que falla**

Run: `flutter test test/pantallas_cuenta_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:santa_secreto/pantalla_crear_cuenta.dart'`

- [ ] **Step 3: Escribir el helper de acceso**

Crear `lib/acceso_cuenta.dart`:

```dart
import 'funciones.dart';
import 'sesion.dart';

/// Lo que devuelve el servidor al entrar: el nickname tal como se escribió
/// y los grupos vinculados a esa cuenta.
class ResultadoAcceso {
  final String nickname;
  final List<Map<String, dynamic>> grupos;
  const ResultadoAcceso(this.nickname, this.grupos);
}

/// Registro e inicio de sesión comparten casi todo: registrar es lo mismo
/// más una llamada previa. Vive fuera de las pantallas para que las dos
/// hagan exactamente lo mismo y no se desincronicen.
///
/// Lanza FuncionError, que la pantalla traduce con `e.texto(t)`.
Future<ResultadoAcceso> entrarConCuenta({
  required String nickname,
  required String password,
  required bool registrando,
}) async {
  if (registrando) {
    await llamarFuncion('registrarCuenta', {'nickname': nickname, 'password': password});
  }
  final r = await llamarFuncion(
      'iniciarSesionCuenta', {'nickname': nickname, 'password': password});
  await guardarSesion(nickname, password);
  return ResultadoAcceso(
    r['nickname'] as String,
    List<Map<String, dynamic>>.from(
        (r['grupos'] as List).map((g) => Map<String, dynamic>.from(g as Map))),
  );
}
```

- [ ] **Step 4: Escribir la pantalla de crear cuenta**

Crear `lib/pantalla_crear_cuenta.dart`:

```dart
import 'package:flutter/material.dart';

import 'acceso_cuenta.dart';
import 'funciones.dart';
import 'glass.dart';
import 'l10n/app_localizations.dart';
import 'ocasion.dart';
import 'pantalla_iniciar_sesion.dart';
import 'pantalla_raiz.dart';
import 'selector_idioma.dart';
import 'tematica.dart';

/// Misma exigencia que valida el servidor: 8+, mayúscula, minúscula,
/// número y símbolo. Se comprueba aquí para no gastar una llamada.
final RegExp _regexPassword =
    RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}$');

/// Primera pantalla de la app.
class PantallaCrearCuenta extends StatefulWidget {
  /// Si se llegó por un QR, el nombre del grupo que invitó. Se muestra en
  /// vez de la frase gancho: quien escanea necesita saber a qué entra, no
  /// leer un eslogan.
  final String? nombreGrupoInvitacion;

  const PantallaCrearCuenta({super.key, this.nombreGrupoInvitacion});

  @override
  State<PantallaCrearCuenta> createState() => _PantallaCrearCuentaState();
}

class _PantallaCrearCuentaState extends State<PantallaCrearCuenta> {
  final _nickname = TextEditingController();
  final _password = TextEditingController();
  final _confirmar = TextEditingController();
  bool _cargando = false;
  bool _verPassword = false;

  @override
  void dispose() {
    _nickname.dispose();
    _password.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _enviar() async {
    final t = Textos.of(context);
    final nickname = _nickname.text.trim();
    final password = _password.text;

    if (nickname.isEmpty || password.isEmpty) {
      _avisar('⚠️ ${t.cuentaFaltanDatos}');
      return;
    }
    if (!_regexPassword.hasMatch(password)) {
      _avisar('⚠️ ${t.errorPasswordDebil}');
      return;
    }
    if (password != _confirmar.text) {
      _avisar('⚠️ ${t.cuentaNoCoinciden}');
      return;
    }

    setState(() => _cargando = true);
    try {
      final r = await entrarConCuenta(
          nickname: nickname, password: password, registrando: true);
      if (!mounted) return;
      await irADondeToque(context, r);
    } on FuncionError catch (e) {
      _avisar('⚠️ ${e.texto(t)}');
    } catch (e) {
      _avisar('⚠️ ${t.errorInesperado(e.toString())}');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    final invitacion = widget.nombreGrupoInvitacion;
    return Theme(
      data: temaGlass(colorNeutro),
      child: FondoNeutro(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              children: [
                Image.asset('assets/logo.png', height: 120),
                const SizedBox(height: 8),
                Text(t.appTitle,
                    textAlign: TextAlign.center, style: tituloGlass(colorNeutro)),
                const SizedBox(height: 16),
                GlassCard(
                  color: colorNeutro,
                  child: Text(
                    invitacion != null && invitacion.isNotEmpty
                        ? t.cuentaInvitadoA(invitacion)
                        : t.cuentaFraseGancho,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black87, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 24),
                const CampoIdioma(),
                const SizedBox(height: 16),
                GlassTextField(
                    controller: _nickname,
                    labelText: t.cuentaNickname,
                    icon: Icons.person_outline),
                const SizedBox(height: 16),
                GlassTextField(
                  controller: _password,
                  labelText: t.cuentaPassword,
                  helperText: t.cuentaPasswordAyuda,
                  icon: Icons.lock_outline,
                  obscureText: !_verPassword,
                  suffixIcon: IconButton(
                    icon: Icon(_verPassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _verPassword = !_verPassword),
                  ),
                ),
                const SizedBox(height: 16),
                GlassTextField(
                    controller: _confirmar,
                    labelText: t.cuentaConfirmar,
                    icon: Icons.lock_outline,
                    obscureText: !_verPassword),
                const SizedBox(height: 24),
                GlassButton(
                  color: colorNeutro.shade600,
                  icon: Icons.person_add_alt,
                  label: t.cuentaCrearTitulo,
                  onPressed: _cargando ? null : _enviar,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _cargando
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const PantallaIniciarSesion()),
                          ),
                  child: Text(t.cuentaYaTengoCuenta, textAlign: TextAlign.center),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Escribir la pantalla de iniciar sesión**

Crear `lib/pantalla_iniciar_sesion.dart`. Es la misma estructura sin frase gancho, sin casilla de idioma y sin confirmación de contraseña:

```dart
import 'package:flutter/material.dart';

import 'acceso_cuenta.dart';
import 'funciones.dart';
import 'glass.dart';
import 'l10n/app_localizations.dart';
import 'ocasion.dart';
import 'pantalla_raiz.dart';
import 'tematica.dart';

/// Entrar con una cuenta que ya existe.
///
/// No lleva casilla de idioma a propósito: quien vuelve ya tiene el suyo
/// guardado, y quien llega desde un dispositivo nuevo pasa antes por la
/// pantalla de registro, donde sí está.
class PantallaIniciarSesion extends StatefulWidget {
  const PantallaIniciarSesion({super.key});

  @override
  State<PantallaIniciarSesion> createState() => _PantallaIniciarSesionState();
}

class _PantallaIniciarSesionState extends State<PantallaIniciarSesion> {
  final _nickname = TextEditingController();
  final _password = TextEditingController();
  bool _cargando = false;
  bool _verPassword = false;

  @override
  void dispose() {
    _nickname.dispose();
    _password.dispose();
    super.dispose();
  }

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _enviar() async {
    final t = Textos.of(context);
    final nickname = _nickname.text.trim();
    final password = _password.text;
    if (nickname.isEmpty || password.isEmpty) {
      _avisar('⚠️ ${t.cuentaFaltanDatos}');
      return;
    }
    setState(() => _cargando = true);
    try {
      final r = await entrarConCuenta(
          nickname: nickname, password: password, registrando: false);
      if (!mounted) return;
      await irADondeToque(context, r);
    } on FuncionError catch (e) {
      _avisar('⚠️ ${e.texto(t)}');
    } catch (e) {
      _avisar('⚠️ ${t.errorInesperado(e.toString())}');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Textos.of(context);
    return Theme(
      data: temaGlass(colorNeutro),
      child: FondoNeutro(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: GlassAppBar(title: Text(t.cuentaEntrarTitulo), color: colorNeutro),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              children: [
                Image.asset('assets/logo.png', height: 96),
                const SizedBox(height: 24),
                GlassTextField(
                    controller: _nickname,
                    labelText: t.cuentaNickname,
                    icon: Icons.person_outline),
                const SizedBox(height: 16),
                GlassTextField(
                  controller: _password,
                  labelText: t.cuentaPassword,
                  icon: Icons.lock_outline,
                  obscureText: !_verPassword,
                  suffixIcon: IconButton(
                    icon: Icon(_verPassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _verPassword = !_verPassword),
                  ),
                ),
                const SizedBox(height: 24),
                GlassButton(
                  color: colorNeutro.shade600,
                  icon: Icons.login,
                  label: t.cuentaEntrarTitulo,
                  onPressed: _cargando ? null : _enviar,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _cargando ? null : () => Navigator.pop(context),
                  child: Text(t.cuentaNoTengoCuenta, textAlign: TextAlign.center),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Ejecutar los tests (tras completar Task 6)**

Run: `flutter test test/pantallas_cuenta_test.dart`
Expected: PASS — 3 tests

- [ ] **Step 7: Commit**

```bash
git add lib/acceso_cuenta.dart lib/pantalla_crear_cuenta.dart lib/pantalla_iniciar_sesion.dart test/pantallas_cuenta_test.dart
git commit -m "Separa registro e inicio de sesión en dos pantallas

Era una sola con un interruptor _modoCrear. La lógica común queda en
acceso_cuenta.dart para que las dos hagan lo mismo y no se desincronicen.
El registro lleva la frase gancho, la casilla de idioma y confirmación de
contraseña; el login no necesita ninguna de las tres."
```

---

### Task 6: El portero

La raíz de la app. Lee sesión e invitación, decide con `decidirDestino`, y navega.

**Files:**
- Create: `lib/pantalla_raiz.dart`
- Modify: `lib/main.dart:53` (cambiar `home:`)

**Interfaces:**
- Consumes: `decidirDestino` / `DestinoInicial` (Task 2), `guardarInvitacion` / `leerInvitacion` / `borrarInvitacion` (Task 1), `leerSesion` (`lib/sesion.dart`), `ResultadoAcceso` (Task 5).
- Produces: `class PantallaRaiz extends StatefulWidget`, y `Future<void> irADondeToque(BuildContext context, ResultadoAcceso resultado)` que usan las dos pantallas de cuenta.

- [ ] **Step 1: Escribir el portero**

Crear `lib/pantalla_raiz.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'acceso_cuenta.dart';
import 'destino_inicial.dart';
import 'glass.dart';
import 'invitacion_pendiente.dart';
import 'ocasion.dart';
import 'pantalla_crear_cuenta.dart';
import 'pantalla_mis_grupos.dart';
import 'pantalla_registro.dart';
import 'sesion.dart';
import 'tematica.dart';

/// Primera pantalla real de la app: decide a dónde va cada quien.
///
/// Solo muestra un indicador mientras lee disco y, si hace falta, valida
/// el código de la URL. Nunca se queda como pantalla visible.
class PantallaRaiz extends StatefulWidget {
  const PantallaRaiz({super.key});

  @override
  State<PantallaRaiz> createState() => _PantallaRaizState();
}

class _PantallaRaizState extends State<PantallaRaiz> {
  @override
  void initState() {
    super.initState();
    _arrancar();
  }

  /// Si la URL trae ?codigo=XXXX se guarda como invitación ANTES de
  /// decidir destino. Se valida contra Firestore para no guardar códigos
  /// inventados, y de paso se obtiene el nombre del grupo, que la
  /// pantalla de registro muestra.
  Future<void> _capturarInvitacionDeLaUrl() async {
    if (!kIsWeb) return;
    final codigo = Uri.base.queryParameters['codigo']?.trim().toUpperCase();
    if (codigo == null || codigo.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('grupos')
          .doc(codigo)
          .get()
          .timeout(const Duration(seconds: 6));
      if (!doc.exists) return;
      await guardarInvitacion(codigo, doc.data()!['nombreGrupo'] as String? ?? '');
    } catch (_) {
      // Sin conexión o código inválido: se sigue el flujo normal. La
      // próxima apertura con el mismo enlace volverá a intentarlo.
    }
  }

  Future<void> _arrancar() async {
    await _capturarInvitacionDeLaUrl();
    final sesion = await leerSesion();
    final invitacion = await leerInvitacion();
    if (!mounted) return;

    switch (decidirDestino(
        haySesion: sesion != null, hayInvitacion: invitacion != null)) {
      case DestinoInicial.crearCuenta:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                PantallaCrearCuenta(nombreGrupoInvitacion: invitacion?.nombreGrupo),
          ),
        );
      case DestinoInicial.grupo:
        await _entrarAlGrupo(context, invitacion!);
      case DestinoInicial.misGrupos:
        // La sesión guardada puede haber dejado de valer: contraseña
        // cambiada desde otro dispositivo, cuenta borrada, o sin
        // conexión. Sin este catch la app se queda en el indicador de
        // carga para siempre, que es la peor pantalla posible.
        try {
          final r = await entrarConCuenta(
              nickname: sesion!.nickname, password: sesion.password, registrando: false);
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    PantallaMisGrupos(nickname: r.nickname, grupos: r.grupos)),
          );
        } catch (_) {
          await cerrarSesion();
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const PantallaCrearCuenta()),
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
        data: temaGlass(colorNeutro),
        child: FondoNeutro(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(child: CircularProgressIndicator(color: colorNeutro.shade700)),
          ),
        ),
      );
}

/// Entra al grupo de una invitación y la borra. Borrarla importa: si no,
/// cada apertura de la app volvería a meter a esa persona en ese grupo
/// para siempre.
Future<void> _entrarAlGrupo(BuildContext context, InvitacionPendiente i) async {
  final doc =
      await FirebaseFirestore.instance.collection('grupos').doc(i.codigo).get();
  await borrarInvitacion();
  if (!context.mounted || !doc.exists) return;
  final data = doc.data()!;
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => PantallaRegistro(
        codigo: i.codigo,
        ocasion: Ocasion.desdeId(data['ocasion'] as String),
        valorMinimo: data['valorMinimo'] as String? ?? '',
        nombreGrupo: data['nombreGrupo'] as String? ?? '',
      ),
    ),
  );
}

/// A dónde se va tras crear cuenta o iniciar sesión. Lo usan las dos
/// pantallas de cuenta para no duplicar la decisión.
Future<void> irADondeToque(BuildContext context, ResultadoAcceso resultado) async {
  final invitacion = await leerInvitacion();
  if (!context.mounted) return;
  if (invitacion != null) {
    await _entrarAlGrupo(context, invitacion);
    return;
  }
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(
      builder: (_) =>
          PantallaMisGrupos(nickname: resultado.nickname, grupos: resultado.grupos),
    ),
    (r) => false,
  );
}
```

- [ ] **Step 2: Apuntar `main.dart` al portero**

En `lib/main.dart`: cambiar el import `import 'pantalla_inicio.dart';` por `import 'pantalla_raiz.dart';`, y la línea 53 `home: const PantallaInicio(),` por `home: const PantallaRaiz(),`.

- [ ] **Step 3: Comprobar que compila**

Run: `flutter analyze`
Expected: `No issues found!` (salvo avisos por `pantalla_inicio.dart` y `pantalla_cuenta.dart`, que se borran en Task 9)

- [ ] **Step 4: Ejecutar toda la suite**

Run: `flutter test`
Expected: PASS — los tests de Tasks 1, 2, 4 y 5

- [ ] **Step 5: Commit**

```bash
git add lib/pantalla_raiz.dart lib/main.dart
git commit -m "Añade el portero como raíz de la app

Lee sesión e invitación pendiente y decide destino con decidirDestino.
El ?codigo= de la URL se captura y valida ANTES de decidir, para que una
invitación sobreviva al registro."
```

---

### Task 7: "Mis grupos" pasa a ser autónoma

Hoy es una lista de solo lectura, con los grupos recibidos como lista fija. Como pantalla principal necesita poder crear, unirse, recargar y cambiar el idioma.

**Files:**
- Modify: `lib/pantalla_mis_grupos.dart` (pasa de `StatelessWidget` a `StatefulWidget`)

**Interfaces:**
- Consumes: `IconoIdioma` (Task 4), `entrarConCuenta` (Task 5), `leerSesion` / `cerrarSesion` (`lib/sesion.dart`), `PantallaCrearGrupo()` y `PantallaUnirseGrupo()` (constructores const, sin parámetros), `misGruposCrear` / `misGruposUnirse` (Task 3).
- Produces: mismo constructor `PantallaMisGrupos({required String nickname, required List<Map<String, dynamic>> grupos})`.

- [ ] **Step 1: Convertir a StatefulWidget con estado recargable**

En `lib/pantalla_mis_grupos.dart`, sustituir la clase por un `StatefulWidget` cuyo estado arranca con `_grupos = widget.grupos` y añade:

```dart
  /// La lista llega como semilla desde el login para pintar sin espera,
  /// pero deja de valer en cuanto se crea o se entra a un grupo. Se
  /// recarga al volver de esas pantallas: si no, un grupo recién creado
  /// no aparecería hasta cerrar sesión y volver a entrar.
  Future<void> _recargar() async {
    final sesion = await leerSesion();
    if (sesion == null) return;
    try {
      final r = await entrarConCuenta(
          nickname: sesion.nickname, password: sesion.password, registrando: false);
      if (!mounted) return;
      setState(() => _grupos = r.grupos);
    } catch (_) {
      // Sin conexión se queda la lista que ya había, que es mejor que
      // vaciarla o mostrar un error por algo secundario.
    }
  }

  Future<void> _abrir(Widget pantalla) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
    await _recargar();
  }
```

- [ ] **Step 2: Añadir el icono de idioma a la barra**

En `actions:` del `GlassAppBar`, antes del botón de cerrar sesión: `const IconoIdioma(),`

- [ ] **Step 3: Añadir los dos botones bajo la lista**

Envolver el `body` en una `Column` con la lista en `Expanded` y, debajo:

```dart
Padding(
  padding: const EdgeInsets.all(20),
  child: Column(
    children: [
      GlassButton(
        color: colorNeutro.shade600,
        icon: Icons.add_circle_outline,
        label: t.misGruposCrear,
        onPressed: () => _abrir(const PantallaCrearGrupo()),
      ),
      const SizedBox(height: 12),
      GlassOutlineButton(
        color: colorNeutro,
        icon: Icons.groups_outlined,
        label: t.misGruposUnirse,
        onPressed: () => _abrir(const PantallaUnirseGrupo()),
      ),
    ],
  ),
),
```

- [ ] **Step 4: Hacer que cerrar sesión vuelva al registro**

Sustituir el `Navigator.pop(context)` del botón de cerrar sesión por:

```dart
Navigator.pushAndRemoveUntil(
  context,
  MaterialPageRoute(builder: (_) => const PantallaCrearCuenta()),
  (r) => false,
);
```

- [ ] **Step 5: Comprobar que compila y pasa la suite**

Run: `flutter analyze && flutter test`
Expected: `No issues found!` y todos los tests en verde

- [ ] **Step 6: Commit**

```bash
git add lib/pantalla_mis_grupos.dart
git commit -m "Mis grupos pasa a ser la pantalla principal

Gana crear grupo, unirse con código y el icono de idioma, que es el único
sitio donde se puede cambiar con sesión abierta. Y recarga la lista al
volver: la recibía como lista fija, así que un grupo recién creado no
aparecía."
```

---

### Task 8: La vinculación de cuenta deja de fallar en silencio

**Files:**
- Modify: `functions/index.js` — función `vincularCuentaSiAplica`

- [ ] **Step 1: Cambiar el fallo silencioso por un error visible**

Sustituir el cuerpo de `vincularCuentaSiAplica` por:

```javascript
async function vincularCuentaSiAplica(nickname, password, entrada) {
  if (!nickname || !password) return;
  const clave = normalizarNickname(nickname);
  const ref = usuarioRef(clave);
  const snap = await ref.get();
  if (!snap.exists || !bcrypt.compareSync(password, snap.data().hash)) {
    // Antes se ignoraba en silencio para no romper el alta por un extra.
    // Con la cuenta ya obligatoria eso deja de valer: el grupo no
    // aparecería en "Mis grupos" y nadie sabría por qué.
    throw new HttpsError("unauthenticated", "La sesión de tu cuenta no es válida. Vuelve a entrar.", {clave: "sesion_invalida"});
  }
  await ref.update({grupos: admin.firestore.FieldValue.arrayUnion(entrada)});
}
```

- [ ] **Step 2: Añadir la clave de error a los dos ARB**

En `app_en.arb`: `"errorSesionInvalida": "Your account session is no longer valid. Please sign in again.",`
En `app_es.arb`: `"errorSesionInvalida": "La sesión de tu cuenta ya no es válida. Vuelve a entrar.",`

En `lib/funciones.dart`, dentro del `switch (clave)` de la extensión `MensajeLocalizado`, añadir una línea junto a las demás (van antes del `_ => mensaje` final):

```dart
        'sesion_invalida' => t.errorSesionInvalida,
```

- [ ] **Step 3: Desplegar solo las funciones**

Run: `firebase deploy --only functions`
Expected: `Deploy complete!`

- [ ] **Step 4: Commit**

```bash
git add functions/index.js lib/l10n/app_en.arb lib/l10n/app_es.arb lib/funciones.dart
git commit -m "vincularCuentaSiAplica deja de fallar en silencio

Con la cuenta opcional, ignorar credenciales malas era lo correcto: no
romper el alta por un extra. Con la cuenta obligatoria, el grupo no
aparecería en Mis grupos y nadie sabría por qué."
```

---

### Task 9: Borrar lo muerto y verificar de punta a punta

**Files:**
- Delete: `lib/pantalla_inicio.dart`
- Delete: `lib/pantalla_cuenta.dart`

- [ ] **Step 1: Comprobar que nadie los referencia**

Run: `grep -rn "pantalla_inicio\|PantallaInicio\|pantalla_cuenta\|PantallaCuenta" lib/ test/`
Expected: sin resultados

- [ ] **Step 2: Borrarlos**

Run: `git rm lib/pantalla_inicio.dart lib/pantalla_cuenta.dart`

- [ ] **Step 3: Verificar**

Run: `flutter analyze && flutter test && flutter build web --release`
Expected: `No issues found!`, todos los tests en verde, `Built build\web`

- [ ] **Step 4: Desplegar y comprobar contra el servidor**

Run:
```bash
firebase deploy --only hosting
curl -s "https://santa-secreto-860c3.web.app/main.dart.js?cb=$RANDOM" | sha256sum | cut -c1-16
sha256sum build/web/main.dart.js | cut -c1-16
```
Expected: los dos hashes iguales.

- [ ] **Step 5: Probar en el dispositivo los cuatro caminos**

Borrar datos del sitio o usar incógnito antes de cada uno (el service worker sirve el build anterior).

1. Abrir sin sesión y sin código → sale **Crear cuenta**, con logo, nombre, la frase y la casilla de idioma.
2. Crear una cuenta → va a **Mis grupos**, vacío. Crear un grupo desde ahí → al volver, **el grupo aparece sin recargar**.
3. Compartir el QR, abrirlo en otro navegador sin sesión → sale **Crear cuenta** con *"You've been invited to X"*. **Recargar a mitad del registro** y terminarlo → entra al grupo.
4. Abrir de nuevo la app → va a **Mis grupos**, no vuelve a meterse en el grupo (la invitación se borró).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "Elimina pantalla_inicio y pantalla_cuenta

Sustituidas por el portero y las dos pantallas de cuenta separadas."
```

---

## Pendientes que este plan NO resuelve

Están en el spec y siguen abiertos. Los dos juntos significan que cada contraseña olvidada es una cuenta perdida:

1. **No hay recuperación de contraseña.** Sin correo ni teléfono, no hay camino de vuelta.
2. **La contraseña exige 8+ con mayúscula, minúscula, número y símbolo**, y ahora es obligatoria para todo el mundo.
