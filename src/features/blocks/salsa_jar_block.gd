extends "res://src/features/blocks/block_base.gd"
## Frasco de Salsa (GDD sección 3): "Bloque explosivo. Al llegar a 0, explota y causa
## 10 puntos de daño a todos los bloques adyacentes en cruz. Parpadea en rojo antes de
## estallar." BoardManager escucha EventBus.salsa_exploded y aplica el daño en cruz
## (dueño de la matriz del tablero) — este script solo decide CUÁNDO explota.

var _is_warning: bool = false
var _blink_tween: Tween = null


func _ready() -> void:
	block_type = "salsa"


func _update_visual() -> void:
	super._update_visual()
	if is_indestructible or current_hp <= 0:
		return
	if current_hp <= Constants.BLOCK_SALSA_WARNING_HP and not _is_warning:
		_start_warning_blink()


func _start_warning_blink() -> void:
	var visual: ColorRect = _visual as ColorRect
	if visual == null:
		return
	_is_warning = true
	_blink_tween = create_tween()
	_blink_tween.set_loops()
	_blink_tween.tween_property(visual, ^"modulate", Color(2.2, 2.2, 2.2), 0.15)
	_blink_tween.tween_property(visual, ^"modulate", Color.WHITE, 0.15)


func _die() -> void:
	if _blink_tween and _blink_tween.is_valid():
		_blink_tween.kill()
	EventBus.salsa_exploded.emit(grid_pos)
	super._die()


func _get_color() -> Color:
	return Constants.COLOR_SALSA
