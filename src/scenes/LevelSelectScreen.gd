extends Control
## Selección de nivel (Modo Nivel — ver LevelManager/level_loader.gd). Grilla de botones
## a partir del manifiesto; bloqueados más allá de SaveManager.get_highest_level_unlocked().
## Elegir un nivel SÍ respeta el gate de tutorial (igual que "JUGAR" en MainMenu.gd) —
## entrar a esta pantalla no, por eso MainMenu no la gatea.

const GAME_SCENE: String = "res://src/scenes/Game.tscn"
const TUTORIAL_SCENE: String = "res://src/scenes/TutorialGame.tscn"
const MAIN_MENU_SCENE: String = "res://src/scenes/MainMenu.tscn"

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

	var title: Label = Label.new()
	title.text = "TITLE_LEVEL_SELECT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 26)
	title.add_theme_color_override(&"font_color", Constants.COLOR_TOTOPO)
	title.position = Vector2(0.0, 60.0)
	title.set_size(Vector2(Constants.DESIGN_WIDTH, 44.0))
	add_child(title)

	_build_grid()

	var back_btn: Button = Button.new()
	back_btn.text = "BTN_BACK"
	back_btn.custom_minimum_size = Vector2(160.0, 48.0)
	back_btn.position = Vector2((Constants.DESIGN_WIDTH - 160.0) * 0.5, Constants.DESIGN_HEIGHT - 96.0)
	back_btn.pressed.connect(_on_back_pressed)
	add_child(back_btn)


## Los ids del roster numérico principal SIEMPRE empiezan con "level_"; cualquier otro
## prefijo ("holiday_"/"worldcup_"/lo que traiga una skill futura) es un pack temático —
## ver .claude/skills/level-designer/SKILL.md, PASO 4 "convención de ids para packs".
func _is_pack_level(level_id: String) -> bool:
	return not level_id.begins_with("level_")


## Los packs temáticos (holiday_00N/worldcup_00N) NO se muestran aquí — pedido explícito
## del usuario: esta pantalla es solo el roster numérico secuencial; los packs tienen su
## propia pantalla dedicada (`PackSelectScreen` -> `PackLevelsScreen`, botón "PACKS" en
## MainMenu). Antes convivían en una sección aparte ("PACKS ESPECIALES") al final del
## scroll — se quitó por completo, no solo se dejó de resaltar.
func _build_grid() -> void:
	var manifest: Array = LevelManager.get_manifest()
	var highest_unlocked: int = SaveManager.get_highest_level_unlocked()

	var grid_w: float = COLUMNS * BUTTON_SIZE + (COLUMNS - 1) * BUTTON_GAP
	var origin_x: float = (Constants.DESIGN_WIDTH - grid_w) * 0.5
	var origin_y: float = 140.0

	## El ScrollContainer (Container) reposiciona a sus hijos por su cuenta en cada sort —
	## un `grid.position` puesto a mano ahí queda ignorado (regla CLAUDE.md #49, mismo
	## principio que #32 pero para Container en vez de anchors). Para centrar el contenido,
	## el que se centra es el propio ScrollContainer (hijo de este Control plano, donde
	## position/set_size sí se respetan) con el ancho exacto del contenido — no hace falta
	## scroll horizontal porque nunca hay overflow en X.
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
		if _is_pack_level(level_id):
			continue
		var level_number: int = i + 1
		_build_level_button(grid, level_id, level_number, level_number <= highest_unlocked)


func _build_level_button(
	grid: GridContainer, level_id: String, level_number: int, unlocked: bool
) -> void:
	var btn: Button = Button.new()
	btn.text = str(level_number)
	btn.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	if unlocked:
		btn.pressed.connect(_on_level_pressed.bind(level_id))
	else:
		btn.disabled = true
	grid.add_child(btn)


func _on_level_pressed(level_id: String) -> void:
	LevelManager.set_pending_level(level_id)
	var dest: String = GAME_SCENE if SaveManager.get_tutorial_shown() else TUTORIAL_SCENE
	get_tree().change_scene_to_file.call_deferred(dest)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file.call_deferred(MAIN_MENU_SCENE)
