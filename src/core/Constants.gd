extends Node
## Constantes tipadas de Totopo Smash. Autoload PRIMERO — todo lo demás depende de esto.
## Fuente de verdad: totopo-smash-gdd.md

# --- Capas de física (deben coincidir con [layer_names] en project.godot) ---
const LAYER_WORLD: int = 1  ## paredes, techo, piso
const LAYER_BLOCKS: int = 2
const LAYER_MOLCAJETE: int = 4
const LAYER_SEEDS: int = 8
const LAYER_PICKUPS: int = 16  ## íconos: limón, semilla extra

# --- Grid del tablero (GDD sección 2, "Game Over") ---
const GRID_COLS: int = 7
const GRID_ROWS: int = 9
const MOLCAJETE_ROW: int = GRID_ROWS - 1  ## fila del molcajete; bloque aquí = game over

# --- Geometría / layout (390x844 portrait, debe calzar con project.godot [display]) ---
const DESIGN_WIDTH: float = 390.0
const DESIGN_HEIGHT: float = 844.0
const BOARD_TOP_MARGIN: float = 96.0
const MOLCAJETE_BOTTOM_MARGIN: float = 72.0

# --- Molcajete ---
const MOLCAJETE_START_SEEDS: int = 10
const MOLCAJETE_START_X_RATIO: float = 0.5  ## centrado antes de que caiga la 1ra semilla
const MOLCAJETE_MOVE_DURATION: float = 0.22
const MOLCAJETE_SPRITE_RADIUS: float = 26.0
const MORTAR_AIM_MARGIN_DEG: float = 15.0  ## cono de apuntado: nunca horizontal/abajo
const AIM_PREVIEW_LENGTH: float = 260.0  ## largo del primer tramo si no golpea nada
const AIM_BOUNCE_PREVIEW_LENGTH: float = 90.0  ## largo del tramo tras el primer rebote
const AIM_DOT_SPACING: float = 14.0
const AIM_DOT_RADIUS: float = 2.5

# --- Semillas ---
const SEED_SPEED: float = 640.0
const SEED_RADIUS: float = 7.0
const SEED_FIRE_INTERVAL: float = 0.06  ## separación entre disparos de la ráfaga (no todas juntas)
const SEED_MAX_BOUNCES_SAFETY: int = 600  ## failsafe: fuerza retorno si se cuelga rebotando
const SEED_QUESO_SLOWDOWN_RATIO: float = 0.85  ## -15% velocidad al rebotar en queso
const SEED_MIN_SPEED_RATIO: float = 0.35  ## piso de velocidad tras varios rebotes en queso
const LEMON_SPLIT_ANGLE_DEG: float = 20.0  ## separación de cada rama respecto al rumbo original
const SEED_BOOST_MULTIPLIER: float = 2.0  ## acelerar semillas: mantener presionado fuera de AIMING

# --- Bloques: vida y daño (GDD sección 3 y 4.1) ---
const BLOCK_NORMAL_DAMAGE_PER_HIT: int = 1
const BLOCK_QUESO_DAMAGE_PER_HIT: int = 2  ## "absorbe el doble de daño por impacto"
## Ya no se usa un valor de daño fijo para la salsa (GDD actualizado, pedido explícito del
## usuario: destrucción instantánea de todo lo pegado alrededor, no daño parcial en cruz —
## ver block_base.gd::destroy_instantly()/board_manager.gd::_on_salsa_exploded()).
const BLOCK_SALSA_WARNING_HP: int = 1  ## HP en el que empieza a parpadear antes de estallar
const WAVE_TOTOPO_HP_MULTIPLIER: float = 1.0  ## N = O
const WAVE_QUESO_HP_MULTIPLIER: float = 1.5  ## N = ceil(O * 1.5)
const LASER_DAMAGE: int = 25  ## power-up láser: daño a TODA la fila/columna al tocarlo

# --- Introducción de complejidad por oleada (GDD sección 4.2) ---
const WAVE_INTRO_END: int = 5  ## 1-5: solo totopos, vida 1-5
const WAVE_GEOMETRY_START: int = 6  ## 6-15: triángulos + primeros quesos
const WAVE_GEOMETRY_END: int = 15
const WAVE_STATIC_OBSTACLES_START: int = 16  ## 16-30: piedra de molcajete indestructible
const WAVE_STATIC_OBSTACLES_END: int = 30
const WAVE_TIGHT_SPACING_START: int = 31  ## 31+: menos huecos libres

# --- Spawn de fila: probabilidades por celda (documentado, ajustable) ---
const ROW_EMPTY_CHANCE_EARLY: float = 0.30  ## oleadas 1-5
const ROW_EMPTY_CHANCE_MID: float = 0.20  ## oleadas 6-30
const ROW_EMPTY_CHANCE_LATE: float = 0.08  ## oleadas 31+ ("estrangulamiento del espacio")
const ROW_SEED_EXTRA_CHANCE_EARLY: float = 0.22  ## "abundantes íconos de semilla extra"
const ROW_SEED_EXTRA_CHANCE_LATE: float = 0.05
const ROW_LEMON_CHANCE: float = 0.05
const ROW_TRIANGLE_CHANCE: float = 0.18  ## dentro del rango de oleadas 6+
const ROW_QUESO_CHANCE: float = 0.18  ## dentro del rango de oleadas 6+
const ROW_STONE_CHANCE: float = 0.10  ## dentro del rango de oleadas 16+

# --- Power-ups en tablero ---
const SEED_EXTRA_AMOUNT: int = 1

# --- Score ---
const SCORE_PER_DAMAGE_POINT: int = 10
const SCORE_PER_WAVE_CLEARED: int = 50

# --- Feedback háptico (GDD sección 5 — sutil, solo en destrucción/explosión) ---
const HAPTIC_BLOCK_DESTROYED_MS: int = 15
const HAPTIC_SALSA_EXPLOSION_MS: int = 30

# --- UI / Colores (GDD sección 5) ---
const COLOR_BG_BOARD: Color = Color(0.086, 0.106, 0.145)  ## azul noche / gris pizarra
const COLOR_TOTOPO: Color = Color(0.976, 0.663, 0.157)  ## amarillo/naranja crujiente
const COLOR_QUESO: Color = Color(0.949, 0.878, 0.663)  ## amarillo pastel viscoso
const COLOR_SALSA: Color = Color(0.831, 0.129, 0.129)  ## rojo brillante
const COLOR_STONE: Color = Color(0.42, 0.42, 0.45)  ## piedra de molcajete
const COLOR_LEMON: Color = Color(0.667, 0.925, 0.239)  ## verde brillante
const COLOR_SEED_EXTRA: Color = Color(1.0, 0.878, 0.313)  ## semilla brillante
const COLOR_LASER: Color = Color(0.9, 0.15, 0.85)  ## magenta — power-up láser
const COLOR_SEED_TRAIL: Color = Color(0.31, 0.86, 0.44)  ## semillas verdes
const COLOR_MOLCAJETE: Color = Color(0.35, 0.24, 0.16)  ## piedra volcánica
const COLOR_HUD_TEXT: Color = Color(0.95, 0.95, 0.95)
const COLOR_AIM_GUIDE: Color = Color(1.0, 1.0, 1.0, 0.55)
const COLOR_DANGER_LINE: Color = Color(0.9, 0.2, 0.2, 0.8)  ## línea de la fila del molcajete

# --- UI: tamaños mínimos ---
const UI_MIN_FONT_SIZE: int = 18
## El label de HP escala su font_size con `_cell_size * UI_HP_FONT_SIZE_RATIO` (capado por
## UI_MIN_FONT_SIZE arriba, piso UI_HP_FONT_MIN_SIZE abajo) — un font_size FIJO (bug real
## reportado jugando: en niveles `static`, con celdas de ~20-30px, un HP de 3 dígitos a
## font_size 18 desbordaba visualmente el cuadro, porque 18px fijo solo entra bien al
## tamaño de celda del tablero normal ~56px) solo funciona bien a un tamaño; cualquier
## bloque más chico necesita un número más chico también.
## Por debajo de esto, el número de HP de un bloque se oculta por completo (niveles
## `static` de muy alta resolución, ej. el texto "GOL") — con el font_size ya escalado
## (piso UI_HP_FONT_MIN_SIZE=8) un HP de 3 dígitos todavía entra en una celda de ~15px;
## bajado de 20.0 a 15.0 tras el fix de escalado de fuente (antes ocultaba de más, sin
## necesidad, niveles que con el número ya chico se leían perfectamente bien).
const UI_MIN_READABLE_CELL_SIZE: float = 15.0
const UI_HP_FONT_SIZE_RATIO: float = 0.4
const UI_HP_FONT_MIN_SIZE: int = 8

# --- VFX (migajas / salpicadura, sin assets — GPUParticles2D procedural) ---
const VFX_CRUMB_AMOUNT: int = 14
const VFX_CRUMB_LIFETIME: float = 0.5
const VFX_SAUCE_AMOUNT: int = 24
const VFX_SAUCE_LIFETIME: float = 0.6

# --- Mejoras permanentes (oro) — ver src/features/meta/upgrade_shop.gd ---
const GOLD_PER_SCORE_POINT: float = 0.05  ## oro ganado = score * esto, al terminar la run
const UPGRADE_MAX_LEVEL: int = 5
const UPGRADE_BASE_COST: int = 50  ## costo del nivel 1 de cualquier mejora
const UPGRADE_COST_STEP: int = 40  ## incremento de costo por cada nivel adicional
const UPGRADE_SEEDS_BONUS_PER_LEVEL: int = 2  ## +2 semillas iniciales por nivel comprado
const UPGRADE_DAMAGE_BONUS_PER_LEVEL: float = 0.08  ## +8% daño por nivel comprado
const UPGRADE_SPEED_BONUS_PER_LEVEL: float = 0.04  ## +4% velocidad de semilla por nivel comprado

# --- Personajes (skins cosméticas del molcajete, oro — sin efecto en gameplay) ---
const CHARACTER_DEFAULT_ID: String = "classic"
const CHARACTERS: Array = [
	{"id": "classic", "name_key": "CHARACTER_CLASSIC", "color": Color(1.0, 1.0, 1.0), "cost": 0},
	{
		"id": "turquoise", "name_key": "CHARACTER_TURQUOISE",
		"color": Color(0.16, 0.62, 0.60), "cost": 200,
	},
	{"id": "pink", "name_key": "CHARACTER_PINK", "color": Color(0.86, 0.27, 0.55), "cost": 350},
	{"id": "gold", "name_key": "CHARACTER_GOLD", "color": Color(0.83, 0.68, 0.21), "cost": 500},
]

# --- Niveles "static" (figuras de alta resolución, sin condición de derrota — ver
# BoardManager/level_loader.gd) ---
const STATIC_LEVEL_PAR_BONUS_MULTIPLIER: float = 1.5  ## ×score si se limpia en <= par_turns
## Espacio reservado ABAJO para que la figura nunca se dibuje encima del molcajete (bug
## real: un nivel `static` muy alto tapaba visualmente el molcajete). BoardManager calcula
## el cell_size más grande que quepa en ancho Y alto dentro de esta área, así que ningún
## nivel puede violar esto sin importar qué grid_cols/grid_rows pida.
const STATIC_LEVEL_BOTTOM_MARGIN: float = 144.0
## Tamaño de una celda del tablero NORMAL (7 columnas) — referencia para que el tamaño de
## celda de un nivel `static` sea "proporcional" (pedido explícito del usuario): dividir
## una celda normal en NxN sub-celdas da grid_cols = GRID_COLS * N. N=2 (celdas a la mitad
## de tamaño, 14 columnas) es el default recomendado — suficiente detalle sin saturar.
const STATIC_LEVEL_DEFAULT_SUBDIVISION: int = 2

# --- Packs temáticos de niveles (ver PackSelectScreen/PackLevelsScreen/LevelSelectScreen) ---
## Registro central de packs — un nivel nuevo agregado por /level-designer con un prefijo
## de id nuevo (ej. "easter_001") necesita una entrada nueva aquí para aparecer en
## PackSelectScreen; si no, sigue siendo jugable (visible en la sección "PACKS ESPECIALES"
## de LevelSelectScreen, que detecta packs solo por prefijo != "level_"), simplemente no
## sale en la lista dedicada de packs hasta que se registre acá.
const LEVEL_PACKS: Array = [
	{"prefix": "holiday", "name_key": "PACK_HOLIDAY_NAME"},
	{"prefix": "worldcup", "name_key": "PACK_WORLDCUP_NAME"},
]
