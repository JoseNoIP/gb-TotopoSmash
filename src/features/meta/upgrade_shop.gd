extends RefCounted
## Lógica pura de la tienda de mejoras (oro): costos y bonos por nivel. Sin estado, sin
## nodo — testeable sin escena, mismo estilo que wave_scaling.gd/grid_math.gd.
## `SaveManager` es el dueño del estado persistido (nivel comprado de cada mejora, oro,
## personajes); este módulo solo sabe traducir "nivel N" a "costo"/"bono".

const UPGRADE_IDS: Array = ["seeds", "damage", "speed"]


## Nivel objetivo 1..UPGRADE_MAX_LEVEL. `current_level` = 0 significa "sin comprar
## todavía". Costo lineal creciente, mismo patrón en las 3 mejoras.
static func cost_for_next_level(current_level: int) -> int:
	var next_level: int = current_level + 1
	return Constants.UPGRADE_BASE_COST + (next_level - 1) * Constants.UPGRADE_COST_STEP


static func is_max_level(current_level: int) -> bool:
	return current_level >= Constants.UPGRADE_MAX_LEVEL


static func bonus_seeds(level: int) -> int:
	return level * Constants.UPGRADE_SEEDS_BONUS_PER_LEVEL


static func damage_multiplier(level: int) -> float:
	return 1.0 + level * Constants.UPGRADE_DAMAGE_BONUS_PER_LEVEL


static func seed_speed_multiplier(level: int) -> float:
	return 1.0 + level * Constants.UPGRADE_SPEED_BONUS_PER_LEVEL


## Oro ganado al terminar una run/nivel (victoria, derrota, o nivel fallido — GameManager
## lo otorga siempre que la partida termina, sin distinguir el desenlace).
static func gold_earned_for_score(score: int) -> int:
	return int(floor(score * Constants.GOLD_PER_SCORE_POINT))


static func find_character(character_id: String) -> Dictionary:
	for character: Dictionary in Constants.CHARACTERS:
		if character.get("id") == character_id:
			return character
	return {}
