extends "res://src/features/blocks/block_base.gd"
## Bloque de Queso (GDD sección 3): "Ladrillo pesado. Absorbe el doble de daño por
## impacto (N-2), pero reduce la velocidad de la semilla un 15% al rebotar."
## Vida inicial escalada x1.5 respecto al totopo (ver wave_scaling.gd, aplicado por
## quien invoca setup() — este script solo define damage_per_hit y el frenado).

var _squish_tween: Tween = null


func _ready() -> void:
	block_type = "queso"
	damage_per_hit = Constants.BLOCK_QUESO_DAMAGE_PER_HIT


## Frena la semilla 15% (con piso mínimo) y le da un pequeño "squish" visual al bloque
## para transmitir la sensación viscosa/densa que pide el GDD.
func on_seed_bounce(seed_node: Node) -> void:
	if seed_node.has_method(&"apply_speed_ratio"):
		seed_node.call(&"apply_speed_ratio", Constants.SEED_QUESO_SLOWDOWN_RATIO)
	_play_squish()


func _play_squish() -> void:
	if _visual == null:
		return
	if _squish_tween and _squish_tween.is_valid():
		_squish_tween.kill()
	## .set(&"scale", ...) en vez de _visual.scale =: "scale" no vive en CanvasItem (lo
	## declaran Node2D y Control por separado) — regla CLAUDE.md #15. tween_property() sí
	## es seguro con acceso directo porque resuelve la propiedad en runtime, no en estático.
	_visual.set(&"scale", Vector2(1.15, 0.85))
	_squish_tween = create_tween()
	_squish_tween.tween_property(_visual, ^"scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT)


func _get_color() -> Color:
	return Constants.COLOR_QUESO


func _get_texture_path() -> String:
	return "res://assets/sprites/blocks/queso.png"
