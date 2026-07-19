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
19b. **`gradle_build/use_gradle_build=true` en `export_presets.cfg` afecta TODOS los exports de Android, no solo el AAB de release** — si está activado (necesario para el pipeline de AAB), un simple `--export-debug` en un workflow de CI también falla con `"Android build template not installed"` a menos que ese mismo job corra `--install-android-build-template` (y tenga Java 17 configurado, ya que el export invoca Gradle). Un workflow de "build APK de prueba" separado del de release necesita los mismos pasos de Java + template que `deploy-playstore.yml`, no una versión simplificada.
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

### Reglas de tipado descubiertas construyendo Totopo Smash
38. **`var velocity: Vector2` en un script que `extends CharacterBody2D`** → error de compilación "Member velocity redefined" (`velocity` ya es nativo de `CharacterBody2D`, usado por `move_and_slide()`). Si el script implementa su propio movimiento a mano (ej. rebote con `move_and_collide()`), NO redeclarar la propiedad — usar directamente el `velocity` heredado.
39. **`Dictionary[K, V]` tipada + `.set(&"campo", {...nuevo...})` con un diccionario literal** → falla en silencio (el campo queda vacío; ni error ni warning). Pasa tanto en producción como en tests que intentan inyectar estado. Para reemplazar el contenido desde fuera del objeto: obtener la referencia con `.get(&"campo")` y mutarla in-place (`d.clear(); d[key] = value`) — `Dictionary` es tipo por referencia en GDScript, así que la mutación se refleja en el objeto real sin pasar por `.set()`.
40. **Input táctil (`InputEventScreenTouch`/`Drag`) no responde a mouse/trackpad en el editor de escritorio** → Godot no emula touch desde mouse por defecto. Si el control del juego es 100% táctil (ver tabla de Stack), agregar en `project.godot`: `[input_devices]` → `pointing/emulate_touch_from_mouse=true`. Sin esto, probar en Mac/PC "no hace nada" y no genera ningún error — parece un bug de gameplay pero es config de proyecto faltante.
41. **Definir una physics layer en `Constants` (`LAYER_WORLD`, etc.) y usarla en `collision_mask` NO crea ningún cuerpo físico en esa capa.** Si el diseño requiere paredes/techo/piso como colliders (cualquier juego con rebote tipo Arkanoid/Brick Breaker), hay que instanciar explícitamente un `StaticBody2D` con `collision_layer` en esa capa — si no, cualquier proyectil que no golpee otra cosa en el juego (ej. un bloque) sale disparado fuera de pantalla para siempre y la máquina de estados que espera su retorno (`TurnManager` aquí) se queda trabada sin ningún error en consola. Verificar con `grep -rn "collision_layer = Constants.LAYER_X"` que cada layer referenciada como `collision_mask` tiene al menos un emisor real.
42. **Un `ColorRect`/nodo de fondo metido dentro de un `CanvasLayer` se dibuja SIEMPRE por encima de los `Node2D` normales de la escena** (bloques, personajes, proyectiles), sin importar el valor de `layer` que se le ponga (ni `layer = 0`). `CanvasLayer` no es "una capa más entre las demás dentro del mismo canvas" — es un canvas de composición aparte que Godot dibuja por encima del contenido 2D que no está envuelto en ningún `CanvasLayer`. Si necesitas un fondo detrás del gameplay, agrégalo como `Node2D`/`ColorRect` normal (primer hijo, para quedar atrás por orden de árbol) — nunca dentro de un `CanvasLayer`, aunque sea `layer = 0`. Síntoma si se hace mal: el juego "no muestra nada" (pantalla del color de fondo, sin errores), pero la lógica de turnos/física sigue corriendo perfectamente por debajo — muy fácil de confundir con un bug de lógica cuando es puramente un problema de orden de dibujado.

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

**Totopo Smash** — puzzle/arcade de física de rebotes (brick breaker), progresión infinita por oleadas, sin condición de victoria.

- **Mecánica core:** arrastrar el dedo para apuntar (cono "hacia arriba", nunca horizontal/abajo) → soltar dispara TODAS las semillas del inventario en ráfaga continua (`SEED_FIRE_INTERVAL = 0.06s` entre disparos) → rebote elástico perfecto (e=1.0) contra paredes/techo/bloques → la primera semilla en tocar el suelo reposiciona el molcajete → al volver la última, el tablero baja 1 fila y aparece una fila nueva arriba.
- **Derrota:** un bloque toca la fila del molcajete (`Constants.MOLCAJETE_ROW`) al terminar un turno.
- **Victoria:** no existe — se juega por score / oleada máxima alcanzada (persistidos en `SaveManager`).
- **Controles:** solo `Mortar` (molcajete) escucha input; no hay "Player" que se mueva por drag (a diferencia del template genérico) — el molcajete se reposiciona automáticamente, nunca por el jugador directamente.
- **Escenas jugables:** `MainMenu.tscn` → `TutorialGame.tscn` (primera vez) o `Game.tscn`. Ambas instancian los mismos sistemas (`BoardManager`, `TurnManager`, `Mortar`, `VFXSpawner`, `HUD`).
- **Sin metagame** — no hay oro, upgrades, ni multi-idioma en esta versión (ver Pendientes en `idea-base.md`).
- **Build:** `gdlint` 0 errores · GUT 78/78 tests · `--export-debug Android` genera APK válido.

### Señales clave en EventBus

| Señal | Emisor | Receptores |
|---|---|---|
| `game_started` | `GameManager.start_game()` | `BoardManager`, `TurnManager` (reset de estado) |
| `game_over(score, wave)` | `GameManager` (vía `board_reached_bottom`) | `GameOverScreen`, `Game.gd` |
| `game_paused` / `game_resumed` | `GameManager.pause_game()/resume_game()` | `PauseScreen` (show/hide) |
| `wave_advanced(wave_number)` | `BoardManager` (fila inicial y cada avance) | `GameManager` (bono de score), `HUD`, `TurnManager` (guard ADVANCING→AIMING) |
| `turn_phase_changed(phase)` | `TurnManager._set_phase()` | `Mortar` (gatea el input de apuntado) |
| `aim_updated` / `aim_cancelled` | `Mortar` | (feedback visual propio) |
| `fire_requested(direction, origin)` | `Mortar` al soltar el dedo | `TurnManager` (inicia la ráfaga) |
| `burst_fired(seed_count)` | `TurnManager` | `HUD` / tutorial |
| `all_seeds_returned(landing_x)` | `TurnManager` (última semilla aterriza) | `BoardManager` (avanza el tablero) |
| `molcajete_position_changed(x)` | `TurnManager` (primera semilla aterriza) | `Mortar` (tween a la nueva posición) |
| `seed_count_changed(n)` | `TurnManager` | `HUD` |
| `block_damaged(pos, hp, max_hp)` | `block_base._apply_damage()` | (feedback visual propio del bloque) |
| `block_destroyed(pos, type, score)` | `block_base._die()` | `GameManager` (score), `BoardManager` (borra de la grilla), `VFXSpawner`, `HapticManager` |
| `salsa_exploded(pos)` | `salsa_jar_block._die()` | `BoardManager` (daño en cruz), `VFXSpawner`, `HapticManager` |
| `board_reached_bottom` | `BoardManager` (game over) | `GameManager` |
| `lemon_triggered` / `seed_extra_touched` / `seed_extra_collected` | `LemonIcon` / `SeedExtraIcon` / `TurnManager` | `TurnManager` (split real vía señal privada `Seed.split_requested`, no EventBus) / `HUD` |
| `score_changed` / `high_score_updated` | `GameManager` | `HUD` / `GameOverScreen` |

### Referencia Rápida del GDD

- **Molcajete:** 10 semillas iniciales, velocidad 640px/s, ráfaga cada 0.06s, cono de apuntado ±15° respecto a la horizontal.
- **Totopo:** `HP = oleada`. **Queso:** `HP = ceil(oleada * 1.5)`, daño x2, -15% velocidad de semilla al rebotar (piso `SEED_MIN_SPEED_RATIO = 0.35`). **Salsa:** 10 de daño en cruz al morir. **Piedra:** indestructible.
- **Oleadas:** 1–5 introducción (solo totopo) · 6–15 geometría (triángulo + queso + salsa) · 16–30 piedra · 31+ espaciado ajustado.
- **Grid:** 7 columnas × 9 filas (`Constants.GRID_COLS/GRID_ROWS`), diseño base 390×844.
- **Sin metagame de oro/upgrades** — el GDD no lo define; `SaveManager` solo persiste settings + best_score/max_wave/tutorial_shown.

### Autoloads registrados en project.godot

| Nombre | Archivo | Rol |
|---|---|---|
| `Constants` | `src/core/Constants.gd` | Constantes tipadas (GDD como fuente de verdad) |
| `EventBus` | `src/core/EventBus.gd` | Bus de señales cross-feature |
| `GameManager` | `src/core/GameManager.gd` | Estados `MENU/PLAYING/PAUSED/GAME_OVER`, score, oleada, pausa real del `SceneTree` |
| `SaveManager` | `src/core/SaveManager.gd` | Persistencia `user://save.json` |
| `AudioManager` | `src/features/audio/AudioManager.gd` | Stub de SFX/música (no crashea sin `.ogg`) |
| `HapticManager` | `src/features/audio/HapticManager.gd` | Vibración sutil solo en destrucción/explosión |

### Skills y Agentes Disponibles

Todos los del template (`/gen-ai-art`, `/mobile-i18n`, `/feature`, `/android-deploy`, `/new-game`, `/doc`, `/validate`) + agentes `game-designer`, `game-feel`, `godot-architect`, `godot-qa`. Ninguno es específico de Totopo Smash todavía.

### Pendientes Documentados

Ver sección **Pendientes** en `idea-base.md` (assets visuales/SFX reales, CI/CD con credenciales reales, balance fino de probabilidades de spawn). Resumen: el juego es 100% jugable y testeado, pero 100% procedural (sin arte/audio finales) y sin pipeline de publicación configurado con secrets reales.
