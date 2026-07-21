extends RefCounted
## Reglas puras de escalado de dificultad por oleada (GDD sección 4).
## Sin estado propio — el RNG se recibe como parámetro para que sea determinístico y testeable.
## Uso: const WaveScalingGd := preload("res://src/features/board/wave_scaling.gd")
##
## BALANCE VALIDADO (simulación Monte Carlo, 20k filas por oleada muestreada 1-60): los
## saltos de huecos libres caen exactamente donde el GDD los describe (~30% oleadas 1-5,
## ~20% oleadas 6-30, ~8% oleada 31+, "estrangulamiento del espacio"). Densidad de piedra
## nunca pasa de ~8% de celdas; una fila con 5+ piedras (posible softlock geométrico) ocurre
## en <0.02% de las filas incluso en oleada 60. No se detectaron valores que produzcan
## tableros imposibles o triviales — los defaults documentados abajo se mantienen tal cual.

const KIND_EMPTY: String = "empty"
const KIND_TOTOPO: String = "totopo"
const KIND_QUESO: String = "queso"
const KIND_TRIANGLE: String = "triangle"
const KIND_STONE: String = "stone"
const KIND_SALSA: String = "salsa"
const KIND_LEMON: String = "lemon"
const KIND_SEED_EXTRA: String = "seed_extra"
## Con probabilidad de spawn en Modo Infinito (Constants.ROW_LASER_CHANCE, ver
## pick_cell_kind() más abajo) — pedido explícito del usuario, antes solo aparecía en
## niveles autorados (row_queue/cells), ver CellFactoryGd.
const KIND_LASER: String = "laser"


## GDD 4.1 — "Bloques Normales (Totopos): N = O". Este es el HP "central" de la oleada —
## el HP REAL de cada bloque individual se sortea alrededor de este valor, ver
## random_hp_for_wave() (pedido explícito del usuario: variedad de HP dentro de una misma
## fila, no todos los bloques con el mismo golpe).
static func totopo_hp_for_wave(wave: int) -> int:
	return maxi(1, roundi(float(wave) * Constants.WAVE_TOTOPO_HP_MULTIPLIER))


## GDD 4.1 — "Bloques Pesados (Queso): N = O x 1.5 (redondeado hacia arriba)". HP central,
## ver misma nota que totopo_hp_for_wave().
static func queso_hp_for_wave(wave: int) -> int:
	return maxi(1, ceili(float(wave) * Constants.WAVE_QUESO_HP_MULTIPLIER))


## Cuánto puede desviarse el HP de UN bloque respecto al valor central de la oleada — crece
## con la oleada (tope Constants.WAVE_HP_VARIANCE_RATIO_MAX) para que oleadas tempranas casi
## no varíen (GDD: 1-5 es la introducción) y oleadas tardías sí muestren bloques bastante
## más resistentes que el promedio.
static func hp_variance_ratio(wave: int) -> float:
	return minf(
		Constants.WAVE_HP_VARIANCE_RATIO_MAX, float(wave) * Constants.WAVE_HP_VARIANCE_RATIO_PER_WAVE
	)


## HP real de UN bloque — sorteado dentro de un rango centrado en `base_hp` (el valor de
## totopo_hp_for_wave()/queso_hp_for_wave() para esta oleada), no un valor fijo repetido en
## toda la fila. `rng` se inyecta para que el resultado sea reproducible en tests, mismo
## patrón que pick_cell_kind().
static func random_hp_for_wave(base_hp: int, wave: int, rng: RandomNumberGenerator) -> int:
	var ratio: float = hp_variance_ratio(wave)
	var lo: int = maxi(1, roundi(float(base_hp) * (1.0 - ratio)))
	var hi: int = maxi(lo, roundi(float(base_hp) * (1.0 + ratio)))
	return rng.randi_range(lo, hi)


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
	if rng.randf() < Constants.ROW_LASER_CHANCE:
		return KIND_LASER
	if stone_unlocked(wave) and rng.randf() < Constants.ROW_STONE_CHANCE:
		return KIND_STONE
	if salsa_unlocked(wave) and rng.randf() < 0.10:
		return KIND_SALSA
	if queso_unlocked(wave) and rng.randf() < Constants.ROW_QUESO_CHANCE:
		return KIND_QUESO
	if triangles_unlocked(wave) and rng.randf() < Constants.ROW_TRIANGLE_CHANCE:
		return KIND_TRIANGLE
	return KIND_TOTOPO
