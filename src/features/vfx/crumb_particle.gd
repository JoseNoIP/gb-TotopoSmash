extends Node2D
## Partícula procedural individual ("migaja" de totopo o gota de salsa — GDD sección 5).
## Sin dependencia de GPUParticles2D/ParticleProcessMaterial: usamos un Node2D + _draw()
## simple (mismo enfoque que el resto del juego, sin sprites) para no arriesgar nombres de
## propiedades del motor que no se puedan verificar aquí (regla anti-alucinación #1).
## Instanciada y descartada por vfx_spawner.gd — no se reutiliza.

const GRAVITY: float = 640.0

var _velocity: Vector2 = Vector2.ZERO
var _color: Color = Color.WHITE
var _radius: float = 3.0
var _lifetime: float = 0.5
var _age: float = 0.0


func setup(color: Color, radius: float, velocity: Vector2, lifetime: float) -> void:
	_color = color
	_radius = radius
	_velocity = velocity
	_lifetime = lifetime


func _process(delta: float) -> void:
	_age += delta
	if _age >= _lifetime:
		queue_free()
		return
	_velocity.y += GRAVITY * delta
	position += _velocity * delta
	queue_redraw()


func _draw() -> void:
	var fade: float = clampf(1.0 - _age / _lifetime, 0.0, 1.0)
	draw_circle(Vector2.ZERO, _radius * fade, Color(_color.r, _color.g, _color.b, fade))
