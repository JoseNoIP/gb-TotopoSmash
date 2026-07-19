extends RefCounted
## Funciones puras de física para el rebote elástico de semillas (GDD sección 2: "e=1.0").
## Implementamos la reflexión manualmente (formula estándar v' = v - 2*(v·n)*n) en vez de
## depender de Vector2.bounce()/reflect() para no arriesgar una convención de signo mal
## recordada (regla anti-alucinación #7). Sin estado, testeable con GUT sin escena.
## Uso: const PhysicsMathGd := preload("res://src/shared/physics_math.gd")


## Refleja `velocity` respecto a una superficie con normal `normal` (no requiere que
## `normal` venga normalizado). Preserva la magnitud exacta de `velocity` — es lo que
## garantiza la "física elástica perfecta" (e=1.0) del GDD.
static func reflect(velocity: Vector2, normal: Vector2) -> Vector2:
	if normal == Vector2.ZERO:
		return velocity
	var n: Vector2 = normal.normalized()
	return velocity - 2.0 * velocity.dot(n) * n


## Escala la velocidad manteniendo su dirección, con un piso mínimo relativo a
## `base_speed` (GDD: el Queso frena la semilla 15% por rebote, pero no debe tender a 0
## tras varios rebotes seguidos — Constants.SEED_MIN_SPEED_RATIO).
static func apply_speed_ratio(
	velocity: Vector2, ratio: float, base_speed: float, min_ratio: float
) -> Vector2:
	var new_speed: float = velocity.length() * ratio
	var floor_speed: float = base_speed * min_ratio
	new_speed = maxf(new_speed, floor_speed)
	return velocity.normalized() * new_speed


## Rota `velocity` por `angle_rad` radianes. Usado por el Limón para partir la semilla
## en dos ángulos simétricos opuestos (GDD sección 3).
static func rotate_velocity(velocity: Vector2, angle_rad: float) -> Vector2:
	return velocity.rotated(angle_rad)


## Clampa una dirección cruda (arrastre del jugador) a un cono "hacia arriba" para que
## el molcajete nunca apunte hacia abajo o casi horizontal. `margin_rad` es el margen
## mínimo respecto a la horizontal en cada lado (ver Constants.MORTAR_AIM_MARGIN_DEG).
## `sensitivity` amplifica (>1.0) o amortigua (<1.0) la desviación respecto a "arriba"
## antes de clampar — usado por SettingsScreen (Constants por defecto: 1.0 = sin cambio,
## idéntico a clampf(angle, ...) directo). Ver SaveManager.get_swipe_sensitivity().
static func clamp_aim_direction(
	raw_direction: Vector2, margin_rad: float, sensitivity: float = 1.0
) -> Vector2:
	if raw_direction == Vector2.ZERO:
		return Vector2.UP
	var up_angle: float = -PI * 0.5
	var raw_angle: float = raw_direction.angle()
	var deviation: float = wrapf(raw_angle - up_angle, -PI, PI) * sensitivity
	var angle: float = up_angle + deviation
	var clamped: float = clampf(angle, -PI + margin_rad, -margin_rad)
	return Vector2(cos(clamped), sin(clamped))
