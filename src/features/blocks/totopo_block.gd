extends "res://src/features/blocks/block_base.gd"
## Bloque normal (GDD sección 3): "Se va agrietando conforme baja su vida.
## Explota en migajas al llegar a 0."
## Sin vida propia: hereda take_damage/_die de block_base.gd sin cambios.


func _ready() -> void:
	block_type = "totopo"


## Oscurece el color base proporcionalmente al daño acumulado — simula el "agrietado"
## sin necesitar sprites de grietas (no hay assets de arte todavía, ver /gen-ai-art).
func _update_visual() -> void:
	super._update_visual()
	if max_hp <= 0 or _visual == null:
		return
	var hp_ratio: float = float(current_hp) / float(max_hp)
	var cracked_color: Color = _get_color().lerp(Color(0.25, 0.2, 0.15), 1.0 - hp_ratio)
	(_visual as ColorRect).color = cracked_color


func _get_color() -> Color:
	return Constants.COLOR_TOTOPO
