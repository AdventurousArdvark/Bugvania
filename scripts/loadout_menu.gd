extends CanvasLayer
class_name LoadoutMenu
## Pause-screen loadout + map, themed as the bug reviewing its grafted parts.
##
## LAYOUT MODEL: everything is authored in a fixed 1280x720 "design space" and
## drawn through a single scale+offset transform that fits it to the window
## (centered, aspect-preserved). Because the layout is deterministic in design
## space, panels can never overlap — they only scale together. Mouse hit-tests
## convert the cursor back into design space.

# ---- palette -------------------------------------------------------------
const BG_DIM       := Color(0.02, 0.04, 0.03, 0.93)
const FRAME_FILL   := Color(0.05, 0.085, 0.065, 0.55)
const PANEL_FILL   := Color(0.06, 0.10, 0.08, 0.80)
const PANEL_EDGE   := Color(0.18, 0.30, 0.22, 0.90)
const PANEL_EDGE_HI:= Color(0.42, 0.68, 0.47, 0.45)
const ACCENT       := Color("#5fa86b")
const ACCENT_DIM   := Color("#33513a")
const TEXT         := Color("#cfe9c2")
const TEXT_DIM     := Color("#84a578")
const TEXT_MUTE    := Color("#56705a")
const GLYPH_LIT    := Color("#d8f0c8")
const GLYPH_DIM    := Color("#4a6a48")
const LOCK_FILL    := Color(0.045, 0.07, 0.055, 0.75)
const SELECT       := Color("#e8ffd8")

const DESIGN := Vector2(1280.0, 720.0)
const MARGIN := 64.0          # content left/right inset in design space

var _player: Node = null
var _font: Font
var _open: bool = false
var _idx: int = 0
var _cols: int = 4
var _anim: float = 0.0
var _parts: Array = []
var _cell_rects: Array = []          # design-space Rect2 per part cell
var _tab_rects: Array = []           # design-space Rect2 per tab header
var _map_source = null
var _tab: int = 0                    # 0 = ASSEMBLY, 1 = MAP
var _ui_scale: float = 1.0           # design -> screen scale (set each render)
var _ui_off: Vector2 = Vector2.ZERO  # design -> screen offset (set each render)
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
		{"key": "has_ice",         "active": "ice_active",    "name": "Frost Gland",       "glyph": "ice",     "desc": "Shots chill prey solid. Frozen prey becomes a platform."},
		{"key": "has_wave",        "active": "wave_active",   "name": "Resonant Membrane", "glyph": "wave",    "desc": "Shots phase through carapace and wall alike."},
		{"key": "has_missiles",    "active": "",              "name": "Stinger Pods",      "glyph": "missile", "desc": "Volatile pods. Burst armored growths and sealed ways."},
		{"key": "has_double_jump", "active": "",              "name": "Wing-Segment",      "glyph": "wing",    "desc": "A second beat of borrowed wings."},
		{"key": "has_dash",        "active": "",              "name": "Drill-Limb",        "glyph": "drill",   "desc": "A lunging bore. Crosses gaps and carries momentum."},
		{"key": "has_wall_jump",   "active": "",              "name": "Grip-Claws",        "glyph": "claw",    "desc": "Cling to walls; kick off them to climb."},
		{"key": "has_slide",       "active": "",              "name": "Carapace-Roll",     "glyph": "roll",    "desc": "Tuck and slide low and fast."},
	]
	_draw_node = MenuDraw.new()
	(_draw_node as MenuDraw).menu = self
	_draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_draw_node)

func bind(player: Node) -> void:
	_player = player

func set_map_source(src) -> void:
	_map_source = src

# ---- lifecycle / input ---------------------------------------------------

func _process(delta: float) -> void:
	if not _open:
		return
	_anim += delta
	if _tab == 0:
		var dm := _to_design(_draw_node.get_global_mouse_position())
		for i in _cell_rects.size():
			if _cell_rects[i].has_point(dm):
				_idx = i
	_redraw()

func _to_design(screen_pos: Vector2) -> Vector2:
	return (screen_pos - _ui_off) / maxf(_ui_scale, 0.001)

func _input(event: InputEvent) -> void:
	var toggle : bool = (InputMap.has_action("map") and event.is_action_pressed("map")) \
		or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB)
	if not _open:
		if toggle:
			_open_menu()
		return
	if toggle or event.is_action_pressed("ui_cancel"):
		_close_menu()
		return
	# Tab switching: Q/E keys or gamepad shoulders.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			_set_tab(0); return
		elif event.keycode == KEY_E:
			_set_tab(1); return
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			_set_tab(0); return
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			_set_tab(1); return
	# Mouse: header click switches tabs; otherwise toggle a part (assembly only).
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var dm := _to_design(_draw_node.get_global_mouse_position())
		for t in _tab_rects.size():
			if _tab_rects[t].has_point(dm):
				_set_tab(t); return
		if _tab == 0:
			_toggle_current()
		return
	# Grid nav (assembly only).
	if _tab == 0:
		if event.is_action_pressed("ui_left"):
			_move(-1)
		elif event.is_action_pressed("ui_right"):
			_move(1)
		elif event.is_action_pressed("ui_up"):
			_move(-_cols)
		elif event.is_action_pressed("ui_down"):
			_move(_cols)
		elif event.is_action_pressed("ui_accept"):
			_toggle_current()

func _set_tab(t: int) -> void:
	if t == _tab:
		return
	_tab = t
	Audio.play("charge_ready")
	_redraw()

func _open_menu() -> void:
	_open = true
	add_to_group("modal")
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
	var part: Dictionary = _parts[_idx]
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

# ---- render --------------------------------------------------------------

func _render(c: Control) -> void:
	if not _open:
		return
	var sz := c.size
	# Full-screen dim (in screen space, covers letterbox bars too).
	c.draw_rect(Rect2(Vector2.ZERO, sz), BG_DIM)
	# Fit the 1280x720 design space into the window, centered. Pure fit (no floor)
	# so the whole menu is always visible regardless of viewport size.
	_ui_scale = minf(sz.x / DESIGN.x, sz.y / DESIGN.y)
	_ui_off = (sz - DESIGN * _ui_scale) * 0.5
	c.draw_set_transform(_ui_off, 0.0, Vector2(_ui_scale, _ui_scale))

	_draw_frame(c)
	_draw_tabs(c)
	if _tab == 0:
		_draw_assembly(c)
	else:
		_draw_map(c)
	_draw_footer(c)

	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_frame(c: Control) -> void:
	var outer := Rect2(40.0, 28.0, DESIGN.x - 80.0, DESIGN.y - 56.0)
	c.draw_rect(outer, FRAME_FILL)
	c.draw_rect(outer, PANEL_EDGE, false, 1.5)
	c.draw_string(_font, Vector2(MARGIN, 58.0), "VESSEL", HORIZONTAL_ALIGNMENT_LEFT, 300.0, 14, TEXT_MUTE)

func _draw_tabs(c: Control) -> void:
	_tab_rects.clear()
	var labels := ["ASSEMBLY", "MAP"]
	var fs := 24
	var pad := 30.0
	var gap := 14.0
	var th := 46.0
	var widths: Array = []
	var total := 0.0
	for L in labels:
		var w: float = _font.get_string_size(L, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		widths.append(w)
		total += w + pad * 2.0
	total += gap
	var x := DESIGN.x * 0.5 - total * 0.5
	var y := 62.0
	for i in labels.size():
		var w: float = widths[i]
		var rect := Rect2(x, y, w + pad * 2.0, th)
		_tab_rects.append(rect)
		var active: bool = i == _tab
		if active:
			c.draw_rect(rect, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.14))
			c.draw_line(rect.position + Vector2(0.0, rect.size.y),
				rect.position + Vector2(rect.size.x, rect.size.y), ACCENT, 3.0)
		var col: Color = TEXT if active else TEXT_MUTE
		c.draw_string(_font, Vector2(rect.position.x, y + th * 0.5 + float(fs) * 0.36),
			labels[i], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, fs, col)
		x += rect.size.x + gap
	# Divider under the tab row, spanning the content width.
	c.draw_line(Vector2(MARGIN, 122.0), Vector2(DESIGN.x - MARGIN, 122.0), PANEL_EDGE, 1.0)

func _draw_footer(c: Control) -> void:
	var hint := "navigate  ·  ENTER suppress / restore  ·  Q / E  switch tabs  ·  TAB close" if _tab == 0 \
		else "Q / E  switch tabs  ·  TAB close"
	c.draw_string(_font, Vector2(MARGIN, DESIGN.y - 40.0), hint,
		HORIZONTAL_ALIGNMENT_CENTER, DESIGN.x - MARGIN * 2.0, 14, TEXT_MUTE)

# ---- ASSEMBLY tab --------------------------------------------------------

func _draw_assembly(c: Control) -> void:
	# Two columns inside the content band (y 132..632).
	var left := Rect2(MARGIN, 138.0, 716.0, 494.0)
	var right_x := MARGIN + 716.0 + 32.0
	var right_w := DESIGN.x - MARGIN - right_x
	var parts_panel := Rect2(left.position.x, left.position.y, left.size.x, 318.0)
	var desc_panel := Rect2(left.position.x, left.position.y + 334.0, left.size.x, 160.0)
	var silh_panel := Rect2(right_x, 138.0, right_w, 318.0)
	var stat_panel := Rect2(right_x, 138.0 + 334.0, right_w, 160.0)

	_panel(c, parts_panel, "GRAFTED PARTS")
	_panel(c, desc_panel, "")
	_panel(c, silh_panel, "MORPHOLOGY")
	_panel(c, stat_panel, "STATUS")

	# Grid centered within the parts panel interior.
	var pad := 22.0
	var inner := parts_panel.grow(-pad)
	inner.position.y += 30.0          # below the panel title
	inner.size.y -= 30.0
	var cell := 112.0
	var gap := 24.0
	var grid_w := _cols * cell + (_cols - 1) * gap
	var rows := int(ceil(float(_parts.size()) / float(_cols)))
	var grid_h := rows * cell + (rows - 1) * gap
	var gx := inner.position.x + (inner.size.x - grid_w) * 0.5
	var gy := inner.position.y + (inner.size.y - grid_h) * 0.5
	_cell_rects.clear()
	for i in _parts.size():
		var cx := gx + float(i % _cols) * (cell + gap)
		var cy := gy + float(i / _cols) * (cell + gap)
		var r := Rect2(cx, cy, cell, cell)
		_cell_rects.append(r)
		_draw_cell(c, r, _parts[i], i == _idx)

	_draw_description(c, desc_panel)
	_draw_silhouette(c, silh_panel.get_center() + Vector2(0.0, 12.0), 1.75)
	_draw_status(c, stat_panel)

func _draw_cell(c: Control, r: Rect2, part: Dictionary, sel: bool) -> void:
	var acq := _has(part.key)
	var togg: bool = part.active != ""
	var act: bool = togg and acq and bool(_player.get(part.active))
	var lit := acq and (not togg or act)

	var fill: Color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.22) if lit \
		else (Color(ACCENT_DIM.r, ACCENT_DIM.g, ACCENT_DIM.b, 0.55) if acq else LOCK_FILL)
	_hex(c, r, fill)
	var edge: Color = ACCENT if lit else (ACCENT_DIM if acq else Color(0.14, 0.20, 0.16, 0.9))
	_hex_outline(c, r, edge, 2.0)

	var grad := GLYPH_LIT if lit else GLYPH_DIM
	_glyph(c, r.get_center(), part.glyph, grad, r.size.x * 0.20)

	if not acq:
		# Locked: a small bar across, reads as "dormant".
		c.draw_line(r.get_center() + Vector2(-r.size.x * 0.16, 0.0),
			r.get_center() + Vector2(r.size.x * 0.16, 0.0), Color(0, 0, 0, 0.45), 2.0)
	elif togg and not act:
		# Suppressed: a diagonal slash.
		c.draw_line(r.position + r.size * 0.28, r.position + r.size * 0.72, Color(0, 0, 0, 0.5), 2.5)

	if sel:
		var a := 0.55 + 0.45 * sin(_anim * 6.0)
		_hex_outline(c, r.grow(5.0), Color(SELECT.r, SELECT.g, SELECT.b, a), 2.5)

func _draw_description(c: Control, panel: Rect2) -> void:
	var part: Dictionary = _parts[_idx]
	var acq := _has(part.key)
	var togg: bool = part.active != ""
	var status := ""
	var scol := TEXT_DIM
	if not acq:
		status = "DORMANT — not yet assembled"
		scol = Color("#9a6a6a")
	elif part.key == "has_missiles":
		status = "ASSEMBLED — %d pods" % int(_player.get("missiles"))
		scol = ACCENT
	elif togg:
		if bool(_player.get(part.active)):
			status = "ACTIVE"
			scol = ACCENT
		else:
			status = "SUPPRESSED"
			scol = TEXT_MUTE
	else:
		status = "ASSEMBLED"
		scol = ACCENT

	var p := panel.position + Vector2(22.0, 0.0)
	var w := panel.size.x - 44.0
	var name_col: Color = TEXT if acq else Color("#7a5a5a")
	var name_txt: String = part.name if acq else "UNKNOWN PART"
	c.draw_string(_font, p + Vector2(0.0, 38.0), name_txt, HORIZONTAL_ALIGNMENT_LEFT, w, 26, name_col)
	c.draw_string(_font, p + Vector2(0.0, 64.0), status, HORIZONTAL_ALIGNMENT_LEFT, w, 15, scol)
	if acq:
		c.draw_multiline_string(_font, p + Vector2(0.0, 94.0), part.desc,
			HORIZONTAL_ALIGNMENT_LEFT, w, 16, -1, TEXT_DIM)

func _draw_status(c: Control, panel: Rect2) -> void:
	if _player == null:
		return
	var p := panel.position + Vector2(22.0, 60.0)
	var w := panel.size.x - 44.0
	# Integrity bar.
	var hp := int(_player.get("health"))
	var hpm: int = maxi(1, int(_player.get("max_health")))
	c.draw_string(_font, p, "INTEGRITY", HORIZONTAL_ALIGNMENT_LEFT, w, 14, TEXT_MUTE)
	var bar := Rect2(p.x, p.y + 12.0, w, 12.0)
	c.draw_rect(bar, Color(0, 0, 0, 0.35))
	c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(float(hp) / float(hpm), 0.0, 1.0), bar.size.y)), ACCENT)
	c.draw_rect(bar, PANEL_EDGE, false, 1.0)
	# Beam readout.
	var beam_name := "Base Beam"
	var beam_col := Color("#9fe6ff")
	if _has("has_wave") and bool(_player.get("wave_active")):
		beam_name = "Resonant"; beam_col = Color("#c77dff")
	elif _has("has_ice") and bool(_player.get("ice_active")):
		beam_name = "Frost"; beam_col = Color("#bfe9ff")
	if _has("has_charge") and bool(_player.get("charge_active")):
		beam_name += " · charged"
	var by := p.y + 44.0
	c.draw_string(_font, Vector2(p.x, by), "BEAM", HORIZONTAL_ALIGNMENT_LEFT, w, 14, TEXT_MUTE)
	c.draw_rect(Rect2(p.x, by + 10.0, 13.0, 13.0), beam_col)
	c.draw_string(_font, Vector2(p.x + 22.0, by + 22.0), beam_name, HORIZONTAL_ALIGNMENT_LEFT, w - 22.0, 16, TEXT)
	# Stingers (only if owned).
	if _has("has_missiles"):
		c.draw_string(_font, Vector2(p.x, by + 50.0),
			"STINGERS   %d" % int(_player.get("missiles")), HORIZONTAL_ALIGNMENT_LEFT, w, 16, TEXT_DIM)

# A bug that lights up the parts you've grafted on.
func _draw_silhouette(c: Control, ctr: Vector2, s: float) -> void:
	var body := Color("#26352b")
	var on := func(k): return ACCENT if _has(k) else body
	c.draw_circle(ctr + Vector2(0, 24) * s, 16.0 * s, body)
	c.draw_circle(ctr, 12.0 * s, body)
	c.draw_circle(ctr + Vector2(0, -20) * s, 9.0 * s, body)
	var wing: Color = on.call("has_double_jump")
	c.draw_colored_polygon(PackedVector2Array([ctr + Vector2(-4, -4) * s, ctr + Vector2(-34, -22) * s, ctr + Vector2(-10, 6) * s]), wing)
	c.draw_colored_polygon(PackedVector2Array([ctr + Vector2(4, -4) * s, ctr + Vector2(34, -22) * s, ctr + Vector2(10, 6) * s]), wing)
	var st: Color = on.call("has_missiles")
	c.draw_colored_polygon(PackedVector2Array([ctr + Vector2(-5, 38) * s, ctr + Vector2(5, 38) * s, ctr + Vector2(0, 52) * s]), st)
	var claw: Color = on.call("has_wall_jump")
	c.draw_line(ctr + Vector2(-12, 8) * s, ctr + Vector2(-26, 16) * s, claw, 2.0 * s)
	c.draw_line(ctr + Vector2(12, 8) * s, ctr + Vector2(26, 16) * s, claw, 2.0 * s)
	var drill: Color = on.call("has_dash")
	c.draw_colored_polygon(PackedVector2Array([ctr + Vector2(-4, -28) * s, ctr + Vector2(4, -28) * s, ctr + Vector2(0, -40) * s]), drill)
	var beam := Color("#9fe6ff")
	if _has("has_wave") and bool(_player.get("wave_active")):
		beam = Color("#c77dff")
	elif _has("has_ice") and bool(_player.get("ice_active")):
		beam = Color("#bfe9ff")
	c.draw_circle(ctr + Vector2(0, -20) * s, 3.5 * s, beam)

# ---- MAP tab -------------------------------------------------------------

func _draw_map(c: Control) -> void:
	var panel := Rect2(MARGIN, 138.0, DESIGN.x - MARGIN * 2.0, 494.0)
	_panel(c, panel, "HIVE MAP")
	if _map_source == null:
		return
	var rooms: Dictionary = _map_source.map_rooms()
	var visited: Dictionary = _map_source.map_visited()
	var current: String = _map_source.map_current()

	var have := false
	var bb := Rect2()
	var names: Array = []
	for name in rooms:
		if not visited.has(name):
			continue
		names.append(name)
		var r: Rect2 = rooms[name]
		bb = r if not have else bb.merge(r)
		have = true
	if not have:
		c.draw_string(_font, panel.get_center() + Vector2(-panel.size.x * 0.5, 0.0),
			"·  UNEXPLORED  ·", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 18, TEXT_MUTE)
		return

	# Drawing area inside the panel: leave room for the title and a legend row.
	var area := Rect2(panel.position.x + 36.0, panel.position.y + 52.0,
		panel.size.x - 72.0, panel.size.y - 96.0)
	var sc: float = minf(area.size.x / bb.size.x, area.size.y / bb.size.y)
	var off: Vector2 = area.position + (area.size - bb.size * sc) * 0.5 - bb.position * sc

	# Tunnels first.
	for ai in names.size():
		for bi in range(ai + 1, names.size()):
			var ra: Rect2 = rooms[names[ai]]
			var rb: Rect2 = rooms[names[bi]]
			if ra.grow(48.0).intersects(rb):
				var pa: Vector2 = off + ra.get_center() * sc
				var pb: Vector2 = off + rb.get_center() * sc
				c.draw_line(pa, pb, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.30), 4.0)

	# Chambers.
	for name in names:
		var r: Rect2 = rooms[name]
		var cell := Rect2(off + r.position * sc, r.size * sc).grow(-3.0)
		var is_cur: bool = name == current
		var fill: Color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.26) if is_cur \
			else Color(ACCENT_DIM.r, ACCENT_DIM.g, ACCENT_DIM.b, 0.55)
		c.draw_rect(cell, fill)
		c.draw_rect(cell.grow(-3.0), Color(0, 0, 0, 0.18))
		c.draw_rect(cell, ACCENT if is_cur else ACCENT_DIM, false, 2.0)
		if is_cur:
			var pa2 := 0.35 + 0.4 * sin(_anim * 4.0)
			c.draw_rect(cell.grow(3.0), Color(GLYPH_LIT.r, GLYPH_LIT.g, GLYPH_LIT.b, pa2), false, 2.0)
		var lc: Color = GLYPH_LIT if is_cur else GLYPH_DIM
		c.draw_string(_font, cell.get_center() + Vector2(-cell.size.x * 0.5, 6.0),
			str(name), HORIZONTAL_ALIGNMENT_CENTER, cell.size.x, 18, lc)

	# Player mote.
	var pp: Vector2 = off + _map_source.map_player_pos() * sc
	var hp := 0.5 + 0.5 * sin(_anim * 5.0)
	c.draw_circle(pp, 9.0 * (0.7 + 0.3 * hp), Color(GLYPH_LIT.r, GLYPH_LIT.g, GLYPH_LIT.b, 0.16))
	c.draw_circle(pp, 4.0, GLYPH_LIT)

	# Legend along the bottom of the panel.
	var ly := panel.position.y + panel.size.y - 22.0
	var lx := panel.position.x + 30.0
	c.draw_circle(Vector2(lx + 6.0, ly - 4.0), 4.0, GLYPH_LIT)
	c.draw_string(_font, Vector2(lx + 18.0, ly), "you", HORIZONTAL_ALIGNMENT_LEFT, 80, 14, TEXT_DIM)
	c.draw_rect(Rect2(lx + 78.0, ly - 13.0, 13.0, 13.0), ACCENT, false, 2.0)
	c.draw_string(_font, Vector2(lx + 98.0, ly), "current", HORIZONTAL_ALIGNMENT_LEFT, 110, 14, TEXT_DIM)
	c.draw_rect(Rect2(lx + 192.0, ly - 13.0, 13.0, 13.0), ACCENT_DIM, false, 2.0)
	c.draw_string(_font, Vector2(lx + 212.0, ly), "explored", HORIZONTAL_ALIGNMENT_LEFT, 110, 14, TEXT_DIM)

# ---- shared drawing helpers ----------------------------------------------

func _panel(c: Control, rect: Rect2, title: String) -> void:
	c.draw_rect(rect, PANEL_FILL)
	c.draw_rect(rect, PANEL_EDGE, false, 1.5)
	c.draw_line(rect.position, rect.position + Vector2(rect.size.x, 0.0), PANEL_EDGE_HI, 1.5)
	if title != "":
		c.draw_string(_font, rect.position + Vector2(20.0, 26.0), title,
			HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 40.0, 15, TEXT_DIM)
		c.draw_line(rect.position + Vector2(20.0, 36.0),
			rect.position + Vector2(rect.size.x - 20.0, 36.0), PANEL_EDGE, 1.0)

func _hex_points(r: Rect2) -> PackedVector2Array:
	var w := r.size.x
	var h := r.size.y
	var p := r.position
	return PackedVector2Array([
		p + Vector2(w * 0.25, 0.0), p + Vector2(w * 0.75, 0.0),
		p + Vector2(w, h * 0.5),
		p + Vector2(w * 0.75, h), p + Vector2(w * 0.25, h),
		p + Vector2(0.0, h * 0.5),
	])

func _hex(c: Control, r: Rect2, col: Color) -> void:
	c.draw_colored_polygon(_hex_points(r), col)

func _hex_outline(c: Control, r: Rect2, col: Color, width: float) -> void:
	var pts := _hex_points(r)
	pts.append(pts[0])
	c.draw_polyline(pts, col, width)

func _glyph(c: Control, ctr: Vector2, kind: String, col: Color, rad: float) -> void:
	match kind:
		"charge":
			c.draw_arc(ctr, rad, 0.0, TAU, 22, col, 2.0)
			c.draw_circle(ctr, rad * 0.26, col)
		"ice":
			for a: float in [0.0, PI / 3.0, 2.0 * PI / 3.0]:
				var d := Vector2(cos(a), sin(a)) * rad
				c.draw_line(ctr - d, ctr + d, col, 2.0)
		"wave":
			var pts := PackedVector2Array()
			for i in 17:
				var x := -rad + float(i) * (2.0 * rad) / 16.0
				pts.append(ctr + Vector2(x, sin(float(i) / 16.0 * TAU) * rad * 0.55))
			c.draw_polyline(pts, col, 2.0)
		"missile":
			for j in 3:
				c.draw_circle(ctr + Vector2(0.0, -rad * 0.6 + float(j) * rad * 0.6), rad * 0.24, col)
		"wing":
			c.draw_colored_polygon(PackedVector2Array([ctr, ctr + Vector2(-rad * 1.2, -rad * 0.85), ctr + Vector2(-rad * 0.2, rad * 0.5)]), col)
			c.draw_colored_polygon(PackedVector2Array([ctr, ctr + Vector2(rad * 1.2, -rad * 0.85), ctr + Vector2(rad * 0.2, rad * 0.5)]), col)
		"drill":
			c.draw_colored_polygon(PackedVector2Array([ctr + Vector2(-rad * 0.7, -rad * 0.7), ctr + Vector2(rad, 0.0), ctr + Vector2(-rad * 0.7, rad * 0.7)]), col)
		"claw":
			c.draw_line(ctr + Vector2(-rad * 0.85, -rad * 0.7), ctr + Vector2(-rad * 0.85, rad * 0.7), col, 2.0)
			c.draw_line(ctr + Vector2(-rad * 0.85, rad * 0.7), ctr + Vector2(-rad * 0.15, rad * 0.35), col, 2.0)
			c.draw_line(ctr + Vector2(rad * 0.85, -rad * 0.7), ctr + Vector2(rad * 0.85, rad * 0.7), col, 2.0)
			c.draw_line(ctr + Vector2(rad * 0.85, rad * 0.7), ctr + Vector2(rad * 0.15, rad * 0.35), col, 2.0)
		"roll":
			c.draw_arc(ctr, rad, 0.0, TAU, 20, col, 2.0)
			c.draw_arc(ctr, rad * 0.45, 0.5, 4.0, 14, col, 2.0)
