extends GutTest
## Tests para BoardManager: niveles `static` (figuras de alta resolución, sin condición de
## derrota) y el power-up láser — pedidos explícitos del usuario. Separado de
## test_board_manager.gd porque ese archivo ya rozaba el máximo de 20 métodos públicos por
## clase que exige gdlint (mismo motivo que MetaManager, ver regla CLAUDE.md #51).

const BoardManagerGd := preload("res://src/features/board/board_manager.gd")
const TotopoBlockGd := preload("res://src/features/blocks/totopo_block.gd")

const CELL_SIZE: float = 55.7


func before_each() -> void:
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
	EventBus.laser_triggered.emit(Vector2i(4, 5), true)
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
	EventBus.laser_triggered.emit(Vector2i(3, 9), false)
	assert_eq(int(same_col.get(&"current_hp")), 100 - Constants.LASER_DAMAGE)
	assert_eq(int(other_col.get(&"current_hp")), 100, "otra columna no debe recibir daño")
