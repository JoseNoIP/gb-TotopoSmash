extends GutTest
## Tests para BoardManager: niveles `static` (figuras de alta resolución, sin condición de
## derrota) y el power-up láser — pedidos explícitos del usuario. Separado de
## test_board_manager.gd porque ese archivo ya rozaba el máximo de 20 métodos públicos por
## clase que exige gdlint (mismo motivo que MetaManager, ver regla CLAUDE.md #51).

const BoardManagerGd := preload("res://src/features/board/board_manager.gd")
const TotopoBlockGd := preload("res://src/features/blocks/totopo_block.gd")
const SalsaJarBlockGd := preload("res://src/features/blocks/salsa_jar_block.gd")
const LaserIconGd := preload("res://src/features/powerups/laser_icon.gd")
const GridMathGd := preload("res://src/shared/grid_math.gd")

const CELL_SIZE: float = 55.7


func before_each() -> void:
	GameManager.start_game()


## --- grid_to_pixel() (bug real corregido: VFXSpawner ubicaba mal sus partículas en
## niveles `static` porque asumía siempre la grilla normal de 7 columnas) ---


func test_grid_to_pixel_uses_normal_grid_math_outside_static_levels() -> void:
	var board: Node2D = BoardManagerGd.new()
	add_child_autofree(board)
	GameManager.start_game()  # Modo Infinito, no static
	var pos: Vector2 = board.call(&"grid_to_pixel", Vector2i(3, 2))
	var expected := Vector2(
		GridMathGd.col_to_x(3, Constants.DESIGN_WIDTH), GridMathGd.row_to_y(2, Constants.DESIGN_WIDTH)
	)
	assert_eq(pos, expected)


func test_grid_to_pixel_uses_the_static_layout_when_static() -> void:
	var board: Node2D = BoardManagerGd.new()
	add_child_autofree(board)
	GameManager.start_game("worldcup_001")
	var static_cell_size: float = board.get(&"_static_cell_size")
	var static_origin: Vector2 = board.get(&"_static_origin")
	var pos: Vector2 = board.call(&"grid_to_pixel", Vector2i(2, 3))
	var expected: Vector2 = static_origin + static_cell_size * (Vector2(2, 3) + Vector2(0.5, 0.5))
	assert_eq(pos, expected)
	## La misma celda calculada con la fórmula NORMAL sería otra muy distinta — confirma
	## que de verdad usó el layout static, no el genérico.
	var wrong: Vector2 = Vector2(
		GridMathGd.col_to_x(2, Constants.DESIGN_WIDTH), GridMathGd.row_to_y(3, Constants.DESIGN_WIDTH)
	)
	assert_ne(pos, wrong, "en static NO debe usar la conversión de la grilla normal")
	GameManager.start_game()


## --- Niveles `static` (figuras de alta resolución, sin condición de derrota) ---


func test_game_started_in_static_level_places_blocks_without_random_rows() -> void:
	var board: Node2D = BoardManagerGd.new()
	add_child_autofree(board)
	watch_signals(EventBus)
	GameManager.start_game("worldcup_001")
	assert_true(board.get(&"_is_static_level"))
	var blocks: Dictionary = board.get(&"_blocks")
	var icons: Dictionary = board.get(&"_icons")
	assert_true(blocks.size() + icons.size() > 0, "el nivel static debe colocar contenido")
	assert_signal_not_emitted(EventBus, "wave_advanced")
	GameManager.start_game()


## Regresión directa del pedido del usuario: un nivel static NUNCA se desplaza ni
## game-overea, sin importar qué tan "abajo" (row) esté un bloque.
func test_static_level_blocks_never_shift_and_never_trigger_game_over() -> void:
	var board: Node2D = BoardManagerGd.new()
	add_child_autofree(board)
	GameManager.start_game("worldcup_001")
	var block: StaticBody2D = TotopoBlockGd.new()
	add_child_autofree(block)
	var forced_key := Vector2i(0, Constants.MOLCAJETE_ROW + 50)
	block.call(&"setup", forced_key, 5, CELL_SIZE)
	var blocks: Dictionary = board.get(&"_blocks")
	blocks.clear()
	blocks[forced_key] = block
	watch_signals(EventBus)
	EventBus.all_seeds_returned.emit(0.0)
	assert_signal_not_emitted(EventBus, "board_reached_bottom", "static nunca debe game-overear")
	var msg: String = "un bloque static nunca debe desplazarse de fila"
	assert_eq(int((block.get(&"grid_pos") as Vector2i).y), forced_key.y, msg)
	GameManager.start_game()


func test_static_level_cleared_reports_turns_used() -> void:
	var board: Node2D = BoardManagerGd.new()
	add_child_autofree(board)
	GameManager.start_game("worldcup_001")
	board.get(&"_blocks").clear()
	board.get(&"_icons").clear()
	watch_signals(EventBus)
	EventBus.all_seeds_returned.emit(0.0)
	assert_signal_emitted_with_parameters(EventBus, "level_cleared", ["worldcup_001", 1])
	GameManager.start_game()


func test_static_level_not_cleared_while_blocks_remain() -> void:
	var board: Node2D = BoardManagerGd.new()
	add_child_autofree(board)
	GameManager.start_game("worldcup_001")
	var block: StaticBody2D = TotopoBlockGd.new()
	add_child_autofree(block)
	block.call(&"setup", Vector2i(0, 0), 5, CELL_SIZE)
	var blocks: Dictionary = board.get(&"_blocks")
	blocks.clear()
	blocks[Vector2i(0, 0)] = block
	watch_signals(EventBus)
	EventBus.all_seeds_returned.emit(0.0)
	assert_signal_not_emitted(EventBus, "level_cleared")
	assert_signal_emitted(EventBus, "turn_advanced")
	GameManager.start_game()


## --- Power-up láser (pedido explícito del usuario) ---


func test_laser_triggered_horizontal_damages_only_the_same_row() -> void:
	var board: Node2D = BoardManagerGd.new()
	add_child_autofree(board)
	var same_row_a: StaticBody2D = TotopoBlockGd.new()
	add_child_autofree(same_row_a)
	same_row_a.call(&"setup", Vector2i(2, 5), 100, CELL_SIZE)
	var same_row_b: StaticBody2D = TotopoBlockGd.new()
	add_child_autofree(same_row_b)
	same_row_b.call(&"setup", Vector2i(9, 5), 100, CELL_SIZE)
	var other_row: StaticBody2D = TotopoBlockGd.new()
	add_child_autofree(other_row)
	other_row.call(&"setup", Vector2i(2, 6), 100, CELL_SIZE)
	var blocks: Dictionary = board.get(&"_blocks")
	blocks[Vector2i(2, 5)] = same_row_a
	blocks[Vector2i(9, 5)] = same_row_b
	blocks[Vector2i(2, 6)] = other_row
	EventBus.laser_triggered.emit(Vector2i(4, 5), "horizontal")
	assert_eq(int(same_row_a.get(&"current_hp")), 100 - Constants.LASER_DAMAGE)
	assert_eq(int(same_row_b.get(&"current_hp")), 100 - Constants.LASER_DAMAGE)
	assert_eq(int(other_row.get(&"current_hp")), 100, "otra fila no debe recibir daño")


func test_laser_triggered_vertical_damages_only_the_same_column() -> void:
	var board: Node2D = BoardManagerGd.new()
	add_child_autofree(board)
	var same_col: StaticBody2D = TotopoBlockGd.new()
	add_child_autofree(same_col)
	same_col.call(&"setup", Vector2i(3, 1), 100, CELL_SIZE)
	var other_col: StaticBody2D = TotopoBlockGd.new()
	add_child_autofree(other_col)
	other_col.call(&"setup", Vector2i(4, 1), 100, CELL_SIZE)
	var blocks: Dictionary = board.get(&"_blocks")
	blocks[Vector2i(3, 1)] = same_col
	blocks[Vector2i(4, 1)] = other_col
	EventBus.laser_triggered.emit(Vector2i(3, 9), "vertical")
	assert_eq(int(same_col.get(&"current_hp")), 100 - Constants.LASER_DAMAGE)
	assert_eq(int(other_col.get(&"current_hp")), 100, "otra columna no debe recibir daño")


## "both" (pedido explícito del usuario): el mismo golpe debe alcanzar fila Y columna a la
## vez, no solo una — un bloque que comparte fila O columna con el origen recibe daño.
func test_laser_triggered_both_damages_row_and_column() -> void:
	var board: Node2D = BoardManagerGd.new()
	add_child_autofree(board)
	var same_row: StaticBody2D = TotopoBlockGd.new()
	add_child_autofree(same_row)
	same_row.call(&"setup", Vector2i(8, 5), 100, CELL_SIZE)
	var same_col: StaticBody2D = TotopoBlockGd.new()
	add_child_autofree(same_col)
	same_col.call(&"setup", Vector2i(3, 1), 100, CELL_SIZE)
	var neither: StaticBody2D = TotopoBlockGd.new()
	add_child_autofree(neither)
	neither.call(&"setup", Vector2i(8, 1), 100, CELL_SIZE)
	var blocks: Dictionary = board.get(&"_blocks")
	blocks[Vector2i(8, 5)] = same_row
	blocks[Vector2i(3, 1)] = same_col
	blocks[Vector2i(8, 1)] = neither
	EventBus.laser_triggered.emit(Vector2i(3, 5), "both")
	assert_eq(int(same_row.get(&"current_hp")), 100 - Constants.LASER_DAMAGE)
	assert_eq(int(same_col.get(&"current_hp")), 100 - Constants.LASER_DAMAGE)
	assert_eq(int(neither.get(&"current_hp")), 100, "ni la fila ni la columna coinciden")


## Regresión de un crash real jugando ("Invalid access to property or key" en
## _on_laser_triggered): un frasco de salsa en la línea del láser puede morir por el
## propio daño del láser y explotar SÍNCRONAMENTE (_on_salsa_exploded destruye a sus
## vecinos antes de que el for termine de recorrer _blocks.keys()) — si esa explosión
## destruye a otro bloque que el láser todavía no visitó, la clave desaparece de _blocks
## a mitad del bucle. Orden de inserción importa: la salsa debe procesarse ANTES que su
## vecino para reproducir el bug.
func test_laser_triggered_survives_a_salsa_dying_and_removing_a_later_block() -> void:
	var board: Node2D = BoardManagerGd.new()
	add_child_autofree(board)
	var salsa: StaticBody2D = SalsaJarBlockGd.new()
	add_child_autofree(salsa)
	salsa.call(&"setup", Vector2i(2, 5), 1, CELL_SIZE)  # muere con un solo golpe del láser
	var neighbor: StaticBody2D = TotopoBlockGd.new()
	add_child_autofree(neighbor)
	neighbor.call(&"setup", Vector2i(3, 5), 100, CELL_SIZE)  # pegado a la salsa, misma fila
	var blocks: Dictionary = board.get(&"_blocks")
	blocks[Vector2i(2, 5)] = salsa  # insertado PRIMERO: el bucle lo procesa antes
	blocks[Vector2i(3, 5)] = neighbor
	EventBus.laser_triggered.emit(Vector2i(0, 5), "horizontal")
	## queue_free() es diferido (no invalida is_instance_valid() en el mismo frame síncrono
	## del test, ver regla CLAUDE.md #43) — se verifica el efecto real en su lugar: HP en 0
	## y ya borrado del Dictionary del tablero (_on_block_destroyed lo borra síncronamente).
	assert_eq(int(salsa.get(&"current_hp")), 0, "la salsa debió morir por el daño del láser")
	assert_eq(int(neighbor.get(&"current_hp")), 0, "el vecino debió morir por la explosión")
	var blocks_after: Dictionary = board.get(&"_blocks")
	assert_false(blocks_after.has(Vector2i(2, 5)), "la salsa debe haberse borrado de _blocks")
	assert_false(blocks_after.has(Vector2i(3, 5)), "el vecino debe haberse borrado de _blocks")


## Regresión directa del bug real reportado jugando: el ícono NO debe desaparecer al
## primer toque — debe seguir existiendo y disparar de nuevo cada vez que una semilla
## vuelva a tocarlo.
func test_laser_icon_persists_and_retriggers_on_repeated_touch() -> void:
	var icon: Area2D = LaserIconGd.new()
	add_child_autofree(icon)
	icon.call(&"setup", CELL_SIZE)
	var seed_node: Node2D = Node2D.new()
	seed_node.add_to_group(&"seeds")
	add_child_autofree(seed_node)
	watch_signals(EventBus)
	icon.call(&"_on_body_entered", seed_node)
	assert_true(is_instance_valid(icon), "el láser no debe autodestruirse al tocarse")
	icon.call(&"_on_body_entered", seed_node)
	assert_true(is_instance_valid(icon), "sigue vivo tras un segundo toque")
	assert_signal_emit_count(
		EventBus, "laser_triggered", 2, "debe disparar una vez por cada toque, no solo el primero"
	)
