extends GutTest
## Tests para las funciones puras de física de rebote (GDD sección 2: "e=1.0").

const PhysicsMathGd := preload("res://src/shared/physics_math.gd")


func test_reflect_flips_component_along_normal() -> void:
	var result: Vector2 = PhysicsMathGd.reflect(Vector2(100.0, 50.0), Vector2.RIGHT)
	assert_almost_eq(
		result.x, -100.0, 0.001, "el componente en la dirección de la normal se invierte"
	)
	assert_almost_eq(result.y, 50.0, 0.001, "el componente tangente no cambia")


func test_reflect_preserves_speed_magnitude() -> void:
	var velocity: Vector2 = Vector2(300.0, -450.0)
	var result: Vector2 = PhysicsMathGd.reflect(velocity, Vector2(0.7071, 0.7071))
	assert_almost_eq(result.length(), velocity.length(), 0.01, "e=1.0: la rapidez no debe cambiar")


func test_reflect_zero_normal_returns_velocity_unchanged() -> void:
	var velocity: Vector2 = Vector2(42.0, -7.0)
	var result: Vector2 = PhysicsMathGd.reflect(velocity, Vector2.ZERO)
	assert_eq(result, velocity, "normal cero es entrada inválida: no debe alterar la velocidad")


func test_apply_speed_ratio_slows_down_by_ratio() -> void:
	var result: Vector2 = PhysicsMathGd.apply_speed_ratio(Vector2(100.0, 0.0), 0.85, 100.0, 0.35)
	assert_almost_eq(result.length(), 85.0, 0.01, "debe frenar exactamente al ratio pedido")


func test_apply_speed_ratio_never_drops_below_floor() -> void:
	var result: Vector2 = PhysicsMathGd.apply_speed_ratio(Vector2(40.0, 0.0), 0.1, 100.0, 0.35)
	assert_almost_eq(result.length(), 35.0, 0.01, "no debe bajar del piso relativo a base_speed")


func test_apply_speed_ratio_zero_velocity_does_not_crash() -> void:
	var result: Vector2 = PhysicsMathGd.apply_speed_ratio(Vector2.ZERO, 0.85, 100.0, 0.35)
	assert_eq(result, Vector2.ZERO, "velocidad cero debe seguir siendo cero, sin dividir por cero")


func test_rotate_velocity_preserves_magnitude() -> void:
	var velocity: Vector2 = Vector2(120.0, -80.0)
	var result: Vector2 = PhysicsMathGd.rotate_velocity(velocity, deg_to_rad(20.0))
	assert_almost_eq(result.length(), velocity.length(), 0.01, "rotar no debe cambiar la rapidez")


func test_rotate_velocity_changes_angle_by_exact_amount() -> void:
	var velocity: Vector2 = Vector2(100.0, 0.0)
	var result: Vector2 = PhysicsMathGd.rotate_velocity(velocity, deg_to_rad(90.0))
	var delta_angle: float = wrapf(result.angle() - velocity.angle(), -PI, PI)
	assert_almost_eq(delta_angle, deg_to_rad(90.0), 0.01)


func test_clamp_aim_direction_zero_input_defaults_to_up() -> void:
	var result: Vector2 = PhysicsMathGd.clamp_aim_direction(Vector2.ZERO, deg_to_rad(15.0))
	assert_eq(result, Vector2.UP, "sin arrastre, debe apuntar derecho hacia arriba")


func test_clamp_aim_direction_straight_up_stays_up() -> void:
	var result: Vector2 = PhysicsMathGd.clamp_aim_direction(Vector2(0.0, -200.0), deg_to_rad(15.0))
	assert_almost_eq(result.x, 0.0, 0.01)
	assert_almost_eq(result.y, -1.0, 0.01)


func test_clamp_aim_direction_clamps_near_horizontal_to_margin() -> void:
	var margin: float = deg_to_rad(15.0)
	var result: Vector2 = PhysicsMathGd.clamp_aim_direction(Vector2(200.0, -1.0), margin)
	assert_almost_eq(result.angle(), -margin, 0.01, "no debe superar el margen")


func test_clamp_aim_direction_default_sensitivity_matches_explicit_one() -> void:
	var raw: Vector2 = Vector2(60.0, -140.0)
	var margin: float = deg_to_rad(15.0)
	var implicit_result: Vector2 = PhysicsMathGd.clamp_aim_direction(raw, margin)
	var explicit_result: Vector2 = PhysicsMathGd.clamp_aim_direction(raw, margin, 1.0)
	assert_almost_eq(implicit_result.x, explicit_result.x, 0.001)
	assert_almost_eq(implicit_result.y, explicit_result.y, 0.001)


func test_clamp_aim_direction_higher_sensitivity_deviates_more_from_up() -> void:
	var raw: Vector2 = Vector2(30.0, -140.0)
	var margin: float = deg_to_rad(15.0)
	var up_angle: float = -PI * 0.5
	var low_sensitivity: Vector2 = PhysicsMathGd.clamp_aim_direction(raw, margin, 1.0)
	var high_sensitivity: Vector2 = PhysicsMathGd.clamp_aim_direction(raw, margin, 3.0)
	var low_deviation: float = absf(low_sensitivity.angle() - up_angle)
	var high_deviation: float = absf(high_sensitivity.angle() - up_angle)
	var msg: String = "mayor sensibilidad debe alejar mas el angulo de 'arriba' para el mismo arrastre"
	assert_true(high_deviation > low_deviation, msg)
