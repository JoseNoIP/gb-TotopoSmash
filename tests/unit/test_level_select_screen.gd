extends GutTest
## Tests para LevelSelectScreen: distinción "nivel numérico" vs "pack temático" y que los
## packs siempre estén desbloqueados. Regresión de un bug real reportado por el usuario:
## los packs (holiday_00N/worldcup_00N) quedaban inaccesibles en la práctica porque el
## desbloqueo secuencial normal exige terminar los 100 niveles numéricos primero para
## llegar a esa posición del manifiesto — un pack "opcional/bonus" no debería depender de
## eso.

const LevelSelectScreenGd := preload("res://src/scenes/LevelSelectScreen.gd")


func _find_button_with_text(root: Node, text: String) -> Button:
	for child: Node in root.get_children():
		if child is Button and (child as Button).text == text:
			return child as Button
		var found: Button = _find_button_with_text(child, text)
		if found != null:
			return found
	return null


func test_is_pack_level_detects_by_id_prefix() -> void:
	var screen: Control = LevelSelectScreenGd.new()
	add_child_autofree(screen)
	assert_false(screen.call(&"_is_pack_level", "level_042"))
	assert_true(screen.call(&"_is_pack_level", "holiday_001"))
	assert_true(screen.call(&"_is_pack_level", "worldcup_003"))


func test_pack_level_buttons_are_always_enabled_regardless_of_unlock_progress() -> void:
	var screen: Control = LevelSelectScreenGd.new()
	add_child_autofree(screen)
	var pack_number: int = LevelManager.get_level_index("holiday_001") + 1
	var pack_button: Button = _find_button_with_text(screen, str(pack_number))
	assert_not_null(pack_button, "arreglo del test: debe existir un botón para holiday_001")
	assert_false(pack_button.disabled, "los packs temáticos deben estar siempre desbloqueados")


func test_pack_section_label_appears_when_packs_exist() -> void:
	var screen: Control = LevelSelectScreenGd.new()
	add_child_autofree(screen)
	var manifest: Array = LevelManager.get_manifest()
	var has_packs: bool = false
	for level_id: String in manifest:
		if not level_id.begins_with("level_"):
			has_packs = true
			break
	assert_true(has_packs, "arreglo del test: el manifiesto real debe tener al menos un pack")
	var label: Label = _find_label_with_text(screen, "TITLE_LEVEL_PACKS")
	assert_not_null(label, "debe mostrarse un encabezado separando los packs del roster numérico")


func _find_label_with_text(root: Node, text: String) -> Label:
	for child: Node in root.get_children():
		if child is Label and (child as Label).text == text:
			return child as Label
		var found: Label = _find_label_with_text(child, text)
		if found != null:
			return found
	return null
