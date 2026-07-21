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


## Regla GDD actualizada (pedido explícito del usuario): la salsa ya no daña solo en
## cruz, ahora destruye TODOS los bloques pegados alrededor — los 8 vecinos, incluidas
## las 4 diagonales.
func test_surrounding_neighbors_center_cell_has_eight_neighbors() -> void:
	var neighbors: Array = GridMathGd.surrounding_neighbors(3, 4)
	assert_eq(neighbors.size(), 8)
	assert_has(neighbors, Vector2i(3, 3))
	assert_has(neighbors, Vector2i(3, 5))
	assert_has(neighbors, Vector2i(2, 4))
	assert_has(neighbors, Vector2i(4, 4))
	assert_has(neighbors, Vector2i(2, 3))
	assert_has(neighbors, Vector2i(4, 3))
	assert_has(neighbors, Vector2i(2, 5))
	assert_has(neighbors, Vector2i(4, 5))


## SIN filtrar por límites a propósito (ver comentario en grid_math.gd) — una esquina
## (0,0) real del tablero normal sigue devolviendo sus 8 offsets, aunque algunos caigan
## fuera de Constants.GRID_COLS/GRID_ROWS; quien la llama (BoardManager) ya filtra por si
## existe un bloque real ahí, así que valores "fuera de rango" son inofensivos.
func test_surrounding_neighbors_corner_cell_still_returns_eight_offsets() -> void:
	var neighbors: Array = GridMathGd.surrounding_neighbors(0, 0)
	assert_eq(neighbors.size(), 8)
	assert_has(neighbors, Vector2i(-1, -1))
	assert_has(neighbors, Vector2i(1, 1))
