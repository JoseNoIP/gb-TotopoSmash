extends Area2D
## Semilla Extra +1 (GDD sección 3): "Ícono de semilla brillante. Al tocarlo, se añade
## permanentemente +1 semilla al inventario del jugador para el resto del nivel. El
## ícono vuela hacia el contador del molcajete." Ícono de un solo uso.

const TEXTURE_PATH: String = "res://assets/sprites/powerup_icons/seed_extra.png"

var _radius: float = 14.0
var _has_sprite: bool = false


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
	_build_sprite()
	queue_redraw()


func _build_sprite() -> void:
	if not ResourceLoader.exists(TEXTURE_PATH):
		return
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = load(TEXTURE_PATH)
	var diameter: float = _radius * 2.0
	var tex_size: Vector2 = sprite.texture.get_size()
	sprite.scale = Vector2(diameter / tex_size.x, diameter / tex_size.y)
	add_child(sprite)
	_has_sprite = true


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _draw() -> void:
	if _has_sprite:
		return
	draw_circle(Vector2.ZERO, _radius, Constants.COLOR_SEED_EXTRA)
	var highlight_offset: Vector2 = Vector2(-_radius * 0.3, -_radius * 0.35)
	draw_circle(highlight_offset, _radius * 0.35, Color(1.0, 1.0, 1.0, 0.85))


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(&"seeds"):
		return
	EventBus.seed_extra_touched.emit(global_position)
	queue_free()
