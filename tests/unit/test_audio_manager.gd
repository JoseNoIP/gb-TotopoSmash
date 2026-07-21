extends GutTest
## Tests para AudioManager: preferencias de música/SFX independientes (pedido explícito
## del usuario: poder silenciar solo la música, solo los efectos, o ambos). Persiste en
## user://audio_settings.json (autoload real, sin mock) — todo test que lo mueva debe
## restaurarlo al final, mismo criterio que test_save_manager.gd/test_meta_manager.gd
## (ver tools/run_tests.sh, que además respalda este archivo como red de seguridad).


func test_music_enabled_roundtrip() -> void:
	var original: bool = AudioManager.get_music_enabled()
	AudioManager.set_music_enabled(false)
	assert_false(AudioManager.get_music_enabled())
	AudioManager.set_music_enabled(true)
	assert_true(AudioManager.get_music_enabled())
	AudioManager.set_music_enabled(original)


func test_sfx_enabled_roundtrip() -> void:
	var original: bool = AudioManager.get_sfx_enabled()
	AudioManager.set_sfx_enabled(false)
	assert_false(AudioManager.get_sfx_enabled())
	AudioManager.set_sfx_enabled(true)
	assert_true(AudioManager.get_sfx_enabled())
	AudioManager.set_sfx_enabled(original)


## Regresión directa del pedido del usuario: los dos interruptores deben ser
## INDEPENDIENTES — apagar uno no debe afectar al otro.
func test_music_and_sfx_are_independent() -> void:
	var original_music: bool = AudioManager.get_music_enabled()
	var original_sfx: bool = AudioManager.get_sfx_enabled()
	AudioManager.set_music_enabled(false)
	AudioManager.set_sfx_enabled(true)
	assert_false(AudioManager.get_music_enabled())
	assert_true(AudioManager.get_sfx_enabled())
	AudioManager.set_music_enabled(true)
	AudioManager.set_sfx_enabled(false)
	assert_true(AudioManager.get_music_enabled())
	assert_false(AudioManager.get_sfx_enabled())
	AudioManager.set_music_enabled(original_music)
	AudioManager.set_sfx_enabled(original_sfx)


func test_play_sfx_does_nothing_when_sfx_disabled() -> void:
	var original: bool = AudioManager.get_sfx_enabled()
	AudioManager.set_sfx_enabled(false)
	var children_before: int = AudioManager.get_child_count()
	AudioManager.play_sfx(&"bounce")
	var msg: String = "sin SFX no debe crear ningún AudioStreamPlayer nuevo"
	assert_eq(AudioManager.get_child_count(), children_before, msg)
	AudioManager.set_sfx_enabled(original)
