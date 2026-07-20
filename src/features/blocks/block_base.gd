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
var _visual: CanvasItem = null
var _cell_size: float = 0.0


## Board llama esto justo después de instanciar el bloque.
func setup(p_grid_pos: Vector2i, p_hp: int, p_cell_size: float) -> void:
	grid_pos = p_grid_pos
	max_hp = p_hp
	current_hp = p_hp
	_cell_size = p_cell_size
	collision_layer = Constants.LAYER_BLOCKS
	collision_mask = 0
	_build_shape(p_cell_size)
	_build_visual(p_cell_size)
	_update_visual()


## Golpe normal de una semilla. La cantidad de daño base la decide el propio bloque
## (Queso la sobreescribe a 2 vía damage_per_hit), multiplicada por la mejora "Daño Base"
## comprada en la tienda (MetaManager) — mínimo 1 para que un bloque siempre pueda morir.
func take_damage() -> void:
	var amount: int = maxi(1, roundi(damage_per_hit * MetaManager.get_damage_multiplier()))
	_apply_damage(amount)


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


## Sprite2D con textura real si existe (ver tools/gen_assets.py); si no, cae al
## ColorRect plano de siempre — nunca crashea si falta el asset todavía.
func _build_visual(cell_size: float) -> void:
	var visual_size: float = cell_size * 0.92
	var texture_path: String = _get_texture_path()
	if not texture_path.is_empty() and ResourceLoader.exists(texture_path):
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = load(texture_path)
		var tex_size: Vector2 = sprite.texture.get_size()
		sprite.scale = Vector2(visual_size / tex_size.x, visual_size / tex_size.y)
		sprite.name = &"Visual"
		add_child(sprite)
		_visual = sprite
	else:
		var rect: ColorRect = ColorRect.new()
		rect.size = Vector2(visual_size, visual_size)
		rect.position = Vector2(visual_size, visual_size) * -0.5
		rect.color = _get_color()
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.pivot_offset = rect.size * 0.5  ## para que scale/rotation pivoteen al centro
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
	var font_size: int = clampi(
		roundi(cell_size * Constants.UI_HP_FONT_SIZE_RATIO),
		Constants.UI_HP_FONT_MIN_SIZE, Constants.UI_MIN_FONT_SIZE
	)
	_hp_label.add_theme_font_size_override(&"font_size", font_size)
	_hp_label.position = Vector2(visual_size, visual_size) * -0.5 + center_offset
	_hp_label.size = Vector2(visual_size, visual_size)
	_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hp_label)


## El número de HP se oculta en bloques muy chicos (niveles `static` de alta resolución,
## ver BoardManager — celdas de ~9px en vez de los ~56px normales): a ese tamaño el texto
## es ilegible y solo agrega ruido visual, arruinando el propósito de "apreciar la figura"
## (pedido explícito del usuario tras ver el resultado real con captura de pantalla).
func _update_visual() -> void:
	var too_small_to_read: bool = _cell_size > 0.0 and _cell_size < Constants.UI_MIN_READABLE_CELL_SIZE
	_hp_label.text = "" if (is_indestructible or too_small_to_read) else str(current_hp)


## Hook de color — usado como fallback si _get_texture_path() no existe todavía,
## y como base para el tinte de "agrietado" en subtipos que lo necesitan.
func _get_color() -> Color:
	return Constants.COLOR_TOTOPO


## Hook de textura — cada subtipo lo sobreescribe apuntando a su sprite en
## assets/sprites/blocks/. "" (default) = usar el ColorRect + _get_color().
func _get_texture_path() -> String:
	return ""
