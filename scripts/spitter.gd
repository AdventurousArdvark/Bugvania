extends EnemyBase
class_name Spitter
## Stationary turret. Tracks you; when in range it WINDS UP (swells + flashes), then
## fires a slow hostile glob you can out-maneuver. Punishes campers, rewards movement.

enum S { COOLDOWN, WINDUP, FIRE }

@export var sight_range: float = 380.0
@export var windup_time: float = 0.55
@export var cooldown_time: float = 1.8
@export var shot_speed: float = 230.0
@export var shot_damage: int = 12

var _s: int = S.COOLDOWN
var _t: float = 0.0

func _setup() -> void:
	visual_kind = "spitter"
	max_health = 5
	health = 5
	size = Vector2(28, 26)
	color = Color("#7a8f3b")
	contact_damage = 10

func _behavior(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
	if _player == null:
		return
	var ppos: Vector2 = (_player as Node2D).global_position
	var in_range := global_position.distance_to(ppos) < sight_range
	_t -= delta
	_set_pose("charge" if _s == S.WINDUP else "")

	match _s:
		S.COOLDOWN:
			if _t <= 0.0 and in_range:
				_s = S.WINDUP
				_t = windup_time
				modulate = Color("#e6ff8a")
		S.WINDUP:
			var p: float = clampf(1.0 - _t / windup_time, 0.0, 1.0)
			scale = Vector2.ONE * (1.0 + 0.18 * p)     # swell as it charges
			if _t <= 0.0:
				_fire(ppos)
				scale = Vector2.ONE
				modulate = Color.WHITE
				_s = S.COOLDOWN
				_t = cooldown_time

func _fire(ppos: Vector2) -> void:
	var dir := (ppos - global_position).normalized()
	var proj := Projectile.new()
	get_parent().add_child(proj)
	proj.setup(global_position + dir * (size.x * 0.5 + 8.0), dir, {
		"speed": shot_speed, "damage": shot_damage, "size": 8.0,
		"color": Color("#caff5e"), "lifetime": 3.0, "hostile": true, "element": "",
	})
	Audio.play("shoot")
