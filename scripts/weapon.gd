extends Node2D
class_name Weapon
## The cannon. Attach as a child of the player (player.gd auto-creates one).
##
## Responsibilities:
##   - Read an 8-DIRECTIONAL aim from existing inputs (move_left/right/up/down + facing).
##   - Fire on the "attack" input. Tap = normal shot. Hold to full + release = charged.
##   - Compose the shot's stats from whichever beam FLAGS the player owns
##     (has_charge now; has_ice / has_wave / ... plug in the same way later).
##
## The aim is produced as a DIRECTION VECTOR. Everything downstream consumes the
## vector and doesn't care how it was made -> swapping to free aim later only
## means rewriting _aim_dir(), nothing else.

@export var projectile_speed: float = 460.0
@export var base_damage: int = 1
@export var charged_damage: int = 4
@export var charge_time: float = 0.6      # hold this long for a charged shot
@export var fire_cooldown: float = 0.18   # min time between normal shots
@export var muzzle_offset: float = 14.0

var _player: Node = null
var _cooldown: float = 0.0
var _charging: bool = false
var _charge_t: float = 0.0

func _ready() -> void:
	var p := get_parent()
	if p is CharacterBody2D:
		_player = p

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta

	var can_charge : bool = _player != null and _player.get("has_charge") == true

	if _act_just_pressed("attack"):
		_fire(false)            # immediate normal shot on press
		_charging = true
		_charge_t = 0.0

	if _charging and can_charge:
		_charge_t += delta

	if _act_just_released("attack"):
		if _charging and can_charge and _charge_t >= charge_time:
			_fire(true)         # charged shot on release
		_charging = false

func _fire(charged: bool) -> void:
	if not charged and _cooldown > 0.0:
		return
	if _player == null:
		return
	var dir := _aim_dir()
	var world := _player.get_parent()
	if world == null:
		world = _player
	var proj := Projectile.new()
	world.add_child(proj)
	var muzzle := (_player as Node2D).global_position + Vector2(0, -8) + dir * muzzle_offset
	proj.setup(muzzle, dir, _make_stats(charged))
	if not charged:
		_cooldown = fire_cooldown

# 8-directional aim from held inputs; defaults to the player's facing.
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

# Build the shot's stats from the player's beam flags. THIS is the upgrade hub:
# every future beam upgrade adds a branch here that tweaks the same dictionary.
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
	# --- Future beam upgrades (flat flags on the player) ---
	if _player != null and _player.get("has_ice") == true:
		s.element = "ice"
		s.color = Color("#bfe9ff")
	if _player != null and _player.get("has_wave") == true:
		s.pierce = true        # Wave passes through walls and enemies
	return s

# Action helpers that won't error if an action isn't in the Input Map yet.
func _act_pressed(a: String) -> bool:
	return InputMap.has_action(a) and Input.is_action_pressed(a)
func _act_just_pressed(a: String) -> bool:
	return InputMap.has_action(a) and Input.is_action_just_pressed(a)
func _act_just_released(a: String) -> bool:
	return InputMap.has_action(a) and Input.is_action_just_released(a)
