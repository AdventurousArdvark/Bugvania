extends CanvasLayer
class_name LoadoutMenu
## Super Metroid-style loadout screen, themed as the bug reviewing its grafted parts.
## Opens on Tab (or the "map" action), pauses the game, and lets you navigate a grid
## of parts. Beam parts can be SUPPRESSED (toggled off) without losing them - the SM
## trick of deactivating a beam when you don't want it. Status parts just show as
## assembled. A small silhouette lights up the parts you've installed.
##
## Created and bound by the level. Reads the player live; toggles its *_active flags.

const TITLE   := Color("#9fd68a")
const SUB     := Color("#5f7a55")
const CHITIN  := Color("#5fa86b")
const DIM      := Color("#33513a")
const LOCKED  := Color("#1c2620")
const CRACK   := Color("#0e1612")
const GLYPH_LIT := Color("#d8f0c8")
const GLYPH_DIM := Color("#4a6a48")
const CURSOR  := Color("#d8f0c8")
const BG      := Color(0.02, 0.045, 0.03, 0.88)

var _player: Node = null
var _font: Font
var _open: bool = false
var _idx: int = 0
var _cols: int = 4
var _anim: float = 0.0
var _parts: Array = []
var _cell_rects: Array = []
var _draw_node: Control = null

class MenuDraw extends Control:
	var menu
	func _draw() -> void:
		if menu != null:
			menu._render(self)

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = ThemeDB.fallback_font
	_parts = [
		{"key": "has_charge",      "active": "charge_active", "name": "Charge Gland",      "glyph": "charge",  "desc": "Hold the trigger to overcharge one heavy lance."},
		{"key": "has_ice",         "active": "ice_active",    "name": "Frost Gland",       "glyph": "ice",     "desc": "Shots chill prey solid. Frozen prey is a platform."},
		{"key": "has_wave",        "active": "wave_active",   "name": "Resonant Membrane", "glyph": "wave",    "desc": "Shots phase through carapace and wall alike."},
		{"key": "has_missiles",    "active": "",              "name": "Stinger Pods",      "glyph": "missile", "desc": "Volatile pods. Burst armored growths and sealed ways."},
		{"key": "has_double_jump", "active": "",              "name": "Wing-Segment",      "glyph": "wing",    "desc": "A second beat of borrowed wings."},
		{"key": "has_dash",        "active": "",              "name": "Drill-Limb",        "glyph": "drill",   "desc": "A lunging bore. Crosses gaps and carries momentum."},
		{"key": "has_wall_jump",   "active": "",              "name": "Grip-Claws",        "glyph": "claw",    "desc": "Cling to walls; kick off to climb."},
		{"key": "has_slide",       "active": "",              "name": "Carapace-Roll",     "glyph": "roll",    "desc": "Tuck and slide low and fast."},
	]
	_draw_node = MenuDraw.new()
	(_draw_node as MenuDraw).menu = self
	_draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_draw_node)

func bind(player: Node) -> void:
	_player = player

func _process(delta: float) -> void:
	if _open:
		_anim += delta
		var mp := _draw_node.get_global_mouse_position()
		for i in _cell_rects.size():
			if _cell_rects[i].has_point(mp):
				_idx = i
		_redraw()

func _input(event: InputEvent) -> void:
	var toggle : bool = (InputMap.has_action("map") and event.is_action_pressed("map")) \
		or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB)
	if not _open:
		if toggle:
			_open_menu()
		return
	if toggle or event.is_action_pressed("ui_cancel"):
		_close_menu()
	elif event.is_action_pressed("ui_left"):
		_move(-1)
	elif event.is_action_pressed("ui_right"):
		_move(1)
	elif event.is_action_pressed("ui_up"):
		_move(-_cols)
	elif event.is_action_pressed("ui_down"):
		_move(_cols)
	elif event.is_action_pressed("ui_accept"):
		_toggle_current()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_toggle_current()

func _open_menu() -> void:
	_open = true
	add_to_group("modal")            # tells the Game manager not to fight us
	get_tree().paused = true
	Audio.play("charge_ready")
	_redraw()

func _close_menu() -> void:
	_open = false
	remove_from_group("modal")
	get_tree().paused = false
	_redraw()

func _move(d: int) -> void:
	_idx = clampi(_idx + d, 0, _parts.size() - 1)
	Audio.play("hit")

func _toggle_current() -> void:
	var part = _parts[_idx]
	if _has(part.key) and part.active != "":
		_player.set(part.active, not bool(_player.get(part.active)))
		Audio.play("charge_ready")
	else:
		Audio.play("hit")

func _redraw() -> void:
	if _draw_node != null:
		_draw_node.queue_redraw()

func _has(key: String) -> bool:
	return _player != null and _player.get(key) == true

# ---------------------------------------------------------------------------

func _render(c: Control) -> void:
	if not _open:
		return
	var sz := c.size
	c.draw_rect(Rect2(Vector2.ZERO, sz), BG)
	c.draw_string(_font, Vector2(0, sz.y * 0.13), "ASSEMBLY", HORIZONTAL_ALIGNMENT_CENTER, sz.x, 40, TITLE)
	c.draw_string(_font, Vector2(0, sz.y * 0.13 + 22), "grafted parts", HORIZONTAL_ALIGNMENT_CENTER, sz.x, 14, SUB)

	var cell := 66.0
	var gap := 18.0
	var gw := _cols * cell + (_cols - 1) * gap
	var gx := sz.x * 0.5 - gw * 0.5 - 80.0     # nudge left; silhouette sits on the right
	var gy := sz.y * 0.26
	_cell_rects.clear()
	for i in _parts.size():
		var cx := gx + (i % _cols) * (cell + gap)
		var cy := gy + (i / _cols) * (cell + gap)
		var r := Rect2(cx, cy, cell, cell)
		_cell_rects.append(r)
		_draw_cell(c, r, _parts[i], i == _idx)

	_draw_description(c, Vector2(gx, gy + 2.0 * (cell + gap) + 18.0), gw)
	_draw_silhouette(c, Vector2(sz.x * 0.80, sz.y * 0.42))

	c.draw_string(_font, Vector2(0, sz.y - 26), "arrows move  ·  enter suppress/restore  ·  tab close",
		HORIZONTAL_ALIGNMENT_CENTER, sz.x, 13, Color(SUB.r, SUB.g, SUB.b, 0.7))

func _draw_cell(c: Control, r: Rect2, part: Dictionary, sel: bool) -> void:
	var acq := _has(part.key)
	var togg: bool = part.active != ""
	var act: bool = togg and bool(_player.get(part.active))
	var lit := acq and (not togg or act)

	var fill := CHITIN if lit else (DIM if acq else LOCKED)
	_hex(c, r, fill)
	if not acq:
		c.draw_line(r.position + Vector2(r.size.x * 0.3, r.size.y * 0.3),
			r.position + Vector2(r.size.x * 0.7, r.size.y * 0.7), CRACK, 1.5)
	_glyph(c, r.get_center(), part.glyph, GLYPH_LIT if lit else GLYPH_DIM)
	if sel:
		var a := 0.6 + 0.4 * sin(_anim * 6.0)
		var o := r.grow(3.0)
		c.draw_rect(o, Color(CURSOR.r, CURSOR.g, CURSOR.b, a), false, 2.0)

func _draw_description(c: Control, pos: Vector2, w: float) -> void:
	var part = _parts[_idx]
	var acq := _has(part.key)
	var togg: bool = part.active != ""
	var status := ""
	var scol := SUB
	if not acq:
		status = "DORMANT — not yet assembled"
		scol = Color("#6a4a4a")
	elif part.key == "has_missiles":
		status = "ASSEMBLED — %d pods" % int(_player.get("missiles"))
		scol = CHITIN
	elif togg:
		if bool(_player.get(part.active)):
			status = "ACTIVE"
			scol = CHITIN
		else:
			status = "SUPPRESSED"
			scol = DIM
	else:
		status = "ASSEMBLED"
		scol = CHITIN

	var name_col := TITLE if acq else Color("#5a4a4a")
	var name_txt: String = part.name if acq else "??? "
	c.draw_string(_font, pos, name_txt, HORIZONTAL_ALIGNMENT_LEFT, w, 24, name_col)
	c.draw_string(_font, pos + Vector2(0, 24), status, HORIZONTAL_ALIGNMENT_LEFT, w, 14, scol)
	if acq:
		c.draw_string(_font, pos + Vector2(0, 48), part.desc, HORIZONTAL_ALIGNMENT_LEFT, w, 15, SUB)

# A small bug that lights up the parts you've grafted on.
func _draw_silhouette(c: Control, ctr: Vector2) -> void:
	var body := Color("#26352b")
	var on := func(k): return CHITIN if _has(k) else body
	# abdomen / thorax / head
	c.draw_circle(ctr + Vector2(0, 24), 16, body)
	c.draw_circle(ctr, 12, body)
	c.draw_circle(ctr + Vector2(0, -20), 9, body)
	# wings (double jump)
	var wing: Color = on.call("has_double_jump")
	c.draw_colored_polygon(PackedVector2Array([ctr + Vector2(-4, -4), ctr + Vector2(-34, -22), ctr + Vector2(-10, 6)]), wing)
	c.draw_colored_polygon(PackedVector2Array([ctr + Vector2(4, -4), ctr + Vector2(34, -22), ctr + Vector2(10, 6)]), wing)
	# stinger (missiles)
	var st: Color = on.call("has_missiles")
	c.draw_colored_polygon(PackedVector2Array([ctr + Vector2(-5, 38), ctr + Vector2(5, 38), ctr + Vector2(0, 52)]), st)
	# grip claws (wall jump) on the legs
	var claw: Color = on.call("has_wall_jump")
	c.draw_line(ctr + Vector2(-12, 8), ctr + Vector2(-26, 16), claw, 2.0)
	c.draw_line(ctr + Vector2(12, 8), ctr + Vector2(26, 16), claw, 2.0)
	# drill horn (dash)
	var drill: Color = on.call("has_dash")
	c.draw_colored_polygon(PackedVector2Array([ctr + Vector2(-4, -28), ctr + Vector2(4, -28), ctr + Vector2(0, -40)]), drill)
	# mandible glow = current beam color (ice/wave/charge/base), only if it would apply
	var beam := Color("#9fe6ff")
	if _has("has_wave") and bool(_player.get("wave_active")):
		beam = Color("#c77dff")
	elif _has("has_ice") and bool(_player.get("ice_active")):
		beam = Color("#bfe9ff")
	c.draw_circle(ctr + Vector2(0, -20), 3.5, beam)
	c.draw_string(_font, ctr + Vector2(-40, 74), "you", HORIZONTAL_ALIGNMENT_CENTER, 80, 12, SUB)

func _hex(c: Control, r: Rect2, col: Color) -> void:
	var w := r.size.x
	var h := r.size.y
	var p := r.position
	c.draw_colored_polygon(PackedVector2Array([
		p + Vector2(w * 0.25, 0), p + Vector2(w * 0.75, 0),
		p + Vector2(w, h * 0.5),
		p + Vector2(w * 0.75, h), p + Vector2(w * 0.25, h),
		p + Vector2(0, h * 0.5),
	]), col)

func _glyph(c: Control, ctr: Vector2, kind: String, col: Color) -> void:
	match kind:
		"charge":
			c.draw_arc(ctr, 12, 0, TAU, 20, col, 2.0)
			c.draw_circle(ctr, 3, col)
		"ice":
			for a in [0.0, PI / 3.0, 2.0 * PI / 3.0]:
				var d := Vector2(cos(a), sin(a)) * 12.0
				c.draw_line(ctr - d, ctr + d, col, 2.0)
		"wave":
			var pts := PackedVector2Array()
			for i in 13:
				var x := -14.0 + i * 28.0 / 12.0
				pts.append(ctr + Vector2(x, sin(float(i) / 12.0 * TAU) * 7.0))
			c.draw_polyline(pts, col, 2.0)
		"missile":
			for j in 3:
				c.draw_circle(ctr + Vector2(0, -8 + j * 8), 3.0, col)
		"wing":
			c.draw_colored_polygon(PackedVector2Array([ctr + Vector2(0, 0), ctr + Vector2(-14, -10), ctr + Vector2(-2, 6)]), col)
			c.draw_colored_polygon(PackedVector2Array([ctr + Vector2(0, 0), ctr + Vector2(14, -10), ctr + Vector2(2, 6)]), col)
		"drill":
			c.draw_colored_polygon(PackedVector2Array([ctr + Vector2(-8, -8), ctr + Vector2(12, 0), ctr + Vector2(-8, 8)]), col)
		"claw":
			c.draw_line(ctr + Vector2(-10, -8), ctr + Vector2(-10, 8), col, 2.0)
			c.draw_line(ctr + Vector2(-10, 8), ctr + Vector2(-2, 4), col, 2.0)
			c.draw_line(ctr + Vector2(10, -8), ctr + Vector2(10, 8), col, 2.0)
			c.draw_line(ctr + Vector2(10, 8), ctr + Vector2(2, 4), col, 2.0)
		"roll":
			c.draw_arc(ctr, 11, 0, TAU, 18, col, 2.0)
			c.draw_arc(ctr, 5, 0.5, 4.0, 12, col, 2.0)
