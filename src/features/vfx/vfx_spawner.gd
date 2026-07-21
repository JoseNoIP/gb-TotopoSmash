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
