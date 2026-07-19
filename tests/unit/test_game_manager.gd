extends GutTest
## Tests para GameManager (autoload real). El singleton persiste durante toda la corrida
## de tests (los autoloads no se recrean por test), así que before_each() lo resetea con
## start_game() para evitar contaminación entre casos.


func before_each() -> void:
	GameManager.start_game()


func test_start_game_resets_score_and_wave_and_sets_playing() -> void:
	GameManager.add_score(500)
	GameManager.start_game()
	assert_eq(GameManager.get_score(), 0, "score debe reiniciar a 0")
	assert_eq(GameManager.get_wave(), 1, "wave debe reiniciar a 1")
	assert_true(GameManager.is_playing(), "start_game debe dejar el estado en PLAYING")


func test_pause_then_resume_round_trips_state_and_tree_pause() -> void:
	GameManager.pause_game()
	assert_eq(GameManager.get_state(), GameManager.State.PAUSED)
	assert_true(get_tree().paused, "pause_game debe pausar el SceneTree")
	GameManager.resume_game()
	assert_eq(GameManager.get_state(), GameManager.State.PLAYING)
	assert_false(get_tree().paused, "resume_game debe reanudar el SceneTree")


func test_pause_game_is_noop_when_not_playing() -> void:
	EventBus.board_reached_bottom.emit()  # fuerza GAME_OVER
	var state_before: int = GameManager.get_state()
	GameManager.pause_game()
	assert_eq(GameManager.get_state(), state_before, "pause_game no debe actuar fuera de PLAYING")


func test_resume_game_is_noop_when_not_paused() -> void:
	assert_true(GameManager.is_playing())
	GameManager.resume_game()
	assert_true(GameManager.is_playing(), "resume_game no debe actuar si no estaba en PAUSED")


func test_add_score_accumulates_while_playing() -> void:
	GameManager.add_score(10)
	GameManager.add_score(25)
	assert_eq(GameManager.get_score(), 35)


func test_add_score_ignored_when_not_playing() -> void:
	EventBus.board_reached_bottom.emit()  # fuerza GAME_OVER
	var score_before: int = GameManager.get_score()
	GameManager.add_score(999)
	assert_eq(GameManager.get_score(), score_before, "no debe sumar puntaje fuera de PLAYING")


func test_wave_advanced_awards_bonus_only_when_wave_actually_increases() -> void:
	var score_after_start: int = GameManager.get_score()
	EventBus.wave_advanced.emit(1)  # mismo wave que ya trae desde start_game(): sin bono
	assert_eq(GameManager.get_score(), score_after_start, "wave 1 repetido no debe otorgar bono")
	EventBus.wave_advanced.emit(2)
	assert_eq(GameManager.get_wave(), 2)
	assert_eq(GameManager.get_score(), score_after_start + Constants.SCORE_PER_WAVE_CLEARED)


func test_block_destroyed_adds_its_score_value() -> void:
	var score_before: int = GameManager.get_score()
	EventBus.block_destroyed.emit(Vector2i(0, 0), "totopo", 30)
	assert_eq(GameManager.get_score(), score_before + 30)


func test_board_reached_bottom_ends_game_and_emits_game_over() -> void:
	GameManager.add_score(123)
	watch_signals(EventBus)
	EventBus.board_reached_bottom.emit()
	assert_eq(GameManager.get_state(), GameManager.State.GAME_OVER)
	assert_signal_emitted(EventBus, "game_over")


func test_board_reached_bottom_updates_best_score_when_higher() -> void:
	var current_best: int = SaveManager.get_best_score()
	GameManager.add_score(current_best + 50)
	watch_signals(EventBus)
	EventBus.board_reached_bottom.emit()
	assert_eq(SaveManager.get_best_score(), current_best + 50)
	assert_signal_emitted(EventBus, "high_score_updated")


## Regresión explícita (Modo Nivel): start_game() sin argumentos sigue siendo Modo
## Infinito de siempre — los dos call-sites reales (Game.gd, TutorialGame.gd) no cambian.
func test_start_game_with_no_args_defaults_to_infinity_mode() -> void:
	GameManager.start_game()
	assert_false(GameManager.is_level_mode())
	assert_eq(GameManager.get_current_level_id(), "")


func test_start_game_with_level_id_sets_level_mode() -> void:
	GameManager.start_game("level_001")
	assert_true(GameManager.is_level_mode())
	assert_eq(GameManager.get_current_level_id(), "level_001")
	GameManager.start_game()  # deja Infinito para no contaminar otros tests


func test_level_cleared_sets_level_complete_state_and_emits_level_completed() -> void:
	GameManager.start_game("level_001")
	GameManager.add_score(77)
	watch_signals(EventBus)
	EventBus.level_cleared.emit("level_001")
	assert_eq(GameManager.get_state(), GameManager.State.LEVEL_COMPLETE)
	assert_signal_emitted_with_parameters(EventBus, "level_completed", ["level_001", 77])
	GameManager.start_game()


func test_level_cleared_ignored_when_not_playing() -> void:
	GameManager.start_game("level_001")
	EventBus.board_reached_bottom.emit()  # fuerza GAME_OVER
	var state_before: int = GameManager.get_state()
	watch_signals(EventBus)
	EventBus.level_cleared.emit("level_001")
	assert_eq(GameManager.get_state(), state_before, "level_cleared no debe actuar fuera de PLAYING")
	assert_signal_not_emitted(EventBus, "level_completed")
	GameManager.start_game()
