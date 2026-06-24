extends Node2D
## LEVEL ONE  -  "plays as a level, teaches as a tutorial" (the Star Fox 64 model).
##
## Rooms live in one world. A Camera2D (on the player) is CONFINED to the current
## room via its limits, and pans smoothly when you cross a doorway. No scene
## loading - the same door API later swaps to streamed scenes if you want.
##
## Each room introduces one mechanic safely, then requires it:
##   A  RUN          - open corridor, can't fail
##   B  JUMP         - step ledges + a gap that needs a real jump
##   C  WALL-JUMP    - a pit whose only exit is up (teach by necessity)
##   D  DASH-JUMP    - a chasm too wide for a normal jump (dash is base kit)
##   E  DOUBLE-JUMP  - a tall gate; the pickup sits nearby; grab it and clear the wall
##   F  GRIP         - a wall descent you control by holding grip, down to the exit
##
## SEQUENCE BREAK: in room E an expert can DASH-JUMP onto the gate instead of
## grabbing double-jump. Nothing past E assumes you own double-jump (flat flags),
## so breaking in is safe. That's the metroidvania soul living under the tutorial.
##
## Everything here is a navigable STARTING POINT in grey boxes. Exact gap widths
## and wall heights are meant to be tuned against your final movement feel - the
## values flagged below are the ones to adjust first.

const C_FLOOR  := "#2b3a4a"
const C_WALL   := "#3a4d63"
const C_ACCENT := "#2f7d72"
const C_CUE    := "#c8763a"   # wordless "look here / go this way" hint color

@export var tile: float = 32.0
@export var player_scene: PackedScene
@export var show_labels: bool = false
@export var next_scene: String = ""     # passed to the level exit

var _rooms: Dictionary = {}              # name -> Rect2 (world px)
var _entries: Dictionary = {}            # name -> Vector2 (checkpoint/spawn)
var _player: Node = null
var _cam: Camera2D = null
var _current_room: String = ""
var _visited: Dictionary = {}            # room names the player has entered
var _checkpoint: Vector2 = Vector2.ZERO
var _world_bottom: float = 0.0
var _hud: Hud = null
var _r_down: bool = false
var T: float


func _ready() -> void:
	T = tile
	add_to_group("level")
	add_child(Game.new())          # pause/restart/complete + procedural audio
	add_child(Ambiance.new())      # tint + spores + drips
	_build_room_a()
	_build_room_b()
	_build_room_c()
	_build_room_d()
	_build_room_e()
	_build_room_f()
	_build_room_g()
	_build_surface()
	_compute_world_bottom()
	_spawn_enemies()
	_spawn_hazards()
	_spawn_player()


func _process(_delta: float) -> void:
	if _player == null:
		return
	# Safety net so nobody gets stranded: fell out of the world, or pressed R.
	var r := Input.is_physical_key_pressed(KEY_R)
	if _player.global_position.y > _world_bottom or (r and not _r_down):
		_respawn()
	_r_down = r


# ===========================================================================
# ROOMS
# ===========================================================================

func _build_room_a() -> void:
	var x0 := 0.0
	var x1 := 22.0 * T
	_register_room("A", Rect2(x0, -7.0 * T, x1 - x0, 9.0 * T), Vector2(2.0 * T, -T))
	_frame(x0, x1, -7.0 * T, 2.0 * T, false, true)   # solid left edge of the world
	_slab(x0, x1, 0.0, 2.0 * T, C_FLOOR)             # flat floor
	_label(Vector2(x0 + T, -6.0 * T), "RUN")


func _build_room_b() -> void:
	var x0 := 22.0 * T
	var x1 := 46.0 * T
	_register_room("B", Rect2(x0, -10.0 * T, x1 - x0, 12.0 * T), Vector2(x0 + T, -T))
	_frame(x0, x1, -10.0 * T, 2.0 * T, true, true)
	# Floor with a gap that needs a real jump.
	_slab(x0, 40.0 * T, 0.0, 2.0 * T, C_FLOOR)
	_slab(42.0 * T, x1, 0.0, 2.0 * T, C_FLOOR)       # gap 40..42 (2 tiles) <-- TUNE
	# Inviting step-up ledges.
	_slab(28.0 * T, 30.0 * T, -2.0 * T, -1.0 * T, C_FLOOR)
	_slab(32.0 * T, 34.0 * T, -3.0 * T, -2.0 * T, C_FLOOR)
	# First weapon upgrade: the Charge Beam, on a small ledge.
	_slab(36.0 * T, 38.0 * T, -3.0 * T, -2.0 * T, C_FLOOR)
	var charge := AbilityPickup.new()
	charge.ability = "has_charge"
	charge.display_name = "Charge Gland"
	charge.color = Color("#9fe6ff")
	charge.position = Vector2(37.0 * T, -4.0 * T)
	add_child(charge)
	_label(Vector2(35.5 * T, -5.0 * T), "CHARGE BEAM", 11)
	_label(Vector2(x0 + T, -9.0 * T), "JUMP")


func _build_room_c() -> void:
	var x0 := 46.0 * T
	var x1 := 64.0 * T
	_register_room("C", Rect2(x0, -7.0 * T, x1 - x0, 14.0 * T), Vector2(x0 + T, -T))
	_frame(x0, x1, -7.0 * T, 7.0 * T, true, true)
	# Left landing is a thick block; its right face is the left pit wall.
	_slab(x0, 53.0 * T, 0.0, 7.0 * T, C_FLOOR)
	# Pit floor you fall onto.
	_slab(53.0 * T, 57.0 * T, 6.0 * T, 7.0 * T, C_FLOOR)
	# Right wall = the climb target; its top is the exit ledge level.
	_slab(57.0 * T, 58.0 * T, 0.0, 7.0 * T, C_WALL)
	_slab(57.0 * T, x1, 0.0, 2.0 * T, C_FLOOR)        # exit ledge -> doorway to D
	# Wordless cue: accent stripes up the 4-tile slot say "go up here".
	_slab(52.7 * T, 53.0 * T, -1.0 * T, 5.0 * T, C_CUE)
	_slab(57.0 * T, 57.3 * T, -1.0 * T, 5.0 * T, C_CUE)
	# Missiles (flag + 5 ammo) as the reward for climbing out.
	var missiles_pick := AbilityPickup.new()
	missiles_pick.ability = "has_missiles"
	missiles_pick.display_name = "Stinger Pods"
	missiles_pick.amount_property = "missiles"
	missiles_pick.grant_amount = 5
	missiles_pick.color = Color("#ff8c42")
	missiles_pick.position = Vector2(61.0 * T, -2.0 * T)
	add_child(missiles_pick)
	_label(Vector2(59.5 * T, -3.5 * T), "MISSILES", 11)
	_label(Vector2(53.5 * T, -2.0 * T), "WALL-JUMP UP")


func _build_room_d() -> void:
	var x0 := 64.0 * T
	var x1 := 90.0 * T
	_register_room("D", Rect2(x0, -10.0 * T, x1 - x0, 18.0 * T), Vector2(x0 + T, -T))
	_frame(x0, x1, -10.0 * T, 8.0 * T, true, true)
	_slab(x0, 72.0 * T, 0.0, 2.0 * T, C_FLOOR)        # launch ledge
	_slab(80.0 * T, x1, 0.0, 2.0 * T, C_FLOOR)        # landing ledge (gap 72..80 = 8 tiles) <-- TUNE to dash-jump range
	# Recovery so a missed jump never strands you: a floor below + steps back up.
	_slab(72.0 * T, 80.0 * T, 6.0 * T, 8.0 * T, C_FLOOR)
	_slab(72.0 * T, 73.5 * T, 4.0 * T, 8.0 * T, C_FLOOR)
	_slab(73.5 * T, 75.0 * T, 2.0 * T, 8.0 * T, C_FLOOR)
	# Cue at the launch edge.
	_slab(71.0 * T, 72.0 * T, -1.0 * T, 0.0, C_CUE)
	# Ice Beam, on the far landing (freezes enemies into platforms).
	var ice := AbilityPickup.new()
	ice.ability = "has_ice"
	ice.display_name = "Frost Gland"
	ice.color = Color("#bfe9ff")
	ice.position = Vector2(86.0 * T, -3.0 * T)
	add_child(ice)
	_label(Vector2(84.5 * T, -4.5 * T), "ICE BEAM", 11)
	_label(Vector2(x0 + T, -9.0 * T), "DASH-JUMP")


func _build_room_e() -> void:
	var x0 := 90.0 * T
	var x1 := 112.0 * T
	_register_room("E", Rect2(x0, -10.0 * T, x1 - x0, 12.0 * T), Vector2(x0 + T, -T))
	_frame(x0, x1, -10.0 * T, 2.0 * T, true, true)
	_slab(x0, x1, 0.0, 2.0 * T, C_FLOOR)
	# Pickup ledge reachable with a normal jump.
	_slab(94.0 * T, 97.0 * T, -3.0 * T, -2.0 * T, C_FLOOR)
	# The gate: 5 tiles tall = too high for a normal jump, easy with double-jump,
	# and just reachable by an expert dash-jump (the intended sequence break). <-- TUNE height
	_slab(102.0 * T, 103.0 * T, -5.0 * T, 2.0 * T, C_WALL)
	_label(Vector2(x0 + T, -9.0 * T), "DOUBLE-JUMP")
	_label(Vector2(99.0 * T, -6.0 * T), "(or dash-jump it)")
	# The reward.
	var pickup := AbilityPickup.new()
	pickup.ability = "has_double_jump"
	pickup.display_name = "Wing-Segment"
	pickup.position = Vector2(95.5 * T, -4.0 * T)
	add_child(pickup)


func _build_room_f() -> void:
	var x0 := 112.0 * T
	var x1 := 130.0 * T
	_register_room("F", Rect2(x0, -7.0 * T, x1 - x0, 17.0 * T), Vector2(x0 + T, -T))
	# Enter top-left at floor level; exit bottom-right (door at y = 8T) into the arena.
	_frame(x0, x1, -7.0 * T, 10.0 * T, true, true, 0.0, 8.0 * T)
	_slab(x0, 116.0 * T, 0.0, 2.0 * T, C_FLOOR)            # entry ledge (top)
	_slab(120.0 * T, 121.0 * T, -1.0 * T, 5.0 * T, C_WALL) # grip wall (ends above the floor)
	_slab(116.0 * T, 120.0 * T, 5.0 * T, 6.0 * T, C_FLOOR) # mid ledge
	_slab(113.0 * T, x1, 8.0 * T, 10.0 * T, C_FLOOR)       # bottom floor -> arena door
	_slab(119.7 * T, 120.0 * T, -1.0 * T, 5.0 * T, C_CUE)  # grip cue
	# Optional bonus pocket (dead-end LEFT): a missile door gates the Wave Beam.
	# It never blocks the path to the boss (that goes right).
	var door := MissileDoor.new()
	door.position = Vector2(115.0 * T, 6.5 * T)
	add_child(door)
	var wave := AbilityPickup.new()
	wave.ability = "has_wave"
	wave.display_name = "Resonant Membrane"
	wave.color = Color("#c77dff")
	wave.position = Vector2(113.6 * T, 7.0 * T)
	add_child(wave)
	_label(Vector2(116.5 * T, -1.0 * T), "GRIP")


func _build_room_g() -> void:
	var x0 := 130.0 * T
	var x1 := 158.0 * T
	_register_room("G", Rect2(x0, -4.0 * T, x1 - x0, 14.0 * T), Vector2(x0 + T, 7.0 * T))
	# Arena floor at y = 8T (meets F's bottom door). Solid right edge of the world.
	_frame(x0, x1, -4.0 * T, 10.0 * T, true, false, 8.0 * T)
	_slab(x0, x1, 8.0 * T, 10.0 * T, C_FLOOR)
	# A couple of ledges for dodging over lunges.
	_slab(136.0 * T, 140.0 * T, 4.0 * T, 5.0 * T, C_FLOOR)
	_slab(148.0 * T, 152.0 * T, 4.0 * T, 5.0 * T, C_FLOOR)
	# The boss.
	var boss := Boss.new()
	add_child(boss)
	boss.global_position = Vector2(150.0 * T, 8.0 * T - boss.size.y * 0.5)
	_label(Vector2(x0 + T, -3.0 * T), "BOSS")


# The above-ground finale arena, placed high over the hive (open sky). Reached only
# via begin_surface() after the escape succeeds; the player can't walk here normally.
const SKY_X0_T := 60.0
const SKY_X1_T := 100.0
const SKY_TOP_T := -72.0
const SKY_FLOOR_T := -50.0
const SKY_BOT_T := -48.0

func _build_surface() -> void:
	var x0 := SKY_X0_T * T
	var x1 := SKY_X1_T * T
	var top := SKY_TOP_T * T
	var bot := SKY_BOT_T * T
	var floor_top := SKY_FLOOR_T * T
	_register_room("SKY", Rect2(x0, top, x1 - x0, bot - top), Vector2(x0 + 3.0 * T, floor_top - T))
	_slab(x0, x1, floor_top, bot, C_FLOOR)             # ground
	_slab(x0, x0 + T, top, floor_top, C_WALL)          # left cliff
	_slab(x1 - T, x1, top, floor_top, C_WALL)          # right cliff
	_slab(x0 + 8.0 * T, x0 + 12.0 * T, floor_top - 5.0 * T, floor_top - 4.0 * T, C_FLOOR)   # perches
	_slab(x1 - 12.0 * T, x1 - 8.0 * T, floor_top - 5.0 * T, floor_top - 4.0 * T, C_FLOOR)

# Called by the escape sequence on success: lift the player out of the hive into the
# open sky and start the two-phase finale boss.
func begin_surface() -> void:
	if _player == null:
		return
	get_tree().call_group("game", "room_fade")
	var entry: Vector2 = _entries.get("SKY", Vector2.ZERO)
	(_player as Node2D).global_position = entry
	if _player is CharacterBody2D:
		(_player as CharacterBody2D).velocity = Vector2.ZERO
	_player.set("health", int(_player.get("max_health")))   # full heal for the finale
	_current_room = ""
	_enter_room("SKY")
	var sb := SkyBoss.new()
	add_child(sb)
	sb.global_position = Vector2((SKY_X0_T + SKY_X1_T) * 0.5 * T, SKY_FLOOR_T * T - sb.size.y * 0.5)
	sb.hover_y = (SKY_TOP_T + 10.0) * T
	if _hud != null:
		_hud.bind_boss(sb)
	get_tree().create_timer(0.9).timeout.connect(sb.engage)


# ===========================================================================
# ROOM / CAMERA PLUMBING
# ===========================================================================

func _register_room(room_name: String, rect: Rect2, entry: Vector2) -> void:
	_rooms[room_name] = rect
	_entries[room_name] = entry
	# A trigger area the size of the room. Entering it hands the camera to this room.
	var area := Area2D.new()
	area.collision_mask = 3        # see the player on layer 1 or 2
	area.monitoring = true
	add_child(area)
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = rect.size
	cs.shape = rs
	cs.position = rect.position + rect.size * 0.5
	area.add_child(cs)
	area.body_entered.connect(func(body): _on_room_body_entered(room_name, body))


func _on_room_body_entered(room_name: String, body: Node) -> void:
	if body.is_in_group("player"):
		_enter_room(room_name)


func _enter_room(room_name: String) -> void:
	if room_name == _current_room:
		return
	var first := _current_room == ""
	# If the player was knocked across the boundary by a hit, follow with the camera
	# but don't treat it as a real arrival: no checkpoint move, no autosave, no boss
	# engage/disengage. Prevents knockback from corrupting your save/checkpoint.
	var knocked: bool = _player != null and _player.has_method("is_hurt_knockback") \
		and _player.is_hurt_knockback()
	_current_room = room_name
	_visited[room_name] = true
	_apply_camera_limits(_rooms[room_name])
	get_tree().call_group("ambiance", "set_tint", _room_tint(room_name))
	if not first:
		get_tree().call_group("game", "room_fade")
	if knocked:
		return
	_checkpoint = _entries[room_name]
	get_tree().call_group("escape", "room_entered", room_name)
	if room_name == "G":
		get_tree().call_group("boss", "engage")   # wake the boss + show its bar
	elif room_name != "SKY":
		get_tree().call_group("boss", "disengage") # left the hive arena: boss stands down
	if not first and room_name != "SKY":
		save_progress()                             # autosave at each hive room (checkpoint)


# Faint per-area color so rooms feel like distinct places.
func _room_tint(room_name: String) -> Color:
	match room_name:
		"A": return Color(0.25, 0.45, 0.50, 0.10)   # cool entrance
		"B": return Color(0.30, 0.45, 0.25, 0.10)   # mossy
		"C": return Color(0.20, 0.25, 0.45, 0.13)   # deep pit
		"D": return Color(0.45, 0.60, 0.70, 0.12)   # icy
		"E": return Color(0.40, 0.28, 0.50, 0.11)   # spore-purple
		"F": return Color(0.30, 0.22, 0.28, 0.13)   # gloom
		"G": return Color(0.50, 0.12, 0.12, 0.14)   # the brood
		"SKY": return Color(0.65, 0.78, 0.95, 0.06)  # open daylight, above the hive
		_:   return Color(0.30, 0.30, 0.30, 0.10)


# --- map data for the loadout menu's minimap ---
func map_rooms() -> Dictionary:
	return _rooms

func map_visited() -> Dictionary:
	return _visited

func map_current() -> String:
	return _current_room

func map_player_pos() -> Vector2:
	return (_player as Node2D).global_position if _player != null else Vector2.ZERO


func _apply_camera_limits(rect: Rect2) -> void:
	if _cam == null:
		return
	_cam.limit_left = int(rect.position.x)
	_cam.limit_top = int(rect.position.y)
	_cam.limit_right = int(rect.position.x + rect.size.x)
	_cam.limit_bottom = int(rect.position.y + rect.size.y)


# ===========================================================================
# PLAYER / RESPAWN
# ===========================================================================

func _spawn_player() -> void:
	var data := SaveSystem.load_data()
	var spawn: Vector2 = _entries.get("A", Vector2.ZERO)
	var start_room := "A"
	if not data.is_empty():
		var cp: Variant = data.get("checkpoint", null)
		if cp is Array and (cp as Array).size() == 2:
			spawn = Vector2(float(cp[0]), float(cp[1]))
		start_room = str(data.get("current_room", "A"))
		var vis: Variant = data.get("visited", [])
		if vis is Array:
			for r in vis:
				_visited[str(r)] = true
	_checkpoint = spawn
	if player_scene != null:
		_player = player_scene.instantiate()
		add_child(_player)
		if _player is Node2D:
			(_player as Node2D).global_position = spawn
		_cam = _find_camera(_player)
		if _player.has_signal("died"):
			_player.died.connect(_respawn)
		_apply_abilities(data)
	else:
		_label(spawn + Vector2(-3.0 * T, -2.0 * T), "▶ set player_scene to spawn here")
	if _cam != null:
		_cam.position_smoothing_enabled = true
		_cam.position_smoothing_speed = 6.0
		_cam.limit_smoothed = true        # smooth pan when limits change between rooms
	else:
		push_warning("Level1: no Camera2D found on the player - add one as a child of the player scene.")
	_enter_room(start_room)
	if _player != null:
		var hud := Hud.new()
		_hud = hud
		add_child(hud)
		hud.bind(_player)
		for b in get_tree().get_nodes_in_group("boss"):
			hud.bind_boss(b)
		var menu := LoadoutMenu.new()
		add_child(menu)
		menu.bind(_player)
		menu.set_map_source(self)


# --- save/restore -----------------------------------------------------------
func save_progress() -> void:
	if _player == null:
		return
	var ab := {}
	for k in ["has_charge", "has_ice", "has_wave", "has_missiles",
			"has_double_jump", "has_dash", "has_wall_jump", "has_slide"]:
		ab[k] = bool(_player.get(k))
	SaveSystem.save({
		"abilities": ab,
		"charge_active": bool(_player.get("charge_active")),
		"ice_active": bool(_player.get("ice_active")),
		"wave_active": bool(_player.get("wave_active")),
		"missiles": int(_player.get("missiles")),
		"visited": _visited.keys(),
		"current_room": _current_room,
		"checkpoint": [_checkpoint.x, _checkpoint.y],
	})

func _apply_abilities(data: Dictionary) -> void:
	if data.is_empty() or _player == null:
		return
	var ab: Variant = data.get("abilities", {})
	if ab is Dictionary:
		for k in ab:
			_player.set(str(k), bool(ab[k]))
	_player.set("charge_active", bool(data.get("charge_active", true)))
	_player.set("ice_active", bool(data.get("ice_active", true)))
	_player.set("wave_active", bool(data.get("wave_active", true)))
	_player.set("missiles", int(data.get("missiles", 0)))


func _find_camera(n: Node) -> Camera2D:
	for c in n.get_children():
		if c is Camera2D:
			return c
	return null


func _respawn() -> void:
	if _player == null:
		return
	(_player as Node2D).global_position = _checkpoint
	_player.set("velocity", Vector2.ZERO)


func _compute_world_bottom() -> void:
	var maxb := -INF
	for r in _rooms.values():
		maxb = maxf(maxb, r.position.y + r.size.y)
	_world_bottom = maxb + 6.0 * T


func _spawn_enemies() -> void:
	# Placed where combat fits the teaching flow: after movement is introduced,
	# and one past the gate in E. (Room A stays a safe, can't-fail intro.)
	_add_enemy(Vector2(36.0 * T, -2.0 * T))            # B: first target, test the charge beam
	_add_enemy(Vector2(85.0 * T, -2.0 * T))            # D: on the far landing ledge
	_add_enemy(Vector2(108.0 * T, -2.0 * T))           # E: beyond the double-jump gate
	# Variety with readable tells, introduced one mechanic at a time:
	_add_typed(Spitter.new(), Vector2(40.0 * T, -2.0 * T))   # B: learn to dodge shots
	_add_typed(Flyer.new(),   Vector2(86.0 * T, -6.0 * T))   # D: airborne swooper (interior, not on the D/E line)
	_add_typed(Charger.new(), Vector2(104.0 * T, -2.0 * T))  # E: read-and-sidestep (interior, not on the E/F line)
	# A bash hook over the chasm in D, to demonstrate the verb for traversal.
	var bp := BashPoint.new()
	add_child(bp)
	bp.global_position = Vector2(82.0 * T, -7.0 * T)


func _spawn_hazards() -> void:
	# ROOM D — a traversal puzzle around the chasm (72..80T).
	# Spikes line the chasm floor (top at 6T): falling in hurts.
	var sp := Spikes.new()
	sp.span = 5.0 * T
	sp.depth = 18.0
	sp.normal = Vector2.UP
	sp.damage = 12
	sp.position = Vector2(76.0 * T, 6.0 * T)
	add_child(sp)
	# ...but an updraft column lets you float across (or recover from a fall).
	var cz := CurrentZone.new()
	cz.area_size = Vector2(3.0 * T, 8.0 * T)
	cz.push = Vector2(0.0, -560.0)
	cz.position = Vector2(76.0 * T, 2.0 * T)
	add_child(cz)
	_label(Vector2(74.0 * T, -4.0 * T), "UPDRAFT", 11)
	# A breakable gate across the entry walkway teaches "shoot to open".
	var bw := BreakableWall.new()
	bw.block = Vector2(T, 4.0 * T)
	bw.hp = 6
	bw.position = Vector2(70.0 * T, -1.0 * T)
	add_child(bw)
	_label(Vector2(68.5 * T, -4.0 * T), "SHOOT", 11)
	# A one-way ledge up toward the ICE BEAM shelf (jump up through it).
	var op := OnewayPlatform.new()
	op.span = 5.0 * T
	op.position = Vector2(84.0 * T, -4.0 * T)
	add_child(op)

	# ROOM F — a crusher to time on the way down to the boss door.
	var cr := Crusher.new()
	cr.block = Vector2(2.5 * T, 2.5 * T)
	cr.travel = 3.0 * T
	cr.dir = Vector2.DOWN
	cr.damage = 24
	cr.position = Vector2(124.0 * T, 3.0 * T)
	add_child(cr)
	_label(Vector2(122.0 * T, 0.5 * T), "CRUSHER", 11)


func _add_enemy(pos: Vector2) -> void:
	var e := Enemy.new()
	add_child(e)
	var rn := _room_name_at(pos)
	e.global_position = _safe_spawn(pos, rn)
	e.room_bounds = _rooms[rn].grow(-tile) if rn != "" else Rect2()


func _add_typed(e: Node2D, pos: Vector2) -> void:
	add_child(e)
	var rn := _room_name_at(pos)
	e.global_position = _safe_spawn(pos, rn)
	e.set("room_bounds", _rooms[rn].grow(-tile) if rn != "" else Rect2())


# The room a point belongs to, chosen by the deepest interior margin so a point
# sitting exactly on a shared boundary resolves to the room it's actually inside
# (not the neighbor). This was the cause of enemies landing by the wrong doorway.
func _room_name_at(pos: Vector2) -> String:
	var best := ""
	var best_margin := -INF
	for name in _rooms:
		var r: Rect2 = _rooms[name]
		var mx := minf(pos.x - r.position.x, r.position.x + r.size.x - pos.x)
		var my := minf(pos.y - r.position.y, r.position.y + r.size.y - pos.y)
		var m := minf(mx, my)
		if m > best_margin:
			best_margin = m
			best = name
	return best


# Keep a spawn clear of the room's walls AND its entry point so the player never
# walks straight into an enemy on a room transition.
func _safe_spawn(pos: Vector2, room_name: String) -> Vector2:
	if room_name == "" or not _rooms.has(room_name):
		return pos
	var r: Rect2 = _rooms[room_name]
	var m := 4.0 * tile
	pos.x = clampf(pos.x, r.position.x + m, r.position.x + r.size.x - m)
	var entry: Vector2 = _entries.get(room_name, pos)
	if absf(pos.x - entry.x) < 4.0 * tile:
		pos.x = entry.x + (4.0 * tile if pos.x >= entry.x else -4.0 * tile)
		pos.x = clampf(pos.x, r.position.x + m, r.position.x + r.size.x - m)
	return pos


# The room rectangle that contains a point (inset a little so enemies don't
# clip the doorway seams). Returns an empty Rect2 if the point is roomless.
func _room_containing(pos: Vector2) -> Rect2:
	for name in _rooms:
		var r: Rect2 = _rooms[name]
		if r.has_point(pos):
			return r.grow(-tile)
	return Rect2()


# ===========================================================================
# GEOMETRY HELPERS
# ===========================================================================

# A solid rectangle defined by its edges (top < bottom; up is negative y).
func _slab(x0: float, x1: float, top: float, bottom: float, color_hex := C_FLOOR) -> void:
	if x1 <= x0 or bottom <= top:
		return
	var center := Vector2((x0 + x1) * 0.5, (top + bottom) * 0.5)
	var size := Vector2(x1 - x0, bottom - top)
	var body := StaticBody2D.new()
	body.position = center
	body.collision_layer = 1     # World
	body.collision_mask = 0
	add_child(body)
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	col.shape = rect
	body.add_child(col)
	var hw := size.x * 0.5
	var hh := size.y * 0.5
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh),
	])
	poly.color = Color(color_hex)
	body.add_child(poly)


# Ceiling + side walls. Doorways are 3-tile openings whose floor is at door_y
# (defaults to 0). This lets adjacent rooms connect at different heights.
func _frame(x0: float, x1: float, top: float, bottom: float, left_door: bool, right_door: bool,
		left_door_y := 0.0, right_door_y := 0.0) -> void:
	var dh := 3.0 * T
	_slab(x0, x1, top, top + T, C_WALL)                       # ceiling
	if left_door:
		_slab(x0, x0 + T, top, left_door_y - dh, C_WALL)      # wall above the opening
		_slab(x0, x0 + T, left_door_y, bottom, C_WALL)        # wall below the opening
	else:
		_slab(x0, x0 + T, top, bottom, C_WALL)
	if right_door:
		_slab(x1 - T, x1, top, right_door_y - dh, C_WALL)
		_slab(x1 - T, x1, right_door_y, bottom, C_WALL)
	else:
		_slab(x1 - T, x1, top, bottom, C_WALL)


func _label(pos: Vector2, text: String, size := 13) -> void:
	if not show_labels:
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.position = pos
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", Color("#e8e8e8"))
	add_child(lbl)


# ===========================================================================
# SETUP
#   1. Put player.gd, ability_pickup.gd, level_exit.gd, and this file in scripts/.
#   2. New scene, root Node2D, attach this script. Set `player_scene` to player.tscn.
#   3. Make sure player.tscn has a Camera2D as a child (the room lock drives it).
#   4. Press play. R respawns at the current room's entry if you ever get stuck.
#
# TUNING ORDER (match the level to the feel you're still dialing in):
#   - D chasm width (gap 72..80) vs your dash-jump distance.
#   - E gate height (the -5T wall) - high enough that a normal jump fails, low
#     enough that a confident dash-jump can break it.
#   - C pit slot width (4 tiles) vs your wall-jump climb.
# ===========================================================================
