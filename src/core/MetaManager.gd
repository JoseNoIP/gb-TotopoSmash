extends Node
## Persistencia de la tienda de mejoras (oro, mejoras permanentes, personajes
## cosméticos) — mismo patrón que SaveManager.gd (JSON plano en user://) pero en su propio
## archivo, separado de settings/tutorial/score: SaveManager ya rozaba el máximo de 20
## métodos públicos por clase que exige gdlint (max-public-methods) y esto es, de por sí,
## una responsabilidad propia (ver /feature skill, PASO A.4 "una sola responsabilidad por
## script"). Sin `class_name` — es autoload.

const SAVE_PATH: String = "user://meta.json"
const UpgradeShopGd := preload("res://src/features/meta/upgrade_shop.gd")

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


# --- Oro ---
func get_gold() -> int:
	return _data.get("gold", 0) as int


func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	_data["gold"] = get_gold() + amount
	save()


## false si no alcanza el oro — nunca deja el total en negativo.
func spend_gold(amount: int) -> bool:
	if amount <= 0 or amount > get_gold():
		return false
	_data["gold"] = get_gold() - amount
	save()
	return true


# --- Mejoras permanentes ---
## upgrade_id: uno de UpgradeShopGd.UPGRADE_IDS ("seeds"/"damage"/"speed"). 0 = sin
## comprar todavía. String plano (nunca StringName) como key, mismo patrón que
## SaveManager, para no depender de que String/StringName comparen igual como key de
## Dictionary en todos los casos.
func get_upgrade_level(upgrade_id: String) -> int:
	var levels: Dictionary = _data.get("upgrade_levels", {}) as Dictionary
	return int(levels.get(upgrade_id, 0))


func set_upgrade_level(upgrade_id: String, level: int) -> void:
	var levels: Dictionary = _data.get("upgrade_levels", {}) as Dictionary
	levels[upgrade_id] = level
	_data["upgrade_levels"] = levels
	save()


func get_bonus_seeds() -> int:
	return UpgradeShopGd.bonus_seeds(get_upgrade_level("seeds"))


func get_damage_multiplier() -> float:
	return UpgradeShopGd.damage_multiplier(get_upgrade_level("damage"))


func get_seed_speed_multiplier() -> float:
	return UpgradeShopGd.seed_speed_multiplier(get_upgrade_level("speed"))


# --- Personajes (skins cosméticas, sin efecto en gameplay) ---
## "classic" siempre desbloqueado por default, aunque nunca se haya guardado nada todavía.
func get_unlocked_characters() -> Array:
	var unlocked: Variant = _data.get("unlocked_characters")
	if unlocked is Array and not (unlocked as Array).is_empty():
		return unlocked as Array
	return [Constants.CHARACTER_DEFAULT_ID]


func unlock_character(character_id: String) -> void:
	var unlocked: Array = get_unlocked_characters()
	if character_id in unlocked:
		return
	unlocked.append(character_id)
	_data["unlocked_characters"] = unlocked
	save()


func get_selected_character() -> String:
	return _data.get("selected_character", Constants.CHARACTER_DEFAULT_ID) as String


func set_selected_character(character_id: String) -> void:
	_data["selected_character"] = character_id
	save()
