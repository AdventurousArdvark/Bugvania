extends Node2D
class_name World
## ONE COHESIVE WORLD — not separate levels. A single coordinate space that owns the
## shared systems (Game, Music, Ambiance, HUD, loadout, player, camera, save) and the
## global room registry. Region MODULES (mod_intro / mod_hollow / mod_glimmerwet) just
## lay their geometry and entities into this space at fixed world coordinates and
## register their rooms; walking between them is seamless room-to-room flow, like
## Super Metroid. The Intro is the prologue you descend out of into the world proper.
##
## Setup: new scene, root Node2D, attach this script, set player_scene to player.tscn
## (with a Camera2D child). Press play. Modules build everything else.

const C_FLOOR := "#2b2620"
const C_WALL := "#211b16"

@export var tile: float = 32.0
@export var player_scene: PackedScene
@export var show_labels: bool = true

var T: float
var _rooms: Dictionary = {}
var _entries: Dictionary = {}
var _region_of: Dictionary = {}
var _apex_rooms: Dictionary = {}
var _visited: Dictionary = {}
var _current_room: String = ""
var _current_region: String = ""
var _checkpoint: Vector2
var _player: Node2D = null
var _cam: Camera2D = null
var _hud = null
var _music: Music = null
var _boss_music: Music = null
var _start_room: String = ""
var _start_spawn: Vector2 = Vector2.ZERO

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
	# Lay the world out, left-to-right + up, in one continuous space.
	ModIntro.build(self)
	ModHollow.build(self)
	ModGlimmerwet.build(self)
	_spawn_player()

# ===========================================================================
# PUBLIC BUILD API (modules call these)
# ===========================================================================

func set_spawn(room_name: String, pos: Vector2) -> void:
	_start_room = room_name
	_start_spawn = pos

func register_room(room_name: String, rect: Rect2, entry: Vector2, region_id: String) -> void:
	_rooms[room_name] = rect
	_entries[room_name] = entry
	_region_of[room_name] = region_id
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

# A removable gate (arena seal). Returns the node so it can be freed on clear.
func make_seal(rect: Rect2, color := Color(0.5, 0.16, 0.16, 0.85)) -> StaticBody2D:
	var s := StaticBody2D.new()
	s.position = rect.position + rect.size * 0.5
	s.collision_layer = 1
	add_child(s)
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = rect.size
	cs.shape = rs
	s.add_child(cs)
	var p := Polygon2D.new()
	var hw := rect.size.x * 0.5
	var hh := rect.size.y * 0.5
	p.polygon = PackedVector2Array([Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)])
	p.color = color
	s.add_child(p)
	return s

# Register an apex: the arena room wakes it (+ boss music); its death frees the seal,
# banners the reward, and saves. (The apex itself harvests the graft.)
func register_apex(room_name: String, apex: Node, seal: Node, banner_name: String, banner_sub: String) -> void:
	_apex_rooms[room_name] = apex
	if apex.has_signal("cleared"):
		apex.cleared.connect(func(): _on_apex_cleared(seal, banner_name, banner_sub))

func _on_apex_cleared(seal: Node, banner_name: String, banner_sub: String) -> void:
	set_boss_music(false)
	if seal != null and is_instance_valid(seal):
		var t := create_tween()
		t.tween_property(seal, "modulate:a", 0.0, 0.4)
		t.tween_callback(seal.queue_free)
	get_tree().call_group("game", "region_banner", banner_name, banner_sub, Color(0.62, 0.84, 0.54))
	save_progress()

# ===========================================================================
# ROOM FLOW
# ===========================================================================

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
	var rid: String = _region_of.get(room_name, "")
	if rid != _current_region:
		_current_region = rid
		var info := _region_info(rid)
		get_tree().call_group("ambiance", "set_tint", info["tint"])
		if info["name"] != "":
			get_tree().call_group("game", "region_banner", info["name"], info["sub"], Color(0.62, 0.84, 0.54))
	if not first:
		get_tree().call_group("game", "room_fade")
	if knocked:
		return
	_checkpoint = _entries[room_name]
	if _apex_rooms.has(room_name) and is_instance_valid(_apex_rooms[room_name]):
		_apex_rooms[room_name].engage()
		set_boss_music(true)
	else:
		set_boss_music(false)
	if not first:
		save_progress()

func _region_info(id: String) -> Dictionary:
	if id == "intro":
		return {"name": "CONTAINMENT", "sub": "specimen seven is awake", "tint": Color(0.18, 0.22, 0.27, 0.12)}
	var r := Regions.by_id(id)
	if not r.is_empty():
		return {"name": r.get("name", ""), "sub": r.get("sub", ""), "tint": r.get("tint", Color(0.3, 0.3, 0.3, 0.1))}
	return {"name": "", "sub": "", "tint": Color(0.3, 0.3, 0.3, 0.1)}

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
	var spawn := _start_spawn
	var start_room := _start_room
	if not data.is_empty():
		var cp: Variant = data.get("checkpoint", null)
		if cp is Array and (cp as Array).size() == 2:
			spawn = Vector2(float(cp[0]), float(cp[1]))
		var sr := str(data.get("current_room", _start_room))
		if _rooms.has(sr):
			start_room = sr
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
		label(spawn + Vector2(-3.0 * T, -2.0 * T), "▶ set player_scene to spawn here")
	if _cam != null:
		_cam.position_smoothing_enabled = true
		_cam.position_smoothing_speed = 6.0
		_cam.limit_smoothed = true
	if start_room != "":
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
	Codex.load_array(data.get("logs", []))

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
		"logs": Codex.to_array(),
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
# GEOMETRY HELPERS (public; modules build through these)
# ===========================================================================

func slab(x0: float, x1: float, top: float, bottom: float, color_hex := C_FLOOR) -> void:
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
	poly.polygon = PackedVector2Array([Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)])
	poly.color = Color(color_hex)
	body.add_child(poly)

func frame(x0: float, x1: float, top: float, bottom: float, left_door: bool, right_door: bool,
		left_door_y := 0.0, right_door_y := 0.0, wall_hex := C_WALL) -> void:
	var dh := 3.0 * T
	slab(x0, x1, top, top + T, wall_hex)
	if left_door:
		slab(x0, x0 + T, top, left_door_y - dh, wall_hex)
		slab(x0, x0 + T, left_door_y, bottom, wall_hex)
	else:
		slab(x0, x0 + T, top, bottom, wall_hex)
	if right_door:
		slab(x1 - T, x1, top, right_door_y - dh, wall_hex)
		slab(x1 - T, x1, right_door_y, bottom, wall_hex)
	else:
		slab(x1 - T, x1, top, bottom, wall_hex)

func label(pos: Vector2, text: String, size := 13) -> void:
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
