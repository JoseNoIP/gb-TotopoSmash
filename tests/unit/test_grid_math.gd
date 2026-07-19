extends GutTest
## Tests para conversiones grid <-> píxeles (rejilla 7x9 del GDD sección 2).

const GridMathGd := preload("res://src/shared/grid_math.gd")

const WIDTH: float = 390.0


func test_cell_size_divides_width_by_column_count() -> void:
	assert_almost_eq(GridMathGd.cell_size(WIDTH), WIDTH / 7.0, 0.001)


func test_col_to_x_centers_within_first_column() -> void:
	var expected: float = GridMathGd.cell_size(WIDTH) * 0.5
	assert_almost_eq(GridMathGd.col_to_x(0, WIDTH), expected, 0.01)


func test_col_to_x_centers_within_last_column() -> void:
	var expected: float = GridMathGd.cell_size(WIDTH) * 6.5
	assert_almost_eq(GridMathGd.col_to_x(6, WIDTH), expected, 0.01)


func test_col_from_x_clamps_negative_to_first_column() -> void:
	assert_eq(GridMathGd.col_from_x(-50.0, WIDTH), 0, "entrada fuera de pantalla debe clampar a 0")


func test_col_from_x_clamps_overflow_to_last_column() -> void:
	assert_eq(GridMathGd.col_from_x(10000.0, WIDTH), Constants.GRID_COLS - 1)


func test_col_from_x_round_trips_with_col_to_x() -> void:
	for col: int in Constants.GRID_COLS:
		var x: float = GridMathGd.col_to_x(col, WIDTH)
		var msg: String = "el centro de una columna debe mapear de vuelta a esa columna"
		assert_eq(GridMathGd.col_from_x(x, WIDTH), col, msg)


func test_molcajete_y_sits_above_bottom_margin() -> void:
	var height: float = 844.0
	assert_almost_eq(
		GridMathGd.molcajete_y(height), height - Constants.MOLCAJETE_BOTTOM_MARGIN, 0.01
	)


func test_is_in_bounds_accepts_corners_of_the_grid() -> void:
	assert_true(GridMathGd.is_in_bounds(0, 0))
	assert_true(GridMathGd.is_in_bounds(Constants.GRID_COLS - 1, Constants.GRID_ROWS - 1))


func test_is_in_bounds_rejects_out_of_range_values() -> void:
	assert_false(GridMathGd.is_in_bounds(-1, 0), "columna negativa es inválida")
	assert_false(GridMathGd.is_in_bounds(Constants.GRID_COLS, 0), "col == GRID_COLS ya es inválida")
	assert_false(GridMathGd.is_in_bounds(0, Constants.GRID_ROWS), "row == GRID_ROWS ya es inválida")


func test_cross_neighbors_center_cell_has_four_neighbors() -> void:
	var neighbors: Array = GridMathGd.cross_neighbors(3, 4)
	assert_eq(neighbors.size(), 4)
	assert_has(neighbors, Vector2i(3, 3))
	assert_has(neighbors, Vector2i(3, 5))
	assert_has(neighbors, Vector2i(2, 4))
	assert_has(neighbors, Vector2i(4, 4))


func test_cross_neighbors_corner_cell_has_two_neighbors() -> void:
	var neighbors: Array = GridMathGd.cross_neighbors(0, 0)
	assert_eq(neighbors.size(), 2, "una esquina solo tiene 2 vecinos válidos en cruz")
	assert_has(neighbors, Vector2i(1, 0))
	assert_has(neighbors, Vector2i(0, 1))


func test_cross_neighbors_never_returns_out_of_bounds_cells() -> void:
	var neighbors: Array = GridMathGd.cross_neighbors(0, 0)
	for neighbor: Vector2i in neighbors:
		assert_true(GridMathGd.is_in_bounds(neighbor.x, neighbor.y))
