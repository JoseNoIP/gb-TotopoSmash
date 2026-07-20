extends GutTest
## Tests para LevelSelectScreen: solo debe mostrar el roster numérico secuencial. Pedido
## explícito del usuario: los packs temáticos (holiday_00N/worldcup_00N) tienen su propia
## pantalla dedicada (PackSelectScreen -> PackLevelsScreen) y NO deben aparecer también
## acá — antes convivían en una sección aparte ("PACKS ESPECIALES") al final del scroll.

const LevelSelectScreenGd := preload("res://src/scenes/LevelSelectScreen.gd")


func _find_button_with_text(root: Node, text: String) -> Button:
	for child: Node in root.get_children():
		if child is Button and (child as Button).text == text:
			return child as Button
		var found: Button = _find_button_with_text(child, text)
		if found != null:
			return found
	return null


func _find_label_with_text(root: Node, text: String) -> Label:
	for child: Node in root.get_children():
		if child is Label and (child as Label).text == text:
			return child as Label
		var found: Label = _find_label_with_text(child, text)
		if found != null:
			return found
	return null


func test_is_pack_level_detects_by_id_prefix() -> void:
	var screen: Control = LevelSelectScreenGd.new()
	add_child_autofree(screen)
	assert_false(screen.call(&"_is_pack_level", "level_042"))
	assert_true(screen.call(&"_is_pack_level", "holiday_001"))
	assert_true(screen.call(&"_is_pack_level", "worldcup_003"))


## Regresión directa del pedido del usuario: un botón de pack (ej. "holiday_001") no debe
## poder encontrarse por su número de posición en el manifiesto — esta pantalla ya no
## construye ningún botón para ids que no empiecen con "level_".
func test_pack_levels_do_not_appear_as_buttons() -> void:
	var screen: Control = LevelSelectScreenGd.new()
	add_child_autofree(screen)
	var pack_number: int = LevelManager.get_level_index("holiday_001") + 1
	var pack_button: Button = _find_button_with_text(screen, str(pack_number))
	assert_null(pack_button, "los niveles de pack no deben mostrarse en LevelSelectScreen")


func test_pack_section_label_no_longer_appears() -> void:
	var screen: Control = LevelSelectScreenGd.new()
	add_child_autofree(screen)
	var label: Label = _find_label_with_text(screen, "TITLE_LEVEL_PACKS")
	assert_null(label, "la sección de packs se quitó de esta pantalla")


func test_numeric_level_button_count_matches_only_non_pack_manifest_entries() -> void:
	var screen: Control = LevelSelectScreenGd.new()
	add_child_autofree(screen)
	var expected: int = 0
	for level_id: String in LevelManager.get_manifest():
		if (level_id as String).begins_with("level_"):
			expected += 1
	var count: int = 0
	for child: Node in screen.find_children("*", "Button", true, false):
		if (child as Button).text != "BTN_BACK":
			count += 1
	assert_eq(count, expected)
