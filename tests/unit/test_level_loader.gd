extends GutTest
## Tests para level_loader.gd: parseo puro (sin autoloads de nivel) y validate_level().

const LevelLoaderGd := preload("res://src/features/levels/level_loader.gd")


func _valid_level() -> Dictionary:
	return {
		"id": "level_test",
		"starting_seeds": 10,
		"cells": [
			{"col": 0, "row": 0, "kind": "totopo", "hp": 2},
			{"col": 1, "row": 0, "kind": "lemon"},
		],
	}


func test_parse_level_json_returns_empty_dict_for_missing_file() -> void:
	var data: Dictionary = LevelLoaderGd.parse_level_json("res://data/levels/no_existe.json")
	assert_eq(data, {})


func test_validate_level_accepts_a_minimal_valid_level() -> void:
	var errors: Array = LevelLoaderGd.validate_level(_valid_level(), "level_test")
	assert_eq(errors, [])


func test_validate_level_rejects_empty_data() -> void:
	var errors: Array = LevelLoaderGd.validate_level({}, "level_test")
	assert_true(errors.size() > 0)


func test_validate_level_rejects_id_mismatch() -> void:
	var errors: Array = LevelLoaderGd.validate_level(_valid_level(), "level_other")
	assert_true(errors.size() > 0)


func test_validate_level_rejects_non_positive_starting_seeds() -> void:
	var data: Dictionary = _valid_level()
	data["starting_seeds"] = 0
	var errors: Array = LevelLoaderGd.validate_level(data, "level_test")
	assert_true(errors.size() > 0)


func test_validate_level_rejects_molcajete_row() -> void:
	var data: Dictionary = _valid_level()
	data["cells"] = [{"col": 0, "row": Constants.MOLCAJETE_ROW, "kind": "totopo", "hp": 1}]
	var errors: Array = LevelLoaderGd.validate_level(data, "level_test")
	assert_true(errors.size() > 0, "la fila del molcajete nunca debe aceptarse")


func test_validate_level_rejects_col_out_of_range() -> void:
	var data: Dictionary = _valid_level()
	data["cells"] = [{"col": Constants.GRID_COLS, "row": 0, "kind": "totopo", "hp": 1}]
	var errors: Array = LevelLoaderGd.validate_level(data, "level_test")
	assert_true(errors.size() > 0)


func test_validate_level_rejects_duplicate_positions() -> void:
	var data: Dictionary = _valid_level()
	data["cells"] = [
		{"col": 0, "row": 0, "kind": "totopo", "hp": 1},
		{"col": 0, "row": 0, "kind": "queso", "hp": 2},
	]
	var errors: Array = LevelLoaderGd.validate_level(data, "level_test")
	assert_true(errors.size() > 0)


func test_validate_level_rejects_unknown_kind() -> void:
	var data: Dictionary = _valid_level()
	data["cells"] = [{"col": 0, "row": 0, "kind": "unicornio"}]
	var errors: Array = LevelLoaderGd.validate_level(data, "level_test")
	assert_true(errors.size() > 0)


func test_validate_level_rejects_missing_hp_where_required() -> void:
	var data: Dictionary = _valid_level()
	data["cells"] = [{"col": 0, "row": 0, "kind": "queso"}]
	var errors: Array = LevelLoaderGd.validate_level(data, "level_test")
	assert_true(errors.size() > 0, "queso requiere hp")


func test_validate_level_rejects_triangle_without_corner() -> void:
	var data: Dictionary = _valid_level()
	data["cells"] = [{"col": 0, "row": 0, "kind": "triangle", "hp": 2}]
	var errors: Array = LevelLoaderGd.validate_level(data, "level_test")
	assert_true(errors.size() > 0, "triangle requiere corner")


func test_validate_level_accepts_stone_and_icons_without_hp() -> void:
	var data: Dictionary = _valid_level()
	data["cells"] = [
		{"col": 0, "row": 0, "kind": "stone"},
		{"col": 1, "row": 0, "kind": "lemon"},
		{"col": 2, "row": 0, "kind": "seed_extra"},
	]
	var errors: Array = LevelLoaderGd.validate_level(data, "level_test")
	assert_eq(errors, [])
