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

## Tests GUT (138 tests, 0 fallos) ✅
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

## Pendientes

- **iOS sin configurar** — `export_presets.cfg` tiene `application/app_store_team_id="PLACEHOLDER_TEAM_ID"` sin llenar (falta el Team ID de Apple Developer); no existe workflow de CI para iOS (no se ha pedido todavía).
- **Pulido de assets** — los sprites/audio actuales son una primera pasada sólida pero simple (formas geométricas + specks, sonidos sintetizados); se puede seguir iterando el detalle visual/sonoro con el mismo pipeline (`tools/gen_assets.py`) si se quiere más fidelidad.
- **Sistema de mejoras/oro/personajes** — decisión de alcance explícita, pedido por el usuario pero diferido a otra sesión. `SaveManager` ya persiste cualquier clave nueva en un `Dictionary` a JSON sin fricción, así que agregarlo después no debería requerir cambios estructurales.
- **Balance de los 100 niveles** — primera pasada razonable (HP/filas/semillas escalados a mano en `tools/gen_levels.py`, tope de filas agregado para respetar la sesión target), no verificada con playtesting real más allá de las pruebas automatizadas y visuales. Ajustar constantes del script y regenerar si algún nivel resulta muy fácil/difícil — especialmente los niveles altos (70+), donde el HP escala bastante (`effective_wave` sigue creciendo sin tope) y no hay forma de confirmar la sensación real de dificultad sin jugarlos.
- **Más niveles / packs temáticos** — el roster ya llega a 100 (objetivo del GDD). Lo que sigue es variedad cualitativa: usar `/level-designer` para packs temáticos (ej. figuras navideñas) o reemplazar tramos procedurales por niveles diseñados a mano donde se quiera más personalidad.

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
