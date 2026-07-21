extends GutTest
## Tests para el bloque base y sus subtipos (GDD sección 3). La mecánica común
## (take_damage/_die/señales) se prueba una vez con TotopoBlock como representante
## neutro; cada subtipo solo se prueba en lo que lo distingue de block_base.gd.

const TotopoBlockGd := preload("res://src/features/blocks/totopo_block.gd")
const QuesoBlockGd := preload("res://src/features/blocks/queso_block.gd")
const SalsaJarBlockGd := preload("res://src/features/blocks/salsa_jar_block.gd")
const StoneBlockGd := preload("res://src/features/blocks/stone_block.gd")
const TriangleBlockGd := preload("res://src/features/blocks/triangle_block.gd")
const SeedGd := preload("res://src/features/projectiles/seed.gd")

const CELL_SIZE: float = 55.7


func test_take_damage_reduces_hp_and_emits_block_damaged() -> void:
	MetaManager.set_upgrade_level("damage", 0)  ## arreglo del test: sin mejora de la tienda
	var block: StaticBody2D = TotopoBlockGd.new()
	add_child_autofree(block)
	block.call(&"setup", Vector2i(2, 3), 3, CELL_SIZE)
	watch_signals(EventBus)
	block.call(&"take_damage")
	assert_eq(int(block.get(&"current_hp")), 2, "un impacto normal debe restar 1 de vida")
	assert_signal_emitted_with_parameters(EventBus, "block_damaged", [Vector2i(2, 3), 2, 3])


## Regresión: la mejora "Daño Base" de la tienda (MetaManager) debe multiplicar el daño
## por impacto — mínimo 1 garantizado aunque el multiplicador redondeara a 0.
func test_take_damage_scales_with_damage_multiplier_upgrade() -> void:
	MetaManager.set_upgrade_level("damage", Constants.UPGRADE_MAX_LEVEL)
	var block: StaticBody2D = TotopoBlockGd.new()
	add_child_autofree(block)
	block.call(&"setup", Vector2i(0, 0), 1000, CELL_SIZE)
	block.call(&"take_damage")
	var bonus: float = Constants.UPGRADE_MAX_LEVEL * Constants.UPGRADE_DAMAGE_BONUS_PER_LEVEL
	var multiplier: float = 1.0 + bonus
	var expected_damage: int = maxi(1, roundi(1 * multiplier))
	assert_eq(int(block.get(&"current_hp")), 1000 - expected_damage)
	MetaManager.set_upgrade_level("damage", 0)  ## deja el estado limpio para otros tests


func test_take_damage_to_zero_destroys_block_and_emits_block_destroyed() -> void:
	var block: StaticBody2D = TotopoBlockGd.new()
	add_child_autofree(block)
	block.call(&"setup", Vector2i(0, 0), 1, CELL_SIZE)
	watch_signals(EventBus)
	block.call(&"take_damage")
	assert_signal_emitted(EventBus, "block_destroyed")
	assert_true(block.is_queued_for_deletion(), "debe eliminarse al llegar a 0 hp")


func test_take_explosion_damage_never_goes_below_zero() -> void:
	var block: StaticBody2D = TotopoBlockGd.new()
	add_child_autofree(block)
	block.call(&"setup", Vector2i(0, 0), 1, CELL_SIZE)
	block.call(&"take_explosion_damage", 999)
	assert_eq(int(block.get(&"current_hp")), 0, "la vida nunca debe quedar negativa")


func test_score_value_on_destroy_equals_max_hp_times_score_per_point() -> void:
	MetaManager.set_upgrade_level("damage", 0)  ## arreglo del test: sin mejora de la tienda
	var block: StaticBody2D = TotopoBlockGd.new()
	add_child_autofree(block)
	block.call(&"setup", Vector2i(0, 0), 4, CELL_SIZE)
	watch_signals(EventBus)
	for _i: int in 4:
		block.call(&"take_damage")
	var expected_score: int = 4 * Constants.SCORE_PER_DAMAGE_POINT
	var expected_params: Array = [Vector2i(0, 0), "totopo", expected_score]
	assert_signal_emitted_with_parameters(EventBus, "block_destroyed", expected_params)


func test_indestructible_stone_ignores_all_damage() -> void:
	var block: StaticBody2D = StoneBlockGd.new()
	add_child_autofree(block)
	block.call(&"setup", Vector2i(1, 1), 1, CELL_SIZE)
	watch_signals(EventBus)
	block.call(&"take_damage")
	block.call(&"take_explosion_damage", 50)
	assert_signal_not_emitted(EventBus, "block_destroyed")
	assert_false(block.is_queued_for_deletion(), "una piedra nunca debe destruirse")


## GDD actualizado (pedido explícito del usuario): la explosión de la salsa destruye de
## un tirón, sin importar cuánto HP le quede al bloque — usado por
## board_manager.gd::_on_salsa_exploded().
func test_destroy_instantly_destroys_regardless_of_remaining_hp() -> void:
	var block: StaticBody2D = TotopoBlockGd.new()
	add_child_autofree(block)
	block.call(&"setup", Vector2i(2, 2), 500, CELL_SIZE)
	watch_signals(EventBus)
	block.call(&"destroy_instantly")
	assert_signal_emitted(EventBus, "block_destroyed")
	assert_true(block.is_queued_for_deletion())


func test_destroy_instantly_never_destroys_an_indestructible_stone() -> void:
	var block: StaticBody2D = StoneBlockGd.new()
	add_child_autofree(block)
	block.call(&"setup", Vector2i(1, 1), 1, CELL_SIZE)
	watch_signals(EventBus)
	block.call(&"destroy_instantly")
	assert_signal_not_emitted(EventBus, "block_destroyed")
	assert_false(block.is_queued_for_deletion(), "una piedra nunca debe destruirse")


func test_queso_takes_double_damage_per_hit() -> void:
	MetaManager.set_upgrade_level("damage", 0)  ## arreglo del test: sin mejora de la tienda
	var block: StaticBody2D = QuesoBlockGd.new()
	add_child_autofree(block)
	block.call(&"setup", Vector2i(0, 0), 10, CELL_SIZE)
	block.call(&"take_damage")
	assert_eq(int(block.get(&"current_hp")), 8, "queso resta 2 de vida por impacto (N-2)")


func test_queso_slows_down_a_bouncing_seed() -> void:
	var block: StaticBody2D = QuesoBlockGd.new()
	add_child_autofree(block)
	block.call(&"setup", Vector2i(0, 0), 10, CELL_SIZE)
	var seed_node: CharacterBody2D = SeedGd.new()
	add_child_autofree(seed_node)
	seed_node.call(&"launch", Vector2.ZERO, Vector2.UP, Constants.SEED_SPEED, 1000.0)
	block.call(&"on_seed_bounce", seed_node)
	var expected_speed: float = Constants.SEED_SPEED * Constants.SEED_QUESO_SLOWDOWN_RATIO
	var msg: String = "GDD: -15% de velocidad en queso"
	assert_almost_eq(seed_node.velocity.length(), expected_speed, 0.5, msg)


func test_salsa_explodes_and_destroys_on_death() -> void:
	var block: StaticBody2D = SalsaJarBlockGd.new()
	add_child_autofree(block)
	block.call(&"setup", Vector2i(3, 3), 1, CELL_SIZE)
	watch_signals(EventBus)
	block.call(&"take_damage")
	assert_signal_emitted_with_parameters(EventBus, "salsa_exploded", [Vector2i(3, 3)])
	assert_signal_emitted(EventBus, "block_destroyed")


## Regresión directa del bug real reportado jugando: los sprites de IA (totopo/queso/
## salsa/piedra) no son cuadrados — tienen transparencia real alrededor de la silueta —
## pero la colisión SIEMPRE es un RectangleShape2D cuadrado (la grilla del tablero define
## el rebote, no la silueta del arte). Sin un fondo sólido del mismo tamaño que la
## colisión, la semilla rebotaba "en el aire" cerca de las esquinas donde el sprite ya
## había terminado. `totopo.png` es un sprite real en este repo (no un placeholder), así
## que este test ejercita la rama con textura de verdad, no el ColorRect de fallback.
func test_block_with_texture_gets_a_backing_rect_matching_the_collision_size() -> void:
	var block: StaticBody2D = TotopoBlockGd.new()
	add_child_autofree(block)
	block.call(&"setup", Vector2i(0, 0), 3, CELL_SIZE)
	var backing: ColorRect = block.get_node(^"Backing") as ColorRect
	assert_not_null(backing, "un bloque con sprite real debe tener un ColorRect de respaldo")
	var expected_size: float = CELL_SIZE * 0.92
	assert_eq(backing.size, Vector2(expected_size, expected_size))
	assert_eq(backing.color, Constants.COLOR_TOTOPO)


func test_triangle_cutting_one_corner_leaves_a_triangle() -> void:
	var block: StaticBody2D = TriangleBlockGd.new()
	block.set(&"corner", 1)
	add_child_autofree(block)
	block.call(&"setup", Vector2i(0, 0), 2, CELL_SIZE)
	var visual: Object = block.get(&"_visual")
	var msg: String = "recortar 1 esquina de un cuadrado deja un triángulo"
	assert_eq((visual as Polygon2D).polygon.size(), 3, msg)
