extends Control
## Menú principal (FASE 8). GDD: sin metagame de mejoras (ver SaveManager) — solo JUGAR y
## CONFIGURACIÓN. "JUGAR" enruta a TutorialGame.tscn o Game.tscn según
## SaveManager.get_tutorial_shown() (regla anti-alucinación FTUE #35).

const GAME_SCENE: String = "res://src/scenes/Game.tscn"
const TUTORIAL_SCENE: String = "res://src/scenes/TutorialGame.tscn"
const LANGUAGE_SELECT_SCENE: String = "res://src/scenes/LanguageSelectScreen.tscn"
const LEVEL_SELECT_SCENE: String = "res://src/scenes/LevelSelectScreen.tscn"
const MENU_BG_PATH: String = "res://assets/sprites/backgrounds/menu_bg.png"
const SettingsScreenGd := preload("res://src/features/ui/SettingsScreen.gd")

var _settings: CanvasLayer = null


func _ready() -> void:
	## Primera ejecución (/mobile-i18n): sin idioma elegido todavía → selector antes que
	## nada. LocalizationManager ya aplicó "es" por defecto en su _ready(), pero eso no
	## cuenta como elección persistida por el jugador.
	if SaveManager.get_language().is_empty():
		get_tree().change_scene_to_file.call_deferred(LANGUAGE_SELECT_SCENE)
		return
	_build_ui()


func _build_ui() -> void:
	position = Vector2.ZERO
	set_size(Vector2(Constants.DESIGN_WIDTH, Constants.DESIGN_HEIGHT))

	_build_background()

	## Título/botones: se asigna la KEY directo (no tr()) para aprovechar el
	## auto-translate nativo de Control — este menú se construye una sola vez y
	## SettingsScreen (hijo) puede cambiar el idioma sin recargar la escena; con la key
	## cruda, Godot re-traduce solo al cambiar TranslationServer.set_locale(). Los labels
	## con valores (best_label) sí necesitan tr()+formato explícito en cada actualización.
	var title: Label = Label.new()
	title.text = "TITLE_GAME"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 34)
	title.add_theme_color_override(&"font_color", Constants.COLOR_TOTOPO)
	title.position = Vector2(0.0, 140.0)
	title.set_size(Vector2(Constants.DESIGN_WIDTH, 60.0))
	add_child(title)

	var best_label: Label = Label.new()
	var best_score: int = SaveManager.get_best_score()
	var max_wave: int = SaveManager.get_max_wave()
	best_label.text = tr(&"LABEL_BEST_STATS") % [best_score, max_wave]
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best_label.add_theme_font_size_override(&"font_size", Constants.UI_MIN_FONT_SIZE)
	best_label.add_theme_color_override(&"font_color", Constants.COLOR_HUD_TEXT)
	best_label.position = Vector2(0.0, 210.0)
	best_label.set_size(Vector2(Constants.DESIGN_WIDTH, 30.0))
	add_child(best_label)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 16)
	vbox.position = Vector2((Constants.DESIGN_WIDTH - 220.0) * 0.5, 400.0)
	vbox.set_size(Vector2(220.0, 200.0))
	add_child(vbox)

	var levels_btn: Button = Button.new()
	levels_btn.text = "BTN_LEVELS"
	levels_btn.custom_minimum_size = Vector2(0.0, 52.0)
	levels_btn.pressed.connect(_on_levels_pressed)
	vbox.add_child(levels_btn)

	var play_btn: Button = Button.new()
	play_btn.text = "BTN_INFINITY_MODE"
	play_btn.custom_minimum_size = Vector2(0.0, 52.0)
	play_btn.pressed.connect(_on_play_pressed)
	vbox.add_child(play_btn)

	var settings_btn: Button = Button.new()
	settings_btn.text = "TITLE_SETTINGS"
	settings_btn.custom_minimum_size = Vector2(0.0, 52.0)
	settings_btn.pressed.connect(_on_settings_pressed)
	vbox.add_child(settings_btn)

	_settings = SettingsScreenGd.new()
	add_child(_settings)


## Fondo real (IA, ver /gen-ai-art) + scrim oscuro para que el título/botones sigan
## legibles encima. Si el asset no existe todavía, cae al ColorRect plano de siempre —
## el fondo del tablero de juego SÍ debe quedarse plano (GDD sección 5: para resaltar
## las trayectorias de las semillas), esto solo aplica al menú, que no compite con nada.
func _build_background() -> void:
	if not ResourceLoader.exists(MENU_BG_PATH):
		var flat_bg: ColorRect = ColorRect.new()
		flat_bg.color = Constants.COLOR_BG_BOARD
		flat_bg.position = Vector2.ZERO
		flat_bg.set_size(Vector2(Constants.DESIGN_WIDTH, Constants.DESIGN_HEIGHT))
		flat_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(flat_bg)
		return

	var bg: TextureRect = TextureRect.new()
	bg.texture = load(MENU_BG_PATH)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.position = Vector2.ZERO
	bg.set_size(Vector2(Constants.DESIGN_WIDTH, Constants.DESIGN_HEIGHT))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var scrim: ColorRect = ColorRect.new()
	scrim.color = Color(0.0, 0.0, 0.0, 0.4)
	scrim.position = Vector2.ZERO
	scrim.set_size(Vector2(Constants.DESIGN_WIDTH, Constants.DESIGN_HEIGHT))
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)


## Modo Infinito (progresión al azar de siempre). Limpia el buzón de LevelManager antes
## de rutear — si no, un nivel elegido en una sesión anterior "sobreviviría" y este botón
## terminaría cargando ese nivel en vez de Modo Infinito.
func _on_play_pressed() -> void:
	LevelManager.set_pending_level("")
	var dest: String = GAME_SCENE if SaveManager.get_tutorial_shown() else TUTORIAL_SCENE
	get_tree().change_scene_to_file.call_deferred(dest)


## Entrar al selector de niveles NO está gateado por el tutorial (solo elegir un nivel
## ahí sí lo está, igual que "JUGAR" aquí) — es solo navegación, no intención de jugar.
func _on_levels_pressed() -> void:
	get_tree().change_scene_to_file.call_deferred(LEVEL_SELECT_SCENE)


func _on_settings_pressed() -> void:
	_settings.call(&"open")
