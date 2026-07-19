extends CanvasLayer
## HUD de gameplay: score, oleada actual, semillas disponibles y botón de pausa.
## Instanciado por Game.tscn (construcción 100% programática, sin sprites — ver
## CLAUDE.md sección FTUE). Sin lógica de juego: solo refleja EventBus / GameManager.

var _score_label: Label = Label.new()
var _wave_label: Label = Label.new()
var _seed_label: Label = Label.new()
var _pause_button: Button = Button.new()


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	EventBus.score_changed.connect(_on_score_changed)
	EventBus.wave_advanced.connect(_on_wave_advanced)
	EventBus.seed_count_changed.connect(_on_seed_count_changed)
	_on_score_changed(GameManager.get_score())
	_on_wave_advanced(GameManager.get_wave())


func _build_ui() -> void:
	_score_label.position = Vector2(16.0, 40.0)
	_score_label.set_size(Vector2(200.0, 26.0))
	_style_label(_score_label, Constants.COLOR_HUD_TEXT)
	add_child(_score_label)

	_wave_label.position = Vector2(16.0, 68.0)
	_wave_label.set_size(Vector2(200.0, 26.0))
	_style_label(_wave_label, Constants.COLOR_HUD_TEXT)
	add_child(_wave_label)

	_seed_label.text = "Semillas: %d" % Constants.MOLCAJETE_START_SEEDS
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


func _style_label(label: Label, color: Color) -> void:
	label.add_theme_font_size_override(&"font_size", Constants.UI_MIN_FONT_SIZE)
	label.add_theme_color_override(&"font_color", color)


func _on_score_changed(new_score: int) -> void:
	_score_label.text = "Score: %d" % new_score


func _on_wave_advanced(wave_number: int) -> void:
	_wave_label.text = "Oleada %d" % wave_number


func _on_seed_count_changed(new_count: int) -> void:
	_seed_label.text = "Semillas: %d" % new_count


func _on_pause_pressed() -> void:
	GameManager.pause_game()
