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
@export var air_max_speed := 200.0      # SMASH: lower active air speed -> you drift, not dart
@export var run_accel := 2600.0        # snappy ramp; lower for more weight
@export var ground_friction := 1800.0  # moderate: you still slide a little on release
@export var air_accel := 1500.0         # SMASH: gentle air steering
@export var air_friction := 360.0       # SMASH: low drag -> momentum carries through the air
@export var turn_boost := 2.4          # accel multiplier when reversing direction

# --- Jump ---
@export var jump_velocity := -430.0
@export var short_hop_velocity := -270.0   # SMASH: tap = short hop, hold = full hop
@export var jump_cut_multiplier := 0.45
@export var gravity := 1300.0
@export var fall_gravity := 1700.0     # heavier going down = weighty arc
@export var max_fall_speed := 720.0
@export var fast_fall_speed := 1080.0  # SMASH: tap down while falling to drop fast
@export var coyote_time := 0.10
@export var jump_buffer_time := 0.10

# --- Wall ---
@export var wall_slide_speed := 90.0          # fall speed WHILE gripping (hold grab)
@export var wall_grip_stick := 30.0           # gentle inward pull to hold contact
@export var wall_jump_push := 420.0           # horizontal kick off the wall
@export var wall_jump_velocity := -430.0
@export var wall_jump_control_lock := 0.10    # brief full-ignore pop right off the wall
@export var wall_jump_steer_time := 0.30      # after the pop, return-steering stays damped this long
@export var wall_jump_return_control := 0.32  # accel multiplier when steering BACK toward the wall

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
var _wall_jump_steer := 0.0
var _wall_jump_dir := 0.0     # +1 = launched rightward (off a left wall), -1 = left
var _air_dash_used := false
var _double_jump_used := false
var _fast_falling := false

# --- GRAFTS: harvested parts you OWN vs. the limited set you have EQUIPPED -------
# has_X flags = currently equipped/active (gameplay reads these, unchanged).
# `_owned` = every part you've harvested (permanent). The loadout screen swaps
# which owned parts fill your limited slots; equipped MASS reshapes your physics.
@export var graft_capacity: int = 4
var _owned: Dictionary = {}
var _grav_mult: float = 1.0
var _fallcap_mult: float = 1.0
var _airspeed_mult: float = 1.0
var _knock_mult: float = 1.0
var _is_sliding := false
var _slide_shrunk := false
var _slide_orig_h: float = 0.0
var _slide_orig_pos: Vector2 = Vector2.ZERO
var _fragments: Dictionary = {}      # ship-part id -> true
var _is_wall_sliding := false
var _facing := 1
var _iframes := 0.0
var _flash_t := 0.0
var _hit_lock := 0.0
var _dead := false
var _was_on_floor := false
var _shake = null
@export var bash_force: float = 540.0
@export var bash_range: float = 80.0
@export var bash_air_refresh: bool = true
var _bash_sensor: Area2D = null
var _f_down: bool = false
var _grip_held: bool = false
var _external_vel: Vector2 = Vector2.ZERO
var _hit_recent: float = 0.0
@export var external_decay: float = 900.0   # how fast a current's push fades on exit

func is_hurt_knockback() -> bool:
	return _hit_recent > 0.0
var health: int = 0:
	set(value):
		health = value
		health_changed.emit(health, max_health)


func _ready() -> void:
	collision_layer = 2          # Player layer, so your own beams pass through you
	add_to_group("player")       # so hostile (boss) projectiles can find you
	health = max_health
	# Whatever flags start true are considered already harvested + equipped.
	for key in Grafts.CATALOG:
		if get(key) == true:
			_owned[key] = true
	_recompute_grafts()
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
	# Bash sensor: a generous circle that notices nearby "bashable" targets.
	_bash_sensor = Area2D.new()
	_bash_sensor.collision_layer = 0
	_bash_sensor.collision_mask = 4          # enemies + bash points live on layer 4
	var bs := CollisionShape2D.new()
	var bc := CircleShape2D.new()
	bc.radius = bash_range
	bs.shape = bc
	_bash_sensor.add_child(bs)
	add_child(_bash_sensor)
	# Hide any grey-box placeholder sprite from the scene and attach the procedural
	# creature visual. (Swap this for an AnimatedSprite2D when real art exists.)
	for c in get_children():
		if c is Sprite2D or c is AnimatedSprite2D:
			(c as CanvasItem).visible = false
	var pv := PlayerVisual.new()
	add_child(pv)


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

	var pre := velocity
	velocity += _external_vel
	move_and_slide()
	velocity = pre                      # external push doesn't pollute owned momentum
	# Currents refresh _external_vel each frame while you're inside; it fades on exit.
	_external_vel = _external_vel.move_toward(Vector2.ZERO, external_decay * delta)
	_post_move()


# Called by CurrentZone each physics frame the player is inside it.
func apply_current(v: Vector2) -> void:
	_external_vel = v

# --- graft API ------------------------------------------------------------

func harvest(key: String) -> void:
	if not Grafts.has(key):
		set(key, true)               # non-catalog flags still flip (forward-compat)
		return
	_owned[key] = true
	if used_slots() + Grafts.slot_of(key) <= graft_capacity:
		equip(key)                   # auto-equip if there's room
	else:
		_recompute_grafts()

func is_owned(key: String) -> bool:
	return bool(_owned.get(key, false))

func is_equipped(key: String) -> bool:
	return get(key) == true

func used_slots() -> int:
	var s := 0
	for key in Grafts.CATALOG:
		if is_equipped(key):
			s += Grafts.slot_of(key)
	return s

func total_mass() -> int:
	var m := 0
	for key in Grafts.CATALOG:
		if is_equipped(key):
			m += Grafts.mass_of(key)
	return m

func can_equip(key: String) -> bool:
	return is_owned(key) and not is_equipped(key) \
		and used_slots() + Grafts.slot_of(key) <= graft_capacity

func equip(key: String) -> void:
	if not is_owned(key) or is_equipped(key):
		return
	if used_slots() + Grafts.slot_of(key) > graft_capacity:
		return
	set(key, true)
	var af := Grafts.active_flag(key)
	if af != "":
		set(af, true)                # beam mods come on when equipped
	_recompute_grafts()

func unequip(key: String) -> void:
	if not is_equipped(key):
		return
	set(key, false)
	var af := Grafts.active_flag(key)
	if af != "":
		set(af, false)
	_recompute_grafts()

func toggle_graft(key: String) -> void:
	if is_equipped(key):
		unequip(key)
	elif can_equip(key):
		equip(key)

func owned_keys() -> Array:
	return _owned.keys()

# --- ship fragments (salvage) ---------------------------------------------

func collect_fragment(id: String) -> bool:
	if _fragments.has(id):
		return false
	_fragments[id] = true
	return true

func has_fragment(id: String) -> bool:
	return _fragments.has(id)

func fragment_count() -> int:
	return _fragments.size()

func fragment_ids() -> Array:
	return _fragments.keys()

func restore_fragments(ids: Variant) -> void:
	_fragments.clear()
	if ids is Array:
		for i in ids:
			_fragments[str(i)] = true

func restore_grafts(owned: Array, capacity: int) -> void:
	_owned.clear()
	for k in owned:
		_owned[str(k)] = true
	graft_capacity = maxi(1, capacity)
	_recompute_grafts()

# Equipped MASS reshapes the bug: heavier = falls faster, drifts less, shrugs off
# knockback; lighter (wings) = floatier and easily launched.
func _recompute_grafts() -> void:
	var w := float(total_mass())
	_grav_mult = clampf(1.0 + w * 0.045, 0.78, 1.5)
	_fallcap_mult = clampf(1.0 + w * 0.05, 0.78, 1.6)
	_airspeed_mult = clampf(1.0 - w * 0.022, 0.78, 1.18)
	_knock_mult = clampf(1.0 - w * 0.05, 0.5, 1.35)


func _update_timers(delta: float) -> void:
	if _hit_recent > 0.0:
		_hit_recent -= delta
	if _jump_buffer > 0.0:
		_jump_buffer -= delta
	if _dash_cd > 0.0:
		_dash_cd -= delta
	if _wall_jump_lock > 0.0:
		_wall_jump_lock -= delta
	if _wall_jump_steer > 0.0:
		_wall_jump_steer -= delta
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

	# SMASH short hop: release jump while still rising hard -> snap down to the
	# short-hop height. Hold past that and you get the full jump. Two clean heights.
	if Input.is_action_just_released("jump") and velocity.y < short_hop_velocity:
		velocity.y = short_hop_velocity

	# SMASH fast-fall: tap down past the apex to commit to a faster descent.
	if not is_on_floor() and velocity.y > 0.0 and not _fast_falling \
			and Input.get_axis("move_up", "move_down") > 0.5:
		_fast_falling = true
		velocity.y = maxf(velocity.y, fast_fall_speed)

	_try_jump()
	_try_dash()
	_try_slide()
	_try_bash()


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		_fast_falling = false
		return
	var g := (fall_gravity if velocity.y > 0.0 else gravity) * _grav_mult
	var cap := (fast_fall_speed if _fast_falling else max_fall_speed) * _fallcap_mult
	velocity.y = minf(velocity.y + g * delta, cap)


func _handle_horizontal(delta: float, input_x: float) -> void:
	# The brief pop right off the wall ignores steering entirely so the kick reads.
	if _wall_jump_lock > 0.0 or _hit_lock > 0.0:
		return

	var on_floor := is_on_floor()
	var accel := run_accel if on_floor else air_accel
	var fric := ground_friction if on_floor else air_friction
	var top := max_run_speed if on_floor else air_max_speed * _airspeed_mult   # SMASH + mass
	var allow_boost := true

	# Super Metroid feel: for a short window after a wall jump, steering BACK toward
	# the wall doesn't snap you — it gently arcs you in (so you can drift back and
	# kick again to climb a shaft). Steering away or up stays fully responsive.
	if _wall_jump_steer > 0.0 and input_x != 0.0 and signf(input_x) != signf(_wall_jump_dir):
		accel *= wall_jump_return_control
		allow_boost = false

	if input_x != 0.0:
		# Reversing direction -> stronger accel so quick changes feel instant.
		if allow_boost and signf(input_x) != signf(velocity.x) and velocity.x != 0.0:
			accel *= turn_boost
		velocity.x = move_toward(velocity.x, input_x * top, accel * delta)
	else:
		# >>> MOMENTUM: friction only bleeds speed when you let go; never snaps to 0.
		velocity.x = move_toward(velocity.x, 0.0, fric * delta)


func _handle_wall() -> void:
	_is_wall_sliding = false
	if is_on_floor() or not is_on_wall_only():
		_grip_held = false
		return
	# Cling while the grab button is engaged. In Hold mode that means held; in
	# Toggle mode a press flips a latch that releases on the next press.
	var engaged := Input.is_action_pressed("slide")
	if Settings.grip_toggle:
		if Input.is_action_just_pressed("slide"):
			_grip_held = not _grip_held
		engaged = _grip_held
	if engaged and velocity.y > 0.0:
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
		_wall_jump_lock = wall_jump_control_lock  # brief pure-kick pop
		_wall_jump_steer = wall_jump_steer_time   # then damped return-steering
		_wall_jump_dir = n.x                       # the direction we launched
		_jump_buffer = 0.0
		_double_jump_used = false                 # touching a wall refreshes air options
		_air_dash_used = false
		Audio.play("wall_jump")
		return

	# Double jump - flag-gated.
	if has_double_jump and not _double_jump_used:
		velocity.y = jump_velocity
		_double_jump_used = true
		_fast_falling = false                     # SMASH: double jump resets the dive
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
			Rumble.pulse(0.2, 0.2, 0.1)


func _process_dash() -> void:
	velocity.x = _facing * dash_speed
	velocity.y = 0.0


# --- Bash (Ori-style): latch the nearest target and fling, redirecting momentum.
# Refreshes air options, so you can chain bashes across a gap. Map a "bash" action,
# or use the F key as a fallback.
func _bash_pressed() -> bool:
	if InputMap.has_action("bash") and Input.is_action_just_pressed("bash"):
		return true
	var down := Input.is_physical_key_pressed(KEY_F)
	var edge := down and not _f_down
	_f_down = down
	return edge

func _try_bash() -> void:
	if _bash_sensor == null:
		return
	if not _bash_pressed():
		return
	var target = _nearest_bashable()
	if target == null:
		return
	var dir := _bash_dir(target)
	velocity = dir * bash_force
	_hit_lock = 0.16                              # let the fling carry past steering
	if bash_air_refresh:
		_air_dash_used = false
		_double_jump_used = false
	if target.is_in_group("enemy") and target.has_method("take_damage"):
		target.take_damage(1, {"hit_dir": -dir})  # shove the target the other way
	Audio.play("dash")
	Rumble.pulse(0.3, 0.45, 0.12)
	get_tree().call_group("game", "hitstop", 0.05)
	Fx.burst(get_parent(), global_position, Color("#bff0c0"), 8, 150.0)

func _nearest_bashable():
	var best = null
	var best_d := INF
	var candidates: Array = []
	candidates.append_array(_bash_sensor.get_overlapping_bodies())
	candidates.append_array(_bash_sensor.get_overlapping_areas())
	for n in candidates:
		if n == self or not n.is_in_group("bashable"):
			continue
		var d := global_position.distance_squared_to((n as Node2D).global_position)
		if d < best_d:
			best_d = d
			best = n
	return best

func _bash_dir(target) -> Vector2:
	var ix := Input.get_axis("move_left", "move_right")
	var iy := Input.get_axis("move_up", "move_down")
	var v := Vector2(ix, iy)
	if v.length() > 0.2:
		return v.normalized()
	# No steer held: fling away from the target (classic bounce-off).
	var away := global_position - (target as Node2D).global_position
	return away.normalized() if away.length() > 1.0 else Vector2.UP


func _try_slide() -> void:
	if not has_slide or not is_on_floor():
		return
	if Input.is_action_just_pressed("slide") and absf(velocity.x) > slide_min_speed:
		_is_sliding = true
		velocity.x = _facing * slide_speed
		_set_slide_shape(true)


func _set_slide_shape(on: bool) -> void:
	# Best-effort morph-squeeze: shrink the player's collision height while sliding so
	# a low gap is passable only mid-slide. Works for a Capsule or Rectangle shape.
	var cs: CollisionShape2D = null
	for c in get_children():
		if c is CollisionShape2D:
			cs = c
			break
	if cs == null or cs.shape == null:
		return
	var shp := cs.shape
	if on and not _slide_shrunk:
		_slide_orig_pos = cs.position
		if shp is CapsuleShape2D:
			_slide_orig_h = (shp as CapsuleShape2D).height
			var nh: float = maxf((shp as CapsuleShape2D).radius * 2.0, _slide_orig_h * 0.5)
			(shp as CapsuleShape2D).height = nh
			cs.position = _slide_orig_pos + Vector2(0.0, (_slide_orig_h - nh) * 0.5)
		elif shp is RectangleShape2D:
			_slide_orig_h = (shp as RectangleShape2D).size.y
			var nh2: float = _slide_orig_h * 0.5
			(shp as RectangleShape2D).size.y = nh2
			cs.position = _slide_orig_pos + Vector2(0.0, (_slide_orig_h - nh2) * 0.5)
		_slide_shrunk = true
	elif not on and _slide_shrunk:
		if shp is CapsuleShape2D:
			(shp as CapsuleShape2D).height = _slide_orig_h
		elif shp is RectangleShape2D:
			(shp as RectangleShape2D).size.y = _slide_orig_h
		cs.position = _slide_orig_pos
		_slide_shrunk = false


func _process_slide(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, slide_friction * delta)
	_try_jump()
	if absf(velocity.x) < slide_min_speed or not is_on_floor() or Input.is_action_just_released("slide"):
		_is_sliding = false
		_set_slide_shape(false)


func _post_move() -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		Audio.play("land")
		Rumble.pulse(0.0, 0.22, 0.07)
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
	_hit_recent = 0.5                # room transitions during this window don't checkpoint
	if from_pos != null:
		var dir := signf((global_position - from_pos).x)
		if dir == 0.0:
			dir = -float(_facing)
		velocity.x = dir * knockback_force * _knock_mult
		velocity.y = -knockback_force * 0.5 * _knock_mult
	if health <= 0:
		await _die()
		return
	if _shake != null:
		_shake.shake(hit_shake, 0.25)
	Audio.play("hurt")
	Rumble.pulse(0.5, 0.7, 0.25)
	await _do_hitstop(hitstop_time)


func _die() -> void:
	_dead = true
	velocity = Vector2.ZERO
	modulate = death_color
	Audio.play("die")
	Rumble.pulse(0.9, 1.0, 0.5)
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
