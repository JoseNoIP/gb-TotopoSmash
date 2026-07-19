extends "res://src/features/blocks/block_base.gd"
## Bloque normal (GDD sección 3): "Se va agrietando conforme baja su vida.
## Explota en migajas al llegar a 0."
## Sin vida propia: hereda take_damage/_die de block_base.gd sin cambios.


func _ready() -> void:
	block_type = "totopo"


## Oscurece el tinte proporcionalmente al daño acumulado — simula el "agrietado" sin
## necesitar sprites de grietas propios. modulate (no .color) funciona igual sobre el
## ColorRect de fallback y sobre el Sprite2D real (ver _get_texture_path()).
func _update_visual() -> void:
	super._update_visual()
	if max_hp <= 0 or _visual == null:
		return
	var hp_ratio: float = float(current_hp) / float(max_hp)
	_visual.modulate = Color.WHITE.lerp(Color(0.45, 0.35, 0.28), 1.0 - hp_ratio)


func _get_color() -> Color:
	return Constants.COLOR_TOTOPO


func _get_texture_path() -> String:
	return "res://assets/sprites/blocks/totopo.png"
