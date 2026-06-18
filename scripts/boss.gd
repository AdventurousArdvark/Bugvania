extends CharacterBody2D
class_name Boss
## The demo climax: a large bug. Readable, fair, and built to show off the kit.
##   - Telegraphed LUNGE (windup flash -> dash across the arena -> vulnerable recover).
##   - Phase 2 (under 60% HP): adds a projectile VOLLEY and speeds up.
## Takes beam/missile damage anytime; the recover window is the safe time to hit it.
## In group "enemy" (so your beams damage it) and "boss" (so the HUD shows its bar).

enum St { DORMANT, INTRO, IDLE, WINDUP, LUNGE, RECOVER, VOLLEY, DEAD }

@export var max_health: int = 40
@export var lunge_speed: float = 420.0
@export var lunge_windup: float = 0.55
@export var recover_time: float = 1.15
@export var idle_time: float = 0.7
@export var contact_damage: int = 20
@export var size: Vector2 = Vector2(64, 44)
@export var color: Color = Color("#7a3b8f")

signal health_changed(current, maximum)
signal engaged

var health: int
var _state: int = St.DORMANT
var _t: float = 0.6
var _dir: int = -1
var _phase2: bool = false
var _gravity: float = 1300.0
var _player: Node = null
var _hitbox: Area2D = null

func _ready() -> void:
	health = max_health
	add_to_group("enemy")
	add_to_group("boss")
	collision_layer = 4
	collision_mask = 1
	if get_child_count() == 0:
		_build()

func _build() -> void:
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	add_child(cs)
	var hw := size.x * 0.5
	var hh := size.y * 0.5
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh),
	])
	poly.color = color
	poly.name = "Body"
	add_child(poly)
	_hitbox = Area2D.new()
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = 2          # the player
	add_child(_hitbox)
	var hcs := CollisionShape2D.new()
	var hr := RectangleShape2D.new()
	hr.size = size
	hcs.shape = hr
	_hitbox.add_child(hcs)
	_hitbox.body_entered.connect(_on_contact)

func _physics_process(delta: float) -> void:
	if _state == St.DEAD:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")

	velocity.y = 0.0 if is_on_floor() else velocity.y + _gravity * delta
	_t -= delta

	match _state:
		St.DORMANT:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		St.INTRO:
			velocity.x = 0.0
			if _t <= 0.0:
				_to_idle()
		St.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			_face_player()
			if _t <= 0.0:
				if _phase2 and randf() < 0.5:
					_state = St.VOLLEY
					_t = lunge_windup
					modulate = Color("#ffd0d0")    # telegraph
				else:
					_state = St.WINDUP
					_t = lunge_windup
					modulate = Color("#ffd0d0")
		St.WINDUP:
			velocity.x = 0.0
			if _t <= 0.0:
				_face_player()
				modulate = Color.WHITE
				_state = St.LUNGE
				_t = 1.2
		St.LUNGE:
			velocity.x = _dir * lunge_speed
			if is_on_wall() or _t <= 0.0:
				velocity.x = 0.0
				_state = St.RECOVER
				_t = recover_time
				modulate = Color("#c7b3d6")        # vulnerable tint
		St.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
			if _t <= 0.0:
				modulate = Color.WHITE
				_to_idle()
		St.VOLLEY:
			velocity.x = 0.0
			if _t <= 0.0:
				_fire_volley()
				modulate = Color.WHITE
				_state = St.RECOVER
				_t = recover_time

	move_and_slide()

func _to_idle() -> void:
	_state = St.IDLE
	_t = idle_time * (0.65 if _phase2 else 1.0)

func engage() -> void:
	if _state == St.DORMANT:
		_state = St.INTRO
		_t = 0.8
		engaged.emit()

func _face_player() -> void:
	if _player != null:
		_dir = -1 if _player.global_position.x < global_position.x else 1

func _fire_volley() -> void:
	if _player == null:
		return
	var world := get_parent()
	var base : Vector2 = (_player.global_position - global_position).normalized()
	for ang in [-18.0, 0.0, 18.0]:
		var dir := base.rotated(deg_to_rad(ang))
		var proj := Projectile.new()
		world.add_child(proj)
		proj.setup(global_position + dir * (size.x * 0.5 + 8.0), dir, {
			"speed": 240.0, "damage": 12, "size": 9.0,
			"color": Color("#ff5d73"), "lifetime": 2.5, "hostile": true, "element": "",
		})

func take_damage(amount: int, _props: Dictionary = {}) -> void:
	if _state == St.DEAD:
		return
	health -= amount
	Audio.play("boss_hit")
	health_changed.emit(health, max_health)
	if not _phase2 and health <= int(max_health * 0.6):
		_phase2 = true
		get_tree().call_group("camera_rig", "shake", 10.0, 0.4)
	if health <= 0:
		_die()

func _die() -> void:
	_state = St.DEAD
	velocity = Vector2.ZERO
	if _hitbox != null:
		_hitbox.monitoring = false
	Audio.play("boss_die")
	get_tree().call_group("camera_rig", "shake", 18.0, 0.8)
	Fx.burst(get_parent(), global_position, color, 22, 240.0)
	health_changed.emit(0, max_health)
	_finish()

func _finish() -> void:
	await get_tree().create_timer(0.9, true, false, true).timeout
	get_tree().call_group("game", "show_complete")
	queue_free()

func _on_contact(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(contact_damage, global_position)
