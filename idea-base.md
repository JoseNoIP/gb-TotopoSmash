# Totopo Smash — Idea Base

> Definición viva del juego. Actualizar con `/doc` al cerrar cada tarea.

---

## Concepto

**Género:** Puzzle / Arcade / Física de Rebotes (Brick Breaker)
**Estudio:** GuacamoleBit
**Plataforma:** iOS 14+ / Android API 24+
**Control:** Touch drag para apuntar (1 dedo) + soltar para disparar — sin autofire, sin movimiento de jugador
**Sesión target:** 2–5 minutos por run (progresión infinita por oleadas, sin condición de victoria)
**Propuesta de valor:** Docenas de semillas rebotando en pantalla a la vez, con física elástica perfecta y feedback "crujiente" (migajas, sonidos ASMR) — caos controlado en vez de puntería 1:1.

---

## Mecánicas Core

- **Bucle:** Apuntar (arrastrar) → Disparar (ráfaga continua de semillas) → Rebote elástico → Retorno automático (la primera semilla en tocar el suelo reposiciona el molcajete) → Avance (bloques bajan 1 fila, aparece fila nueva).
- **Victoria:** No existe — progresión infinita por oleadas, se juega por puntaje/oleada máxima.
- **Derrota:** Cualquier bloque toca la fila del molcajete (fila `MOLCAJETE_ROW = GRID_ROWS - 1 = 8`) al final de un turno.
- **Controles:** `InputEventScreenTouch`/`InputEventScreenDrag` en `Mortar` — la dirección de disparo va del molcajete hacia el dedo, clampeada a un cono "hacia arriba" (nunca horizontal/abajo).

---

## Mejoras Implementadas

## Core systems (Constants / EventBus / GameManager / SaveManager / AudioManager / HapticManager) ✅
- Autoloads en el orden correcto (Constants → EventBus → GameManager → SaveManager → AudioManager → HapticManager).
- `GameManager` usa una máquina de estados reducida (`MENU, PLAYING, PAUSED, GAME_OVER`) — sin `LEVEL_UP` ni `GAME_WON`, porque el GDD no define metagame de upgrades ni condición de victoria.
- `GameManager.pause_game()/resume_game()/start_game()` ahora también controlan `get_tree().paused` (antes solo cambiaban el enum de estado sin pausar nada de verdad — corregido en esta sesión).
- `SaveManager` persiste: tutorial_shown, sound/vibration/swipe_sensitivity, best_score, max_wave, total_games_played. Sin metagame de oro/upgrades (el GDD no lo pide).

## Tablero: TurnManager + BoardManager ✅
- **`src/features/board/turn_manager.gd`** — orquesta el turno completo: `enum Phase {AIMING, FIRING, RESOLVING, RETURNING, ADVANCING}`. Dueño del inventario de semillas (`Constants.MOLCAJETE_START_SEEDS = 10`, +1 por cada Semilla Extra tocada). Dispara la ráfaga con un `Timer` (`SEED_FIRE_INTERVAL = 0.06s` entre semillas — "una detrás de otra rápidamente, no todas juntas"). Reposiciona el molcajete con la primera semilla que aterriza. Emite `all_seeds_returned` cuando la última regresa.
- **`src/features/board/board_manager.gd`** — dueño exclusivo de la matriz de bloques (`Dictionary[Vector2i, StaticBody2D]`). Arma la fila inicial al iniciar partida, desplaza el tablero y spawnea fila nueva en cada `all_seeds_returned`, detecta Game Over, aplica el daño en cruz del Frasco de Salsa. Totalmente desacoplado de TurnManager — solo se comunican por EventBus (`all_seeds_returned` → `wave_advanced` / `board_reached_bottom`).
- Ambos módulos ya existían referenciados (`mortar.gd`, comentarios en los bloques) pero nunca se habían implementado — sin ellos el juego no arrancaba.

## Bloques y power-ups del tablero ✅ (ya implementados al iniciar esta sesión, ver `src/features/blocks/`, `src/features/powerups/`)
- Totopo (agrietado visual por daño), Queso (doble daño para destruir, frena semilla -15%), Frasco de Salsa (explota en cruz, parpadea en rojo antes), Piedra de Molcajete (indestructible), Triángulo (geometría de rebote vía `CollisionPolygon2D`).
- Limón Ácido (duplica la semilla en 2 ángulos simétricos) y Semilla Extra (+1 al inventario).
- `wave_scaling.gd` — reglas puras de escalado: `totopo_hp = O`, `queso_hp = ceil(O * 1.5)`, desbloqueos por oleada (triángulo/queso/salsa oleada 6+, piedra oleada 16+, espaciado ajustado oleada 31+).

## Física de rebote ✅ (ya implementada, con 1 fix esta sesión)
- `physics_math.gd` — reflexión manual `v' = v - 2(v·n)n` (e=1.0 exacto), sin depender de `Vector2.bounce()`.
- **Fix:** `seed.gd` declaraba `var velocity: Vector2` propio, que colisiona con la propiedad nativa `CharacterBody2D.velocity` (error de compilación "Member velocity redefined"). Se eliminó la redeclaración; el campo heredado cumple la misma función.
- **Nuevo:** `clamp_aim_direction()` acepta un parámetro `sensitivity` (default 1.0) que amplifica/amortigua la desviación respecto a "arriba" — conecta el ajuste de sensibilidad de `SettingsScreen` con el apuntado real (antes el valor se guardaba pero no afectaba nada).

## VFX procedural ✅
- **`src/features/vfx/crumb_particle.gd`** + **`vfx_spawner.gd`** — partículas simples (Node2D + `_draw()`, sin `GPUParticles2D`/`ParticleProcessMaterial` para no arriesgar nombres de propiedades del motor no verificables). Migajas amarillo/naranja al destruir un bloque, salpicadura roja en la explosión de salsa.

## UI completa (procedural, sin sprites) ✅
- `MainMenu.tscn/.gd` — JUGAR (enruta a Tutorial o Game según `tutorial_shown`) + CONFIGURACIÓN. Sin botón de mejoras (no hay metagame).
- `Game.tscn/.gd` — escena raíz: instancia BoardManager, TurnManager, Mortar, VFXSpawner, HUD, PauseScreen, GameOverScreen, SettingsScreen. Auto-pausa en `NOTIFICATION_APPLICATION_FOCUS_OUT`.
- `HUD.gd` — score, oleada, semillas disponibles, botón de pausa.
- `PauseScreen.gd` / `GameOverScreen.gd` / `SettingsScreen.gd` — overlays `CanvasLayer` con `PROCESS_MODE_ALWAYS`, construidos 100% por código (sin `.tscn` propio), igual que el resto del proyecto.
- Todo el texto está en español, literal (sin `tr()`) — el juego es mono-idioma en esta versión (ver sección Pendientes).

## Tutorial interactivo (FTUE) ✅
- `TutorialGame.tscn/.gd` — escena separada (nunca overlay sobre `Game.tscn`), reutiliza los sistemas reales del juego. Pasos: `WELCOME → AIM_SHOOT → WATCH_RETURN → ADVANCE → COMPLETE`, adaptados a la mecánica real de apuntar-y-soltar (no al flujo genérico de drag-mover/autofire del template).
- `set_tutorial_shown(true)` solo se llama al presionar JUGAR en el paso COMPLETE.
- Si el jugador muere durante el tutorial, se reinicia `TutorialGame.tscn` (no marca `tutorial_shown`).

## Tests GUT (79 tests, 0 fallos) ✅
- `test_physics_math.gd`, `test_grid_math.gd`, `test_wave_scaling.gd` — funciones puras, casos normal/borde/inválido.
- `test_game_manager.gd`, `test_save_manager.gd` — máquina de estados y persistencia (autoloads reales).
- `test_block_base.gd` — daño, destrucción, indestructibilidad, doble daño de queso, explosión de salsa, geometría de triángulo.
- `test_board_manager.gd`, `test_turn_manager.gd` — spawn de filas, avance de turno, Game Over, explosión en cruz, inventario de semillas, transiciones de fase.
- `test_gut_smoke.gd` — verifica que GUT y los autoloads core están disponibles.

## Configuración corregida ✅
- `project.godot`: `run/main_scene` apuntaba a `res://src/scenes/Main.tscn` (no existía — el proyecto no podía arrancar). Corregido a `MainMenu.tscn`.

---

## Bugs reales encontrados y corregidos jugando (post-build) ✅

El build inicial pasaba los 3 gates (lint/tests/export) pero el juego no era jugable — ningún gate automático detecta bugs de render/física que solo aparecen jugando de verdad. Corregidos en esta sesión, con test de regresión donde aplicaba:
- **Paredes/techo inexistentes** (`Constants.LAYER_WORLD` sin ningún `StaticBody2D` real) — las semillas que no golpeaban un bloque salían disparadas fuera de pantalla para siempre; `TurnManager` quedaba trabado en `RESOLVING`. Fix: `src/features/board/world_bounds.gd`.
- **Fondo dentro de un `CanvasLayer`** en `Game.gd`/`TutorialGame.gd` — tapaba todo el gameplay (bloques, molcajete, semillas) sin ningún error; la lógica de turnos corría perfecta por debajo (llegamos a oleada 7 sin ver nada en pantalla). Fix: fondo agregado directo, sin `CanvasLayer`.
- **Ícono recogido (Limón/Semilla Extra) nunca se borraba de `BoardManager._icons`** — al desplazar el tablero, insertar la referencia ya liberada en el `Dictionary` tipado crasheaba con "previously freed object". Fix + test de regresión en `test_board_manager.gd`.
- **Split del Limón crasheaba la física** — creaba una semilla nueva con `add_child()` síncrono desde dentro de `Area2D.body_entered` (callback de física), tocando `collision_layer` mientras el motor seguía "flushing queries". Fix: `call_deferred(&"add_child", ...)` en `TurnManager._spawn_seed()`.
- Además: input táctil no emulado en escritorio (`pointing/emulate_touch_from_mouse`), placeholders de `export_presets.cfg` sin llenar, `.gitignore` sin proteger `*.keystore`.

**Lección para el proceso:** verificar visualmente con una captura de pantalla real (no solo boot headless) antes de dar por bueno un build — headless nunca renderiza nada, así que no atrapa ninguno de estos 5 bugs.

## CI/CD Android ✅ — funcional de punta a punta
- `.github/workflows/build-android.yml` — build de APK + subida a Dropbox en cada push a `main`/`staging`. **Confirmado corriendo en verde**, APK instalado y probado en Android real.
- `.github/workflows/deploy-playstore.yml` — placeholders reemplazados por valores reales (`com.guacamolebit.totoposmash`). Sin probar de punta a punta todavía (solo dispara con push a `main` o tag `v*.*.*`; hasta ahora solo se probó el flujo de `staging`).
- Secrets ya configurados en el repo: keystore de Android (uno nuevo, propio de este juego — no reusa el de GuacBlaster), `GOOGLE_PLAY_JSON` (reutilizado de la cuenta de servicio de Guacamole Bit, con permiso agregado para esta app en Play Console), y los 3 de Dropbox.

## Pendientes

- **Assets visuales reales** (sprites, íconos, fondos) — todo el juego usa `_draw()` procedural (bloques, semillas, molcajete, íconos). `assets/icon.png`/`assets/splash.png` ya existen (procedurales, temáticos de Totopo Smash). Requiere correr `/gen-ai-art`. `tools/gen_assets.py`/`tools/fetch_ai_assets.py` son del template genérico (GuacBlaster Survivor) y NO aplican tal cual — hay que reescribirlos con prompts/formas propias.
- **SFX / música reales** — `AudioManager` es un stub funcional que no crashea sin archivos `.ogg`; faltan los assets de audio (rebotes tipo xilófono, crunch de totopo, thud de queso, splash de salsa).
- **Probar `deploy-playstore.yml` de punta a punta** — nunca se ha ejecutado (solo dispara con push a `main` o un tag `v*.*.*`). La primera subida a Play Store debe hacerse manual desde Play Console antes de que el pipeline automático funcione; la ficha de la app también debe existir ya creada ahí.
- **iOS sin configurar** — `export_presets.cfg` tiene `application/app_store_team_id="PLACEHOLDER_TEAM_ID"` sin llenar (falta el Team ID de Apple Developer); no existe workflow de CI para iOS (no se ha pedido todavía).
- **Multi-idioma** — no implementado (decisión de alcance: GDD y estudio en español, sin mercado angloparlante mencionado). Si se necesita, correr `/mobile-i18n`.
- **Balance fino** — varias probabilidades de spawn (`ROW_STONE_CHANCE`, `ROW_QUESO_CHANCE`, chance fija de salsa 0.10 hardcodeada en `wave_scaling.pick_cell_kind()`, etc.) son valores razonables documentados en `Constants.gd` pero no verificados con playtesting extenso, más allá de las pruebas manuales de esta sesión.
- **Corner de triángulos** — el GDD no especifica cómo se elige la esquina cortada; se randomiza (`BoardManager._spawn_cell`). Documentado como supuesto en `triangle_block.gd`.

---

## Valores de Balance (GDD)

### Molcajete / semillas
- Semillas iniciales: 10 · Intervalo entre disparos de la ráfaga: 0.06s · Velocidad: 640 px/s
- Cono de apuntado: 15° de margen respecto a la horizontal en cada lado

### Bloques
- Totopo: `HP = oleada` (ej. oleada 10 → HP 10)
- Queso: `HP = ceil(oleada * 1.5)` (ej. oleada 10 → HP 15), daño x2 por impacto, -15% velocidad de semilla al rebotar
- Frasco de Salsa: 10 de daño en cruz al explotar
- Piedra de Molcajete: indestructible (oleada 16+)

### Progresión de oleadas
- 1–5: solo totopos, vida 1–5, abundante Semilla Extra
- 6–15: triángulos + queso + salsa
- 16–30: piedra de molcajete indestructible
- 31+: menos huecos libres (estrangulamiento del espacio)

### Grid
- 7 columnas × 9 filas · fila 8 (última) = fila de Game Over
