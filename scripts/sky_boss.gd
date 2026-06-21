extends CharacterBody2D
class_name SkyBoss
## THE BROODMOTHER ASCENDANT — the surface finale. She erupts from the hive after
## the escape and fights in two phases, shown as two HP bars:
##   PHASE 1 (ground): telegraphed lunges, like the hive fight.
##   PHASE 2 (flying): once the first bar empties she takes to the air (gravity off),
##     the bar refills, and she gains a SUSTAINED BEAM special — a ~2s raking beam
##     that tracks slightly, telegraphed by a charge glow.
## In groups "enemy" (your beams hurt her) and "boss" (HUD shows her bar).

enum St { INTRO, G_IDLE, G_WINDUP, G_LUNGE, G_RECOVER, TRANSITION,
	F_IDLE, F_SWOOP, BEAM_CHARGE, BEAM_FIRE, BEAM_RECOVER, DEAD }

signal health_changed(current, maximum)
signal engaged
signal phase_changed(phase)

@export var ground_health: int = 50
@export var fly_health: int = 90
@export var lunge_speed: float = 460.0
@export var lunge_windup: float = 0.5
@export var recover_time: float = 1.0
@export var idle_time: float = 0.7
@export var swoop_speed: float = 540.0
@export var swoop_time: float = 0.7
@export var beam_charge_time: float = 0.9
@export var beam_fire_time: float = 2.0
@export var beam_recover_time: float = 1.2
@export var beam_len: float = 760.0
@export var beam_damage: int = 10
@export var beam_halfwidth: float = 28.0
@export var contact_damage: int = 18
@export var size: Vector2 = Vector2(72, 52)
@export var color: Color = Color("#7a3b8f")
@export var boss_name: String = "THE BROODMOTHER ASCENDANT"
@export var hover_y: float = 0.0          # arena sets this; 0 = auto on transition

var max_health: int = 1
var health: int = 1:
	set(value):
		health = clampi(value, 0, max_health)
		health_changed.emit(health, max_health)

var _state: int = St.INTRO
var _t: float = 1.2
var _dir: int = -1
var _phase: int = 1
var _gravity: float = 1300.0
var _player: Node = null
var _hitbox: Area2D = null
var _visual: Node2D = null
var _beam_dir: Vector2 = Vector2.LEFT
var _beam_charge: float = 0.0
var _beam_on: bool = false
var _swoop_vel: Vector2 = Vector2.ZERO
var _started: bool = false

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	collision_layer = 4
	collision_mask = 1
	max_health = ground_health
	health = ground_health
	_build()

func _build() -> void:
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	add_child(cs)
	var bv := BossVisual.new()
	bv.name = "Body"
	bv.base_color = color
	bv.box = size
	bv.face = _dir
	_visual = bv
	add_child(_visual)
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

func engage() -> void:
	if _started:
		return
	_started = true
	_state = St.INTRO
	_t = 1.6
	engaged.emit()
	get_tree().call_group("game", "boss_intro", boss_name)
	get_tree().call_group("camera_rig", "punch", 1.12, 0.7)
	Audio.play("boss_roar")
	Rumble.pulse(0.6, 0.8, 0.5)

func _physics_process(delta: float) -> void:
	if _state == St.DEAD:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	_t -= delta

	var grounded := _phase == 1
	if grounded:
		velocity.y = 0.0 if is_on_floor() else velocity.y + _gravity * delta

	_feed_visual()

	match _state:
		St.INTRO:
			velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
			_face_player()
			if _t <= 0.0:
				_state = St.G_IDLE
				_t = idle_time
		St.G_IDLE:
			velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
			_face_player()
			if _t <= 0.0:
				_state = St.G_WINDUP
				_t = lunge_windup
				modulate = Color("#ffd0d0")
		St.G_WINDUP:
			velocity.x = 0.0
			if _t <= 0.0:
				modulate = Color.WHITE
				_state = St.G_LUNGE
				_t = 0.55
				velocity.x = float(_dir) * lunge_speed
				Audio.play("boss_roar")
		St.G_LUNGE:
			if is_on_wall() or _t <= 0.0:
				_state = St.G_RECOVER
				_t = recover_time
		St.G_RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if _t <= 0.0:
				_state = St.G_IDLE
				_t = idle_time
		St.TRANSITION:
			velocity = velocity.move_toward(Vector2(0.0, -180.0), 900.0 * delta)
			if global_position.y <= hover_y + 8.0:
				velocity = Vector2.ZERO
				_state = St.F_IDLE
				_t = idle_time
		St.F_IDLE:
			_hover(delta)
			_face_player()
			if _t <= 0.0:
				if _beam_ready():
					_state = St.BEAM_CHARGE
					_t = beam_charge_time
					Audio.play("charge")
				else:
					_begin_swoop()
		St.F_SWOOP:
			velocity = _swoop_vel
			if _t <= 0.0:
				_state = St.F_IDLE
				_t = idle_time
		St.BEAM_CHARGE:
			_hover(delta * 0.4)
			_face_player()
			_beam_charge = clampf(1.0 - _t / beam_charge_time, 0.0, 1.0)
			if _t <= 0.0:
				_beam_dir = _aim_dir()
				_dir = -1 if _beam_dir.x < 0.0 else 1
				_beam_on = true
				_beam_charge = 1.0
				_state = St.BEAM_FIRE
				_t = beam_fire_time
				Audio.play("boss_roar")
				get_tree().call_group("camera_rig", "shake", 3.0, beam_fire_time)
		St.BEAM_FIRE:
			velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
			# Beam tracks the player slowly so it's threatening but dodgeable.
			_beam_dir = _beam_dir.slerp(_aim_dir(), clampf(delta * 0.7, 0.0, 1.0))
			_dir = -1 if _beam_dir.x < 0.0 else 1
			_damage_along_beam()
			if _t <= 0.0:
				_beam_on = false
				_beam_charge = 0.0
				_state = St.BEAM_RECOVER
				_t = beam_recover_time
		St.BEAM_RECOVER:
			_hover(delta)
			if _t <= 0.0:
				_state = St.F_IDLE
				_t = idle_time

	move_and_slide()

func _hover(delta: float) -> void:
	# Drift toward the player's x, bob gently around the hover line.
	var target_x := global_position.x
	if _player != null:
		target_x = (_player as Node2D).global_position.x
	var vx := clampf((target_x - global_position.x) * 2.0, -140.0, 140.0)
	var bob := sin(Time.get_ticks_msec() * 0.002) * 30.0
	var vy := (hover_y + bob - global_position.y) * 2.0
	velocity = velocity.move_toward(Vector2(vx, vy), 600.0 * delta)

func _begin_swoop() -> void:
	_state = St.F_SWOOP
	_t = swoop_time
	var dir := Vector2.DOWN
	if _player != null:
		dir = ((_player as Node2D).global_position - global_position).normalized()
	_swoop_vel = dir * swoop_speed
	_dir = -1 if dir.x < 0.0 else 1
	Audio.play("boss_roar")

var _beam_toggle: bool = false
func _beam_ready() -> bool:
	_beam_toggle = not _beam_toggle
	return _beam_toggle          # alternate swoop / beam

func _aim_dir() -> Vector2:
	if _player == null:
		return Vector2(float(_dir), 0.0)
	return ((_player as Node2D).global_position - _muzzle()).normalized()

func _muzzle() -> Vector2:
	return global_position + Vector2(float(_dir) * size.x * 0.5, -size.y * 0.2)

func _damage_along_beam() -> void:
	if _player == null:
		return
	var rel: Vector2 = (_player as Node2D).global_position - _muzzle()
	var along := rel.dot(_beam_dir)
	if along < 0.0 or along > beam_len:
		return
	var perp := absf(rel.dot(Vector2(-_beam_dir.y, _beam_dir.x)))
	if perp <= beam_halfwidth and _player.has_method("take_damage"):
		_player.take_damage(beam_damage, global_position)

func _face_player() -> void:
	if _player != null:
		_dir = -1 if (_player as Node2D).global_position.x < global_position.x else 1

func _feed_visual() -> void:
	if not _visual is BossVisual:
		return
	var bv := _visual as BossVisual
	bv.phase2 = _phase >= 2
	bv.flying = _phase >= 2
	bv.face = _dir
	bv.beam_from = Vector2(float(_dir) * size.x * 0.5, -size.y * 0.2)
	bv.beam_dir = _beam_dir
	bv.beam_len = beam_len
	bv.beam_charge = _beam_charge
	bv.beam_on = _beam_on
	match _state:
		St.G_WINDUP, St.BEAM_CHARGE: bv.pose = "windup"
		St.G_LUNGE, St.F_SWOOP:      bv.pose = "lunge"
		St.BEAM_FIRE:                bv.pose = "volley"
		St.G_RECOVER:                bv.pose = "stagger"
		_:                           bv.pose = "idle"

func take_damage(amount: int, _props: Dictionary = {}) -> void:
	if _state == St.DEAD or _state == St.TRANSITION:
		return
	health -= amount
	get_tree().call_group("game", "hitstop", clampf(0.02 + float(amount) * 0.004, 0.02, 0.1))
	if health <= 0:
		if _phase == 1:
			_to_flight()
		else:
			_die()

func _to_flight() -> void:
	_phase = 2
	_state = St.TRANSITION
	if hover_y == 0.0:
		hover_y = global_position.y - 140.0
	max_health = fly_health
	health = fly_health                 # emits -> HUD bar refills (the "second bar")
	phase_changed.emit(2)
	modulate = Color.WHITE
	Audio.play("boss_roar")
	get_tree().call_group("camera_rig", "punch", 1.18, 0.9)
	Rumble.pulse(0.7, 0.9, 0.6)

func _die() -> void:
	_state = St.DEAD
	_beam_on = false
	velocity = Vector2.ZERO
	if _hitbox != null:
		_hitbox.monitoring = false
	get_tree().call_group("game", "hitstop", 0.35)
	get_tree().call_group("camera_rig", "shake", 6.0, 0.6)
	Audio.play("boss_roar")
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 1.4)
	tw.tween_callback(func() -> void:
		get_tree().call_group("game", "show_end", "DAYBREAK")
	)

func _on_contact(body: Node) -> void:
	if _state == St.DEAD:
		return
	if body.has_method("take_damage"):
		body.take_damage(contact_damage, global_position)
