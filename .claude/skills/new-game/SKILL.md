---
name: new-game
description: Construye un juego móvil Godot 4 completo y funcional a partir de un GDD en markdown. 100% autónomo hasta tener build verde.
context: fork
effort: max
agent: general-purpose
allowed-tools:
  - Read
  - Edit
  - Write
  - Bash
  - Glob
  - Grep
---

## /new-game [ruta/al/gdd.md] — Construcción autónoma de juego móvil

GDD a implementar:

```
!`cat $ARGUMENTS`
```

---

## Contexto del stack

Este proyecto usa:
- **Godot 4.7** / GDScript con tipado estático obligatorio
- **GUT v9.7.1** en `addons/gut/` para tests
- **gdtoolkit** (`gdlint` / `gdformat`) para lint
- **Plataforma:** iOS 14+ / Android API 24+ (pantalla vertical, 1 dedo)
- **CI/CD:** GitHub Actions → APK en Dropbox

Lee `CLAUDE.md` completo antes de empezar — contiene todas las reglas anti-alucinación, convenciones de código, y estructura de carpetas.

---

## Protocolo de construcción autónoma

Sigue estas fases en orden. Cada fase termina con su gate de validación antes de continuar.

---

### FASE 0 — Preguntas de alcance (antes de implementar)

Responder estas preguntas con el usuario ANTES de empezar a codificar:

1. **¿Multi-idioma?** → Si sí, usar `/mobile-i18n`. Impacta todos los strings UI — mejor decidirlo antes que refactorizar después.
2. **¿Vista top-down con sensación de profundidad?** → Evaluar ilusión de perspectiva (ver agente `game-feel`, sección 6). No es automático — requiere que el diseño del juego lo soporte.
3. **¿Publicar en Google Play?** → Usar `/android-deploy` para el pipeline completo. Requiere keystore + cuenta de servicio de Google.
4. **¿Sesiones cortas (< 5 min)?** → El arco sesión debe ser: aprendizaje (min 0–1) → acumulación (min 1–3) → clímax (boss / objetivo final).
5. **¿Tutorial interactivo (FTUE)?** → Recomendado siempre. Ver arquitectura en FASE 8 y anti-alucinación §FTUE. El tutorial usa los sistemas reales del juego (Player, GemSpawner, PowerUpDropper) en una escena separada `TutorialGame.tscn`.

---

### FASE 1 — Parsear GDD

Extraer y confirmar:
- [ ] Nombre del juego, plataforma, orientación
- [ ] Mecánica core (qué hace el jugador cada frame)
- [ ] Condición de victoria y derrota
- [ ] Entidades: jugador, enemigos, items, proyectiles
- [ ] Power-ups / habilidades con sus IDs y efectos
- [ ] Progresión: XP, niveles, metagame (upgrades, moneda)
- [ ] UI requerida: menús, HUD, pantallas de resultado
- [ ] Señales principales (derivar del diseño si no están explícitas)
- [ ] Valores numéricos: HP, velocidad, daño, intervalos, duraciones

Si el GDD no especifica un valor → usar valor razonable para hyper-casual móvil y documentarlo.

---

### FASE 2 — Scaffold del proyecto

```bash
# Verificar que Godot esté disponible
godot --version

# Estructura de carpetas (feature-first)
mkdir -p src/core src/features/player src/features/projectiles
mkdir -p src/features/enemies src/features/powerups src/features/gems
mkdir -p src/features/meta src/features/audio src/features/vfx src/features/ui
mkdir -p src/scenes src/shared
mkdir -p assets/sprites assets/audio assets/fonts
mkdir -p tests/unit builds/debug builds/release
```

Crear `project.godot` con:
- Autoloads en orden: Constants → EventBus → GameManager → SaveManager → AudioManager
- Display/window: 390×844 (portrait), stretch mode: canvas_items, aspect: expand
- Physics layers nombradas: player(1), enemy(2), projectile(3), item(4), powerup(5)

---

### FASE 3 — Core systems

Crear en este orden (dependencias primero):

#### 3.1 Constants.gd
Todas las constantes del GDD. Incluir:
- Valores del jugador (HP, speed, damage, fire_rate)
- Valores de enemigos (HP, speed, XP, gold)
- Valores de power-ups (duración, pool)
- Valores de UI (colores, fuentes)
- Paletas de background (mínimo 3)
- Constantes de metagame (costos de upgrade)

#### 3.2 EventBus.gd
Todas las señales derivadas del GDD, agrupadas por sección:
```
# --- Player ---
# --- Enemies ---
# --- PowerUps ---
# --- Progression ---
# --- Game State ---
# --- UI ---
```

#### 3.3 GameManager.gd
- Enum de estados: `{ MENU, PLAYING, PAUSED, LEVEL_UP, GAME_OVER, GAME_WON }`
- Timers: session_time, boss_spawn_interval
- Transiciones: start_game, pause_game, resume_game, game_over, game_won
- Métodos: get_state(), get_session_time()

#### 3.4 SaveManager.gd
- Persistencia en `user://save.json`
- Guarda: gold, upgrades (array), best_score, total_sessions, victories
- Métodos: get_gold(), add_gold(), get_upgrade_level(), upgrade(), get_victories()
- Auto-carga en `_ready()`, auto-guarda en cada cambio

#### 3.5 AudioManager.gd
- Stub funcional: métodos `play_sfx(name)`, `play_music()`, `stop_music()`
- No crashea si el archivo .ogg no existe (verifica antes de cargar)

**Gate 3:** `gdlint src/core/` — debe pasar a 0 errores.

---

### FASE 4 — Player y controles

#### 4.1 Player.gd (CharacterBody2D)
- Drag con ancla (NO salto al primer toque):
  ```gdscript
  # InputEventScreenTouch: registra _drag_anchor_x y _drag_anchor_player_x
  # InputEventScreenDrag: _target_x = _drag_anchor_player_x + (drag.x - _drag_anchor_x) * sensitivity
  ```
- Autofire: Timer con intervalo desde Constants
- HP, shield, invulnerabilidad temporal post-daño
- Emitir señales: player_health_changed, player_died

#### 4.2 ProjectileSpawner.gd
- Instancia proyectiles en posición del jugador
- Responde a powerup_stack_changed para modificar patrones

#### 4.3 Projectile.gd (Area2D)
- Velocidad, daño, pierce, bounce según power-ups activos
- `_exit_tree()` desconecta señales

**Gate 4:** `gdlint src/features/player/` — 0 errores.

---

### FASE 5 — Enemigos

#### 5.1 EnemyBase.gd (CharacterBody2D)
- take_damage(amount), _die(), _initialize()
- Emite enemy_destroyed(id, position, gem_value)
- NO implementar comportamiento aquí — solo interfaz

#### 5.2 Un subtipo por enemigo del GDD
- Herencia: `extends "res://src/features/enemies/EnemyBase.gd"`
- Cada uno en su propio archivo (enemy_basic.gd, enemy_tank.gd, etc.)
- Comportamiento único en `_physics_process()`

#### 5.3 EnemySpawner.gd
- Dificultad creciente por tiempo
- Unlock de tipos por tiempo/generación
- NO se pausa durante level-up (continuar spawneando)

#### 5.4 EnemyBoss.gd
- Hereda de EnemyBase
- HP = base + increment × generación
- Emite boss_health_changed(current, maximum) en take_damage()
- Emite boss_defeated al morir

**Gate 5:** `gdlint src/features/enemies/` — 0 errores.

---

### FASE 6 — Power-ups y progresión

#### 6.1 PowerUpManager.gd
- `_stacks: Dictionary` (id → count)
- `_timers: Dictionary` (id → Array[float])
- `add_stack(id)`: agrega 1 stack con timer independiente
- `_process(delta)`: decrementa timers, emite powerup_stack_changed al expirar
- `get_stack_count(id) -> int`

#### 6.2 PowerUpDrop.gd + PowerUpDrop.tscn
- Area2D que cae desde arriba
- Al contacto con player: emite powerup_selected(id)
- Los demás drops desaparecen vía powerup_selected signal

#### 6.3 PowerUpDropper.gd
- Escucha powerup_selection_requested(options)
- Instancia 3 PowerUpDrop con IDs random del pool
- Posiciones: distribuidas horizontalmente

#### 6.4 XPGem.gd
- Cae al morir enemigos
- Atracción magnética si salsa_magnet activo
- Emite xp_collected(amount, total, required)

#### 6.5 GemSpawner.gd
- Instancia XPGem en posición del enemigo muerto

**Gate 6:** `gdlint src/features/powerups/ src/features/gems/` — 0 errores.

---

### FASE 7 — Metagame y meta-progresión

#### 7.1 ProgressionManager.gd (o integrado en GameManager)
- XP_BASE_REQUIRED, XP_SCALE_FACTOR
- level_up: emite player_level_up(level), powerup_selection_requested(options)
- Selección de 3 power-ups random ponderada por "suerte"

#### 7.2 UpgradeScreen.gd
- 6 upgrades (derivar del GDD o usar estándar: damage, speed, health, luck, gold_bonus, starter_shield)
- Costo: `50 × 1.8^nivel`, cap nivel 5
- Guarda en SaveManager

---

### FASE 8 — UI completa

Pantallas mínimas requeridas:
- **MainMenu.tscn** — botones: JUGAR, MEJORAS, CONFIGURACIÓN
- **Game.tscn** — escena principal con HUD
- **HUD.gd** — corazones, XP bar, score, nivel, timer de boss, tira de power-ups activos, barra HP boss
- **PauseScreen.tscn** — CONTINUAR, REINICIAR, MENU PRINCIPAL
- **GameOverScreen.tscn** — score, oro ganado, botón REINTENTAR
- **VictoryScreen.tscn** — score, oro, bioma siguiente, botón CONTINUAR
- **UpgradeScreen.tscn** — grid de upgrades con costos
- **SettingsScreen.tscn** — sensibilidad swipe (slider), sound on/off, vibración on/off, idioma (si multi-idioma activo)
- **LanguageSelectScreen.tscn** — solo si el juego es multi-idioma (ver `/mobile-i18n`)

Reglas UI:
- Todo texto de gameplay: mínimo 18px (legibilidad en móvil)
- Colores de HUD: sacar de Constants para poder cambiarlos globalmente
- Pantallas de overlay: CanvasLayer con `process_mode = PROCESS_MODE_ALWAYS`
- `_panel.hide()` en `_ready()` para todos los overlays

---

### FASE 9 — Game.tscn (escena raíz)

Conectar todo:
- Instanciar: Player, EnemySpawner, PowerUpManager, PowerUpDropper, GemSpawner, HeartDropper
- Instanciar HUD, PauseScreen, GameOverScreen, VictoryScreen, BossWarning
- Background: ColorRect (o TextureRect si hay assets)
- `Game.gd`: conectar restart_requested, game_over, game_won con cambios de escena
- Auto-pausa: `_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)`

---

### FASE 10 — Tests GUT

Mínimo un archivo de test por feature principal:
- `tests/unit/test_player.gd` — movimiento, daño, shield
- `tests/unit/test_powerup_manager.gd` — stacks, timers, expiración
- `tests/unit/test_game_manager.gd` — transiciones de estado
- `tests/unit/test_save_manager.gd` — persistencia, upgrades, gold
- `tests/unit/test_enemy_base.gd` — take_damage, die, signals
- `tests/unit/test_hud.gd` — actualización de HP, XP, score, boss bar
- `tests/unit/test_progression.gd` — XP threshold, level-up signal

Cada test: caso normal + borde mínimo + borde máximo + entrada inválida.

---

### FASE 11 — VALIDATE FINAL

```bash
# Gate lint
gdlint src/ tests/

# Gate tests
godot --headless -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit -gexit -glog=2 2>&1

# Gate build
godot --headless --export-debug "Android" builds/debug/game.apk 2>&1
```

Los tres gates deben estar en verde. Si alguno falla → corregir antes de reportar terminado.

---

### FASE 11b — Features de calidad (evaluar con el usuario)

Antes de cerrar, ofrecer estas features probadas que elevan la calidad percibida:

| Feature | Skill / Agente | Cuándo aplicar |
|---|---|---|
| Tutorial interactivo (FTUE) | Ver §FTUE en este archivo | Siempre — reduce abandono en primera sesión |
| Multi-idioma | `/mobile-i18n` | Si el mercado objetivo incluye más de un idioma |
| Ilusión de profundidad | agente `game-feel` §6 | Si el juego tiene vista top-down y enemigos que se acercan |
| Animación de victoria | agente `game-feel` §7 | Siempre — el jugador debe "salir" antes de ver resultados |
| CI/CD Google Play | `/android-deploy` | Si se va a publicar en Android |

---

### FASE 12 — Documentación

1. Crear `idea-base.md` con:
   - Resumen del juego (del GDD)
   - Features implementadas (todas)
   - Assets externos requeridos (sprites, audio)
   - Pendientes de código
   - Setup de CI/CD

2. `CLAUDE.md` ya existe en el template — actualizar con:
   - Señales reales del EventBus
   - Valores reales del jugador
   - Lista real de power-ups
   - Estado actual del juego

3. Confirmar al usuario:
   ```
   BUILD COMPLETO — [nombre del juego]

   Features: [lista]
   Tests: N passing
   Lint: 0 errores
   Build: APK generado en builds/debug/

   Assets pendientes (sin código): [lista]
   ```

---

## Tutorial interactivo FTUE (First-Time User Experience)

Implementación probada en GuacBlaster Survivor (julio 2026).

### Arquitectura

```
src/scenes/TutorialGame.gd    ← escena autónoma, construye todo programáticamente
src/scenes/TutorialGame.tscn  ← minimal (solo root Node2D + script)
src/scenes/MainMenu.gd        ← _on_play_pressed() enruta según SaveManager.get_tutorial_shown()
```

`SaveManager` necesita:
```gdscript
func get_tutorial_shown() -> bool:
    return _data.get("tutorial_shown", false) as bool

func set_tutorial_shown(value: bool) -> void:
    _data["tutorial_shown"] = value
    _save()
```

### Flujo de pasos

```
WELCOME (botón EMPEZAR)
  → MOVE (arrastra >80px; flecha animada sigue al jugador)
  → SHOOT (spawnea 1 enemigo; espera enemy_destroyed)
  → COLLECT (GemSpawner auto-spawnea gema; espera gem_collected)
  → LEVEL_UP (emite powerup_selection_requested con 3 opciones; espera powerup_selected)
  → COMPLETE (botón JUGAR → set_tutorial_shown(true) → Game.tscn)
```

Si el jugador muere durante el tutorial → reinicia TutorialGame.tscn (NO marca tutorial_shown).

### TutorialGame._ready() — orden obligatorio

```gdscript
func _ready() -> void:
    _build_scene()       # 1. instancia Player, ProjectileSpawner, GemSpawner, PowerUpDropper
    GameManager.start_game()  # 2. emite game_started → Player y ProjectileSpawner se inicializan
    EventBus.game_over.connect(_on_game_over)
    _advance_to(Step.WELCOME)
```

`add_child()` en `_ready()` llama `_ready()` del hijo inmediatamente (el padre ya está en el árbol).
Por eso los hijos ya están conectados al EventBus cuando `start_game()` emite.

### Routing en MainMenu

```gdscript
const GAME_SCENE: String = "res://src/scenes/Game.tscn"
const TUTORIAL_SCENE: String = "res://src/scenes/TutorialGame.tscn"

func _on_play_pressed() -> void:
    var dest: String = GAME_SCENE if SaveManager.get_tutorial_shown() else TUTORIAL_SCENE
    get_tree().change_scene_to_file.call_deferred(dest)
```

### Overlay — panel de instrucciones

El panel usa posición y tamaño **explícitos** (NO `set_anchors_preset`):

```gdscript
var panel_h: float = 160.0
var panel: PanelContainer = PanelContainer.new()
panel.position = Vector2(0.0, vp.y - panel_h)
panel.set_size(Vector2(vp.x, panel_h))
layer.add_child(panel)
```

**Anti-alucinación FTUE:**

1. **NO usar `set_anchors_preset(PRESET_BOTTOM_WIDE)` con PanelContainer creado programáticamente** — cuando `anchor_top = 1` y `anchor_bottom = 1`, el panel queda con altura 0 y no se renderiza. `custom_minimum_size` no lo rescata. Usar `position` + `set_size()` siempre que se cree UI de forma programática en un CanvasLayer.
2. **ProjectileSpawner necesita `projectile_scene` asignado** — usar `ps.set(&"projectile_scene", ProjectileScene)` (regla CLAUDE.md #15, no usar class_name como tipo).
3. **`set_tutorial_shown(true)` solo al COMPLETAR** — no antes. Si se llama en el primer frame como hacía el tutorial viejo de Game.gd, cualquier save existente tiene el flag en `true` y el tutorial nunca vuelve a mostrarse.
4. **Conectar eventos con `CONNECT_ONE_SHOT`** — `enemy_destroyed`, `gem_collected`, `powerup_selected` deben conectarse justo antes de que el paso que los espera comience, con `CONNECT_ONE_SHOT`, para no acumular listeners entre reinicios.
5. **Enum antes de const** — gdlint (class-definitions-order) exige: `enum` → `const` → `var`. Si el enum va después de los const, falla lint.

### Claves de traducción recomendadas

```
TUTORIAL_WELCOME_TITLE, TUTORIAL_WELCOME_HINT, TUTORIAL_BTN_START
TUTORIAL_MOVE_TITLE, TUTORIAL_MOVE_HINT
TUTORIAL_SHOOT_TITLE, TUTORIAL_SHOOT_HINT
TUTORIAL_COLLECT_TITLE, TUTORIAL_COLLECT_HINT
TUTORIAL_LEVELUP_TITLE, TUTORIAL_LEVELUP_HINT
TUTORIAL_DONE_TITLE, TUTORIAL_DONE_HINT
```

### Checklist

- [ ] `SaveManager` tiene `get_tutorial_shown()` / `set_tutorial_shown()`
- [ ] `MainMenu._on_play_pressed()` enruta a TutorialGame si `!tutorial_shown`
- [ ] `TutorialGame._ready()` llama `GameManager.start_game()` DESPUÉS de `add_child` de todos los sistemas
- [ ] Panel de overlay usa `position` + `set_size()` explícitos (no `PRESET_BOTTOM_WIDE`)
- [ ] `set_tutorial_shown(true)` solo se llama en el paso COMPLETE, al presionar el botón final
- [ ] Si el jugador muere → reinicia tutorial (no Game.tscn)
- [ ] Todos los strings del tutorial usan `tr(&"KEY")`
- [ ] `gdlint src/` pasa a 0 errores

---

## GDD mínimo requerido

Si el GDD proporcionado no tiene alguno de estos campos, preguntar antes de asumir:
- Nombre del juego
- Mecánica core (cómo se mueve/ataca el jugador)
- Condición de victoria
- Condición de derrota
- Al menos 2 tipos de enemigos
- Al menos 3 power-ups
- Loop de progresión (¿hay metagame?)
