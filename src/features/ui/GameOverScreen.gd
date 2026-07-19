extends CanvasLayer
## Overlay de fin de partida: score final, mejor puntaje, REINTENTAR / MENU PRINCIPAL.
## Modo Infinito: además muestra la oleada alcanzada (sin condición de victoria, GDD
## original). Modo Nivel: oculta "oleada" (no aplica) y usa un título distinto — perder
## un nivel no es lo mismo que "fin de la partida" de Modo Infinito.

signal restart_requested
signal main_menu_requested

var _panel: PanelContainer = PanelContainer.new()
var _title_label: Label = Label.new()
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

	## KEY cruda (no tr()) — auto-translate nativo (ver MainMenu.gd). El título se fija en
	## _on_game_over() porque depende del modo (Infinito/Nivel), no se conoce al construir.
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override(&"font_size", 20)
	vbox.add_child(_title_label)

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
	var level_mode: bool = GameManager.is_level_mode()
	_title_label.text = "LEVEL_FAILED_TITLE" if level_mode else "TITLE_GAME_OVER"
	_score_label.text = tr(&"LABEL_SCORE") % final_score
	_wave_label.visible = not level_mode
	if not level_mode:
		_wave_label.text = tr(&"LABEL_WAVE_REACHED") % wave_reached
	_best_label.text = tr(&"LABEL_BEST_SCORE") % SaveManager.get_best_score()
	_panel.show()


func _on_retry_pressed() -> void:
	_panel.hide()
	restart_requested.emit()


func _on_menu_pressed() -> void:
	_panel.hide()
	main_menu_requested.emit()
