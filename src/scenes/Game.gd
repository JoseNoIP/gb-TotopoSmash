extends Node2D
## Escena raíz de gameplay (GDD completo). Construcción 100% programática — sin sprites
## de fondo todavía (ver /gen-ai-art); fondo es un ColorRect con el color de la sección 5
## del GDD. Instancia todos los sistemas y pantallas de overlay, y conecta la navegación
## de escena (reintentar / menú principal) que las pantallas piden por señal local.

const BoardManagerGd := preload("res://src/features/board/board_manager.gd")
const TurnManagerGd := preload("res://src/features/board/turn_manager.gd")
const WorldBoundsGd := preload("res://src/features/board/world_bounds.gd")
const MortarGd := preload("res://src/features/player/mortar.gd")
const VfxSpawnerGd := preload("res://src/features/vfx/vfx_spawner.gd")
const HudGd := preload("res://src/features/ui/HUD.gd")
const PauseScreenGd := preload("res://src/features/ui/PauseScreen.gd")
const GameOverScreenGd := preload("res://src/features/ui/GameOverScreen.gd")
const SettingsScreenGd := preload("res://src/features/ui/SettingsScreen.gd")

const MAIN_MENU_SCENE: String = "res://src/scenes/MainMenu.tscn"
const GAME_SCENE: String = "res://src/scenes/Game.tscn"


func _ready() -> void:
	_build_scene()
	GameManager.start_game()
	EventBus.game_over.connect(_on_game_over)


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
	add_child(MortarGd.new())
	add_child(VfxSpawnerGd.new())
	add_child(HudGd.new())

	var pause_screen: CanvasLayer = PauseScreenGd.new()
	add_child(pause_screen)
	pause_screen.connect(&"restart_requested", _on_restart_requested)
	pause_screen.connect(&"main_menu_requested", _on_main_menu_requested)

	var game_over_screen: CanvasLayer = GameOverScreenGd.new()
	add_child(game_over_screen)
	game_over_screen.connect(&"restart_requested", _on_restart_requested)
	game_over_screen.connect(&"main_menu_requested", _on_main_menu_requested)

	add_child(SettingsScreenGd.new())


func _on_game_over(_final_score: int, _wave_reached: int) -> void:
	SaveManager.increment_total_games_played()


func _on_restart_requested() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(GAME_SCENE)


func _on_main_menu_requested() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(MAIN_MENU_SCENE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		GameManager.pause_game()
