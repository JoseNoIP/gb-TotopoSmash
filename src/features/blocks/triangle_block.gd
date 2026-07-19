extends "res://src/features/blocks/block_base.gd"
## Bloque triangular (GDD sección 4.2, oleadas 6-15 "Geometría"): "cambian por
## completo los ángulos de rebote habituales (enviar las semillas a 45° o cambiar
## la dirección vertical)". Usa un CollisionPolygon2D en vez del rectángulo de
## block_base.gd: la reflexión física normal (physics_math.gd, aplicada por Seed)
## ya produce el ángulo correcto según qué cara del triángulo golpee la semilla —
## no hace falta lógica especial de rebote aquí.
##
## SUPUESTO (no especificado en el GDD): el triángulo es una variante geométrica del
## totopo normal (mismo color, misma vida N=O) — la sección 3 no le asigna un material
## propio, la 4.2 solo lo introduce como complejidad de forma.
##
## Contrato: quien instancia este bloque debe asignar `corner` ANTES de llamar setup(),
## porque _build_shape()/_build_visual() (invocados desde dentro de setup()) lo leen
## para elegir la orientación. `corner` = esquina "cortada" del cuadrado de la celda:
## 0=arriba-izq, 1=arriba-der, 2=abajo-der, 3=abajo-izq.
##
## DECISIÓN DE DISEÑO CONFIRMADA (el GDD no especifica el criterio): la esquina se elige
## uniforme al azar en BoardManager._spawn_cell(), UNA vez por instancia, en el momento del
## spawn — no en cada rebote. Esto es intencional y no un placeholder: la forma resultante
## es 100% visible antes de que cualquier semilla la toque, y el rebote lo determina la
## física normal (physics_math.gd) según qué cara golpee. El jugador siempre puede leer el
## ángulo de rebote con solo mirar el triángulo — la variedad es puramente geométrica/visual
## entre instancias distintas del tablero, nunca información oculta o injusta para una
## instancia ya visible. Coincide con el pilar de diseño del GDD ("Cálculo de Ángulos").

var corner: int = 0


func _ready() -> void:
	block_type = "triangle"


func _build_shape(cell_size: float) -> void:
	var poly_shape: CollisionPolygon2D = CollisionPolygon2D.new()
	poly_shape.name = &"CollisionPolygon2D"
	poly_shape.polygon = _triangle_points(cell_size)
	add_child(poly_shape)


func _build_visual(cell_size: float) -> void:
	var points: PackedVector2Array = _triangle_points(cell_size)
	var poly: Polygon2D = Polygon2D.new()
	poly.name = &"Visual"
	poly.polygon = points
	poly.color = _get_color()
	add_child(poly)
	_visual = poly

	var centroid: Vector2 = (points[0] + points[1] + points[2]) / 3.0
	_build_hp_label(cell_size, centroid)


func _triangle_points(cell_size: float) -> PackedVector2Array:
	var h: float = cell_size * 0.46
	var square: Array[Vector2] = [
		Vector2(-h, -h),  # 0 arriba-izq
		Vector2(h, -h),  # 1 arriba-der
		Vector2(h, h),  # 2 abajo-der
		Vector2(-h, h),  # 3 abajo-izq
	]
	var indices: Array[int] = [0, 1, 2, 3]
	indices.erase(clampi(corner, 0, 3))
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in indices:
		points.append(square[i])
	return points


func _get_color() -> Color:
	return Constants.COLOR_TOTOPO
