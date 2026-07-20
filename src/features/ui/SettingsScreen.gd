extends CanvasLayer
## Overlay de configuración (FASE 8): sonido on/off, vibración on/off, sensibilidad de
## apuntado. Reutilizable — se instancia tanto desde MainMenu como desde Game (vía botón
## de pausa) sin cambiar de escena; open()/close() solo la muestran/ocultan.

signal closed

const ModalStyleGd := preload("res://src/shared/modal_style.gd")
const LANG_CODES: Array = ["es", "en", "pt_BR", "fr"]
const LANG_NAME_KEYS: Array = ["LANG_NAME_ES", "LANG_NAME_EN", "LANG_NAME_PT_BR", "LANG_NAME_FR"]

var _panel: PanelContainer = PanelContainer.new()
var _sound_check: CheckButton = CheckButton.new()
var _vibration_check: CheckButton = CheckButton.new()
var _sensitivity_slider: HSlider = HSlider.new()
var _lang_button: Button = Button.new()


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_panel.hide()


func open() -> void:
	_sound_check.button_pressed = SaveManager.get_sound_enabled()
	_vibration_check.button_pressed = SaveManager.get_vibration_enabled()
	_sensitivity_slider.value = SaveManager.get_swipe_sensitivity()
	_refresh_lang_button()
	_panel.show()


func _build_ui() -> void:
	var panel_w: float = 300.0
	var panel_h: float = 340.0
	var origin_x: float = (Constants.DESIGN_WIDTH - panel_w) * 0.5
	var origin_y: float = (Constants.DESIGN_HEIGHT - panel_h) * 0.5
	_panel.position = Vector2(origin_x, origin_y)
	_panel.set_size(Vector2(panel_w, panel_h))
	## Fondo sólido/opaco — el estilo default de PanelContainer es semi-transparente y el
	## texto se mezclaba con lo que hay detrás (bug real reportado jugando, ver
	## modal_style.gd). Aplicar SIEMPRE a un PanelContainer usado como overlay/modal.
	_panel.add_theme_stylebox_override(&"panel", ModalStyleGd.opaque_panel())
	add_child(_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 16)
	_panel.add_child(vbox)

	## KEY cruda (no tr()) en título/checkboxes/labels estáticos — auto-translate nativo
	## de Control (ver nota en MainMenu.gd). Esta pantalla nunca se reconstruye, solo se
	## muestra/oculta, así que es la que más depende de que el cambio de idioma se
	## refleje solo (sin tr(), quedaría en el idioma viejo hasta cerrar y reabrir).
	var title: Label = Label.new()
	title.text = "TITLE_SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 20)
	vbox.add_child(title)

	_sound_check.text = "SETTINGS_SOUND"
	_sound_check.toggled.connect(_on_sound_toggled)
	vbox.add_child(_sound_check)

	_vibration_check.text = "SETTINGS_VIBRATION"
	_vibration_check.toggled.connect(_on_vibration_toggled)
	vbox.add_child(_vibration_check)

	var sensitivity_label: Label = Label.new()
	sensitivity_label.text = "SETTINGS_SENSITIVITY"
	sensitivity_label.add_theme_font_size_override(&"font_size", Constants.UI_MIN_FONT_SIZE)
	vbox.add_child(sensitivity_label)

	_sensitivity_slider.min_value = 0.5
	_sensitivity_slider.max_value = 2.0
	_sensitivity_slider.step = 0.1
	_sensitivity_slider.custom_minimum_size = Vector2(0.0, 32.0)
	_sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	vbox.add_child(_sensitivity_slider)

	var lang_label: Label = Label.new()
	lang_label.text = "SETTINGS_LANGUAGE"
	lang_label.add_theme_font_size_override(&"font_size", Constants.UI_MIN_FONT_SIZE)
	vbox.add_child(lang_label)

	## _lang_button.text SIEMPRE se asigna manualmente (nunca queda como key cruda): los
	## LANG_NAME_* son autónimos (Español/English/...) — el valor no depende del locale
	## activo, así que auto-translate no aporta nada aquí y el ciclo lo controla
	## _refresh_lang_button() explícitamente.
	_lang_button.custom_minimum_size = Vector2(0.0, 44.0)
	_lang_button.pressed.connect(_on_lang_next_pressed)
	vbox.add_child(_lang_button)

	var close_btn: Button = Button.new()
	close_btn.text = "BTN_CLOSE"
	close_btn.custom_minimum_size = Vector2(0.0, 44.0)
	close_btn.pressed.connect(_on_close_pressed)
	vbox.add_child(close_btn)


## La música de fondo (AudioManager, en loop desde el arranque) no se detiene sola al
## desactivar el sonido — a diferencia de los SFX (uno solo, ya terminan por su cuenta),
## sin este toque explícito seguiría sonando con el interruptor en "apagado", lo cual el
## jugador razonablemente esperaría que silenciara TODO.
func _on_sound_toggled(enabled: bool) -> void:
	SaveManager.set_sound_enabled(enabled)
	if enabled:
		AudioManager.play_music()
	else:
		AudioManager.stop_music()


func _on_vibration_toggled(enabled: bool) -> void:
	SaveManager.set_vibration_enabled(enabled)


func _on_sensitivity_changed(value: float) -> void:
	SaveManager.set_swipe_sensitivity(value)


func _on_lang_next_pressed() -> void:
	var current: String = LocalizationManager.get_current_language()
	var idx: int = LANG_CODES.find(current)
	idx = (idx + 1) % LANG_CODES.size()
	LocalizationManager.set_language(LANG_CODES[idx])
	_refresh_lang_button()


func _refresh_lang_button() -> void:
	var current: String = LocalizationManager.get_current_language()
	var idx: int = maxi(0, LANG_CODES.find(current))
	_lang_button.text = tr(LANG_NAME_KEYS[idx])


func _on_close_pressed() -> void:
	_panel.hide()
	closed.emit()
