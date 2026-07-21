extends GutTest
## Tests para VFXSpawner: ubicación correcta de partículas vía BoardManager.grid_to_pixel()
## (bug real corregido: antes VFXSpawner calculaba su propia conversión grid->píxel
## asumiendo siempre la grilla normal de 7 columnas, dando una posición incorrecta en
## niveles `static` con su propia grilla — detectado con captura real al agregar el VFX
## del láser, pero afectaba a TODOS los VFX por igual).

const BoardManagerGd := preload("res://src/features/board/board_manager.gd")
const VfxSpawnerGd := preload("res://src/features/vfx/vfx_spawner.gd")
const LaserBeamGd := preload("res://src/features/vfx/laser_beam.gd")


func _beams_of(root: Node) -> Array:
	var beams: Array = []
	for child: Node in root.get_children():
		if child.get_script() == LaserBeamGd:
			beams.append(child)
	return beams


func _first_particle_position(root: Node) -> Variant:
	if root.get_child_count() == 0:
		return null
	return (root.get_child(0) as Node2D).position


func test_laser_vfx_spawns_at_the_static_layout_position_not_the_normal_grid() -> void:
	var board: Node2D = BoardManagerGd.new()
	add_child_autofree(board)
	var vfx: Node2D = VfxSpawnerGd.new()
	add_child_autofree(vfx)
	GameManager.start_game("worldcup_001")

	var static_cell_size: float = board.get(&"_static_cell_size")
	var static_origin: Vector2 = board.get(&"_static_origin")
	var grid_pos := Vector2i(2, 3)
	var expected: Vector2 = static_origin + static_cell_size * (Vector2(grid_pos) + Vector2(0.5, 0.5))

	EventBus.laser_triggered.emit(grid_pos, "horizontal")
	var particle_pos: Variant = _first_particle_position(vfx)
	assert_not_null(particle_pos, "arreglo del test: debe haberse creado al menos una partícula")
	assert_eq(particle_pos, expected)
	GameManager.start_game()


## Pedido explícito del usuario: "solo se ve un pequeño destello... lo esperado es que se
## vea una línea horizontal, vertical o ambas que está golpeando todos los ladrillos" — el
## rayo debe recorrer TODA la fila (columna 0 a la última), no solo el punto de origen.
func test_laser_triggered_spawns_a_beam_spanning_the_full_row() -> void:
	var board: Node2D = BoardManagerGd.new()
	add_child_autofree(board)
	var vfx: Node2D = VfxSpawnerGd.new()
	add_child_autofree(vfx)
	GameManager.start_game()
	var grid_pos := Vector2i(3, 2)

	EventBus.laser_triggered.emit(grid_pos, "horizontal")

	var beams: Array = _beams_of(vfx)
	assert_eq(beams.size(), 1, "orientación horizontal debe crear exactamente un rayo")
	var beam: Node2D = beams[0]
	var expected_from: Vector2 = board.call(&"grid_to_pixel", Vector2i(0, grid_pos.y))
	var last_col := Vector2i(Constants.GRID_COLS - 1, grid_pos.y)
	var expected_to: Vector2 = board.call(&"grid_to_pixel", last_col)
	assert_eq(beam.get(&"_from"), expected_from)
	assert_eq(beam.get(&"_to"), expected_to)


## orientation "both" debe crear DOS rayos (uno horizontal, uno vertical) — mismo alcance
## que BoardManager._on_laser_triggered() ya calcula para el daño real.
func test_laser_triggered_with_both_orientation_spawns_two_beams() -> void:
	var board: Node2D = BoardManagerGd.new()
	add_child_autofree(board)
	var vfx: Node2D = VfxSpawnerGd.new()
	add_child_autofree(vfx)
	GameManager.start_game()

	EventBus.laser_triggered.emit(Vector2i(1, 1), "both")

	var msg: String = "orientación 'both' debe crear un rayo horizontal y uno vertical"
	assert_eq(_beams_of(vfx).size(), 2, msg)
