extends Node2D
class_name RegionHollow
## REGION 1 — THE HOLLOW MOUTH. The template for every spine region, and the first
## finished one. Self-contained like level_one: attach to a Node2D scene root, set
## player_scene to player.tscn (with a Camera2D child), press play.
##
## Shape: MAW -> GULLET -> CRAW (apex arena) -> THROAT (a grip shaft). The apex,
## THE BURROWER, grants Grip-Claws (wall-grip) on death; the only way onward is the
## shaft, which needs that grip — so the region physically gates on its own reward.
##
## Per-region wiring cost (what you copy for regions 2-5):
##   1. build rooms   2. _region_of returns this id   3. apex.cleared -> harvest
##   4. a physical gate that needs the granted graft   5. connect the exit onward.

const REGION_ID := "hollow"
const C_FLOOR := "#332a24"
const C_WALL := "#241d18"

@export var tile: float = 32.0
@export var player_scene: PackedScene
@export var show_labels: bool = true

var T: float
var _rooms: Dictionary = {}
var _entries: Dictionary = {}
var _visited: Dictionary = {}
var _current_room: String = ""
var _current_region: String = ""
var _checkpoint: Vector2
var _player: Node2D = null
var _cam: Camera2D = null
var _hud = null
var _music: Music = null
var _boss_music: Music = null
var _apex: ApexBurrower = null
var _seal: StaticBody2D = null

func _ready() -> void:
	T = tile
	add_to_group("level")
	add_child(Game.new())
	add_child(Ambiance.new())
	_music = Music.new()
	add_child(_music)
	_boss_music = Music.new()
	_boss_music.theme = "boss"
	_boss_music.autoplay = false
	add_child(_boss_music)

	_build_maw()
	_build_gullet()
	_build_craw()
	_build_throat()
	_spawn_entities()
	_spawn_player()

# ===========================================================================
# ROOMS
# ===========================================================================

func _build_maw() -> void:
	var x0 := 0.0
	var x1 := 24.0 * T
	_register_room("H1", Rect2(x0, -9.0 * T, x1 - x0, 11.0 * T), Vector2(2.0 * T, -T))
	_frame(x0, x1, -9.0 * T, 2.0 * T, false, true)
	_slab(x0, x1, 0.0, 2.0 * T, C_FLOOR)
	_slab(8.0 * T, 10.0 * T, -2.0 * T, -1.0 * T, C_FLOOR)   # a step to introduce jumping
	_label(Vector2(x0 + 1.5 * T, -8.0 * T), "THE MAW")


func _build_gullet() -> void:
	var x0 := 24.0 * T
	var x1 := 50.0 * T
	_register_room("H2", Rect2(x0, -10.0 * T, x1 - x0, 12.0 * T), Vector2(x0 + T, -T))
	_frame(x0, x1, -10.0 * T, 2.0 * T, true, true)
	_slab(x0, x1, 0.0, 2.0 * T, C_FLOOR)
	# Step ledges and a spike strip to hop.
	_slab(28.0 * T, 31.0 * T, -3.0 * T, -2.0 * T, C_FLOOR)
	_slab(40.0 * T, 43.0 * T, -3.0 * T, -2.0 * T, C_FLOOR)
	var spikes := Spikes.new()
	spikes.position = Vector2(36.0 * T, -T)
	if "width" in spikes:
		spikes.set("width", 3.0 * T)
	add_child(spikes)
	_label(Vector2(x0 + T, -9.0 * T), "THE GULLET")


func _build_craw() -> void:
	var x0 := 50.0 * T
	var x1 := 82.0 * T
	_register_room("H3", Rect2(x0, -11.0 * T, x1 - x0, 13.0 * T), Vector2(x0 + T, -T))
	_frame(x0, x1, -11.0 * T, 2.0 * T, true, true)
	_slab(x0, x1, 0.0, 2.0 * T, C_FLOOR)
	_label(Vector2(x0 + T, -10.0 * T), "THE CRAW")


func _build_throat() -> void:
	var x0 := 82.0 * T
	var x1 := 98.0 * T
	_register_room("H4", Rect2(x0, -22.0 * T, x1 - x0, 24.0 * T), Vector2(x0 + T, -T))
	_frame(x0, x1, -22.0 * T, 2.0 * T, true, false)
	_slab(x0, x1, 0.0, 2.0 * T, C_FLOOR)
	# The grip shaft: two opposing pillars with a narrow channel to wall-jump up.
	_slab(86.0 * T, 87.0 * T, -20.0 * T, 0.0, C_WALL)
	_slab(91.0 * T, 92.0 * T, -20.0 * T, 0.0, C_WALL)
	_slab(86.0 * T, 96.0 * T, -21.0 * T, -20.0 * T, C_FLOOR)   # ledge at the top
	_label(Vector2(87.0 * T, -19.0 * T), "THE THROAT")
	_label(Vector2(85.0 * T, -21.5 * T), "▶ THE GLIMMERWET — region 2 (not yet built)", 11)


# ===========================================================================
# ENTITIES
# ===========================================================================

func _spawn_entities() -> void:
	var e := Enemy.new()
	add_child(e)
	e.global_position = Vector2(30.0 * T, -3.0 * T)
	e.set("room_bounds", _rooms["H2"].grow(-tile))
	var f := Flyer.new()
	add_child(f)
	f.global_position = Vector2(45.0 * T, -6.0 * T)
	f.set("room_bounds", _rooms["H2"].grow(-tile))

	# The apex, resting on the Craw floor.
	_apex = ApexBurrower.new()
	add_child(_apex)
	_apex.global_position = Vector2(65.0 * T, -_apex.size.y * 0.5)
	_apex.cleared.connect(_on_apex_cleared)

	# Seal the Craw's exit until the apex falls (arena locks, then opens).
	_seal = StaticBody2D.new()
	_seal.position = Vector2(81.5 * T, -1.5 * T)
	_seal.collision_layer = 1
	add_child(_seal)
	var sc := CollisionShape2D.new()
	var srs := RectangleShape2D.new()
	srs.size = Vector2(T, 3.0 * T)
	sc.shape = srs
	_seal.add_child(sc)
	var sp := Polygon2D.new()
	sp.polygon = PackedVector2Array([
		Vector2(-T * 0.5, -1.5 * T), Vector2(T * 0.5, -1.5 * T),
		Vector2(T * 0.5, 1.5 * T), Vector2(-T * 0.5, 1.5 * T)])
	sp.color = Color(0.5, 0.16, 0.16, 0.85)
	_seal.add_child(sp)


func _on_apex_cleared() -> void:
	set_boss_music(false)
	if _seal != null and is_instance_valid(_seal):
		var t := create_tween()
		t.tween_property(_seal, "modulate:a", 0.0, 0.4)
		t.tween_callback(_seal.queue_free)
	get_tree().call_group("game", "region_banner", "GRIP-CLAWS", "the walls are yours now", Color(0.62, 0.84, 0.54))
	save_progress()

# ===========================================================================
# ROOM FLOW (mirrors level_one)
# ===========================================================================

func _register_room(room_name: String, rect: Rect2, entry: Vector2) -> void:
	_rooms[room_name] = rect
	_entries[room_name] = entry
	var area := Area2D.new()
	area.collision_mask = 3
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
	if room_name == _current_room or not _rooms.has(room_name):
		return
	var first := _current_room == ""
	var knocked: bool = _player != null and _player.has_method("is_hurt_knockback") \
		and _player.is_hurt_knockback()
	_current_room = room_name
	_visited[room_name] = true
	_apply_camera_limits(_rooms[room_name])
	if _current_region != REGION_ID:
		_current_region = REGION_ID
		get_tree().call_group("ambiance", "set_tint", Regions.tint_of(REGION_ID))
		get_tree().call_group("game", "region_banner",
			Regions.name_of(REGION_ID), Regions.sub_of(REGION_ID), Color(0.62, 0.84, 0.54))
	if not first:
		get_tree().call_group("game", "room_fade")
	if knocked:
		return
	_checkpoint = _entries[room_name]
	# The Craw is the apex arena.
	if room_name == "H3" and _apex != null and is_instance_valid(_apex):
		_apex.engage()
		set_boss_music(true)
	else:
		set_boss_music(false)
	if not first:
		save_progress()


func _apply_camera_limits(rect: Rect2) -> void:
	if _cam == null:
		return
	_cam.limit_left = int(rect.position.x)
	_cam.limit_top = int(rect.position.y)
	_cam.limit_right = int(rect.position.x + rect.size.x)
	_cam.limit_bottom = int(rect.position.y + rect.size.y)


func set_boss_music(on: bool) -> void:
	if _music == null or _boss_music == null:
		return
	if on:
		_music.stop()
		_boss_music.play()
	else:
		_boss_music.stop()
		_music.play()

# ===========================================================================
# PLAYER / SAVE
# ===========================================================================

func _spawn_player() -> void:
	var data := SaveSystem.load_data()
	var spawn: Vector2 = _entries.get("H1", Vector2.ZERO)
	var start_room := "H1"
	if not data.is_empty():
		var cp: Variant = data.get("checkpoint", null)
		if cp is Array and (cp as Array).size() == 2:
			spawn = Vector2(float(cp[0]), float(cp[1]))
		start_room = str(data.get("current_room", "H1"))
		if not _rooms.has(start_room):
			start_room = "H1"
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
		_cam.limit_smoothed = true
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


func _apply_abilities(data: Dictionary) -> void:
	if _player == null or data.is_empty():
		return
	var ab: Variant = data.get("abilities", {})
	if ab is Dictionary:
		for k in ab:
			_player.set(str(k), bool(ab[k]))
	for k in ["charge_active", "ice_active", "wave_active"]:
		if data.has(k):
			_player.set(k, bool(data[k]))
	_player.set("missiles", int(data.get("missiles", 0)))
	if _player.has_method("restore_grafts"):
		var owned: Variant = data.get("owned", [])
		var cap := int(data.get("graft_capacity", 4))
		_player.restore_grafts(owned if owned is Array else [], cap)


func save_progress() -> void:
	if _player == null:
		return
	var ab := {}
	for k in ["has_charge", "has_ice", "has_wave", "has_missiles",
			"has_double_jump", "has_dash", "has_wall_jump", "has_slide"]:
		ab[k] = bool(_player.get(k))
	var vis := []
	for r in _visited:
		vis.append(r)
	SaveSystem.save({
		"abilities": ab,
		"owned": _player.owned_keys() if _player.has_method("owned_keys") else [],
		"graft_capacity": int(_player.get("graft_capacity")),
		"charge_active": bool(_player.get("charge_active")),
		"ice_active": bool(_player.get("ice_active")),
		"wave_active": bool(_player.get("wave_active")),
		"missiles": int(_player.get("missiles")),
		"current_room": _current_room,
		"checkpoint": [_checkpoint.x, _checkpoint.y],
		"visited": vis,
	})


func _respawn() -> void:
	if _player == null:
		return
	(_player as Node2D).global_position = _checkpoint
	if _player is CharacterBody2D:
		(_player as CharacterBody2D).velocity = Vector2.ZERO
	_player.set("health", int(_player.get("max_health")))


func _find_camera(n: Node) -> Camera2D:
	if n is Camera2D:
		return n
	for c in n.get_children():
		var r := _find_camera(c)
		if r != null:
			return r
	return null

# ===========================================================================
# GEOMETRY HELPERS (same idiom as level_one)
# ===========================================================================

func _slab(x0: float, x1: float, top: float, bottom: float, color_hex := C_FLOOR) -> void:
	if x1 <= x0 or bottom <= top:
		return
	var center := Vector2((x0 + x1) * 0.5, (top + bottom) * 0.5)
	var size := Vector2(x1 - x0, bottom - top)
	var body := StaticBody2D.new()
	body.position = center
	body.collision_layer = 1
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
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)])
	poly.color = Color(color_hex)
	body.add_child(poly)


func _frame(x0: float, x1: float, top: float, bottom: float, left_door: bool, right_door: bool,
		left_door_y := 0.0, right_door_y := 0.0) -> void:
	var dh := 3.0 * T
	_slab(x0, x1, top, top + T, C_WALL)
	if left_door:
		_slab(x0, x0 + T, top, left_door_y - dh, C_WALL)
		_slab(x0, x0 + T, left_door_y, bottom, C_WALL)
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


func map_rooms() -> Dictionary:
	return _rooms
