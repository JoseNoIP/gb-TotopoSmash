extends CanvasLayer
## Overlay de configuración (FASE 8): sonido on/off, vibración on/off, sensibilidad de
## apuntado. Reutilizable — se instancia tanto desde MainMenu como desde Game (vía botón
## de pausa) sin cambiar de escena; open()/close() solo la muestran/ocultan.

signal closed

var _panel: PanelContainer = PanelContainer.new()
var _sound_check: CheckButton = CheckButton.new()
var _vibration_check: CheckButton = CheckButton.new()
var _sensitivity_slider: HSlider = HSlider.new()


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_panel.hide()


func open() -> void:
	_sound_check.button_pressed = SaveManager.get_sound_enabled()
	_vibration_check.button_pressed = SaveManager.get_vibration_enabled()
	_sensitivity_slider.value = SaveManager.get_swipe_sensitivity()
	_panel.show()


func _build_ui() -> void:
	var panel_w: float = 300.0
	var panel_h: float = 280.0
	var origin_x: float = (Constants.DESIGN_WIDTH - panel_w) * 0.5
	var origin_y: float = (Constants.DESIGN_HEIGHT - panel_h) * 0.5
	_panel.position = Vector2(origin_x, origin_y)
	_panel.set_size(Vector2(panel_w, panel_h))
	add_child(_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 16)
	_panel.add_child(vbox)

	var title: Label = Label.new()
	title.text = "CONFIGURACIÓN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 20)
	vbox.add_child(title)

	_sound_check.text = "Sonido"
	_sound_check.toggled.connect(_on_sound_toggled)
	vbox.add_child(_sound_check)

	_vibration_check.text = "Vibración"
	_vibration_check.toggled.connect(_on_vibration_toggled)
	vbox.add_child(_vibration_check)

	var sensitivity_label: Label = Label.new()
	sensitivity_label.text = "Sensibilidad de apuntado"
	sensitivity_label.add_theme_font_size_override(&"font_size", Constants.UI_MIN_FONT_SIZE)
	vbox.add_child(sensitivity_label)

	_sensitivity_slider.min_value = 0.5
	_sensitivity_slider.max_value = 2.0
	_sensitivity_slider.step = 0.1
	_sensitivity_slider.custom_minimum_size = Vector2(0.0, 32.0)
	_sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	vbox.add_child(_sensitivity_slider)

	var close_btn: Button = Button.new()
	close_btn.text = "CERRAR"
	close_btn.custom_minimum_size = Vector2(0.0, 44.0)
	close_btn.pressed.connect(_on_close_pressed)
	vbox.add_child(close_btn)


func _on_sound_toggled(enabled: bool) -> void:
	SaveManager.set_sound_enabled(enabled)


func _on_vibration_toggled(enabled: bool) -> void:
	SaveManager.set_vibration_enabled(enabled)


func _on_sensitivity_changed(value: float) -> void:
	SaveManager.set_swipe_sensitivity(value)


func _on_close_pressed() -> void:
	_panel.hide()
	closed.emit()
