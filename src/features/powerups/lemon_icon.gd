extends Area2D
## Limón Ácido (GDD sección 3): "Ícono circular estático. Al tocarlo, la semilla
## actual se duplica temporalmente en dos semillas con ángulos opuestos. Destello
## verde brillante." Ícono de un solo uso: se destruye tras activarse.
## Sin sprite todavía (ver /gen-ai-art) — se dibuja procedural con _draw().

var _radius: float = 16.0


func setup(p_cell_size: float) -> void:
	_radius = p_cell_size * 0.32
	collision_layer = Constants.LAYER_PICKUPS
	collision_mask = Constants.LAYER_SEEDS
	monitoring = true
	monitorable = false
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = _radius
	var col: CollisionShape2D = CollisionShape2D.new()
	col.name = &"CollisionShape2D"
	col.shape = shape
	add_child(col)
	queue_redraw()


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _draw() -> void:
	draw_circle(Vector2.ZERO, _radius, Constants.COLOR_LEMON)
	draw_circle(Vector2.ZERO, _radius * 0.5, Constants.COLOR_LEMON.lightened(0.5))


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(&"seeds"):
		return
	if body.has_method(&"trigger_lemon_split"):
		body.call(&"trigger_lemon_split")
	EventBus.lemon_triggered.emit(global_position)
	queue_free()
