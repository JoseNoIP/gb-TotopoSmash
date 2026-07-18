extends Node
## Game state machine. Owns the game lifecycle: idle → playing → paused → over.
## TEMPLATE: Expand states and transitions for your game's specific flow.

enum State { IDLE, PLAYING, PAUSED, GAME_OVER }

var _state: State = State.IDLE


func _ready() -> void:
	EventBus.game_over.connect(_on_game_over)


func start_game() -> void:
	_state = State.PLAYING
	EventBus.game_started.emit()


func end_game(won: bool) -> void:
	if _state != State.PLAYING:
		return
	_state = State.GAME_OVER
	EventBus.game_over.emit(won)


func is_playing() -> bool:
	return _state == State.PLAYING


func _on_game_over(_won: bool) -> void:
	_state = State.GAME_OVER
