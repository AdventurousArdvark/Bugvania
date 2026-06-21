extends AnimatableBody2D
class_name Crusher
## A heavy block that slams along `dir` on a timed cycle: rest -> fast slam ->
## hold -> slow retract. Solid (World layer) so it shoves the player; if it catches
## the player during the slam/hold it deals a heavy crush hit. Telegraphed by the
## slow rest/retract so it's dodgeable on rhythm.

@export var block: Vector2 = Vector2(96, 96)
@export var travel: float = 96.0
@export var dir: Vector2 = Vector2.DOWN
@export var rest_time: float = 1.0
@export var slam_time: float = 0.12
@export var hold_time: float = 0.45
@export var retract_time: float = 1.1
@export var damage: int = 24
@export var color: Color = Color("#5b3a3a")

enum { REST, SLAM, HOLD, RETRACT }
var _state: int = REST
var _t: float = 0.0
var _base: Vector2 = Vector2.ZERO
var _hurt: Area2D = null
var _prog: float = 0.0

func _ready() -> void:
	sync_to_physics = true
	collision_layer = 1                 # solid World
	collision_mask = 0
	_base = position
	_t = rest_time
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = block
	cs.shape = r
	add_child(cs)
	_hurt = Area2D.new()
	_hurt.collision_layer = 0
	_hurt.collision_mask = 2            # the player
	_hurt.monitoring = true
	add_child(_hurt)
	var hcs := CollisionShape2D.new()
	var hr := RectangleShape2D.new()
	hr.size = block + dir.normalized().abs() * 12.0   # a little reach on the leading face
	hcs.shape = hr
	_hurt.add_child(hcs)

func _physics_process(delta: float) -> void:
	_t -= delta
	match _state:
		REST:
			_prog = 0.0
			if _t <= 0.0:
				_state = SLAM
				_t = slam_time
		SLAM:
			_prog = clampf(1.0 - _t / slam_time, 0.0, 1.0)
			_prog *= _prog                # ease-in: accelerate into the slam
			if _t <= 0.0:
				_prog = 1.0
				_state = HOLD
				_t = hold_time
				Audio.play("hit")
				get_tree().call_group("camera_rig", "shake", 4.0, 0.2)
				_crush()
		HOLD:
			_prog = 1.0
			_crush()
			if _t <= 0.0:
				_state = RETRACT
				_t = retract_time
		RETRACT:
			_prog = clampf(_t / retract_time, 0.0, 1.0)
			if _t <= 0.0:
				_state = REST
				_t = rest_time
	position = _base + dir.normalized() * travel * _prog
	queue_redraw()

func _crush() -> void:
	for b in _hurt.get_overlapping_bodies():
		if b.has_method("take_damage"):
			b.take_damage(damage, global_position)

func _draw() -> void:
	var hw := block.x * 0.5
	var hh := block.y * 0.5
	draw_rect(Rect2(-hw, -hh, block.x, block.y), color)
	draw_rect(Rect2(-hw, -hh, block.x, block.y), color.lightened(0.25), false, 2.0)
	# Teeth on the leading face.
	var n := dir.normalized()
	var tan := Vector2(-n.y, n.x)
	var face := n * Vector2(hw, hh).length() * 0.0 + n * (hh if absf(n.y) > absf(n.x) else hw)
	var reach := 10.0
	var count := 6
	var fw := (block.x if absf(n.y) > absf(n.x) else block.y) / float(count)
	for i in count:
		var c := face + tan * (-(block.x if absf(n.y) > absf(n.x) else block.y) * 0.5 + (float(i) + 0.5) * fw)
		draw_colored_polygon(PackedVector2Array([
			c - tan * fw * 0.5, c + tan * fw * 0.5, c + n * reach,
		]), color.lightened(0.15))
