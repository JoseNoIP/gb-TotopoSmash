extends StaticBody2D
## Paredes laterales y techo del tablero (GDD sección 2, "Fase de Rebote": las semillas
## "rebotan con física elástica perfecta... contra las paredes laterales, techo y
## bloques"). `Constants.LAYER_WORLD` se usaba como máscara de colisión en seed.gd y
## mortar.gd pero ningún cuerpo real vivía en esa capa — una semilla que no golpeaba un
## bloque salía disparada fuera de pantalla para siempre y TurnManager quedaba trabado
## en RESOLVING (nunca llega _floor_y). Instanciado por Game.gd y TutorialGame.gd.

const GridMathGd := preload("res://src/shared/grid_math.gd")
const WALL_THICKNESS: float = 40.0


func _ready() -> void:
	collision_layer = Constants.LAYER_WORLD
	collision_mask = 0
	var width: float = Constants.DESIGN_WIDTH
	var top: float = GridMathGd.board_top_y()
	var bottom: float = Constants.DESIGN_HEIGHT
	var half_thick: float = WALL_THICKNESS * 0.5

	_add_wall(Vector2(-half_thick, (top + bottom) * 0.5), Vector2(WALL_THICKNESS, bottom - top))
	_add_wall(Vector2(width + half_thick, (top + bottom) * 0.5), Vector2(WALL_THICKNESS, bottom - top))
	_add_wall(Vector2(width * 0.5, top - half_thick), Vector2(width, WALL_THICKNESS))


func _add_wall(center: Vector2, size: Vector2) -> void:
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = size
	var col: CollisionShape2D = CollisionShape2D.new()
	col.shape = shape
	col.position = center
	add_child(col)
