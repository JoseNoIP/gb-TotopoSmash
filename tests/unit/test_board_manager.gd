extends GutTest
## Tests para BoardManager: spawn de filas, avance de turno, Game Over y explosión de
## salsa (GDD secciones 2 y 4). Se maneja el estado interno (_blocks/_icons) directamente
## en algunos casos para forzar situaciones deterministas — wave_scaling.gd usa un RNG sin
## seed fija, así que no se puede depender de qué columna concreta recibe cada bloque.

const BoardManagerGd := preload("res://src/features/board/board_manager.gd")
const TotopoBlockGd := preload("res://src/features/blocks/totopo_block.gd")

const CELL_SIZE: float = 55.7


## BoardManager solo actúa sobre all_seeds_returned mientras GameManager.is_playing() es
## true — igual que en producción, donde ese estado lo pone start_game(). Emitir
## EventBus.game_started directamente (sin pasar por GameManager) deja is_playing() en
## false y todos los handlers que dependen de ese guard quedan en no-op.
func before_each() -> void:
	GameManager.start_game()


func test_game_started_spawns_a_full_row_and_reports_wave_one() -> void:
	var board: Node2D = BoardManagerGd.new()
	add_child_autofree(board)
	watch_signals(EventBus)
	GameManager.start_game()
	assert_eq(board.call(&"get_wave"), 1)
	assert_signal_emitted_with_parameters(EventBus, "wave_advanced", [1])
	# GDD 4.2: hay probabilidad de celda vacía, así que "fila armada" no implica las 7
	# columnas ocupadas — solo que nunca se ocupan MÁS de 7 columnas ni fuera de rango.
	var blocks: Dictionary = board.get(&"_blocks")
	var icons: Dictionary = board.get(&"_icons")
	var occupied: int = blocks.size() + icons.size()
	assert_true(occupied <= Constants.GRID_COLS, "no puede haber más celdas ocupadas que columnas")
	for key: Vector2i in blocks.keys():
		assert_eq(key.y, 0, "la fila inicial se arma en la fila 0")
		assert_true(key.x >= 0 and key.x < Constants.GRID_COLS, "columna fuera de rango")


func test_all_seeds_returned_shifts_every_surviving_block_down_one_row() -> void:
	var board: Node2D = BoardManagerGd.new()
	add_child_autofree(board)
	GameManager.start_game()
	# Referencias ANTES del avance: _on_all_seeds_returned no solo desplaza estos bloques,
	# también spawnea una fila 0 nueva en la misma llamada (turno normal), así que leer
	# "_blocks" completo DESPUÉS mezclaría los originales desplazados con los recién
	# creados. Hay que rastrear los nodos originales por referencia, no por el dict entero.
	var original_blocks: Dictionary = board.get(&"_blocks")
	var original_nodes: Array = original_blocks.values()
	assert_true(original_nodes.size() > 0, "arreglo del test: la fila inicial no debe estar vacía")
	EventBus.all_seeds_returned.emit(0.0)
	for node: StaticBody2D in original_nodes:
		var new_pos: Vector2i = node.get(&"grid_pos")
		assert_eq(new_pos.y, 1, "cada bloque original debe haber bajado exactamente una fila")


func test_all_seeds_returned_advances_wave_and_spawns_a_new_row() -> void:
	var board: Node2D = BoardManagerGd.new()
	add_child_autofree(board)
	GameManager.start_game()
	watch_signals(EventBus)
	EventBus.all_seeds_returned.emit(0.0)
	assert_eq(board.call(&"get_wave"), 2)
	assert_signal_emitted_with_parameters(EventBus, "wave_advanced", [2])


func test_block_reaching_molcajete_row_triggers_game_over_and_stops_the_wave() -> void:
	var board: Node2D = BoardManagerGd.new()
	add_child_autofree(board)
	GameManager.start_game()
	# Forzamos un bloque justo una fila antes de la última: el próximo avance lo cruza.
	# NOTA: Dictionary tipada + .set() con un literal nuevo falla en silencio (queda
	# vacía) — hay que mutar in-place el dict que ya tiene el nodo (Dictionary es tipo
	# por referencia en GDScript).
	var lone_block: StaticBody2D = TotopoBlockGd.new()
	add_child_autofree(lone_block)
	var forced_key: Vector2i = Vector2i(0, Constants.MOLCAJETE_ROW - 1)
	lone_block.call(&"setup", forced_key, 5, CELL_SIZE)
	var blocks: Dictionary = board.get(&"_blocks")
	blocks.clear()
	blocks[forced_key] = lone_block
	watch_signals(EventBus)
	EventBus.all_seeds_returned.emit(0.0)
	assert_signal_emitted(EventBus, "board_reached_bottom")
	assert_signal_not_emitted(
		EventBus, "wave_advanced", "no debe spawnear fila nueva tras game over"
	)


func test_salsa_explosion_damages_only_cross_neighbors() -> void:
	var board: Node2D = BoardManagerGd.new()
	add_child_autofree(board)
	var neighbor: StaticBody2D = TotopoBlockGd.new()
	add_child_autofree(neighbor)
	neighbor.call(&"setup", Vector2i(3, 4), 50, CELL_SIZE)
	var far_block: StaticBody2D = TotopoBlockGd.new()
	add_child_autofree(far_block)
	far_block.call(&"setup", Vector2i(6, 8), 50, CELL_SIZE)
	var blocks: Dictionary = board.get(&"_blocks")
	blocks[Vector2i(3, 4)] = neighbor
	blocks[Vector2i(6, 8)] = far_block
	EventBus.salsa_exploded.emit(Vector2i(3, 3))  # arriba del vecino, en cruz
	var msg: String = "vecino en cruz debe recibir BLOCK_SALSA_EXPLOSION_DAMAGE"
	assert_eq(int(neighbor.get(&"current_hp")), 40, msg)
	assert_eq(int(far_block.get(&"current_hp")), 50, "un bloque lejano no debe recibir daño")


func test_block_destroyed_removes_it_from_the_grid() -> void:
	var board: Node2D = BoardManagerGd.new()
	add_child_autofree(board)
	var block: StaticBody2D = TotopoBlockGd.new()
	add_child_autofree(block)
	block.call(&"setup", Vector2i(2, 2), 1, CELL_SIZE)
	var blocks: Dictionary = board.get(&"_blocks")
	blocks[Vector2i(2, 2)] = block
	assert_true(blocks.has(Vector2i(2, 2)), "arreglo del test: el bloque debe estar registrado")
	block.call(&"take_damage")  # llega a 0 hp: emite block_destroyed
	assert_false(blocks.has(Vector2i(2, 2)), "BoardManager debe olvidar un bloque destruido")
