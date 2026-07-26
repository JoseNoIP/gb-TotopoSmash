extends Control
## Selector de idioma de primera ejecución (ver /mobile-i18n). MainMenu.gd redirige aquí
## si SaveManager.get_language() está vacío. Al elegir, LocalizationManager.set_language()
## persiste la elección — nunca vuelve a aparecer para este jugador.

const MAIN_MENU_SCENE: String = "res://src/scenes/MainMenu.tscn"
const MenuBackgroundGd := preload("res://src/shared/menu_background.gd")
const LANG_CODES: Array = ["es", "en", "pt_BR", "fr"]
const LANG_NAME_KEYS: Array = ["LANG_NAME_ES", "LANG_NAME_EN", "LANG_NAME_PT_BR", "LANG_NAME_FR"]


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	position = Vector2.ZERO
	set_size(Vector2(Constants.DESIGN_WIDTH, Constants.DESIGN_HEIGHT))

	_build_background()

	var title: Label = Label.new()
	title.text = tr(&"LANGSELECT_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 28)
	title.add_theme_color_override(&"font_color", Constants.COLOR_HUD_TEXT)
	title.position = Vector2(0.0, 260.0)
	title.set_size(Vector2(Constants.DESIGN_WIDTH, 50.0))
	add_child(title)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 16)
	vbox.position = Vector2((Constants.DESIGN_WIDTH - 220.0) * 0.5, 340.0)
	vbox.set_size(Vector2(220.0, 220.0))
	add_child(vbox)

	for i: int in LANG_CODES.size():
		var code: String = LANG_CODES[i]
		var name_key: StringName = LANG_NAME_KEYS[i]
		var btn: Button = Button.new()
		btn.text = tr(name_key)
		btn.custom_minimum_size = Vector2(0.0, 48.0)
		btn.pressed.connect(_on_language_pressed.bind(code))
		vbox.add_child(btn)


## Mismo fondo que MainMenu.gd, extraído a src/shared/menu_background.gd (ver ese archivo
## para el porqué del scrim y del fallback plano cuando el asset todavía no existe).
func _build_background() -> void:
	MenuBackgroundGd.build(self)


func _on_language_pressed(code: String) -> void:
	LocalizationManager.set_language(code)
	get_tree().change_scene_to_file.call_deferred(MAIN_MENU_SCENE)
