extends GutTest
## Tests para PackLevelsScreen: grilla filtrada a un solo pack (via el buzón
## LevelManager.get_pending_pack_prefix()), con desbloqueo SECUENCIAL dentro del pack
## (pedido explícito del usuario tras jugar: antes todos los niveles de un pack aparecían
## habilitados desde el inicio).
##
## `LevelManager._pack_progress` persiste en user://pack_progress.json (autoload real, sin
## mock) — todo test que lo mueva debe restaurarlo EN DISCO al final (no solo en memoria,
## llamando `_save_pack_progress()`), mismo criterio que test_save_manager.gd/
## test_meta_manager.gd tras el bug real de contaminación de esta sesión (ver
## tools/run_tests.sh, que además respalda pack_progress.json como red de seguridad).

const PackLevelsScreenGd := preload("res://src/scenes/PackLevelsScreen.gd")


func _count_buttons(root: Node) -> int:
	var count: int = 0
	for child: Node in root.get_children():
		if child is Button:
			count += 1
		count += _count_buttons(child)
	return count


func _find_button_with_text_containing(root: Node, needle: String) -> Button:
	for child: Node in root.get_children():
		if child is Button and (child as Button).text.contains(needle):
			return child as Button
		var found: Button = _find_button_with_text_containing(child, needle)
		if found != null:
			return found
	return null


## Quita `prefix` del progreso real (simula un pack nunca antes jugado) y devuelve el
## valor original para restaurarlo con `_restore_pack_progress()` al final del test.
func _clear_pack_progress(prefix: String) -> Variant:
	var progress: Dictionary = LevelManager.get(&"_pack_progress")
	LevelManager.set(&"_pack_progress_loaded", true)
	var original: Variant = progress.get(prefix)
	progress.erase(prefix)
	return original


func _restore_pack_progress(prefix: String, original: Variant) -> void:
	var progress: Dictionary = LevelManager.get(&"_pack_progress")
	if original == null:
		progress.erase(prefix)
	else:
		progress[prefix] = original
	LevelManager.call(&"_save_pack_progress")


func test_shows_only_the_levels_of_the_pending_pack() -> void:
	LevelManager.set_pending_pack_prefix("holiday")
	var screen: Control = PackLevelsScreenGd.new()
	add_child_autofree(screen)
	var expected: int = 0
	for level_id: String in LevelManager.get_manifest():
		if (level_id as String).begins_with("holiday_"):
			expected += 1
	## +1 por el botón VOLVER, que no pertenece a la grilla de niveles.
	assert_eq(_count_buttons(screen), expected + 1)


func test_first_pack_level_is_unlocked_by_default() -> void:
	var original: Variant = _clear_pack_progress("worldcup")

	LevelManager.set_pending_pack_prefix("worldcup")
	var screen: Control = PackLevelsScreenGd.new()
	add_child_autofree(screen)
	var first_btn: Button = _find_button_with_text_containing(screen, "1.")
	assert_not_null(first_btn, "arreglo del test: debe existir un botón para el nivel 1")
	assert_false(first_btn.disabled, "el primer nivel de un pack siempre debe estar desbloqueado")
	var second_btn: Button = _find_button_with_text_containing(screen, "2.")
	assert_true(second_btn.disabled, "el segundo nivel debe empezar bloqueado")

	_restore_pack_progress("worldcup", original)


## Regresión directa del bug real reportado jugando: completar un nivel de PACK no debe
## afectar el desbloqueo del roster numérico (antes usaba la posición GLOBAL del
## manifiesto, desbloqueando casi toda la campaña de un solo golpe).
func test_completing_a_pack_level_does_not_affect_the_numeric_campaign() -> void:
	var original: Variant = _clear_pack_progress("holiday")
	var before: int = SaveManager.get_highest_level_unlocked()

	LevelManager.mark_level_completed("holiday_001")
	assert_eq(SaveManager.get_highest_level_unlocked(), before)

	_restore_pack_progress("holiday", original)


func test_completing_a_pack_level_unlocks_the_next_one_in_that_pack_only() -> void:
	var original_holiday: Variant = _clear_pack_progress("holiday")
	var original_worldcup: Variant = _clear_pack_progress("worldcup")

	LevelManager.call(&"_mark_pack_level_completed", "holiday_001")
	assert_eq(LevelManager.call(&"get_pack_highest_unlocked", "holiday"), 2)
	assert_eq(
		LevelManager.call(&"get_pack_highest_unlocked", "worldcup"), 1,
		"completar un nivel del pack navideño no debe desbloquear nada del pack Mundial"
	)

	_restore_pack_progress("holiday", original_holiday)
	_restore_pack_progress("worldcup", original_worldcup)
