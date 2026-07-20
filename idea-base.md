# Totopo Smash — Idea Base

> Definición viva del juego. Actualizar con `/doc` al cerrar cada tarea.

---

## Concepto

**Género:** Puzzle / Arcade / Física de Rebotes (Brick Breaker)
**Estudio:** GuacamoleBit
**Plataforma:** iOS 14+ / Android API 24+
**Control:** Touch drag para apuntar (1 dedo) + soltar para disparar — sin autofire, sin movimiento de jugador
**Sesión target:** 2–5 minutos por run/nivel
**Propuesta de valor:** Docenas de semillas rebotando en pantalla a la vez, con física elástica perfecta y feedback "crujiente" (migajas, sonidos ASMR) — caos controlado en vez de puntería 1:1.

---

## Mecánicas Core

- **Bucle:** Apuntar (arrastrar) → Disparar (ráfaga continua de semillas) → Rebote elástico (mantener presionado acelera las semillas) → Retorno automático (la primera semilla en tocar el suelo reposiciona el molcajete) → Avance (bloques bajan 1 fila; en Modo Infinito además aparece fila nueva).
- **Dos modos:** **Modo Nivel** (principal) — tablero finito y determinista (`data/levels/*.json`), se gana al destruir todo lo destructible. **Modo Infinito** — el diseño original: progresión infinita y aleatoria por oleadas, sin condición de victoria, se juega por puntaje/oleada máxima.
- **Derrota (ambos modos):** Cualquier bloque toca la fila del molcajete (fila `MOLCAJETE_ROW = GRID_ROWS - 1 = 8`) al final de un turno — marcada con una línea de peligro animada en pantalla (degradado + chevrones + pulso, ver `danger_line.gd`).
- **Controles:** `InputEventScreenTouch`/`InputEventScreenDrag` en `Mortar` — la dirección de disparo va del molcajete hacia el dedo, clampeada a un cono "hacia arriba" (nunca horizontal/abajo). Fuera de la fase de apuntado, mantener presionado acelera las semillas.

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
- Todo el texto usa `tr()`/auto-translate — ver sección Multi-idioma abajo.

## Multi-idioma ✅ (`/mobile-i18n`) — es / en / pt_BR / fr
- `assets/translations/translations.txt` (CSV real, extensión `.txt` por el bug #38957 de Godot) con 36 keys.
- `src/core/LocalizationManager.gd` (autoload, sin `class_name`, registrado después de `SaveManager`) — parsea el CSV en runtime y aplica el locale guardado (o `es` por defecto).
- `src/scenes/LanguageSelectScreen.tscn/.gd` — selector de primera ejecución; `MainMenu.gd._ready()` redirige aquí si `SaveManager.get_language()` está vacío.
- `SettingsScreen` — fila de idioma con botón cíclico (`_on_lang_next_pressed()`).
- **Dos convenciones de texto, según si el nodo se reconstruye o no:** títulos/botones estáticos de overlays que solo se muestran/ocultan (`SettingsScreen`, `PauseScreen`, `GameOverScreen`, `MainMenu`) usan la **key cruda** (`title.text = "TITLE_SETTINGS"`, sin `tr()`) para aprovechar el auto-translate nativo de `Control` — así se retraducen solos si el jugador cambia de idioma sin que la escena se recargue. Labels con valores interpolados (`score`, `oleada`, pasos del tutorial) usan `tr(&"KEY") % valor` explícito en el punto donde ya se recalculan. **Verificado con captura de pantalla real:** cambiar el idioma con `SettingsScreen` ya abierto retradujo título/checkboxes/botones sin volver a construir nada.
- Bono: se corrigió `HUD`/`GameOverScreen`, que mezclaban "Score:" (inglés) con el resto del texto en español — ahora `LABEL_SCORE` es consistente por locale.

## Tutorial interactivo (FTUE) ✅
- `TutorialGame.tscn/.gd` — escena separada (nunca overlay sobre `Game.tscn`), reutiliza los sistemas reales del juego. Pasos: `WELCOME → AIM_SHOOT → WATCH_RETURN → ADVANCE → COMPLETE`, adaptados a la mecánica real de apuntar-y-soltar (no al flujo genérico de drag-mover/autofire del template).
- `set_tutorial_shown(true)` solo se llama al presionar JUGAR en el paso COMPLETE.
- Si el jugador muere durante el tutorial, se reinicia `TutorialGame.tscn` (no marca `tutorial_shown`).

## Tests GUT (196 tests, 0 fallos) ✅
- `test_physics_math.gd`, `test_grid_math.gd`, `test_wave_scaling.gd` — funciones puras, casos normal/borde/inválido.
- `test_game_manager.gd`, `test_save_manager.gd` — máquina de estados y persistencia (autoloads reales), incluye `language`.
- `test_block_base.gd` — daño, destrucción, indestructibilidad, doble daño de queso, explosión de salsa, geometría de triángulo.
- `test_board_manager.gd`, `test_turn_manager.gd` — spawn de filas, avance de turno, Game Over, explosión en cruz, inventario de semillas, transiciones de fase, ícono liberado (regresión).
- `test_localization_manager.gd` — carga de CSV, cambio de locale, persistencia, locale no soportado ignorado, las 4 traducciones existen para la misma key.
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

### Ronda 2 — reportados por el usuario jugando Modo Nivel ✅

- **El apuntado se quedaba trabado para siempre después del primer disparo en Modo Nivel** (el botón de pausa seguía funcionando, el juego no) — `TurnManager` solo volvía de `Phase.ADVANCING` a `Phase.AIMING` escuchando `EventBus.wave_advanced`, una señal específica de Modo Infinito que `BoardManager` nunca emite en Modo Nivel. Bug real desde que existe Modo Nivel, invisible a los tests porque ninguno ejercitaba el ciclo completo de un segundo turno con ambos sistemas conectados de verdad. Fix: nueva señal mode-agnostic `EventBus.turn_advanced` (sin parámetros), emitida por `BoardManager` en AMBOS modos cuando el turno termina sin game over ni nivel ganado; `TurnManager` pasó a escucharla en vez de `wave_advanced`. Test de regresión de punta a punta en `test_turn_manager.gd` (instancia `BoardManager` + `TurnManager` juntos, sin emitir la señal a mano). Ver regla CLAUDE.md #50.
- **Botón del tutorial mostraba `BTN_UNDERSTOOD` en vez de "ENTENDIDO"** — la key nunca se agregó a `assets/translations/translations.txt` (usada en código, ausente en el CSV; Godot devuelve la key cruda cuando no encuentra traducción, sin error ni warning). Fix: key agregada para los 4 idiomas. De paso, un barrido sistemático de TODAS las keys usadas vía `tr()` contra el archivo de traducciones no encontró ninguna otra faltante — y se corrigió un cabo suelto relacionado: `LEVEL_NAME_015..020` (nombres de los niveles-figura) quedaron huérfanas al mover esos niveles a 95-100 en la expansión del roster a 100 niveles; renombradas a `LEVEL_NAME_095..100` (el campo `name` del nivel todavía no se renderiza en ningún lado, así que esto no era un bug visible, solo dato inconsistente).

**Lección para el proceso:** ningún test verifica que una key usada en código exista en el CSV de traducciones — un grep cruzando `tr(&"...")` contra las keys definidas (`comm -23` de las dos listas ordenadas) lo detecta en segundos y debería correrse cada vez que se toquen strings de UI.

## CI/CD Android ✅ — funcional de punta a punta
- `.github/workflows/build-android.yml` — build de APK + subida a Dropbox en cada push a `main`/`staging`. **Confirmado corriendo en verde**, APK instalado y probado en Android real.
- `.github/workflows/deploy-playstore.yml` — placeholders reemplazados por valores reales (`com.guacamolebit.totoposmash`). Sin probar de punta a punta todavía (solo dispara con push a `main` o tag `v*.*.*`; hasta ahora solo se probó el flujo de `staging`).
- Secrets ya configurados en el repo: keystore de Android (uno nuevo, propio de este juego — no reusa el de GuacBlaster), `GOOGLE_PLAY_JSON` (reutilizado de la cuenta de servicio de Guacamole Bit, con permiso agregado para esta app en Play Console), y los 3 de Dropbox.
- **`deploy-playstore.yml` probado de punta a punta** ✅ — subió la app a Google Play Store como Internal Testing exitosamente.

## Decisiones de diseño confirmadas (sin cambios de código, solo documentación) ✅
- **Balance de spawn** — simulación Monte Carlo (20k filas/oleada, oleadas 1-60) confirmó que los saltos de dificultad caen donde el GDD los describe y no hay tableros imposibles (fila 100% piedra <0.02% de las veces). Ver comentario en `wave_scaling.gd`. No se cambió ningún valor — ya estaban bien calibrados.
- **Corner de triángulos** — se confirmó como decisión de diseño intencional (no un placeholder): la esquina se randomiza una vez por instancia en el spawn, visible antes de cualquier rebote, así que nunca es información oculta o injusta. Ver comentario en `triangle_block.gd`.

## Assets visuales y de audio reales ✅
- `tools/gen_assets.py` reescrito para Totopo Smash (se quitó todo lo específico de GuacBlaster Survivor: personajes, enemigos, íconos de power-up, 5 biomas de fondo). Genera procedural: `totopo.png`, `queso.png`, `salsa.png`, `stone.png` (`assets/sprites/blocks/`), `molcajete.png`, `seed.png`, `lemon.png`/`seed_extra.png` (`assets/sprites/powerup_icons/`) — todos ≤96px, por eso procedural y no IA (ver `/gen-ai-art` paso 4: a esos tamaños la IA sale borrosa y no comunica la mecánica).
- `tools/fetch_ai_assets.py` reescrito: un solo fondo de menú vía Pollinations.ai (`assets/sprites/backgrounds/menu_bg.png`, 390×844 — el único asset ≥128px, por eso sí usa IA). El fondo del tablero de juego (`Game.tscn`) se queda plano a propósito (GDD sección 5: oscuro para resaltar las trayectorias de las semillas).
- `block_base.gd` ahora intenta `Sprite2D` con textura real primero, cae a `ColorRect`+color si el asset no existe (nunca crashea). Los subtipos con efectos (`totopo_block.gd` agrietado, `queso_block.gd` squish, `salsa_jar_block.gd` parpadeo) se generalizaron de `ColorRect` a `CanvasItem` — ver regla CLAUDE.md #44 sobre `.scale` y `CanvasItem`.
- `mortar.gd`, `seed.gd`, `lemon_icon.gd`, `seed_extra_icon.gd` — mismo patrón (Sprite2D si existe, `_draw()` de respaldo si no).
- `MainMenu.gd`/`LanguageSelectScreen.gd` — fondo real + scrim oscuro semitransparente para legibilidad del texto encima.
- **Audio real** (GDD sección 5): `AudioManager` reescrito para usar `.wav` (no `.ogg` — sin encoder OGG en la stdlib de Python; mismo patrón ya probado en GuacBlaster) y se suscribe directo a `EventBus` (`seed_bounced` nueva señal, `salsa_exploded`) igual que `HapticManager`, en vez de que cada feature llame `play_sfx()` a mano. Rebote genérico usa un solo tono con `pitch_scale` creciente por rebote dentro de la ráfaga (efecto "escala ascendente" del GDD sin necesitar varios archivos).
- Verificado con captura real del viewport (no solo boot headless): bloques, molcajete e íconos se ven con sus sprites nuevos; el menú con el fondo IA es legible.

## Niveles finitos + acelerar semillas + skill de diseño ✅

Cambio de fondo pedido por el usuario: el diseño original del GDD (progresión infinita
por oleadas) se conserva como **Modo Infinito**, y se agrega **Modo Nivel** como
experiencia principal — tableros finitos y deterministas (mismo contenido para todos
los jugadores), con victoria real.

- **`data/levels/*.json` + `manifest.json`** — un archivo por nivel, el manifiesto define el orden de juego. Un nivel define su contenido con `cells` (col/row/kind/hp/corner, absolutas, visibles desde el inicio) y/o `row_queue` (filas sin `row` explícito que se revelan una por turno, igual mecánica que Modo Infinito pero con contenido fijo). **Corrección de diseño post-implementación:** la primera versión colocaba todo el contenido de un nivel de una sola vez (`cells` únicamente) — el usuario aclaró que un nivel debe sentirse como el Modo Infinito en miniatura: arrancar mostrando 1 fila y revelar el resto de a poco hasta agotar un total fijo de filas (nivel 1 = 10 filas), venciendo solo cuando la cola se agota Y no queda ningún destructible. De ahí nace `row_queue`; `cells` se conservó tal cual para los niveles-figura, donde SÍ se quiere ver toda la forma de una vez. **100 niveles** (`tools/gen_levels.py`, objetivo del GDD alcanzado): 94 procedurales vía `row_queue` (porta las fórmulas de `wave_scaling.gd` a Python, sin RNG en runtime; `total_rows_for_level()` = 10 + 3×(nivel-1) con TOPE de 50 filas, alcanzado en el nivel 15 — de ahí en adelante la dificultad sigue subiendo por HP/variedad de bloques vía `effective_wave`, no por duración, para no violar la "sesión target: 2-5 minutos" del GDD en niveles altos) + 6 niveles-figura vía `cells` hechos a mano (Cruz, Corazón, Botella, Estrella, Diamante, Carita Feliz — 3 en silueta + 3 rellenos).
- **`src/features/board/cell_factory.gd`** (nuevo) — única fábrica "kind → nodo", compartida por Modo Infinito y Modo Nivel. Es el único lugar que hay que tocar para agregar un power-up/bonus nuevo a futuro.
- **`src/features/levels/level_loader.gd`** — parseo + validación pura de JSON (mismo estilo que `wave_scaling.gd`). **Bug real encontrado por los tests:** `JSON.parse_string()` devuelve los números siempre como `float`, nunca `int` — un chequeo `is int` rechazaba niveles perfectamente válidos. Ver regla CLAUDE.md #46.
- **`LevelManager`** (autoload nuevo, después de `SaveManager`) — cachea niveles ya cargados, guarda el manifiesto, y expone un "buzón" de nivel pendiente de **lectura no destructiva** (crítico: si se vaciara al leerlo, reintentar un nivel tras perder volvería a Modo Infinito en silencio).
- **`GameManager`** — `start_game(level_id: String = "")`: los dos call-sites existentes (`Game.gd`, `TutorialGame.gd`) no cambiaron y siguen siendo Modo Infinito. Nuevo estado `LEVEL_COMPLETE`.
- **`BoardManager`/`TurnManager`** — la rama Modo Infinito queda literal (envuelta en `if/else`); Modo Nivel coloca las `cells` del JSON directo (sin `_spawn_row` aleatorio), revela la primera fila de `row_queue` al iniciar y una fila más por cada `all_seeds_returned` (`_spawn_next_queued_row()`), y usa `starting_seeds` del nivel. `_shift_down()`/`_check_game_over()` se llaman igual en ambos modos — el tablero se sigue desplazando cada turno aunque no aparezcan filas nuevas, así que "llegar a la fila del molcajete" sigue siendo derrota real también en un nivel. `level_cleared` solo se emite cuando la cola ya se agotó Y no queda ningún destructible.
- **Acelerar semillas**: `EventBus.seed_boost_changed` — `Mortar` lo emite fuera de AIMING (mantener presionado), `Seed` multiplica su delta efectivo (`Constants.SEED_BOOST_MULTIPLIER = 2.0`) y duplica su tope de iteraciones de rebote por frame (no `Engine.time_scale`, que afectaría tweens/timers que deben seguir a velocidad normal).
- **Línea de peligro visual** (`danger_line.gd`, v2) — rediseñada tras feedback de que la primera versión (línea punteada simple) "se veía sin chiste" y no transmitía "no querer cruzarla": ahora es una banda de degradado rojo que se desvanece hacia arriba + chevrones estilo cinta de peligro apuntando hacia abajo + línea sólida, las tres capas pulsando juntas (`_process` + `queue_redraw`, `sin()` sobre el tiempo transcurrido). Sigue sin collider — puramente visual.
- **Pantallas nuevas**: `LevelSelectScreen.tscn` (grilla de niveles, bloqueados más allá de `SaveManager.get_highest_level_unlocked()`), `LevelCompleteScreen.gd` (calco de `GameOverScreen.gd`, con botón "Siguiente Nivel"). `MainMenu` ahora tiene NIVELES / MODO INFINITO / CONFIGURACIÓN.
- **Bug real encontrado por captura de pantalla:** `HUD` leía `GameManager.is_level_mode()` en su propio `_ready()`, que corre ANTES de que `Game.gd` llame `GameManager.start_game(level_id)` — mostraba el nivel/oleada de la partida ANTERIOR. Fix: `HUD` reacciona a `EventBus.game_started` (igual que `BoardManager`/`TurnManager`), nunca lee el estado de forma síncrona y temprana. Ver regla CLAUDE.md #47.
- **Skill nueva `/level-designer`** (`.claude/skills/level-designer/SKILL.md`) — diseña niveles nuevos en lenguaje natural (figuras, packs temáticos), incluye `tools/validate_level.py` (validación en Python sin necesitar Godot) y `tests/unit/test_level_manifest_integrity.gd` como autoridad final (recorre TODO el catálogo real).
- Verificado con captura real del viewport: nivel procedural, nivel-figura (corazón en silueta), MainMenu con los 3 botones, y LevelSelectScreen con la grilla de niveles (ScrollContainer vertical, escala sin cambios a 100 niveles).
- **Corrección post-feedback verificada con captura real:** `level_001` arranca mostrando solo 1 fila (no las 10 completas) y, tras emitir `all_seeds_returned`, revela la fila siguiente de la cola mientras la primera baja — confirma `row_queue` funcionando turno a turno. La misma captura muestra `danger_line.gd` v2 (banda + chevrones) renderizando correctamente. **Nota técnica:** la captura vía `get_viewport().get_texture().get_image()` da `null` bajo `--headless` (usa el `RenderingServer` dummy, sin textura real) — hay que correr el proceso probe SIN `--headless` (ventana real, aunque no se vea) para que la captura funcione.

### Rebalance de HP/semillas por nivel (dificultad progresiva) ✅

Pedido explícito: los niveles procedurales se sentían con muy poca resistencia por bloque
(nivel 1 arrancaba con totopos de HP 1). El HP ahora escala directo con el **número de
nivel**, desacoplado de `effective_wave` (que sigue gobernando SOLO qué tipos de bloque
pueden aparecer — queso/triángulo/salsa oleada 6+, piedra oleada 16+, igual que antes):
- `tools/gen_levels.py::totopo_hp_max_for_level()`/`totopo_hp_min_for_level()` — nivel 1 va
  de 10 a 50 golpes, nivel 100 de 60 a 300, sigue subiendo igual más allá (sin tope, a
  diferencia de `total_rows_for_level()`). Totopo es la escala ancla (no queso) porque
  queso/triángulo/salsa no existen todavía en el nivel 1 real (desbloquean en nivel 11+) —
  anclar el tope en queso habría dejado el nivel 1 sin ningún bloque que realmente llegue a
  50. **Corrección post-feedback:** la primera versión le daba el MISMO valor de HP a
  TODOS los bloques del nivel (ej. todos con 50 en nivel 1) — el usuario aclaró que quería
  variedad: cada bloque sortea su propio HP dentro del rango del nivel
  (`random_totopo_hp()`, determinista vía la seed fija del nivel, así que sigue siendo el
  mismo tablero para todos los jugadores), con el valor MÁXIMO posible siendo el número
  pedido (50 en nivel 1, 300 en nivel 100) — no un valor fijo repetido. El pack Mundial
  (`tools/gen_worldcup_pack.py`) se corrigió igual (rango 60-300, el mismo que nivel 100).
- `queso_hp_for_base()` = 1.5x el HP sorteado de ESE bloque (misma proporción que
  `wave_scaling.gd` de siempre — no un valor de queso fijo), salsa/triángulo comparten la
  misma llamada a `random_totopo_hp()` que totopo (cada uno sortea su propio valor).
- `starting_seeds_for_level()` escala con la misma curva lineal (30 semillas en nivel 1,
  110 en nivel 100) — pedido explícito de mantener esto "consistente" para que el salto de
  HP no vuelva los niveles imposibles de limpiar. Ajuste de buena fe, no verificado con
  playtesting real (ver Pendientes) — la física de rebote real (una semilla puede golpear
  el mismo bloque muchas veces mientras rebota, no se "gasta" al primer impacto) hace muy
  difícil simular en el papel si el ratio HP:semillas elegido es exactamente el correcto.

## Ícono de Android rediseñado ✅

El ícono anterior (`assets/icon.png`, `config/icon` en `project.godot` — usado por Android
al no haber `launcher_icons/*` configurados en `export_presets.cfg`) era un placeholder
procedural muy básico: un triángulo plano con puntos oscuros simulando manchas. Reemplazado
por una mascota vectorial "toony" del totopo (ver skill `/gen-ai-art`, 512×512 ≥ umbral de
128px para usar IA en vez de procedural):
- Generado vía Pollinations.ai (Flux), prompt "cute cartoon tortilla chip character mascot,
  big expressive eyes, golden crispy corn chip triangle body, tiny red salsa splash,
  playful toony vector style, thick black outlines, flat vibrant colors, dark navy circular
  background, mobile game app icon, centered, no text", seed `7734`.
- El personaje llegaba casi hasta los bordes del canvas — riesgo real en Android, donde
  varios launchers (Samsung/Pixel, etc.) aplican máscara "adaptive icon" incluso a un ícono
  plano sin capas foreground/background configuradas, recortando ~25-33% del borde. Se le
  aplicó chroma-key contra su propio fondo oscuro (mismo patrón que `chroma_key()` del
  skill, pero sobre fondo oscuro en vez de blanco) y se recompuso al 72% de escala,
  centrado, sobre un canvas plano del mismo tono que `Constants.COLOR_BG_BOARD` — deja
  margen de seguridad real sin dejar ninguna costura visible.
- `assets/icon.png.import` no cambió (mismo archivo/UID, Godot reimporta solo). Confirmado
  con `godot --headless --editor --quit` (reimport limpio) + `gdlint`/GUT sin regresiones.

## Packs temáticos de niveles ✅

Dos packs hand-authored (namespace propio, nunca `level_0NN`, siguiendo la convención de
`/level-designer` para packs) agregados al final del manifiesto (115 niveles en total):
- **`tools/gen_holiday_pack.py`** (5 niveles, `holiday_001`-`005`) — Árbol de Navidad,
  Regalo, Muñeco de Nieve, Bastón de Caramelo, Campana. Mismo patrón que las 6 figuras del
  roster numérico: `cells` (toda la forma visible desde el inicio), HP 1 fijo, 16 semillas
  — el objetivo es la satisfacción de despejar la figura, no la dificultad.
- **`tools/gen_worldcup_pack.py` v1** (10 niveles, baja resolución 7×6, HP variado
  60-300) — **REEMPLAZADO por v2** tras ver referencias visuales del usuario (ver sección
  "Niveles static de alta resolución" abajo). Ya no existe en el repo.
- Ambos scripts son idempotentes (correrlos de nuevo no duplica entradas en el manifiesto)
  y usan `cells_from_ascii()`/`sprinkle_icons()` de `tools/gen_levels.py` por import, sin
  duplicar lógica. Validados con `tools/validate_level.py` + `test_level_manifest_integrity.gd`
  (recorre TODO el manifiesto real, incluyendo todos los packs) + captura real del viewport
  (árbol navideño reconocible).
- **Bug real encontrado (el usuario no podía acceder a los packs):** dos problemas
  distintos, ambos corregidos:
  1. `tools/gen_levels.py::main()` sobreescribía `manifest.json` completo con SOLO su
     propia lista de 100 ids — cualquier corrida posterior de este script borraba las
     entradas de los packs (`holiday_00N`/`worldcup_00N`) del manifiesto, aunque sus
     archivos `.json` seguían en disco (contenido huérfano, invisible en el juego, sin
     ningún error). Fix: `main()` ahora preserva cualquier id existente en el manifiesto
     que NO empiece con `level_` (es un pack, no algo que ese script genere) al final de
     la lista regenerada.
  2. `LevelSelectScreen.gd` desbloqueaba TODOS los niveles del manifiesto (numéricos y de
     packs) con la misma regla secuencial (`highest_level_unlocked`) — como los packs
     quedan en las posiciones 101+ del manifiesto, en la práctica había que terminar el
     roster numérico completo para poder tocarlos. Fix: `_is_pack_level()` distingue por
     prefijo del id; los packs ahora se muestran en una sección aparte ("PACKS ESPECIALES")
     y SIEMPRE están desbloqueados, sin depender del progreso — son contenido
     opcional/bonus, no una continuación de la campaña principal. Verificado con captura
     real (scroll hasta el final: niveles 89-100 en gris/bloqueados, los de los packs
     todos habilitados). El total de niveles de los packs cambió después (ver siguiente
     sección) — el mecanismo de desbloqueo siempre-abierto no depende de un número fijo.

## Niveles `static` de alta resolución + power-up láser ✅

Pedido explícito del usuario tras compartir 3 imágenes de referencia (cancha de fútbol,
Copa del Mundo, texto "GOL") mucho más detalladas que lo que permite la grilla de 7
columnas del juego — "cuadros más pequeños... que se apreciaran las figuras desde el
inicio". Reemplaza por completo el pack Mundial v1 (10 niveles, baja resolución, HP fijo).

- **Por qué no se pudo resolver con lo que ya existía:** el tablero normal tiene exactamente
  7 columnas (`Constants.GRID_COLS`) y solo ~9 filas visibles a la vez antes de la fila del
  molcajete — insuficiente para una imagen "de cientos de bloques" como las de referencia.
  Tampoco servía `row_queue` (revelado progresivo): como cada fila nueva empuja las
  anteriores hacia abajo, con más de ~9 filas en la cola el jugador NUNCA vería la figura
  completa de una vez, solo una ventana deslizante — lo opuesto a "apreciarla desde el
  inicio".
- **Solución: niveles `"static": true`** (ver `src/features/levels/level_loader.gd`,
  `src/features/board/board_manager.gd`) — grilla PROPIA por nivel vía el campo
  `"grid_cols"` (nada que ver con `Constants.GRID_COLS`, que sigue rigiendo Modo Infinito y
  el resto de Modo Nivel intacto): `_static_cell_size = DESIGN_WIDTH / grid_cols`, así que
  un nivel puede pedir 44, 22 o 50 columnas y los bloques se dibujan proporcionalmente más
  chicos para que quepan todos en el mismo ancho de pantalla. Los bloques de un nivel
  `static` **nunca se desplazan** (`BoardManager` se salta `_shift_down()`) y **no hay
  condición de derrota** (se salta `_check_game_over()` también) — decisión confirmada con
  el usuario tras preguntarle explícitamente. `danger_line.gd` se oculta a sí misma para
  estos niveles (mostrarla no tendría sentido y cortaría la figura a la mitad visualmente,
  ver bug corregido abajo). Se gana despejando todo lo destructible, sin importar cuántos
  turnos tome.
- **`grid_rows` obligatorio + auto-escalado en 2 ejes (v3, corrige un bug real reportado
  jugando):** v2 solo escalaba el tamaño de celda por ancho (`DESIGN_WIDTH / grid_cols`),
  sin verificar si `grid_rows` (que ni siquiera era un campo declarado — se inferían del
  máximo `row` usado) cabía en el alto disponible. Resultado real: el nivel de la Copa (alto,
  40 filas de contenido) se dibujaba más grande de lo que cabía verticalmente y terminaba
  tapando el área del molcajete. Fix: `grid_rows` ahora es **obligatorio** (validado igual
  que `grid_cols`, en `level_loader.gd` y su espejo `tools/validate_level.py`) y
  `BoardManager._setup_static_layout()` calcula `_static_cell_size =
  min(DESIGN_WIDTH/grid_cols, alto_disponible/grid_rows)` (el menor de los dos ajustes, para
  garantizar que SIEMPRE quepan ambas dimensiones) y centra el resultado en ambos ejes
  (`_static_origin`) dentro del área de juego, reservando `Constants.STATIC_LEVEL_BOTTOM_MARGIN
  = 144.0` px libres antes del molcajete. Con esto, declarar `grid_cols`/`grid_rows`
  correctamente basta — ya no hace falta calcular a mano si una figura "cabe".
- **Tamaño proporcional entre niveles del mismo pack** (pedido explícito: "los tamaños de
  los cuadros deben ser proporcionales... el espacio del cuadro de un nivel normal
  podríamos dividirlo en 4 cuadros de niveles fijos") — v2 usaba `grid_cols` muy distintos
  entre sí (22/44/50) sin relación con el tablero normal, dando bloques de tamaño
  visualmente inconsistente entre las 3 figuras. v3 fija `Constants.STATIC_LEVEL_DEFAULT_SUBDIVISION
  = 2` → `grid_cols = Constants.GRID_COLS * 2 = 14` como tamaño ESTÁNDAR para la mayoría de
  las figuras del pack (mismo tamaño de bloque en todas), con una excepción documentada
  (subdivisión 3 → 21 columnas) solo para la cancha y el texto "GOL", que sí necesitan más
  ancho para leerse. `grid_rows` varía libremente según la proporción natural de cada
  figura a `grid_cols` fijo.
- **Bono por velocidad** (pedido explícito: "recompensar el hecho de hacerlo en menos
  turnos") — campo opcional `"par_turns"` en el nivel; si se limpia en <= par_turns,
  `GameManager._apply_par_turns_bonus()` multiplica el score final por
  `Constants.STATIC_LEVEL_PAR_BONUS_MULTIPLIER` (1.5×) ANTES de calcular oro/mejor puntaje
  — reusa el sistema de oro/score que ya existe en vez de inventar una segunda moneda o un
  sistema de estrellas nuevo. `EventBus.level_cleared` ganó un segundo parámetro
  (`turns_used: int`, 0 = no aplica) para poder calcularlo; se actualizaron todos los
  emisores/tests existentes a la firma nueva.
- **Power-up nuevo: láser** (`src/features/powerups/laser_icon.gd`, pedido explícito
  del usuario — "elementos tipo laser que... lanzan golpes en horizontal o vertical") — al
  tocarlo, `Constants.LASER_DAMAGE` (25) de daño a TODA la fila o columna donde está (según
  `orientation`, fija por instancia), vía `EventBus.laser_triggered` →
  `BoardManager._on_laser_triggered()` (mismo patrón que la explosión en cruz de la salsa,
  pero en línea recta). Nuevo kind `"laser"` registrado en `wave_scaling.gd`/
  `cell_factory.gd`, **sin** probabilidad de spawn en Modo Infinito a propósito (solo
  aparece en niveles autorados) para no tocar el balance ya validado de ese modo.
- **Puntos de entrada dentro de la figura** (pedido explícito, corrige v2: "dentro de los
  huecos puedes poner los power up" se leyó primero como "solo en el fondo", pero el
  usuario aclaró después: "entre las partes de las figuras puedes poner power up... para
  entrar a la figura y poder destruirla desde adentro") — v3 identifica celdas realmente
  INTERIORES de la silueta (con sus 4 vecinos también rellenos, inalcanzables en línea
  recta desde afuera) y reemplaza hasta 5 de ellas por `lemon`/`seed_extra`/`laser` en vez
  de `totopo` (`_interior_entry_points()`) — el jugador tiene que abrirse paso hasta esa
  celda exacta para "entrar". Figuras sin celdas interiores (marcos delgados como la
  portería, patrones fragmentados como la bandera a cuadros) terminan con 0 puntos de
  entrada — no se fuerza.
- **Elementos decorativos** (pedido explícito: "que no se vean tan vacíos... alguna
  estrella, un balón, la silueta abstracta de un futbolista") — 2-5 mini-estrellas
  (`_add_decorations()`) sembradas en el margen alrededor de cada figura, sin superponerse
  a la silueta principal; `MARGIN_CELLS = 2` de padding entre el borde del canvas y el
  bounding box real de la figura para que tengan dónde ir.
- **Semillas iniciales bajas** (pedido explícito, ya sin presión de tiempo): 50 en vez del
  antiguo 200 del pack Mundial v1.
- **`tools/gen_worldcup_pack.py` v3 — 10 niveles** (corrige v2, que redujo el pack de 10 a
  3 por error de alcance — "tampoco me refería a que solo dejaras 3 niveles"): Balón,
  Trofeo (silueta paramétrica reutilizada de v2, con el "ojo" hueco cerca de la cabeza),
  Portería, Camiseta, Estrella del Mundial, **Silueta abstracta de futbolista** (nueva,
  pedida explícitamente — cabeza + torso + pierna de apoyo + pierna de patada extendida,
  geometría pura), Cancha de Fútbol (geometría reutilizada de v2), texto "¡GOL!" (único que
  usa Pillow), Banderín de esquina, Medalla. Las imágenes de referencia que compartió el
  usuario (cancha/copa/GOL) se tratan como **ejemplos de estilo**, no specs a replicar
  celda por celda ("no se trataba de que los crearas exactamente igual con la misma
  cantidad de bloques" — aclaración explícita del usuario). HP variado 60-300 por bloque
  (igual filosofía que el resto del roster: sorteado, nunca fijo).
  - Dos formas descartadas por no leerse bien en el juego (detectado con captura real, no a
    priori): una "malla" en la portería con suficiente densidad para leerse como red
    terminaba rellenando casi todo el marco (se simplificó a marco limpio, sin malla); una
    "bandera a cuadros" no se distinguía como tal porque el juego solo tiene un color de
    bloque por tipo (sin alternancia de color no hay efecto ajedrezado) — se reemplazó por
    un banderín de esquina (asta + triángulo), que sí se lee en monocromo.
- **Bug real encontrado con captura de pantalla (v2):** a la resolución de un nivel
  `static` (~9px por celda), el número de HP que `block_base.gd` siempre dibuja sobre cada
  bloque se volvía ilegible y convertía la figura en ruido visual — arruinaba el propósito
  completo de la feature. Fix inicial: `Constants.UI_MIN_READABLE_CELL_SIZE = 20.0`;
  `block_base.gd` guarda su `_cell_size` real en `setup()` y oculta el label de HP por
  debajo de ese umbral.
- **Bug real reportado jugando (v2 → v3): el nivel de la Copa tapaba el molcajete** — ver
  el punto "`grid_rows` obligatorio + auto-escalado en 2 ejes" más arriba; root cause y fix
  completos ahí.
- **Bug real reportado jugando (v3): los números de HP excedían el tamaño de los cuadros**
  — el fix anterior solo ocultaba el label por debajo de 20px, pero para niveles `static`
  con celdas de ~21-22px (la mayoría del pack Mundial v3) el label SÍ se mostraba, con un
  `font_size` FIJO de 18px (pensado para el tablero normal, ~56px de celda) — un HP de 3
  dígitos a 18px desbordaba visualmente cualquier celda por debajo de ese tamaño. Fix:
  `Constants.UI_HP_FONT_SIZE_RATIO = 0.4` — el font_size ahora escala con
  `_cell_size * UI_HP_FONT_SIZE_RATIO` (capado por `UI_MIN_FONT_SIZE=18`, piso
  `UI_HP_FONT_MIN_SIZE=8`). Con la fuente ya escalando, el umbral de "ocultar por completo"
  se pudo bajar de 20.0 a 15.0 (antes ocultaba de más — con el número ya chico, celdas de
  ~15-19px se leen perfectamente bien) — recuperó los números en el nivel de la Copa
  (~19.5px), que antes quedaba oculto de más. Verificado con captura real: números
  legibles y CLARAMENTE variados (ej. "61 43 260 255 167 193…" en el mismo nivel) — esto
  también resuelve, sin tocar datos, la percepción reportada de "todos los cuadrados
  requieren la misma cantidad de golpes": el HP siempre estuvo sorteado por celda
  (`rng.randint(HP_MIN, HP_MAX)` en `build_static_level()`, confirmado con datos reales:
  106 celdas, 89 valores únicos, rango 63-300) — lo que hacía parecer "todos iguales" era
  que los números overflowing/ilegibles no dejaban comparar valores, no que faltara
  variedad real.
- **Semillas extra abundantes** (pedido explícito tras jugar: "en una partida de este tipo
  de exhibición deberíamos poder llegar por lo menos a unas 300 semillas al finalizar el
  nivel") — con `Constants.SEED_EXTRA_AMOUNT` fijo en +1 (pensado para Modo Infinito/
  campaña numérica) habría hecho falta sembrar ~250 íconos por nivel, poco práctico. En vez
  de tocar esa constante global (arriesgaría el balance ya ajustado de los otros dos
  modos), `EventBus.seed_extra_touched` ganó un segundo parámetro (`amount: int`) y
  `seed_extra_icon.gd` expone una propiedad `amount` (default = la constante global,
  overridable por celda vía el campo opcional `"amount"` en el JSON del nivel, mismo patrón
  que `corner`/`orientation` en triangle/laser). `gen_worldcup_pack.py` v3 siembra
  `SEED_BOUNTY_COUNT=12` íconos por nivel en el fondo (fácil de alcanzar, sin necesidad de
  abrirse paso) más los que caigan en puntos de entrada, cada uno con
  `"amount": SEED_EXTRA_ICON_AMOUNT=20` — la mayoría de los 10 niveles llega a 290-330
  semillas máximas si se recolectan todos.
- **Bug real reportado jugando: el molcajete se reposicionaba antes de que terminara la
  ráfaga** — `TurnManager` emitía `EventBus.molcajete_position_changed` en cuanto ATERRIZABA
  LA PRIMERA semilla, mientras el resto de la ráfaga seguía rebotando en el aire — se veía
  raro (el molcajete "abandonaba" la posición con semillas todavía cayendo ahí). Fix: la
  posición de destino se sigue calculando con la primera semilla en aterrizar (mismo
  criterio de siempre para "dónde atajar"), pero la señal que mueve el molcajete
  (`Mortar._on_molcajete_position_changed`) ahora se emite junto con `all_seeds_returned`
  — recién cuando ya no queda ninguna semilla activa. No es específico de niveles `static`
  (afecta a los 3 modos por igual, ver `turn_manager.gd::_on_seed_landed()`).
- Verificado con captura real de varios niveles del pack v3 tras todos los fixes de esta
  ronda — ninguno invade el área del molcajete, figuras centradas verticalmente, números de
  HP legibles y variados donde el tamaño de celda lo permite.
- **Nombre del nivel visible al jugar** (pedido explícito: "poner el nombre de lo que
  representa la imagen abstracta para ayudar al jugador a relacionar la imagen... por
  ejemplo, donde está la copa, poner 'Copa'") — `HUD._on_game_started()` ahora arma
  "Nivel N · Nombre" (`LABEL_LEVEL_NUMBER_NAMED`, nueva key i18n) cuando el nivel trae
  `name` (niveles-figura del roster numérico y AMBOS packs temáticos); sin `name` (la
  mayoría de los 100 niveles numéricos) sigue mostrando solo "Nivel N" como antes. Mismo
  criterio en `PackLevelsScreen`: los botones pasaron de mostrar solo un número a
  "N. Nombre" (ej. "2. Copa del Mundo") — ayuda a reconocer qué figura es ANTES de entrar a
  jugarla, no solo durante. Grilla de botones angostos-cuadrados (4 columnas) a
  botones anchos (2 columnas, `PackLevelsScreen.BUTTON_WIDTH=172`) para que el nombre
  quepa. La numeración de estos botones es LOCAL al pack (1, 2, 3...), no la posición
  global en el manifiesto de 115 niveles — más intuitiva para explorar un pack temático
  como colección propia, aunque no coincida con el "Nivel 107" que se ve una vez adentro
  (ese número sigue siendo la posición real en el manifiesto, consistente con el resto de
  la campaña). Verificado con captura real: HUD mostrando "Nivel 107 · Copa del Mundo",
  grilla del pack con los 10 nombres legibles.
- **HP sesgado hacia golpes baratos** (pedido explícito tras jugar: "lo ideal sería que la
  mayoría de bloques no requirieran tantos golpes... el 80% por debajo de la mitad del
  rango, y solo el 20% por encima, porque si no cada partida se vuelve demasiado larga y
  tediosa") — antes `hp = rng.randint(HP_MIN, HP_MAX)` uniforme (HP promedio ~180); ahora
  `_random_hp()` en `tools/gen_worldcup_pack.py`: 80% de probabilidad de caer en la mitad
  baja del rango (`[HP_MIN, HP_MID]`), 20% en la mitad alta — HP promedio real tras
  regenerar ~140-150 (~20% menos), con la proporción real medida en un nivel: 85% de los
  bloques por debajo de la mitad, 78 valores únicos de 106 celdas (sigue siendo sorteado,
  nunca fijo, solo con el sesgo). `par_turns` (calculado a partir de `total_hp`) bajó en la
  misma proporción automáticamente, sin tocar esa fórmula. Aplicado solo al pack Mundial
  (`static`, sin condición de derrota — el HP promedio determina directamente cuánto dura
  la partida) — no se tocó `gen_levels.py` (roster numérico, `row_queue`, la duración ya
  está acotada por el número de turnos, no solo por HP).

## Pulido de descubribilidad y ritmo del pack Mundial ✅

Tres pedidos explícitos del usuario tras jugar el pack v3 ya corregido (fuente/molcajete/
semillas de la ronda anterior):

- **Botones del pack desalineados** ("los nombres no aparecen alineados, creo que es
  porque están centrados sobre su columna... quizá deban estar alineados a la izquierda")
  — `PackLevelsScreen`: cada botón centraba su texto dentro de su propio ancho, así que un
  nombre corto ("1. Balón") y uno largo ("2. Copa del Mundo") arrancaban en columnas X
  distintas, dando sensación de desorden al leer la lista de corrido. Fix: `btn.alignment =
  HORIZONTAL_ALIGNMENT_LEFT` — todos los nombres ahora arrancan en la misma columna. Un
  margen chico (dos espacios al inicio del texto) separa el texto del borde izquierdo del
  botón sin tocar el `StyleBox` del tema (pisar el StyleBox "normal" con uno vacío para
  simular un margen habría roto el fondo/borde/hover del botón — descartado a mitad de
  implementación al notar el efecto secundario).
- **Complejidad de HP bajada a "nivel 50"** (pedido explícito: "bajemos la complejidad de
  los packs a un nivel 50, para que sean más divertidos, pero conservemos las 'ayudas'")
  — `HP_MIN`/`HP_MAX` en `tools/gen_worldcup_pack.py` pasaron de los valores del nivel 100
  (60-300, el tope de la campaña) a los del nivel 50 (`totopo_hp_min_for_level(50)`/
  `totopo_hp_max_for_level(50)` de `gen_levels.py` = 35-174). Combinado con el sesgo 80/20
  ya aplicado, el HP promedio real bajó de ~140-150 a ~80-87 por nivel, y `par_turns` cayó
  proporcionalmente (ej. worldcup_002: 51 → 29 turnos). Las "ayudas" (decoraciones, puntos
  de entrada, semillas extra abundantes, nombre visible) quedaron intactas — solo se tocó
  el rango de HP.
- **Los niveles de pack ya no aparecen en "Niveles"** (pedido explícito: "quita los
  niveles que pertenecen a Packs de la pantalla de 'Niveles'. Que solo se muestren en la
  pantalla de su pack correspondiente") — `LevelSelectScreen` antes mostraba una sección
  aparte ("PACKS ESPECIALES") al final del roster numérico con los mismos niveles que ya
  eran accesibles desde `PackSelectScreen`/`PackLevelsScreen` — contenido duplicado en dos
  pantallas. Se quitó esa sección por completo (`_build_grid()` ahora hace `continue` en
  cualquier id que no empiece con `level_`); los packs siguen siendo 100% accesibles, solo
  que exclusivamente desde su pantalla dedicada. `_is_pack_level()` se conserva (se sigue
  usando para filtrar, no para separar en dos secciones).
- Verificado con captura real de las tres pantallas: nombres alineados en `PackLevelsScreen`,
  `LevelSelectScreen` mostrando solo números 1-100 sin ningún botón de pack, y un nivel del
  pack Mundial con HP visiblemente más bajo (mayormente 2 dígitos) que antes.

## Sistema de mejoras/oro/personajes ✅

Pedido explícito del usuario — decisión de alcance previamente diferida, implementada esta
sesión sin más aclaraciones (el usuario pidió "avanzar" mientras probaba otra parte del
juego). Alcance elegido deliberadamente conservador para no arriesgar el balance del juego
ya ajustado esta sesión:
- **`MetaManager`** (autoload nuevo, `user://meta.json`, SEPARADO de `SaveManager`) — oro,
  nivel de cada mejora (0-5), personajes desbloqueados/seleccionado. Se separó de
  `SaveManager` porque agregar estos métodos ahí superaba el máximo de 20 métodos públicos
  por clase que exige `gdlint` (`max-public-methods`) — ver regla CLAUDE.md #51. Mismo
  patrón JSON plano que `SaveManager.gd` (`_load()`/`save()`), archivo separado.
- **`src/features/meta/upgrade_shop.gd`** — lógica pura (costos, bonos, oro ganado por
  score), sin autoload, testeable sin escena (mismo estilo que `wave_scaling.gd`).
- **Oro:** se gana siempre que una run/nivel termina (`GameManager._award_gold_for_run()`,
  victoria, derrota o nivel fallido — sin distinguir el desenlace), `Constants.GOLD_PER_SCORE_POINT
  = 0.05` × score final.
- **3 mejoras permanentes**, 5 niveles cada una, costo lineal creciente
  (`Constants.UPGRADE_BASE_COST=50` + 40 por nivel adicional): **Semillas Extra**
  (+2 semillas iniciales/nivel, aplicado en `TurnManager._on_game_started()`, ambos modos),
  **Daño Base** (+8% daño por impacto/nivel, aplicado en `block_base.take_damage()` —
  la explosión de salsa NO se escala, sigue siendo el valor fijo del GDD), **Velocidad**
  (+4% velocidad de semilla/nivel, aplicado en `TurnManager._fire_one_seed()`).
- **4 personajes cosméticos** (Clásico/Turquesa/Rosa Mexicano/Dorado) — SOLO tiñen el
  molcajete vía `modulate` (`Mortar._apply_character_tint()`), sin ningún efecto en
  gameplay — decisión deliberada para no meter otra variable de balance encima del
  rebalance de HP/semillas de esta misma sesión.
- **`UpgradeShopScreen.tscn`** (nueva, accesible desde `MainMenu` — botón TIENDA) — lista de
  mejoras con nivel/costo/botón comprar + grilla de personajes con estado
  bloqueado/desbloqueado/seleccionado. `MainMenu` también muestra el oro actual, reactivo a
  `EventBus.gold_changed`.
- Verificado con captura real: `MainMenu` con el botón TIENDA + oro visible, y la tienda
  completa (mejoras + personajes) renderizando sin el bug de centrado de Container (regla
  CLAUDE.md #49) que ya se había corregido antes en `LevelSelectScreen`.

## Navegación dedicada a packs temáticos ✅

Pedido explícito del usuario tras probar: los packs (navideño/Mundial) solo eran visibles
haciendo scroll hasta el final de los 115 niveles en `LevelSelectScreen` — "no intuitivo".
- **`Constants.LEVEL_PACKS`** — registro central (`{"prefix": ..., "name_key": ...}` por
  pack). Agregar un pack nuevo con la skill `/level-designer` requiere sumarlo acá para que
  aparezca en la lista dedicada (aunque sigue siendo jugable desde la sección de
  `LevelSelectScreen` sin este paso, por prefijo de id).
- **`PackSelectScreen.tscn`** (nueva, botón "PACKS ESPECIALES" en `MainMenu`, antes de
  MODO INFINITO) — una tarjeta por pack registrado con nivel/es reales en el manifiesto
  (nombre + cantidad de niveles). Tocar una tarjeta escribe el buzón no destructivo
  `LevelManager.get_pending_pack_prefix()` (mismo patrón que `get_pending_level()`) y rutea
  a...
- **`PackLevelsScreen.tscn`** (nueva) — grilla de SOLO los niveles de ese pack, todos
  SIEMPRE desbloqueados (son contenido opcional/bonus, no la campaña numérica secuencial).
- `LevelSelectScreen` conserva su sección "PACKS ESPECIALES" al final del scroll (no se
  quitó — sigue siendo un camino válido, ahora hay dos formas de llegar).
- Verificado con captura real: `MainMenu` con el botón nuevo, y `PackSelectScreen` mostrando
  "Pack Navideño (5 niveles)" / "Pack Mundial (10 niveles)".

## Fix: paneles modales translúcidos ✅

Pedido explícito del usuario ("ten esto en cuenta siempre que hagas un modal"): la pantalla
de configuración (y, por el mismo motivo, cualquier overlay construido con
`PanelContainer.new()` sin un `StyleBox` propio) usa el panel semi-transparente por
defecto del tema de Godot — el texto se mezclaba visualmente con el fondo real detrás
(la imagen de `MainMenu`, el tablero de juego durante el tutorial), ilegible.
- **`src/shared/modal_style.gd`** (nuevo, helper compartido) — `opaque_panel(bg_color)`
  devuelve un `StyleBoxFlat` con `bg_color` casi 100% opaco (alpha 0.97) y esquinas
  redondeadas, aplicado vía `panel.add_theme_stylebox_override(&"panel", ...)`.
- Aplicado a los 5 `PanelContainer` que existen en el proyecto: `SettingsScreen`,
  `PauseScreen`, `GameOverScreen`, `LevelCompleteScreen`, y el panel de hints de
  `TutorialGame`. Ver regla CLAUDE.md #52 — cualquier modal nuevo debe usar este helper
  desde el principio, no solo los que ya existían.
- Verificado con captura real: `SettingsScreen` abierto sobre `MainMenu`, texto
  completamente legible (antes se mezclaba con el fondo detrás).

## Pendientes

- **iOS sin configurar** — `export_presets.cfg` tiene `application/app_store_team_id="PLACEHOLDER_TEAM_ID"` sin llenar (falta el Team ID de Apple Developer); no existe workflow de CI para iOS (no se ha pedido todavía). Explícitamente dejado para después.
- **Pulido de assets** — los sprites/audio actuales son una primera pasada sólida pero simple (formas geométricas + specks, sonidos sintetizados); se puede seguir iterando el detalle visual/sonoro con el mismo pipeline (`tools/gen_assets.py`) si se quiere más fidelidad.
- **Balance de los 100 niveles numéricos** — el HP por bloque escala fuerte (totopo 10-50 en nivel 1, hasta 60-300 en nivel 100, VARIADO por bloque) y las semillas iniciales se ajustaron para compensar (30→110), pero es un ajuste de buena fe sin playtesting real: la física de rebote (una semilla puede golpear el mismo bloque muchas veces antes de aterrizar) hace que "¿alcanzan las semillas para limpiar el nivel a tiempo?" no se pueda confirmar simulando en el papel. Si algún tramo del roster resulta imposible o trivial, ajustar las constantes en `tools/gen_levels.py` y regenerar.
- **Balance de los niveles `static` (pack Mundial v3)** — HP variado 60-300, 50 semillas iniciales, `par_turns` estimado con una heurística simple (`total_hp / (starting_seeds * 6)`) — ninguno de estos tres números está verificado jugando de verdad. Como estos niveles ya no tienen condición de derrota, "muy difícil" en el peor caso solo significa "toma muchos turnos", no "imposible". Ajustar `HP_MIN/HP_MAX/STARTING_SEEDS/hits_per_seed_estimate` en `tools/gen_worldcup_pack.py` y regenerar si hace falta. `Constants.LASER_DAMAGE=25` también es un valor de partida sin verificar (¿se siente débil o roto contra bloques de hasta 300 HP?).
- **Balance del sistema de mejoras/oro** — recién implementado, sin playtesting: `Constants.GOLD_PER_SCORE_POINT`, los costos (`UPGRADE_BASE_COST/COST_STEP`) y los bonos por nivel (`UPGRADE_SEEDS/DAMAGE/SPEED_BONUS_PER_LEVEL`) son valores de partida razonables pero no verificados — puede que el oro se gane muy rápido/lento, o que las mejoras se sientan poco impactantes o rotas. Ajustar en `Constants.gd` y en `src/features/meta/upgrade_shop.gd` si hace falta.
- **Más variedad de niveles** — el roster numérico ya llega a 100 (objetivo del GDD) y hay 2 packs temáticos (navideño tipo "bloques descendentes", Mundial v3 tipo "imagen fija", 10 niveles). Seguir usando `/level-designer` para más packs (ej. otras festividades) si se quiere — declarar siempre qué tipo(s) de nivel usa el pack nuevo (ver sección de niveles `static` arriba).

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
