extends Control
## Grilla de niveles de UN pack temático específico (ver PackSelectScreen). El prefijo
## viene del buzón no destructivo LevelManager.get_pending_pack_prefix() — mismo patrón
## que LevelManager.get_pending_level() para Modo Nivel. Todos los niveles de un pack
## están SIEMPRE desbloqueados (son contenido opcional/bonus, no la campaña numérica).

const GAME_SCENE: String = "res://src/scenes/Game.tscn"
const TUTORIAL_SCENE: String = "res://src/scenes/TutorialGame.tscn"
const PACK_SELECT_SCENE: String = "res://src/scenes/PackSelectScreen.tscn"

const COLUMNS: int = 4
const BUTTON_SIZE: float = 64.0
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

	var grid_w: float = COLUMNS * BUTTON_SIZE + (COLUMNS - 1) * BUTTON_GAP
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

	for i: int in manifest.size():
		var level_id: String = manifest[i]
		if not (level_id as String).begins_with(prefix + "_"):
			continue
		var btn: Button = Button.new()
		btn.text = str(i + 1)
		btn.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
		btn.pressed.connect(_on_level_pressed.bind(level_id))
		grid.add_child(btn)


func _on_level_pressed(level_id: String) -> void:
	LevelManager.set_pending_level(level_id)
	var dest: String = GAME_SCENE if SaveManager.get_tutorial_shown() else TUTORIAL_SCENE
	get_tree().change_scene_to_file.call_deferred(dest)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file.call_deferred(PACK_SELECT_SCENE)
