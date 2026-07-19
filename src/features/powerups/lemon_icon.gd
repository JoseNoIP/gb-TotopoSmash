extends Area2D
## Limón Ácido (GDD sección 3): "Ícono circular estático. Al tocarlo, la semilla
## actual se duplica temporalmente en dos semillas con ángulos opuestos. Destello
## verde brillante." Ícono de un solo uso: se destruye tras activarse.

const TEXTURE_PATH: String = "res://assets/sprites/powerup_icons/lemon.png"

var _radius: float = 16.0
var _has_sprite: bool = false


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
	draw_circle(Vector2.ZERO, _radius, Constants.COLOR_LEMON)
	draw_circle(Vector2.ZERO, _radius * 0.5, Constants.COLOR_LEMON.lightened(0.5))


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(&"seeds"):
		return
	if body.has_method(&"trigger_lemon_split"):
		body.call(&"trigger_lemon_split")
	EventBus.lemon_triggered.emit(global_position)
	queue_free()
