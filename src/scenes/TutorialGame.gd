extends Node2D
## Tutorial interactivo (FTUE). Usa los sistemas reales del juego (BoardManager,
## TurnManager, Mortar, VFXSpawner, HUD) en una escena separada — nunca overlay sobre
## Game.tscn (regla anti-alucinación FTUE #33). `set_tutorial_shown(true)` se llama
## SOLO al completar el último paso (regla #34), nunca al entrar a la escena. Si el
## jugador muere durante el tutorial, se reinicia esta misma escena (no marca shown).
##
## Nota de secuencia: BoardManager escucha EventBus.all_seeds_returned y responde de
## forma SÍNCRONA (desplaza el tablero, spawnea la fila nueva, emite wave_advanced) antes
## de que el propio handler de este script para la misma señal llegue a ejecutarse (se
## conectó después, en tiempo de ejecución). Por eso el paso ADVANCE no espera una señal
## nueva — para cuando WATCH_RETURN reacciona, el avance de tablero ya ocurrió.

enum Step { WELCOME, AIM_SHOOT, WATCH_RETURN, ADVANCE, COMPLETE }

const BoardManagerGd := preload("res://src/features/board/board_manager.gd")
const TurnManagerGd := preload("res://src/features/board/turn_manager.gd")
const WorldBoundsGd := preload("res://src/features/board/world_bounds.gd")
const DangerLineGd := preload("res://src/features/board/danger_line.gd")
const MortarGd := preload("res://src/features/player/mortar.gd")
const VfxSpawnerGd := preload("res://src/features/vfx/vfx_spawner.gd")
const HudGd := preload("res://src/features/ui/HUD.gd")
const PauseScreenGd := preload("res://src/features/ui/PauseScreen.gd")

const GAME_SCENE: String = "res://src/scenes/Game.tscn"
const TUTORIAL_SCENE: String = "res://src/scenes/TutorialGame.tscn"
const MAIN_MENU_SCENE: String = "res://src/scenes/MainMenu.tscn"

var _step: Step = Step.WELCOME
var _layer: CanvasLayer = CanvasLayer.new()
var _panel: PanelContainer = PanelContainer.new()
var _title_label: Label = Label.new()
var _hint_label: Label = Label.new()
var _action_button: Button = Button.new()


func _ready() -> void:
	_build_scene()
	GameManager.start_game()
	EventBus.game_over.connect(_on_game_over)
	_advance_to(Step.WELCOME)


func _build_scene() -> void:
	## Sin CanvasLayer: cualquier nodo dentro de un CanvasLayer se dibuja SIEMPRE por
	## encima de los Node2D normales (BoardManager, Mortar, semillas), sin importar su
	## valor de `layer` — un ColorRect de fondo ahí adentro tapa todo el juego. Se agrega
	## primero para quedar detrás por orden de árbol, igual que en MainMenu.gd.
	var bg: ColorRect = ColorRect.new()
	bg.color = Constants.COLOR_BG_BOARD
	bg.position = Vector2.ZERO
	bg.set_size(Vector2(Constants.DESIGN_WIDTH, Constants.DESIGN_HEIGHT))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	add_child(BoardManagerGd.new())
	add_child(TurnManagerGd.new())
	add_child(WorldBoundsGd.new())
	add_child(DangerLineGd.new())
	add_child(MortarGd.new())
	add_child(VfxSpawnerGd.new())
	add_child(HudGd.new())

	var pause_screen: CanvasLayer = PauseScreenGd.new()
	add_child(pause_screen)
	pause_screen.connect(&"restart_requested", _on_restart_requested)
	pause_screen.connect(&"main_menu_requested", _on_main_menu_requested)

	_build_overlay()


func _build_overlay() -> void:
	_layer.layer = 40
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)

	var panel_h: float = 176.0
	_panel.position = Vector2(0.0, Constants.DESIGN_HEIGHT - panel_h)
	_panel.set_size(Vector2(Constants.DESIGN_WIDTH, panel_h))
	_layer.add_child(_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 8)
	_panel.add_child(vbox)

	_title_label.add_theme_font_size_override(&"font_size", 20)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	_hint_label.add_theme_font_size_override(&"font_size", Constants.UI_MIN_FONT_SIZE)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_hint_label)

	_action_button.custom_minimum_size = Vector2(0.0, 44.0)
	_action_button.pressed.connect(_on_action_pressed)
	vbox.add_child(_action_button)


## tr(&"KEY") explícito (no key cruda): a diferencia de los overlays persistentes
## (SettingsScreen/PauseScreen), estos labels se reasignan en cada transición de paso, y
## no hay forma de cambiar de idioma durante el tutorial (no instancia SettingsScreen).
func _advance_to(step: Step) -> void:
	_step = step
	match step:
		Step.WELCOME:
			_title_label.text = tr(&"TUTORIAL_WELCOME_TITLE")
			_hint_label.text = tr(&"TUTORIAL_WELCOME_HINT")
			_action_button.text = tr(&"BTN_START")
			_action_button.show()
		Step.AIM_SHOOT:
			_title_label.text = tr(&"TUTORIAL_AIM_TITLE")
			_hint_label.text = tr(&"TUTORIAL_AIM_HINT")
			_action_button.hide()
			EventBus.burst_fired.connect(_on_burst_fired, CONNECT_ONE_SHOT)
		Step.WATCH_RETURN:
			_title_label.text = tr(&"TUTORIAL_RETURN_TITLE")
			_hint_label.text = tr(&"TUTORIAL_RETURN_HINT")
			EventBus.all_seeds_returned.connect(_on_all_seeds_returned, CONNECT_ONE_SHOT)
		Step.ADVANCE:
			_title_label.text = tr(&"TUTORIAL_ADVANCE_TITLE")
			_hint_label.text = tr(&"TUTORIAL_ADVANCE_HINT")
			_action_button.text = tr(&"BTN_UNDERSTOOD")
			_action_button.show()
		Step.COMPLETE:
			_title_label.text = tr(&"TUTORIAL_COMPLETE_TITLE")
			_hint_label.text = tr(&"TUTORIAL_COMPLETE_HINT")
			_action_button.text = tr(&"BTN_PLAY")
			_action_button.show()


func _on_action_pressed() -> void:
	match _step:
		Step.WELCOME:
			_advance_to(Step.AIM_SHOOT)
		Step.ADVANCE:
			_advance_to(Step.COMPLETE)
		Step.COMPLETE:
			SaveManager.set_tutorial_shown(true)
			get_tree().change_scene_to_file.call_deferred(GAME_SCENE)


func _on_burst_fired(_seed_count: int) -> void:
	_advance_to(Step.WATCH_RETURN)


func _on_all_seeds_returned(_landing_x: float) -> void:
	_advance_to(Step.ADVANCE)


func _on_game_over(_final_score: int, _wave_reached: int) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(TUTORIAL_SCENE)


func _on_restart_requested() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(TUTORIAL_SCENE)


func _on_main_menu_requested() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(MAIN_MENU_SCENE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		GameManager.pause_game()
