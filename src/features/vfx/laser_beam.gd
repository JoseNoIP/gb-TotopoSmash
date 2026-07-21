extends Node2D
## Rayo visual del power-up láser (pedido explícito del usuario: "se vea una línea
## horizontal, vertical o ambas que está golpeando todos los ladrillos", no solo un
## destello puntual en el origen — ver vfx_spawner.gd). Puramente visual: el daño real ya
## lo aplica BoardManager._on_laser_triggered() vía EventBus; esto solo dibuja la línea y
## se autodestruye sola.

var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _color: Color = Color.WHITE


func setup(from: Vector2, to: Vector2, color: Color, lifetime: float) -> void:
	_from = from
	_to = to
	_color = color
	queue_redraw()
	var tween: Tween = create_tween()
	tween.tween_property(self, ^"modulate:a", 0.0, lifetime)
	tween.tween_callback(queue_free)


func _draw() -> void:
	## Núcleo brillante blanco + halo de color del láser, más ancho — mismo truco visual
	## que danger_line.gd usa para su glow, pero como una sola línea recta.
	draw_line(_from, _to, _color, Constants.VFX_LASER_BEAM_WIDTH)
	draw_line(_from, _to, Color(1.0, 1.0, 1.0, 0.85), Constants.VFX_LASER_BEAM_WIDTH * 0.35)
