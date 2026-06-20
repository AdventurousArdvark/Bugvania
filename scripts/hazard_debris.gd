extends Area2D
class_name HazardDebris
## A chunk of falling ceiling during the escape. Falls under gravity, damages the
## player on contact, and frees itself when it leaves the screen or times out.

var _vel: Vector2 = Vector2.ZERO
var _life: float = 4.0
var _size: float = 10.0
var _spin: float = 0.0

func setup(pos: Vector2, vx: float, sz: float) -> void:
	global_position = pos
	_vel = Vector2(vx, 40.0)
	_size = sz
	_spin = randf_range(-6.0, 6.0)

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2                  # the player body lives on layer 2
	monitoring = true
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = _size
	cs.shape = c
	add_child(cs)
	body_entered.connect(_on_body)

func _process(delta: float) -> void:
	_vel.y += 900.0 * delta
	position += _vel * delta
	rotation += _spin * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()
	queue_redraw()

func _on_body(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(15, global_position)
		Fx.burst(get_parent(), global_position, Color("#9a7a52"), 6, 130.0)
		queue_free()

func _draw() -> void:
	var s := _size
	var pts := PackedVector2Array([
		Vector2(-s, -s * 0.6), Vector2(s * 0.7, -s), Vector2(s, s * 0.5),
		Vector2(s * 0.2, s), Vector2(-s * 0.8, s * 0.7),
	])
	draw_colored_polygon(pts, Color("#6e5436"))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color("#8a6a44"), 1.5)
