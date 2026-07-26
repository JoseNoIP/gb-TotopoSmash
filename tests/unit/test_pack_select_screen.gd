extends GutTest
## Tests para PackSelectScreen: lista de packs temáticos (Constants.LEVEL_PACKS) y
## navegación al pack elegido vía el buzón LevelManager.get_pending_pack_prefix().

const PackSelectScreenGd := preload("res://src/scenes/PackSelectScreen.gd")


func _find_label_with_text(root: Node, text: String) -> Label:
	for child: Node in root.get_children():
		if child is Label and (child as Label).text == text:
			return child as Label
		var found: Label = _find_label_with_text(child, text)
		if found != null:
			return found
	return null


func _count_levels_with_prefix(prefix: String) -> int:
	var count: int = 0
	for level_id: String in LevelManager.get_manifest():
		if (level_id as String).begins_with(prefix + "_"):
			count += 1
	return count


## Pedido explícito del usuario ("revisa qué pantallas necesitan pulirse"): la tarjeta de
## cada pack ahora es un Button de texto VACÍO (identidad visual vía StyleBox propio, ver
## PackSelectScreen.gd) con el nombre y el progreso como Label hijos independientes — ya
## no se puede buscar por el texto combinado de un solo botón.
func test_shows_a_card_for_each_registered_pack_with_levels() -> void:
	var screen: Control = PackSelectScreenGd.new()
	add_child_autofree(screen)
	for pack: Dictionary in Constants.LEVEL_PACKS:
		var prefix: String = pack.get("prefix", "") as String
		var count: int = _count_levels_with_prefix(prefix)
		assert_true(count > 0, "arreglo del test: %s debe tener niveles en el manifiesto real" % prefix)
		var pack_name: String = tr(pack.get("name_key", "") as String)
		var name_label: Label = _find_label_with_text(screen, pack_name)
		assert_not_null(name_label, "debe existir una tarjeta para el pack '%s'" % prefix)
		assert_true(
			name_label.get_parent() is Button,
			"el nombre del pack debe vivir dentro de una tarjeta clickeable"
		)
		var highest_unlocked: int = mini(LevelManager.get_pack_highest_unlocked(prefix), count)
		var expected_progress: String = tr(&"LABEL_PACK_PROGRESS") % [highest_unlocked, count]
		var progress_label: Label = _find_label_with_text(screen, expected_progress)
		assert_not_null(progress_label, "debe mostrar el progreso real del pack '%s'" % prefix)


func test_pressing_a_pack_card_sets_the_pending_pack_prefix() -> void:
	var screen: Control = PackSelectScreenGd.new()
	add_child_autofree(screen)
	screen.call(&"_on_pack_pressed", "holiday")
	assert_eq(LevelManager.get_pending_pack_prefix(), "holiday")
