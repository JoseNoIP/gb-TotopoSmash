# CLAUDE.md — Godot Mobile Game Template

Guía autoritativa de desarrollo para Claude Code. **Lee este archivo completo antes de cualquier tarea.**
Versión del template: ver historial de git. Repo del template: `/Users/norb/Dockers/gb-GameTemplate`.

---

## Stack Tecnológico

| Capa | Tecnología |
|---|---|
| Motor | Godot 4.7 (GDScript con tipado estático) |
| Testing | GUT (Godot Unit Testing) v9.7.1 |
| Lint/Format | gdtoolkit (`gdlint` / `gdformat`) vía pipx |
| Plataforma | iOS 14+ / Android API 24+ |
| CI/CD | GitHub Actions → AAB firmado en Google Play Store (Internal/Production) |
| Arte | Pixel art / Vector toony |
| Control | Touch drag relativo (1 dedo) |

---

## Comandos Esenciales

```bash
# Instalar herramientas de linting (una sola vez)
brew install pipx && pipx install gdtoolkit

# Lint — 0 errores antes de cualquier commit
gdlint src/

# Format check
gdformat --check src/

# Tests headless
godot --headless -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit -gexit -glog=2

# Export Debug — Android
godot --headless --export-debug "Android" builds/debug/Game.apk

# Export Release — Android
godot --headless --export-release "Android" builds/release/Game.apk
```

---

## Estructura de Carpetas (Feature-First)

```
src/
├── core/                   # Singletons / Autoloads globales
│   ├── Constants.gd        # Constantes tipadas (cargado PRIMERO)
│   ├── EventBus.gd         # Bus de señales (TODA comunicación cross-feature)
│   ├── GameManager.gd      # Máquina de estados de partida
│   └── SaveManager.gd      # Persistencia JSON (user://)
├── features/
│   ├── player/
│   ├── projectiles/
│   ├── enemies/
│   ├── powerups/
│   ├── gems/
│   ├── meta/
│   ├── audio/
│   ├── vfx/
│   └── ui/
├── scenes/                 # Escenas raíz (.tscn)
└── shared/                 # Recursos compartidos
assets/
├── sprites/
├── audio/
└── fonts/
tests/
└── unit/
addons/
└── gut/
builds/
├── debug/
└── release/
tools/
├── gen_assets.py           # Íconos y assets procedurales
└── fetch_ai_assets.py      # Backgrounds y sprites con Pollinations.ai
```

---

## Estándares de Código GDScript

### Nomenclatura
| Elemento | Convención | Ejemplo |
|---|---|---|
| Clases | PascalCase, **antes de extends** | `class_name EnemyTank` |
| Variables / funciones | snake_case | `var max_health: int` |
| Constantes | SCREAMING_SNAKE_CASE | `const BASE_DAMAGE: float = 10.0` |
| Señales | snake_case (pasado) | `signal enemy_destroyed(id: int)` |
| Archivos | snake_case | `enemy_tank.gd` |
| Parámetros privados | prefijo `_` | `var _state: GameState` |

### Tipado estático obligatorio
```gdscript
# CORRECTO
var speed: float = 200.0
func take_damage(amount: int) -> void: pass

# PROHIBIDO
var speed = 200.0
func take_damage(amount): pass
```

### Event-Driven Architecture (regla absoluta)
**TODA comunicación entre features NO relacionadas va por `EventBus.gd`.**

```gdscript
EventBus.enemy_destroyed.emit(id, position, xp_value)
EventBus.enemy_destroyed.connect(_on_enemy_destroyed)
func _exit_tree() -> void:
    EventBus.enemy_destroyed.disconnect(_on_enemy_destroyed)
```

---

## Reglas Anti-Alucinación (CRÍTICO — NO NEGOCIABLE)

1. **PROHIBIDO** inventar nombres de métodos de la API de Godot → verificar en docs o WebSearch.
2. **PROHIBIDO** agregar addons no presentes en `addons/` → verificar con `ls addons/`.
3. **PROHIBIDO** usar `get_node()` con rutas hardcodeadas → usar `@onready var` o señales.
4. **PROHIBIDO** crear `.tscn` referenciando scripts inexistentes.
5. **SIEMPRE** leer un archivo con `Read` antes de editarlo.
6. **SIEMPRE** verificar existencia de archivos con `ls` o `find` antes de referenciarlos.
7. Si una función de Godot parece existir pero no hay certeza → declarar la duda, no inventar.
8. Los valores del GDD son la única fuente de verdad para mecánicas.
9. **`const ARRAY: Array[T]`** — inválido como `const` en GDScript 4. Usar `const POOL: Array = [...]`.
10. **`class_name X` + autoload `X`** → conflicto fatal. Singletons SIN `class_name`.
11. **Autoload de constantes PRIMERO** en `[autoload]` de project.godot.
12. **`change_scene_to_file()` en `_ready()`** → usar `.call_deferred()` siempre.
13. **Herencia por class_name** → usar `extends "res://ruta/A.gd"` (path-based) en headless.
14. **Preload-consts** → deben ser PascalCase (`const EnemyBasicGd := preload(...)`).
15. **`class_name` como tipo en otro script** → usar clase base como tipo + `set(&"prop", val)`.
16. **`for id: Variant in dict.keys()`** → tipo `Variant` no válido en for-loop. Usar índice entero.
17. **`add_child()` desde callback de física** → usar `call_deferred(&"add_child", node)`.

### Reglas Android CI/CD
18. **Godot 4.7 no exporta `.aab` directamente** → exportar `.apk` primero, luego `./gradlew bundleRelease`.
19. **`--install-android-build-template`** extrae `android_source.zip` y escribe `.build_version`.
20. **`shouldSign()` es `false` por defecto** → pasar `-Pperform_signing=true` + keystore props a `bundleRelease`.
20b. **`export_version_code` default=1** → pasar `-Pexport_version_code=N` a `bundleRelease`. Usar `$(( ($(date +%s) - 1704067200) / 60 ))` (minutos desde 2024-01-01).
21. **Package name default es `com.godot.game`** → pasar `-Pexport_package_name=com.tuempresa.tujuego`.
22. **`assetPackInstallTime/src/main/assets` debe existir** → `mkdir -p` antes de Gradle.
23. **Primera subida a Play Store debe ser manual** desde Play Console.
24. **Pre-heat obligatorio** → `godot --headless --editor --quit || true` antes del export.
25. **`bundleRelease` no firma con `-Pperform_signing`** → firmar AAB con `jarsigner` explícitamente tras buildear.

### Reglas Multi-idioma / i18n
26. **`LocalizationManager` NO lleva `class_name`** — es autoload.
27. **No usar archivos `.translation` binarios en CI/CD** → CSV parseado en runtime con `FileAccess.get_csv_line()`.
28. **Saltos de línea en CSV** → usar `[BR]` como placeholder, reemplazar en `_load_csv()`.
29. **`LocalizationManager` carga DESPUÉS de `SaveManager`** en project.godot.
30. **El archivo de traducciones NO puede tener extensión `.csv` en Android** (Godot bug #38957) → usar `.txt` + `include_filter="*.txt"` en export_presets.cfg.
31. **Chino/japonés requieren fuente especial** → no añadir sin fuente compatible.

### Reglas de UI programática
32. **`set_anchors_preset(PRESET_BOTTOM_WIDE)` en Control creado programáticamente** → deja altura 0. Usar `position` + `set_size()` explícitos: `panel.position = Vector2(0, vp.y - h); panel.set_size(Vector2(vp.x, h))`.

### Reglas de Tutorial FTUE
33. **Tutorial en escena separada** (`TutorialGame.tscn`) — nunca como overlay sobre `Game.tscn`.
34. **`set_tutorial_shown(true)` solo al completar** — no al entrar a la escena.
35. **Enrutar desde MainMenu** — `_on_play_pressed()` decide entre Tutorial y Game según `SaveManager.get_tutorial_shown()`.

### Reglas de Assets Visuales
36. **NUNCA correr `gen_assets.py` completo para generar un solo ícono** — sobreescribe todos los assets AI. Importar solo la función necesaria:
    ```bash
    python3 -c "import sys; sys.path.insert(0,'tools'); from gen_assets import _make_XX_icon, save_png; save_png('ruta.png', 64, 64, _make_XX_icon())"
    ```
37. **Siempre consultar `/gen-ai-art` antes de tocar archivos de imagen** — el skill documenta el pipeline, los bugs de Pollinations.ai y el proceso de reimport en Godot.

---

## Auto-detección de Skills (OBLIGATORIO)

Antes de implementar, identificar qué skill aplica y **leerlo completo**:

| Tarea | Skill a consultar |
|---|---|
| Cualquier asset visual (sprites, íconos, fondos) | `/gen-ai-art` |
| Strings de UI, nuevos idiomas | `/mobile-i18n` |
| Feature nueva completa | `/feature` |
| Publicación Android / CI/CD | `/android-deploy` |
| Juego nuevo desde GDD | `/new-game` |
| Tutorial / FTUE | Sección FTUE en `/new-game` |
| Commit / cierre de tarea | `/doc` |
| Verificar antes de commit | `/validate` |

**No esperar a que el usuario lo pida.** Si la tarea encaja con un skill, leerlo primero.

---

## Propagación al Template (OBLIGATORIO)

Ruta del template: `/Users/norb/Dockers/gb-GameTemplate`

Cuando se descubra algo genérico (aplica a cualquier juego Godot 4 móvil), propagarlo al template **en la misma sesión**, sin que el usuario lo pida:

| Tipo de aprendizaje | Qué actualizar en el template |
|---|---|
| Nueva regla anti-alucinación o anti-patrón Godot | `CLAUDE.md` (sección Reglas) |
| Nuevo skill o agente | `.claude/skills/<nombre>/SKILL.md` o `.claude/.agents/<nombre>.md` |
| Bug de Godot / Android / CI | Skill correspondiente + `CLAUDE.md` si es regla general |
| Mejora al pipeline de assets | `.claude/skills/gen-ai-art/SKILL.md` + `tools/` |
| Mejora al proceso de i18n | `.claude/skills/mobile-i18n/SKILL.md` |

**Si no tienes la ruta del template en memoria, pregunta antes de asumir.**

---

## Protocolo Obligatorio por Cambio

```
a) PLAN      — Listar qué archivos se modifican, qué tests se agregan
b) IMPL      — Código mínimo y tipado (sin over-engineering)
c) VALIDATE  — gdlint src/ && tests GUT headless → BUILD GREEN
d) SANITY    — Verificar que features existentes no se rompieron
e) DOC       — Actualizar idea-base.md, CLAUDE.md, memoria y template si aplica
```

**Una tarea NO está terminada hasta que (c) y (e) estén completos.**

---

## Secciones a rellenar por juego

> Las siguientes secciones están vacías en el template. Rellenarlas al correr `/new-game`.

### Estado Actual del Juego
<!-- Mecánicas implementadas, condición de victoria/derrota, controles -->

### Señales clave en EventBus
<!-- Tabla: Señal | Emisor | Receptores -->

### Referencia Rápida del GDD
<!-- Valores base del jugador, enemigos, power-ups, metagame -->

### Autoloads registrados en project.godot
<!-- Tabla: Nombre | Archivo | Rol -->

### Skills y Agentes Disponibles
<!-- Lista de skills activos para este juego -->

### Pendientes Documentados
<!-- Features por implementar -->
