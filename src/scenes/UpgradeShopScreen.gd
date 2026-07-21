extends Control
## Tienda de mejoras (oro, mejoras permanentes, personajes cosméticos — ver MetaManager y
## src/features/meta/upgrade_shop.gd). Escena completa nueva (no overlay), mismo patrón que
## LevelSelectScreen.gd. Accesible desde MainMenu, sin gate de tutorial (es solo
## consulta/compra, igual que entrar a LevelSelectScreen).

const MAIN_MENU_SCENE: String = "res://src/scenes/MainMenu.tscn"
const UpgradeShopGd := preload("res://src/features/meta/upgrade_shop.gd")
const ModalStyleGd := preload("res://src/shared/modal_style.gd")

const UPGRADE_NAME_KEYS: Dictionary = {
	"seeds": "UPGRADE_SEEDS_NAME",
	"damage": "UPGRADE_DAMAGE_NAME",
	"speed": "UPGRADE_SPEED_NAME",
}

## Pedido explícito del usuario: "solo hay textos y no es claro las mejoras que existen"
## — cada mejora ahora muestra el efecto NUMÉRICO concreto (no solo el nombre), formateado
## con la key correspondiente a su unidad (semillas enteras vs. porcentaje).
const UPGRADE_EFFECT_FORMAT_KEYS: Dictionary = {
	"seeds": "UPGRADE_SEEDS_EFFECT_FORMAT",
	"damage": "UPGRADE_DAMAGE_EFFECT_FORMAT",
	"speed": "UPGRADE_SPEED_EFFECT_FORMAT",
}

const LEVEL_DOT_FILLED: String = "●"
const LEVEL_DOT_EMPTY: String = "○"

var _gold_label: Label = Label.new()
var _upgrade_rows: Dictionary = {}  ## upgrade_id (String) -> {dots_label, desc_label, buy_btn}
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


## Tarjeta opaca (ModalStyleGd, regla CLAUDE.md #52) en vez de una fila de texto suelta —
## separa visualmente cada mejora y deja lugar para nombre + puntos de nivel + descripción
## numérica del efecto + botón de compra, en vez de solo "nombre / Nivel N/5 / Comprar".
func _build_upgrade_row(parent: VBoxContainer, upgrade_id: String) -> void:
	var panel: PanelContainer = PanelContainer.new()
	var card_color: Color = Constants.COLOR_BG_BOARD.lightened(0.06)
	panel.add_theme_stylebox_override(&"panel", ModalStyleGd.opaque_panel(card_color))
	parent.add_child(panel)

	var card: VBoxContainer = VBoxContainer.new()
	card.add_theme_constant_override(&"separation", 6)
	panel.add_child(card)

	var header: HBoxContainer = HBoxContainer.new()
	card.add_child(header)

	var name_label: Label = Label.new()
	name_label.text = UPGRADE_NAME_KEYS.get(upgrade_id, "") as String
	name_label.add_theme_font_size_override(&"font_size", Constants.UI_MIN_FONT_SIZE)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)

	var dots_label: Label = Label.new()
	dots_label.add_theme_font_size_override(&"font_size", Constants.UI_MIN_FONT_SIZE)
	dots_label.add_theme_color_override(&"font_color", Constants.COLOR_SEED_EXTRA)
	header.add_child(dots_label)

	var desc_label: Label = Label.new()
	desc_label.add_theme_font_size_override(&"font_size", Constants.UI_MIN_FONT_SIZE - 4)
	desc_label.add_theme_color_override(&"font_color", Constants.COLOR_HUD_TEXT)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	card.add_child(desc_label)

	var buy_btn: Button = Button.new()
	buy_btn.custom_minimum_size = Vector2(0.0, 40.0)
	buy_btn.pressed.connect(_on_buy_pressed.bind(upgrade_id))
	card.add_child(buy_btn)

	_upgrade_rows[upgrade_id] = {
		"dots_label": dots_label, "desc_label": desc_label, "buy_btn": buy_btn
	}


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
	var dots_label: Label = row["dots_label"]
	var desc_label: Label = row["desc_label"]
	var buy_btn: Button = row["buy_btn"]
	var level: int = MetaManager.get_upgrade_level(upgrade_id)
	dots_label.text = _level_dots(level)
	if level == 0:
		desc_label.text = tr(&"LABEL_UPGRADE_EFFECT_NOT_BOUGHT") % _effect_text(upgrade_id, 1)
	elif UpgradeShopGd.is_max_level(level):
		desc_label.text = tr(&"LABEL_UPGRADE_EFFECT_CURRENT_MAX") % _effect_text(upgrade_id, level)
	else:
		var current_text: String = _effect_text(upgrade_id, level)
		var next_text: String = _effect_text(upgrade_id, level + 1)
		desc_label.text = tr(&"LABEL_UPGRADE_EFFECT_CURRENT_TO_NEXT") % [current_text, next_text]
	if UpgradeShopGd.is_max_level(level):
		buy_btn.text = tr(&"LABEL_MAX_LEVEL")
		buy_btn.disabled = true
		return
	var cost: int = UpgradeShopGd.cost_for_next_level(level)
	buy_btn.text = tr(&"BTN_BUY_COST") % cost
	buy_btn.disabled = cost > MetaManager.get_gold()


## Puntos de nivel rellenos/vacíos (pedido explícito del usuario: "no es claro las
## mejoras que existen" — un indicador visual rápido además del texto).
func _level_dots(level: int) -> String:
	var dots: String = ""
	for i: int in Constants.UPGRADE_MAX_LEVEL:
		dots += LEVEL_DOT_FILLED if i < level else LEVEL_DOT_EMPTY
	return dots


## Valor numérico concreto del efecto de una mejora a un nivel dado — misma unidad que
## src/features/meta/upgrade_shop.gd usa internamente (semillas enteras, o % redondeado).
func _effect_value(upgrade_id: String, level: int) -> int:
	match upgrade_id:
		"seeds":
			return UpgradeShopGd.bonus_seeds(level)
		"damage":
			return roundi((UpgradeShopGd.damage_multiplier(level) - 1.0) * 100.0)
		"speed":
			return roundi((UpgradeShopGd.seed_speed_multiplier(level) - 1.0) * 100.0)
		_:
			return 0


func _effect_text(upgrade_id: String, level: int) -> String:
	var format_key: StringName = UPGRADE_EFFECT_FORMAT_KEYS.get(upgrade_id, "") as StringName
	return tr(format_key) % _effect_value(upgrade_id, level)


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
