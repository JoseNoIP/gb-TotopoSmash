extends Node
## Dueño del estado de Modo Nivel en runtime (niveles finitos/deterministas — ver
## level_loader.gd, data/levels/). Sin class_name — es autoload (regla CLAUDE.md #10).
## Autoload DESPUÉS de SaveManager (mark_level_completed() lo usa).
##
## _pending_level_id es un buzón de lectura NO destructiva: get_pending_level() nunca lo
## limpia solo. Si se vaciara al leerlo, reintentar un nivel tras perder (GameOverScreen
## -> restart_requested -> recargar Game.tscn) caería de vuelta a Modo Infinito en
## silencio. Cada punto de navegación (MainMenu, LevelSelectScreen, LevelCompleteScreen)
## debe ESCRIBIR el valor explícitamente antes de cambiar de escena; los que solo
## recargan la escena actual (reintentar, tutorial) no lo tocan y heredan lo que ya
## había — los autoloads persisten entre cambios de escena.

const LevelLoaderGd := preload("res://src/features/levels/level_loader.gd")

var _pending_level_id: String = ""
var _pending_pack_prefix: String = ""
var _level_cache: Dictionary[String, Dictionary] = {}
var _manifest_cache: Array = []
var _manifest_loaded: bool = false


func set_pending_level(level_id: String) -> void:
	_pending_level_id = level_id


func get_pending_level() -> String:
	return _pending_level_id


## Mismo patrón que _pending_level_id (buzón no destructivo) — PackSelectScreen lo escribe
## antes de rutear a PackLevelsScreen, que lee de acá para saber qué pack mostrar.
func set_pending_pack_prefix(prefix: String) -> void:
	_pending_pack_prefix = prefix


func get_pending_pack_prefix() -> String:
	return _pending_pack_prefix


## Carga+valida perezosamente vía LevelLoaderGd la primera vez que se pide un id;
## cachea para que BoardManager y TurnManager no re-parseen el mismo JSON dos veces.
## {} si el nivel no existe o no pasa validate_level() (nunca crashea).
func get_level_data(level_id: String) -> Dictionary:
	if level_id.is_empty():
		return {}
	if _level_cache.has(level_id):
		return _level_cache[level_id]
	var data: Dictionary = LevelLoaderGd.load_level(level_id)
	var errors: Array = LevelLoaderGd.validate_level(data, level_id)
	if not errors.is_empty():
		push_warning("LevelManager: nivel '%s' inválido: %s" % [level_id, errors])
		_level_cache[level_id] = {}
		return {}
	_level_cache[level_id] = data
	return data


func get_manifest() -> Array:
	if not _manifest_loaded:
		_manifest_cache = LevelLoaderGd.parse_manifest()
		_manifest_loaded = true
	return _manifest_cache


## -1 si el id no está en el manifiesto.
func get_level_index(level_id: String) -> int:
	return get_manifest().find(level_id)


func mark_level_completed(level_id: String) -> void:
	var next_unlock: int = get_level_index(level_id) + 2  ## +1 mostrar, +1 desbloquear el siguiente
	var capped: int = mini(next_unlock, get_manifest().size())
	SaveManager.set_highest_level_unlocked_if_higher(capped)
