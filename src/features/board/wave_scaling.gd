extends RefCounted
## Reglas puras de escalado de dificultad por oleada (GDD sección 4).
## Sin estado propio — el RNG se recibe como parámetro para que sea determinístico y testeable.
## Uso: const WaveScalingGd := preload("res://src/features/board/wave_scaling.gd")

const KIND_EMPTY: String = "empty"
const KIND_TOTOPO: String = "totopo"
const KIND_QUESO: String = "queso"
const KIND_TRIANGLE: String = "triangle"
const KIND_STONE: String = "stone"
const KIND_SALSA: String = "salsa"
const KIND_LEMON: String = "lemon"
const KIND_SEED_EXTRA: String = "seed_extra"


## GDD 4.1 — "Bloques Normales (Totopos): N = O"
static func totopo_hp_for_wave(wave: int) -> int:
	return maxi(1, roundi(float(wave) * Constants.WAVE_TOTOPO_HP_MULTIPLIER))


## GDD 4.1 — "Bloques Pesados (Queso): N = O x 1.5 (redondeado hacia arriba)"
static func queso_hp_for_wave(wave: int) -> int:
	return maxi(1, ceili(float(wave) * Constants.WAVE_QUESO_HP_MULTIPLIER))


## GDD 4.2 — oleadas 6-15 "Geometría": bloques triangulares
static func triangles_unlocked(wave: int) -> bool:
	return wave >= Constants.WAVE_GEOMETRY_START


## GDD 4.2 — oleadas 6-15: "Aparecen los primeros bloques de Queso"
static func queso_unlocked(wave: int) -> bool:
	return wave >= Constants.WAVE_GEOMETRY_START


## SUPUESTO (no especificado en el GDD): los Frascos de Salsa se introducen junto con
## la etapa de "Geometría" (oleada 6+), ya que el GDD no fija una oleada explícita.
static func salsa_unlocked(wave: int) -> bool:
	return wave >= Constants.WAVE_GEOMETRY_START


## GDD 4.2 — oleadas 16-30 "Obstáculos Estáticos": Piedra de Molcajete indestructible
static func stone_unlocked(wave: int) -> bool:
	return wave >= Constants.WAVE_STATIC_OBSTACLES_START


## GDD 4.2 — oleadas 31+: "el patrón de aparición deja menos huecos libres"
static func is_tight_spacing(wave: int) -> bool:
	return wave >= Constants.WAVE_TIGHT_SPACING_START


static func empty_cell_chance(wave: int) -> float:
	if is_tight_spacing(wave):
		return Constants.ROW_EMPTY_CHANCE_LATE
	if wave > Constants.WAVE_INTRO_END:
		return Constants.ROW_EMPTY_CHANCE_MID
	return Constants.ROW_EMPTY_CHANCE_EARLY


## GDD 4.2 — oleadas 1-5: "Abundantes íconos de Semilla Extra (+1)"
static func seed_extra_chance(wave: int) -> float:
	if wave <= Constants.WAVE_INTRO_END:
		return Constants.ROW_SEED_EXTRA_CHANCE_EARLY
	return Constants.ROW_SEED_EXTRA_CHANCE_LATE


## Decide qué ocupa una celda de la nueva fila. `rng` se inyecta para que el resultado
## sea reproducible en tests. El orden de los checks es la prioridad: el primero que
## acierta su tirada gana la celda.
static func pick_cell_kind(wave: int, rng: RandomNumberGenerator) -> String:
	if rng.randf() < empty_cell_chance(wave):
		return KIND_EMPTY
	if rng.randf() < seed_extra_chance(wave):
		return KIND_SEED_EXTRA
	if rng.randf() < Constants.ROW_LEMON_CHANCE:
		return KIND_LEMON
	if stone_unlocked(wave) and rng.randf() < Constants.ROW_STONE_CHANCE:
		return KIND_STONE
	if salsa_unlocked(wave) and rng.randf() < 0.10:
		return KIND_SALSA
	if queso_unlocked(wave) and rng.randf() < Constants.ROW_QUESO_CHANCE:
		return KIND_QUESO
	if triangles_unlocked(wave) and rng.randf() < Constants.ROW_TRIANGLE_CHANCE:
		return KIND_TRIANGLE
	return KIND_TOTOPO
