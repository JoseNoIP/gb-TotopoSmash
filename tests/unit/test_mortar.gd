extends GutTest
## Tests para Mortar: regresión bit a bit de la fase AIMING (apuntar/disparar, sin
## cambios) + la rama nueva de acelerar semillas (seed_boost_changed) fuera de AIMING.

const MortarGd := preload("res://src/features/player/mortar.gd")
const TurnManagerGd := preload("res://src/features/board/turn_manager.gd")


func _touch(pressed: bool, pos: Vector2) -> InputEventScreenTouch:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.pressed = pressed
	event.position = pos
	return event


func after_each() -> void:
	EventBus.seed_boost_changed.emit(false)


func test_aiming_phase_touch_press_starts_aiming_and_emits_aim_updated() -> void:
	var mortar: Node2D = MortarGd.new()
	add_child_autofree(mortar)
	mortar.set(&"_phase", TurnManagerGd.Phase.AIMING)
	watch_signals(EventBus)
	mortar.call(&"_unhandled_input", _touch(true, mortar.global_position + Vector2(0, -100)))
	assert_signal_emitted(EventBus, "aim_updated")
	assert_signal_not_emitted(EventBus, "seed_boost_changed", "AIMING no debe tocar el boost")


func test_aiming_phase_release_fires_and_never_touches_boost() -> void:
	var mortar: Node2D = MortarGd.new()
	add_child_autofree(mortar)
	mortar.set(&"_phase", TurnManagerGd.Phase.AIMING)
	var pos: Vector2 = mortar.global_position + Vector2(0, -100)
	mortar.call(&"_unhandled_input", _touch(true, pos))
	watch_signals(EventBus)
	mortar.call(&"_unhandled_input", _touch(false, pos))
	assert_signal_emitted(EventBus, "fire_requested")
	assert_signal_not_emitted(EventBus, "seed_boost_changed")


func test_non_aiming_phase_touch_emits_seed_boost_changed() -> void:
	var mortar: Node2D = MortarGd.new()
	add_child_autofree(mortar)
	mortar.set(&"_phase", TurnManagerGd.Phase.RESOLVING)
	watch_signals(EventBus)
	mortar.call(&"_unhandled_input", _touch(true, Vector2.ZERO))
	assert_signal_emitted_with_parameters(EventBus, "seed_boost_changed", [true])
	mortar.call(&"_unhandled_input", _touch(false, Vector2.ZERO))
	assert_signal_emitted_with_parameters(EventBus, "seed_boost_changed", [false])


func test_non_aiming_phase_never_fires_or_aims() -> void:
	var mortar: Node2D = MortarGd.new()
	add_child_autofree(mortar)
	mortar.set(&"_phase", TurnManagerGd.Phase.FIRING)
	watch_signals(EventBus)
	mortar.call(&"_unhandled_input", _touch(true, Vector2.ZERO))
	assert_signal_not_emitted(EventBus, "fire_requested")
	assert_signal_not_emitted(EventBus, "aim_updated")


func test_returning_to_aiming_forces_boost_off() -> void:
	var mortar: Node2D = MortarGd.new()
	add_child_autofree(mortar)
	watch_signals(EventBus)
	mortar.call(&"_on_turn_phase_changed", TurnManagerGd.Phase.AIMING)
	assert_signal_emitted_with_parameters(EventBus, "seed_boost_changed", [false])
