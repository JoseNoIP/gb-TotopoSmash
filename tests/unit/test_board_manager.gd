extends GutTest
## Tests para BoardManager: spawn de filas, avance de turno, Game Over y explosión de
## salsa (GDD secciones 2 y 4). Se maneja el estado interno (_blocks/_icons) directamente
## en algunos casos para forzar situaciones deterministas — wave_scaling.gd usa un RNG sin
## seed fija, así que no se puede depender de qué columna concreta recibe cada bloque.

const BoardManagerGd := preload("res://src/features/board/board_manager.gd")
const TotopoBlockGd := preload("res://src/features/blocks/totopo_block.gd")
const StoneBlockGd := preload("res://src/features/blocks/stone_block.gd")

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
	assert_signal_emitted(
		EventBus, "turn_advanced", "TurnManager depende de esto para volver a AIMING"
	)


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
	assert_signal_not_emitted(
		EventBus, "turn_advanced", "no debe volver a AIMING tras game over"
	)


## GDD actualizado (pedido explícito del usuario): la salsa destruye TODOS los bloques
## pegados alrededor (los 8 vecinos, incluidas diagonales), no solo daña en cruz. Un
## bloque diagonal (antes ignorado) ahora también debe ser destruido; uno lejano sigue sin
## recibir nada.
func test_salsa_explosion_destroys_all_eight_surrounding_neighbors() -> void:
	var board: Node2D = BoardManagerGd.new()
	add_child_autofree(board)
	var cross_neighbor: StaticBody2D = TotopoBlockGd.new()
	add_child_autofree(cross_neighbor)
	cross_neighbor.call(&"setup", Vector2i(3, 4), 50, CELL_SIZE)
	var diagonal_neighbor: StaticBody2D = TotopoBlockGd.new()
	add_child_autofree(diagonal_neighbor)
	diagonal_neighbor.call(&"setup", Vector2i(4, 4), 50, CELL_SIZE)
	var far_block: StaticBody2D = TotopoBlockGd.new()
	add_child_autofree(far_block)
	far_block.call(&"setup", Vector2i(6, 8), 50, CELL_SIZE)
	var blocks: Dictionary = board.get(&"_blocks")
	blocks[Vector2i(3, 4)] = cross_neighbor
	blocks[Vector2i(4, 4)] = diagonal_neighbor
	blocks[Vector2i(6, 8)] = far_block
	watch_signals(EventBus)
	EventBus.salsa_exploded.emit(Vector2i(3, 3))  # (3,4) es vecino en cruz, (4,4) es diagonal
	assert_true(int(cross_neighbor.get(&"current_hp")) <= 0, "vecino en cruz debe destruirse")
	assert_true(int(diagonal_neighbor.get(&"current_hp")) <= 0, "vecino diagonal debe destruirse")
	assert_eq(int(far_block.get(&"current_hp")), 50, "un bloque lejano no debe recibir nada")


## "A excepción de... un bloque de piedra" (pedido explícito del usuario) — ya exento
## gratis vía el guard de is_indestructible en destroy_instantly(), sin lógica especial.
func test_salsa_explosion_never_destroys_an_indestructible_stone_neighbor() -> void:
	var board: Node2D = BoardManagerGd.new()
	add_child_autofree(board)
	var stone: StaticBody2D = StoneBlockGd.new()
	add_child_autofree(stone)
	stone.call(&"setup", Vector2i(3, 4), 1, CELL_SIZE)
	var blocks: Dictionary = board.get(&"_blocks")
	blocks[Vector2i(3, 4)] = stone
	EventBus.salsa_exploded.emit(Vector2i(3, 3))
	assert_true(is_instance_valid(stone), "la piedra nunca debe destruirse por la explosión")
	assert_true(bool(stone.get(&"is_indestructible")))


## Regresión: LemonIcon/SeedExtraIcon se autodestruyen (queue_free) al ser tocados por una
## semilla, pero BoardManager nunca borraba esa entrada de _icons. Para el siguiente
## avance, _shift_down() intentaba copiar la referencia ya liberada a un
## Dictionary[Vector2i, Area2D] tipado, lo cual revienta en tiempo de ejecución
## ("previously freed object") en vez de fallar en silencio.
func test_shift_down_drops_a_freed_icon_without_crashing() -> void:
	var board: Node2D = BoardManagerGd.new()
	add_child_autofree(board)
	GameManager.start_game()
	var icon: Area2D = Area2D.new()
	var icons: Dictionary = board.get(&"_icons")
	icons[Vector2i(3, 0)] = icon
	icon.free()  # simula el ícono ya recogido (referencia inválida antes del avance)
	EventBus.all_seeds_returned.emit(0.0)
	var new_icons: Dictionary = board.get(&"_icons")
	assert_false(
		new_icons.has(Vector2i(3, 1)), "un ícono liberado no debe sobrevivir al desplazamiento"
	)


## --- Modo Nivel (niveles finitos/deterministas, ver LevelManager/level_loader.gd) ---

func test_spawn_level_cell_places_a_block_at_its_exact_position() -> void:
	var board: Node2D = BoardManagerGd.new()
	add_child_autofree(board)
	var cell: Dictionary = {"col": 3, "row": 2, "kind": "totopo", "hp": 5}
	board.call(&"_spawn_level_cell", cell)
	var blocks: Dictionary = board.get(&"_blocks")
	assert_true(blocks.has(Vector2i(3, 2)), "la celda debe caer exactamente en (3,2)")
	var node: StaticBody2D = blocks[Vector2i(3, 2)]
	assert_eq(int(node.get(&"current_hp")), 5, "el hp debe venir del JSON, no de wave_scaling")


func test_spawn_level_cell_places_an_icon() -> void:
	var board: Node2D = BoardManagerGd.new()
	add_child_autofree(board)
	board.call(&"_spawn_level_cell", {"col": 1, "row": 0, "kind": "lemon"})
	var icons: Dictionary = board.get(&"_icons")
	assert_true(icons.has(Vector2i(1, 0)))


## Regresión: Modo Nivel nunca debe usar el spawn aleatorio de Infinito.
func test_game_started_in_level_mode_does_not_spawn_a_random_row() -> void:
	var board: Node2D = BoardManagerGd.new()
	add_child_autofree(board)
	watch_signals(EventBus)
	GameManager.start_game("level_001")
	assert_signal_not_emitted(
		EventBus, "wave_advanced", "modo nivel no debe emitir wave_advanced al iniciar"
	)
	var blocks: Dictionary = board.get(&"_blocks")
	var icons: Dictionary = board.get(&"_icons")
	assert_true(blocks.size() + icons.size() > 0, "el nivel debe colocar al menos una celda")
	GameManager.start_game()  # vuelve a Modo Infinito para no contaminar otros tests


## Regresión: el tablero se sigue desplazando y game-over sigue funcionando igual en
## Modo Nivel (es lo que hace que "llegar a la fila del molcajete" siga siendo derrota
## real aunque no aparezcan filas nuevas).
func test_all_seeds_returned_in_level_mode_still_checks_game_over() -> void:
	var board: Node2D = BoardManagerGd.new()
	add_child_autofree(board)
	GameManager.start_game("level_001")
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
		EventBus, "turn_advanced", "no debe volver a AIMING tras game over en Modo Nivel"
	)
	GameManager.start_game()


## _level_row_queue/_level_queue_index se fuerzan a "cola ya agotada": este test cubre
## _all_destructible_cleared() de forma aislada, no la mecánica de la cola (ver
## test_level_loader.gd para eso) — level_001 real trae row_queue con contenido, así que
## sin este override la cola seguiría revelando filas nuevas y jamás se agotaría aquí.
func test_level_cleared_emitted_when_only_stone_blocks_remain() -> void:
	var board: Node2D = BoardManagerGd.new()
	add_child_autofree(board)
	GameManager.start_game("level_001")
	board.set(&"_level_row_queue", [])
	board.set(&"_level_queue_index", 0)
	var stone: StaticBody2D = StoneBlockGd.new()
	add_child_autofree(stone)
	stone.call(&"setup", Vector2i(0, 0), 1, CELL_SIZE)
	var blocks: Dictionary = board.get(&"_blocks")
	blocks.clear()
	blocks[Vector2i(0, 0)] = stone
	watch_signals(EventBus)
	EventBus.all_seeds_returned.emit(0.0)
	assert_signal_emitted_with_parameters(EventBus, "level_cleared", ["level_001", 0])
	assert_signal_not_emitted(
		EventBus, "turn_advanced", "el nivel ya terminó, no debe volver a AIMING"
	)
	GameManager.start_game()


## Regresión real encontrada jugando: Modo Nivel nunca emitía `wave_advanced` (específica
## de Modo Infinito) y TurnManager dependía SOLO de esa señal para volver de ADVANCING a
## AIMING — el apuntado se quedaba trabado para siempre después del primer turno en
## cualquier nivel. `turn_advanced` es la señal mode-agnostic que reemplaza esa dependencia.
func test_level_cleared_not_emitted_while_a_destructible_block_remains() -> void:
	var board: Node2D = BoardManagerGd.new()
	add_child_autofree(board)
	GameManager.start_game("level_001")
	board.set(&"_level_row_queue", [])
	board.set(&"_level_queue_index", 0)
	var totopo: StaticBody2D = TotopoBlockGd.new()
	add_child_autofree(totopo)
	totopo.call(&"setup", Vector2i(0, 0), 5, CELL_SIZE)
	var blocks: Dictionary = board.get(&"_blocks")
	blocks.clear()
	blocks[Vector2i(0, 0)] = totopo
	watch_signals(EventBus)
	EventBus.all_seeds_returned.emit(0.0)
	assert_signal_not_emitted(EventBus, "level_cleared")
	assert_signal_emitted(
		EventBus,
		"turn_advanced",
		"sin esto el apuntado se queda trabado para siempre tras el primer turno en Modo Nivel"
	)
	GameManager.start_game()


## --- row_queue: revelado progresivo (dificultad estándar, sin RNG en runtime) ---


func test_game_started_in_level_mode_reveals_only_the_first_queued_row() -> void:
	var board: Node2D = BoardManagerGd.new()
	add_child_autofree(board)
	GameManager.start_game("level_001")
	var queue_index: int = int(board.get(&"_level_queue_index"))
	assert_eq(queue_index, 1, "solo la primera fila de la cola se revela al iniciar")
	GameManager.start_game()


func test_all_seeds_returned_in_level_mode_reveals_the_next_queued_row() -> void:
	var board: Node2D = BoardManagerGd.new()
	add_child_autofree(board)
	GameManager.start_game("level_001")
	EventBus.all_seeds_returned.emit(0.0)
	var queue_index: int = int(board.get(&"_level_queue_index"))
	assert_eq(queue_index, 2, "cada turno exitoso consume una fila más de la cola")
	GameManager.start_game()


func test_level_cleared_only_fires_once_the_queue_is_exhausted() -> void:
	var board: Node2D = BoardManagerGd.new()
	add_child_autofree(board)
	GameManager.start_game("level_001")
	board.set(&"_level_row_queue", [[{"col": 0, "kind": "totopo", "hp": 1}]])
	board.set(&"_level_queue_index", 0)
	board.get(&"_blocks").clear()
	board.get(&"_icons").clear()
	watch_signals(EventBus)
	EventBus.all_seeds_returned.emit(0.0)
	assert_eq(
		int(board.get(&"_level_queue_index")), 1, "arreglo del test: la única fila debe consumirse"
	)
	assert_signal_not_emitted(
		EventBus, "level_cleared", "el bloque recién revelado sigue destructible"
	)
	GameManager.start_game()


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
