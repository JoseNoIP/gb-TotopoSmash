extends GutTest
## Tests para el autoload LevelManager: buzón no destructivo, cache de nivel, manifiesto,
## y persistencia de desbloqueo. Usa el catálogo real en data/levels/ (ya cubierto en
## detalle por test_level_manifest_integrity.gd) solo como fuente de datos existente.


func test_pending_level_roundtrip_is_non_destructive() -> void:
	var original: String = LevelManager.get_pending_level()
	LevelManager.set_pending_level("level_001")
	assert_eq(LevelManager.get_pending_level(), "level_001")
	## Leer de nuevo NO debe vaciar el buzón — crítico para reintentar un nivel.
	assert_eq(LevelManager.get_pending_level(), "level_001")
	LevelManager.set_pending_level(original)


func test_get_manifest_returns_the_real_catalog_in_order() -> void:
	var manifest: Array = LevelManager.get_manifest()
	assert_true(manifest.size() > 0)
	assert_eq(manifest[0], "level_001")


func test_get_level_index_matches_manifest_position() -> void:
	assert_eq(LevelManager.get_level_index("level_001"), 0)
	assert_eq(LevelManager.get_level_index("no_existe"), -1)


func test_get_level_data_caches_the_same_dictionary() -> void:
	var first: Dictionary = LevelManager.get_level_data("level_001")
	var second: Dictionary = LevelManager.get_level_data("level_001")
	assert_true(first.size() > 0)
	assert_eq(first, second)


func test_get_level_data_returns_empty_dict_for_unknown_id() -> void:
	assert_eq(LevelManager.get_level_data("no_existe"), {})


func test_get_level_data_returns_empty_dict_for_empty_id() -> void:
	assert_eq(LevelManager.get_level_data(""), {})


## Relativo/idempotente (no intenta restaurar el valor previo) — mismo estilo que
## test_save_manager.gd, porque highest_level_unlocked persiste entre corridas de test.
func test_mark_level_completed_persists_highest_unlocked() -> void:
	var before: int = SaveManager.get_highest_level_unlocked()
	LevelManager.mark_level_completed("level_001")
	assert_true(SaveManager.get_highest_level_unlocked() >= maxi(before, 2))
