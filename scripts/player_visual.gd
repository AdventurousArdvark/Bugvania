extends Node2D
class_name PlayerVisual
## The protagonist, drawn procedurally on top of the grey-box body. Richer and more
## articulated than the enemies: a gait-cycling walk, antennae with lag, a blinking
## eye, a warm bioluminescent core, and — the signature of this game — GRAFTED PARTS
## that physically appear as you acquire abilities:
##   has_double_jump -> wings (fold at rest, flare in the air)
##   has_dash        -> a drill-blade foreleg (extends + spins on dash)
##   has_wall_jump   -> hooked gripping claws (splay when clinging)
##   has_missiles    -> a stinger on the abdomen
##   has_charge      -> a glowing gland that pulses
##
## Purely cosmetic: reads the player's state and flags, owns no logic. Swap an
## AnimatedSprite2D in here later with zero gameplay changes.

@export var base_color: Color = Color("#43607a")   # cool slate carapace
@export var accent: Color = Color("#ffd27a")        # warm bioluminescent core/eye
@export var rim: Color = Color("#bdf0ff")           # cool highlight
@export var box: Vector2 = Vector2(22, 34)

var _p: Node = null
var _t: float = 0.0
var _mrs: float = 260.0
var face: int = 1

# Eased state (0..1 unless noted).
var _lean: float = 0.0      # -1..1 horizontal lean
var _gait: float = 0.0      # walk-cycle phase
var _air: float = 0.0
var _dash: float = 0.0
var _wall: float = 0.0
var _slide: float = 0.0
var _spin: float = 0.0      # drill spin phase
var _blink: float = 0.0     # 1 = eye shut
var _blink_cd: float = 2.0

# palette, per draw
var _dark: Color
var _darker: Color
var _light: Color

func _ready() -> void:
	_p = get_parent()
	var m = _p.get("max_run_speed") if _p else null
	if typeof(m) == TYPE_FLOAT and float(m) > 0.0:
		_mrs = float(m)

func _process(delta: float) -> void:
	_t += delta
	if _p == null:
		return
	var v: Vector2 = _p.velocity
	var onf: bool = _p.is_on_floor()
	face = _p.get_facing()
	var dashing: bool = float(_p.get("_dash_timer")) > 0.0
	var sliding: bool = bool(_p.get("_is_sliding"))
	var walling: bool = bool(_p.get("_is_wall_sliding"))
	var spd := absf(v.x)

	var k := clampf(delta * 12.0, 0.0, 1.0)
	_air = lerpf(_air, 0.0 if onf else 1.0, k)
	_dash = lerpf(_dash, 1.0 if dashing else 0.0, clampf(delta * 16.0, 0.0, 1.0))
	_wall = lerpf(_wall, 1.0 if walling else 0.0, k)
	_slide = lerpf(_slide, 1.0 if sliding else 0.0, k)
	_lean = lerpf(_lean, clampf(v.x / _mrs, -1.0, 1.0), k)
	if onf and spd > 12.0 and not sliding:
		_gait += delta * (5.0 + spd * 0.03)
	else:
		_gait = lerpf(_gait, roundf(_gait / PI) * PI, k)   # settle feet to neutral
	_spin += delta * (6.0 + _dash * 40.0)

	# Blink occasionally.
	_blink_cd -= delta
	if _blink_cd <= 0.0:
		_blink = 1.0
		_blink_cd = randf_range(2.2, 4.5)
	_blink = maxf(0.0, _blink - delta * 9.0)

	queue_redraw()

func _has(flag: String) -> bool:
	return _p != null and _p.get(flag) == true

func _draw() -> void:
	if _p == null:
		return
	_dark = base_color.darkened(0.42)
	_darker = base_color.darkened(0.66)
	_light = base_color.lightened(0.40)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(float(face), 1.0))

	var hw := box.x * 0.5
	var hh := box.y * 0.5
	var lean := _lean * hw * 0.7                     # upper-body shear, in facing space
	var drop := _slide * hh * 0.42                   # body lowers when sliding
	var stretch := 1.0 + _slide * 0.35 + _dash * 0.18

	# Dash afterimages, behind everything.
	if _dash > 0.05:
		for g in 2:
			var gx := -float(g + 1) * hw * 0.5 * _dash
			_oval(Vector2(gx, drop), hw * 0.7, hh * 0.55, Color(rim.r, rim.g, rim.b, 0.10 * _dash))

	# --- grafted wings (behind body) ---
	if _has("has_double_jump"):
		var spread := lerpf(0.28, 1.0, _air)
		var flut := sin(_t * 24.0) * _air * 0.18
		_wing(Vector2(-hw * 0.2 + lean * 0.5, -hh * 0.2 + drop), spread + flut, 0.85)
		_wing(Vector2(-hw * 0.1 + lean * 0.5, -hh * 0.3 + drop), spread + flut * 0.7, 1.0)

	# --- abdomen + optional stinger ---
	_oval(Vector2(-hw * 0.5, hh * 0.12 + drop), hw * 0.62 * stretch, hh * 0.62, _dark)
	_oval(Vector2(-hw * 0.28, 0.02 * hh + drop), hw * 0.6 * stretch, hh * 0.66, base_color)
	for s in 2:
		draw_arc(Vector2(-hw * 0.4, hh * 0.05 + drop), hw * (0.42 - 0.13 * float(s)), PI * 1.15, PI * 1.9, 8, _darker, 1.5)
	if _has("has_missiles"):
		var tip := Vector2(-hw * 1.05, hh * 0.18 + drop)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-hw * 0.78, -hh * 0.05 + drop), Vector2(-hw * 0.78, hh * 0.35 + drop), tip,
		]), _darker)
		draw_circle(tip, hh * 0.07, Color(accent.r, accent.g, accent.b, 0.7 + 0.3 * sin(_t * 4.0)))

	# --- hind legs ---
	_gait_leg(Vector2(-hw * 0.25, hh * 0.5 + drop), 0.0, hh * 0.95, true)
	_gait_leg(Vector2(-hw * 0.05, hh * 0.52 + drop), PI, hh * 0.95, true)

	# --- thorax + bioluminescent core (cool, so it reads as body-light, not an eye) ---
	_oval(Vector2(hw * 0.18 + lean, -hh * 0.05 + drop), hw * 0.5 * stretch, hh * 0.58, base_color)
	_oval(Vector2(hw * 0.12 + lean, -hh * 0.24 + drop), hw * 0.34, hh * 0.26, _light)   # back highlight
	var corepulse := 0.55 + 0.25 * sin(_t * 3.0) + 0.4 * _dash
	var ccore := Vector2(hw * 0.12 + lean, hh * 0.06 + drop)
	draw_circle(ccore, hh * 0.2 * (1.0 + 0.35 * _dash), Color(rim.r, rim.g, rim.b, 0.18 * corepulse))
	draw_circle(ccore, hh * 0.07, Color(rim.r, rim.g, rim.b, clampf(corepulse, 0.0, 1.0)))

	# --- grafted charge gland ---
	if _has("has_charge"):
		var gp := 0.4 + 0.4 * sin(_t * 2.5)
		_oval(Vector2(-hw * 0.05 + lean * 0.6, -hh * 0.28 + drop), hw * 0.2, hh * 0.22, Color(rim.r, rim.g, rim.b, 0.4 + 0.4 * gp))

	# --- fore legs (one is the drill-arm if dash is grafted) ---
	if _has("has_dash"):
		_drill_arm(Vector2(hw * 0.4 + lean, hh * 0.2 + drop))
	else:
		_gait_leg(Vector2(hw * 0.38 + lean * 0.8, hh * 0.5 + drop), PI * 0.5, hh * 0.85, false)
	_gait_leg(Vector2(hw * 0.22 + lean * 0.8, hh * 0.52 + drop), PI * 1.5, hh * 0.85, false)

	# --- head, mandibles, eye, antennae ---
	var hpos := Vector2(hw * 0.7 + lean, -hh * 0.2 + drop)
	_oval(hpos, hw * 0.3, hh * 0.34, _dark)
	draw_line(hpos + Vector2(hw * 0.18, hh * 0.16), hpos + Vector2(hw * 0.46, hh * 0.08), _darker, 1.6)
	draw_line(hpos + Vector2(hw * 0.18, hh * 0.28), hpos + Vector2(hw * 0.46, hh * 0.26), _darker, 1.6)
	# Eye (blinks) — the single warm focal point.
	var epos := hpos + Vector2(hw * 0.1, -hh * 0.04)
	var er := hh * 0.15
	draw_circle(epos, er * 1.7, Color(accent.r, accent.g, accent.b, 0.22))
	if _blink < 0.5:
		draw_circle(epos, er, accent)
		draw_circle(epos - Vector2(er * 0.3, er * 0.35), er * 0.4, Color(1, 1, 1, 0.9))
	else:
		draw_line(epos + Vector2(-er, 0), epos + Vector2(er, 0), _darker, 2.0)
	# Antennae with lag (trail opposite to lean/motion).
	var aroot := hpos + Vector2(hw * 0.05, -hh * 0.34)
	_antenna(aroot, -0.2 - _lean * 0.5, 0.0)
	_antenna(aroot + Vector2(-hw * 0.12, hh * 0.02), -0.05 - _lean * 0.5, 1.3)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ---- helpers -------------------------------------------------------------

func _oval(ctr: Vector2, rx: float, ry: float, col: Color, segs: int = 18) -> void:
	var pts := PackedVector2Array()
	for i in segs:
		var a := TAU * float(i) / float(segs)
		pts.append(ctr + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)

# A walk-cycling leg. `phase` offsets the gait; airborne tucks the foot up.
func _gait_leg(hip: Vector2, phase: float, length: float, hind: bool) -> void:
	var swing := sin(_gait + phase) * 0.5
	var lift := maxf(0.0, sin(_gait + phase)) * 4.0
	# Tuck toward the body when airborne; sweep back when sliding.
	var base_ang := PI * 0.5 + (0.25 if hind else -0.2) + swing * 0.4 - _slide * 0.6
	base_ang -= _air * (0.5 if hind else 0.7)
	var knee := hip + Vector2(cos(base_ang), sin(base_ang)) * length * 0.5 * (1.0 - _air * 0.35)
	knee.y -= lift
	var foot_ang := base_ang + 0.5 + swing * 0.3
	var foot := knee + Vector2(cos(foot_ang), sin(foot_ang)) * length * 0.5 * (1.0 - _air * 0.35)
	draw_line(hip, knee, _darker, 2.2)
	draw_line(knee, foot, _darker, 2.2)
	# Grafted gripping claws.
	if _has("has_wall_jump"):
		var splay := 0.35 + _wall * 0.5
		draw_line(foot, foot + Vector2(cos(foot_ang - splay), sin(foot_ang - splay)) * length * 0.16, accent, 2.0)
		draw_line(foot, foot + Vector2(cos(foot_ang + splay), sin(foot_ang + splay)) * length * 0.16, accent, 2.0)
	else:
		draw_circle(foot, 1.6, _darker)

# The grafted drill foreleg: a spinning conical bore that extends on dash.
func _drill_arm(shoulder: Vector2) -> void:
	var reach := box.y * (0.5 + _dash * 0.7)
	var tip := shoulder + Vector2(reach, box.y * 0.08)
	var mid := shoulder + Vector2(reach * 0.55, box.y * 0.04)
	draw_line(shoulder, mid, _dark, 3.5)                  # upper arm
	# Drill cone.
	var w := box.x * 0.16
	draw_colored_polygon(PackedVector2Array([
		mid + Vector2(0, -w), mid + Vector2(0, w), tip,
	]), _light)
	# Spinning flutes.
	for i in 4:
		var ph := _spin + float(i) * 1.57
		var fx := mid.x + (tip.x - mid.x) * (0.2 + 0.18 * float(i))
		var fo := sin(ph) * w * 0.7
		draw_line(Vector2(fx, mid.y - w * 0.7), Vector2(fx, mid.y + w * 0.7), Color(rim.r, rim.g, rim.b, 0.5), 1.4)
	draw_circle(tip, 1.8, rim)

func _wing(base: Vector2, spread: float, scale: float) -> void:
	var tip := base + Vector2(-box.x * 0.5 * scale, -box.y * 0.9 * spread)
	var mid := base + Vector2(box.x * 0.05 * scale, -box.y * 0.35 * spread)
	var col := Color(rim.r, rim.g, rim.b, 0.30 + 0.15 * spread)
	draw_colored_polygon(PackedVector2Array([base, tip, mid]), col)
	draw_polyline(PackedVector2Array([base, tip, mid]), Color(rim.r, rim.g, rim.b, 0.6), 1.3)

func _antenna(root: Vector2, bend: float, phase: float) -> void:
	var sway := sin(_t * 2.5 + phase) * 0.14 + bend
	var p1 := root + Vector2(box.x * 0.2, -box.y * 0.28)
	var p2 := p1 + Vector2(box.x * 0.22, -box.y * 0.3).rotated(sway)
	var p3 := p2 + Vector2(box.x * 0.16, -box.y * 0.12).rotated(sway * 1.8)
	draw_polyline(PackedVector2Array([root, p1, p2, p3]), _light, 1.6)
	draw_circle(p3, 2.0, accent)
