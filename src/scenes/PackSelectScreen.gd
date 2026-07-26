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
const CARD_HEIGHT: float = 72.0
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
		vbox.add_child(_build_pack_card(pack, prefix, count))

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


## Pedido explícito del usuario ("revisa qué pantallas necesitan pulirse"): antes cada
## pack era un botón de texto plano IDÉNTICO, sin ninguna identidad visual pese a que cada
## pack tiene un tema propio (navideño, mundial). Ahora cada tarjeta usa el acento de color
## de `Constants.LEVEL_PACKS` (borde + tinte de fondo) y muestra el progreso real de
## desbloqueo, no solo el conteo total de niveles. El botón en sí queda con texto vacío —
## los Label hijos (con `mouse_filter = IGNORE` para no robarle el toque al botón) dan el
## contenido de dos líneas con colores independientes, algo que el `.text` de un solo
## Button no puede lograr.
func _build_pack_card(pack: Dictionary, prefix: String, count: int) -> Button:
	var accent: Color = pack.get("color", Constants.COLOR_TOTOPO) as Color
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	btn.text = ""
	_apply_pack_card_style(btn, accent)
	btn.pressed.connect(_on_pack_pressed.bind(prefix))

	var name_label: Label = Label.new()
	name_label.text = tr(pack.get("name_key", "") as String)
	name_label.add_theme_font_size_override(&"font_size", 19)
	name_label.add_theme_color_override(&"font_color", accent)
	name_label.position = Vector2(16.0, 8.0)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(name_label)

	var highest_unlocked: int = mini(LevelManager.get_pack_highest_unlocked(prefix), count)
	var progress_label: Label = Label.new()
	progress_label.text = tr(&"LABEL_PACK_PROGRESS") % [highest_unlocked, count]
	progress_label.add_theme_font_size_override(&"font_size", Constants.UI_MIN_FONT_SIZE - 2)
	progress_label.add_theme_color_override(&"font_color", Constants.COLOR_HUD_TEXT)
	progress_label.position = Vector2(16.0, 36.0)
	progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(progress_label)

	return btn


func _apply_pack_card_style(btn: Button, accent: Color) -> void:
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color(accent.r, accent.g, accent.b, 0.12)
	normal.border_color = accent
	normal.border_width_left = 5
	normal.set_corner_radius_all(8)
	btn.add_theme_stylebox_override(&"normal", normal)

	var pressed: StyleBoxFlat = StyleBoxFlat.new()
	pressed.bg_color = Color(accent.r, accent.g, accent.b, 0.28)
	pressed.border_color = accent
	pressed.border_width_left = 5
	pressed.set_corner_radius_all(8)
	btn.add_theme_stylebox_override(&"pressed", pressed)


func _on_pack_pressed(prefix: String) -> void:
	LevelManager.set_pending_pack_prefix(prefix)
	get_tree().change_scene_to_file.call_deferred(PACK_LEVELS_SCENE)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file.call_deferred(MAIN_MENU_SCENE)
