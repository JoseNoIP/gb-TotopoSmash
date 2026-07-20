extends Control
## Grilla de niveles de UN pack temático específico (ver PackSelectScreen). El prefijo
## viene del buzón no destructivo LevelManager.get_pending_pack_prefix() — mismo patrón
## que LevelManager.get_pending_level() para Modo Nivel.
##
## Desbloqueo SECUENCIAL dentro del pack (pedido explícito del usuario tras jugar: "todos
## los niveles me aparecen habilitados desde el inicio... solo se deben ir habilitando
## conforme vaya pasando los diferentes niveles, pero sí debo poder volver a jugar niveles
## ya completados") — mismo criterio que LevelSelectScreen para el roster numérico, pero
## con su propio contador vía LevelManager.get_pack_highest_unlocked(prefix), independiente
## por pack (terminar el pack navideño no afecta el desbloqueo del pack Mundial).

const GAME_SCENE: String = "res://src/scenes/Game.tscn"
const TUTORIAL_SCENE: String = "res://src/scenes/TutorialGame.tscn"
const PACK_SELECT_SCENE: String = "res://src/scenes/PackSelectScreen.tscn"

## 2 columnas de botones anchos (en vez de 4 cuadrados) — hace falta el espacio extra para
## mostrar el nombre del nivel además del número (pedido explícito del usuario: ayuda a
## saber qué representa la figura antes de entrar a jugarla, ej. "3. Copa").
const COLUMNS: int = 2
const BUTTON_WIDTH: float = 172.0
const BUTTON_HEIGHT: float = 56.0
const BUTTON_GAP: float = 14.0


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	position = Vector2.ZERO
	set_size(Vector2(Constants.DESIGN_WIDTH, Constants.DESIGN_HEIGHT))

	var bg: ColorRect = ColorRect.new()
	bg.color = Constants.COLOR_BG_BOARD
	bg.position = Vector2.ZERO
	bg.set_size(Vector2(Constants.DESIGN_WIDTH, Constants.DESIGN_HEIGHT))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var prefix: String = LevelManager.get_pending_pack_prefix()
	var pack: Dictionary = _find_pack(prefix)

	var title: Label = Label.new()
	title.text = tr(pack.get("name_key", "") as String) if not pack.is_empty() else ""
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 26)
	title.add_theme_color_override(&"font_color", Constants.COLOR_TOTOPO)
	title.position = Vector2(0.0, 60.0)
	title.set_size(Vector2(Constants.DESIGN_WIDTH, 44.0))
	add_child(title)

	_build_grid(prefix)

	var back_btn: Button = Button.new()
	back_btn.text = "BTN_BACK"
	back_btn.custom_minimum_size = Vector2(160.0, 48.0)
	back_btn.position = Vector2((Constants.DESIGN_WIDTH - 160.0) * 0.5, Constants.DESIGN_HEIGHT - 96.0)
	back_btn.pressed.connect(_on_back_pressed)
	add_child(back_btn)


func _find_pack(prefix: String) -> Dictionary:
	for pack: Dictionary in Constants.LEVEL_PACKS:
		if pack.get("prefix") == prefix:
			return pack
	return {}


## Mismo patrón de centrado que LevelSelectScreen (regla CLAUDE.md #49: un Container
## ignora `position` puesto a mano en sus hijos directos, así que el que se centra es el
## ScrollContainer, con el ancho exacto del contenido).
func _build_grid(prefix: String) -> void:
	var manifest: Array = LevelManager.get_manifest()

	var grid_w: float = COLUMNS * BUTTON_WIDTH + (COLUMNS - 1) * BUTTON_GAP
	var origin_x: float = (Constants.DESIGN_WIDTH - grid_w) * 0.5
	var origin_y: float = 140.0

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(origin_x, origin_y)
	scroll.set_size(Vector2(grid_w, Constants.DESIGN_HEIGHT - origin_y - 120.0))
	add_child(scroll)

	var grid: GridContainer = GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override(&"h_separation", int(BUTTON_GAP))
	grid.add_theme_constant_override(&"v_separation", int(BUTTON_GAP))
	scroll.add_child(grid)

	var highest_unlocked: int = LevelManager.get_pack_highest_unlocked(prefix)
	var position_in_pack: int = 0
	for i: int in manifest.size():
		var level_id: String = manifest[i]
		if not (level_id as String).begins_with(prefix + "_"):
			continue
		position_in_pack += 1
		var btn: Button = Button.new()
		## Centrado (default) hacía que el texto de cada botón arrancara en una columna X
		## distinta según su largo — se veía "desordenado" al leer varios de corrido
		## (reportado directo por el usuario). Alineado a la izquierda; el espacio inicial
		## es el margen visual respecto al borde del botón (sin tocar el StyleBox del tema,
		## que ya trae su propio look de fondo/borde/hover — pisarlo con un StyleBox propio
		## rompería esos estados visuales sin necesidad).
		btn.text = "  " + _level_button_text(level_id, position_in_pack)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
		if position_in_pack <= highest_unlocked:
			btn.pressed.connect(_on_level_pressed.bind(level_id))
		else:
			btn.disabled = true
		grid.add_child(btn)


## El nombre (ej. "Copa") ayuda a relacionar la figura abstracta con lo que representa
## antes de siquiera entrar a jugarla — mismo objetivo que el label del HUD en partida.
func _level_button_text(level_id: String, position_in_pack: int) -> String:
	var name_key: Variant = LevelManager.get_level_data(level_id).get("name")
	if name_key is String and not (name_key as String).is_empty():
		return "%d. %s" % [position_in_pack, tr(name_key as String)]
	return str(position_in_pack)


func _on_level_pressed(level_id: String) -> void:
	LevelManager.set_pending_level(level_id)
	var dest: String = GAME_SCENE if SaveManager.get_tutorial_shown() else TUTORIAL_SCENE
	get_tree().change_scene_to_file.call_deferred(dest)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file.call_deferred(PACK_SELECT_SCENE)
