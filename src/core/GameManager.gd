extends Node
## Máquina de estados de la partida. Dueño del score, la oleada actual (Modo Infinito) y
## el nivel activo (Modo Nivel — ver LevelManager/level_loader.gd). Modo Infinito: sin
## condición de victoria, progresión infinita por oleadas (diseño original del GDD).
## Modo Nivel: sí existe victoria (LEVEL_COMPLETE) — destruir todos los bloques
## destructibles antes de que el tablero llegue a la fila del molcajete.

enum State { MENU, PLAYING, PAUSED, GAME_OVER, LEVEL_COMPLETE }

var _state: State = State.MENU
var _score: int = 0
var _wave: int = 1
var _current_level_id: String = ""


func _ready() -> void:
	EventBus.board_reached_bottom.connect(_on_board_reached_bottom)
	EventBus.level_cleared.connect(_on_level_cleared)
	EventBus.wave_advanced.connect(_on_wave_advanced)
	EventBus.block_destroyed.connect(_on_block_destroyed)


## level_id = "" (default) → Modo Infinito, igual que siempre. Los call-sites existentes
## (Game.gd, TutorialGame.gd) llaman start_game() sin argumentos y no cambian.
func start_game(level_id: String = "") -> void:
	_state = State.PLAYING
	_score = 0
	_wave = 1
	_current_level_id = level_id
	get_tree().paused = false
	EventBus.game_started.emit()
	EventBus.score_changed.emit(_score)


func get_current_level_id() -> String:
	return _current_level_id


func is_level_mode() -> bool:
	return not _current_level_id.is_empty()


func pause_game() -> void:
	if _state != State.PLAYING:
		return
	_state = State.PAUSED
	get_tree().paused = true
	EventBus.game_paused.emit()


func resume_game() -> void:
	if _state != State.PAUSED:
		return
	_state = State.PLAYING
	get_tree().paused = false
	EventBus.game_resumed.emit()


func add_score(amount: int) -> void:
	if _state != State.PLAYING:
		return
	_score += amount
	EventBus.score_changed.emit(_score)


func get_score() -> int:
	return _score


func get_wave() -> int:
	return _wave


func get_state() -> State:
	return _state


func is_playing() -> bool:
	return _state == State.PLAYING


func _on_wave_advanced(wave_number: int) -> void:
	## BoardManager emite wave_advanced(1) también al armar el tablero inicial; ese primer
	## aviso no debe otorgar el bono de "oleada superada" (el jugador aún no jugó nada).
	if wave_number > _wave:
		add_score(Constants.SCORE_PER_WAVE_CLEARED)
	_wave = wave_number


func _on_block_destroyed(_grid_pos: Vector2i, _block_type: String, score_value: int) -> void:
	add_score(score_value)


func _on_board_reached_bottom() -> void:
	if _state != State.PLAYING:
		return
	_state = State.GAME_OVER
	var is_new_best: bool = SaveManager.set_best_score_if_higher(_score)
	SaveManager.set_max_wave_if_higher(_wave)
	if is_new_best:
		EventBus.high_score_updated.emit(_score)
	EventBus.game_over.emit(_score, _wave)


func _on_level_cleared(level_id: String) -> void:
	if _state != State.PLAYING:
		return
	_state = State.LEVEL_COMPLETE
	LevelManager.mark_level_completed(level_id)
	var is_new_best: bool = SaveManager.set_best_score_if_higher(_score)
	if is_new_best:
		EventBus.high_score_updated.emit(_score)
	EventBus.level_completed.emit(level_id, _score)
