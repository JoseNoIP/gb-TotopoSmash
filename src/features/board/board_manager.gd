extends Node2D
## Dueño exclusivo de la matriz de bloques (GDD secciones 2 y 4). Modo Infinito: crea la
## fila inicial al empezar la partida y spawnea filas nuevas al azar según wave_scaling.gd,
## para siempre.
##
## Modo Nivel: contenido finito y determinista (mismo tablero para todos, ver
## level_loader.gd/LevelManager), con dos mecanismos que un nivel puede combinar:
## - `cells` — celdas ya colocadas en su posición absoluta desde el inicio (niveles-figura:
##   toda la forma visible de una vez).
## - `row_queue` — filas que aparecen una por turno, igual que Modo Infinito pero con
##   contenido fijo en vez de aleatorio (niveles de dificultad progresiva: arrancan
##   mostrando 1 fila y el resto se revela de a poco, hasta agotar la cola).
## El nivel se gana cuando la cola ya no tiene más filas Y no queda ningún bloque
## destructible (piedra no cuenta) — antes de eso, aunque el tablero esté momentáneamente
## limpio, todavía falta contenido por venir. TurnManager NUNCA toca esta matriz
## directamente — solo EventBus.

const WaveScalingGd := preload("res://src/features/board/wave_scaling.gd")
const CellFactoryGd := preload("res://src/features/board/cell_factory.gd")
const GridMathGd := preload("res://src/shared/grid_math.gd")

var _wave: int = 1
var _blocks: Dictionary[Vector2i, StaticBody2D] = {}
var _icons: Dictionary[Vector2i, Area2D] = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _level_row_queue: Array = []
var _level_queue_index: int = 0


func _ready() -> void:
	EventBus.game_started.connect(_on_game_started)
	EventBus.all_seeds_returned.connect(_on_all_seeds_returned)
	EventBus.block_destroyed.connect(_on_block_destroyed)
	EventBus.salsa_exploded.connect(_on_salsa_exploded)


func get_wave() -> int:
	return _wave


func _on_game_started() -> void:
	_clear_board()
	var level_id: String = GameManager.get_current_level_id()
	if level_id.is_empty():
		_wave = 1
		_spawn_row(0)
		EventBus.wave_advanced.emit(_wave)
		return
	var data: Dictionary = LevelManager.get_level_data(level_id)
	for cell: Dictionary in data.get("cells", []) as Array:
		_spawn_level_cell(cell)
	_level_row_queue = data.get("row_queue", []) as Array
	_level_queue_index = 0
	_spawn_next_queued_row()  # revela la primera fila de la cola (si el nivel tiene una)


## GDD "Fase de Avance": una vez que la última semilla regresa, los bloques sobrevivientes
## bajan una fila. Si algún bloque queda en la fila del molcajete tras bajar, la partida
## termina (GDD "Condiciones de Fin de Juego") — igual en ambos modos. Modo Infinito
## además spawnea una fila aleatoria nueva; Modo Nivel revela la siguiente fila de la cola
## (si queda alguna) y, si ya no queda ninguna Y el tablero está libre de destructibles,
## declara el nivel ganado.
func _on_all_seeds_returned(_landing_x: float) -> void:
	if not GameManager.is_playing():
		return
	_shift_down()
	if _check_game_over():
		EventBus.board_reached_bottom.emit()
		return
	var level_id: String = GameManager.get_current_level_id()
	if level_id.is_empty():
		_wave += 1
		_spawn_row(0)
		EventBus.wave_advanced.emit(_wave)
		return
	_spawn_next_queued_row()
	if _level_queue_index >= _level_row_queue.size() and _all_destructible_cleared():
		EventBus.level_cleared.emit(level_id)


## Modo Nivel: consume la siguiente fila de `row_queue` (si queda alguna) y la coloca en
## la fila 0 — misma posición donde Modo Infinito siempre revela contenido nuevo. Cada
## celda de la cola no trae `row` (es implícito, "la próxima fila arriba"), así que se
## inyecta antes de reusar _spawn_level_cell().
func _spawn_next_queued_row() -> void:
	if _level_queue_index >= _level_row_queue.size():
		return
	var row_cells: Array = _level_row_queue[_level_queue_index]
	_level_queue_index += 1
	for cell: Dictionary in row_cells:
		var grid_pos := Vector2i(int(cell.get("col", 0)), 0)
		if _blocks.has(grid_pos) or _icons.has(grid_pos):
			continue  # defensivo: la fila 0 recién desplazada siempre debería estar libre
		var cell_with_row: Dictionary = cell.duplicate()
		cell_with_row["row"] = 0
		_spawn_level_cell(cell_with_row)


func _clear_board() -> void:
	for key: Vector2i in _blocks.keys():
		var node: StaticBody2D = _blocks[key]
		if is_instance_valid(node):
			node.queue_free()
	_blocks.clear()
	for key: Vector2i in _icons.keys():
		var node: Area2D = _icons[key]
		if is_instance_valid(node):
			node.queue_free()
	_icons.clear()


## `is_instance_valid()` se revisa ANTES de insertar en el Dictionary tipado, nunca
## después: un ícono recogido (LemonIcon/SeedExtraIcon) se autodestruye con queue_free()
## sin que BoardManager borre su entrada de _icons, así que para el siguiente turno esa
## referencia ya está liberada — asignarla a un Dictionary[Vector2i, Area2D] tipado
## revienta en tiempo de ejecución ("previously freed object"). Los bloques nunca quedan
## inválidos aquí (block_destroyed los borra de _blocks de forma síncrona), pero se
## revisa igual por si acaso.
func _shift_down() -> void:
	var new_blocks: Dictionary[Vector2i, StaticBody2D] = {}
	for key: Vector2i in _blocks.keys():
		var node: StaticBody2D = _blocks[key]
		if not is_instance_valid(node):
			continue
		var new_key: Vector2i = Vector2i(key.x, key.y + 1)
		new_blocks[new_key] = node
		node.set(&"grid_pos", new_key)
		_tween_to_row(node, new_key.y)
	_blocks = new_blocks

	var new_icons: Dictionary[Vector2i, Area2D] = {}
	for key: Vector2i in _icons.keys():
		var node: Area2D = _icons[key]
		if not is_instance_valid(node):
			continue
		var new_key: Vector2i = Vector2i(key.x, key.y + 1)
		new_icons[new_key] = node
		_tween_to_row(node, new_key.y)
	_icons = new_icons


func _tween_to_row(node: Node2D, row: int) -> void:
	var target_y: float = GridMathGd.row_to_y(row, Constants.DESIGN_WIDTH)
	var tween: Tween = create_tween()
	tween.tween_property(node, ^"position:y", target_y, Constants.MOLCAJETE_MOVE_DURATION)


## GDD "Condiciones de Fin de Juego": "Si cualquier bloque toca la fila inferior (donde se
## ubica el molcajete) al final de un turno, la partida termina."
func _check_game_over() -> bool:
	for key: Vector2i in _blocks.keys():
		if key.y >= Constants.MOLCAJETE_ROW:
			return true
	return false


func _spawn_row(row: int) -> void:
	for col: int in Constants.GRID_COLS:
		var grid_pos: Vector2i = Vector2i(col, row)
		if _blocks.has(grid_pos) or _icons.has(grid_pos):
			continue  # defensivo: row 0 recién desplazada siempre debería estar libre
		var kind: String = WaveScalingGd.pick_cell_kind(_wave, _rng)
		_spawn_cell(kind, grid_pos)


## Modo Infinito: HP y corner de triángulo se calculan aquí igual que siempre
## (totopo_hp_for_wave/queso_hp_for_wave/RNG) — el refactor a CellFactoryGd solo movió
## el "qué clase instanciar", no el origen del HP/corner.
func _spawn_cell(kind: String, grid_pos: Vector2i) -> void:
	if kind == WaveScalingGd.KIND_EMPTY:
		return
	var node: Node = CellFactoryGd.create_kind_instance(kind)
	if node == null:
		return
	var cell_size: float = GridMathGd.cell_size(Constants.DESIGN_WIDTH)
	var pos := Vector2(
		GridMathGd.col_to_x(grid_pos.x, Constants.DESIGN_WIDTH),
		GridMathGd.row_to_y(grid_pos.y, Constants.DESIGN_WIDTH)
	)
	if kind == WaveScalingGd.KIND_TRIANGLE:
		node.set(&"corner", _rng.randi_range(0, 3))
	if CellFactoryGd.is_icon_kind(kind):
		_spawn_icon(node as Area2D, grid_pos, pos, cell_size)
		return
	var hp: int = 1
	match kind:
		WaveScalingGd.KIND_QUESO:
			hp = WaveScalingGd.queso_hp_for_wave(_wave)
		WaveScalingGd.KIND_STONE:
			hp = 1
		_:
			hp = WaveScalingGd.totopo_hp_for_wave(_wave)
	_spawn_block(node as StaticBody2D, grid_pos, pos, hp, cell_size)


## Modo Nivel: hp/corner vienen directo del JSON del nivel (level_loader.gd ya validó
## que existan donde el kind los requiere) — sin RNG, mismo tablero para todos.
func _spawn_level_cell(cell: Dictionary) -> void:
	var kind: String = cell.get("kind", "") as String
	var node: Node = CellFactoryGd.create_kind_instance(kind)
	if node == null:
		return
	var grid_pos := Vector2i(int(cell.get("col", 0)), int(cell.get("row", 0)))
	var cell_size: float = GridMathGd.cell_size(Constants.DESIGN_WIDTH)
	var pos := Vector2(
		GridMathGd.col_to_x(grid_pos.x, Constants.DESIGN_WIDTH),
		GridMathGd.row_to_y(grid_pos.y, Constants.DESIGN_WIDTH)
	)
	if kind == WaveScalingGd.KIND_TRIANGLE:
		node.set(&"corner", int(cell.get("corner", 0)))
	if CellFactoryGd.is_icon_kind(kind):
		_spawn_icon(node as Area2D, grid_pos, pos, cell_size)
		return
	var hp: int = int(cell.get("hp", 1))
	_spawn_block(node as StaticBody2D, grid_pos, pos, hp, cell_size)


## Modo Nivel: el nivel se gana cuando ya no queda ningún bloque destructible (la piedra
## indestructible no cuenta para el clear, GDD/decisión confirmada con el usuario).
func _all_destructible_cleared() -> bool:
	for node: StaticBody2D in _blocks.values():
		if not bool(node.get(&"is_indestructible")):
			return false
	return true


func _spawn_block(
	block: StaticBody2D, grid_pos: Vector2i, pos: Vector2, hp: int, cell_size: float
) -> void:
	add_child(block)
	block.position = pos
	block.call(&"setup", grid_pos, hp, cell_size)
	_blocks[grid_pos] = block


func _spawn_icon(icon: Area2D, grid_pos: Vector2i, pos: Vector2, cell_size: float) -> void:
	add_child(icon)
	icon.position = pos
	icon.call(&"setup", cell_size)
	_icons[grid_pos] = icon


func _on_block_destroyed(grid_pos: Vector2i, _block_type: String, _score_value: int) -> void:
	_blocks.erase(grid_pos)


## GDD Frasco de Salsa: "explota y causa 10 puntos de daño a todos los bloques
## adyacentes en cruz." BoardManager es quien conoce la matriz, así que aplica el daño.
func _on_salsa_exploded(grid_pos: Vector2i) -> void:
	for neighbor: Vector2i in GridMathGd.cross_neighbors(grid_pos.x, grid_pos.y):
		if _blocks.has(neighbor):
			var node: StaticBody2D = _blocks[neighbor]
			if is_instance_valid(node):
				node.call(&"take_explosion_damage", Constants.BLOCK_SALSA_EXPLOSION_DAMAGE)
