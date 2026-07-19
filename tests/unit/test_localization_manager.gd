extends GutTest
## Tests para LocalizationManager (autoload real; el CSV ya se cargó en TranslationServer
## desde su _ready() al boot del juego, antes de que corra ningún test). Cada test
## restaura el idioma original al final — mismo patrón que test_save_manager.gd, porque
## el locale activo es estado global compartido entre tests.


func test_default_locale_resolves_a_known_key() -> void:
	var original: String = LocalizationManager.get_current_language()
	LocalizationManager.set_language("es")
	assert_eq(tr(&"BTN_PLAY"), "JUGAR")
	LocalizationManager.set_language(original)


func test_set_language_switches_translation_server_locale() -> void:
	var original: String = LocalizationManager.get_current_language()
	LocalizationManager.set_language("en")
	assert_eq(LocalizationManager.get_current_language(), "en")
	assert_eq(tr(&"BTN_PLAY"), "PLAY")
	LocalizationManager.set_language(original)


func test_set_language_persists_choice_to_save_manager() -> void:
	var original_locale: String = LocalizationManager.get_current_language()
	var original_saved: String = SaveManager.get_language()
	LocalizationManager.set_language("pt_BR")
	assert_eq(SaveManager.get_language(), "pt_BR")
	LocalizationManager.set_language(original_locale)
	SaveManager.set_language(original_saved)


func test_unsupported_locale_is_ignored() -> void:
	var original: String = LocalizationManager.get_current_language()
	LocalizationManager.set_language("de")  # no está en SUPPORTED_LOCALES
	assert_eq(
		LocalizationManager.get_current_language(),
		original,
		"un locale no soportado no debe cambiar el idioma activo"
	)


func test_every_supported_locale_translates_the_same_key() -> void:
	var original: String = LocalizationManager.get_current_language()
	for locale: String in LocalizationManager.SUPPORTED_LOCALES:
		LocalizationManager.set_language(locale)
		var msg: String = "locale '%s' no debe devolver la key sin traducir" % locale
		assert_ne(tr(&"BTN_PLAY"), "BTN_PLAY", msg)
	LocalizationManager.set_language(original)
