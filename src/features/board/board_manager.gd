extends Node2D
## Dueño exclusivo de la matriz de bloques (GDD secciones 2 y 4). Crea la fila inicial al
## empezar la partida, spawnea filas nuevas según wave_scaling.gd, desplaza el tablero
## hacia abajo al completar un turno, detecta el Game Over (bloque en la fila del
## molcajete) y aplica el daño en cruz del Frasco de Salsa. TurnManager NUNCA toca esta
## matriz directamente — solo se comunican por EventBus.

const WaveScalingGd := preload("res://src/features/board/wave_scaling.gd")
const GridMathGd := preload("res://src/shared/grid_math.gd")
const TotopoBlockGd := preload("res://src/features/blocks/totopo_block.gd")
const QuesoBlockGd := preload("res://src/features/blocks/queso_block.gd")
const SalsaJarBlockGd := preload("res://src/features/blocks/salsa_jar_block.gd")
const StoneBlockGd := preload("res://src/features/blocks/stone_block.gd")
const TriangleBlockGd := preload("res://src/features/blocks/triangle_block.gd")
const LemonIconGd := preload("res://src/features/powerups/lemon_icon.gd")
const SeedExtraIconGd := preload("res://src/features/powerups/seed_extra_icon.gd")

var _wave: int = 1
var _blocks: Dictionary[Vector2i, StaticBody2D] = {}
var _icons: Dictionary[Vector2i, Area2D] = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	EventBus.game_started.connect(_on_game_started)
	EventBus.all_seeds_returned.connect(_on_all_seeds_returned)
	EventBus.block_destroyed.connect(_on_block_destroyed)
	EventBus.salsa_exploded.connect(_on_salsa_exploded)


func get_wave() -> int:
	return _wave


func _on_game_started() -> void:
	_clear_board()
	_wave = 1
	_spawn_row(0)
	EventBus.wave_advanced.emit(_wave)


## GDD "Fase de Avance": una vez que la última semilla regresa, los bloques sobrevivientes
## bajan una fila y aparece una nueva fila arriba. Si algún bloque queda en la fila del
## molcajete tras bajar, la partida termina (GDD "Condiciones de Fin de Juego").
func _on_all_seeds_returned(_landing_x: float) -> void:
	if not GameManager.is_playing():
		return
	_shift_down()
	if _check_game_over():
		EventBus.board_reached_bottom.emit()
		return
	_wave += 1
	_spawn_row(0)
	EventBus.wave_advanced.emit(_wave)


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


func _shift_down() -> void:
	var new_blocks: Dictionary[Vector2i, StaticBody2D] = {}
	for key: Vector2i in _blocks.keys():
		var node: StaticBody2D = _blocks[key]
		var new_key: Vector2i = Vector2i(key.x, key.y + 1)
		new_blocks[new_key] = node
		if is_instance_valid(node):
			node.set(&"grid_pos", new_key)
			_tween_to_row(node, new_key.y)
	_blocks = new_blocks

	var new_icons: Dictionary[Vector2i, Area2D] = {}
	for key: Vector2i in _icons.keys():
		var node: Area2D = _icons[key]
		var new_key: Vector2i = Vector2i(key.x, key.y + 1)
		new_icons[new_key] = node
		if is_instance_valid(node):
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


func _spawn_cell(kind: String, grid_pos: Vector2i) -> void:
	if kind == WaveScalingGd.KIND_EMPTY:
		return
	var cell_size: float = GridMathGd.cell_size(Constants.DESIGN_WIDTH)
	var pos := Vector2(
		GridMathGd.col_to_x(grid_pos.x, Constants.DESIGN_WIDTH),
		GridMathGd.row_to_y(grid_pos.y, Constants.DESIGN_WIDTH)
	)
	var totopo_hp: int = WaveScalingGd.totopo_hp_for_wave(_wave)
	var queso_hp: int = WaveScalingGd.queso_hp_for_wave(_wave)
	match kind:
		WaveScalingGd.KIND_TOTOPO:
			_spawn_block(TotopoBlockGd.new(), grid_pos, pos, totopo_hp, cell_size)
		WaveScalingGd.KIND_QUESO:
			_spawn_block(QuesoBlockGd.new(), grid_pos, pos, queso_hp, cell_size)
		WaveScalingGd.KIND_SALSA:
			_spawn_block(SalsaJarBlockGd.new(), grid_pos, pos, totopo_hp, cell_size)
		WaveScalingGd.KIND_STONE:
			_spawn_block(StoneBlockGd.new(), grid_pos, pos, 1, cell_size)
		WaveScalingGd.KIND_TRIANGLE:
			var block: StaticBody2D = TriangleBlockGd.new()
			block.set(&"corner", _rng.randi_range(0, 3))
			_spawn_block(block, grid_pos, pos, totopo_hp, cell_size)
		WaveScalingGd.KIND_LEMON:
			_spawn_icon(LemonIconGd.new(), grid_pos, pos, cell_size)
		WaveScalingGd.KIND_SEED_EXTRA:
			_spawn_icon(SeedExtraIconGd.new(), grid_pos, pos, cell_size)


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
