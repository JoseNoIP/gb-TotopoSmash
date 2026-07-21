extends Area2D
## Láser (power-up, pedido explícito del usuario): al ser tocado por una semilla, dispara
## un golpe a TODOS los bloques de su fila, columna, o AMBAS (según `orientation`) —
## Constants.LASER_DAMAGE de daño explícito, mismo mecanismo que el Frasco de Salsa pero en
## línea(s) recta(s) en vez de en cruz.
##
## PERSISTENTE (pedido explícito del usuario: "los elementos láser no deben desaparecer
## al primer toque de una semilla... debe permanecer y ejecutarse cada vez que una semilla
## lo toque") — a diferencia de LemonIcon/SeedExtraIcon (un solo uso, `queue_free()` al
## tocarse), este ícono NUNCA se libera solo; sigue en el tablero disparando cada vez que
## una semilla vuelve a entrar en su área.

const TEXTURE_PATH_HORIZONTAL: String = "res://assets/sprites/powerup_icons/laser_horizontal.png"
const TEXTURE_PATH_VERTICAL: String = "res://assets/sprites/powerup_icons/laser_vertical.png"
const TEXTURE_PATH_BOTH: String = "res://assets/sprites/powerup_icons/laser_both.png"

const ORIENTATION_HORIZONTAL: String = "horizontal"
const ORIENTATION_VERTICAL: String = "vertical"
const ORIENTATION_BOTH: String = "both"

var grid_pos: Vector2i = Vector2i.ZERO
var orientation: String = ORIENTATION_HORIZONTAL
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
	var texture_path: String = TEXTURE_PATH_HORIZONTAL
	if orientation == ORIENTATION_VERTICAL:
		texture_path = TEXTURE_PATH_VERTICAL
	elif orientation == ORIENTATION_BOTH:
		texture_path = TEXTURE_PATH_BOTH
	if not ResourceLoader.exists(texture_path):
		return
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = load(texture_path)
	var diameter: float = _radius * 2.0
	var tex_size: Vector2 = sprite.texture.get_size()
	sprite.scale = Vector2(diameter / tex_size.x, diameter / tex_size.y)
	add_child(sprite)
	_has_sprite = true


func _ready() -> void:
	body_entered.connect(_on_body_entered)


## Sin sprite: un rombo alargado en la orientación real del láser (o una cruz completa si
## `orientation == "both"`), para que el jugador pueda distinguir el alcance real ANTES de
## tocarlo (no es información oculta).
func _draw() -> void:
	if _has_sprite:
		return
	draw_circle(Vector2.ZERO, _radius * 0.6, Constants.COLOR_LASER)
	var beam_half_length: float = _radius * 1.4
	var beam_half_width: float = _radius * 0.18
	if orientation != ORIENTATION_VERTICAL:
		var h_extent := Vector2(beam_half_length, beam_half_width)
		draw_rect(Rect2(-h_extent, h_extent * 2.0), Constants.COLOR_LASER)
	if orientation != ORIENTATION_HORIZONTAL:
		var v_extent := Vector2(beam_half_width, beam_half_length)
		draw_rect(Rect2(-v_extent, v_extent * 2.0), Constants.COLOR_LASER)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(&"seeds"):
		return
	EventBus.laser_triggered.emit(grid_pos, orientation)
