extends Node2D
## Escucha eventos globales de destrucción (GDD sección 5, "Satisfacción del Crujido") y
## dispara ráfagas de crumb_particle.gd: migajas amarillo/naranja al destruir un bloque,
## salpicadura roja al explotar un Frasco de Salsa. Puramente reactivo — no conoce la
## matriz del tablero, solo convierte grid_pos -> píxeles con grid_math.gd.

const GridMathGd := preload("res://src/shared/grid_math.gd")
const CrumbParticleGd := preload("res://src/features/vfx/crumb_particle.gd")

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	EventBus.block_destroyed.connect(_on_block_destroyed)
	EventBus.salsa_exploded.connect(_on_salsa_exploded)
	EventBus.laser_triggered.connect(_on_laser_triggered)


func _on_block_destroyed(grid_pos: Vector2i, block_type: String, _score_value: int) -> void:
	var color: Color = Constants.COLOR_QUESO if block_type == "queso" else Constants.COLOR_TOTOPO
	var amount: int = Constants.VFX_CRUMB_AMOUNT
	var lifetime: float = Constants.VFX_CRUMB_LIFETIME
	_spawn_burst(_grid_to_pixel(grid_pos), color, amount, lifetime, 90.0)


func _on_salsa_exploded(grid_pos: Vector2i) -> void:
	var amount: int = Constants.VFX_SAUCE_AMOUNT
	var lifetime: float = Constants.VFX_SAUCE_LIFETIME
	_spawn_burst(_grid_to_pixel(grid_pos), Constants.COLOR_SALSA, amount, lifetime, 160.0)


## Pedido explícito del usuario: "faltó agregarle algún efecto visual... al power-up de
## láser". Ráfaga de partículas magenta en el punto de origen (mismo patrón que la salsa)
## — no dibuja la línea completa que recorre toda la fila/columna (sería un cambio de VFX
## mucho más grande) pero sí confirma visualmente que el láser se activó, cada vez que se
## toca (persistente, ver laser_icon.gd).
func _on_laser_triggered(grid_pos: Vector2i, _orientation: String) -> void:
	var amount: int = Constants.VFX_LASER_AMOUNT
	var lifetime: float = Constants.VFX_LASER_LIFETIME
	_spawn_burst(_grid_to_pixel(grid_pos), Constants.COLOR_LASER, amount, lifetime, 220.0)


func _grid_to_pixel(grid_pos: Vector2i) -> Vector2:
	return Vector2(
		GridMathGd.col_to_x(grid_pos.x, Constants.DESIGN_WIDTH),
		GridMathGd.row_to_y(grid_pos.y, Constants.DESIGN_WIDTH)
	)


func _spawn_burst(pos: Vector2, color: Color, amount: int, lifetime: float, speed: float) -> void:
	for _i: int in amount:
		var angle: float = _rng.randf_range(0.0, TAU)
		var this_speed: float = _rng.randf_range(speed * 0.4, speed)
		var velocity: Vector2 = Vector2(cos(angle), sin(angle)) * this_speed
		var particle: Node2D = CrumbParticleGd.new()
		add_child(particle)
		particle.position = pos
		particle.call(&"setup", color, _rng.randf_range(2.0, 4.0), velocity, lifetime)
