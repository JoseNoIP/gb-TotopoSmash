extends GutTest
## Tests para PackSelectScreen: lista de packs temáticos (Constants.LEVEL_PACKS) y
## navegación al pack elegido vía el buzón LevelManager.get_pending_pack_prefix().

const PackSelectScreenGd := preload("res://src/scenes/PackSelectScreen.gd")


func _find_button_with_text(root: Node, text: String) -> Button:
	for child: Node in root.get_children():
		if child is Button and (child as Button).text == text:
			return child as Button
		var found: Button = _find_button_with_text(child, text)
		if found != null:
			return found
	return null


func _count_levels_with_prefix(prefix: String) -> int:
	var count: int = 0
	for level_id: String in LevelManager.get_manifest():
		if (level_id as String).begins_with(prefix + "_"):
			count += 1
	return count


func test_shows_a_card_for_each_registered_pack_with_levels() -> void:
	var screen: Control = PackSelectScreenGd.new()
	add_child_autofree(screen)
	for pack: Dictionary in Constants.LEVEL_PACKS:
		var prefix: String = pack.get("prefix", "") as String
		var count: int = _count_levels_with_prefix(prefix)
		assert_true(count > 0, "arreglo del test: %s debe tener niveles en el manifiesto real" % prefix)
		var pack_name: String = tr(pack.get("name_key", "") as String)
		var expected_text: String = tr(&"LABEL_PACK_CARD") % [pack_name, count]
		var btn: Button = _find_button_with_text(screen, expected_text)
		assert_not_null(btn, "debe existir una tarjeta para el pack '%s'" % prefix)


func test_pressing_a_pack_card_sets_the_pending_pack_prefix() -> void:
	var screen: Control = PackSelectScreenGd.new()
	add_child_autofree(screen)
	screen.call(&"_on_pack_pressed", "holiday")
	assert_eq(LevelManager.get_pending_pack_prefix(), "holiday")
