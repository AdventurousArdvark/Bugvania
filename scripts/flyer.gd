extends EnemyBase
class_name Flyer
## Hovers at its spawn height, drifting toward the player. Every few seconds it
## TELEGRAPHS (rises slightly + flashes pale) then SWOOPS at your position, then
## climbs back. The flash is the tell — bait it, then punish the recovery.

enum S { HOVER, TELEGRAPH, SWOOP, RETURN }

@export var hover_speed: float = 55.0
@export var swoop_speed: float = 360.0
@export var swoop_interval: float = 2.6
@export var telegraph_time: float = 0.45

var _s: int = S.HOVER
var _t: float = 0.0
var _base_y: float = 0.0
var _have_base: bool = false
var _target: Vector2 = Vector2.ZERO

func _setup() -> void:
	visual_kind = "flyer"
	use_gravity = false
	max_health = 3
	health = 3
	color = Color("#6f9bd6")
	contact_damage = 12

func _behavior(delta: float) -> void:
	if not _have_base:
		_base_y = global_position.y
		_have_base = true
		_t = swoop_interval
	if _player == null:
		return
	var ppos: Vector2 = (_player as Node2D).global_position
	_t -= delta
	_set_pose("swoop" if (_s == S.TELEGRAPH or _s == S.SWOOP) else "")

	match _s:
		S.HOVER:
			var bob := sin(Time.get_ticks_msec() / 320.0) * 14.0
			velocity.y = ((_base_y + bob) - global_position.y) * 3.0
			velocity.x = signf(ppos.x - global_position.x) * hover_speed
			if _t <= 0.0:
				_s = S.TELEGRAPH
				_t = telegraph_time
				modulate = Color("#dce8ff")
		S.TELEGRAPH:
			velocity = Vector2(0, -40.0)               # tense little rise
			if _t <= 0.0:
				_target = (_player as Node2D).global_position
				_s = S.SWOOP
				_t = 0.9
				modulate = Color.WHITE
				var dir := (_target - global_position).normalized()
				velocity = dir * swoop_speed
		S.SWOOP:
			if _t <= 0.0 or is_on_wall():
				_s = S.RETURN
				_t = 0.0
		S.RETURN:
			velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
			velocity.y = (_base_y - global_position.y) * 2.4
			if absf(global_position.y - _base_y) < 10.0:
				_s = S.HOVER
				_t = swoop_interval
