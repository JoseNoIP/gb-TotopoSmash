extends Node
## SFX reales (GDD sección 5). Se suscribe directo a EventBus (seed_bounced,
## salsa_exploded) en vez de que cada feature llame play_sfx() a mano — mismo patrón que
## HapticManager. Nunca crashea si falta un .wav todavía (ResourceLoader.exists()).
## .wav, no .ogg: gen_assets.py sintetiza WAV puro (stdlib `wave`, sin dependencias) y
## Godot lo reproduce igual de bien para SFX cortos — sin necesidad de un encoder externo.

const SFX_DIR: String = "res://assets/audio/sfx/"
const MUSIC_DIR: String = "res://assets/audio/music/"

const SFX_FILES: Dictionary = {
	&"bounce": "seed_bounce.wav",
	&"totopo_crunch": "totopo_crunch.wav",
	&"queso_thud": "queso_thud.wav",
	&"salsa_splash": "salsa_splash.wav",
}

## GDD: material del bloque golpeado -> SFX de impacto. Sin entrada = usa el tono de
## rebote genérico (paredes/techo, y "salsa"/"stone" que el GDD no distingue en sección 5).
const BLOCK_TYPE_TO_SFX: Dictionary = {
	"totopo": &"totopo_crunch",
	"triangle": &"totopo_crunch",
	"queso": &"queso_thud",
}

## GDD: "rebotes normales en escala ascendente... para que las ráfagas largas suenen como
## una melodía rítmica" — un solo sample con pitch_scale creciente por rebote, en vez de
## varios archivos de tonos distintos.
const BOUNCE_PITCH_STEP: float = 0.06
const BOUNCE_PITCH_MAX_STEPS: int = 7

var _music_player: AudioStreamPlayer = AudioStreamPlayer.new()
var _bounce_streak: int = 0


func _ready() -> void:
	_music_player.name = &"MusicPlayer"
	_music_player.bus = &"Master"
	## Discreta a propósito (-8dB) — es fondo, no debe competir con los SFX del GDD, que se
	## reproducen a volumen normal por encima.
	_music_player.volume_db = -8.0
	add_child(_music_player)
	EventBus.seed_bounced.connect(_on_seed_bounced)
	EventBus.salsa_exploded.connect(_on_salsa_exploded)
	EventBus.burst_fired.connect(_on_burst_fired)
	## Autoload — vive toda la sesión, así que arrancarla acá (en vez de en MainMenu/Game)
	## la deja sonando de fondo en cualquier pantalla desde el arranque, en loop
	## (`edit/loop_mode=1` en theme.wav.import), sin necesidad de re-lanzarla en cada
	## cambio de escena. `play_music()` ya respeta `SaveManager.get_sound_enabled()`.
	play_music()


func play_sfx(sfx_name: StringName, pitch_scale: float = 1.0) -> void:
	if not SaveManager.get_sound_enabled():
		return
	var filename: String = SFX_FILES.get(sfx_name, "")
	if filename.is_empty():
		return
	var path: String = SFX_DIR + filename
	if not ResourceLoader.exists(path):
		return
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = load(path)
	player.pitch_scale = pitch_scale
	player.bus = &"Master"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func play_music(track_name: String = "theme") -> void:
	if not SaveManager.get_sound_enabled():
		return
	var path: String = MUSIC_DIR + track_name + ".wav"
	if not ResourceLoader.exists(path):
		return
	_music_player.stream = load(path)
	_music_player.play()


func stop_music() -> void:
	_music_player.stop()


func _on_burst_fired(_seed_count: int) -> void:
	_bounce_streak = 0


func _on_seed_bounced(block_type: String) -> void:
	var mapped: Variant = BLOCK_TYPE_TO_SFX.get(block_type)
	if mapped != null:
		play_sfx(mapped)
		return
	var step: int = _bounce_streak % (BOUNCE_PITCH_MAX_STEPS + 1)
	play_sfx(&"bounce", 1.0 + step * BOUNCE_PITCH_STEP)
	_bounce_streak += 1


func _on_salsa_exploded(_grid_pos: Vector2i) -> void:
	play_sfx(&"salsa_splash")
