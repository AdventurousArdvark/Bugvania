extends Node2D
class_name Weapon
## The cannon. Attach as a child of the player (player.gd auto-creates one).
##
##   - 8-DIRECTIONAL aim from existing inputs (move_left/right/up/down + facing).
##   - "attack": tap = normal beam. Hold to full + release = charged beam.
##   - "shoot": fires a MISSILE (limited ammo) - also the key for missile doors.
##   - Shot stats are composed from the player's beam FLAGS (has_charge / has_ice /
##     has_wave). Each upgrade is one branch in _make_stats().
##
## Aim is produced as a DIRECTION VECTOR; swapping to free aim later only means
## rewriting _aim_dir().

@export var projectile_speed: float = 460.0
@export var base_damage: int = 1
@export var charged_damage: int = 4
@export var charge_time: float = 0.6
@export var fire_cooldown: float = 0.18
@export var muzzle_offset: float = 14.0

# Missiles
@export var missile_speed: float = 320.0
@export var missile_damage: int = 8

var _player: Node = null
var _cooldown: float = 0.0
var _charging: bool = false
var _charge_t: float = 0.0
var _can_charge: bool = false
var _anim: float = 0.0

func _ready() -> void:
	var p := get_parent()
	if p is CharacterBody2D:
		_player = p

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
	_anim += delta

	var can_charge: bool = _player != null and _player.get("has_charge") == true and _player.get("charge_active") != false
	_can_charge = can_charge

	if _act_just_pressed("attack"):
		_fire(false)
		_charging = true
		_charge_t = 0.0
	if _charging and can_charge:
		var was := _charge_t
		_charge_t += delta
		if was < charge_time and _charge_t >= charge_time:
			Audio.play("charge_ready")
			if _player != null:
				Fx.burst(_player.get_parent(), (_player as Node2D).global_position + Vector2(0, -8), Color("#ffffff"), 6, 90.0)
	if _act_just_released("attack"):
		if _charging and can_charge and _charge_t >= charge_time:
			_fire(true)
		_charging = false

	if _act_just_pressed("shoot"):
		_fire_missile()

	queue_redraw()   # update the charge ring (or clear it)

func _draw() -> void:
	if not (_charging and _can_charge):
		return
	var p := clampf(_charge_t / charge_time, 0.0, 1.0)
	var c := Vector2(0, -8)
	var r := lerpf(5.0, 16.0, p)
	var col := Color("#9fe6ff")
	var a := 0.35 + 0.45 * p
	if p >= 1.0:
		col = Color("#ffffff")                      # fully charged: bright + pulsing
		a = 0.7 + 0.3 * sin(_anim * 18.0)
	draw_arc(c, r, 0.0, TAU, 28, Color(col.r, col.g, col.b, a), 2.0)
	for i in 3:                                      # orbiting motes as it fills
		var ang := _anim * 6.0 + i * TAU / 3.0
		draw_circle(c + Vector2(cos(ang), sin(ang)) * r, 1.6, Color(col.r, col.g, col.b, a))

func _fire(charged: bool) -> void:
	if not charged and _cooldown > 0.0:
		return
	_spawn(_aim_dir(), _make_stats(charged))
	Audio.play("charged" if charged else "shoot")
	if not charged:
		_cooldown = fire_cooldown

func _fire_missile() -> void:
	if _player == null or _player.get("has_missiles") != true:
		return
	var ammo: int = int(_player.get("missiles"))
	if ammo <= 0:
		return
	_player.set("missiles", ammo - 1)
	_spawn(_aim_dir(), _missile_stats())
	Audio.play("missile")

func _spawn(dir: Vector2, stats: Dictionary) -> void:
	if _player == null:
		return
	var world := _player.get_parent()
	if world == null:
		world = _player
	var proj := Projectile.new()
	world.add_child(proj)
	var muzzle := (_player as Node2D).global_position + Vector2(0, -8) + dir * muzzle_offset
	proj.setup(muzzle, dir, stats)
	Fx.burst(world, muzzle, stats.get("color", Color.WHITE), 3, 70.0)   # muzzle flash

func _aim_dir() -> Vector2:
	var hx := 0
	if _act_pressed("move_left"):
		hx -= 1
	if _act_pressed("move_right"):
		hx += 1
	var vy := 0
	if _act_pressed("move_up"):
		vy -= 1
	if _act_pressed("move_down"):
		vy += 1
	if hx == 0 and vy == 0:
		return Vector2(_facing(), 0)
	return Vector2(hx, vy).normalized()

func _facing() -> int:
	if _player != null and _player.has_method("get_facing"):
		return _player.get_facing()
	return 1

# THE UPGRADE HUB. Every beam upgrade adds a branch that tweaks this dictionary.
func _make_stats(charged: bool) -> Dictionary:
	var s := {
		"speed": projectile_speed,
		"damage": base_damage,
		"size": 7.0,
		"color": Color("#9fe6ff"),
		"lifetime": 1.2,
		"pierce": false,
		"element": "",
	}
	if charged:
		s.damage = charged_damage
		s.size = 14.0
		s.color = Color("#ffffff")
		s.lifetime = 1.5
	if _player != null and _player.get("has_ice") == true and _player.get("ice_active") != false:
		s.element = "ice"                 # freezes enemies (enemy.gd reacts)
		s.color = Color("#bfe9ff")
	if _player != null and _player.get("has_wave") == true and _player.get("wave_active") != false:
		s.pierce = true                   # Wave passes through walls and enemies
		s.color = Color("#c77dff")
	return s

func _missile_stats() -> Dictionary:
	return {
		"speed": missile_speed,
		"damage": missile_damage,
		"size": 12.0,
		"color": Color("#ff8c42"),
		"lifetime": 2.0,
		"pierce": false,
		"element": "missile",             # opens missile doors
	}

func _act_pressed(a: String) -> bool:
	return InputMap.has_action(a) and Input.is_action_pressed(a)
func _act_just_pressed(a: String) -> bool:
	return InputMap.has_action(a) and Input.is_action_just_pressed(a)
func _act_just_released(a: String) -> bool:
	return InputMap.has_action(a) and Input.is_action_just_released(a)
