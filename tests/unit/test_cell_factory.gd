extends GutTest
## Tests para cell_factory.gd: la única fábrica "kind -> nodo" (Infinito y Modo Nivel).

const CellFactoryGd := preload("res://src/features/board/cell_factory.gd")
const WaveScalingGd := preload("res://src/features/board/wave_scaling.gd")


## setup() se llama con datos dummy antes de add_child_autofree(): block_base.gd crea un
## Label interno (_hp_label) como valor por defecto de propiedad, que solo se parenta
## como hijo real DENTRO de setup()/_build_visual(). Sin llamarlo, ese Label queda
## huérfano (nunca se agregó a ningún árbol) y add_child_autofree/free() no lo alcanza.
func test_create_kind_instance_maps_every_known_kind_to_a_node() -> void:
	for kind: String in CellFactoryGd.KNOWN_KINDS:
		var node: Node = CellFactoryGd.create_kind_instance(kind)
		assert_not_null(node, "kind '%s' debe producir una instancia" % kind)
		if node == null:
			continue
		if CellFactoryGd.is_icon_kind(kind):
			node.call(&"setup", 50.0)
		else:
			if kind == WaveScalingGd.KIND_TRIANGLE:
				node.set(&"corner", 0)
			node.call(&"setup", Vector2i.ZERO, 1, 50.0)
		add_child_autofree(node)


func test_create_kind_instance_returns_null_for_empty_kind() -> void:
	assert_null(CellFactoryGd.create_kind_instance(WaveScalingGd.KIND_EMPTY))


func test_create_kind_instance_returns_null_for_unknown_kind() -> void:
	assert_null(CellFactoryGd.create_kind_instance("no_existe"))


func test_is_icon_kind_true_only_for_lemon_and_seed_extra() -> void:
	assert_true(CellFactoryGd.is_icon_kind(WaveScalingGd.KIND_LEMON))
	assert_true(CellFactoryGd.is_icon_kind(WaveScalingGd.KIND_SEED_EXTRA))
	assert_false(CellFactoryGd.is_icon_kind(WaveScalingGd.KIND_TOTOPO))
	assert_false(CellFactoryGd.is_icon_kind(WaveScalingGd.KIND_STONE))


func test_is_known_kind() -> void:
	assert_true(CellFactoryGd.is_known_kind(WaveScalingGd.KIND_TOTOPO))
	assert_false(CellFactoryGd.is_known_kind("no_existe"))
	assert_false(CellFactoryGd.is_known_kind(WaveScalingGd.KIND_EMPTY))
