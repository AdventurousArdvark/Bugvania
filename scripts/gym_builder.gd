extends Node2D

## GYM BUILDER  -  Phase 1 feel-test apparatus, generated in code.

##

## USAGE

##   1. New scene, root = Node2D (or add a Node2D to an existing scene).

##   2. Attach this script.

##   3. (Optional) Set `player_scene` to your player.tscn to auto-spawn it.

##   4. Set `block` to match your world's tile size if you like (default 32).

##   5. Press play.

##

## Everything is measured in BLOCKS so each section is a ruler, not decoration:

##   - Staircase steps are 1..6 blocks tall  -> read which step your jump clears.

##   - Gaps are 2 / 4 / 6 blocks wide        -> read how far a dash-jump carries.

## This whole scene is DISPOSABLE. It exists to tune numbers, then you delete it.

 

const WORLD_LAYER := 1   # matches the "World" 2D physics layer from Phase 0

 

# Section colors, just so the diagnostic reads at a glance.

const C_FLOOR  := "#2b3a4a"

const C_STAIR  := "#2f7d72"

const C_WALL   := "#5b4b8a"

const C_GAP    := "#c8763a"

const C_TUNNEL := "#a13b3b"

const C_PERCH  := "#c8a83a"

 

@export var block: float = 32.0          # one "block" in pixels

@export var show_labels: bool = true

@export var player_scene: PackedScene    # leave empty to just get a spawn marker

 

var _floor_h: float

var _spawn_at: Vector2

 

 

func _ready() -> void:

				_floor_h = block * 2.0

				_build()

 

 

func _build() -> void:

				var x := 0.0

 

				# --- RUNWAY: ground accel / friction / top speed (wider than one screen) ---

				var run_len := block * 28.0

				_floor(x, x + run_len, Color(C_FLOOR))

				_label(Vector2(x + block, -block * 4.0), "RUNWAY  ·  accel / friction / top speed")

				_spawn_at = Vector2(x + block * 3.0, -block * 3.0)

				x += run_len

 

				# --- STAIRCASE: jump-height ruler, steps rising 1..6 blocks ---

				var stair_len := block * 18.0

				_floor(x, x + stair_len, Color(C_FLOOR))

				_label(Vector2(x + block, -block * 8.5), "STAIRCASE  ·  jump height (which step do you clear?)")

				var sx := x + block * 2.0

				for i in range(1, 7):

								var h := block * float(i)

								var w := block * 2.0

								_solid(Vector2(sx + w * 0.5, -h * 0.5), Vector2(w, h), Color(C_STAIR))

								_label(Vector2(sx, -h - block * 0.7), "%d blk" % i, 11)

								sx += w + block * 0.6

				x += stair_len

 

				# --- WALL-JUMP SHAFT: two facing walls with a narrow gap ---

				var shaft_len := block * 8.0

				_floor(x, x + shaft_len, Color(C_FLOOR))

				_label(Vector2(x + block, -block * 13.5), "WALL SHAFT  ·  wall slide + climb rhythm")

				var wall_h := block * 12.0

				var wall_w := block

				var shaft_gap := block * 3.0

				var left_x := x + block * 2.0

				_solid(Vector2(left_x + wall_w * 0.5, -wall_h * 0.5), Vector2(wall_w, wall_h), Color(C_WALL))

				var right_x := left_x + wall_w + shaft_gap

				_solid(Vector2(right_x + wall_w * 0.5, -wall_h * 0.5), Vector2(wall_w, wall_h), Color(C_WALL))

				x += shaft_len

 

				# --- GAP GAUNTLET: landing pads split by gaps of known width ---

				_label(Vector2(x + block, -block * 4.0), "GAP GAUNTLET  ·  dash-jump distance")

				var pad_w := block * 4.0

				_floor(x, x + pad_w, Color(C_GAP))   # first landing pad

				x += pad_w

				for g in [2, 4, 6]:

								var gw := block * float(g)

								_label(Vector2(x + gw * 0.25, -block * 1.3), "gap %d blk" % g, 11)

								x += gw                          # the gap = no floor here

								_floor(x, x + pad_w, Color(C_GAP))

								x += pad_w

 

				# --- LOW TUNNEL: slide test. Ceiling sits 1.5 blocks above the floor. ---

				# NOTE: the slide doesn't shrink the collider yet (dual-shape work is later),

				# so you can't fit under this until you add that. It's a placed marker for now.

				var tunnel_len := block * 12.0

				_floor(x, x + tunnel_len, Color(C_FLOOR))

				_label(Vector2(x + block, -block * 4.0), "LOW TUNNEL  ·  slide (ceiling 1.5 blk)")

				var ceil_clear := block * 1.5

				var ceil_h := block * 2.0

				var ceil_w := tunnel_len - block * 2.0

				var ceil_cx := x + block + ceil_w * 0.5

				_solid(Vector2(ceil_cx, -ceil_clear - ceil_h * 0.5), Vector2(ceil_w, ceil_h), Color(C_TUNNEL))

				x += tunnel_len

 

				# --- HIGH PERCH: reachable only by chaining tech (wall-jump -> dash) ---

				var perch_len := block * 10.0

				_floor(x, x + perch_len, Color(C_FLOOR))

				_label(Vector2(x + block, -block * 7.5), "HIGH PERCH  ·  wall-jump → dash chain")

				var kick_h := block * 6.0

				_solid(Vector2(x + block * 2.0, -kick_h * 0.5), Vector2(wall_w, kick_h), Color(C_WALL))

				var perch_pw := block * 4.0

				_solid(Vector2(x + block * 6.0 + perch_pw * 0.5, -block * 5.0), Vector2(perch_pw, block * 0.8), Color(C_PERCH))

 

				_spawn_player()

 

 

# --- helpers ---------------------------------------------------------------

 

func _solid(center: Vector2, size: Vector2, color: Color) -> void:

				var body := StaticBody2D.new()

				body.position = center

				body.collision_layer = WORLD_LAYER

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

								Vector2(-hw, -hh), Vector2(hw, -hh),

								Vector2(hw, hh), Vector2(-hw, hh),

				])

				poly.color = color

				body.add_child(poly)

 

 

# Floor segment whose TOP surface sits at y = 0 (where the player stands).

func _floor(x0: float, x1: float, color: Color) -> void:

				_solid(Vector2((x0 + x1) * 0.5, _floor_h * 0.5), Vector2(x1 - x0, _floor_h), color)

 

 

func _label(pos: Vector2, text: String, size := 13) -> void:

				if not show_labels:

								return

				var lbl := Label.new()

				lbl.text = text

				lbl.position = pos

				lbl.add_theme_font_size_override("font_size", size)

				lbl.add_theme_color_override("font_color", Color("#e8e8e8"))

				add_child(lbl)

 

 

func _spawn_player() -> void:

				if player_scene == null:

								var marker := Marker2D.new()

								marker.position = _spawn_at

								add_child(marker)

								_label(_spawn_at + Vector2(-block * 1.5, -block * 1.5),

												"▶ spawn  (set player_scene to auto-spawn)", 11)

								return

				var p := player_scene.instantiate()

				if p is Node2D:

								(p as Node2D).position = _spawn_at

				add_child(p)
