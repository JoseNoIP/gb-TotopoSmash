extends Control
## Tienda de mejoras (oro, mejoras permanentes, personajes cosméticos — ver MetaManager y
## src/features/meta/upgrade_shop.gd). Escena completa nueva (no overlay), mismo patrón que
## LevelSelectScreen.gd. Accesible desde MainMenu, sin gate de tutorial (es solo
## consulta/compra, igual que entrar a LevelSelectScreen).

const MAIN_MENU_SCENE: String = "res://src/scenes/MainMenu.tscn"
const UpgradeShopGd := preload("res://src/features/meta/upgrade_shop.gd")

const UPGRADE_NAME_KEYS: Dictionary = {
	"seeds": "UPGRADE_SEEDS_NAME",
	"damage": "UPGRADE_DAMAGE_NAME",
	"speed": "UPGRADE_SPEED_NAME",
}

var _gold_label: Label = Label.new()
var _upgrade_rows: Dictionary = {}  ## upgrade_id (String) -> {level_label, buy_btn}
var _character_buttons: Dictionary = {}  ## character_id (String) -> Button


func _ready() -> void:
	_build_ui()
	_refresh_all()


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
	title.text = "TITLE_SHOP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 26)
	title.add_theme_color_override(&"font_color", Constants.COLOR_TOTOPO)
	title.position = Vector2(0.0, 50.0)
	title.set_size(Vector2(Constants.DESIGN_WIDTH, 40.0))
	add_child(title)

	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label.add_theme_font_size_override(&"font_size", 20)
	_gold_label.add_theme_color_override(&"font_color", Constants.COLOR_SEED_EXTRA)
	_gold_label.position = Vector2(0.0, 92.0)
	_gold_label.set_size(Vector2(Constants.DESIGN_WIDTH, 30.0))
	add_child(_gold_label)

	## El ScrollContainer se centra a sí mismo con ancho fijo (no sus hijos) — un
	## Container ignora `position` puesto a mano en sus hijos directos (regla CLAUDE.md #49).
	var content_w: float = Constants.DESIGN_WIDTH - 40.0
	var content_h: float = Constants.DESIGN_HEIGHT - 140.0 - 96.0
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(20.0, 140.0)
	scroll.set_size(Vector2(content_w, content_h))
	add_child(scroll)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(content_w, 0.0)
	vbox.add_theme_constant_override(&"separation", 14)
	scroll.add_child(vbox)

	for upgrade_id: String in UpgradeShopGd.UPGRADE_IDS:
		_build_upgrade_row(vbox, upgrade_id)

	var characters_label: Label = Label.new()
	characters_label.text = "TITLE_CHARACTERS"
	characters_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	characters_label.add_theme_font_size_override(&"font_size", 18)
	characters_label.add_theme_color_override(&"font_color", Constants.COLOR_HUD_TEXT)
	vbox.add_child(characters_label)

	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 12)
	grid.add_theme_constant_override(&"v_separation", 12)
	vbox.add_child(grid)
	for character: Dictionary in Constants.CHARACTERS:
		_build_character_button(grid, character.get("id", "") as String)

	var back_btn: Button = Button.new()
	back_btn.text = "BTN_BACK"
	back_btn.custom_minimum_size = Vector2(160.0, 48.0)
	back_btn.position = Vector2((Constants.DESIGN_WIDTH - 160.0) * 0.5, Constants.DESIGN_HEIGHT - 76.0)
	back_btn.pressed.connect(_on_back_pressed)
	add_child(back_btn)


func _build_upgrade_row(parent: VBoxContainer, upgrade_id: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	parent.add_child(row)

	var name_label: Label = Label.new()
	name_label.text = UPGRADE_NAME_KEYS.get(upgrade_id, "") as String
	name_label.custom_minimum_size = Vector2(110.0, 40.0)
	name_label.add_theme_font_size_override(&"font_size", Constants.UI_MIN_FONT_SIZE)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)

	var level_label: Label = Label.new()
	level_label.custom_minimum_size = Vector2(70.0, 40.0)
	level_label.add_theme_font_size_override(&"font_size", Constants.UI_MIN_FONT_SIZE)
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(level_label)

	var buy_btn: Button = Button.new()
	buy_btn.custom_minimum_size = Vector2(120.0, 40.0)
	buy_btn.pressed.connect(_on_buy_pressed.bind(upgrade_id))
	row.add_child(buy_btn)

	_upgrade_rows[upgrade_id] = {"level_label": level_label, "buy_btn": buy_btn}


func _build_character_button(parent: GridContainer, character_id: String) -> void:
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2((Constants.DESIGN_WIDTH - 40.0 - 12.0) * 0.5, 48.0)
	btn.pressed.connect(_on_character_pressed.bind(character_id))
	parent.add_child(btn)
	_character_buttons[character_id] = btn


func _refresh_all() -> void:
	_gold_label.text = tr(&"LABEL_GOLD") % MetaManager.get_gold()
	for upgrade_id: String in UpgradeShopGd.UPGRADE_IDS:
		_refresh_upgrade_row(upgrade_id)
	for character: Dictionary in Constants.CHARACTERS:
		_refresh_character_button(character.get("id", "") as String)


func _refresh_upgrade_row(upgrade_id: String) -> void:
	var row: Dictionary = _upgrade_rows[upgrade_id]
	var level_label: Label = row["level_label"]
	var buy_btn: Button = row["buy_btn"]
	var level: int = MetaManager.get_upgrade_level(upgrade_id)
	level_label.text = tr(&"LABEL_UPGRADE_LEVEL") % [level, Constants.UPGRADE_MAX_LEVEL]
	if UpgradeShopGd.is_max_level(level):
		buy_btn.text = tr(&"LABEL_MAX_LEVEL")
		buy_btn.disabled = true
		return
	var cost: int = UpgradeShopGd.cost_for_next_level(level)
	buy_btn.text = tr(&"BTN_BUY_COST") % cost
	buy_btn.disabled = cost > MetaManager.get_gold()


func _refresh_character_button(character_id: String) -> void:
	var btn: Button = _character_buttons[character_id]
	var character: Dictionary = UpgradeShopGd.find_character(character_id)
	var unlocked: Array = MetaManager.get_unlocked_characters()
	var selected: String = MetaManager.get_selected_character()
	var name_text: String = tr(character.get("name_key", "") as String)
	if character_id == selected:
		btn.text = tr(&"LABEL_CHARACTER_SELECTED") % name_text
		btn.disabled = false
	elif character_id in unlocked:
		btn.text = name_text
		btn.disabled = false
	else:
		var cost: int = int(character.get("cost", 0))
		btn.text = "%s (%d)" % [name_text, cost]
		btn.disabled = cost > MetaManager.get_gold()


func _on_buy_pressed(upgrade_id: String) -> void:
	var level: int = MetaManager.get_upgrade_level(upgrade_id)
	if UpgradeShopGd.is_max_level(level):
		return
	var cost: int = UpgradeShopGd.cost_for_next_level(level)
	if not MetaManager.spend_gold(cost):
		return
	var new_level: int = level + 1
	MetaManager.set_upgrade_level(upgrade_id, new_level)
	EventBus.upgrade_purchased.emit(upgrade_id, new_level)
	EventBus.gold_changed.emit(MetaManager.get_gold())
	_refresh_all()


func _on_character_pressed(character_id: String) -> void:
	var unlocked: Array = MetaManager.get_unlocked_characters()
	if character_id in unlocked:
		MetaManager.set_selected_character(character_id)
		EventBus.character_selected.emit(character_id)
		_refresh_all()
		return
	var character: Dictionary = UpgradeShopGd.find_character(character_id)
	var cost: int = int(character.get("cost", 0))
	if not MetaManager.spend_gold(cost):
		return
	MetaManager.unlock_character(character_id)
	MetaManager.set_selected_character(character_id)
	EventBus.character_selected.emit(character_id)
	EventBus.gold_changed.emit(MetaManager.get_gold())
	_refresh_all()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file.call_deferred(MAIN_MENU_SCENE)
