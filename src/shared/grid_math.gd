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


## Los 8 vecinos alrededor de (col,row) — arriba/abajo/izq/der + las 4 diagonales — para
## la explosión de salsa (GDD actualizado, pedido explícito del usuario: "debe destruir
## todos los bloques que estén alrededor... los que estén pegados", no solo en cruz).
## SIN filtrar por is_in_bounds(): esa función usa Constants.GRID_COLS/GRID_ROWS (la
## grilla del tablero NORMAL), que da resultados incorrectos para niveles `static` con su
## propia grilla más ancha (ver board_manager.gd) — el propio Dictionary disperso de
## BoardManager (`_blocks.has(neighbor)`) ya es el único chequeo de límites que hace falta.
static func surrounding_neighbors(col: int, row: int) -> Array:
	var result: Array = []
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			result.append(Vector2i(col + dx, row + dy))
	return result
