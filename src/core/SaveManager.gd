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
func get_sound_enabled() -> bool:
	return _data.get("sound_enabled", true) as bool


func set_sound_enabled(value: bool) -> void:
	_data["sound_enabled"] = value
	save()


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


# --- Puntuación / progreso (Totopo Smash no tiene metagame de oro/upgrades: el GDD
# solo define progresión infinita por oleadas dentro de una run — ver GDD sección 4) ---
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
