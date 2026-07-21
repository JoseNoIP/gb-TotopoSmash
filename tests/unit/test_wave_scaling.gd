extends GutTest
## Tests para el escalado de dificultad por oleada (GDD sección 4).

const WaveScalingGd := preload("res://src/features/board/wave_scaling.gd")

## "laser" incluido — pedido explícito del usuario (ver Constants.ROW_LASER_CHANCE):
## ahora pick_cell_kind() también puede devolverlo en Modo Infinito.
const ALL_KINDS: Array = [
	"empty", "totopo", "queso", "triangle", "stone", "salsa", "lemon", "seed_extra", "laser"
]


func test_totopo_hp_matches_wave_number() -> void:
	assert_eq(WaveScalingGd.totopo_hp_for_wave(1), 1)
	assert_eq(WaveScalingGd.totopo_hp_for_wave(10), 10, "GDD: oleada 10 -> totopos con 10 de vida")


func test_totopo_hp_never_drops_below_one() -> void:
	assert_eq(WaveScalingGd.totopo_hp_for_wave(0), 1, "oleada inválida no debe producir HP <= 0")


func test_queso_hp_is_wave_times_1_5_rounded_up() -> void:
	assert_eq(WaveScalingGd.queso_hp_for_wave(10), 15, "GDD: oleada 10 -> queso con 15 de vida")
	assert_eq(WaveScalingGd.queso_hp_for_wave(1), 2, "ceil(1 * 1.5) == 2")


func test_queso_hp_never_drops_below_one() -> void:
	assert_eq(WaveScalingGd.queso_hp_for_wave(0), 1)


## Pedido explícito del usuario: "cada hilera siempre trae el mismo HP... debería variar".
## Oleada 1 (introducción, GDD 1-5): la variación es tan chica que redondea al mismo valor
## para TODOS los sorteos — comportamiento intencional, no un bug (ver comentario en
## Constants.WAVE_HP_VARIANCE_RATIO_PER_WAVE).
func test_random_hp_for_wave_has_no_variance_at_wave_one() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	var base_hp: int = WaveScalingGd.totopo_hp_for_wave(1)
	for _i: int in 20:
		assert_eq(WaveScalingGd.random_hp_for_wave(base_hp, 1, rng), base_hp)


## Oleadas avanzadas sí deben mostrar variedad real — con suficientes tiradas, alguna debe
## caer por encima del valor central de la oleada (bloque "más resistente que el promedio",
## pedido explícito del usuario).
func test_random_hp_for_wave_produces_values_above_the_average_at_late_waves() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var base_hp: int = WaveScalingGd.totopo_hp_for_wave(40)
	var saw_above_average: bool = false
	for _i: int in 100:
		if WaveScalingGd.random_hp_for_wave(base_hp, 40, rng) > base_hp:
			saw_above_average = true
			break
	assert_true(saw_above_average, "oleada 40 debería producir al menos un bloque sobre el promedio")


## random_hp_for_wave() nunca debe devolver un HP inválido (<= 0), sin importar la oleada.
func test_random_hp_for_wave_never_drops_below_one() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	for _i: int in 50:
		assert_gt(WaveScalingGd.random_hp_for_wave(1, 60, rng), 0)


func test_triangles_and_queso_and_salsa_unlock_at_wave_six() -> void:
	assert_false(WaveScalingGd.triangles_unlocked(5), "oleada 5 todavía es 'introducción' (1-5)")
	assert_true(WaveScalingGd.triangles_unlocked(6), "oleada 6 empieza 'geometría' (6-15)")
	assert_false(WaveScalingGd.queso_unlocked(5))
	assert_true(WaveScalingGd.queso_unlocked(6))
	assert_false(WaveScalingGd.salsa_unlocked(5))
	assert_true(WaveScalingGd.salsa_unlocked(6))


func test_stone_unlocks_at_wave_sixteen() -> void:
	assert_false(WaveScalingGd.stone_unlocked(15), "oleada 15 todavía es 'geometría' (6-15)")
	assert_true(
		WaveScalingGd.stone_unlocked(16), "oleada 16 empieza 'obstáculos estáticos' (16-30)"
	)


func test_tight_spacing_starts_at_wave_thirty_one() -> void:
	assert_false(WaveScalingGd.is_tight_spacing(30))
	assert_true(
		WaveScalingGd.is_tight_spacing(31), "oleada 31 empieza 'estrangulamiento del espacio'"
	)


func test_pick_cell_kind_is_deterministic_given_same_seed() -> void:
	var rng_a: RandomNumberGenerator = RandomNumberGenerator.new()
	var rng_b: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_a.seed = 12345
	rng_b.seed = 12345
	for _i: int in 20:
		assert_eq(
			WaveScalingGd.pick_cell_kind(10, rng_a),
			WaveScalingGd.pick_cell_kind(10, rng_b),
			"misma seed debe producir la misma secuencia de resultados"
		)


func test_pick_cell_kind_always_returns_a_known_kind() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 777
	for wave: int in [1, 6, 16, 31, 50]:
		for _i: int in 30:
			var kind: String = WaveScalingGd.pick_cell_kind(wave, rng)
			assert_has(ALL_KINDS, kind, "pick_cell_kind no debe devolver un tipo desconocido")


func test_pick_cell_kind_never_returns_locked_kinds_before_their_wave() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 99
	for _i: int in 200:
		var kind: String = WaveScalingGd.pick_cell_kind(1, rng)
		assert_ne(
			kind, WaveScalingGd.KIND_TRIANGLE, "triángulos no deben aparecer antes de la oleada 6"
		)
		assert_ne(kind, WaveScalingGd.KIND_QUESO, "queso no debe aparecer antes de la oleada 6")
		assert_ne(kind, WaveScalingGd.KIND_SALSA, "salsa no debe aparecer antes de la oleada 6")
		assert_ne(kind, WaveScalingGd.KIND_STONE, "piedra no debe aparecer antes de la oleada 16")
