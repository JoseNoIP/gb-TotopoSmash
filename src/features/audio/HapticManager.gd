extends Node
## Feedback háptico sutil (GDD sección 5): SOLO vibra cuando un bloque se destruye
## por completo o cuando explota un Frasco de Salsa. Nunca en rebotes normales.


func _ready() -> void:
	EventBus.block_destroyed.connect(_on_block_destroyed)
	EventBus.salsa_exploded.connect(_on_salsa_exploded)


func vibrate(duration_msec: int) -> void:
	if not SaveManager.get_vibration_enabled():
		return
	Input.vibrate_handheld(duration_msec)


func _on_block_destroyed(_grid_pos: Vector2i, _block_type: String, _score_value: int) -> void:
	vibrate(Constants.HAPTIC_BLOCK_DESTROYED_MS)


func _on_salsa_exploded(_grid_pos: Vector2i) -> void:
	vibrate(Constants.HAPTIC_SALSA_EXPLOSION_MS)
