extends GutTest
## Test "dorado": recorre CADA id real en data/levels/manifest.json, carga y valida cada
## archivo real con LevelLoaderGd.validate_level(). Mantiene consistente todo el catálogo
## de niveles según se le vayan agregando más (con tools/gen_levels.py o con la skill
## /level-designer) sin necesitar un test nuevo por cada nivel.

const LevelLoaderGd := preload("res://src/features/levels/level_loader.gd")


func test_manifest_is_not_empty() -> void:
	var manifest: Array = LevelLoaderGd.parse_manifest()
	assert_true(manifest.size() > 0, "el manifiesto no debe estar vacío")


func test_every_level_in_manifest_is_valid() -> void:
	var manifest: Array = LevelLoaderGd.parse_manifest()
	for level_id: String in manifest:
		var data: Dictionary = LevelLoaderGd.load_level(level_id)
		var errors: Array = LevelLoaderGd.validate_level(data, level_id)
		assert_eq(errors, [], "nivel '%s' tiene errores: %s" % [level_id, errors])


func test_every_level_has_at_least_one_destructible_cell() -> void:
	var manifest: Array = LevelLoaderGd.parse_manifest()
	for level_id: String in manifest:
		var data: Dictionary = LevelLoaderGd.load_level(level_id)
		var has_destructible: bool = false
		for cell: Dictionary in data.get("cells", []) as Array:
			if cell.get("kind") != "stone":
				has_destructible = true
				break
		if not has_destructible:
			for row_cells: Array in data.get("row_queue", []) as Array:
				for cell: Dictionary in row_cells:
					if cell.get("kind") != "stone":
						has_destructible = true
						break
				if has_destructible:
					break
		assert_true(has_destructible, "nivel '%s' no tiene ningún bloque destructible" % level_id)


func test_manifest_ids_are_unique() -> void:
	var manifest: Array = LevelLoaderGd.parse_manifest()
	var seen: Dictionary = {}
	for level_id: String in manifest:
		assert_false(seen.has(level_id), "id duplicado en el manifiesto: %s" % level_id)
		seen[level_id] = true
