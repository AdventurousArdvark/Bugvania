extends Control
class_name TitleScreen
## A code-drawn, slightly-creepy bug title screen. No art assets.
##   - Dark field with skittering bugs, drifting spores, and blinking eyes in the black.
##   - Flickering title (failing-light effect) with a slow breathing pulse.
##   - Low procedural drone for unease + soft blips on the menu.
##   - Menu works with mouse, keyboard (arrows + Enter), and gamepad (d-pad + A).
##
## SETUP: new scene, root = Control (Full Rect), attach this script, set it as the
## Main Scene. Set `level_scene_path` to your level scene. Rename `title_text` freely.

@export var title_text: String = "INSTAR"          # working title (entomology: a stage between molts)
@export var subtitle_text: String = "assemble · molt · become"
@export var level_scene_path: String = "res://scenes/level_one.tscn"

const BG        := Color("#0a0f0c")
const BG_DEEP   := Color("#050806")
const TITLE_COL := Color("#9fd68a")     # pale chitin green
const TITLE_DIM := Color("#3f5a39")
const SUB_COL   := Color("#5f7a55")
const MENU_COL  := Color("#86a87a")
const MENU_SEL  := Color("#d8f0c8")
const BUG_COL   := Color("#0f1a12")
const EYE_COL   := Color("#7bd06a")

var _font: Font
var _t: float = 0.0
var _flick: float = 1.0
var _selected: int = 0
var _items := ["START", "QUIT"]
var _item_rects: Array = []
var _mode: int = 0                 # 0 = main menu, 1 = profile select
var _psel: int = 0                 # 0..2 profiles, 3 = back
var _prects: Array = []
var _bugs: Array = []
var _motes: Array = []
var _eyes: Array = []
var _drone: AudioStreamPlayer
var _blip: AudioStreamPlayer
var _starting: bool = false

func _ready() -> void:
	_font = ThemeDB.fallback_font
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var sz := _vp()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# Skittering bugs.
	for i in 7:
		_bugs.append({
			"pos": Vector2(rng.randf_range(0, sz.x), rng.randf_range(sz.y * 0.15, sz.y * 0.95)),
			"dir": (1 if rng.randf() < 0.5 else -1),
			"speed": rng.randf_range(26, 60),
			"scale": rng.randf_range(0.7, 1.5),
			"phase": rng.randf_range(0, TAU),
			"pause": rng.randf_range(0, 2.0),
			"walking": true,
		})
	# Drifting spores.
	for i in 40:
		_motes.append({
			"pos": Vector2(rng.randf_range(0, sz.x), rng.randf_range(0, sz.y)),
			"speed": rng.randf_range(6, 22),
			"r": rng.randf_range(0.6, 1.8),
			"a": rng.randf_range(0.05, 0.22),
		})
	# Eyes blinking in the dark.
	for i in 6:
		_eyes.append({
			"pos": Vector2(rng.randf_range(sz.x * 0.05, sz.x * 0.95), rng.randf_range(sz.y * 0.1, sz.y * 0.9)),
			"phase": rng.randf_range(0, TAU),
			"rate": rng.randf_range(0.3, 0.8),
			"gap": rng.randf_range(8, 16),
		})
	_setup_audio()
	# Responsive: keep the Control filling the window and repaint on any resize.
	get_viewport().size_changed.connect(func():
		set_anchors_preset(Control.PRESET_FULL_RECT)
		queue_redraw())

func _setup_audio() -> void:
	var m := Music.new()
	m.theme = "title"
	m.volume_db = -13.0
	add_child(m)
	_blip = AudioStreamPlayer.new()
	add_child(_blip)

func _process(delta: float) -> void:
	_t += delta
	var sz := _vp()

	# Failing-light flicker.
	if randf() < 0.04:
		_flick = randf_range(0.35, 0.7)
	else:
		_flick = lerpf(_flick, 1.0, clampf(8.0 * delta, 0.0, 1.0))

	for b in _bugs:
		b.phase += delta * 9.0 * b.scale
		if b.walking:
			b.pos.x += b.dir * b.speed * delta
			if randf() < 0.004:
				b.walking = false
				b.pause = randf_range(0.4, 1.6)
		else:
			b.pause -= delta
			if b.pause <= 0.0:
				b.walking = true
				if randf() < 0.3:
					b.dir *= -1
		if b.pos.x < -40:
			b.pos.x = sz.x + 40
		elif b.pos.x > sz.x + 40:
			b.pos.x = -40

	for m in _motes:
		m.pos.y -= m.speed * delta
		if m.pos.y < -4:
			m.pos.y = sz.y + 4
			m.pos.x = randf_range(0, sz.x)

	_update_mouse_selection()
	queue_redraw()

func _draw() -> void:
	var sz := _vp()
	# Background, slightly darker at the edges for a vignette feel.
	draw_rect(Rect2(Vector2.ZERO, sz), BG)
	draw_rect(Rect2(Vector2.ZERO, Vector2(sz.x, sz.y * 0.18)), BG_DEEP)
	draw_rect(Rect2(0, sz.y * 0.82, sz.x, sz.y * 0.18), BG_DEEP)

	for m in _motes:
		draw_circle(m.pos, m.r, Color(EYE_COL.r, EYE_COL.g, EYE_COL.b, m.a))

	for e in _eyes:
		var blink := sin(_t * e.rate + e.phase)
		if blink > 0.6:                       # eyes open only part of the time
			var a := (blink - 0.6) / 0.4
			draw_circle(e.pos + Vector2(-e.gap * 0.5, 0), 1.6, Color(EYE_COL.r, EYE_COL.g, EYE_COL.b, a * 0.8))
			draw_circle(e.pos + Vector2(e.gap * 0.5, 0), 1.6, Color(EYE_COL.r, EYE_COL.g, EYE_COL.b, a * 0.8))

	for b in _bugs:
		_draw_bug(b.pos, b.scale, b.phase, b.dir)

	# Mode-specific layout. Each mode owns its own title treatment so nothing
	# overlaps: the menu uses a big centered title; the manifest uses a compact one.
	if _mode == 0:
		_draw_title_big(sz)
		_draw_menu(sz)
	else:
		_draw_profiles(sz)


func _draw_title_big(sz: Vector2) -> void:
	var pulse := 1.0 + sin(_t * 1.4) * 0.02
	var tsize := int(84 * pulse)
	var tcol := TITLE_DIM.lerp(TITLE_COL, _flick)
	var ty := sz.y * 0.34
	draw_string(_font, Vector2(0, ty), title_text, HORIZONTAL_ALIGNMENT_CENTER, sz.x, tsize, tcol)
	var drip_x := sz.x * 0.5 + 70.0
	var drip_len := 18.0 + sin(_t * 0.7) * 10.0
	draw_line(Vector2(drip_x, ty + 6), Vector2(drip_x, ty + 6 + drip_len),
		Color(TITLE_COL.r, TITLE_COL.g, TITLE_COL.b, 0.25 * _flick), 2.0)
	draw_string(_font, Vector2(0, ty + 34), subtitle_text, HORIZONTAL_ALIGNMENT_CENTER, sz.x, 18, SUB_COL)


func _draw_menu(sz: Vector2) -> void:
	_item_rects.clear()
	var my := sz.y * 0.62
	for i in _items.size():
		var s: String = _items[i]
		var col := MENU_SEL if i == _selected else MENU_COL
		var fs := 30 if i == _selected else 26
		var y := my + i * 48.0
		draw_string(_font, Vector2(0, y), s, HORIZONTAL_ALIGNMENT_CENTER, sz.x, fs, col)
		_item_rects.append(Rect2(sz.x * 0.5 - 120, y - 28, 240, 40))
		if i == _selected:
			var mx := sz.x * 0.5 - 130 + sin(_t * 6.0) * 3.0
			draw_circle(Vector2(mx, y - 9), 3.0, MENU_SEL)
	draw_string(_font, Vector2(0, sz.y - 28), "arrows / mouse  ·  enter to select",
		HORIZONTAL_ALIGNMENT_CENTER, sz.x, 14, Color(SUB_COL.r, SUB_COL.g, SUB_COL.b, 0.6))

func _draw_profiles(sz: Vector2) -> void:
	_prects.clear()
	var W := sz.x
	var H := sz.y
	var M: float = clampf(minf(W, H) * 0.05, 30.0, 60.0)
	var cxm := W * 0.5
	var rule := Color(SUB_COL.r, SUB_COL.g, SUB_COL.b, 0.30)

	# ---- top stack (kicker -> title -> divider+label) ----
	var top := M
	var kf: int = int(clampf(H * 0.014, 10.0, 13.0))
	draw_string(_font, Vector2(M, top + kf), "SPECIMEN ARCHIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, kf,
		Color(SUB_COL.r, SUB_COL.g, SUB_COL.b, 0.55))
	draw_string(_font, Vector2(0, top + kf), "SECURE // EYES-ONLY", HORIZONTAL_ALIGNMENT_RIGHT, W - M, kf,
		Color(SUB_COL.r, SUB_COL.g, SUB_COL.b, 0.35))
	top += float(kf) * 1.4

	var ts: int = int(clampf(H * 0.07, 42.0, 76.0))
	var tcol := TITLE_DIM.lerp(TITLE_COL, _flick)
	draw_string(_font, Vector2(M, top + ts), title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, tcol)
	top += float(ts) * 1.05

	var hf: int = int(clampf(H * 0.0175, 13.0, 18.0))
	var lab := "CONTAINMENT MANIFEST     SELECT VESSEL"
	var lab_w := _font.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, hf).x
	var dy := top + float(hf) * 0.6
	var gaphalf := lab_w * 0.5 + 18.0
	draw_line(Vector2(M, dy), Vector2(cxm - gaphalf, dy), rule, 1.0)
	draw_line(Vector2(cxm + gaphalf, dy), Vector2(W - M, dy), rule, 1.0)
	draw_string(_font, Vector2(0, top + hf), lab, HORIZONTAL_ALIGNMENT_CENTER, W, hf,
		Color(SUB_COL.r, SUB_COL.g, SUB_COL.b, 0.8))
	top += float(hf) + H * 0.03

	# ---- bottom stack (footer -> abandon), grown upward ----
	var bot := H - M
	var ff: int = int(clampf(H * 0.0145, 11.0, 15.0))
	draw_string(_font, Vector2(0, bot), "◂ ▸  select      ENTER  seed / resume      X  purge      ESC  back",
		HORIZONTAL_ALIGNMENT_CENTER, W, ff, Color(SUB_COL.r, SUB_COL.g, SUB_COL.b, 0.5))
	bot -= float(ff) + H * 0.022

	var af: int = int(clampf(H * 0.02, 15.0, 20.0))
	var asel := _psel == 3
	var afs: int = int(float(af) * 1.15) if asel else af
	var acol := MENU_SEL if asel else Color(SUB_COL.r, SUB_COL.g, SUB_COL.b, 0.7)
	draw_string(_font, Vector2(0, bot), "ABANDON", HORIZONTAL_ALIGNMENT_CENTER, W, afs, acol)
	if asel:
		var aw := _font.get_string_size("ABANDON", HORIZONTAL_ALIGNMENT_LEFT, -1, afs).x
		var dotx := cxm - aw * 0.5 - 16.0 + sin(_t * 6.0) * 3.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(dotx, bot - float(afs) * 0.55), Vector2(dotx, bot - 1.0),
			Vector2(dotx + 7.0, bot - float(afs) * 0.28)]), MENU_SEL)
	var abandon_rect := Rect2(cxm - 90.0, bot - float(af), 180.0, float(af) + 10.0)
	bot -= float(af) + H * 0.03

	# ---- card band (everything left between the two stacks) ----
	var band_top := top + 16.0
	var band_bot := bot
	var band_w := W - 2.0 * M
	var band_h := band_bot - band_top
	var ar := 0.64
	var gap: float = clampf(W * 0.018, 18.0, 40.0)
	var cw := (band_w - 2.0 * gap) / 3.0
	var ch := cw / ar
	if ch > band_h:
		ch = band_h
		cw = ch * ar
	var total := 3.0 * cw + 2.0 * gap
	var x0 := (W - total) * 0.5
	var cy0 := band_top + (band_h - ch) * 0.5
	for i in 3:
		var rx := x0 + float(i) * (cw + gap)
		var rect := Rect2(rx, cy0, cw, ch)
		_draw_vessel_card(rect, i, i == _psel)
		_prects.append(rect)
		if i == _psel:
			var chx := rx + cw * 0.5
			var chy := cy0 - 12.0 + sin(_t * 6.0) * 2.0
			draw_colored_polygon(PackedVector2Array([
				Vector2(chx - 7.0, chy - 6.0), Vector2(chx + 7.0, chy - 6.0), Vector2(chx, chy + 3.0)]),
				MENU_SEL)
	# ABANDON is _prects[3] (mouse hit-testing relies on this order).
	_prects.append(abandon_rect)


func _draw_vessel_card(rect: Rect2, slot: int, sel: bool) -> void:
	var data := SaveSystem.summary_data(slot)
	var empty: bool = data["empty"]
	var accent: Color = Color("#9fd68a") if not empty else Color("#9a6450")
	if sel:
		accent = accent.lightened(0.18)
	var fl := _flick if sel else 1.0
	var x := rect.position.x
	var y := rect.position.y
	var w := rect.size.x
	var h := rect.size.y
	var pad: float = w * 0.085

	# Opaque body + faint accent tint + scanlines (nothing bleeds through a card).
	draw_rect(rect, Color(0.031, 0.051, 0.039, 1.0))
	draw_rect(Rect2(x + 4.0, y + 4.0, w - 8.0, h - 8.0), Color(accent.r, accent.g, accent.b, 0.045))
	var yy := y + 8.0
	while yy < y + h - 4.0:
		draw_line(Vector2(x + 4.0, yy), Vector2(x + w - 4.0, yy), Color(0, 0, 0, 0.16), 1.0)
		yy += 4.0

	# Header band — filled when selected so the title reads as a live readout.
	var hb: float = h * 0.115
	if sel:
		draw_rect(Rect2(x, y, w, hb), Color(accent.r, accent.g, accent.b, 0.18))
	var hfs: int = int(clampf(w * 0.085, 14.0, 22.0))
	draw_string(_font, Vector2(x, y + hb * 0.5 + float(hfs) * 0.35), "VESSEL %02d" % (slot + 1),
		HORIZONTAL_ALIGNMENT_CENTER, w, hfs, Color(accent.r, accent.g, accent.b, 1.0 if sel else 0.92))
	draw_line(Vector2(x + 12.0, y + hb), Vector2(x + w - 12.0, y + hb),
		Color(accent.r, accent.g, accent.b, 0.4), 1.0)

	# Specimen viewport.
	var vx := x + pad
	var vy := y + hb + pad * 0.6
	var vw := w - pad * 2.0
	var vh: float = h * 0.36
	var vp := Rect2(vx, vy, vw, vh)
	draw_rect(vp, Color(accent.r, accent.g, accent.b, 0.28), false, 1.0)
	var c := vp.get_center()
	if empty:
		var pr: float = vh * 0.32
		draw_arc(c, pr, 0.0, TAU, 28, Color(accent.r, accent.g, accent.b, 0.4), 2.0)
		draw_arc(c, pr * 0.58, 0.0, TAU, 20, Color(accent.r, accent.g, accent.b, 0.22), 1.0)
	else:
		var breath := 1.0 + 0.06 * sin(_t * 2.4 + float(slot))
		var bs: float = clampf(w * 0.013, 2.2, 3.8) * breath
		_draw_bug(c, bs, _t * 3.0 + float(slot), -1)

	# Nameplate.
	var nf: int = int(clampf(w * 0.05, 11.0, 15.0))
	var ny := vy + vh + float(nf) * 1.7
	var nm := ("THREXNA-%02d" % (slot + 1)) if not empty else "— UNSEEDED —"
	draw_string(_font, Vector2(x, ny), nm, HORIZONTAL_ALIGNMENT_CENTER, w, nf,
		Color(accent.r, accent.g, accent.b, 0.88))

	# Prompt zone (shared SEED / RESUME geometry) anchored to the card bottom.
	var pf: int = int(clampf(w * 0.055, 13.0, 18.0))
	var pz_div := y + h - pad * 1.9 - float(pf)
	draw_line(Vector2(x + pad + 6.0, pz_div), Vector2(x + w - pad - 6.0, pz_div),
		Color(accent.r, accent.g, accent.b, 0.22), 1.0)
	var p_base := y + h - pad * 1.1
	var plabel := "▸  SEED" if empty else "▸  RESUME"
	var pcol := MENU_SEL if sel else Color(accent.r, accent.g, accent.b, 0.6)
	draw_string(_font, Vector2(x, p_base), plabel, HORIZONTAL_ALIGNMENT_CENTER, w, pf, pcol)

	# Stat table for live vessels, distributed between nameplate and prompt divider.
	if not empty:
		var sf: int = int(clampf(w * 0.046, 11.0, 14.0))
		var sx := x + pad + 8.0
		var rw := w - (pad + 8.0) * 2.0
		var top_s := ny + float(sf) * 1.4
		var rowh := (pz_div - top_s) / 3.0
		var sc := Color(accent.r, accent.g, accent.b, 0.92)
		var rows := [["FRAGMENTS", "%d / 5" % int(data["fragments"])],
			["GRAFTS", "%d" % int(data["grafts"])],
			["SECTOR", str(data["room"])]]
		for r in 3:
			var ry := top_s + float(r) * rowh + rowh * 0.62
			draw_string(_font, Vector2(sx, ry), rows[r][0], HORIZONTAL_ALIGNMENT_LEFT, rw, sf,
				Color(SUB_COL.r, SUB_COL.g, SUB_COL.b, 0.95))
			draw_string(_font, Vector2(sx, ry), rows[r][1], HORIZONTAL_ALIGNMENT_RIGHT, rw, sf, sc)
			if r < 2:
				var ly := top_s + float(r + 1) * rowh
				draw_line(Vector2(sx, ly), Vector2(sx + rw, ly), Color(accent.r, accent.g, accent.b, 0.10), 1.0)

	# Containment edge: frame (pulsing if selected) + corner brackets.
	var fa: float = (0.55 + 0.45 * sin(_t * 5.0)) if sel else 0.5
	draw_rect(rect, Color(accent.r, accent.g, accent.b, fa * fl), false, 3.0 if sel else 1.5)
	_brackets(rect, Color(accent.r, accent.g, accent.b, fl), 18.0, 3.0 if sel else 2.0)


func _brackets(rect: Rect2, col: Color, n: float, w: float) -> void:
	var p := rect.position
	var s := rect.size
	# top-left
	draw_line(p, p + Vector2(n, 0), col, w)
	draw_line(p, p + Vector2(0, n), col, w)
	# top-right
	draw_line(p + Vector2(s.x, 0), p + Vector2(s.x - n, 0), col, w)
	draw_line(p + Vector2(s.x, 0), p + Vector2(s.x, n), col, w)
	# bottom-left
	draw_line(p + Vector2(0, s.y), p + Vector2(n, s.y), col, w)
	draw_line(p + Vector2(0, s.y), p + Vector2(0, s.y - n), col, w)
	# bottom-right
	draw_line(p + s, p + s - Vector2(n, 0), col, w)
	draw_line(p + s, p + s - Vector2(0, n), col, w)


func _draw_bug(pos: Vector2, s: float, ph: float, dir: int) -> void:
	var fwd := Vector2(dir, 0)
	# Three body segments (abdomen, thorax, head).
	var abdomen := pos - fwd * 7.0 * s
	var thorax := pos
	var head := pos + fwd * 7.0 * s
	# Legs: 3 per side, animated.
	for side in [-1, 1]:
		for i in 3:
			var base := thorax + fwd * (i - 1) * 4.0 * s
			var swing := sin(ph + i * 1.3 + (0.0 if side > 0 else PI)) * 3.0 * s
			var foot := base + Vector2(dir * (2.0 * s), side * 8.0 * s) + Vector2(swing, 0)
			draw_line(base, foot, BUG_COL, maxf(1.0, 1.5 * s))
	draw_circle(abdomen, 6.0 * s, BUG_COL)
	draw_circle(thorax, 4.5 * s, BUG_COL)
	draw_circle(head, 3.5 * s, BUG_COL)
	# Antennae.
	draw_line(head, head + Vector2(dir * 6.0 * s, -5.0 * s + sin(ph) * 1.5), BUG_COL, maxf(1.0, 1.0 * s))
	draw_line(head, head + Vector2(dir * 6.0 * s, 1.0 * s + cos(ph) * 1.5), BUG_COL, maxf(1.0, 1.0 * s))
	# Tiny eyes.
	draw_circle(head + Vector2(dir * 1.5 * s, -1.0 * s), 0.9 * s, EYE_COL)

func _input(event: InputEvent) -> void:
	if _starting:
		return
	if _mode == 1:
		_input_profiles(event)
		return
	if event.is_action_pressed("ui_down"):
		_move_sel(1)
	elif event.is_action_pressed("ui_up"):
		_move_sel(-1)
	elif event.is_action_pressed("ui_accept"):
		_activate()
	elif event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in _item_rects.size():
			if _item_rects[i].has_point(event.position):
				_selected = i
				_activate()

func _input_profiles(event: InputEvent) -> void:
	if event.is_action_pressed("ui_right"):
		_psel = (_psel + 1) % 4
		_play_blip(660.0)
	elif event.is_action_pressed("ui_left"):
		_psel = (_psel + 3) % 4
		_play_blip(660.0)
	elif event.is_action_pressed("ui_down"):
		_psel = 3                      # drop to ABANDON
		_play_blip(660.0)
	elif event.is_action_pressed("ui_up"):
		if _psel == 3:
			_psel = 1                  # back up to the middle vessel
			_play_blip(660.0)
	elif event.is_action_pressed("ui_accept"):
		_activate()
	elif event.is_action_pressed("ui_cancel"):
		_mode = 0
		_play_blip(440.0)
	elif event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_DELETE or event.keycode == KEY_X):
		if _psel < 3:
			SaveSystem.clear(_psel)        # purge that vessel
			_play_blip(280.0)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in _prects.size():
			if _prects[i].has_point(event.position):
				_psel = i
				_activate()

func _move_sel(d: int) -> void:
	_selected = (_selected + d + _items.size()) % _items.size()
	_play_blip(660.0)

func _update_mouse_selection() -> void:
	var mp := get_global_mouse_position()
	if _mode == 1:
		for i in _prects.size():
			if _prects[i].has_point(mp) and _psel != i:
				_psel = i
				_play_blip(660.0)
		return
	for i in _item_rects.size():
		if _item_rects[i].has_point(mp) and _selected != i:
			_selected = i
			_play_blip(660.0)

func _activate() -> void:
	if _mode == 0:
		if _items[_selected] == "QUIT":
			get_tree().quit()
		else:
			_mode = 1                       # START -> choose a vessel
			_psel = 0
			_play_blip(880.0)
		return
	# Profile select.
	if _psel == 3:
		_mode = 0
		_play_blip(440.0)
		return
	SaveSystem.set_slot(_psel)
	_start_game()

func _start_game() -> void:
	if _starting:
		return
	_starting = true
	_play_blip(990.0)
	await get_tree().create_timer(0.22).timeout
	get_tree().change_scene_to_file(level_scene_path)

# --- procedural audio (local to the title) ---

func _play_blip(freq: float) -> void:
	_blip.stream = _make_blip(freq)
	_blip.play()

func _make_blip(freq: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(0.06 * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var w := sin(float(i) * freq / rate * TAU)
		var dec := pow(1.0 - float(i) / n, 2.0)
		var v := int(clampf(w * dec * 0.25, -1.0, 1.0) * 32767.0)
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	return _wav(data, rate, false)

func _make_drone() -> AudioStreamWAV:
	var rate := 22050
	var n := rate                       # 1.0s; integer cycles below = seamless loop
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var tone := sin(55.0 * t * TAU) * 0.6 + sin(110.0 * t * TAU) * 0.35
		var trem := 0.6 + 0.4 * sin(1.0 * t * TAU)   # 1 Hz pulse = seamless over 1s
		var v := int(clampf(tone * trem * 0.5, -1.0, 1.0) * 32767.0)
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	var s := _wav(data, rate, true)
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = n
	return s

func _wav(data: PackedByteArray, rate: int, _loop: bool) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = data
	return s

func _vp() -> Vector2:
	var r := get_viewport_rect().size
	return r if r.x > 0 else Vector2(960, 540)
