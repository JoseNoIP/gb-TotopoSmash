extends CanvasLayer
## HUD de gameplay: score, oleada actual, semillas disponibles y botón de pausa.
## Instanciado por Game.tscn (construcción 100% programática, sin sprites — ver
## CLAUDE.md sección FTUE). Sin lógica de juego: solo refleja EventBus / GameManager.

const TurnManagerGd := preload("res://src/features/board/turn_manager.gd")

var _score_label: Label = Label.new()
var _wave_label: Label = Label.new()
var _seed_label: Label = Label.new()
var _pause_button: Button = Button.new()
## Botón "recoger semillas" (pedido explícito del usuario) — solo visible mientras hay
## una ráfaga en curso (FIRING/RESOLVING/RETURNING); no tiene sentido en AIMING/ADVANCING,
## no hay nada que recoger todavía o ya se recogió todo.
var _recall_button: Button = Button.new()


## NO leer GameManager.is_level_mode()/get_current_level_id() aquí directo: HUD nace
## dentro de Game._build_scene(), que corre ANTES de GameManager.start_game(level_id) —
## en ese momento _current_level_id todavía trae el valor de la partida ANTERIOR (o "").
## Por eso el número de nivel/oleada se fija reaccionando a game_started (que se emite
## DESPUÉS de que start_game() ya actualizó el estado), igual que BoardManager/TurnManager.
func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	EventBus.score_changed.connect(_on_score_changed)
	EventBus.seed_count_changed.connect(_on_seed_count_changed)
	EventBus.game_started.connect(_on_game_started)
	EventBus.wave_advanced.connect(_on_wave_advanced)
	EventBus.turn_phase_changed.connect(_on_turn_phase_changed)
	_on_score_changed(GameManager.get_score())


## Modo Nivel: wave_advanced nunca se emite después de esto (no aparecen filas nuevas,
## ver board_manager.gd) — el label se fija una sola vez a "NIVEL N". Modo Infinito: no
## hace falta nada aquí, wave_advanced(1) ya llega por separado desde BoardManager.
## Si el nivel tiene `name` (niveles-figura y packs temáticos, ver LevelManager) se agrega
## el nombre traducido junto al número — pedido explícito del usuario: al ver una figura
## abstracta (ej. la Copa del Mundo a baja resolución) ayuda a saber a qué se refiere.
func _on_game_started() -> void:
	if not GameManager.is_level_mode():
		return
	var level_id: String = GameManager.get_current_level_id()
	var index: int = LevelManager.get_level_index(level_id)
	var name_key: Variant = LevelManager.get_level_data(level_id).get("name")
	if name_key is String and not (name_key as String).is_empty():
		_wave_label.text = tr(&"LABEL_LEVEL_NUMBER_NAMED") % [index + 1, tr(name_key as String)]
	else:
		_wave_label.text = tr(&"LABEL_LEVEL_NUMBER") % (index + 1)


func _build_ui() -> void:
	_score_label.position = Vector2(16.0, 40.0)
	_score_label.set_size(Vector2(200.0, 26.0))
	_style_label(_score_label, Constants.COLOR_HUD_TEXT)
	add_child(_score_label)

	_wave_label.position = Vector2(16.0, 68.0)
	_wave_label.set_size(Vector2(200.0, 26.0))
	_style_label(_wave_label, Constants.COLOR_HUD_TEXT)
	add_child(_wave_label)

	_seed_label.text = tr(&"LABEL_SEEDS") % Constants.MOLCAJETE_START_SEEDS
	_seed_label.position = Vector2(Constants.DESIGN_WIDTH - 166.0, 40.0)
	_seed_label.set_size(Vector2(150.0, 26.0))
	_seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_style_label(_seed_label, Constants.COLOR_SEED_EXTRA)
	add_child(_seed_label)

	_pause_button.text = "II"
	_pause_button.position = Vector2(Constants.DESIGN_WIDTH - 56.0, 72.0)
	_pause_button.set_size(Vector2(40.0, 40.0))
	_pause_button.pressed.connect(_on_pause_pressed)
	add_child(_pause_button)

	## ">>" (símbolo plano, mismo criterio que "II" de pausa arriba — ninguno de los dos
	## pasa por tr(), son glifos, no texto traducible) a la izquierda del botón de pausa.
	_recall_button.text = ">>"
	_recall_button.position = Vector2(Constants.DESIGN_WIDTH - 104.0, 72.0)
	_recall_button.set_size(Vector2(40.0, 40.0))
	_recall_button.visible = false
	_recall_button.pressed.connect(_on_recall_pressed)
	add_child(_recall_button)


func _style_label(label: Label, color: Color) -> void:
	label.add_theme_font_size_override(&"font_size", Constants.UI_MIN_FONT_SIZE)
	label.add_theme_color_override(&"font_color", color)


func _on_score_changed(new_score: int) -> void:
	_score_label.text = tr(&"LABEL_SCORE") % new_score


func _on_wave_advanced(wave_number: int) -> void:
	## Nunca se emite en Modo Nivel en la práctica (guard defensivo de cualquier forma).
	if GameManager.is_level_mode():
		return
	_wave_label.text = tr(&"LABEL_WAVE") % wave_number


func _on_seed_count_changed(new_count: int) -> void:
	_seed_label.text = tr(&"LABEL_SEEDS") % new_count


## Visible solo mientras hay una ráfaga en curso — en AIMING (apuntando) o ADVANCING
## (tablero ya resuelto, a punto de volver a AIMING) no hay ninguna semilla que recoger.
func _on_turn_phase_changed(phase: int) -> void:
	_recall_button.visible = (
		phase == TurnManagerGd.Phase.FIRING
		or phase == TurnManagerGd.Phase.RESOLVING
		or phase == TurnManagerGd.Phase.RETURNING
	)


func _on_recall_pressed() -> void:
	EventBus.recall_all_seeds_requested.emit()


func _on_pause_pressed() -> void:
	GameManager.pause_game()
