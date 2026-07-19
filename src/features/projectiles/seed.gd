extends CharacterBody2D
## Semilla (GDD sección 2, "Fase de Rebote"): rebota con física elástica perfecta
## (e=1.0) contra paredes, techo y bloques. La reflexión se implementa a mano en
## physics_math.gd (ver ese archivo para el porqué). El "piso" NO es un cuerpo físico:
## se detecta por posición Y (ver launch()/_check_floor()) porque el molcajete real
## ocupa ese espacio y porque simplifica evitar falsos rebotes ahí.
##
## Dueño de esta instancia: TurnManager (quien la crea, la agrega al árbol y escucha
## `landed`/`split_requested`). Sin señales por EventBus para estas dos: son 1:1 con
## quien la disparó, no un evento global de interés para otras features.

signal landed(seed_node: Node2D, x_position: float)
signal split_requested(mirrored_velocity: Vector2)

const PhysicsMathGd := preload("res://src/shared/physics_math.gd")
const MAX_ITERATIONS_PER_FRAME: int = 4
const TEXTURE_PATH: String = "res://assets/sprites/seed.png"

## `velocity` NO se redeclara aquí: CharacterBody2D ya expone `velocity: Vector2` de forma
## nativa. Declarar `var velocity` propio causa "Member velocity redefined" en tiempo de
## compilación (Godot 4 no permite sombrear miembros de la clase base). No usamos
## move_and_slide() pero el campo heredado sigue siendo un Vector2 normal y corriente que
## podemos leer/escribir libremente.

var _base_speed: float = Constants.SEED_SPEED
var _floor_y: float = 0.0
var _landed: bool = false
var _bounce_count: int = 0
var _has_sprite: bool = false
var _boosted: bool = false


func _ready() -> void:
	add_to_group(&"seeds")
	collision_layer = Constants.LAYER_SEEDS
	collision_mask = Constants.LAYER_WORLD | Constants.LAYER_BLOCKS
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = Constants.SEED_RADIUS
	var col: CollisionShape2D = CollisionShape2D.new()
	col.name = &"CollisionShape2D"
	col.shape = shape
	add_child(col)
	_build_sprite()
	EventBus.seed_boost_changed.connect(_on_seed_boost_changed)


func _exit_tree() -> void:
	EventBus.seed_boost_changed.disconnect(_on_seed_boost_changed)


func _on_seed_boost_changed(active: bool) -> void:
	_boosted = active


func _build_sprite() -> void:
	if not ResourceLoader.exists(TEXTURE_PATH):
		return
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = load(TEXTURE_PATH)
	var diameter: float = Constants.SEED_RADIUS * 2.0
	var tex_size: Vector2 = sprite.texture.get_size()
	sprite.scale = Vector2(diameter / tex_size.x, diameter / tex_size.y)
	add_child(sprite)
	_has_sprite = true


## Debe llamarse justo después de instanciar (antes o después de add_child, ambos
## funcionan porque no depende de estar en el árbol todavía).
func launch(origin: Vector2, direction: Vector2, speed: float, floor_y: float) -> void:
	global_position = origin
	_base_speed = speed
	velocity = direction.normalized() * speed
	_floor_y = floor_y


## Boost (acelerar semillas mientras rebotan, ver mortar.gd): escala el delta efectivo de
## ESTA semilla en vez de Engine.time_scale global — así no acelera de rebote los tweens
## (BoardManager._tween_to_row, Mortar._on_molcajete_position_changed) ni Timers
## (TurnManager._fire_timer) que deben seguir a velocidad normal. move_and_collide() es
## una consulta de movimiento continua/barrida — no puede "atravesar" un bloque aunque
## remaining sea grande. El único riesgo real es necesitar más de las iteraciones de
## rebote habituales dentro de un mismo frame en pasillos angostos; se duplica el tope
## mientras está boosteada para evitar un frenón visible.
func _physics_process(delta: float) -> void:
	if _landed:
		return
	var eff_delta: float = delta * Constants.SEED_BOOST_MULTIPLIER if _boosted else delta
	var max_iterations: int = MAX_ITERATIONS_PER_FRAME * 2 if _boosted else MAX_ITERATIONS_PER_FRAME
	var remaining: Vector2 = velocity * eff_delta
	var iterations: int = 0
	while remaining.length() > 0.01 and iterations < max_iterations:
		var collision: KinematicCollision2D = move_and_collide(remaining)
		if collision == null:
			break
		_handle_collision(collision)
		remaining = PhysicsMathGd.reflect(collision.get_remainder(), collision.get_normal())
		iterations += 1
	if global_position.y >= _floor_y:
		_land()


func _handle_collision(collision: KinematicCollision2D) -> void:
	velocity = PhysicsMathGd.reflect(velocity, collision.get_normal())
	_bounce_count += 1
	if _bounce_count >= Constants.SEED_MAX_BOUNCES_SAFETY:
		_land()
		return
	var collider: Object = collision.get_collider()
	## block_type es "" para paredes/techo (WorldBounds no tiene esa propiedad); Object.get()
	## de una propiedad inexistente devuelve null sin error, así que es seguro sin has_method.
	var type_value: Variant = collider.get(&"block_type") if collider != null else null
	EventBus.seed_bounced.emit(type_value if type_value is String else "")
	if collider == null:
		return
	if collider.has_method(&"on_seed_bounce"):
		collider.call(&"on_seed_bounce", self)
	if collider.has_method(&"take_damage"):
		collider.call(&"take_damage")


## Usado por QuesoBlock.on_seed_bounce() — frena la semilla con un piso mínimo relativo
## a su velocidad de disparo original (Constants.SEED_MIN_SPEED_RATIO).
func apply_speed_ratio(ratio: float) -> void:
	var min_ratio: float = Constants.SEED_MIN_SPEED_RATIO
	velocity = PhysicsMathGd.apply_speed_ratio(velocity, ratio, _base_speed, min_ratio)


## Usado por LemonIcon — parte el rumbo actual en dos ángulos simétricos opuestos.
## Esta semilla sigue con +offset; split_requested lleva la velocidad para la clonada
## (-offset), que TurnManager instancia (es quien sabe cómo crear/conectar semillas).
func trigger_lemon_split() -> void:
	var offset: float = deg_to_rad(Constants.LEMON_SPLIT_ANGLE_DEG)
	var mirrored: Vector2 = PhysicsMathGd.rotate_velocity(velocity, -offset)
	velocity = PhysicsMathGd.rotate_velocity(velocity, offset)
	split_requested.emit(mirrored)


func _land() -> void:
	if _landed:
		return
	_landed = true
	landed.emit(self, global_position.x)
	queue_free()


func _draw() -> void:
	if _has_sprite:
		return
	draw_circle(Vector2.ZERO, Constants.SEED_RADIUS, Constants.COLOR_SEED_TRAIL)
	draw_circle(Vector2(-1.5, -1.5), Constants.SEED_RADIUS * 0.35, Color(1.0, 1.0, 1.0, 0.8))
