extends Control
## Lista los packs temáticos de niveles disponibles (Constants.LEVEL_PACKS) — pantalla
## nueva para que sean descubribles desde el menú principal. Bug real reportado por el
## usuario: los packs solo eran visibles haciendo scroll hasta el final de los 100 niveles
## numéricos en LevelSelectScreen, "no intuitivo". Tocar un pack lleva a
## PackLevelsScreen.tscn con solo los niveles de ESE pack (buzón no destructivo, mismo
## patrón que LevelManager.get_pending_level()).

const MAIN_MENU_SCENE: String = "res://src/scenes/MainMenu.tscn"
const PACK_LEVELS_SCENE: String = "res://src/scenes/PackLevelsScreen.tscn"

const CARD_WIDTH: float = 280.0
const CARD_HEIGHT: float = 64.0
const CARD_GAP: float = 16.0


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
	title.text = "TITLE_PACK_SELECT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 26)
	title.add_theme_color_override(&"font_color", Constants.COLOR_TOTOPO)
	title.position = Vector2(0.0, 60.0)
	title.set_size(Vector2(Constants.DESIGN_WIDTH, 44.0))
	add_child(title)

	var hint: Label = Label.new()
	hint.text = "HINT_PACK_SELECT"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.add_theme_font_size_override(&"font_size", Constants.UI_MIN_FONT_SIZE)
	hint.add_theme_color_override(&"font_color", Constants.COLOR_HUD_TEXT)
	hint.position = Vector2((Constants.DESIGN_WIDTH - CARD_WIDTH) * 0.5, 108.0)
	hint.set_size(Vector2(CARD_WIDTH, 40.0))
	add_child(hint)

	## VBoxContainer plano (no ScrollContainer): la cantidad de packs es chica a propósito
	## (registro manual en Constants.LEVEL_PACKS) — si algún día crece lo suficiente para
	## no entrar en pantalla, agregar un ScrollContainer siguiendo el mismo patrón de
	## centrado que LevelSelectScreen (regla CLAUDE.md #49).
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", CARD_GAP)
	vbox.position = Vector2((Constants.DESIGN_WIDTH - CARD_WIDTH) * 0.5, 170.0)
	vbox.set_size(Vector2(CARD_WIDTH, 0.0))
	add_child(vbox)

	var manifest: Array = LevelManager.get_manifest()
	for pack: Dictionary in Constants.LEVEL_PACKS:
		var prefix: String = pack.get("prefix", "") as String
		var count: int = _count_levels_with_prefix(manifest, prefix)
		if count <= 0:
			continue
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
		var pack_name: String = tr(pack.get("name_key", "") as String)
		btn.text = tr(&"LABEL_PACK_CARD") % [pack_name, count]
		btn.pressed.connect(_on_pack_pressed.bind(prefix))
		vbox.add_child(btn)

	var back_btn: Button = Button.new()
	back_btn.text = "BTN_BACK"
	back_btn.custom_minimum_size = Vector2(160.0, 48.0)
	back_btn.position = Vector2((Constants.DESIGN_WIDTH - 160.0) * 0.5, Constants.DESIGN_HEIGHT - 96.0)
	back_btn.pressed.connect(_on_back_pressed)
	add_child(back_btn)


func _count_levels_with_prefix(manifest: Array, prefix: String) -> int:
	var count: int = 0
	for level_id: String in manifest:
		if (level_id as String).begins_with(prefix + "_"):
			count += 1
	return count


func _on_pack_pressed(prefix: String) -> void:
	LevelManager.set_pending_pack_prefix(prefix)
	get_tree().change_scene_to_file.call_deferred(PACK_LEVELS_SCENE)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file.call_deferred(MAIN_MENU_SCENE)
