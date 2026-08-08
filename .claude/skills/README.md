# Skills de Flutter/Dart — santa_secreto

Subconjunto curado de [dhruvanbhalara/skills](https://github.com/dhruvanbhalara/skills)
(MIT, © 2026 Dhruvan Bhalara — ver `LICENSE-dhruvanbhalara-skills`).

**Origen:** commit `28b936d` (2026-07-10). Descargadas el 2026-08-08 sin modificaciones.

## Qué está instalado (9 de 42)

### Flutter
| Skill | Cubre |
|---|---|
| `flutter-firebase` | Auth, Firestore (`withConverter`, batch writes), FCM, Crashlytics, security rules, emulador |
| `flutter-setup-localization` | ARB, ICU, `flutter_localizations` — el proyecto ya usa `generate: true` |
| `flutter-fix-layout-issues` | RenderFlex overflow, alturas/anchos unbounded, ParentData mal usado |
| `flutter-security` | AES-256-GCM, secure storage, gates biométricos, memory safety |
| `flutter-add-widget-test` | `WidgetTester`, patrones de pump, finders, targeting por Key |
| `flutter-debugging` | Error boundaries, logging estructurado, análisis de memoria |
| `flutter-devtools` | Inspector, propiedades visuales de debug, exponer estado custom |

### Dart
Ambas son Dart puro (`platforms: "dart"`), sin dependencia de Flutter. Aplican a
CLI, backend, packages y al Dart dentro de la app.

| Skill | Cubre |
|---|---|
| `dart-modern-syntax` | Dart 3.0–3.12: records, extension types, named params privados, wildcards |
| `dart-use-pattern-matching` | Switch expressions, sealed classes, control de flujo exhaustivo |

> **⚠️ Versión del SDK.** Este proyecto usa **Dart 3.10.4** (Flutter 3.38.5).
> `dart-modern-syntax` documenta features hasta 3.12 que **no compilan aquí**:
> - **Private named parameters** (`User({required String this._name})`) — requiere 3.12
> - **Primary constructors** (`class Point(int x, int y);`) — requiere 3.12, experimental
>
> Sí están disponibles: records/patterns (3.0), extension types (3.3), wildcards `_` (3.7).
> `dart-use-pattern-matching` es 100% aplicable — todo es Dart 3.0+.

## Qué se dejó fuera a propósito

Las skills de arquitectura del repo origen (`flutter-apply-architecture-best-practices`,
`flutter-bloc`, `flutter-bloc-forms`, `flutter-code-gen`) asumen **BLoC + injectable +
Clean Architecture**. `santa_secreto` no usa gestor de estado ni DI, así que instalarlas
haría que los agentes empujen un refactor hacia un stack que no elegimos.

Nota: `flutter-firebase` también asume `AuthRepository` + `AuthBloc`. Sus reglas de
Firestore y de security rules valen igual; ignorá la parte de BLoC.

## Alcance

Instaladas a nivel de proyecto. Para usarlas en cualquier proyecto Flutter,
copiá las carpetas a `~/.claude/skills/`.

## Actualizar

```bash
gh api "repos/dhruvanbhalara/skills/contents/skills/flutter/<nombre>/SKILL.md" \
  --jq '.content' | base64 -d > .claude/skills/<nombre>/SKILL.md
```

Catálogo completo: https://dhruvanbhalara.github.io/skills/
