extends Area2D
## Semilla Extra +1 (GDD sección 3): "Ícono de semilla brillante. Al tocarlo, se añade
## permanentemente +1 semilla al inventario del jugador para el resto del nivel. El
## ícono vuela hacia el contador del molcajete." Ícono de un solo uso.
## Sin sprite todavía (ver /gen-ai-art) — se dibuja procedural con _draw().

var _radius: float = 14.0


func setup(p_cell_size: float) -> void:
	_radius = p_cell_size * 0.28
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
	# Semilla estilizada: óvalo alargado con brillo — sin sprite (ver /gen-ai-art).
	draw_circle(Vector2.ZERO, _radius, Constants.COLOR_SEED_EXTRA)
	var highlight_offset: Vector2 = Vector2(-_radius * 0.3, -_radius * 0.35)
	draw_circle(highlight_offset, _radius * 0.35, Color(1.0, 1.0, 1.0, 0.85))


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(&"seeds"):
		return
	EventBus.seed_extra_touched.emit(global_position)
	queue_free()
