extends Node2D
class_name BossVisual
## THE BROODMOTHER, drawn procedurally to match the player/enemy visual language but
## grander: a pulsing egg-sac full of glowing larvae, an armored thorax, six heavy
## legs, two raptorial scythe-arms that rear up to telegraph and slam on the lunge,
## and a cluster of eyes. Reacts to the boss state machine and shifts into phase 2.
##
## Cosmetic only. The boss owns logic and the telegraph tints (parent.modulate flows
## down). Boss sets `pose`, `phase2`, and `face` each frame.

@export var base_color: Color = Color("#7a3b8f")     # broodmother purple
@export var box: Vector2 = Vector2(64, 44)

var pose: String = "dormant"     # dormant | idle | windup | lunge | volley | stagger
var phase2: bool = false
var face: int = -1
var flying: bool = false          # airborne second phase: big wings, tucked legs
var beam_charge: float = 0.0      # 0..1 telegraph
var beam_on: bool = false
var beam_from: Vector2 = Vector2.ZERO   # muzzle offset from boss origin (world-oriented)
var beam_dir: Vector2 = Vector2.RIGHT
var beam_len: float = 640.0
var beam_width: float = 12.0

var _t: float = 0.0
var _raise: float = 0.2          # scythe-arm raise (-1 slam .. +1 reared)
var _lean: float = 0.0           # body lean (+ forward)
var _wake: float = 0.0           # 0 dormant .. 1 active
var _ph: float = 0.0             # phase-2 ease

var _dark: Color
var _darker: Color
var _light: Color
var _membrane: Color
const EGGS := [Vector2(-0.3, -0.4), Vector2(0.2, -0.2), Vector2(-0.1, 0.1),
	Vector2(0.35, 0.25), Vector2(-0.4, 0.3), Vector2(0.05, 0.45), Vector2(-0.15, -0.7)]

func _process(delta: float) -> void:
	_t += delta
	var tr := 0.2
	var tl := 0.0
	match pose:
		"windup":  tr = 1.0;  tl = -0.4
		"lunge":   tr = -1.0; tl = 0.6
		"volley":  tr = 0.6;  tl = -0.1
		"stagger": tr = -0.7; tl = 0.25
		"dormant": tr = -0.3; tl = 0.0
	var k := clampf(delta * 10.0, 0.0, 1.0)
	_raise = lerpf(_raise, tr, k)
	_lean = lerpf(_lean, tl, k)
	_wake = lerpf(_wake, 0.0 if pose == "dormant" else 1.0, clampf(delta * 4.0, 0.0, 1.0))
	_ph = lerpf(_ph, 1.0 if phase2 else 0.0, clampf(delta * 3.0, 0.0, 1.0))
	queue_redraw()

func _draw() -> void:
	_dark = base_color.darkened(0.42)
	_darker = base_color.darkened(0.66)
	_light = base_color.lightened(0.35)
	_membrane = base_color.lightened(0.25)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(float(face), 1.0))

	var hw := box.x * 0.5
	var hh := box.y * 0.5
	var breath := 1.0 + 0.04 * sin(_t * 1.6)
	var lean := _lean * hw * 0.35
	var curl := (1.0 - _wake) * hh * 0.5            # dormant: hunkers down

	# Egg colors shift from sickly green to angry red in phase 2.
	var egg_col := Color("#caff7a").lerp(Color("#ff5340"), _ph)
	var eye_col := Color("#ff6048").lerp(Color("#ff2a1c"), _ph)

	# --- egg sac (rear) ---
	var sac := Vector2(-hw * 0.95, hh * 0.15 + curl)
	_oval(sac, hw * 1.05 * breath, hh * 1.45 * breath, _dark)
	_oval(sac, hw * 0.92 * breath, hh * 1.3 * breath, Color(_membrane.r, _membrane.g, _membrane.b, 0.92))
	# Glowing larvae inside, pulsing; phase 2 lights more of them, faster.
	var lit_n := 4 + int(round(3.0 * _ph))
	for i in EGGS.size():
		var e: Vector2 = EGGS[i]
		var ep := sac + Vector2(e.x * hw * 0.9, e.y * hh * 1.25)
		var glow := 0.35 + 0.4 * sin(_t * (2.0 + _ph * 2.5) + float(i))
		var on := 1.0 if i < lit_n else 0.25
		draw_circle(ep, hh * 0.16, Color(egg_col.r, egg_col.g, egg_col.b, clampf(glow, 0.0, 1.0) * on * (0.5 + 0.5 * _wake)))
		draw_circle(ep, hh * 0.07, Color(egg_col.r, egg_col.g, egg_col.b, on * (0.4 + 0.5 * _wake)))

	# --- wings: ragged stubs on the ground, large flapping membranes in the air ---
	if flying:
		var flap := 0.45 + 0.55 * (0.5 + 0.5 * sin(_t * 9.0))
		for sgn in [0.85, 1.0]:
			var wb := Vector2(-hw * 0.1 + lean * 0.4, -hh * 0.4)
			var tip := wb + Vector2(-hw * 1.4 * sgn, -hh * (1.6 * flap + 0.2))
			var mid := wb + Vector2(hw * 0.3, -hh * 0.6 * flap)
			draw_colored_polygon(PackedVector2Array([wb, tip, mid]),
				Color(_membrane.r, _membrane.g, _membrane.b, 0.42))
			draw_polyline(PackedVector2Array([wb, tip, mid]), Color(_darker.r, _darker.g, _darker.b, 0.7), 1.5)
	else:
		for sgn in [-1.0, 1.0]:
			var wb := Vector2(-hw * 0.2 + lean * 0.4, -hh * 0.5 + curl)
			draw_colored_polygon(PackedVector2Array([
				wb, wb + Vector2(-hw * 0.5, -hh * 0.7 - sgn * hh * 0.2), wb + Vector2(hw * 0.1, -hh * 0.3),
			]), Color(_darker.r, _darker.g, _darker.b, 0.6))

	# --- six heavy legs (tuck up when airborne) ---
	var tuck := 1.0 if flying else 0.0
	for i in 6:
		var side := -1.0 if i < 3 else 1.0
		var lx := lerpf(-hw * 0.5, hw * 0.45, float(i % 3) / 2.0)
		var hip := Vector2(lx + lean * 0.3, hh * (0.55 - 0.25 * tuck) + curl)
		var wig := sin(_t * (3.0 + 3.0 * tuck) + float(i) * 1.3) * 0.12 * _wake
		var spread := (float(i % 3) - 1.0) * 0.5 + side * 0.15 - _raise * 0.2 + tuck * 0.5
		_leg(hip, PI * 0.5 + spread + wig, hh * (0.9 - 0.3 * tuck), hh * (0.8 - 0.3 * tuck), _darker, 3.5)

	# --- thorax ---
	var thx := Vector2(hw * 0.05 + lean, hh * 0.0 + curl * 0.5)
	_oval(thx, hw * 0.62 * breath, hh * 0.85 * breath, base_color)
	_oval(thx + Vector2(0, -hh * 0.35), hw * 0.42, hh * 0.3, _light)         # carapace sheen
	for s in 3:
		draw_arc(thx, hw * (0.3 + 0.13 * float(s)), PI * 1.1, PI * 1.9, 10, _darker, 2.0)

	# --- raptorial scythe-arms ---
	_scythe(Vector2(hw * 0.45 + lean, -hh * 0.1 + curl * 0.5), _raise, eye_col, 0.0)
	_scythe(Vector2(hw * 0.38 + lean, hh * 0.05 + curl * 0.5), _raise, eye_col, 0.18)

	# --- head + eye cluster + mandibles ---
	var head := Vector2(hw * 0.95 + lean, -hh * 0.25 + curl * 0.4)
	_oval(head, hw * 0.4, hh * 0.5, _dark)
	# Mandibles open a touch when winding up / spitting.
	var gape := (0.3 + 0.5 * maxf(_raise, 0.0)) * (0.5 + 0.5 * _wake)
	draw_line(head + Vector2(hw * 0.3, hh * 0.2), head + Vector2(hw * 0.62, hh * 0.05 + gape * hh * 0.4), _darker, 3.0)
	draw_line(head + Vector2(hw * 0.3, hh * 0.3), head + Vector2(hw * 0.62, hh * 0.45 - gape * hh * 0.2), _darker, 3.0)
	# Eye cluster: more eyes open in phase 2, all glow brighter when awake/tense.
	var eyes := [Vector2(0.1, -0.18), Vector2(0.28, -0.05), Vector2(0.05, 0.05), Vector2(0.3, 0.18)]
	var extra := [Vector2(0.18, -0.3), Vector2(0.42, 0.02)]
	var bright := (0.3 + 0.7 * _wake) * (0.7 + 0.3 * sin(_t * 4.0)) + 0.3 * maxf(_raise, 0.0)
	for e in eyes:
		_eye(head + Vector2(e.x * hw, e.y * hh), hh * 0.1, eye_col, bright)
	for e in extra:
		_eye(head + Vector2(e.x * hw, e.y * hh), hh * 0.09, eye_col, bright * _ph)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# --- sustained beam special (drawn world-aligned; boss feeds muzzle + dir) ---
	if beam_charge > 0.0 and not beam_on:
		# Charging: a swelling glow at the maw and a thin warning line along the path.
		draw_circle(beam_from, hh * 0.35 * beam_charge, Color(eye_col.r, eye_col.g, eye_col.b, 0.5 * beam_charge))
		draw_line(beam_from, beam_from + beam_dir * beam_len,
			Color(eye_col.r, eye_col.g, eye_col.b, 0.3 * beam_charge), 1.0 + 3.0 * beam_charge)
	if beam_on:
		var perp := Vector2(-beam_dir.y, beam_dir.x)
		var w := beam_width * (1.0 + 0.12 * sin(_t * 40.0))
		var a := beam_from
		var b := beam_from + beam_dir * beam_len
		# Outer glow, then bright core.
		draw_colored_polygon(PackedVector2Array([
			a + perp * w * 2.0, b + perp * w * 2.0, b - perp * w * 2.0, a - perp * w * 2.0,
		]), Color(eye_col.r, eye_col.g, eye_col.b, 0.25))
		draw_colored_polygon(PackedVector2Array([
			a + perp * w, b + perp * w, b - perp * w, a - perp * w,
		]), Color(eye_col.r, eye_col.g, eye_col.b, 0.85))
		draw_line(a, b, Color(1, 1, 1, 0.9), w * 0.5)
		draw_circle(a, w * 1.8, Color(eye_col.r, eye_col.g, eye_col.b, 0.7))

func _oval(ctr: Vector2, rx: float, ry: float, col: Color, segs: int = 22) -> void:
	var pts := PackedVector2Array()
	for i in segs:
		var a := TAU * float(i) / float(segs)
		pts.append(ctr + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)

func _leg(hip: Vector2, ang: float, l1: float, l2: float, col: Color, w: float) -> void:
	var knee := hip + Vector2(cos(ang), sin(ang)) * l1
	var foot := knee + Vector2(cos(ang - 0.7), sin(ang - 0.7)) * l2
	draw_line(hip, knee, col, w)
	draw_line(knee, foot, col, w * 0.8)
	draw_circle(foot, w * 0.5, col)

# A segmented raptorial arm ending in a curved blade. `raise` -1 slam .. +1 reared.
func _scythe(shoulder: Vector2, raise: float, glow: Color, phase: float) -> void:
	var jitter := sin(_t * 9.0 + phase) * 0.05 * maxf(raise, 0.0)
	var up := -0.6 - raise * 0.8 + jitter                  # upper-arm angle
	var elbow := shoulder + Vector2(cos(up), sin(up)) * box.y * 0.7
	draw_line(shoulder, elbow, _dark, 5.0)
	var fwd := up + 1.4 + raise * 0.3                       # forearm bends forward
	var wrist := elbow + Vector2(cos(fwd), sin(fwd)) * box.y * 0.6
	draw_line(elbow, wrist, _dark, 4.0)
	# Blade.
	var tip := wrist + Vector2(cos(fwd - 0.5), sin(fwd - 0.5)) * box.y * 0.7
	draw_colored_polygon(PackedVector2Array([
		wrist + Vector2(0, -box.x * 0.06), wrist + Vector2(0, box.x * 0.06), tip,
	]), _light)
	draw_line(wrist, tip, glow, 1.5)                        # glowing edge

func _eye(ctr: Vector2, r: float, col: Color, bright: float) -> void:
	bright = clampf(bright, 0.0, 1.0)
	draw_circle(ctr, r * 1.7, Color(col.r, col.g, col.b, 0.3 * bright))
	draw_circle(ctr, r, Color(col.r, col.g, col.b, 0.35 + 0.6 * bright))
