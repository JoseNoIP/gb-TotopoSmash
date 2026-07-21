extends Node2D
## Escucha eventos globales de destrucción (GDD sección 5, "Satisfacción del Crujido") y
## dispara ráfagas de crumb_particle.gd: migajas amarillo/naranja al destruir un bloque,
## salpicadura roja al explotar un Frasco de Salsa, chispas magenta al tocar un láser.
## Puramente reactivo — no conoce la matriz del tablero, delega la conversión
## grid_pos -> píxeles a BoardManager.grid_to_pixel() (bug real corregido: este script
## antes hacía su propia conversión asumiendo siempre la grilla normal de 7 columnas, que
## da resultados incorrectos en un nivel `static` con su propia grilla — detectado con
## captura real al agregar el VFX del láser, pero afectaba a TODOS los VFX por igual).

const CrumbParticleGd := preload("res://src/features/vfx/crumb_particle.gd")
const LaserBeamGd := preload("res://src/features/vfx/laser_beam.gd")
const LaserIconGd := preload("res://src/features/powerups/laser_icon.gd")

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
## láser" y, después, "solo se ve un pequeño destello... lo esperado es que se vea una
## línea horizontal, vertical o ambas que está golpeando todos los ladrillos" — ráfaga de
## partículas magenta en el punto de origen (feedback de "toque") + un rayo real
## (laser_beam.gd) que recorre toda la fila/columna que el láser afecta de verdad (mismo
## alcance que BoardManager._on_laser_triggered(), que ya calcula hits_row/hits_col).
func _on_laser_triggered(grid_pos: Vector2i, orientation: String) -> void:
	var amount: int = Constants.VFX_LASER_AMOUNT
	var lifetime: float = Constants.VFX_LASER_LIFETIME
	_spawn_burst(_grid_to_pixel(grid_pos), Constants.COLOR_LASER, amount, lifetime, 220.0)
	_spawn_beams(grid_pos, orientation)


func _spawn_beams(grid_pos: Vector2i, orientation: String) -> void:
	var board: Node = get_tree().get_first_node_in_group(&"board_manager")
	if board == null:
		return
	var dims: Vector2i = board.call(&"get_grid_dimensions") as Vector2i
	if orientation != LaserIconGd.ORIENTATION_VERTICAL:
		var row_from: Vector2 = board.call(&"grid_to_pixel", Vector2i(0, grid_pos.y)) as Vector2
		var row_to: Vector2 = board.call(&"grid_to_pixel", Vector2i(dims.x - 1, grid_pos.y)) as Vector2
		_spawn_beam(row_from, row_to)
	if orientation != LaserIconGd.ORIENTATION_HORIZONTAL:
		var col_from: Vector2 = board.call(&"grid_to_pixel", Vector2i(grid_pos.x, 0)) as Vector2
		var col_to: Vector2 = board.call(&"grid_to_pixel", Vector2i(grid_pos.x, dims.y - 1)) as Vector2
		_spawn_beam(col_from, col_to)


func _spawn_beam(from: Vector2, to: Vector2) -> void:
	var beam: Node2D = LaserBeamGd.new()
	add_child(beam)
	beam.call(&"setup", from, to, Constants.COLOR_LASER, Constants.VFX_LASER_BEAM_LIFETIME)


## Grupo, no get_node()/class_name hardcodeado (regla CLAUDE.md #3) — BoardManager se
## agrega solo a este grupo en su _ready(). null defensivo (nunca debería pasar en una
## escena de juego real, pero evita un crash si algún día se instancia este nodo solo).
func _grid_to_pixel(grid_pos: Vector2i) -> Vector2:
	var board: Node = get_tree().get_first_node_in_group(&"board_manager")
	if board == null:
		return Vector2.ZERO
	return board.call(&"grid_to_pixel", grid_pos) as Vector2


func _spawn_burst(pos: Vector2, color: Color, amount: int, lifetime: float, speed: float) -> void:
	for _i: int in amount:
		var angle: float = _rng.randf_range(0.0, TAU)
		var this_speed: float = _rng.randf_range(speed * 0.4, speed)
		var velocity: Vector2 = Vector2(cos(angle), sin(angle)) * this_speed
		var particle: Node2D = CrumbParticleGd.new()
		add_child(particle)
		particle.position = pos
		particle.call(&"setup", color, _rng.randf_range(2.0, 4.0), velocity, lifetime)
