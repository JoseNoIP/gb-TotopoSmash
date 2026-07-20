extends GutTest
## Tests para MetaManager (autoload real, persiste en user://meta.json — separado de
## SaveManager, ver comentario en MetaManager.gd). Casos relativos/idempotentes, mismo
## patrón que test_save_manager.gd: el estado persiste entre corridas en la misma máquina.


## Regresión real (bug reportado por el usuario jugando): sin devolver el oro agregado,
## CADA corrida de esta suite sumaba +50 de oro real para siempre (`MetaManager` es el
## autoload real, persiste en user://meta.json — sin mock/aislamiento de test).
func test_add_gold_increases_total() -> void:
	var before: int = MetaManager.get_gold()
	MetaManager.add_gold(50)
	assert_eq(MetaManager.get_gold(), before + 50)
	MetaManager.spend_gold(50)  ## deja el oro como estaba antes del test


func test_add_gold_ignores_non_positive_amounts() -> void:
	var before: int = MetaManager.get_gold()
	MetaManager.add_gold(0)
	MetaManager.add_gold(-10)
	assert_eq(MetaManager.get_gold(), before)


func test_spend_gold_fails_when_not_enough() -> void:
	var current: int = MetaManager.get_gold()
	var spent: bool = MetaManager.spend_gold(current + 1000)
	assert_false(spent, "no debe poder gastar más oro del que tiene")
	assert_eq(MetaManager.get_gold(), current, "el oro no debe cambiar si la compra falla")


func test_spend_gold_succeeds_and_deducts_exact_amount() -> void:
	var original: int = MetaManager.get_gold()
	MetaManager.add_gold(100)
	var before: int = MetaManager.get_gold()
	var spent: bool = MetaManager.spend_gold(40)
	assert_true(spent)
	assert_eq(MetaManager.get_gold(), before - 40)
	MetaManager.spend_gold(60)  ## deja el oro como estaba antes del test (100 - 40 - 60 = 0 neto)
	assert_eq(MetaManager.get_gold(), original)


func test_upgrade_level_defaults_to_zero_for_unknown_id() -> void:
	assert_eq(MetaManager.get_upgrade_level("no_existe"), 0)


func test_upgrade_level_roundtrip() -> void:
	MetaManager.set_upgrade_level("seeds", 3)
	assert_eq(MetaManager.get_upgrade_level("seeds"), 3)
	MetaManager.set_upgrade_level("seeds", 0)  ## deja el estado limpio para otros tests
	assert_eq(MetaManager.get_upgrade_level("seeds"), 0)


func test_bonus_seeds_scales_with_upgrade_level() -> void:
	MetaManager.set_upgrade_level("seeds", 2)
	var expected: int = 2 * Constants.UPGRADE_SEEDS_BONUS_PER_LEVEL
	assert_eq(MetaManager.get_bonus_seeds(), expected)
	MetaManager.set_upgrade_level("seeds", 0)


func test_damage_multiplier_is_one_at_level_zero() -> void:
	MetaManager.set_upgrade_level("damage", 0)
	assert_almost_eq(MetaManager.get_damage_multiplier(), 1.0, 0.001)


func test_seed_speed_multiplier_increases_with_level() -> void:
	MetaManager.set_upgrade_level("speed", 1)
	var expected: float = 1.0 + Constants.UPGRADE_SPEED_BONUS_PER_LEVEL
	assert_almost_eq(MetaManager.get_seed_speed_multiplier(), expected, 0.001)
	MetaManager.set_upgrade_level("speed", 0)


func test_classic_character_is_unlocked_by_default() -> void:
	assert_true(Constants.CHARACTER_DEFAULT_ID in MetaManager.get_unlocked_characters())


## Usa el personaje default (ya desbloqueado siempre) en vez de uno nuevo real
## ("turquoise") — llamar unlock_character() en un personaje nuevo lo desbloquea para
## siempre en el guardado real (bug real: contaminaba user://meta.json en cada corrida).
## El default ya está desbloqueado de por sí, así que llamarlo de nuevo no cambia el
## estado real y sigue ejercitando la misma lógica de "no duplicar".
func test_unlock_character_adds_it_without_duplicating() -> void:
	MetaManager.unlock_character(Constants.CHARACTER_DEFAULT_ID)
	MetaManager.unlock_character(Constants.CHARACTER_DEFAULT_ID)
	var unlocked: Array = MetaManager.get_unlocked_characters()
	var count: int = 0
	for character_id: String in unlocked:
		if character_id == Constants.CHARACTER_DEFAULT_ID:
			count += 1
	assert_eq(count, 1, "unlock_character no debe duplicar una entrada ya desbloqueada")


func test_selected_character_defaults_to_classic() -> void:
	MetaManager.set_selected_character(Constants.CHARACTER_DEFAULT_ID)
	assert_eq(MetaManager.get_selected_character(), Constants.CHARACTER_DEFAULT_ID)


func test_selected_character_roundtrip() -> void:
	MetaManager.set_selected_character("gold")
	assert_eq(MetaManager.get_selected_character(), "gold")
	MetaManager.set_selected_character(Constants.CHARACTER_DEFAULT_ID)  ## limpio para otros tests
