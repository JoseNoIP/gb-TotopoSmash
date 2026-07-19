extends GutTest
## Tests para Seed: movimiento base y el boost de acelerar semillas mientras rebotan
## (ver mortar.gd/EventBus.seed_boost_changed). Se invoca _physics_process() directamente
## (no se espera un tick real del engine) para que el test sea determinista y rápido.

const SeedGd := preload("res://src/features/projectiles/seed.gd")
const WorldBoundsGd := preload("res://src/features/board/world_bounds.gd")

const FAR_FLOOR: float = 10000.0  ## piso lejano: la semilla no debe aterrizar durante el test


func _make_seed(origin: Vector2, direction: Vector2) -> CharacterBody2D:
	var seed_node: CharacterBody2D = SeedGd.new()
	add_child_autofree(seed_node)
	seed_node.call(&"launch", origin, direction, Constants.SEED_SPEED, FAR_FLOOR)
	return seed_node


func after_each() -> void:
	EventBus.seed_boost_changed.emit(false)  # nunca dejar el boost pegado entre tests


func test_moves_by_velocity_times_delta_without_boost() -> void:
	var seed_node: CharacterBody2D = _make_seed(Vector2(200.0, 200.0), Vector2.UP)
	var start_pos: Vector2 = seed_node.global_position
	seed_node.call(&"_physics_process", 0.1)
	var moved: float = start_pos.distance_to(seed_node.global_position)
	assert_almost_eq(moved, Constants.SEED_SPEED * 0.1, 1.0)


func test_boost_increases_displacement_for_the_same_delta() -> void:
	var seed_node: CharacterBody2D = _make_seed(Vector2(200.0, 200.0), Vector2.UP)
	EventBus.seed_boost_changed.emit(true)
	var start_pos: Vector2 = seed_node.global_position
	seed_node.call(&"_physics_process", 0.1)
	var boosted_moved: float = start_pos.distance_to(seed_node.global_position)
	var expected: float = Constants.SEED_SPEED * 0.1 * Constants.SEED_BOOST_MULTIPLIER
	assert_almost_eq(boosted_moved, expected, 1.0)


func test_boost_resets_when_signal_emits_false() -> void:
	var seed_node: CharacterBody2D = _make_seed(Vector2(200.0, 200.0), Vector2.UP)
	EventBus.seed_boost_changed.emit(true)
	EventBus.seed_boost_changed.emit(false)
	var start_pos: Vector2 = seed_node.global_position
	seed_node.call(&"_physics_process", 0.1)
	var moved: float = start_pos.distance_to(seed_node.global_position)
	assert_almost_eq(moved, Constants.SEED_SPEED * 0.1, 1.0)


## No debe haber ningún error/crash al rebotar repetidamente contra paredes reales con el
## tope de iteraciones duplicado (boost activo).
func test_boosted_seed_does_not_error_bouncing_against_real_walls() -> void:
	add_child_autofree(WorldBoundsGd.new())
	var seed_node: CharacterBody2D = _make_seed(Vector2(20.0, 400.0), Vector2.LEFT)
	EventBus.seed_boost_changed.emit(true)
	for _i: int in 5:
		seed_node.call(&"_physics_process", 0.1)
	assert_true(true, "llegar aquí sin errores en el log es la prueba")
