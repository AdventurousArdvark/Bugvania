extends CharacterBody2D
class_name ApexBurrower
## The Hollow Mouth's apex. A heavy mandibled thing that burrows and erupts. It is
## beatable with the base beam and footwork alone (you don't have its gift yet) —
## telegraphed lunges, brief invulnerable burrows to reposition behind you. On
## death it grants its graft (Grip-Claws / wall-grip) and frees the region.
##
## Boss contract (matches the others so the HUD bar + music switch work):
##   groups "enemy" (beams hit it) + "boss" (HUD binds, level wakes it)
##   signals health_changed / engaged / disengaged
##   take_damage(amount, _props)

signal health_changed(current, maximum)
signal engaged
signal disengaged
signal cleared            # the region listens: harvest + banner + open the way

@export var max_health: int = 44
@export var move_speed: float = 70.0
@export var lunge_speed: float = 360.0
@export var gravity: float = 1500.0

const GRAFT := "has_wall_jump"

enum St { SLEEP, IDLE, TELL, LUNGE, BURROW, RISE, DEAD }

var size := Vector2(64, 52)
var health: int
var _state: int = St.SLEEP
var _t: float = 0.0
var _face: float = -1.0
var _flash: float = 0.0
var _started := false
var _player: Node2D = null
var _surface_y: float = 0.0
var _visual: Node2D = null
var _hitbox: Area2D = null

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	collision_layer = 4
	collision_mask = 1
	health = max_health
	_surface_y = global_position.y
	var col := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = size
	col.shape = rs
	add_child(col)
	# Contact hitbox that hurts the player.
	_hitbox = Area2D.new()
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = 2
	add_child(_hitbox)
	var hc := CollisionShape2D.new()
	var hrs := RectangleShape2D.new()
	hrs.size = size * 1.04
	hc.shape = hrs
	_hitbox.add_child(hc)
	_hitbox.body_entered.connect(_on_touch)
	_visual = _BurrowerVisual.new()
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
	get_tree().call_group("game", "boss_intro", "THE BURROWER")

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
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			_face_player()
			if _t > 0.6:
				_set_state(St.TELL)
		St.TELL:
			_apply_gravity(delta)
			velocity.x = 0.0
			if _t > 0.45:
				_set_state(St.LUNGE)         # commit a telegraphed lunge
		St.LUNGE:
			_apply_gravity(delta)
			velocity.x = _face * lunge_speed
			if _t > 0.5 or is_on_wall():
				_set_state(St.BURROW)
		St.BURROW:
			# Sink and become untouchable, glide toward a spot near the player.
			velocity = Vector2.ZERO
			global_position.y = lerpf(global_position.y, _surface_y + size.y, minf(1.0, _t * 4.0))
			if _player != null and _t > 0.25:
				var tx: float = (_player as Node2D).global_position.x - _face * 120.0
				global_position.x = move_toward(global_position.x, tx, move_speed * 3.0 * delta)
			if _t > 1.1:
				_set_state(St.RISE)
		St.RISE:
			global_position.y = lerpf(global_position.y, _surface_y, minf(1.0, _t * 5.0))
			if _t > 0.35:
				global_position.y = _surface_y
				_face_player()
				_set_state(St.IDLE)
	move_and_slide()

func _set_state(s: int) -> void:
	_state = s
	_t = 0.0

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, 900.0)

func _face_player() -> void:
	if _player != null:
		_face = signf((_player as Node2D).global_position.x - global_position.x)
		if _face == 0.0:
			_face = -1.0

func is_burrowed() -> bool:
	return _state == St.BURROW or _state == St.RISE

func take_damage(amount: int, _props: Dictionary = {}) -> void:
	if _state == St.DEAD or _state == St.SLEEP or is_burrowed():
		return                                  # untouchable underground
	health -= amount
	_flash = 0.1
	health_changed.emit(maxi(health, 0), max_health)
	get_tree().call_group("game", "hitstop", 0.05)
	if health <= 0:
		_die()

func _on_touch(body: Node) -> void:
	if is_burrowed() or _state == St.DEAD:
		return
	if body.has_method("take_damage") and body.is_in_group("player"):
		body.take_damage(2, global_position)

func _die() -> void:
	_state = St.DEAD
	disengaged.emit()
	health_changed.emit(0, max_health)
	if _hitbox != null:
		_hitbox.set_deferred("monitoring", false)
	# Grant the graft and free the region.
	var p := get_tree().get_first_node_in_group("player")
	if p != null and p.has_method("harvest"):
		p.harvest(GRAFT)
	cleared.emit()
	# Dissolve.
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.8)
	tw.parallel().tween_property(self, "scale", Vector2(1.1, 0.6), 0.8)
	tw.tween_callback(queue_free)


# --- procedural grey-box visual (cosmetic; collision above is authoritative) ---
class _BurrowerVisual extends Node2D:
	var host: ApexBurrower

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if host == null:
			return
		var s := host.size
		var bury := 0.0
		if host.is_burrowed():
			bury = 0.7
		var body_col := Color(0.16, 0.13, 0.11)
		if host._flash > 0.0:
			body_col = Color(0.9, 0.6, 0.5)
		# carapace
		var hw := s.x * 0.5
		var hh := s.y * 0.5 * (1.0 - bury)
		draw_rect(Rect2(-hw, -hh, s.x, hh + s.y * 0.5), body_col)
		if bury > 0.3:
			return
		# mandibles up front
		var fx := host._face * hw
		var mand := Color(0.32, 0.26, 0.2)
		draw_line(Vector2(fx, -hh * 0.2), Vector2(fx + host._face * 22.0, -hh * 0.9), mand, 5.0)
		draw_line(Vector2(fx, hh * 0.4), Vector2(fx + host._face * 22.0, hh * 0.2), mand, 5.0)
		# eyes — flare during the tell
		var glow := 0.4
		if host._state == St.TELL:
			glow = 0.6 + 0.4 * sin(host._t * 30.0)
		var ec := Color(0.9, 0.3, 0.25, glow)
		draw_circle(Vector2(fx - host._face * 12.0, -hh * 0.3), 4.0, ec)
		draw_circle(Vector2(fx - host._face * 22.0, -hh * 0.3), 4.0, ec)
