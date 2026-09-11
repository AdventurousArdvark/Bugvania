extends CharacterBody2D
class_name ApexGantry
## THE OXIDE WASTES' apex — THE GANTRY-THING. A lab servicing-rig that never got shut
## off: a bolted crane-frame that dragged itself off its rails and learned to hunt. It
## SWEEPS a claw across the floor and STOMPS with the whole frame (shockwave + shake).
## Beatable with the base beam and footwork — everything is telegraphed. On death it
## sheds its CHARGE GLAND (charge beam) and frees the region.
##
## Boss contract (matches the others so the HUD bar + music switch work):
##   groups "enemy" (beams hit it) + "boss" (HUD binds, level wakes it)
##   signals health_changed / engaged / disengaged / cleared
##   engage() ; take_damage(amount, _props)

signal health_changed(current, maximum)
signal engaged
signal disengaged
signal cleared

@export var max_health: int = 52
@export var track_speed: float = 60.0
@export var sweep_speed: float = 300.0
@export var gravity: float = 1500.0

const GRAFT := "has_charge"

enum St { SLEEP, IDLE, TELL, SWEEP, STOMP_TELL, STOMP, RECOVER, DEAD }

var size := Vector2(76, 60)
var health: int
var _state: int = St.SLEEP
var _t: float = 0.0
var _face: float = -1.0
var _flash: float = 0.0
var _started := false
var _player: Node2D = null
var _floor_y: float = 0.0
var _visual: Node2D = null
var _hitbox: Area2D = null

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	collision_layer = 4
	collision_mask = 1
	health = max_health
	_floor_y = global_position.y
	var col := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = size
	col.shape = rs
	add_child(col)
	_hitbox = Area2D.new()
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = 2
	add_child(_hitbox)
	var hc := CollisionShape2D.new()
	var hrs := RectangleShape2D.new()
	hrs.size = size * 1.05
	hc.shape = hrs
	_hitbox.add_child(hc)
	_hitbox.body_entered.connect(_on_touch)
	_visual = _GantryVisual.new()
	_visual.host = self
	add_child(_visual)

func engage() -> void:
	if _started or _state == St.DEAD:
		return
	_started = true
	_state = St.IDLE
	_t = 0.0
	engaged.emit()
	health_changed.emit(health, max_health)
	get_tree().call_group("game", "boss_intro", "THE GANTRY-THING")

func _physics_process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
	if _state == St.SLEEP or _state == St.DEAD:
		return
	_player = get_tree().get_first_node_in_group("player")
	_t += delta

	match _state:
		St.IDLE:
			_apply_gravity(delta)
			_face_player()
			if _player != null:
				var tx: float = (_player as Node2D).global_position.x
				velocity.x = signf(tx - global_position.x) * track_speed
			if _t > 0.9:
				# Alternate between the two telegraphed attacks; STOMP if the player is close.
				var close := _player != null and absf((_player as Node2D).global_position.x - global_position.x) < 120.0
				_set_state(St.STOMP_TELL if close else St.TELL)
		St.TELL:
			_apply_gravity(delta)
			velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
			if _t > 0.5:
				_set_state(St.SWEEP)
		St.SWEEP:
			_apply_gravity(delta)
			velocity.x = _face * sweep_speed
			if _t > 0.55 or is_on_wall():
				_set_state(St.RECOVER)
		St.STOMP_TELL:
			_apply_gravity(delta)
			velocity.x = 0.0
			if _t > 0.45:
				velocity.y = -420.0                 # heave the frame up
				_set_state(St.STOMP)
		St.STOMP:
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
			velocity.y = minf(velocity.y + gravity * 1.6 * delta, 1400.0)
			if is_on_floor() and _t > 0.1:
				get_tree().call_group("camera_rig", "shake", 9.0, 0.35)
				get_tree().call_group("game", "hitstop", 0.05)
				_set_state(St.RECOVER)
		St.RECOVER:
			_apply_gravity(delta)
			velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
			if _t > 0.6:
				_set_state(St.IDLE)
	move_and_slide()

func _set_state(s: int) -> void:
	_state = s
	_t = 0.0

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, 1000.0)

func _face_player() -> void:
	if _player != null:
		_face = signf((_player as Node2D).global_position.x - global_position.x)
		if _face == 0.0:
			_face = -1.0

func take_damage(amount: int, _props: Dictionary = {}) -> void:
	if _state == St.DEAD or _state == St.SLEEP:
		return
	health -= amount
	_flash = 0.1
	health_changed.emit(maxi(health, 0), max_health)
	get_tree().call_group("game", "hitstop", 0.04)
	if health <= 0:
		_die()

func _on_touch(body: Node) -> void:
	if _state == St.DEAD:
		return
	if body.has_method("take_damage") and body.is_in_group("player"):
		body.take_damage(2, global_position)

func _die() -> void:
	_state = St.DEAD
	disengaged.emit()
	health_changed.emit(0, max_health)
	if _hitbox != null:
		_hitbox.set_deferred("monitoring", false)
	get_tree().call_group("camera_rig", "shake", 12.0, 0.5)
	var p := get_tree().get_first_node_in_group("player")
	if p != null and p.has_method("harvest"):
		p.harvest(GRAFT)
	cleared.emit()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.8)
	tw.parallel().tween_property(self, "scale", Vector2(1.06, 0.7), 0.8)
	tw.tween_callback(queue_free)


# --- procedural grey-box visual (cosmetic; collision above is authoritative) ---
class _GantryVisual extends Node2D:
	var host: ApexGantry

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if host == null:
			return
		var s := host.size
		var hw := s.x * 0.5
		var hh := s.y * 0.5
		var body_col := Color(0.20, 0.16, 0.12)
		if host._flash > 0.0:
			body_col = Color(0.95, 0.7, 0.45)
		# Bolted frame body.
		draw_rect(Rect2(-hw, -hh, s.x, s.y), body_col)
		var strut := Color(0.30, 0.24, 0.16)
		draw_rect(Rect2(-hw, -hh, s.x, 8.0), strut)          # top rail
		draw_rect(Rect2(-hw, hh - 8.0, s.x, 8.0), strut)     # bottom rail
		# Rivets.
		for i in 4:
			var rx := -hw + 8.0 + float(i) * (s.x - 16.0) / 3.0
			draw_circle(Vector2(rx, -hh + 4.0), 2.0, Color(0.5, 0.42, 0.3))
			draw_circle(Vector2(rx, hh - 4.0), 2.0, Color(0.5, 0.42, 0.3))
		# The claw hangs on the facing side; it juts out during a sweep tell/sweep.
		var reach := 10.0
		if host._state == St.TELL:
			reach = 10.0 + 14.0 * sin(host._t * 20.0)
		elif host._state == St.SWEEP:
			reach = 26.0
		var cx := host._face * (hw + reach)
		var claw := Color(0.42, 0.34, 0.22)
		draw_line(Vector2(host._face * hw, 0.0), Vector2(cx, hh * 0.6), claw, 6.0)
		draw_line(Vector2(cx, hh * 0.6), Vector2(cx + host._face * 10.0, hh * 0.2), claw, 5.0)
		# Single hunting eye — flares while winding up.
		var glow := 0.45
		if host._state == St.TELL or host._state == St.STOMP_TELL:
			glow = 0.6 + 0.4 * sin(host._t * 26.0)
		draw_circle(Vector2(host._face * hw * 0.4, -hh * 0.2), 6.0,
			Color(0.95, 0.55, 0.2, glow))
