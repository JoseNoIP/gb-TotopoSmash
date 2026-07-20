extends Area2D
## Láser (power-up nuevo, pedido explícito del usuario): ícono que al ser tocado por una
## semilla dispara un golpe en línea recta (horizontal o vertical, fija por instancia,
## decidida por quien arma el nivel) a TODOS los bloques de esa fila/columna —
## Constants.LASER_DAMAGE de daño, mismo mecanismo de daño explícito que el Frasco de Salsa
## (take_explosion_damage), solo que en línea recta en vez de en cruz. Ícono de un solo uso.

const TEXTURE_PATH: String = "res://assets/sprites/powerup_icons/laser.png"

var grid_pos: Vector2i = Vector2i.ZERO
var is_horizontal: bool = true
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


## Sin sprite: un rombo alargado en la orientación real del láser, para que el jugador
## pueda distinguir "va a disparar horizontal" de "va a disparar vertical" ANTES de
## tocarlo (no es información oculta).
func _draw() -> void:
	if _has_sprite:
		return
	draw_circle(Vector2.ZERO, _radius * 0.6, Constants.COLOR_LASER)
	var beam_half_length: float = _radius * 1.4
	var beam_half_width: float = _radius * 0.18
	var extent: Vector2 = (
		Vector2(beam_half_length, beam_half_width)
		if is_horizontal
		else Vector2(beam_half_width, beam_half_length)
	)
	draw_rect(Rect2(-extent, extent * 2.0), Constants.COLOR_LASER)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(&"seeds"):
		return
	EventBus.laser_triggered.emit(grid_pos, is_horizontal)
	queue_free()
