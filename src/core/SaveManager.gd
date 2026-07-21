extends Node
## JSON persistence to user://save.json.

const SAVE_PATH: String = "user://save.json"

var _data: Dictionary = {}


func _ready() -> void:
	_load()


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			_data = parsed


func save() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_data))


# --- Tutorial ---
func get_tutorial_shown() -> bool:
	return _data.get("tutorial_shown", false) as bool


func set_tutorial_shown(value: bool) -> void:
	_data["tutorial_shown"] = value
	save()


# --- Settings ---
## El sonido combinado (música + SFX en un solo interruptor) se separó en
## AudioManager.get_music_enabled()/get_sfx_enabled() (pedido explícito del usuario: poder
## silenciar cada uno por separado) — no vive acá porque SaveManager ya está en el límite
## de 20 métodos públicos de gdlint (regla CLAUDE.md #51).
func get_vibration_enabled() -> bool:
	return _data.get("vibration_enabled", true) as bool


func set_vibration_enabled(value: bool) -> void:
	_data["vibration_enabled"] = value
	save()


func get_swipe_sensitivity() -> float:
	return _data.get("swipe_sensitivity", 1.0) as float


func set_swipe_sensitivity(value: float) -> void:
	_data["swipe_sensitivity"] = value
	save()


## "" significa "sin elegir todavía" — LocalizationManager usa esto para decidir si
## mostrar LanguageSelectScreen en la primera ejecución (regla /mobile-i18n).
func get_language() -> String:
	return _data.get("language", "") as String


func set_language(value: String) -> void:
	_data["language"] = value
	save()


# --- Puntuación / progreso ---
func get_best_score() -> int:
	return _data.get("best_score", 0) as int


func set_best_score_if_higher(value: int) -> bool:
	if value > get_best_score():
		_data["best_score"] = value
		save()
		return true
	return false


func get_max_wave() -> int:
	return _data.get("max_wave", 0) as int


func set_max_wave_if_higher(value: int) -> bool:
	if value > get_max_wave():
		_data["max_wave"] = value
		save()
		return true
	return false


func get_total_games_played() -> int:
	return _data.get("total_games_played", 0) as int


func increment_total_games_played() -> void:
	_data["total_games_played"] = get_total_games_played() + 1
	save()


# --- Modo Nivel (niveles finitos/deterministas, ver LevelManager) ---
## 1 = solo el nivel 1 desbloqueado (default de una partida nueva). Deliberadamente sin
## estrellas/calificación por nivel — solo la frontera de desbloqueo (decisión de
## alcance: el sistema de mejoras/oro queda fuera de esta sesión).
func get_highest_level_unlocked() -> int:
	return _data.get("highest_level_unlocked", 1) as int


func set_highest_level_unlocked_if_higher(value: int) -> bool:
	if value > get_highest_level_unlocked():
		_data["highest_level_unlocked"] = value
		save()
		return true
	return false
