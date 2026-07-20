extends GutTest
## Tests para GameManager: bono de score por terminar un nivel `static` en pocos turnos
## (par_turns) — pedido explícito del usuario ("recompensar hacerlo en menos turnos").
## Separado de test_game_manager.gd porque ese archivo ya rozaba el máximo de 20 métodos
## públicos por clase que exige gdlint (mismo motivo que MetaManager, ver regla CLAUDE.md
## #51).

func before_each() -> void:
	GameManager.start_game()


func test_par_turns_bonus_applied_when_cleared_within_par() -> void:
	GameManager.start_game("worldcup_001")
	GameManager.add_score(1000)
	watch_signals(EventBus)
	EventBus.level_cleared.emit("worldcup_001", 1)  ## par_turns real siempre >= 3
	var expected: int = roundi(1000 * Constants.STATIC_LEVEL_PAR_BONUS_MULTIPLIER)
	assert_signal_emitted_with_parameters(EventBus, "level_completed", ["worldcup_001", expected])
	GameManager.start_game()


func test_par_turns_bonus_not_applied_when_turns_exceed_par() -> void:
	GameManager.start_game("worldcup_001")
	GameManager.add_score(1000)
	var par_turns: int = int(LevelManager.get_level_data("worldcup_001").get("par_turns"))
	watch_signals(EventBus)
	EventBus.level_cleared.emit("worldcup_001", par_turns + 1)
	assert_signal_emitted_with_parameters(EventBus, "level_completed", ["worldcup_001", 1000])
	GameManager.start_game()


func test_par_turns_bonus_not_applied_when_turns_used_is_zero() -> void:
	## turns_used=0 significa "no aplica" (Modo Infinito / Modo Nivel normal).
	GameManager.start_game("level_001")
	GameManager.add_score(1000)
	watch_signals(EventBus)
	EventBus.level_cleared.emit("level_001", 0)
	assert_signal_emitted_with_parameters(EventBus, "level_completed", ["level_001", 1000])
	GameManager.start_game()
