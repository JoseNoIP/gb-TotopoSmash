extends RefCounted
## Funciones puras de conversión grid <-> píxeles. Sin estado, sin nodos.
## Uso: const GridMathGd := preload("res://src/shared/grid_math.gd")
##      GridMathGd.col_to_x(3, 390.0)


static func cell_size(viewport_width: float) -> float:
	return viewport_width / float(Constants.GRID_COLS)


static func col_to_x(col: int, viewport_width: float) -> float:
	var size: float = cell_size(viewport_width)
	return size * (float(col) + 0.5)


static func row_to_y(row: int, viewport_width: float) -> float:
	var size: float = cell_size(viewport_width)
	return Constants.BOARD_TOP_MARGIN + size * (float(row) + 0.5)


static func col_from_x(x: float, viewport_width: float) -> int:
	var size: float = cell_size(viewport_width)
	return clampi(int(floor(x / size)), 0, Constants.GRID_COLS - 1)


static func board_top_y() -> float:
	return Constants.BOARD_TOP_MARGIN


static func board_bottom_y(viewport_width: float) -> float:
	return Constants.BOARD_TOP_MARGIN + cell_size(viewport_width) * float(Constants.GRID_ROWS)


static func molcajete_y(viewport_height: float) -> float:
	return viewport_height - Constants.MOLCAJETE_BOTTOM_MARGIN


static func is_in_bounds(col: int, row: int) -> bool:
	return col >= 0 and col < Constants.GRID_COLS and row >= 0 and row < Constants.GRID_ROWS


## Vecinos en cruz (arriba, abajo, izquierda, derecha) para la explosión de salsa.
static func cross_neighbors(col: int, row: int) -> Array:
	var result: Array = []
	var candidates: Array = [
		Vector2i(col, row - 1),
		Vector2i(col, row + 1),
		Vector2i(col - 1, row),
		Vector2i(col + 1, row),
	]
	for candidate: Vector2i in candidates:
		if is_in_bounds(candidate.x, candidate.y):
			result.append(candidate)
	return result
