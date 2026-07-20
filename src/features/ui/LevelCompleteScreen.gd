extends CanvasLayer
## Overlay de nivel completado (Modo Nivel — ver LevelManager/level_loader.gd): score,
## REINTENTAR / SIGUIENTE NIVEL (oculto si es el último del manifiesto) / MENÚ PRINCIPAL.
## Calcado de GameOverScreen.gd; instanciado siempre en Game.gd, pero solo dispara si
## EventBus.level_completed se emite (nunca en Modo Infinito).

signal restart_requested
signal next_level_requested(level_id: String)
signal main_menu_requested

const ModalStyleGd := preload("res://src/shared/modal_style.gd")

var _panel: PanelContainer = PanelContainer.new()
var _score_label: Label = Label.new()
var _next_btn: Button = Button.new()
var _next_level_id: String = ""


func _ready() -> void:
	layer = 26
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_panel.hide()
	EventBus.level_completed.connect(_on_level_completed)


func _build_ui() -> void:
	var panel_w: float = 300.0
	var panel_h: float = 280.0
	var origin_x: float = (Constants.DESIGN_WIDTH - panel_w) * 0.5
	var origin_y: float = (Constants.DESIGN_HEIGHT - panel_h) * 0.5
	_panel.position = Vector2(origin_x, origin_y)
	_panel.set_size(Vector2(panel_w, panel_h))
	## Fondo sólido/opaco — ver modal_style.gd (bug real: PanelContainer sin esto es
	## semi-transparente y el texto se mezcla con lo que hay detrás).
	_panel.add_theme_stylebox_override(&"panel", ModalStyleGd.opaque_panel())
	add_child(_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 10)
	_panel.add_child(vbox)

	## KEY cruda (no tr()) — auto-translate nativo (ver MainMenu.gd).
	var title: Label = Label.new()
	title.text = "LEVEL_COMPLETE_TITLE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 20)
	vbox.add_child(title)

	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.add_theme_font_size_override(&"font_size", Constants.UI_MIN_FONT_SIZE)
	vbox.add_child(_score_label)

	var retry_btn: Button = Button.new()
	retry_btn.text = "BTN_RETRY"
	retry_btn.custom_minimum_size = Vector2(0.0, 44.0)
	retry_btn.pressed.connect(_on_retry_pressed)
	vbox.add_child(retry_btn)

	_next_btn.text = "BTN_NEXT_LEVEL"
	_next_btn.custom_minimum_size = Vector2(0.0, 44.0)
	_next_btn.pressed.connect(_on_next_pressed)
	vbox.add_child(_next_btn)

	var menu_btn: Button = Button.new()
	menu_btn.text = "BTN_MAIN_MENU"
	menu_btn.custom_minimum_size = Vector2(0.0, 44.0)
	menu_btn.pressed.connect(_on_menu_pressed)
	vbox.add_child(menu_btn)


func _on_level_completed(level_id: String, final_score: int) -> void:
	_score_label.text = tr(&"LABEL_SCORE") % final_score
	var manifest: Array = LevelManager.get_manifest()
	var index: int = manifest.find(level_id)
	var has_next: bool = index >= 0 and index + 1 < manifest.size()
	_next_level_id = manifest[index + 1] if has_next else ""
	_next_btn.visible = has_next
	_panel.show()


func _on_retry_pressed() -> void:
	_panel.hide()
	restart_requested.emit()


func _on_next_pressed() -> void:
	_panel.hide()
	next_level_requested.emit(_next_level_id)


func _on_menu_pressed() -> void:
	_panel.hide()
	main_menu_requested.emit()
