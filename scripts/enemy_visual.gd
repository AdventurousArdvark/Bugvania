extends Node2D
class_name EnemyVisual
## A procedural, idle-animated creature drawn on top of an enemy's grey-box body.
##
## This is PURELY COSMETIC. The CharacterBody2D parent owns collision, behavior,
## and the telegraph tints (parent.modulate flows down to this node, so windup
## flashes and the freeze tint still work). It reads the parent's velocity to face
## the way it moves. Because it's a self-contained child node, you can later delete
## it and parent an AnimatedSprite2D in the same spot with zero gameplay changes.

@export var kind: String = "crawler"     # crawler | charger | flyer | spitter
@export var base_color: Color = Color("#c0432f")
@export var box: Vector2 = Vector2(24, 24)

var face: int = 1
var pose: String = ""          # behavior sets this: swoop | windup | rush | charge
var _t: float = 0.0
var _r: float = 0.0            # eased 0..1 intensity of the current tense pose

# Palette + breath, recomputed per draw.
var _body: Color
var _dark: Color
var _darker: Color
var _light: Color
var _eye: Color
var _br: float = 1.0

func _process(delta: float) -> void:
	_t += delta
	_r = move_toward(_r, 1.0 if pose != "" else 0.0, delta * 9.0)
	var p := get_parent()
	if p is CharacterBody2D and absf((p as CharacterBody2D).velocity.x) > 5.0:
		face = -1 if (p as CharacterBody2D).velocity.x < 0.0 else 1
	queue_redraw()

func _draw() -> void:
	if box == Vector2.ZERO:
		return
	_body = base_color
	_dark = base_color.darkened(0.42)
	_darker = base_color.darkened(0.66)
	_light = base_color.lightened(0.38)
	_br = 1.0 + 0.05 * sin(_t * 2.0)
	match kind:
		"flyer":   _eye = Color("#bff0ff")
		"charger": _eye = Color("#ff5a3c")
		"spitter": _eye = Color("#d6ff5e")
		_:         _eye = Color("#ffd24a")
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(float(face), 1.0))
	match kind:
		"flyer":   _draw_flyer()
		"charger": _draw_charger()
		"spitter": _draw_spitter()
		_:         _draw_crawler()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ---- shared shape helpers ------------------------------------------------

func _oval(ctr: Vector2, rx: float, ry: float, col: Color, segs: int = 18) -> void:
	var pts := PackedVector2Array()
	for i in segs:
		var a := TAU * float(i) / float(segs)
		pts.append(ctr + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)

func _leg(hip: Vector2, ang: float, l1: float, l2: float, wig: float, col: Color, w: float) -> void:
	var knee := hip + Vector2(cos(ang), sin(ang)) * l1
	var foot := knee + Vector2(cos(ang + 0.55 + wig), sin(ang + 0.55 + wig)) * l2
	draw_line(hip, knee, col, w)
	draw_line(knee, foot, col, w)

func _antenna(root: Vector2, col: Color, phase: float) -> void:
	var sway := sin(_t * 3.0 + phase) * 0.20
	var p1 := root + Vector2(box.x * 0.16, -box.y * 0.30)
	var p2 := p1 + Vector2(box.x * 0.14, -box.y * 0.34).rotated(sway)
	draw_polyline(PackedVector2Array([root, p1, p2]), col, 1.5)
	draw_circle(p2, 1.8, col)

func _eyeball(ctr: Vector2, r: float) -> void:
	draw_circle(ctr, r * 1.5, Color(_eye.r, _eye.g, _eye.b, 0.25))   # glow
	draw_circle(ctr, r, _eye)
	draw_circle(ctr - Vector2(r * 0.3, r * 0.3), r * 0.35, Color(1, 1, 1, 0.85))

# ---- creatures -----------------------------------------------------------

func _draw_crawler() -> void:
	var hw := box.x * 0.5
	var hh := box.y * 0.5
	# Legs (behind body), fanning down with a walking wiggle.
	for i in 4:
		var lx := lerpf(-hw * 0.55, hw * 0.5, float(i) / 3.0)
		var hip := Vector2(lx, hh * 0.25)
		var ang := PI * 0.5 + (float(i) - 1.5) * 0.16
		var wig := sin(_t * 9.0 + float(i) * 1.5) * 0.22
		_leg(hip, ang, hh * 0.55, hh * 0.55, wig, _darker, 2.2)
	# Abdomen.
	_oval(Vector2(-hw * 0.12, 0.0), hw * 0.95, hh * 0.82 * _br, _body)
	# Carapace highlight + segment seams.
	_oval(Vector2(-hw * 0.18, -hh * 0.22), hw * 0.62, hh * 0.34, _light)
	for s in 2:
		draw_arc(Vector2(-hw * 0.12, hh * 0.1), hw * (0.5 - 0.16 * float(s)), PI * 1.15, PI * 1.85, 10, _darker, 1.5)
	# Head + face.
	_oval(Vector2(hw * 0.72, -hh * 0.04), hw * 0.34, hh * 0.42, _dark)
	_eyeball(Vector2(hw * 0.82, -hh * 0.12), hh * 0.16)
	draw_line(Vector2(hw * 1.0, hh * 0.02), Vector2(hw * 1.22, -hh * 0.04), _darker, 1.6)
	draw_line(Vector2(hw * 1.0, hh * 0.14), Vector2(hw * 1.22, hh * 0.2), _darker, 1.6)
	_antenna(Vector2(hw * 0.82, -hh * 0.34), _darker, 0.0)
	_antenna(Vector2(hw * 0.7, -hh * 0.36), _darker, 1.2)

func _draw_charger() -> void:
	var hw := box.x * 0.5
	var hh := box.y * 0.5
	var wind := _r if pose == "windup" else 0.0     # crouch + splay (anticipation)
	var rush := _r if pose == "rush" else 0.0        # stretch + lunge forward
	# Heavy planted legs; splay and dig during windup, sweep back during the rush.
	for i in 4:
		var lx := lerpf(-hw * 0.6, hw * 0.55, float(i) / 3.0)
		var hip := Vector2(lx, hh * 0.35)
		var wig := sin(_t * 4.0 + float(i) * 1.7) * 0.10
		var spread := (float(i) - 1.5) * (0.1 + 0.18 * wind) - rush * 0.5
		_leg(hip, PI * 0.5 + spread, hh * (0.5 + 0.18 * wind), hh * 0.5, wig, _darker, 3.4)
	# Armored shell: squashes low on windup, lunges forward on rush.
	var bx := hw * 1.0 * (1.0 + 0.14 * rush)
	var by := hh * 0.92 * _br * (1.0 - 0.12 * wind)
	var cx := hw * (-0.05 + 0.14 * rush)
	var cy := hh * (0.05 + 0.08 * wind)
	_oval(Vector2(cx, cy), bx, by, _dark)
	_oval(Vector2(cx - hw * 0.05, cy - hh * 0.33), hw * 0.78, hh * 0.4, _body)        # ridge
	_oval(Vector2(cx - hw * 0.15, cy - hh * 0.47), hw * 0.5, hh * 0.22, _light)       # highlight
	for s in 3:
		var rx := cx - hw * 0.45 + float(s) * hw * 0.42
		draw_line(Vector2(rx, cy - hh * 0.55), Vector2(rx, cy + hh * 0.45), _darker, 2.0)
	# Ramming horn thrusts forward as it commits to the charge.
	var hx := hw * (0.6 + 0.25 * rush)
	draw_colored_polygon(PackedVector2Array([
		Vector2(hx, -hh * 0.34), Vector2(hx + hw * 0.7, 0.0), Vector2(hx, hh * 0.3),
	]), _light)
	draw_polyline(PackedVector2Array([
		Vector2(hx, -hh * 0.34), Vector2(hx + hw * 0.7, 0.0), Vector2(hx, hh * 0.3),
	]), _darker, 1.5)
	# Angry eye glares brighter the more wound up it is.
	draw_circle(Vector2(hw * 0.5, -hh * 0.18), hh * 0.13 * (1.0 + 0.4 * _r), Color(_eye.r, _eye.g, _eye.b, 0.25 + 0.4 * _r))
	_eyeball(Vector2(hw * 0.5, -hh * 0.18), hh * 0.13)

func _draw_flyer() -> void:
	var hw := box.x * 0.5
	var hh := box.y * 0.5
	var sw := _r                                   # flyer's only tense pose is the swoop
	var flap := 0.5 + 0.5 * sin(_t * 20.0)
	flap = lerpf(flap, 1.0, sw)                     # snap wings wide + stiff when diving
	# Two wings (far then near) behind the body, fluttering.
	_wing(Vector2(-hw * 0.05, -hh * 0.05), flap * 0.85, Color(_light.r, _light.g, _light.b, 0.45))
	_wing(Vector2(hw * 0.05, -hh * 0.1), flap, Color(_body.r, _body.g, _body.b, 0.7))
	# Dangling legs sway under the body; they trail backward in a dive.
	for i in 3:
		var lx := lerpf(-hw * 0.3, hw * 0.3, float(i) / 2.0)
		var wig := sin(_t * 6.0 + float(i) * 1.1) * 0.3
		_leg(Vector2(lx, hh * 0.3), PI * 0.5 + sw * 0.7, hh * 0.4, hh * 0.4, wig, _darker, 1.6)
	# Teardrop body (stretches slightly into the dive).
	_oval(Vector2(hw * 0.12 * sw, 0.0), hw * (0.55 + 0.12 * sw), hh * 0.66 * _br, _body)
	_oval(Vector2(-hw * 0.1, -hh * 0.2), hw * 0.3, hh * 0.26, _light)
	# Head + big eyes.
	_oval(Vector2(hw * 0.45, -hh * 0.1), hw * 0.3, hh * 0.34, _dark)
	_eyeball(Vector2(hw * 0.55, -hh * 0.16), hh * 0.18)
	_antenna(Vector2(hw * 0.45, -hh * 0.4), _darker, 0.0)

func _wing(base: Vector2, flap: float, col: Color) -> void:
	var tip := base + Vector2(-box.x * 0.45, -box.y * 0.85 * flap)
	var mid := base + Vector2(box.x * 0.18, -box.y * 0.35 * flap)
	draw_colored_polygon(PackedVector2Array([base, tip, mid]), col)
	draw_polyline(PackedVector2Array([base, tip, mid, base]), col.darkened(0.25), 1.4)

func _draw_spitter() -> void:
	var hw := box.x * 0.5
	var hh := box.y * 0.5
	# Little gripping feet.
	for i in 4:
		var lx := lerpf(-hw * 0.6, hw * 0.6, float(i) / 3.0)
		var wig := sin(_t * 5.0 + float(i)) * 0.12
		_leg(Vector2(lx, hh * 0.55), PI * 0.5 + (float(i) - 1.5) * 0.22, hh * 0.3, hh * 0.25, wig, _darker, 2.0)
	# Bloated sac.
	_oval(Vector2(0.0, 0.0), hw * 1.0 * _br, hh * 1.0 * _br, _body)
	# Pulsing inner core (glows as it "charges").
	var corep := 0.3 + 0.3 * sin(_t * 3.0)
	_oval(Vector2(hw * 0.1, hh * 0.05), hw * 0.5, hh * 0.5, Color(_eye.r, _eye.g, _eye.b, corep))
	# Pustules.
	for pp in [Vector2(-hw * 0.4, -hh * 0.3), Vector2(-hw * 0.1, -hh * 0.5), Vector2(hw * 0.3, -hh * 0.35)]:
		draw_circle(pp, hh * 0.12, _light)
	# Maw at the front the shot comes from; flares as it charges.
	var ch := _r if pose == "charge" else 0.0
	_oval(Vector2(hw * 0.85, 0.0), hw * 0.22, hh * 0.28, _darker)
	var mp := 0.6 + 0.4 * sin(_t * 6.0)
	if ch > 0.0:
		draw_circle(Vector2(hw * 0.9, 0.0), hh * (0.16 + 0.18 * ch), Color(_eye.r, _eye.g, _eye.b, 0.4 * ch))
	draw_circle(Vector2(hw * 0.9, 0.0), hh * 0.1 * (1.0 + 0.6 * ch), Color(_eye.r, _eye.g, _eye.b, clampf(mp + 0.4 * ch, 0.0, 1.0)))
	# A couple of small eyes.
	_eyeball(Vector2(hw * 0.2, -hh * 0.35), hh * 0.1)
	_eyeball(Vector2(-hw * 0.15, -hh * 0.4), hh * 0.08)
