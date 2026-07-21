extends Node2D
## Dueño exclusivo de la matriz de bloques (GDD secciones 2 y 4). Modo Infinito: crea la
## fila inicial al empezar la partida y spawnea filas nuevas al azar según wave_scaling.gd,
## para siempre.
##
## Modo Nivel: contenido finito y determinista (mismo tablero para todos, ver
## level_loader.gd/LevelManager), con TRES mecanismos que un nivel puede combinar (`static`
## es mutuamente excluyente con `row_queue`, ver level_loader.gd):
## - `cells` — celdas ya colocadas en su posición absoluta desde el inicio (niveles-figura:
##   toda la forma visible de una vez).
## - `row_queue` — filas que aparecen una por turno, igual que Modo Infinito pero con
##   contenido fijo en vez de aleatorio (niveles de dificultad progresiva: arrancan
##   mostrando 1 fila y el resto se revela de a poco, hasta agotar la cola).
## - `static: true` — niveles-figura de ALTA resolución (grilla propia vía `grid_cols`/
##   `grid_rows`, ver _setup_static_layout/_spawn_static_cell, centrada y auto-escalada
##   para nunca invadir el área del molcajete): los bloques NUNCA se desplazan y NO hay
##   condición de derrota; se gana al despejar todo lo destructible, sin importar los turnos.
## El nivel (no-static) se gana cuando la cola ya no tiene más filas Y no queda ningún
## bloque destructible (piedra no cuenta) — antes de eso, aunque el tablero esté
## momentáneamente limpio, todavía falta contenido por venir. TurnManager NUNCA toca esta
## matriz directamente — solo EventBus.

const WaveScalingGd := preload("res://src/features/board/wave_scaling.gd")
const CellFactoryGd := preload("res://src/features/board/cell_factory.gd")
const GridMathGd := preload("res://src/shared/grid_math.gd")
const LevelLoaderGd := preload("res://src/features/levels/level_loader.gd")
const LaserIconGd := preload("res://src/features/powerups/laser_icon.gd")

var _wave: int = 1
var _blocks: Dictionary[Vector2i, StaticBody2D] = {}
var _icons: Dictionary[Vector2i, Area2D] = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _level_row_queue: Array = []
var _level_queue_index: int = 0
var _is_static_level: bool = false
var _static_cell_size: float = 0.0
var _static_origin: Vector2 = Vector2.ZERO
var _static_turns_used: int = 0


func _ready() -> void:
	## Grupo (no class_name/get_node hardcodeado, regla CLAUDE.md #3) — VFXSpawner lo usa
	## para llamar grid_to_pixel() y ubicar sus partículas correctamente en niveles
	## `static` (bug real detectado con captura: el VFX aparecía fuera de la figura).
	add_to_group(&"board_manager")
	EventBus.game_started.connect(_on_game_started)
	EventBus.all_seeds_returned.connect(_on_all_seeds_returned)
	EventBus.block_destroyed.connect(_on_block_destroyed)
	EventBus.salsa_exploded.connect(_on_salsa_exploded)
	EventBus.laser_triggered.connect(_on_laser_triggered)


func get_wave() -> int:
	return _wave


## Convierte una posición de grilla a píxeles — la grilla NORMAL de 7 columnas, o la
## PROPIA de un nivel `static` (más ancha/angosta según el nivel) según corresponda. Único
## punto de verdad para esta conversión: quien necesite ubicar algo en el tablero (ej.
## VFXSpawner) debe llamar esto en vez de usar GridMathGd directo, que siempre asume la
## grilla normal y da resultados incorrectos para un nivel `static`.
func grid_to_pixel(grid_pos: Vector2i) -> Vector2:
	if _is_static_level:
		return _static_origin + _static_cell_size * (Vector2(grid_pos) + Vector2(0.5, 0.5))
	return Vector2(
		GridMathGd.col_to_x(grid_pos.x, Constants.DESIGN_WIDTH),
		GridMathGd.row_to_y(grid_pos.y, Constants.DESIGN_WIDTH)
	)


func _on_game_started() -> void:
	_clear_board()
	_is_static_level = false
	_static_turns_used = 0
	var level_id: String = GameManager.get_current_level_id()
	if level_id.is_empty():
		_wave = 1
		_spawn_row(0)
		EventBus.wave_advanced.emit(_wave)
		return
	var data: Dictionary = LevelManager.get_level_data(level_id)
	_is_static_level = LevelLoaderGd.is_static_level(data)
	if _is_static_level:
		_setup_static_layout(data)
		for cell: Dictionary in data.get("cells", []) as Array:
			_spawn_static_cell(cell)
		return
	for cell: Dictionary in data.get("cells", []) as Array:
		_spawn_level_cell(cell)
	_level_row_queue = data.get("row_queue", []) as Array
	_level_queue_index = 0
	_spawn_next_queued_row()  # revela la primera fila de la cola (si el nivel tiene una)


## Calcula `_static_cell_size` como el MÁS GRANDE que quepa en ancho Y alto dentro del
## área jugable (nunca solo en ancho) — bug real corregido: un nivel `static` con muchas
## filas terminaba dibujándose encima del molcajete porque el cell_size solo se ajustaba
## al ancho. `grid_rows` (obligatorio, ver level_loader.gd) es lo que permite calcular esto
## SIN tener que recorrer `cells` primero. `_static_origin` centra el resultado en ambos
## ejes dentro del área segura (pedido explícito del usuario: "centrarlos verticalmente").
func _setup_static_layout(data: Dictionary) -> void:
	var grid_cols: int = int(data.get("grid_cols", Constants.GRID_COLS))
	var grid_rows: int = int(data.get("grid_rows", 1))
	var safe_height: float = (
		Constants.DESIGN_HEIGHT - Constants.BOARD_TOP_MARGIN - Constants.STATIC_LEVEL_BOTTOM_MARGIN
	)
	_static_cell_size = minf(
		Constants.DESIGN_WIDTH / float(grid_cols), safe_height / float(grid_rows)
	)
	var content_w: float = _static_cell_size * grid_cols
	var content_h: float = _static_cell_size * grid_rows
	_static_origin = Vector2(
		(Constants.DESIGN_WIDTH - content_w) * 0.5,
		Constants.BOARD_TOP_MARGIN + (safe_height - content_h) * 0.5
	)


## GDD "Fase de Avance": una vez que la última semilla regresa, los bloques sobrevivientes
## bajan una fila. Si algún bloque queda en la fila del molcajete tras bajar, la partida
## termina (GDD "Condiciones de Fin de Juego") — igual en Modo Infinito y Modo Nivel
## normal. Modo Infinito además spawnea una fila aleatoria nueva; Modo Nivel revela la
## siguiente fila de la cola (si queda alguna) y, si ya no queda ninguna Y el tablero está
## libre de destructibles, declara el nivel ganado. `EventBus.turn_advanced` se emite
## siempre que el turno termina SIN que la partida haya terminado (ni game over ni nivel
## ganado) — es la señal que TurnManager necesita para volver a AIMING; regresión real
## encontrada jugando: Modo Nivel nunca emitía `wave_advanced` (específica de Infinito) y
## TurnManager dependía solo de esa señal, así que el apuntado se quedaba trabado para
## siempre después del primer turno.
##
## Nivel `static` (pedido explícito del usuario): los bloques NUNCA se desplazan y no hay
## condición de derrota — se salta _shift_down()/_check_game_over() por completo. Solo se
## cuentan los turnos usados (para el bono de score de GameManager si el nivel define
## `par_turns`) y se revisa si ya se despejó todo.
func _on_all_seeds_returned(_landing_x: float) -> void:
	if not GameManager.is_playing():
		return
	var level_id: String = GameManager.get_current_level_id()
	if _is_static_level:
		_static_turns_used += 1
		if _all_destructible_cleared():
			EventBus.level_cleared.emit(level_id, _static_turns_used)
			return
		EventBus.turn_advanced.emit()
		return
	_shift_down()
	if _check_game_over():
		EventBus.board_reached_bottom.emit()
		return
	if level_id.is_empty():
		_wave += 1
		_spawn_row(0)
		EventBus.wave_advanced.emit(_wave)
		EventBus.turn_advanced.emit()
		return
	_spawn_next_queued_row()
	if _level_queue_index >= _level_row_queue.size() and _all_destructible_cleared():
		EventBus.level_cleared.emit(level_id, 0)
		return
	EventBus.turn_advanced.emit()


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


## Nivel `static`: usa la grilla PROPIA del nivel (_static_cell_size/_static_origin,
## calculados en _setup_static_layout() a partir de `grid_cols`/`grid_rows`) en vez de
## GridMathGd/Constants.GRID_COLS — es la única forma de que quepan muchos más bloques, más
## chicos, en el mismo ancho de pantalla (pedido explícito del usuario: "cuadros más
## pequeños" para apreciar figuras de alta resolución), CENTRADA (pedido explícito) y sin
## invadir nunca el área del molcajete. Nunca se desplaza, así que la fila puede ser
## cualquier entero >= 0 (validado contra `grid_rows` en level_loader.gd) sin relación con
## Constants.MOLCAJETE_ROW.
func _spawn_static_cell(cell: Dictionary) -> void:
	var kind: String = cell.get("kind", "") as String
	var node: Node = CellFactoryGd.create_kind_instance(kind)
	if node == null:
		return
	var grid_pos := Vector2i(int(cell.get("col", 0)), int(cell.get("row", 0)))
	var pos: Vector2 = _static_origin + _static_cell_size * (Vector2(grid_pos) + Vector2(0.5, 0.5))
	if kind == WaveScalingGd.KIND_TRIANGLE:
		node.set(&"corner", int(cell.get("corner", 0)))
	if kind == WaveScalingGd.KIND_LASER:
		node.set(&"orientation", cell.get("orientation", LaserIconGd.ORIENTATION_HORIZONTAL))
	if kind == WaveScalingGd.KIND_SEED_EXTRA and cell.has("amount"):
		node.set(&"amount", int(cell.get("amount")))
	if CellFactoryGd.is_icon_kind(kind):
		_spawn_icon(node as Area2D, grid_pos, pos, _static_cell_size)
		return
	var hp: int = int(cell.get("hp", 1))
	_spawn_block(node as StaticBody2D, grid_pos, pos, hp, _static_cell_size)


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


## `grid_pos` se propaga a CUALQUIER ícono (no solo laser_icon.gd) vía `.set()` — un no-op
## silencioso en LemonIcon/SeedExtraIcon (no declaran esa propiedad, regla CLAUDE.md #15
## sobre Object.set() en propiedades inexistentes), pero es justo lo que laser_icon.gd
## necesita para saber qué fila/columna disparar al tocarlo.
func _spawn_icon(icon: Area2D, grid_pos: Vector2i, pos: Vector2, cell_size: float) -> void:
	add_child(icon)
	icon.position = pos
	icon.set(&"grid_pos", grid_pos)
	icon.call(&"setup", cell_size)
	_icons[grid_pos] = icon


func _on_block_destroyed(grid_pos: Vector2i, _block_type: String, _score_value: int) -> void:
	_blocks.erase(grid_pos)


## GDD actualizado (pedido explícito del usuario): "cuando la salsa explote debe destruir
## todos los bloques que estén alrededor (los que estén pegados)" — los 8 vecinos, no solo
## en cruz, y DESTRUCCIÓN instantánea (destroy_instantly()), no daño parcial. "A excepción
## de si es un láser, un bloque de piedra u otro comodín (power up)": la piedra queda
## exenta gratis vía el guard de is_indestructible ya existente en destroy_instantly(); los
## power-ups (lemon/seed_extra/laser) viven en `_icons`, un Dictionary aparte que este
## bucle ni siquiera recorre, así que ya están a salvo por construcción.
func _on_salsa_exploded(grid_pos: Vector2i) -> void:
	for neighbor: Vector2i in GridMathGd.surrounding_neighbors(grid_pos.x, grid_pos.y):
		if _blocks.has(neighbor):
			var node: StaticBody2D = _blocks[neighbor]
			if is_instance_valid(node):
				node.call(&"destroy_instantly")


## Power-up láser (ver laser_icon.gd, pedido explícito del usuario): daño en línea recta —
## fila completa, columna completa, o AMBAS ("both": cada bloque de esa fila O columna,
## un alcance mucho mayor que la cruz local de la salsa) — en vez de en cruz como la
## salsa. Recorre _blocks.keys() con un filtro simple — el tablero es un Dictionary
## disperso (no un array denso), así que esto funciona igual de bien con la grilla enorme
## de un nivel `static` que con la grilla normal de 7 columnas. Se ejecuta cada vez que el
## ícono se toca (persistente, ver laser_icon.gd) — nunca un evento de una sola vez.
func _on_laser_triggered(grid_pos: Vector2i, orientation: String) -> void:
	var hits_row: bool = orientation != LaserIconGd.ORIENTATION_VERTICAL
	var hits_col: bool = orientation != LaserIconGd.ORIENTATION_HORIZONTAL
	for key: Vector2i in _blocks.keys():
		var same_line: bool = (hits_row and key.y == grid_pos.y) or (hits_col and key.x == grid_pos.x)
		if not same_line:
			continue
		var node: StaticBody2D = _blocks[key]
		if is_instance_valid(node):
			node.call(&"take_explosion_damage", Constants.LASER_DAMAGE)
