extends Control
## Menú principal (FASE 8). GDD: sin metagame de mejoras (ver SaveManager) — solo JUGAR y
## CONFIGURACIÓN. "JUGAR" enruta a TutorialGame.tscn o Game.tscn según
## SaveManager.get_tutorial_shown() (regla anti-alucinación FTUE #35).

const GAME_SCENE: String = "res://src/scenes/Game.tscn"
const TUTORIAL_SCENE: String = "res://src/scenes/TutorialGame.tscn"
const SettingsScreenGd := preload("res://src/features/ui/SettingsScreen.gd")

var _settings: CanvasLayer = null


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
	title.text = "TOTOPO SMASH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 34)
	title.add_theme_color_override(&"font_color", Constants.COLOR_TOTOPO)
	title.position = Vector2(0.0, 140.0)
	title.set_size(Vector2(Constants.DESIGN_WIDTH, 60.0))
	add_child(title)

	var best_label: Label = Label.new()
	var best_score: int = SaveManager.get_best_score()
	var max_wave: int = SaveManager.get_max_wave()
	best_label.text = "Mejor puntaje: %d   Oleada máxima: %d" % [best_score, max_wave]
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best_label.add_theme_font_size_override(&"font_size", Constants.UI_MIN_FONT_SIZE)
	best_label.add_theme_color_override(&"font_color", Constants.COLOR_HUD_TEXT)
	best_label.position = Vector2(0.0, 210.0)
	best_label.set_size(Vector2(Constants.DESIGN_WIDTH, 30.0))
	add_child(best_label)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 16)
	vbox.position = Vector2((Constants.DESIGN_WIDTH - 220.0) * 0.5, 420.0)
	vbox.set_size(Vector2(220.0, 140.0))
	add_child(vbox)

	var play_btn: Button = Button.new()
	play_btn.text = "JUGAR"
	play_btn.custom_minimum_size = Vector2(0.0, 52.0)
	play_btn.pressed.connect(_on_play_pressed)
	vbox.add_child(play_btn)

	var settings_btn: Button = Button.new()
	settings_btn.text = "CONFIGURACIÓN"
	settings_btn.custom_minimum_size = Vector2(0.0, 52.0)
	settings_btn.pressed.connect(_on_settings_pressed)
	vbox.add_child(settings_btn)

	_settings = SettingsScreenGd.new()
	add_child(_settings)


func _on_play_pressed() -> void:
	var dest: String = GAME_SCENE if SaveManager.get_tutorial_shown() else TUTORIAL_SCENE
	get_tree().change_scene_to_file.call_deferred(dest)


func _on_settings_pressed() -> void:
	_settings.call(&"open")
