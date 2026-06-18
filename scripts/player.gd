extends CharacterBody2D
## PLAYER MOVEMENT CONTROLLER  (refined)
##
## Feel target  -> F.I.S.T.: Forged In Shadow Torch  (weighty but responsive,
##   momentum carries through dashes/jumps).
## System target -> Super Metroid / Metroid Dread  (open, sequence-break-friendly).
##
## ARCHITECTURE (keep these two rules):
##   1) Gate PHYSICALLY (geometry), never with invisible triggers.
##   2) Abilities are FLAT, INDEPENDENT FLAGS (has_dash, ...), never a linear
##      progress counter. Rooms/bosses read the flags and never assume order.
##
## CHANGES IN THIS REVISION:
##   - Responsiveness: higher accel + a TURN_BOOST so reversing feels instant.
##   - Wall grab is no longer sticky: you only cling while HOLDING the grab
##     button (reuses the "slide" action; grounded slide and airborne grab never
##     overlap). Default behavior is to slide off walls normally.
##   - Climb fixed: a short control lock after a wall jump lets the kick carry
##     you across the gap instead of being cancelled by held input.
##
## TUNING:
##   Quick-change feel  -> raise RUN_ACCEL and TURN_BOOST.
##   Heavier (F.I.S.T.) -> lower them and lower AIR_ACCEL.
##   Shaft climb        -> WALL_JUMP_CONTROL_LOCK (longer = kick carries farther)
##                         and WALL_JUMP_PUSH together cross the gap. A narrower
##                         shaft also helps.
##   Speed tech         -> the >>> MOMENTUM lines must never hard-zero velocity.

# --- Run ---
@export var max_run_speed := 240.0
@export var run_accel := 2600.0        # snappy ramp; lower for more weight
@export var ground_friction := 1800.0  # moderate: you still slide a little on release
@export var air_accel := 1800.0
@export var air_friction := 700.0
@export var turn_boost := 2.4          # accel multiplier when reversing direction

# --- Jump ---
@export var jump_velocity := -430.0
@export var jump_cut_multiplier := 0.45
@export var gravity := 1300.0
@export var fall_gravity := 1700.0     # heavier going down = weighty arc
@export var max_fall_speed := 720.0
@export var coyote_time := 0.10
@export var jump_buffer_time := 0.10

# --- Wall ---
@export var wall_slide_speed := 90.0          # fall speed WHILE gripping (hold grab)
@export var wall_grip_stick := 30.0           # gentle inward pull to hold contact
@export var wall_jump_push := 420.0           # horizontal kick off the wall
@export var wall_jump_velocity := -430.0
@export var wall_jump_control_lock := 0.16    # steering ignored this long after a wall jump

# --- Dash / Drill ---
@export var dash_speed := 480.0
@export var dash_time := 0.16
@export var dash_cooldown := 0.30
@export var dash_momentum_carry := 0.6        # >>> MOMENTUM: speed kept on dash exit

# --- Slide (grounded) ---
@export var slide_speed := 360.0
@export var slide_friction := 900.0
@export var slide_min_speed := 80.0

# --- Ability flags (flat & independent; granted by pickups anywhere) ---
@export var has_wall_jump := true
@export var has_dash := true
@export var has_double_jump := false
@export var has_slide := true

# --- Beam flags (the base beam is always available; these are upgrades) ---
@export var has_charge := false
@export var has_ice := false
@export var has_wave := false
@export var has_missiles := false

# Beam toggles (Super Metroid-style: suppress a part in the menu without losing it).
var charge_active := true
var ice_active := true
var wave_active := true

# --- Missiles ammo ---
@export var max_missiles := 15
var missiles: int = 0:
	set(value):
		missiles = clampi(value, 0, max_missiles)
		missiles_changed.emit(missiles, max_missiles)

# --- Health ---
@export var max_health := 99

signal died
signal health_changed(current, maximum)
signal missiles_changed(current, maximum)

# --- Hit / death feel ---
@export var knockback_force := 260.0
@export var hitstop_time := 0.06
@export var hit_shake := 6.0
@export var death_shake := 16.0
@export var flash_color := Color("#c2e35a")   # hemolymph: sickly green-yellow
@export var death_color := Color("#8fae3a")

# --- Internal state ---
var _coyote := 0.0
var _jump_buffer := 0.0
var _dash_timer := 0.0
var _dash_cd := 0.0
var _wall_jump_lock := 0.0
var _air_dash_used := false
var _double_jump_used := false
var _is_sliding := false
var _is_wall_sliding := false
var _facing := 1
var _iframes := 0.0
var _flash_t := 0.0
var _hit_lock := 0.0
var _dead := false
var _was_on_floor := false
var _shake = null
var health: int = 0:
	set(value):
		health = value
		health_changed.emit(health, max_health)


func _ready() -> void:
	collision_layer = 2          # Player layer, so your own beams pass through you
	add_to_group("player")       # so hostile (boss) projectiles can find you
	health = max_health
	# Auto-attach the base-beam cannon so shooting works without editing the scene.
	var has_weapon := false
	for c in get_children():
		if c is Weapon:
			has_weapon = true
	if not has_weapon:
		add_child(Weapon.new())
	# Attach the camera rig (lookahead + shake) to the camera.
	var cam := _find_camera()
	if cam != null:
		_shake = CameraRig.new()
		cam.add_child(_shake)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_update_feel(delta)

	var input_x := Input.get_axis("move_left", "move_right")
	if input_x > 0.0:
		_facing = 1
	elif input_x < 0.0:
		_facing = -1

	if Input.is_action_just_pressed("jump"):
		_jump_buffer = jump_buffer_time

	_update_timers(delta)

	if _dash_timer > 0.0:
		_process_dash()
	elif _is_sliding:
		_process_slide(delta)
	else:
		_process_normal(delta, input_x)

	move_and_slide()
	_post_move()


func _update_timers(delta: float) -> void:
	if _jump_buffer > 0.0:
		_jump_buffer -= delta
	if _dash_cd > 0.0:
		_dash_cd -= delta
	if _wall_jump_lock > 0.0:
		_wall_jump_lock -= delta
	if not is_on_floor() and _coyote > 0.0:
		_coyote -= delta
	if _dash_timer > 0.0:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			velocity.x = _facing * dash_speed * dash_momentum_carry   # >>> MOMENTUM


func _process_normal(delta: float, input_x: float) -> void:
	_apply_gravity(delta)
	_handle_horizontal(delta, input_x)
	_handle_wall()

	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier

	_try_jump()
	_try_dash()
	_try_slide()


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	var g := fall_gravity if velocity.y > 0.0 else gravity
	velocity.y = minf(velocity.y + g * delta, max_fall_speed)


func _handle_horizontal(delta: float, input_x: float) -> void:
	# After a wall jump, briefly ignore steering so the kick carries you across
	# the gap instead of being cancelled by held input. THIS is the climb fix.
	if _wall_jump_lock > 0.0 or _hit_lock > 0.0:
		return

	var on_floor := is_on_floor()
	var accel := run_accel if on_floor else air_accel
	var fric := ground_friction if on_floor else air_friction
	if input_x != 0.0:
		# Reversing direction -> stronger accel so quick changes feel instant.
		if signf(input_x) != signf(velocity.x) and velocity.x != 0.0:
			accel *= turn_boost
		velocity.x = move_toward(velocity.x, input_x * max_run_speed, accel * delta)
	else:
		# >>> MOMENTUM: friction only bleeds speed when you let go; never snaps to 0.
		velocity.x = move_toward(velocity.x, 0.0, fric * delta)


func _handle_wall() -> void:
	_is_wall_sliding = false
	if is_on_floor() or not is_on_wall_only():
		return
	# Cling ONLY while holding the grab button (same key as slide; grounded slide
	# and airborne grab never overlap). No auto-stick = not sticky.
	if Input.is_action_pressed("slide") and velocity.y > 0.0:
		_is_wall_sliding = true
		velocity.y = minf(velocity.y, wall_slide_speed)
		# Light inward pull so contact holds even without pressing toward the wall.
		velocity.x = -get_wall_normal().x * wall_grip_stick


func _try_jump() -> void:
	if _jump_buffer <= 0.0:
		return

	# Ground / coyote jump.
	if is_on_floor() or _coyote > 0.0:
		velocity.y = jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0
		Audio.play("jump")
		return

	# Wall jump - works on ANY wall, available whether or not you're gripping.
	if has_wall_jump and is_on_wall_only():
		var n := get_wall_normal()
		velocity.x = n.x * wall_jump_push
		velocity.y = wall_jump_velocity
		_facing = 1 if n.x > 0.0 else -1          # face away from the wall
		_wall_jump_lock = wall_jump_control_lock  # let the kick carry (climb fix)
		_jump_buffer = 0.0
		_double_jump_used = false                 # touching a wall refreshes air options
		_air_dash_used = false
		Audio.play("wall_jump")
		return

	# Double jump - flag-gated.
	if has_double_jump and not _double_jump_used:
		velocity.y = jump_velocity
		_double_jump_used = true
		_jump_buffer = 0.0
		Audio.play("double_jump")


func _try_dash() -> void:
	if not has_dash or _dash_cd > 0.0:
		return
	if Input.is_action_just_pressed("dash"):
		if is_on_floor() or not _air_dash_used:
			_dash_timer = dash_time
			_dash_cd = dash_cooldown
			if not is_on_floor():
				_air_dash_used = true
			Audio.play("dash")


func _process_dash() -> void:
	velocity.x = _facing * dash_speed
	velocity.y = 0.0


func _try_slide() -> void:
	if not has_slide or not is_on_floor():
		return
	if Input.is_action_just_pressed("slide") and absf(velocity.x) > slide_min_speed:
		_is_sliding = true
		velocity.x = _facing * slide_speed
		# $StandShape.disabled = true
		# $SlideShape.disabled = false


func _process_slide(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, slide_friction * delta)
	_try_jump()
	if absf(velocity.x) < slide_min_speed or not is_on_floor() or Input.is_action_just_released("slide"):
		_is_sliding = false
		# $StandShape.disabled = false
		# $SlideShape.disabled = true


func _post_move() -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		Audio.play("land")
	_was_on_floor = on_floor
	if on_floor:
		_coyote = coyote_time
		_air_dash_used = false
		_double_jump_used = false


# Aim direction source for the weapon (matches the sprite flip).
func get_facing() -> int:
	return _facing


func take_damage(amount: int, from_pos = null) -> void:
	if _iframes > 0.0 or _dead:
		return
	health -= amount                 # emits health_changed
	_iframes = 1.0
	_flash_t = 0.12
	_hit_lock = 0.16
	if from_pos != null:
		var dir := signf((global_position - from_pos).x)
		if dir == 0.0:
			dir = -float(_facing)
		velocity.x = dir * knockback_force
		velocity.y = -knockback_force * 0.5
	if health <= 0:
		await _die()
		return
	if _shake != null:
		_shake.shake(hit_shake, 0.25)
	Audio.play("hurt")
	await _do_hitstop(hitstop_time)


func _die() -> void:
	_dead = true
	velocity = Vector2.ZERO
	modulate = death_color
	Audio.play("die")
	if _shake != null:
		_shake.shake(death_shake, 0.5)
	await _do_hitstop(0.12)
	await get_tree().create_timer(0.35, true, false, true).timeout
	health = max_health              # emits
	if has_missiles:
		missiles = max_missiles      # emits
	modulate = Color(1, 1, 1, 1)
	_iframes = 1.0
	_dead = false
	died.emit()                      # the level catches this to respawn you


func _do_hitstop(d: float) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(d, true, false, true).timeout   # real-time wait
	Engine.time_scale = 1.0


func _update_feel(delta: float) -> void:
	if _hit_lock > 0.0:
		_hit_lock -= delta
	if _iframes > 0.0:
		_iframes -= delta
	if _flash_t > 0.0:
		_flash_t -= delta
		modulate = flash_color
	elif _iframes > 0.0:
		modulate = Color(1, 1, 1, 0.5 if int(_iframes * 20.0) % 2 == 0 else 1.0)
	else:
		modulate = Color(1, 1, 1, 1)


func _find_camera() -> Camera2D:
	for c in get_children():
		if c is Camera2D:
			return c
	return null      # the level catches this to respawn you


# ===========================================================================
# SETUP
#   Scene:  CharacterBody2D (this script) > CollisionShape2D (capsule) > Sprite2D > Camera2D
#   Input Map actions: move_left, move_right, jump, dash, slide
#     NOTE: "slide" now does double duty - tap on the ground to slide, HOLD it
#     against a wall in the air to grip/cling. No separate action needed.
# ===========================================================================
