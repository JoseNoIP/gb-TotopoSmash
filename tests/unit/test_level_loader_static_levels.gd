extends GutTest
## Tests para level_loader.gd: niveles `static` (figuras de alta resolución, sin condición
## de derrota) y el power-up láser — pedidos explícitos del usuario. Separado de
## test_level_loader.gd porque ese archivo ya rozaba el máximo de 20 métodos públicos por
## clase que exige gdlint (mismo motivo que MetaManager, ver regla CLAUDE.md #51).

const LevelLoaderGd := preload("res://src/features/levels/level_loader.gd")


func _valid_static_level() -> Dictionary:
	return {
		"id": "level_test",
		"starting_seeds": 50,
		"static": true,
		"grid_cols": 30,
		"grid_rows": 150,
		"cells": [
			{"col": 25, "row": 100, "kind": "totopo", "hp": 200},  # fuera del grid normal
		],
	}


func test_validate_level_accepts_a_static_level_with_grid_cols() -> void:
	var errors: Array = LevelLoaderGd.validate_level(_valid_static_level(), "level_test")
	assert_eq(errors, [])


func test_validate_level_rejects_static_without_grid_cols() -> void:
	var data: Dictionary = _valid_static_level()
	data.erase("grid_cols")
	var errors: Array = LevelLoaderGd.validate_level(data, "level_test")
	assert_true(errors.size() > 0, "'static' sin 'grid_cols' debe rechazarse")


func test_validate_level_rejects_static_without_grid_rows() -> void:
	var data: Dictionary = _valid_static_level()
	data.erase("grid_rows")
	var errors: Array = LevelLoaderGd.validate_level(data, "level_test")
	assert_true(errors.size() > 0, "'static' sin 'grid_rows' debe rechazarse")


func test_validate_level_rejects_static_combined_with_row_queue() -> void:
	var data: Dictionary = _valid_static_level()
	data["row_queue"] = [[{"col": 0, "kind": "totopo", "hp": 1}]]
	var errors: Array = LevelLoaderGd.validate_level(data, "level_test")
	assert_true(errors.size() > 0, "'static' + 'row_queue' es una combinación inválida")


func test_validate_level_static_cell_col_bounded_by_grid_cols_not_constants() -> void:
	var data: Dictionary = _valid_static_level()
	data["cells"] = [{"col": 30, "row": 0, "kind": "totopo", "hp": 1}]  # grid_cols=30 -> max col 29
	var errors: Array = LevelLoaderGd.validate_level(data, "level_test")
	var msg: String = "col debe validarse contra grid_cols del nivel, no Constants.GRID_COLS"
	assert_true(errors.size() > 0, msg)


func test_validate_level_static_cell_row_can_exceed_molcajete_row() -> void:
	var data: Dictionary = _valid_static_level()
	data["cells"] = [{"col": 0, "row": Constants.MOLCAJETE_ROW + 5, "kind": "totopo", "hp": 1}]
	var errors: Array = LevelLoaderGd.validate_level(data, "level_test")
	assert_eq(errors, [], "un nivel static no tiene fila de molcajete prohibida")


## Regresión directa del bug real reportado jugando: un nivel `static` sin límite de fila
## real terminaba dibujándose sobre el molcajete. `grid_rows` ahora acota `row` igual que
## `grid_cols` acota `col`.
func test_validate_level_static_cell_row_bounded_by_grid_rows() -> void:
	var data: Dictionary = _valid_static_level()
	data["grid_rows"] = 10
	data["cells"] = [{"col": 0, "row": 10, "kind": "totopo", "hp": 1}]  # grid_rows=10 -> max row 9
	var errors: Array = LevelLoaderGd.validate_level(data, "level_test")
	assert_true(errors.size() > 0, "row debe validarse contra grid_rows del nivel")


func test_validate_level_rejects_invalid_par_turns() -> void:
	var data: Dictionary = _valid_static_level()
	data["par_turns"] = 0
	var errors: Array = LevelLoaderGd.validate_level(data, "level_test")
	assert_true(errors.size() > 0)


func test_validate_level_accepts_valid_par_turns() -> void:
	var data: Dictionary = _valid_static_level()
	data["par_turns"] = 20
	var errors: Array = LevelLoaderGd.validate_level(data, "level_test")
	assert_eq(errors, [])


func test_validate_level_accepts_laser_with_valid_orientation() -> void:
	var data: Dictionary = _valid_static_level()
	data["cells"] = [{"col": 0, "row": 0, "kind": "laser", "orientation": "vertical"}]
	var errors: Array = LevelLoaderGd.validate_level(data, "level_test")
	assert_eq(errors, [])


func test_validate_level_rejects_laser_with_invalid_orientation() -> void:
	var data: Dictionary = _valid_static_level()
	data["cells"] = [{"col": 0, "row": 0, "kind": "laser", "orientation": "diagonal"}]
	var errors: Array = LevelLoaderGd.validate_level(data, "level_test")
	assert_true(errors.size() > 0)


func test_validate_level_accepts_laser_without_orientation() -> void:
	var data: Dictionary = _valid_static_level()
	data["cells"] = [{"col": 0, "row": 0, "kind": "laser"}]
	var errors: Array = LevelLoaderGd.validate_level(data, "level_test")
	assert_eq(errors, [], "'orientation' es opcional (BoardManager usa horizontal por default)")


func test_validate_level_accepts_seed_extra_with_valid_amount() -> void:
	var data: Dictionary = _valid_static_level()
	data["cells"] = [{"col": 0, "row": 0, "kind": "seed_extra", "amount": 25}]
	var errors: Array = LevelLoaderGd.validate_level(data, "level_test")
	assert_eq(errors, [])


func test_validate_level_rejects_seed_extra_with_invalid_amount() -> void:
	var data: Dictionary = _valid_static_level()
	data["cells"] = [{"col": 0, "row": 0, "kind": "seed_extra", "amount": 0}]
	var errors: Array = LevelLoaderGd.validate_level(data, "level_test")
	assert_true(errors.size() > 0)


func test_validate_level_accepts_seed_extra_without_amount() -> void:
	var data: Dictionary = _valid_static_level()
	data["cells"] = [{"col": 0, "row": 0, "kind": "seed_extra"}]
	var errors: Array = LevelLoaderGd.validate_level(data, "level_test")
	assert_eq(errors, [], "'amount' es opcional (default Constants.SEED_EXTRA_AMOUNT)")


func test_is_static_level_reads_the_static_field() -> void:
	assert_true(LevelLoaderGd.is_static_level({"static": true}))
	assert_false(LevelLoaderGd.is_static_level({"static": false}))
	assert_false(LevelLoaderGd.is_static_level({}))
