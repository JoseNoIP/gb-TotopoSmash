extends GutTest
## Tests para SaveManager (autoload real, persiste en user://save.json). Los casos son
## deliberadamente relativos/idempotentes en vez de asumir un archivo de guardado vacío,
## porque el estado persiste entre corridas de test en la misma máquina de desarrollo.


func test_tutorial_shown_roundtrip() -> void:
	SaveManager.set_tutorial_shown(false)
	assert_false(SaveManager.get_tutorial_shown())
	SaveManager.set_tutorial_shown(true)
	assert_true(SaveManager.get_tutorial_shown())


func test_sound_enabled_roundtrip() -> void:
	SaveManager.set_sound_enabled(false)
	assert_false(SaveManager.get_sound_enabled())
	SaveManager.set_sound_enabled(true)
	assert_true(SaveManager.get_sound_enabled())


func test_vibration_enabled_roundtrip() -> void:
	SaveManager.set_vibration_enabled(false)
	assert_false(SaveManager.get_vibration_enabled())
	SaveManager.set_vibration_enabled(true)
	assert_true(SaveManager.get_vibration_enabled())


func test_swipe_sensitivity_roundtrip() -> void:
	SaveManager.set_swipe_sensitivity(1.75)
	assert_almost_eq(SaveManager.get_swipe_sensitivity(), 1.75, 0.001)
	SaveManager.set_swipe_sensitivity(1.0)


func test_swipe_sensitivity_accepts_edge_values() -> void:
	SaveManager.set_swipe_sensitivity(0.5)
	assert_almost_eq(SaveManager.get_swipe_sensitivity(), 0.5, 0.001)
	SaveManager.set_swipe_sensitivity(2.0)
	assert_almost_eq(SaveManager.get_swipe_sensitivity(), 2.0, 0.001)
	SaveManager.set_swipe_sensitivity(1.0)


func test_best_score_only_updates_when_strictly_higher() -> void:
	var current: int = SaveManager.get_best_score()
	var lower_or_equal: bool = SaveManager.set_best_score_if_higher(current)
	assert_false(lower_or_equal, "un valor igual no debe reemplazar el mejor puntaje")
	var higher_value: int = current + 100
	var higher: bool = SaveManager.set_best_score_if_higher(higher_value)
	assert_true(higher, "un valor mayor sí debe reemplazar el mejor puntaje")
	assert_eq(SaveManager.get_best_score(), higher_value)


func test_max_wave_only_updates_when_strictly_higher() -> void:
	var current: int = SaveManager.get_max_wave()
	var higher_value: int = current + 5
	var higher: bool = SaveManager.set_max_wave_if_higher(higher_value)
	assert_true(higher)
	assert_eq(SaveManager.get_max_wave(), higher_value)
	var not_higher: bool = SaveManager.set_max_wave_if_higher(0)
	assert_false(not_higher, "0 nunca debe superar una oleada máxima ya alcanzada")


func test_language_roundtrip() -> void:
	var original: String = SaveManager.get_language()
	SaveManager.set_language("en")
	assert_eq(SaveManager.get_language(), "en")
	SaveManager.set_language(original)


func test_total_games_played_increments_by_one() -> void:
	var before: int = SaveManager.get_total_games_played()
	SaveManager.increment_total_games_played()
	assert_eq(SaveManager.get_total_games_played(), before + 1)


func test_highest_level_unlocked_only_updates_when_strictly_higher() -> void:
	var current: int = SaveManager.get_highest_level_unlocked()
	var lower_or_equal: bool = SaveManager.set_highest_level_unlocked_if_higher(current)
	assert_false(lower_or_equal, "un valor igual no debe reemplazar el desbloqueo")
	var higher_value: int = current + 1
	var higher: bool = SaveManager.set_highest_level_unlocked_if_higher(higher_value)
	assert_true(higher)
	assert_eq(SaveManager.get_highest_level_unlocked(), higher_value)
