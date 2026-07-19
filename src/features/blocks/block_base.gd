extends StaticBody2D
## Bloque base del tablero (GDD sección 3). Maneja HP, daño y señales.
## NO implementa geometría/visual concreta — cada subtipo sobreescribe
## _build_shape() / _build_visual() / _update_visual() según su apariencia.
## Anti-patrón #16 (skill /feature): nunca modificar esta base directamente para
## agregar comportamiento de un tipo — heredar en su propio archivo.

var grid_pos: Vector2i = Vector2i.ZERO
var max_hp: int = 1
var current_hp: int = 1
var damage_per_hit: int = Constants.BLOCK_NORMAL_DAMAGE_PER_HIT
var is_indestructible: bool = false
var block_type: String = "totopo"

var _hp_label: Label = Label.new()
var _visual: Node = null


## Board llama esto justo después de instanciar el bloque.
func setup(p_grid_pos: Vector2i, p_hp: int, p_cell_size: float) -> void:
	grid_pos = p_grid_pos
	max_hp = p_hp
	current_hp = p_hp
	collision_layer = Constants.LAYER_BLOCKS
	collision_mask = 0
	_build_shape(p_cell_size)
	_build_visual(p_cell_size)
	_update_visual()


## Golpe normal de una semilla. La cantidad de daño la decide el propio bloque
## (Queso la sobreescribe a 2 vía damage_per_hit).
func take_damage() -> void:
	_apply_damage(damage_per_hit)


## Daño explícito (usado por la explosión en cruz del Frasco de Salsa).
func take_explosion_damage(amount: int) -> void:
	_apply_damage(amount)


## Hook para efectos al rebotar (Queso lo usa para frenar la semilla). No-op por defecto.
func on_seed_bounce(_seed_node: Node) -> void:
	pass


func _apply_damage(amount: int) -> void:
	if is_indestructible or current_hp <= 0:
		return
	current_hp = maxi(0, current_hp - amount)
	EventBus.block_damaged.emit(grid_pos, current_hp, max_hp)
	_update_visual()
	if current_hp <= 0:
		_die()


func _die() -> void:
	var score_value: int = max_hp * Constants.SCORE_PER_DAMAGE_POINT
	EventBus.block_destroyed.emit(grid_pos, block_type, score_value)
	queue_free()


func _build_shape(cell_size: float) -> void:
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(cell_size, cell_size) * 0.92
	var col_shape: CollisionShape2D = CollisionShape2D.new()
	col_shape.name = &"CollisionShape2D"
	col_shape.shape = shape
	add_child(col_shape)


func _build_visual(cell_size: float) -> void:
	var visual_size: float = cell_size * 0.92
	var rect: ColorRect = ColorRect.new()
	rect.size = Vector2(visual_size, visual_size)
	rect.position = Vector2(visual_size, visual_size) * -0.5
	rect.color = _get_color()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.pivot_offset = rect.size * 0.5  ## para que scale/rotation (squish, blink) pivoteen al centro
	rect.name = &"Visual"
	add_child(rect)
	_visual = rect

	_build_hp_label(cell_size, Vector2.ZERO)


## Reutilizable por subtipos con geometría propia (ej. TriangleBlock) que no usan el
## ColorRect por defecto pero sí necesitan mostrar el HP restante.
func _build_hp_label(cell_size: float, center_offset: Vector2) -> void:
	var visual_size: float = cell_size * 0.92
	_hp_label.name = &"HpLabel"
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_label.add_theme_font_size_override(&"font_size", Constants.UI_MIN_FONT_SIZE)
	_hp_label.position = Vector2(visual_size, visual_size) * -0.5 + center_offset
	_hp_label.size = Vector2(visual_size, visual_size)
	_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hp_label)


func _update_visual() -> void:
	_hp_label.text = "" if is_indestructible else str(current_hp)


## Hook de color — cada subtipo lo sobreescribe para pintar su propio material.
## Vive en la base para que _build_visual() no se duplique en cada subtipo.
func _get_color() -> Color:
	return Constants.COLOR_TOTOPO
