extends Node
## SFX reales (GDD sección 5). Se suscribe directo a EventBus (seed_bounced,
## salsa_exploded) en vez de que cada feature llame play_sfx() a mano — mismo patrón que
## HapticManager. Nunca crashea si falta un .wav todavía (ResourceLoader.exists()).
## .wav, no .ogg: gen_assets.py sintetiza WAV puro (stdlib `wave`, sin dependencias) y
## Godot lo reproduce igual de bien para SFX cortos — sin necesidad de un encoder externo.
##
## Dueño de sus propias preferencias (`_music_enabled`/`_sfx_enabled`, persistidas en
## `user://audio_settings.json`) — pedido explícito del usuario: poder silenciar SOLO la
## música, SOLO los efectos, o ambos, por separado (antes un único
## `SaveManager.sound_enabled` apagaba las dos cosas juntas). No se agregó a SaveManager
## porque ese autoload ya está en el límite de 20 métodos públicos de gdlint (regla
## CLAUDE.md #51, mismo motivo que MetaManager/LevelManager) — AudioManager ya es el dueño
## natural de toda la reproducción de audio, así que las preferencias viven con él.

const SFX_DIR: String = "res://assets/audio/sfx/"
const MUSIC_DIR: String = "res://assets/audio/music/"
const SETTINGS_PATH: String = "user://audio_settings.json"

const SFX_FILES: Dictionary = {
	&"bounce": "seed_bounce.wav",
	&"totopo_crunch": "totopo_crunch.wav",
	&"queso_thud": "queso_thud.wav",
	&"salsa_splash": "salsa_splash.wav",
	&"laser_zap": "laser_zap.wav",
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
## varios archivos de tonos distintos. Revertido a los valores originales (0.06/7) tras
## feedback directo del usuario ("me agradaba más cómo sonaba la primer versión") — un
## intento anterior de bajar el techo no gustó más que el original. La molestia real con
## muchas semillas viene del volumen de rebotes contra PARED, no de esta escala — ver
## WALL_BOUNCE_PITCH_SCALE/VOLUME_DB más abajo.
const BOUNCE_PITCH_STEP: float = 0.06
const BOUNCE_PITCH_MAX_STEPS: int = 7

## Pedido explícito del usuario: "también al rebotar en las paredes es molesto" — las
## paredes/techo se golpean MUCHÍSIMO más seguido que un bloque real (casi cualquier
## rebote que no sea contra un bloque termina siendo contra el borde del tablero), así que
## acumulan volumen/escalada de tono mucho más rápido que el resto de los SFX. Un tono fijo
## (SIN escalar, `_bounce_streak` no se toca acá) y más silencioso reduce esa acumulación
## sin quitarle feedback al rebote contra un bloque real, que sigue sonando igual que
## siempre.
const WALL_BOUNCE_PITCH_SCALE: float = 0.85
const WALL_BOUNCE_VOLUME_DB: float = -9.0

var _music_player: AudioStreamPlayer = AudioStreamPlayer.new()
var _bounce_streak: int = 0
var _settings: Dictionary = {}


func _ready() -> void:
	_load_settings()
	_music_player.name = &"MusicPlayer"
	_music_player.bus = &"Master"
	## Discreta a propósito (-8dB) — es fondo, no debe competir con los SFX del GDD, que se
	## reproducen a volumen normal por encima.
	_music_player.volume_db = -8.0
	add_child(_music_player)
	EventBus.seed_bounced.connect(_on_seed_bounced)
	EventBus.salsa_exploded.connect(_on_salsa_exploded)
	EventBus.laser_triggered.connect(_on_laser_triggered)
	EventBus.burst_fired.connect(_on_burst_fired)
	## Autoload — vive toda la sesión, así que arrancarla acá (en vez de en MainMenu/Game)
	## la deja sonando de fondo en cualquier pantalla desde el arranque, en loop
	## (`edit/loop_mode=1` en theme.wav.import), sin necesidad de re-lanzarla en cada
	## cambio de escena. `play_music()` ya respeta get_music_enabled().
	play_music()


func get_music_enabled() -> bool:
	return _settings.get("music_enabled", true) as bool


func set_music_enabled(value: bool) -> void:
	_settings["music_enabled"] = value
	_save_settings()
	if value:
		play_music()
	else:
		stop_music()


func get_sfx_enabled() -> bool:
	return _settings.get("sfx_enabled", true) as bool


func set_sfx_enabled(value: bool) -> void:
	_settings["sfx_enabled"] = value
	_save_settings()


func play_sfx(sfx_name: StringName, pitch_scale: float = 1.0, volume_db: float = 0.0) -> void:
	if not get_sfx_enabled():
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
	player.volume_db = volume_db
	player.bus = &"Master"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func play_music(track_name: String = "theme") -> void:
	if not get_music_enabled():
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


## `block_type == ""` es SIEMPRE pared/techo (WorldBounds, sin esa propiedad — todos los
## bloques reales la declaran, incluso stone/salsa/triangle, ver block_base.gd) — pedido
## explícito del usuario: rebotar contra pared se sentía molesto, mucho más frecuente que
## contra un bloque real. Ese caso usa un tono fijo y más silencioso, SIN sumar a
## `_bounce_streak` (no tiene sentido que la pared "robe" pasos de la escala ascendente
## pensada para rebotes contra bloques).
func _on_seed_bounced(block_type: String) -> void:
	var mapped: Variant = BLOCK_TYPE_TO_SFX.get(block_type)
	if mapped != null:
		play_sfx(mapped)
		return
	if block_type == "":
		play_sfx(&"bounce", WALL_BOUNCE_PITCH_SCALE, WALL_BOUNCE_VOLUME_DB)
		return
	var step: int = _bounce_streak % (BOUNCE_PITCH_MAX_STEPS + 1)
	play_sfx(&"bounce", 1.0 + step * BOUNCE_PITCH_STEP)
	_bounce_streak += 1


func _on_salsa_exploded(_grid_pos: Vector2i) -> void:
	play_sfx(&"salsa_splash")


## Pedido explícito del usuario: "faltó agregarle... sonido de láser al power-up". Se
## reproduce en CADA toque (persistente, ver laser_icon.gd) — un solo AudioStreamPlayer
## nuevo por toque, igual que cualquier otro SFX (play_sfx() ya maneja eso).
func _on_laser_triggered(_grid_pos: Vector2i, _orientation: String) -> void:
	play_sfx(&"laser_zap")


func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_settings = parsed


func _save_settings() -> void:
	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_settings))
