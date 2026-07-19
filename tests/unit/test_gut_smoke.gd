extends GutTest
## Smoke test: confirma que GUT y los autoloads del proyecto están disponibles antes de
## confiar en el resto de la suite.


func test_gut_itself_runs() -> void:
	assert_true(true, "si esto falla, GUT no está corriendo los tests")


func test_core_autoloads_are_registered() -> void:
	assert_not_null(Constants, "Constants debe estar registrado como autoload")
	assert_not_null(EventBus, "EventBus debe estar registrado como autoload")
	assert_not_null(GameManager, "GameManager debe estar registrado como autoload")
	assert_not_null(SaveManager, "SaveManager debe estar registrado como autoload")
	assert_not_null(AudioManager, "AudioManager debe estar registrado como autoload")
	assert_not_null(HapticManager, "HapticManager debe estar registrado como autoload")
