extends Node2D
## Molcajete (GDD sección 2, "Fase de Apuntado/Disparo"). El jugador arrastra el dedo
## en cualquier parte de la pantalla; la dirección de disparo va del molcajete hacia el
## dedo, clampeada a un cono "hacia arriba" (nunca horizontal ni hacia abajo). Al
## soltar, emite fire_requested — TurnManager decide cuántas semillas y las crea (el
## Molcajete no sabe cuántas semillas hay, esa cuenta vive en TurnManager).
## Se reposiciona con la primera semilla que toca el suelo cada turno
## (EventBus.molcajete_position_changed).

const PhysicsMathGd := preload("res://src/shared/physics_math.gd")
const GridMathGd := preload("res://src/shared/grid_math.gd")
const TurnManagerGd := preload("res://src/features/board/turn_manager.gd")

const BODY_RADIUS: float = 26.0
const TEXTURE_PATH: String = "res://assets/sprites/molcajete.png"

var _phase: int = TurnManagerGd.Phase.AIMING
var _is_aiming: bool = false
var _locked_direction: Vector2 = Vector2.UP
var _aim_preview_points: PackedVector2Array = PackedVector2Array()
var _move_tween: Tween = null
var _has_sprite: bool = false


func _ready() -> void:
	position = Vector2(
		Constants.DESIGN_WIDTH * Constants.MOLCAJETE_START_X_RATIO,
		GridMathGd.molcajete_y(Constants.DESIGN_HEIGHT)
	)
	EventBus.turn_phase_changed.connect(_on_turn_phase_changed)
	EventBus.molcajete_position_changed.connect(_on_molcajete_position_changed)
	_build_sprite()


## Sprite2D con textura real si existe; si no, _draw() sigue dibujando los dos círculos
## de siempre (ver el early-out en _draw()). La guía de apuntado punteada siempre se
## dibuja con _draw(), tenga sprite o no — es procedural por diseño, no un sprite fijo.
func _build_sprite() -> void:
	if not ResourceLoader.exists(TEXTURE_PATH):
		return
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = load(TEXTURE_PATH)
	var diameter: float = BODY_RADIUS * 2.0
	var tex_size: Vector2 = sprite.texture.get_size()
	sprite.scale = Vector2(diameter / tex_size.x, diameter / tex_size.y)
	add_child(sprite)
	_has_sprite = true


## Fuera de AIMING, mantener presionada la pantalla acelera las semillas mientras rebotan
## (EventBus.seed_boost_changed, ver seed.gd). El "return" fuera de AIMING antes no hacía
## nada útil — ahora tiene esta única responsabilidad nueva.
func _unhandled_input(event: InputEvent) -> void:
	if _phase != TurnManagerGd.Phase.AIMING:
		if event is InputEventScreenTouch:
			EventBus.seed_boost_changed.emit((event as InputEventScreenTouch).pressed)
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			_is_aiming = true
			_update_aim(touch.position)
		else:
			var was_aiming: bool = _is_aiming
			_is_aiming = false
			if was_aiming:
				_fire()
	elif event is InputEventScreenDrag and _is_aiming:
		_update_aim((event as InputEventScreenDrag).position)


func _update_aim(screen_pos: Vector2) -> void:
	var raw_direction: Vector2 = screen_pos - global_position
	var margin: float = deg_to_rad(Constants.MORTAR_AIM_MARGIN_DEG)
	var sensitivity: float = SaveManager.get_swipe_sensitivity()
	_locked_direction = PhysicsMathGd.clamp_aim_direction(raw_direction, margin, sensitivity)
	_compute_preview()
	queue_redraw()
	EventBus.aim_updated.emit(global_position, _aim_preview_points)


## Traza un rayo en la dirección apuntada; si golpea algo, agrega un segundo tramo
## reflejado para mostrar "la trayectoria del primer rebote" (GDD sección 2).
func _compute_preview() -> void:
	_aim_preview_points = PackedVector2Array([Vector2.ZERO])
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var from: Vector2 = global_position
	var to: Vector2 = from + _locked_direction * Constants.AIM_PREVIEW_LENGTH
	var mask: int = Constants.LAYER_WORLD | Constants.LAYER_BLOCKS
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to, mask)
	var result: Dictionary = space_state.intersect_ray(query)
	if result.is_empty():
		_aim_preview_points.append(to - global_position)
		return
	var hit_pos: Vector2 = result["position"]
	var normal: Vector2 = result["normal"]
	_aim_preview_points.append(hit_pos - global_position)
	var bounced_dir: Vector2 = PhysicsMathGd.reflect(_locked_direction, normal)
	var second_point: Vector2 = hit_pos + bounced_dir * Constants.AIM_BOUNCE_PREVIEW_LENGTH
	_aim_preview_points.append(second_point - global_position)


func _fire() -> void:
	EventBus.fire_requested.emit(_locked_direction, global_position)
	EventBus.aim_cancelled.emit()
	_aim_preview_points = PackedVector2Array()
	queue_redraw()


func _on_turn_phase_changed(phase: int) -> void:
	_phase = phase
	if phase != TurnManagerGd.Phase.AIMING:
		_is_aiming = false
		_aim_preview_points = PackedVector2Array()
		queue_redraw()
	else:
		## Cubre soltar el dedo justo cuando termina la ráfaga, mientras aún se
		## consideraba "boost" — sin esto, el boost podría quedarse pegado en true.
		EventBus.seed_boost_changed.emit(false)


func _on_molcajete_position_changed(new_x: float) -> void:
	var clamped_x: float = clampf(new_x, BODY_RADIUS, Constants.DESIGN_WIDTH - BODY_RADIUS)
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = create_tween()
	var tweener: PropertyTweener = _move_tween.tween_property(
		self, ^"position:x", clamped_x, Constants.MOLCAJETE_MOVE_DURATION
	)
	tweener.set_ease(Tween.EASE_OUT)


func _draw() -> void:
	if not _has_sprite:
		draw_circle(Vector2.ZERO, BODY_RADIUS, Constants.COLOR_MOLCAJETE)
		draw_circle(Vector2.ZERO, BODY_RADIUS * 0.62, Constants.COLOR_MOLCAJETE.darkened(0.35))
	if _is_aiming and _aim_preview_points.size() >= 2:
		_draw_dotted_line(_aim_preview_points)


func _draw_dotted_line(points: PackedVector2Array) -> void:
	for seg: int in points.size() - 1:
		var a: Vector2 = points[seg]
		var b: Vector2 = points[seg + 1]
		var seg_len: float = a.distance_to(b)
		var steps: int = maxi(1, int(seg_len / Constants.AIM_DOT_SPACING))
		for i: int in steps + 1:
			var t: float = float(i) / float(steps)
			draw_circle(a.lerp(b, t), Constants.AIM_DOT_RADIUS, Constants.COLOR_AIM_GUIDE)
