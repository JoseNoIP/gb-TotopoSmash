extends Node
## Stub funcional de audio. Nunca crashea si el archivo .ogg no existe todavía —
## los SFX/música reales se agregan después vía /gen-ai-art.

const SFX_DIR: String = "res://assets/audio/sfx/"
const MUSIC_DIR: String = "res://assets/audio/music/"

var _music_player: AudioStreamPlayer = AudioStreamPlayer.new()


func _ready() -> void:
	_music_player.name = &"MusicPlayer"
	_music_player.bus = &"Master"
	add_child(_music_player)


func play_sfx(sfx_name: String) -> void:
	if not SaveManager.get_sound_enabled():
		return
	var path: String = SFX_DIR + sfx_name + ".ogg"
	if not ResourceLoader.exists(path):
		return
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = load(path)
	player.bus = &"Master"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func play_music(track_name: String = "theme") -> void:
	if not SaveManager.get_sound_enabled():
		return
	var path: String = MUSIC_DIR + track_name + ".ogg"
	if not ResourceLoader.exists(path):
		return
	_music_player.stream = load(path)
	_music_player.play()


func stop_music() -> void:
	_music_player.stop()
