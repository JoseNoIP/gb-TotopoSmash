extends GutTest
## Tests para VFXSpawner: ubicación correcta de partículas vía BoardManager.grid_to_pixel()
## (bug real corregido: antes VFXSpawner calculaba su propia conversión grid->píxel
## asumiendo siempre la grilla normal de 7 columnas, dando una posición incorrecta en
## niveles `static` con su propia grilla — detectado con captura real al agregar el VFX
## del láser, pero afectaba a TODOS los VFX por igual).

const BoardManagerGd := preload("res://src/features/board/board_manager.gd")
const VfxSpawnerGd := preload("res://src/features/vfx/vfx_spawner.gd")


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
