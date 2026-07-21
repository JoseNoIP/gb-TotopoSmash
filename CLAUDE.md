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

# Tests headless — SIEMPRE por este script, nunca invocar godot/GUT directo (ver regla
# anti-alucinación correspondiente): protege user://save.json/meta.json/pack_progress.json
# de la contaminación real que sufrió el guardado del usuario esta sesión (varios tests
# suman puntaje/oro/nivel desbloqueado permanentemente si no se restauran, y GUT no aísla
# ese estado del guardado real jugado a mano).
./tools/run_tests.sh

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
43. **Un nodo que se autodestruye con `queue_free()` (ej. un power-up/ítem recogido) debe borrarse también de cualquier `Dictionary`/`Array` tipado que lo referencie, en el mismo callback que lo libera.** Si no, la próxima vez que ese diccionario se copie o reasigne (ej. desplazar una grilla una fila) se intenta insertar una referencia ya liberada en un `Dictionary[K, V]` tipado, y Godot lo rechaza en tiempo de ejecución con `"previously freed object"` — un crash real, no una falla silenciosa. Al recorrer y reconstruir un diccionario tipado que puede contener nodos, comprobar `is_instance_valid(node)` **antes** de insertar en el nuevo diccionario (`continue` si es inválido), nunca insertar primero y validar después.
44. **`CanvasItem` (la clase base compartida por `Node2D` y `Control`) NO declara `position`/`rotation`/`scale`** — cada rama los declara por separado con su propio sistema de transform. `modulate`/`self_modulate` sí viven en `CanvasItem` y son seguros de usar directo. Esto importa cuando una variable puede apuntar a un `ColorRect` (fallback sin asset) O a un `Sprite2D` (con textura real) según si el asset existe todavía — típico patrón "placeholder → sprite real" en este proyecto. Si la variable está tipada `CanvasItem` (o cualquier tipo que no garantice `scale`), usar `.set(&"scale", valor)` en vez de `variable.scale = valor` (regla #15 aplicada a este caso concreto). `Tween.tween_property(objeto, ^"scale", ...)` SÍ es seguro con acceso directo sin importar el tipo estático, porque resuelve la propiedad en runtime vía `NodePath`, no en tiempo de compilación.
45. **Para SFX cortos generados con Python stdlib, usar `.wav`, no `.ogg`** — no hay encoder OGG en la stdlib, y `wave`/`struct` producen `.wav` sin dependencias. Godot reproduce `.wav` igual de bien para sonidos cortos (sin la latencia de decodificación de un códec comprimido). Si `AudioManager` asume `.ogg` por defecto sin haber generado ningún asset todavía, verificar contra el patrón real ya probado en otro juego del estudio antes de asumir la extensión.
46. **`JSON.parse_string()` SIEMPRE devuelve los números como `float`, nunca `int`** — incluso `"col": 3` en el archivo se convierte en `3.0` al parsear. Un chequeo `valor is int` sobre datos que vinieron de JSON da `false` aunque el archivo tenga un entero limpio, y rechaza datos perfectamente válidos (detectado por los tests reales del catálogo de niveles, que fallaban contra JSON generado correctamente). Al validar/leer datos parseados de JSON, comprobar "es un número entero" con `valor is int or (valor is float and valor == floor(valor))` (ver `_is_whole_number()` en `level_loader.gd`), nunca `is int` a secas. `int(valor)` para convertir sí funciona igual en ambos casos.
47. **Un nodo hijo instanciado dentro de `_build_scene()` (llamado desde `_ready()` de la escena raíz) NO debe leer el estado de un autoload que esa MISMA escena raíz actualiza recién DESPUÉS de `_build_scene()`** (ej. `GameManager.start_game(level_id)` llamado después de construir la escena) — su `_ready()` corre antes de que ese estado se actualice, así que lee el valor de la partida ANTERIOR (o el default). Si otros sistemas de la escena (`BoardManager`, `TurnManager`) ya reaccionan correctamente al evento `game_started` para leer ese mismo estado, cualquier nodo nuevo que necesite el mismo dato debe escuchar esa señal también — nunca leerlo de forma síncrona en su propio `_ready()`. Detectado con una captura de pantalla real mostrando el número de nivel de la partida anterior, no la actual.
48. **`get_viewport().get_texture().get_image()` (técnica de captura de pantalla real para verificación visual) devuelve `null` bajo `--headless`** — ese modo usa el `RenderingServer` "dummy" (sin textura real detrás del viewport), y llamar `.get_image()` sobre él tira `ERROR: Parameter "t" is null` seguido de un `SCRIPT ERROR` que aborta la función a mitad de camino (si el script sigue con `await`/`get_tree().quit()` después, esas líneas nunca corren y el proceso de Godot se queda colgado para siempre, sin exit code, sin más output — parece un hang de lógica pero es este bug). Para el patrón de "instanciar escena real + esperar frames + guardar PNG del viewport" (usado para verificar bugs visuales que ningún test headless puede atrapar, ver regla #42), correr el proceso probe SIN `--headless` (`godot --path . probe.tscn`, ventana real aunque no se vea en pantalla) — ahí `get_texture()` sí devuelve una textura válida.
49. **Un nodo cuyo padre directo hereda de `Container` (`GridContainer`, `ScrollContainer`, `HBoxContainer`, `VBoxContainer`, `CenterContainer`, etc.) NO respeta un `position`/`set_size()` puesto a mano** — el `Container` reposiciona a TODOS sus hijos en cada `NOTIFICATION_SORT_CHILDREN`, pisando silenciosamente cualquier valor manual (sin error, sin warning; mismo espíritu que la regla #32 pero para `Container`, no para anchors). Síntoma real: una grilla de botones dentro de un `ScrollContainer` con `grid.position = Vector2(origin_x, 0.0)` puesto a mano para centrarla terminaba siempre pegada a la izquierda (`origin_x` se ignoraba). Fix: si hace falta centrar contenido de ancho fijo dentro de un `Container`, centrar el propio `Container` (ajustando SU `position`/`set_size` al ancho exacto del contenido) dentro de un `Control` plano que sí respete asignación manual — nunca intentar mover a mano un hijo directo de un `Container`. Detectado con una captura de pantalla real (`LevelSelectScreen`).
50. **Un sistema compartido por varios modos de juego (ej. `TurnManager`, usado por Modo Infinito Y Modo Nivel) NUNCA debe depender de una señal que solo un modo emite para una transición de estado que TODOS los modos necesitan.** Bug real jugando: `TurnManager` volvía de `Phase.ADVANCING` a `Phase.AIMING` escuchando `EventBus.wave_advanced` — pero esa señal es específica de Modo Infinito ("nueva oleada"); `BoardManager` en Modo Nivel nunca la emite (no tiene sentido ahí, no hay "oleada nueva"). Resultado: en Modo Nivel, después del primer disparo el apuntado se quedaba trabado para siempre (fase nunca volvía a AIMING), sin ningún error en consola — el botón de pausa seguía funcionando (UI separada) pero el juego en sí no respondía más, muy fácil de confundir con un bug de input cuando es una máquina de estados atascada. Fix: se agregó `EventBus.turn_advanced` (sin parámetros, mode-agnostic — se emite en AMBOS modos cuando el turno termina sin game over ni victoria) y `TurnManager` pasó a escuchar esa señal en vez de `wave_advanced`. Regla general: si un handler cross-feature necesita "algo terminó, continuemos" en un sistema que sirve a N modos, la señal que dispara esa transición debe emitirse desde los N modos — nunca reusar una señal que un solo modo entiende como semánticamente relevante.
51. **`gdlint` rechaza cualquier clase con más de 20 métodos públicos (`max-public-methods`)** — un autoload que acumula getters/setters de features no relacionadas (ej. `SaveManager` con settings + tutorial + score + AHORA oro/mejoras/personajes) choca con este límite tarde o temprano. Sin buscar un truco para "caber" (prefijar con `_` cosas que sí son públicas, o un solo método `get(key)`/`set(key,val)` genérico que pierde el tipado): crear un autoload nuevo dedicado a la responsabilidad que se está agregando, con su propio archivo `user://algo.json` si necesita persistencia — mismo patrón exacto que `SaveManager.gd`/`_load()`/`save()`, solo que en un archivo separado (ver `MetaManager.gd`). Además de resolver el límite del linter, es la aplicación correcta de "una sola responsabilidad por script" (regla del skill `/feature`).
52. **`PanelContainer` sin un `StyleBox` propio usa el panel semi-transparente por defecto del tema de Godot — NUNCA asumir que un panel "modal"/overlay es opaco solo porque tiene un color de fondo definido en otro lado.** Bug real reportado jugando: el panel de `SettingsScreen` (y, por el mismo motivo, `PauseScreen`/`GameOverScreen`/`LevelCompleteScreen`/el panel de hints del tutorial — CUALQUIER `PanelContainer` usado como overlay en este proyecto) se veía translúcido sobre el fondo real detrás (la imagen del menú, el tablero de juego), y el texto del modal se mezclaba visualmente con lo que había atrás, ilegible. Sin error, sin warning — solo "se ve raro" hasta que alguien lo nota jugando. Fix: `panel.add_theme_stylebox_override(&"panel", stylebox)` con un `StyleBoxFlat` de `bg_color` casi 100% opaco (alpha ~0.97) — ver `src/shared/modal_style.gd` (helper compartido, reutilizado en las 5 pantallas). **Aplicar esto a TODO `PanelContainer` nuevo usado como modal/overlay, sin excepción, incluso si "se ve bien" en el editor** (el editor a veces renderiza el tema default distinto a como se ve en juego real).
53. **Al auto-escalar contenido de tamaño variable (una grilla, una figura) para que quepa en un espacio de pantalla fijo, escalar SIEMPRE contra TODAS las dimensiones relevantes al mismo tiempo — nunca solo una y asumir que la otra "ya cabrá".** Bug real reportado jugando: un nivel `static` (figura de alta resolución, ver `board_manager.gd::_setup_static_layout()`) calculaba su tamaño de celda solo en función del ANCHO disponible (`DESIGN_WIDTH / grid_cols`), sin verificar cuántas filas tenía la figura ni si esa altura cabía en pantalla — una figura alta (la Copa del Mundo, ~40 filas) terminaba dibujándose más grande de lo que cabía verticalmente y tapaba visualmente el área del molcajete debajo. Sin error, sin warning — el juego seguía funcionando perfectamente por debajo (misma familia de bug que la regla #42, un problema de layout que se confunde con uno de lógica). Fix: el campo que define "cuántas filas ocupa el contenido" pasó a ser **obligatorio** (antes se inferían del máximo índice usado, lo que permitía que el layout nunca supiera de antemano cuánto espacio necesitaba) y el cálculo de escala usa `min(ancho_disponible/columnas, alto_disponible/filas)` — el MENOR de los dos ajustes, para garantizar que ambas dimensiones quepan siempre — y centra el resultado en ambos ejes dentro del espacio disponible. Regla general: cualquier fórmula de "tamaño de celda = espacio disponible / unidades de contenido" que solo mire un eje es una fuga de layout esperando a pasar en el primer contenido con una proporción distinta a la que se probó primero.
54. **Un autoload que arranca música en loop (`AudioStreamPlayer` con un `AudioStreamWAV`/`AudioStreamOGG` de `loop_mode` habilitado) y nunca la detiene hace que `godot --headless -s addons/gut/gut_cmdln.gd -gexit` termine imprimiendo `WARNING: N ObjectDB instances were leaked at exit` + `ERROR: M resources still in use at exit` (el stream/playback de la música, todavía "en uso" en el instante exacto en que el proceso corta).** Esto NO es un bug ni una regresión — es el comportamiento esperado de CUALQUIER audio en loop dentro de un autoload (correcto para un juego real: la música debe sonar hasta que se cierra la app, nunca detenerse sola). Verificar el exit code real (`echo $?`) y el resumen de tests antes de asumir que algo se rompió — el exit code sigue siendo 0 y los tests siguen en verde; el warning es un diagnóstico de shutdown del motor, no una falla de test. No intentar "arreglarlo" agregando un hook de shutdown que detenga la música artificialmente — sería complejidad sin beneficio real, solo para silenciar un mensaje benigno.
55. **Reemplazar un sprite plano (`ColorRect` de color sólido, ocupa el 100% de su celda) por un sprite de IA con silueta irregular (un personaje, un objeto con forma propia) NO cambia la forma de la colisión — sigue siendo el `RectangleShape2D`/celda cuadrada de siempre.** Bug real reportado jugando: los sprites de IA generados para los bloques (un totopo, un queso, un frasco, una roca — con transparencia real alrededor de la silueta, 34-57% de píxeles opacos medido) dejaban 40-65% del área de colisión visualmente vacía; la semilla seguía rebotando en el borde cuadrado exacto de siempre (correcto — la grilla del tablero, no la silueta del arte, define el rebote), pero a los ojos del jugador el rebote pasaba "en el aire", cerca de las esquinas donde el sprite ya había terminado. Sin error, sin warning — la física seguía siendo 100% correcta, solo se veía mal. Fix: un `ColorRect` de fondo (mismo color que el bloque usaba antes de tener sprite) del mismo tamaño EXACTO que la colisión, agregado ANTES del `Sprite2D` (para quedar detrás) — la celda vuelve a verse sólida donde realmente rebota, sin importar cuánta transparencia tenga el arte encima. Regla general: cualquier sprite con transparencia real que se dibuje sobre una hitbox rectangular necesita un respaldo sólido del tamaño de la hitbox — nunca asumir que "un sprite más lindo" es un cambio puramente visual sin implicación de gameplay.
56. **`SaveManager`/`MetaManager`/cualquier autoload que persista en `user://algo.json` es el MISMO archivo real que usa una partida jugada a mano — GUT no lo aísla entre corridas.** Bug real, encontrado porque el usuario reportó "todos los niveles me aparecen habilitados desde el inicio": varios tests (`test_best_score_only_updates_when_strictly_higher`, `test_highest_level_unlocked_only_updates_when_strictly_higher`, `test_add_gold_increases_total`, `test_unlock_character_adds_it_without_duplicating`, entre otros) mutaban ese estado real (`set_*_if_higher()` sube un valor, `add_gold()`/`unlock_character()` agregan algo) sin restaurarlo al final — cada corrida de la suite (decenas a lo largo de una sesión normal de desarrollo) sumaba permanentemente +1 nivel desbloqueado, +oro, +mejor puntaje, hasta un personaje "comprado" sin haberlo comprado. Los tests seguían en verde — el síntoma solo aparece jugando de verdad, mucho después, y es fácil confundirlo con un bug de la lógica de desbloqueo cuando en realidad la lógica está bien y es el DATO el que está corrupto. Dos partes del fix: (1) todo test que mute un valor "solo si es mayor" o agregue algo a un autoload persistente debe restaurarlo al final — si la API pública no puede bajarlo (`set_best_score_if_higher()` es deliberadamente de una sola vía), escribir directo al Dictionary interno del autoload (`Autoload.get(&"_data")["campo"] = valor_original; Autoload.save()` — no es privacidad real en GDScript, el guion bajo es solo convención) — SOLO aceptable en un test, nunca en código de producción; (2) además, como red de seguridad contra tests NUEVOS que reintroduzcan el mismo problema sin que nadie lo note, envolver la corrida de la suite en un script que respalde los archivos `user://*.json` relevantes antes y los restaure después pase lo que pase (ver `tools/run_tests.sh`) — usar ESE script como el comando canónico de tests, nunca invocar `godot --headless -s addons/gut/gut_cmdln.gd` directo. **Esta misma protección NO cubre un probe manual fuera de GUT** (ej. `godot --path . probe.tscn` para capturar una pantalla real, ver regla #48) — si el probe toca un autoload persistente (`MetaManager.add_gold()`, etc.), hay que respaldar/restaurar el `.json` real a mano (`cp` antes/después) alrededor de esa corrida, igual que haría `tools/run_tests.sh` para GUT.
57. **Un SFX de impacto sintetizado con tonos puros (aunque sea fundamental+armónico, ej. una marimba) se percibe "blando"/sintético hasta que se le agrega un TRANSIENTE al inicio — un burst de ruido de solo ~10ms, ANTES/junto con el cuerpo tonal, es lo que el oído interpreta como el "click" de contacto real (mazo/objeto contra superficie).** Confirmado con investigación (técnica estándar de sound design para percusión: capa de ruido corta al ataque + filtro para el cuerpo tonal) tras dos rondas previas de ajuste de tono que no convencieron al usuario — el problema no era la frecuencia/duración elegida, sino la falta de ese transiente. Ver `tools/gen_assets.py::sfx_totopo_crunch()`: `_env(_noise(0.012, ...), 0.0005, 0.01)` mezclado con las capas tonales existentes vía `_mix()`. **Además**: dos SFX con picos de amplitud CASI IDÉNTICOS (medidos en la muestra final, no solo en el parámetro `amp` de la función generadora) pueden sonar con volumen PERCIBIDO muy distinto si difieren en frecuencia — un tono puro agudo (~1kHz+, zona de máxima sensibilidad del oído humano, curvas isofónicas) se percibe más fuerte que un tono grave/compuesto a igual pico de amplitud y hasta con varios dB menos de ganancia nominal. Al balancear el volumen relativo de dos SFX, no alcanza con bajar dB por sensación — verificar el pico real de la muestra generada (`wave`/`struct` en Python) y, si uno de los dos es un tono agudo puro, compensar también bajando su `pitch_scale` (aleja la frecuencia de la zona sensible), no solo su `volume_db`.
58. **Recorrer `dict.keys()` (una foto tomada al inicio del `for`) y acceder `dict[key]` en cada vuelta CRASHEA en runtime (`"Invalid access to property or key"`, no una falla silenciosa) si el CUERPO del propio bucle puede disparar, síncronamente, la eliminación de una clave que el bucle todavía no visitó.** Bug real jugando: `BoardManager._on_laser_triggered()` recorre `_blocks.keys()` aplicando `take_explosion_damage()` a cada bloque en la línea; si uno de esos bloques es un Frasco de Salsa que muere por ESE MISMO daño, su `_die()` emite `salsa_exploded` ANTES de terminar, y `_on_salsa_exploded()` destruye síncronamente a sus vecinos — si un vecino comparte línea con el láser y el bucle todavía no había llegado a esa clave, la iteración siguiente intenta `_blocks[esa_clave]` sobre una entrada que ya no existe → crash real (no un warning). El bug no aparece probando ninguna de las dos features por separado (láser solo, salsa sola) — solo cuando SE COMBINAN en el mismo turno. `_on_salsa_exploded()` ya tenía el guard correcto (`if _blocks.has(neighbor): ...`) pero `_on_laser_triggered()` (agregado después, mismo patrón de "recorrer `_blocks` y aplicar daño") no lo copió. Regla general: CUALQUIER `for key in dict.keys(): ... dict[key] ...` donde el cuerpo puede destruir entidades del tablero (daño que puede matar, que a su vez puede encadenar más destrucción vía señales) necesita `if not dict.has(key): continue` antes de acceder — el motivo no es "por si acaso", es que ya existe un feature real (salsa) que muta el dict desde dentro del callback de daño. Test de regresión: dos entidades insertadas en un orden específico (la que explota ANTES que su vecino en el dict) para forzar que el bucle intente acceder a una clave ya borrada — un test que solo pruebe "el láser hace daño" o "la salsa explota" por separado no lo detecta.

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

**Totopo Smash** — puzzle/arcade de física de rebotes (brick breaker). Dos modos: **Modo Nivel** (principal — niveles finitos y deterministas, mismo tablero para todos, victoria al despejar todo lo destructible) y **Modo Infinito** (el diseño original: progresión infinita y aleatoria por oleadas, sin condición de victoria, se juega por score).

- **Mecánica core:** arrastrar el dedo para apuntar (cono "hacia arriba", nunca horizontal/abajo) → soltar dispara TODAS las semillas del inventario en ráfaga continua (`SEED_FIRE_INTERVAL = 0.06s` entre disparos) → rebote elástico perfecto (e=1.0) contra paredes/techo/bloques → la primera semilla en tocar el suelo reposiciona el molcajete → al volver la última, el tablero baja 1 fila (en ambos modos) y, solo en Modo Infinito, aparece una fila nueva arriba.
- **Acelerar semillas:** mantener presionada la pantalla fuera de la fase de apuntado multiplica el delta físico de cada semilla por `Constants.SEED_BOOST_MULTIPLIER` (`EventBus.seed_boost_changed`, ver `mortar.gd`/`seed.gd`) — no usa `Engine.time_scale` (aceleraría tweens/timers que deben seguir normales).
- **Derrota (ambos modos):** un bloque toca la fila del molcajete (`Constants.MOLCAJETE_ROW`) al terminar un turno — marcado visualmente por `danger_line.gd` (v2: banda de degradado rojo + chevrones de "cinta de peligro" + línea sólida, todo pulsante vía `_process`/`queue_redraw`, sin collider).
- **Victoria — Modo Nivel:** destruir todos los bloques destructibles (piedra no cuenta) antes de que el tablero llegue a la fila del molcajete. **Modo Infinito:** no existe — se juega por score/oleada máxima (persistidos en `SaveManager`).
- **Controles:** solo `Mortar` (molcajete) escucha input; no hay "Player" que se mueva por drag (a diferencia del template genérico) — el molcajete se reposiciona automáticamente, nunca por el jugador directamente.
- **Escenas jugables:** `MainMenu.tscn` (botones NIVELES / PACKS ESPECIALES / MODO INFINITO / TIENDA / CONFIGURACIÓN) → `LevelSelectScreen.tscn` (Modo Nivel, SOLO roster numérico — los packs se quitaron de aquí, pedido explícito del usuario) o `PackSelectScreen.tscn` → `PackLevelsScreen.tscn` (grilla de un solo pack, siempre desbloqueada, botones anchos de 2 columnas con nombre alineado a la izquierda — buzón `LevelManager.get_pending_pack_prefix()`) → `TutorialGame.tscn` (primera vez, cualquier modo) / `Game.tscn`. `Game.tscn` sirve ambos modos — el modo lo decide `LevelManager.get_pending_level()` (buzón no destructivo) leído en `Game.gd._ready()` justo antes de `GameManager.start_game(level_id)`.
- **Niveles:** `data/levels/*.json` + `data/levels/manifest.json` (orden de juego). Un nivel define su contenido con `cells` (celdas absolutas, visibles desde el inicio), `row_queue` (filas que se revelan de a una por turno, dificultad progresiva) y/o `static: true` (ver abajo) — el nivel normal (no-static) se gana cuando la cola se agota Y no queda ningún destructible. **115 niveles**: 100 numéricos (`tools/gen_levels.py`, objetivo del GDD) — 94 procedurales vía `row_queue`, nivel 1 = 10 filas totales y +3 filas por nivel siguiente hasta un TOPE de 50 filas [`total_rows_for_level()`, alcanzado en el nivel 15], + 6 figuras vía `cells` (Cruz/Corazón/Botella/Estrella/Diamante/Carita Feliz) — más 2 packs temáticos hand-authored con namespace propio (nunca `level_0NN`): `tools/gen_holiday_pack.py` (5 niveles, tipo "bloques descendentes" de baja resolución) y `tools/gen_worldcup_pack.py` (**v3**, 10 niveles tipo "imagen fija" `static`, tamaño proporcional al tablero normal vía `Constants.STATIC_LEVEL_DEFAULT_SUBDIVISION` — balón/trofeo/portería/camiseta/estrella/futbolista/cancha/"GOL"/banderín/medalla — ver abajo). Todo pack nuevo debe declarar explícitamente qué tipo(s) de nivel usa (bloques descendentes vs imagen fija) antes de generar contenido — ver `.claude/skills/level-designer/SKILL.md`. Ampliable con la skill `/level-designer`. **Los packs NUNCA se muestran en `LevelSelectScreen`** (pedido explícito del usuario — antes convivían ahí en una sección aparte "PACKS ESPECIALES" al final del scroll, se quitó por completo) — su único acceso es la **pantalla dedicada** (`PackSelectScreen.tscn` → `PackLevelsScreen.tscn`, botón "PACKS" en `MainMenu`), SIEMPRE desbloqueada sin depender de `highest_level_unlocked` (esa regla es solo para la campaña numérica secuencial).
- **Niveles `static`** (pedido explícito del usuario, "figuras de alta resolución que se aprecien desde el inicio, cuadros más pequeños") — grilla PROPIA por nivel vía `grid_cols` (mucho más angosta que `Constants.GRID_COLS=7` → más bloques, más chicos, en el mismo ancho de pantalla), los bloques NUNCA se desplazan y NO hay condición de derrota (`BoardManager` se salta `_shift_down()`/`_check_game_over()` para estos niveles; `danger_line.gd` se oculta). Se gana despejando todo lo destructible sin importar los turnos. `par_turns` (opcional) habilita un bono ×`Constants.STATIC_LEVEL_PAR_BONUS_MULTIPLIER` al score final si se limpia rápido. Ver `src/features/levels/level_loader.gd` (validación), `src/features/board/board_manager.gd::_spawn_static_cell()` (grilla propia), `src/core/GameManager.gd::_apply_par_turns_bonus()`.
- **Power-up láser** (`laser_icon.gd`, pedido explícito del usuario) — PERSISTENTE (nunca se libera solo, se dispara de nuevo en cada toque). Al tocarlo dispara `Constants.LASER_DAMAGE=1` (un punto por toque, no un golpe grande — pedido explícito del usuario) a TODA la fila, columna, o AMBAS (`orientation: "horizontal"/"vertical"/"both"`) donde está, vía `EventBus.laser_triggered` → `BoardManager._on_laser_triggered()` (mismo patrón que la explosión de la salsa, pero en línea recta). VFX: partículas magenta en el origen + un rayo real (`laser_beam.gd`) que recorre toda la fila/columna afectada (pedido explícito del usuario, antes solo un destello puntual) + SFX (`laser_zap.wav`) en cada toque. Kind `"laser"` en `cell_factory.gd`/`wave_scaling.gd`, CON probabilidad de spawn en fila normal (`Constants.ROW_LASER_CHANCE`, Modo Infinito) y en `row_queue` procedural (`tools/gen_levels.py::LASER_CHANCE`, Modo Nivel) — pedido explícito del usuario, además de los niveles `static` autorados. Nunca cuenta para perder (`_check_game_over()` solo mira `_blocks`, nunca `_icons`) y desaparece sin más efecto si cruza `Constants.MOLCAJETE_ROW` al desplazarse (`board_manager.gd::_shift_down()`).
- **HP con font_size escalado + oculto en bloques muy chicos** (`block_base.gd`) — el label de HP escala su `font_size` con `_cell_size * Constants.UI_HP_FONT_SIZE_RATIO` (capado por `UI_MIN_FONT_SIZE=18`, piso `UI_HP_FONT_MIN_SIZE=8`; un `font_size` fijo desbordaba visualmente los cuadros en niveles `static`, bug real reportado jugando) y se oculta por completo por debajo de `Constants.UI_MIN_READABLE_CELL_SIZE=15.0` (niveles de altísima resolución, ej. el texto "GOL") — sin tocar nada más.
- **HP por bloque en Modo Nivel escala con el NÚMERO DE NIVEL** (no con `effective_wave`, que solo gobierna qué tipos de bloque aparecen): nivel 1 va de 10 a 50 golpes, nivel 100 de 60 a 300, sin tope superior — **CADA bloque sortea su propio HP dentro de ese rango** (nunca el mismo valor fijo para todos los bloques del nivel), determinista vía la seed fija del nivel — ver `tools/gen_levels.py::random_totopo_hp()`/`totopo_hp_max_for_level()`/`totopo_hp_min_for_level()`. `starting_seeds_for_level()` escala en la misma proporción para compensar.
- **Sistema de mejoras/oro/personajes** (`MetaManager`, autoload separado de `SaveManager` — persiste en `user://meta.json`): oro ganado al terminar cualquier run/nivel (`Constants.GOLD_PER_SCORE_POINT` × score), 3 mejoras permanentes compradas con oro (Semillas Extra / Daño Base / Velocidad, 5 niveles cada una, ver `src/features/meta/upgrade_shop.gd` para costos/bonos puros) aplicadas en `TurnManager`/`block_base.gd`, y 4 personajes cosméticos (tinte de color del molcajete vía `modulate`, sin efecto en gameplay) desbloqueables/seleccionables desde `UpgradeShopScreen.tscn` (accesible desde `MainMenu`, botón TIENDA).
- **Multi-idioma:** es/en/pt_BR/fr vía `/mobile-i18n` — `LocalizationManager` + `assets/translations/translations.txt`. `MainMenu` redirige a `LanguageSelectScreen` en la primera ejecución.
- **Assets:** bloques (totopo/queso con cara, salsa/piedra sin cara) + molcajete generados con IA (Pollinations.ai, 512px→`LANCZOS` al tamaño real — ver `tools/fetch_ai_assets.py`) + semilla procedural (la IA no dio buen resultado a 16px) + íconos de power-up procedurales (`tools/gen_assets.py`, incluye 2 variantes de láser por orientación) + fondo de menú por IA + SFX y música de fondo reales (`.wav` sintetizado, `AudioManager`, loop a -8dB). Ver sección "Pulido de assets" en `idea-base.md`.
- **Build:** `gdlint` 0 errores · GUT 223/223 tests (correr SIEMPRE vía `./tools/run_tests.sh`, no invocar GUT directo — ver sección "Desbloqueo secuencial..." en `idea-base.md`) · `--export-debug Android` genera APK válido · `deploy-playstore.yml` probado (subió a Play Store Internal Testing).

### Señales clave en EventBus

| Señal | Emisor | Receptores |
|---|---|---|
| `game_started` | `GameManager.start_game()` | `BoardManager`, `TurnManager` (reset de estado) |
| `game_over(score, wave)` | `GameManager` (vía `board_reached_bottom`) | `GameOverScreen`, `Game.gd` |
| `game_paused` / `game_resumed` | `GameManager.pause_game()/resume_game()` | `PauseScreen` (show/hide) |
| `wave_advanced(wave_number)` | `BoardManager` (Modo Infinito: fila inicial y cada avance; nunca en Modo Nivel) | `GameManager` (bono de score), `HUD` |
| `turn_advanced` | `BoardManager` (ambos modos, cuando el turno termina sin game over ni nivel ganado — ver regla #50) | `TurnManager` (guard ADVANCING→AIMING) |
| `turn_phase_changed(phase)` | `TurnManager._set_phase()` | `Mortar` (gatea el input de apuntado) |
| `aim_updated` / `aim_cancelled` | `Mortar` | (feedback visual propio) |
| `fire_requested(direction, origin)` | `Mortar` al soltar el dedo | `TurnManager` (inicia la ráfaga) |
| `recall_all_seeds_requested` | `HUD` (botón ">>", visible solo en FIRING/RESOLVING/RETURNING) | `TurnManager` (cancela la ráfaga pendiente y fuerza `Seed.force_land()` en todas las semillas activas — mismo camino que un aterrizaje natural, incluye el chequeo de nivel despejado en `BoardManager`) |
| `burst_fired(seed_count)` | `TurnManager` | `HUD` / tutorial |
| `all_seeds_returned(landing_x)` | `TurnManager` (última semilla aterriza) | `BoardManager` (avanza el tablero) |
| `molcajete_position_changed(x)` | `TurnManager` (posición de la PRIMERA semilla en aterrizar, pero emitida recién cuando ya NO queda ninguna semilla activa — bug real corregido: moverlo antes se veía raro con semillas todavía rebotando) | `Mortar` (tween a la nueva posición) |
| `seed_count_changed(n)` | `TurnManager` | `HUD` |
| `block_damaged(pos, hp, max_hp)` | `block_base._apply_damage()` | (feedback visual propio del bloque) |
| `block_destroyed(pos, type, score)` | `block_base._die()` | `GameManager` (score), `BoardManager` (borra de la grilla), `VFXSpawner`, `HapticManager` |
| `salsa_exploded(pos)` | `salsa_jar_block._die()` | `BoardManager` (destruye los 8 bloques alrededor vía `destroy_instantly()`, excepto piedra/power-ups — GDD actualizado), `VFXSpawner`, `HapticManager` |
| `laser_triggered(grid_pos, is_horizontal)` | `laser_icon.gd` al ser tocado | `BoardManager` (daño en línea recta, fila u columna completa) |
| `board_reached_bottom` | `BoardManager` (game over) | `GameManager` |
| `seed_bounced(block_type)` | `Seed._handle_collision()` en cada rebote | `AudioManager` (tono de rebote o crunch/thud según el material) |
| `lemon_triggered` / `seed_extra_touched(origin, amount)` / `seed_extra_collected` | `LemonIcon` / `SeedExtraIcon` (`amount` por ícono, default `Constants.SEED_EXTRA_AMOUNT`, overridable por celda vía `"amount"` en el JSON) / `TurnManager` | `TurnManager` (split real vía señal privada `Seed.split_requested`, no EventBus) / `HUD` |
| `score_changed` / `high_score_updated` | `GameManager` | `HUD` / `GameOverScreen` |
| `level_cleared(level_id, turns_used)` | `BoardManager` (sin destructibles + Modo Nivel; `turns_used` > 0 solo en niveles `static`) | `GameManager` (persiste desbloqueo, bono `par_turns` si aplica, emite `level_completed`) |
| `level_completed(level_id, score)` | `GameManager` | `LevelCompleteScreen` |
| `seed_boost_changed(active)` | `Mortar` fuera de AIMING (mantener presionado) | `Seed` (multiplica su delta efectivo) |
| `gold_changed(new_total)` | `GameManager` (fin de run/nivel) / `UpgradeShopScreen` (compra) | `MainMenu`, `UpgradeShopScreen` |
| `upgrade_purchased(upgrade_id, new_level)` | `UpgradeShopScreen` | (feedback visual propio de la tienda) |
| `character_selected(character_id)` | `UpgradeShopScreen` | (feedback visual propio de la tienda) |

### Referencia Rápida del GDD

- **Molcajete:** 10 semillas iniciales, velocidad 640px/s, ráfaga cada 0.06s, cono de apuntado ±15° respecto a la horizontal.
- **Totopo:** HP central `= oleada`. **Queso:** HP central `= ceil(oleada * 1.5)`, daño x2, -15% velocidad de semilla al rebotar (piso `SEED_MIN_SPEED_RATIO = 0.35`). Modo Infinito ya NO usa ese HP central como valor fijo para todos los bloques de la fila — cada bloque lo sortea dentro de un rango que se ensancha por oleada (`WaveScalingGd.random_hp_for_wave()`, pedido explícito del usuario, ver regla de sesión en "Estado Actual del Juego"). **Salsa:** al morir, DESTRUYE (no daña) los 8 bloques pegados alrededor — cruz + diagonales (GDD actualizado, pedido explícito del usuario) — excepto piedra (exenta vía `is_indestructible`) y power-ups (viven en `_icons`, un Dictionary aparte que la explosión ni recorre). **Piedra:** indestructible. Modo Nivel usa su propia escala VARIADA por NÚMERO DE NIVEL, ver `tools/gen_levels.py::random_totopo_hp()`.
- **Oleadas:** 1–5 introducción (solo totopo) · 6–15 geometría (triángulo + queso + salsa) · 16–30 piedra · 31+ espaciado ajustado.
- **Grid:** 7 columnas × 10 filas (`Constants.GRID_COLS/GRID_ROWS`, era 9 filas — bajado 1 por feedback de playtesting: "la línea roja está muy arriba", seguro en cualquier resolución porque el diseño usa lienzo virtual fijo con `stretch/mode=canvas_items`+`aspect=keep`), diseño base 390×844.
- **Metagame de oro/mejoras/personajes** — pedido explícito del usuario, agregado en esta sesión (no estaba en el GDD original). Ver `MetaManager`/`src/features/meta/upgrade_shop.gd` y la sección "Estado Actual del Juego" arriba.

### Autoloads registrados en project.godot

| Nombre | Archivo | Rol |
|---|---|---|
| `Constants` | `src/core/Constants.gd` | Constantes tipadas (GDD como fuente de verdad) |
| `EventBus` | `src/core/EventBus.gd` | Bus de señales cross-feature |
| `GameManager` | `src/core/GameManager.gd` | Estados `MENU/PLAYING/PAUSED/GAME_OVER/LEVEL_COMPLETE`, score, oleada/nivel activo, pausa real del `SceneTree` |
| `SaveManager` | `src/core/SaveManager.gd` | Persistencia `user://save.json` (settings, tutorial, score/oleada, nivel desbloqueado) |
| `MetaManager` | `src/core/MetaManager.gd` | Persistencia `user://meta.json` — oro, mejoras permanentes, personajes (separado de SaveManager por el límite de 20 métodos públicos de gdlint + responsabilidad propia) |
| `LevelManager` | `src/core/LevelManager.gd` | Cache de niveles cargados, buzón de nivel pendiente (no destructivo), manifiesto, progreso de desbloqueo por pack (`user://pack_progress.json`) |
| `LocalizationManager` | `src/core/LocalizationManager.gd` | Carga `translations.txt`, aplica locale (es/en/pt_BR/fr) |
| `AudioManager` | `src/features/audio/AudioManager.gd` | SFX + música de fondo en loop (arranca sola en `_ready()`, no crashea sin `.ogg`); dueña de sus propias preferencias música/SFX independientes (`user://audio_settings.json` — pedido explícito del usuario, no vive en SaveManager por el límite de 20 métodos públicos de gdlint) |
| `HapticManager` | `src/features/audio/HapticManager.gd` | Vibración sutil solo en destrucción/explosión |

### Skills y Agentes Disponibles

Del template (`/gen-ai-art`, `/mobile-i18n`, `/feature`, `/android-deploy`, `/new-game`, `/doc`, `/validate`) + agentes `game-designer`, `game-feel`, `godot-architect`, `godot-qa` + **`/level-designer`** (propia de Totopo Smash — diseña niveles nuevos en lenguaje natural, ver `.claude/skills/level-designer/SKILL.md`).

### Pendientes Documentados

Ver sección **Pendientes** en `idea-base.md` (assets visuales/SFX reales, CI/CD con credenciales reales, balance fino de probabilidades de spawn). Resumen: el juego es 100% jugable y testeado, pero 100% procedural (sin arte/audio finales) y sin pipeline de publicación configurado con secrets reales.
