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
const PACK_PROGRESS_PATH: String = "user://pack_progress.json"

var _pending_level_id: String = ""
var _pending_pack_prefix: String = ""
var _level_cache: Dictionary[String, Dictionary] = {}
var _manifest_cache: Array = []
var _manifest_loaded: bool = false
## prefix -> posición (1-based) más alta desbloqueada DENTRO de ese pack — independiente
## de SaveManager.highest_level_unlocked (que es solo para el roster numérico). Propio
## `user://pack_progress.json` en vez de sumarlo a SaveManager: ese autoload ya está en el
## límite de 20 métodos públicos de gdlint (regla CLAUDE.md #51, mismo motivo que
## MetaManager). Bug real corregido: antes los packs no tenían NINGÚN tracking de
## desbloqueo (todos los niveles de todos los packs aparecían habilitados desde el
## inicio) — pedido explícito del usuario tras jugar.
var _pack_progress: Dictionary = {}
var _pack_progress_loaded: bool = false


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


## Bug real corregido: antes usaba `get_level_index()` (posición GLOBAL en el manifiesto
## de 115 niveles) sin distinguir roster numérico de packs — completar UN nivel de pack
## (posición ~100+ en el manifiesto) desbloqueaba de un tirón casi toda la campaña
## numérica. Ahora cada tipo de nivel actualiza SOLO su propio desbloqueo.
func mark_level_completed(level_id: String) -> void:
	if not level_id.begins_with("level_"):
		_mark_pack_level_completed(level_id)
		return
	var numeric_count: int = 0
	for id: String in get_manifest():
		if (id as String).begins_with("level_"):
			numeric_count += 1
	var next_unlock: int = get_level_index(level_id) + 2  ## +1 mostrar, +1 desbloquear el siguiente
	var capped: int = mini(next_unlock, numeric_count)
	SaveManager.set_highest_level_unlocked_if_higher(capped)


## 1 = solo el primer nivel del pack desbloqueado (default, mismo criterio que
## SaveManager.get_highest_level_unlocked() para el roster numérico) — pero sí se puede
## volver a jugar cualquier nivel <= este valor (pedido explícito del usuario).
func get_pack_highest_unlocked(prefix: String) -> int:
	_ensure_pack_progress_loaded()
	return int(_pack_progress.get(prefix, 1))


## Los ids de pack siguen la convención "prefix_NNN" (ver /level-designer PASO 4) — NNN es
## la posición 1-based dentro del pack, no la global del manifiesto.
func _mark_pack_level_completed(level_id: String) -> void:
	var sep: int = level_id.rfind("_")
	if sep < 0:
		return
	var prefix: String = level_id.substr(0, sep)
	var suffix: String = level_id.substr(sep + 1)
	if not suffix.is_valid_int():
		return
	_ensure_pack_progress_loaded()
	var next_unlock: int = int(suffix) + 1
	if next_unlock > int(_pack_progress.get(prefix, 1)):
		_pack_progress[prefix] = next_unlock
		_save_pack_progress()


func _ensure_pack_progress_loaded() -> void:
	if _pack_progress_loaded:
		return
	_pack_progress_loaded = true
	if not FileAccess.file_exists(PACK_PROGRESS_PATH):
		return
	var file: FileAccess = FileAccess.open(PACK_PROGRESS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_pack_progress = parsed


func _save_pack_progress() -> void:
	var file: FileAccess = FileAccess.open(PACK_PROGRESS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_pack_progress))
