extends GutTest
## Tests para TurnManager: inventario de semillas y transiciones de fase (GDD sección 2).
## No se espera a que las semillas realmente aterricen (requeriría simular física real);
## se prueban los efectos síncronos inmediatos de cada handler, que es donde vive toda la
## lógica de negocio (spawnear semillas es un efecto secundario ya cubierto por el smoke
## test de Game.tscn arrancando la escena completa).
##
## Todas las pruebas usan GameManager.start_game() (no EventBus.game_started.emit()
## directo) porque _on_fire_requested() exige GameManager.is_playing() == true, y ese
## estado solo lo pone start_game() — emitir la señal sola no alcanza.

const TurnManagerGd := preload("res://src/features/board/turn_manager.gd")


func before_each() -> void:
	GameManager.start_game()


func test_seed_count_resets_to_starting_value_on_game_started() -> void:
	var turn_manager: Node = TurnManagerGd.new()
	add_child_autofree(turn_manager)
	GameManager.start_game()
	assert_eq(turn_manager.call(&"get_seed_count"), Constants.MOLCAJETE_START_SEEDS)
	assert_eq(turn_manager.call(&"get_phase"), TurnManagerGd.Phase.AIMING)


func test_seed_extra_touched_adds_one_seed_and_emits_signals() -> void:
	var turn_manager: Node = TurnManagerGd.new()
	add_child_autofree(turn_manager)
	GameManager.start_game()
	var before: int = turn_manager.call(&"get_seed_count")
	watch_signals(EventBus)
	EventBus.seed_extra_touched.emit(Vector2.ZERO)
	var expected: int = before + Constants.SEED_EXTRA_AMOUNT
	assert_eq(turn_manager.call(&"get_seed_count"), expected)
	assert_signal_emitted_with_parameters(EventBus, "seed_extra_collected", [expected])
	assert_signal_emitted_with_parameters(EventBus, "seed_count_changed", [expected])


func test_fire_requested_ignored_outside_aiming_phase() -> void:
	var turn_manager: Node = TurnManagerGd.new()
	add_child_autofree(turn_manager)
	GameManager.start_game()
	turn_manager.set(&"_phase", TurnManagerGd.Phase.FIRING)
	watch_signals(EventBus)
	EventBus.fire_requested.emit(Vector2.UP, Vector2.ZERO)
	assert_signal_not_emitted(EventBus, "burst_fired")


func test_fire_requested_while_aiming_fires_first_seed_immediately() -> void:
	var turn_manager: Node = TurnManagerGd.new()
	add_child_autofree(turn_manager)
	GameManager.start_game()
	watch_signals(EventBus)
	EventBus.fire_requested.emit(Vector2.UP, Vector2(100.0, 700.0))
	# _spawn_seed usa call_deferred(&"add_child", ...) (regla CLAUDE.md #17 — el split del
	# Limón dispara semillas nuevas desde un callback de física). Sin este frame, la semilla
	# nunca llega a entrar al árbol y add_child_autofree no la puede limpiar (orphan).
	await get_tree().process_frame
	# GDD: la ráfaga sale "una detrás de otra rápidamente, no todas juntas" — solo la
	# primera semilla sale en el mismo frame que fire_requested; el resto llega por Timer
	# (SEED_FIRE_INTERVAL), por eso la fase sigue en FIRING y no salta directo a RESOLVING.
	var msg: String = "debe seguir en FIRING: el resto de la ráfaga todavía no ha salido"
	assert_eq(turn_manager.call(&"get_phase"), TurnManagerGd.Phase.FIRING, msg)
	assert_signal_emitted_with_parameters(
		EventBus, "burst_fired", [Constants.MOLCAJETE_START_SEEDS]
	)


func test_full_burst_eventually_reaches_resolving() -> void:
	var turn_manager: Node = TurnManagerGd.new()
	add_child_autofree(turn_manager)
	GameManager.start_game()
	EventBus.fire_requested.emit(Vector2.UP, Vector2(100.0, 700.0))
	var burst_duration: float = Constants.SEED_FIRE_INTERVAL * Constants.MOLCAJETE_START_SEEDS
	await wait_seconds(burst_duration + 0.2, "esperar a que la ráfaga completa termine de salir")
	var msg: String = "tras disparar toda la ráfaga debe pasar a RESOLVING (todavía rebotando)"
	assert_eq(turn_manager.call(&"get_phase"), TurnManagerGd.Phase.RESOLVING, msg)


func test_fire_requested_ignored_when_game_not_playing() -> void:
	var turn_manager: Node = TurnManagerGd.new()
	add_child_autofree(turn_manager)
	GameManager.start_game()
	EventBus.board_reached_bottom.emit()  # fuerza GAME_OVER
	watch_signals(EventBus)
	EventBus.fire_requested.emit(Vector2.UP, Vector2.ZERO)
	assert_signal_not_emitted(EventBus, "burst_fired")


func test_all_seeds_returned_after_landing_resets_phase_to_aiming() -> void:
	var turn_manager: Node = TurnManagerGd.new()
	add_child_autofree(turn_manager)
	GameManager.start_game()
	EventBus.fire_requested.emit(Vector2.UP, Vector2(100.0, 700.0))
	await get_tree().process_frame  # deja que el add_child deferido de la semilla entre al árbol
	turn_manager.set(&"_active_seeds", 0)
	turn_manager.set(&"_seeds_to_fire", 0)
	turn_manager.call(&"_set_phase", TurnManagerGd.Phase.ADVANCING)
	EventBus.wave_advanced.emit(2)  # BoardManager emitiría esto tras un avance real
	assert_eq(turn_manager.call(&"get_phase"), TurnManagerGd.Phase.AIMING)


func test_wave_advanced_at_game_start_does_not_leave_aiming() -> void:
	var turn_manager: Node = TurnManagerGd.new()
	add_child_autofree(turn_manager)
	GameManager.start_game()  # deja fase AIMING
	EventBus.wave_advanced.emit(1)  # BoardManager también emite esto al armar el tablero inicial
	var msg: String = "wave_advanced inicial no debe alterar la fase"
	assert_eq(turn_manager.call(&"get_phase"), TurnManagerGd.Phase.AIMING, msg)
