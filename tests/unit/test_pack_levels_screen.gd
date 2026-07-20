extends GutTest
## Tests para PackLevelsScreen: grilla filtrada a un solo pack (via el buzón
## LevelManager.get_pending_pack_prefix()), siempre desbloqueada.

const PackLevelsScreenGd := preload("res://src/scenes/PackLevelsScreen.gd")


func _count_buttons(root: Node) -> int:
	var count: int = 0
	for child: Node in root.get_children():
		if child is Button:
			count += 1
		count += _count_buttons(child)
	return count


func _all_buttons_enabled(root: Node) -> bool:
	for child: Node in root.get_children():
		if child is Button and (child as Button).disabled:
			return false
		if not _all_buttons_enabled(child):
			return false
	return true


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


func test_all_pack_level_buttons_are_enabled() -> void:
	LevelManager.set_pending_pack_prefix("worldcup")
	var screen: Control = PackLevelsScreenGd.new()
	add_child_autofree(screen)
	var msg: String = "los niveles de un pack deben estar siempre desbloqueados"
	assert_true(_all_buttons_enabled(screen), msg)
