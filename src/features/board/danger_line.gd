extends Node2D
## Línea de peligro en el borde superior de la fila del molcajete (GDD "Condiciones de
## Fin de Juego": si cualquier bloque la cruza al terminar un turno, la partida termina).
## Puramente visual — no es collider, no afecta la física.
##
## Diseño (v2, tras feedback de que la línea punteada simple "no daba suficiente
## sensación de no querer cruzarla"): banda de degradado rojo que se desvanece hacia
## arriba + línea sólida pulsante + chevrones apuntando hacia abajo estilo cinta de
## peligro — todo animado con un pulso lento (_process + queue_redraw, se detiene solo
## si el árbol se pausa, ya que no usa PROCESS_MODE_ALWAYS).

const GridMathGd := preload("res://src/shared/grid_math.gd")

const GLOW_HEIGHT: float = 34.0
const GLOW_BANDS: int = 10
const GLOW_MAX_ALPHA: float = 0.35
const LINE_WIDTH: float = 3.0
const CHEVRON_SPACING: float = 26.0
const CHEVRON_WIDTH: float = 14.0
const CHEVRON_HEIGHT: float = 9.0
const PULSE_SPEED: float = 3.0  ## rad/s — ciclo completo cada ~2s

var _time: float = 0.0
var _line_y: float = 0.0


func _ready() -> void:
	var cell_size: float = GridMathGd.cell_size(Constants.DESIGN_WIDTH)
	var row_center_y: float = GridMathGd.row_to_y(Constants.MOLCAJETE_ROW, Constants.DESIGN_WIDTH)
	_line_y = row_center_y - cell_size * 0.5
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	## pulse oscila 0..1 — nunca llega a 0 del todo para que la línea nunca desaparezca.
	var pulse: float = 0.5 + 0.5 * sin(_time * PULSE_SPEED)
	_draw_glow(pulse)
	_draw_chevrons(pulse)
	_draw_solid_line(pulse)


## Banda que se desvanece hacia arriba, más intensa pegada a la línea — refuerza "esto de
## aquí para abajo es zona prohibida" sin necesitar una textura de degradado.
func _draw_glow(pulse: float) -> void:
	var base: Color = Constants.COLOR_DANGER_LINE
	for i: int in GLOW_BANDS:
		var t0: float = float(i) / GLOW_BANDS
		var t1: float = float(i + 1) / GLOW_BANDS
		var y0: float = _line_y - GLOW_HEIGHT * (1.0 - t0)
		var y1: float = _line_y - GLOW_HEIGHT * (1.0 - t1)
		var band_alpha: float = GLOW_MAX_ALPHA * t1 * (0.6 + 0.4 * pulse)
		draw_rect(
			Rect2(0.0, y0, Constants.DESIGN_WIDTH, y1 - y0),
			Color(base.r, base.g, base.b, band_alpha)
		)


func _draw_chevrons(pulse: float) -> void:
	var color: Color = Constants.COLOR_DANGER_LINE
	color.a = 0.55 + 0.45 * pulse
	var x: float = CHEVRON_SPACING * 0.5
	while x < Constants.DESIGN_WIDTH:
		var points := PackedVector2Array([
			Vector2(x - CHEVRON_WIDTH * 0.5, _line_y - CHEVRON_HEIGHT),
			Vector2(x + CHEVRON_WIDTH * 0.5, _line_y - CHEVRON_HEIGHT),
			Vector2(x, _line_y),
		])
		draw_polygon(points, PackedColorArray([color]))
		x += CHEVRON_SPACING


func _draw_solid_line(pulse: float) -> void:
	var color: Color = Constants.COLOR_DANGER_LINE
	color.a = 0.7 + 0.3 * pulse
	draw_line(Vector2(0.0, _line_y), Vector2(Constants.DESIGN_WIDTH, _line_y), color, LINE_WIDTH)
