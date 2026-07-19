extends CanvasLayer
## Overlay de fin de partida (FASE 8): score final, oleada alcanzada, mejor puntaje,
## REINTENTAR / MENU PRINCIPAL. GDD: sin condición de victoria — Totopo Smash es
## progresión infinita por oleadas, así que solo existe esta pantalla (no VictoryScreen).

signal restart_requested
signal main_menu_requested

var _panel: PanelContainer = PanelContainer.new()
var _score_label: Label = Label.new()
var _wave_label: Label = Label.new()
var _best_label: Label = Label.new()


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_panel.hide()
	EventBus.game_over.connect(_on_game_over)


func _build_ui() -> void:
	var panel_w: float = 300.0
	var panel_h: float = 300.0
	var origin_x: float = (Constants.DESIGN_WIDTH - panel_w) * 0.5
	var origin_y: float = (Constants.DESIGN_HEIGHT - panel_h) * 0.5
	_panel.position = Vector2(origin_x, origin_y)
	_panel.set_size(Vector2(panel_w, panel_h))
	add_child(_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 10)
	_panel.add_child(vbox)

	## KEY cruda (no tr()) en título/botones — auto-translate nativo (ver MainMenu.gd).
	var title: Label = Label.new()
	title.text = "TITLE_GAME_OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 20)
	vbox.add_child(title)

	for label: Label in [_score_label, _wave_label, _best_label]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override(&"font_size", Constants.UI_MIN_FONT_SIZE)
		vbox.add_child(label)

	var retry_btn: Button = Button.new()
	retry_btn.text = "BTN_RETRY"
	retry_btn.custom_minimum_size = Vector2(0.0, 44.0)
	retry_btn.pressed.connect(_on_retry_pressed)
	vbox.add_child(retry_btn)

	var menu_btn: Button = Button.new()
	menu_btn.text = "BTN_MAIN_MENU"
	menu_btn.custom_minimum_size = Vector2(0.0, 44.0)
	menu_btn.pressed.connect(_on_menu_pressed)
	vbox.add_child(menu_btn)


func _on_game_over(final_score: int, wave_reached: int) -> void:
	_score_label.text = tr(&"LABEL_SCORE") % final_score
	_wave_label.text = tr(&"LABEL_WAVE_REACHED") % wave_reached
	_best_label.text = tr(&"LABEL_BEST_SCORE") % SaveManager.get_best_score()
	_panel.show()


func _on_retry_pressed() -> void:
	_panel.hide()
	restart_requested.emit()


func _on_menu_pressed() -> void:
	_panel.hide()
	main_menu_requested.emit()
