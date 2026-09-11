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
var _tab: int = 0                    # 0 = ASSEMBLY, 1 = MAP, 2 = SETTINGS, 3 = CODEX
var _codex_idx: int = 0
var _set_idx: int = 0                # selected settings row
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
	_parts = []
	for key in Grafts.ORDER:
		_parts.append({
			"key": key,
			"active": Grafts.active_flag(key),
			"name": Grafts.name_of(key),
			"glyph": Grafts.glyph_of(key),
			"desc": Grafts.desc_of(key),
		})
	_draw_node = MenuDraw.new()
	(_draw_node as MenuDraw).menu = self
	_draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_draw_node)
	get_viewport().size_changed.connect(func():
		_draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
		if _open:
			_draw_node.queue_redraw())

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
	# Tab switching: Q/E cycle, or gamepad shoulders.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			_set_tab(wrapi(_tab - 1, 0, 4)); return
		elif event.keycode == KEY_E:
			_set_tab(wrapi(_tab + 1, 0, 4)); return
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			_set_tab(wrapi(_tab - 1, 0, 4)); return
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			_set_tab(wrapi(_tab + 1, 0, 4)); return
	# Mouse: header click switches tabs; otherwise act on the current tab.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var dm := _to_design(_draw_node.get_global_mouse_position())
		for t in _tab_rects.size():
			if _tab_rects[t].has_point(dm):
				_set_tab(t); return
		if _tab == 0:
			_toggle_current()
		elif _tab == 2:
			_settings_activate()
		return
	# Per-tab navigation.
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
	elif _tab == 2:
		if event.is_action_pressed("ui_up"):
			_set_idx = wrapi(_set_idx - 1, 0, _settings_rows()); _redraw()
		elif event.is_action_pressed("ui_down"):
			_set_idx = wrapi(_set_idx + 1, 0, _settings_rows()); _redraw()
		elif event.is_action_pressed("ui_left"):
			_settings_adjust(-1)
		elif event.is_action_pressed("ui_right"):
			_settings_adjust(1)
		elif event.is_action_pressed("ui_accept"):
			_settings_activate()
	elif _tab == 3:
		var n := Codex.count()
		if n > 0 and event.is_action_pressed("ui_up"):
			_codex_idx = wrapi(_codex_idx - 1, 0, n); _redraw()
		elif n > 0 and event.is_action_pressed("ui_down"):
			_codex_idx = wrapi(_codex_idx + 1, 0, n); _redraw()

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
	if _player == null:
		return
	var key: String = part.key
	if not _player.is_owned(key):
		Audio.play("hit")                 # not harvested yet
		return
	if _player.is_equipped(key):
		_player.unequip(key)
		Audio.play("hit")
	elif _player.can_equip(key):
		_player.equip(key)
		Audio.play("charge_ready")
	else:
		Audio.play("hit")                 # no free slots
	_redraw()

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
	elif _tab == 1:
		_draw_map(c)
	elif _tab == 2:
		_draw_settings(c)
	else:
		_draw_codex(c)
	_draw_footer(c)

	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_frame(c: Control) -> void:
	var outer := Rect2(40.0, 28.0, DESIGN.x - 80.0, DESIGN.y - 56.0)
	c.draw_rect(outer, FRAME_FILL)
	c.draw_rect(outer, PANEL_EDGE, false, 1.5)
	c.draw_string(_font, Vector2(MARGIN, 58.0), "VESSEL", HORIZONTAL_ALIGNMENT_LEFT, 300.0, 14, TEXT_MUTE)

func _draw_tabs(c: Control) -> void:
	_tab_rects.clear()
	var labels := ["ASSEMBLY", "MAP", "SETTINGS", "CODEX"]
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
	var hint := "Q / E  switch tabs  ·  TAB close"
	if _tab == 0:
		hint = "navigate  ·  ENTER equip / unequip  ·  Q / E  switch tabs  ·  TAB close"
	elif _tab == 2:
		hint = "up / down  select  ·  left / right  adjust  ·  ENTER  activate  ·  Q / E  tabs"
	elif _tab == 3:
		hint = "up / down  browse recovered logs  ·  Q / E  switch tabs  ·  TAB close"
	c.draw_string(_font, Vector2(MARGIN, DESIGN.y - 40.0), hint,
		HORIZONTAL_ALIGNMENT_CENTER, DESIGN.x - MARGIN * 2.0, 14, TEXT_MUTE)

# ---- SETTINGS tab --------------------------------------------------------

func _settings_rows() -> int:
	return 6

func _settings_adjust(dir: int) -> void:
	match _set_idx:
		0: Settings.master_volume = clampf(Settings.master_volume + float(dir) * 0.05, 0.0, 1.0)
		1: Settings.shake_scale = clampf(Settings.shake_scale + float(dir) * 0.1, 0.0, 1.5)
		2: Settings.rumble_on = dir > 0
		3: Settings.grip_toggle = dir > 0
		_: return
	Settings.apply()
	Settings.save_settings()
	Audio.play("hit")
	_redraw()

func _settings_activate() -> void:
	if _set_idx == 4:
		get_tree().call_group("level", "save_progress")
		Audio.play("charge_ready")
	elif _set_idx == 5:
		SaveSystem.clear()
		get_tree().paused = false
		get_tree().reload_current_scene()

func _draw_settings(c: Control) -> void:
	var panel := Rect2(MARGIN + 120.0, 150.0, DESIGN.x - 2.0 * (MARGIN + 120.0), 470.0)
	_panel(c, panel, "OPTIONS")
	var rows := [
		["MASTER VOLUME", "slider", Settings.master_volume / 1.0],
		["SCREEN SHAKE", "slider", Settings.shake_scale / 1.5],
		["RUMBLE", "text", 1.0 if Settings.rumble_on else 0.0],
		["WALL GRIP", "text", 1.0 if Settings.grip_toggle else 0.0],
		["SAVE GAME", "button", 0.0],
		["RESET PROGRESS", "button", 0.0],
	]
	var y := panel.position.y + 70.0
	var rh := 60.0
	var lx := panel.position.x + 36.0
	var rx := panel.position.x + panel.size.x * 0.52
	var rw := panel.size.x * 0.42 - 36.0
	for i in rows.size():
		var row: Array = rows[i]
		var sel: bool = i == _set_idx
		if sel:
			c.draw_rect(Rect2(panel.position.x + 12.0, y - 22.0, panel.size.x - 24.0, rh - 12.0),
				Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.12))
		var lcol: Color = TEXT if sel else TEXT_DIM
		c.draw_string(_font, Vector2(lx, y), str(row[0]), HORIZONTAL_ALIGNMENT_LEFT, panel.size.x * 0.5, 20, lcol)
		match row[1]:
			"slider":
				var frac: float = float(row[2])
				var bar := Rect2(rx, y - 14.0, rw, 14.0)
				c.draw_rect(bar, Color(0, 0, 0, 0.35))
				c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), ACCENT if sel else ACCENT_DIM)
				c.draw_rect(bar, PANEL_EDGE, false, 1.0)
				c.draw_string(_font, Vector2(rx + rw + 14.0, y), "%d%%" % int(round(frac * 100.0)),
					HORIZONTAL_ALIGNMENT_LEFT, 80, 18, lcol)
			"text":
				var on: bool = float(row[2]) > 0.5
				var label := ("ON" if on else "OFF")
				if i == 3:
					label = ("TOGGLE" if on else "HOLD")
				c.draw_string(_font, Vector2(rx, y), "‹  " + label + "  ›", HORIZONTAL_ALIGNMENT_LEFT, rw, 20, lcol)
			"button":
				var brect := Rect2(rx, y - 24.0, 220.0, 36.0)
				c.draw_rect(brect, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.18 if sel else 0.08))
				c.draw_rect(brect, ACCENT if sel else PANEL_EDGE, false, 1.5)
				c.draw_string(_font, Vector2(brect.position.x, y), "  press ENTER",
					HORIZONTAL_ALIGNMENT_LEFT, brect.size.x, 16, lcol)
		y += rh

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

	# Build readout: slots used and the mass profile your equipped set produces.
	if _player != null:
		var used: int = _player.used_slots()
		var cap: int = int(_player.get("graft_capacity"))
		var mass: int = _player.total_mass()
		var prof := Grafts.profile(mass)
		var over := used > cap
		var slot_col: Color = Color("#e0584f") if over else ACCENT
		c.draw_string(_font, Vector2(parts_panel.position.x + parts_panel.size.x - 360.0, parts_panel.position.y + 26.0),
			"SLOTS %d / %d" % [used, cap], HORIZONTAL_ALIGNMENT_LEFT, 160, 18, slot_col)
		var mass_txt := "MASS %+d  ·  %s" % [mass, prof]
		c.draw_string(_font, Vector2(parts_panel.position.x + parts_panel.size.x - 200.0, parts_panel.position.y + 26.0),
			mass_txt, HORIZONTAL_ALIGNMENT_LEFT, 200, 18, TEXT_DIM)

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
	var key: String = part.key
	var owned: bool = _player != null and _player.is_owned(key)
	var equipped: bool = _player != null and _player.is_equipped(key)
	var lit := equipped

	var fill: Color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.22) if lit \
		else (Color(ACCENT_DIM.r, ACCENT_DIM.g, ACCENT_DIM.b, 0.55) if owned else LOCK_FILL)
	_hex(c, r, fill)
	var edge: Color = ACCENT if lit else (ACCENT_DIM if owned else Color(0.14, 0.20, 0.16, 0.9))
	_hex_outline(c, r, edge, 2.0)

	var grad := GLYPH_LIT if lit else GLYPH_DIM
	_glyph(c, r.get_center(), part.glyph, grad, r.size.x * 0.20)

	# Tiny mass tag bottom-right so the build tradeoff is visible at a glance.
	if owned:
		var m: int = Grafts.mass_of(key)
		c.draw_string(_font, r.position + Vector2(r.size.x * 0.5, r.size.y - 14.0),
			"%+d" % m, HORIZONTAL_ALIGNMENT_CENTER, r.size.x * 0.5 - 6.0, 13,
			Color(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, 0.8))

	if not owned:
		# Locked: a small bar across, reads as "not yet harvested".
		c.draw_line(r.get_center() + Vector2(-r.size.x * 0.16, 0.0),
			r.get_center() + Vector2(r.size.x * 0.16, 0.0), Color(0, 0, 0, 0.45), 2.0)
	elif not equipped:
		# Owned but not slotted: a hollow ring marker.
		c.draw_arc(r.get_center() + Vector2(0.0, -r.size.y * 0.04), r.size.x * 0.06, 0.0, TAU, 16,
			Color(ACCENT_DIM.r, ACCENT_DIM.g, ACCENT_DIM.b, 0.9), 1.5)

	if sel:
		var a := 0.55 + 0.45 * sin(_anim * 6.0)
		_hex_outline(c, r.grow(5.0), Color(SELECT.r, SELECT.g, SELECT.b, a), 2.5)

func _draw_description(c: Control, panel: Rect2) -> void:
	var part: Dictionary = _parts[_idx]
	var key: String = part.key
	var owned: bool = _player != null and _player.is_owned(key)
	var equipped: bool = _player != null and _player.is_equipped(key)
	var acq := owned
	var status := ""
	var scol := TEXT_DIM
	if not owned:
		status = "UNHARVESTED — kill its bearer to take it"
		scol = Color("#9a6a6a")
	elif equipped:
		status = "GRAFTED  ·  slot %d  ·  mass %+d" % [Grafts.slot_of(key), Grafts.mass_of(key)]
		if key == "has_missiles":
			status = "GRAFTED  ·  %d pods" % int(_player.get("missiles"))
		scol = ACCENT
	else:
		status = "HARVESTED — not slotted  (slot %d · mass %+d)" % [Grafts.slot_of(key), Grafts.mass_of(key)]
		scol = TEXT_MUTE

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

# ---- CODEX tab -----------------------------------------------------------

func _draw_codex(c: Control) -> void:
	var top := 140.0
	var h := DESIGN.y - top - 96.0
	var list := Rect2(MARGIN, top, 360.0, h)
	var read := Rect2(MARGIN + 380.0, top, DESIGN.x - MARGIN * 2.0 - 380.0, h)
	var logs := Codex.all()
	_panel(c, list, "RECOVERED  %d" % logs.size())
	_panel(c, read, "")

	if logs.is_empty():
		c.draw_string(_font, list.position + Vector2(20.0, 70.0),
			"no data recovered.", HORIZONTAL_ALIGNMENT_LEFT, list.size.x - 40.0, 16, TEXT_MUTE)
		c.draw_string(_font, read.position + Vector2(24.0, 80.0),
			"Logs you find in the world are stored here.", HORIZONTAL_ALIGNMENT_LEFT,
			read.size.x - 48.0, 16, TEXT_MUTE)
		return

	_codex_idx = clampi(_codex_idx, 0, logs.size() - 1)
	var ly := list.position.y + 56.0
	for i in logs.size():
		var sel: bool = i == _codex_idx
		var row := Rect2(list.position.x + 10.0, ly - 18.0, list.size.x - 20.0, 28.0)
		if sel:
			c.draw_rect(row, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.16))
			c.draw_rect(Rect2(row.position, Vector2(3.0, row.size.y)), ACCENT)
		var col: Color = SELECT if sel else TEXT_DIM
		c.draw_string(_font, Vector2(list.position.x + 22.0, ly),
			str(logs[i]["title"]), HORIZONTAL_ALIGNMENT_LEFT, list.size.x - 40.0, 15, col)
		ly += 30.0

	var e: Dictionary = logs[_codex_idx]
	c.draw_string(_font, read.position + Vector2(24.0, 40.0), "▌ RECOVERED DATA",
		HORIZONTAL_ALIGNMENT_LEFT, read.size.x - 48.0, 13, TEXT_MUTE)
	c.draw_string(_font, read.position + Vector2(24.0, 70.0), str(e["title"]),
		HORIZONTAL_ALIGNMENT_LEFT, read.size.x - 48.0, 22, ACCENT)
	c.draw_multiline_string(_font, read.position + Vector2(24.0, 108.0), str(e["body"]),
		HORIZONTAL_ALIGNMENT_LEFT, read.size.x - 48.0, 16, -1, TEXT)


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
