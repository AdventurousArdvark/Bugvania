extends Node2D
class_name FxBit
## One short-lived particle square. Spawned in bunches by Fx.burst for death pops
## and impacts. No art needed.

var _vel: Vector2 = Vector2.ZERO
var _life: float = 0.4
var _t: float = 0.0

func setup(color: Color, vel: Vector2, size: float = 4.0, life: float = 0.4) -> void:
	_vel = vel
	_life = life
	var h := size * 0.5
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h),
	])
	poly.color = color
	add_child(poly)

func _process(delta: float) -> void:
	_t += delta
	position += _vel * delta
	_vel.y += 620.0 * delta          # a little gravity
	_vel.x = move_toward(_vel.x, 0.0, 200.0 * delta)
	modulate.a = clampf(1.0 - _t / _life, 0.0, 1.0)
	if _t >= _life:
		queue_free()
