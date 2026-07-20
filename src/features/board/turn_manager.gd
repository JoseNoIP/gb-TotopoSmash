extends Node
## Orquesta el turno completo (GDD sección 2: Apuntado -> Disparo -> Rebote -> Retorno ->
## Avance). Dueño del inventario de semillas y de cada instancia de Seed que dispara.
## BoardManager es dueño EXCLUSIVO de la matriz de bloques — este nodo nunca la toca
## directamente, solo se comunican por EventBus (fire_requested / all_seeds_returned /
## turn_advanced). Instanciado por Game.tscn y TutorialGame.tscn.

enum Phase { AIMING, FIRING, RESOLVING, RETURNING, ADVANCING }

const SeedGd := preload("res://src/features/projectiles/seed.gd")
const GridMathGd := preload("res://src/shared/grid_math.gd")

var _phase: Phase = Phase.AIMING
var _seed_count: int = Constants.MOLCAJETE_START_SEEDS
var _origin: Vector2 = Vector2.ZERO
var _fire_direction: Vector2 = Vector2.UP
var _seeds_to_fire: int = 0
var _active_seeds: int = 0
var _first_landed_this_turn: bool = false
var _first_landed_x: float = 0.0
var _fire_timer: Timer = Timer.new()


func _ready() -> void:
	_fire_timer.wait_time = Constants.SEED_FIRE_INTERVAL
	_fire_timer.one_shot = false
	_fire_timer.timeout.connect(_on_fire_timer_timeout)
	add_child(_fire_timer)
	EventBus.game_started.connect(_on_game_started)
	EventBus.fire_requested.connect(_on_fire_requested)
	EventBus.seed_extra_touched.connect(_on_seed_extra_touched)
	EventBus.turn_advanced.connect(_on_turn_advanced)
	EventBus.recall_all_seeds_requested.connect(_on_recall_all_seeds_requested)


func get_seed_count() -> int:
	return _seed_count


func get_phase() -> Phase:
	return _phase


## Modo Nivel: starting_seeds viene del JSON del nivel (LevelManager ya lo cacheó, no
## se re-parsea); Modo Infinito: Constants.MOLCAJETE_START_SEEDS de siempre. En ambos casos
## se suma el bono de la mejora "Semillas Extra" comprada en la tienda (MetaManager).
func _on_game_started() -> void:
	var level_id: String = GameManager.get_current_level_id()
	if level_id.is_empty():
		_seed_count = Constants.MOLCAJETE_START_SEEDS
	else:
		var data: Dictionary = LevelManager.get_level_data(level_id)
		_seed_count = int(data.get("starting_seeds", Constants.MOLCAJETE_START_SEEDS))
	_seed_count += MetaManager.get_bonus_seeds()
	_seeds_to_fire = 0
	_active_seeds = 0
	_fire_timer.stop()
	_set_phase(Phase.AIMING)
	EventBus.seed_count_changed.emit(_seed_count)


func _on_fire_requested(direction: Vector2, origin: Vector2) -> void:
	if _phase != Phase.AIMING or not GameManager.is_playing():
		return
	_origin = origin
	_fire_direction = direction
	_seeds_to_fire = _seed_count
	_active_seeds = 0
	_first_landed_this_turn = false
	_set_phase(Phase.FIRING)
	EventBus.burst_fired.emit(_seeds_to_fire)
	_fire_one_seed()
	if _seeds_to_fire > 0:
		_fire_timer.start()


func _on_fire_timer_timeout() -> void:
	_fire_one_seed()


## Dispara una semilla del cupo restante de esta ráfaga. Si es la última, detiene el
## Timer y pasa a RESOLVING (las semillas siguen rebotando, ninguna ha regresado aún).
func _fire_one_seed() -> void:
	if _seeds_to_fire <= 0:
		_fire_timer.stop()
		return
	_seeds_to_fire -= 1
	var speed: float = Constants.SEED_SPEED * MetaManager.get_seed_speed_multiplier()
	_spawn_seed(_origin, _fire_direction, speed)
	if _seeds_to_fire <= 0:
		_fire_timer.stop()
		if _active_seeds > 0:
			_set_phase(Phase.RESOLVING)
		else:
			# Failsafe: no debería ocurrir (seed_count siempre >= 1), pero evita quedar
			# trabado en FIRING para siempre si por algún motivo no se creó ninguna semilla.
			_set_phase(Phase.AIMING)


## El split del Limón llega desde Area2D.body_entered (callback de física, GDD sección 3)
## — un add_child() directo ahí dispara _ready() de Seed sincrónicamente, que toca
## collision_layer/mask mientras el motor todavía está "flushing queries" de ese mismo
## paso de física (regla CLAUDE.md #17). call_deferred() es seguro también para el disparo
## normal (Timer / input), así que se usa siempre, sin importar el origen de la llamada.
func _spawn_seed(origin: Vector2, direction: Vector2, speed: float) -> void:
	var seed_node: CharacterBody2D = SeedGd.new()
	call_deferred(&"add_child", seed_node)
	var floor_y: float = GridMathGd.molcajete_y(Constants.DESIGN_HEIGHT)
	seed_node.call(&"launch", origin, direction, speed, floor_y)
	seed_node.connect(&"landed", _on_seed_landed)
	seed_node.connect(&"split_requested", _on_split_requested.bind(seed_node))
	_active_seeds += 1


## Limón Ácido (GDD sección 3): la semilla que lo toca se duplica en dos ángulos
## opuestos. `source_seed` (bind) da la posición donde ocurrió el split.
func _on_split_requested(mirrored_velocity: Vector2, source_seed: Node2D) -> void:
	if not is_instance_valid(source_seed):
		return
	var direction: Vector2 = mirrored_velocity.normalized()
	_spawn_seed(source_seed.global_position, direction, mirrored_velocity.length())


func _on_seed_landed(_seed_node: Node2D, x_position: float) -> void:
	if not _first_landed_this_turn:
		_first_landed_this_turn = true
		_first_landed_x = x_position
		if _phase == Phase.RESOLVING:
			_set_phase(Phase.RETURNING)
	_active_seeds -= 1
	if _active_seeds <= 0 and _seeds_to_fire <= 0:
		_set_phase(Phase.ADVANCING)
		# El molcajete se reposiciona recién aquí (no en el primer aterrizaje) — pedido
		# explícito del usuario tras verlo jugando: moverlo mientras todavía quedan
		# semillas en el aire se ve raro (el molcajete "abandona" la posición donde
		# siguen cayendo semillas). Sigue usando la posición de la PRIMERA semilla en
		# aterrizar (mismo criterio de siempre para "dónde atajar"), solo que la señal se
		# emite una vez que ya no queda ninguna semilla activa.
		EventBus.molcajete_position_changed.emit(_first_landed_x)
		# BoardManager escucha esta señal y responde de forma síncrona (desplaza el
		# tablero, revela/spawnea contenido nuevo y emite turn_advanced si la partida
		# sigue), lo cual dispara _on_turn_advanced() más abajo antes de que este emit()
		# retorne.
		EventBus.all_seeds_returned.emit(x_position)


## Pedido explícito del usuario: no obligar a esperar el recorrido completo de cada
## semilla (ni el boost de mantener presionado alcanza cuando hay cientos de semillas —
## ej. los niveles `static` del pack Mundial). Cancela cualquier disparo pendiente de la
## ráfaga (no tiene sentido seguir disparando semillas que van a aterrizar ya mismo) y
## fuerza el aterrizaje de TODAS las semillas activas — cada `force_land()` emite `landed`
## como si hubiera llegado sola al piso, así que `_on_seed_landed()` de arriba resuelve el
## fin del turno exactamente igual que un aterrizaje natural, sin lógica duplicada.
func _on_recall_all_seeds_requested() -> void:
	if _active_seeds <= 0 and _seeds_to_fire <= 0:
		return
	_seeds_to_fire = 0
	_fire_timer.stop()
	for seed_node: Node in get_tree().get_nodes_in_group(&"seeds"):
		seed_node.call(&"force_land")


func _on_seed_extra_touched(_origin: Vector2, amount: int) -> void:
	_seed_count += amount
	EventBus.seed_extra_collected.emit(_seed_count)
	EventBus.seed_count_changed.emit(_seed_count)


## Mode-agnostic (ver EventBus.turn_advanced) — BoardManager la emite en Modo Infinito Y
## en Modo Nivel siempre que el turno termina sin game over ni nivel ganado. También podría
## llegar con la fase ya en AIMING (ej. nada que hacer todavía); el guard evita una
## transición espuria en ese caso.
func _on_turn_advanced() -> void:
	if _phase == Phase.ADVANCING:
		_set_phase(Phase.AIMING)


func _set_phase(phase: Phase) -> void:
	_phase = phase
	EventBus.turn_phase_changed.emit(phase)
