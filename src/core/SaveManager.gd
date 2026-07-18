extends Node
## JSON persistence to user://save.json.
## TEMPLATE: Add get/set pairs for each piece of persisted data.

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
	return _data.get("tutorial_shown", false)


func set_tutorial_shown(value: bool) -> void:
	_data["tutorial_shown"] = value
	save()


# --- Settings ---
func get_sound_enabled() -> bool:
	return _data.get("sound_enabled", true)


func set_sound_enabled(value: bool) -> void:
	_data["sound_enabled"] = value
	save()
