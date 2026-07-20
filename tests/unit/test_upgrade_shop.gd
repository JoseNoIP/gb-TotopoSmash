extends GutTest
## Tests para src/features/meta/upgrade_shop.gd — lógica pura, sin autoload, mismo estilo
## que test_wave_scaling.gd/test_grid_math.gd.

const UpgradeShopGd := preload("res://src/features/meta/upgrade_shop.gd")


func test_cost_for_next_level_starts_at_base_cost() -> void:
	assert_eq(UpgradeShopGd.cost_for_next_level(0), Constants.UPGRADE_BASE_COST)


func test_cost_for_next_level_increases_by_step_each_level() -> void:
	var cost_level_1: int = UpgradeShopGd.cost_for_next_level(0)
	var cost_level_2: int = UpgradeShopGd.cost_for_next_level(1)
	assert_eq(cost_level_2 - cost_level_1, Constants.UPGRADE_COST_STEP)


func test_is_max_level() -> void:
	assert_false(UpgradeShopGd.is_max_level(Constants.UPGRADE_MAX_LEVEL - 1))
	assert_true(UpgradeShopGd.is_max_level(Constants.UPGRADE_MAX_LEVEL))
	var msg: String = "arreglo del test: nunca debe fallar por arriba del tope"
	assert_true(UpgradeShopGd.is_max_level(Constants.UPGRADE_MAX_LEVEL + 1), msg)


func test_bonus_seeds_is_zero_at_level_zero() -> void:
	assert_eq(UpgradeShopGd.bonus_seeds(0), 0)


func test_bonus_seeds_scales_linearly() -> void:
	assert_eq(UpgradeShopGd.bonus_seeds(3), 3 * Constants.UPGRADE_SEEDS_BONUS_PER_LEVEL)


func test_damage_multiplier_is_one_at_level_zero() -> void:
	assert_almost_eq(UpgradeShopGd.damage_multiplier(0), 1.0, 0.001)


func test_damage_multiplier_at_max_level() -> void:
	var expected: float = 1.0 + Constants.UPGRADE_MAX_LEVEL * Constants.UPGRADE_DAMAGE_BONUS_PER_LEVEL
	assert_almost_eq(UpgradeShopGd.damage_multiplier(Constants.UPGRADE_MAX_LEVEL), expected, 0.001)


func test_seed_speed_multiplier_is_one_at_level_zero() -> void:
	assert_almost_eq(UpgradeShopGd.seed_speed_multiplier(0), 1.0, 0.001)


func test_gold_earned_for_score_floors_to_an_integer() -> void:
	## GOLD_PER_SCORE_POINT = 0.05 -> score 19 da 0.95, debe redondear hacia abajo a 0.
	assert_eq(UpgradeShopGd.gold_earned_for_score(19), 0)
	assert_eq(UpgradeShopGd.gold_earned_for_score(20), 1)


func test_gold_earned_for_score_is_zero_for_zero_score() -> void:
	assert_eq(UpgradeShopGd.gold_earned_for_score(0), 0)


func test_find_character_returns_matching_entry() -> void:
	var character: Dictionary = UpgradeShopGd.find_character(Constants.CHARACTER_DEFAULT_ID)
	assert_eq(character.get("id"), Constants.CHARACTER_DEFAULT_ID)
	assert_eq(int(character.get("cost", -1)), 0, "el personaje default debe costar 0")


func test_find_character_returns_empty_dict_for_unknown_id() -> void:
	var character: Dictionary = UpgradeShopGd.find_character("no_existe")
	assert_eq(character, {})
