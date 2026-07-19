extends CanvasLayer
## Overlay de pausa: CONTINUAR / REINICIAR / MENU PRINCIPAL (FASE 8). Se muestra al
## recibir EventBus.game_paused y se oculta con game_resumed. "Continuar" llama
## GameManager.resume_game() directamente (autoload global); reiniciar/menú emiten
## señales locales — Game.gd (dueño directo de esta instancia) decide a qué escena ir.

signal restart_requested
signal main_menu_requested

var _panel: PanelContainer = PanelContainer.new()


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_panel.hide()
	EventBus.game_paused.connect(_on_game_paused)
	EventBus.game_resumed.connect(_on_game_resumed)


func _build_ui() -> void:
	var panel_w: float = 280.0
	var panel_h: float = 240.0
	var origin_x: float = (Constants.DESIGN_WIDTH - panel_w) * 0.5
	var origin_y: float = (Constants.DESIGN_HEIGHT - panel_h) * 0.5
	_panel.position = Vector2(origin_x, origin_y)
	_panel.set_size(Vector2(panel_w, panel_h))
	add_child(_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 12)
	_panel.add_child(vbox)

	## KEY cruda (no tr()): esta pantalla se construye una vez en _ready() y solo se
	## muestra/oculta — con la key cruda, el auto-translate nativo de Control re-traduce
	## sola si el idioma cambia mientras el overlay ya existe (ver nota en MainMenu.gd).
	var title: Label = Label.new()
	title.text = "TITLE_PAUSE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 22)
	vbox.add_child(title)

	vbox.add_child(_make_button("BTN_CONTINUE", _on_resume_pressed))
	vbox.add_child(_make_button("BTN_RESTART", _on_restart_pressed))
	vbox.add_child(_make_button("BTN_MAIN_MENU", _on_menu_pressed))


func _make_button(text_key: String, handler: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text_key
	button.custom_minimum_size = Vector2(0.0, 44.0)
	button.pressed.connect(handler)
	return button


func _on_game_paused() -> void:
	_panel.show()


func _on_game_resumed() -> void:
	_panel.hide()


func _on_resume_pressed() -> void:
	GameManager.resume_game()


func _on_restart_pressed() -> void:
	GameManager.resume_game()
	restart_requested.emit()


func _on_menu_pressed() -> void:
	GameManager.resume_game()
	main_menu_requested.emit()
