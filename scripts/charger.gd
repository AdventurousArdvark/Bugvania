extends EnemyBase
class_name Charger
## Grounded bruiser. Paces slowly; when you're roughly level and within range it
## WINDS UP (backs up + flashes red), then RUSHES across the floor. Slams a wall and
## RECOVERS (vulnerable). Sidestep the rush and hit it during recovery.

enum S { PACE, WINDUP, RUSH, RECOVER }

@export var pace_speed: float = 50.0
@export var rush_speed: float = 430.0
@export var sight_range: float = 320.0
@export var windup_time: float = 0.5
@export var recover_time: float = 0.9

var _s: int = S.PACE
var _t: float = 0.0
var _dir: int = -1
var _cooldown: float = 0.0

func _setup() -> void:
	visual_kind = "charger"
	max_health = 6
	health = 6
	size = Vector2(34, 30)
	color = Color("#b8512f")
	contact_damage = 16

func _behavior(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
	if _player == null:
		velocity.x = _dir * pace_speed
		return
	var ppos: Vector2 = (_player as Node2D).global_position
	_t -= delta
	_set_pose("windup" if _s == S.WINDUP else ("rush" if _s == S.RUSH else ""))

	match _s:
		S.PACE:
			velocity.x = _dir * pace_speed
			if is_on_wall() or _bound_hit_x or not _ground_ahead(_dir):
				_dir = -_dir
			var level := absf(ppos.y - global_position.y) < 48.0
			var near := absf(ppos.x - global_position.x) < sight_range
			if level and near and _cooldown <= 0.0:
				_dir = -1 if ppos.x < global_position.x else 1
				_s = S.WINDUP
				_t = windup_time
				modulate = Color("#ff6a4a")           # tell
		S.WINDUP:
			velocity.x = float(-_dir) * 60.0           # rear back
			if _t <= 0.0:
				_s = S.RUSH
				_t = 1.1
				modulate = Color.WHITE
		S.RUSH:
			velocity.x = _dir * rush_speed
			if is_on_wall() or _bound_hit_x or not _ground_ahead(_dir) or _t <= 0.0:
				_s = S.RECOVER
				_t = recover_time
				modulate = Color("#e8b09a")            # vulnerable
		S.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
			if _t <= 0.0:
				modulate = Color.WHITE
				_s = S.PACE
				_cooldown = 1.0
