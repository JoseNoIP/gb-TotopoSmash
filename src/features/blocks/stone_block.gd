extends "res://src/features/blocks/block_base.gd"
## Piedra de Molcajete (GDD sección 4.2, oleadas 16-30): "Bloques indestructibles...
## no tienen número. No se pueden eliminar; actúan como deflectores fijos."
## Reutiliza la geometría rectangular de block_base.gd — solo cambia el flag
## is_indestructible y el color. take_damage()/take_explosion_damage() ya son no-op
## en block_base cuando is_indestructible es true.


func _ready() -> void:
	block_type = "stone"
	is_indestructible = true


func _get_color() -> Color:
	return Constants.COLOR_STONE
