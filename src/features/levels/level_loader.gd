extends RefCounted
## Parseo y validación de niveles finitos/deterministas (JSON, ver data/levels/). Puro y
## sin estado — mismo estilo que wave_scaling.gd/grid_math.gd, testeable sin escena.
## Uso: const LevelLoaderGd := preload("res://src/features/levels/level_loader.gd")

const CellFactoryGd := preload("res://src/features/board/cell_factory.gd")
const WaveScalingGd := preload("res://src/features/board/wave_scaling.gd")

const LEVELS_DIR: String = "res://data/levels/"
const MANIFEST_PATH: String = "res://data/levels/manifest.json"


## Nunca referenciar un autoload (Constants) dentro de un `const` — no es una expresión
## de compilación segura en GDScript (ver wave_scaling.gd/grid_math.gd: siempre acceden a
## Constants dentro de funciones, nunca en declaraciones const). Última fila de contenido
## permitida = justo antes de Constants.MOLCAJETE_ROW; colocar algo ahí sería game over
## instantáneo al primer turno.
static func max_content_row() -> int:
	return Constants.MOLCAJETE_ROW - 1


## Comparación explícita contra `true` (no un `as bool` directo) — el valor viene de JSON
## parseado, así que un `Variant` ausente/de otro tipo nunca debe leerse como verdadero
## por accidente.
static func is_static_level(data: Dictionary) -> bool:
	return data.get("static", false) == true


## Lee y parsea un archivo JSON arbitrario a Dictionary. {} si falta o está corrupto —
## nunca crashea (mismo patrón que SaveManager._load()).
static func parse_level_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


static func parse_manifest() -> Array:
	var data: Dictionary = parse_level_json(MANIFEST_PATH)
	var levels: Variant = data.get("levels")
	return levels if levels is Array else []


static func load_level(level_id: String) -> Dictionary:
	return parse_level_json(LEVELS_DIR + level_id + ".json")


## JSON.parse_string() SIEMPRE devuelve los números como float, nunca int — incluso para
## "col": 3 en el archivo. `3 is int` da false sobre un valor que viene de JSON. Todo
## chequeo de "es un entero" en este archivo debe pasar por aquí, no por `is int` directo.
static func _is_whole_number(value: Variant) -> bool:
	if value is int:
		return true
	return value is float and float(value) == floor(float(value))


## Array de strings de error; vacío = nivel válido. `expected_id` viene de quien pide la
## carga (normalmente el nombre del archivo) para detectar un id que no coincide.
##
## Un nivel define su contenido con `cells` (celdas ya colocadas, absolutas — para
## niveles-figura donde toda la forma es visible desde el inicio) y/o `row_queue` (filas
## que aparecen una por turno, igual que Modo Infinito pero con contenido fijo — para
## niveles de dificultad progresiva). Al menos uno de los dos debe traer contenido real.
##
## `"static": true` (opcional, pedido explícito del usuario) — nivel-figura de ALTA
## resolución: los bloques NUNCA se desplazan y no hay condición de derrota (ver
## BoardManager); usa su PROPIA grilla vía el campo obligatorio `"grid_cols"` (más angosta
## que Constants.GRID_COLS = más bloques, más chicos, caben en el mismo ancho de pantalla),
## así que `col`/`row` de sus `cells` NO se validan contra Constants.GRID_COLS/MOLCAJETE_ROW
## como los niveles-figura normales. Incompatible con `row_queue`. `"par_turns"` (opcional)
## habilita el bono de score por terminarlo en pocos turnos (ver GameManager).
static func validate_level(data: Dictionary, expected_id: String) -> Array:
	var errors: Array = []
	if data.is_empty():
		errors.append("nivel vacío o no se pudo parsear")
		return errors

	var id: Variant = data.get("id")
	if not (id is String) or id.is_empty():
		errors.append("falta 'id' o no es String")
	elif id != expected_id:
		errors.append("'id' (%s) no coincide con el nombre de archivo esperado (%s)" % [id, expected_id])

	var starting_seeds: Variant = data.get("starting_seeds")
	if not _is_whole_number(starting_seeds) or int(starting_seeds) <= 0:
		errors.append("'starting_seeds' debe ser un entero > 0")

	var is_static: bool = data.get("static", false) == true
	var max_col: int = Constants.GRID_COLS - 1
	var max_row: int = max_content_row()
	if is_static:
		var grid_cols: Variant = data.get("grid_cols")
		if not _is_whole_number(grid_cols) or int(grid_cols) <= 0:
			errors.append("nivel 'static' requiere 'grid_cols' entero > 0")
		else:
			max_col = int(grid_cols) - 1
		## grid_rows es obligatorio (no inferido del máximo `row` usado) para que
		## BoardManager pueda centrar la figura verticalmente y escalarla a un cell_size
		## que nunca invada el área del molcajete SIN tener que recorrer todas las celdas
		## primero — bug real corregido: un nivel muy alto tapaba el molcajete.
		var grid_rows: Variant = data.get("grid_rows")
		if not _is_whole_number(grid_rows) or int(grid_rows) <= 0:
			errors.append("nivel 'static' requiere 'grid_rows' entero > 0")
		else:
			max_row = int(grid_rows) - 1
		if data.has("par_turns"):
			var par_turns: Variant = data.get("par_turns")
			if not _is_whole_number(par_turns) or int(par_turns) <= 0:
				errors.append("'par_turns' debe ser un entero > 0 si está presente")

	var cells: Variant = data.get("cells", [])
	var row_queue: Variant = data.get("row_queue", [])
	var has_cells: bool = cells is Array and not (cells as Array).is_empty()
	var has_queue: bool = row_queue is Array and not (row_queue as Array).is_empty()
	if not has_cells and not has_queue:
		errors.append("el nivel no tiene contenido — 'cells' y 'row_queue' están vacíos o ausentes")
		return errors
	if is_static and has_queue:
		errors.append("un nivel 'static' no puede combinarse con 'row_queue'")

	if data.has("cells"):
		if not (cells is Array):
			errors.append("'cells' debe ser un Array")
		else:
			var seen_positions: Dictionary = {}
			for i: int in (cells as Array).size():
				var cell: Variant = (cells as Array)[i]
				if not (cell is Dictionary):
					errors.append("cells[%d]: no es un Dictionary" % i)
					continue
				errors.append_array(
					_validate_cell(
						cell as Dictionary, "cells[%d]" % i, true, seen_positions, max_col, max_row
					)
				)

	if data.has("row_queue"):
		if not (row_queue is Array):
			errors.append("'row_queue' debe ser un Array")
		else:
			for r: int in (row_queue as Array).size():
				var row_cells: Variant = (row_queue as Array)[r]
				if not (row_cells is Array):
					errors.append("row_queue[%d]: debe ser un Array" % r)
					continue
				if (row_cells as Array).size() > Constants.GRID_COLS:
					errors.append("row_queue[%d]: más celdas que columnas tiene el tablero" % r)
				var seen_cols: Dictionary = {}
				for i: int in (row_cells as Array).size():
					var cell: Variant = (row_cells as Array)[i]
					if not (cell is Dictionary):
						errors.append("row_queue[%d][%d]: no es un Dictionary" % [r, i])
						continue
					errors.append_array(
						_validate_cell(
							cell as Dictionary, "row_queue[%d][%d]" % [r, i], false, seen_cols,
							Constants.GRID_COLS - 1, max_content_row()
						)
					)

	return errors


## `require_row`: true para `cells` (posición absoluta, valida col+row+duplicados por
## (col,row)). false para celdas de `row_queue` (la fila es implícita — siempre "la
## próxima fila que aparece arriba" — así que solo se valida `col` y duplicados por col).
## `max_col`/`max_row`: un nivel `static` usa su propia grilla (`grid_cols`/`grid_rows`,
## ver validate_level), así que el rango válido es distinto al de un nivel-figura normal.
static func _validate_cell(
	cell: Dictionary, label: String, require_row: bool, seen_positions: Dictionary,
	max_col: int, max_row: int
) -> Array:
	var errors: Array = []

	var col: Variant = cell.get("col")
	var col_ok: bool = _is_whole_number(col) and int(col) >= 0 and int(col) <= max_col
	if not col_ok:
		errors.append("%s: 'col' fuera de rango [0, %d]" % [label, max_col])

	if require_row:
		var row: Variant = cell.get("row")
		var row_ok: bool = _is_whole_number(row) and int(row) >= 0 and int(row) <= max_row
		if not row_ok:
			errors.append("%s: 'row' fuera de rango [0, %d]" % [label, max_row])
		if col_ok and row_ok:
			var pos_key: Vector2i = Vector2i(int(col), int(row))
			if seen_positions.has(pos_key):
				errors.append("%s: posición (%d,%d) duplicada" % [label, pos_key.x, pos_key.y])
			seen_positions[pos_key] = true
	elif col_ok:
		if seen_positions.has(int(col)):
			errors.append("%s: columna %d duplicada en la misma fila" % [label, int(col)])
		seen_positions[int(col)] = true

	var kind: Variant = cell.get("kind")
	if not (kind is String) or not CellFactoryGd.is_known_kind(kind):
		errors.append("%s: 'kind' desconocido: %s" % [label, str(kind)])
		return errors

	var needs_hp: bool = kind in [
		WaveScalingGd.KIND_TOTOPO, WaveScalingGd.KIND_QUESO,
		WaveScalingGd.KIND_SALSA, WaveScalingGd.KIND_TRIANGLE,
	]
	if needs_hp:
		var hp: Variant = cell.get("hp")
		if not _is_whole_number(hp) or int(hp) <= 0:
			errors.append("%s: kind '%s' requiere 'hp' entero > 0" % [label, kind])

	if kind == WaveScalingGd.KIND_TRIANGLE:
		var corner: Variant = cell.get("corner")
		if not _is_whole_number(corner) or int(corner) < 0 or int(corner) > 3:
			errors.append("%s: kind 'triangle' requiere 'corner' entero en [0,3]" % label)

	if kind == WaveScalingGd.KIND_LASER and cell.has("orientation"):
		var orientation: Variant = cell.get("orientation")
		if orientation != "horizontal" and orientation != "vertical" and orientation != "both":
			errors.append(
				"%s: 'orientation' de laser debe ser 'horizontal', 'vertical' o 'both'" % label
			)

	if kind == WaveScalingGd.KIND_SEED_EXTRA and cell.has("amount"):
		var amount: Variant = cell.get("amount")
		if not _is_whole_number(amount) or int(amount) <= 0:
			errors.append("%s: 'amount' de seed_extra debe ser un entero > 0 si está presente" % label)

	return errors
