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
@export var level_scene_path: String = "res://scenes/world.tscn"

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

	# Title with breathing pulse + flicker.
	var pulse := 1.0 + sin(_t * 1.4) * 0.02
	var tsize := int(84 * pulse)
	var tcol := TITLE_DIM.lerp(TITLE_COL, _flick)
	var ty := sz.y * 0.34
	draw_string(_font, Vector2(0, ty), title_text, HORIZONTAL_ALIGNMENT_CENTER, sz.x, tsize, tcol)
	# A faint ichor drip under the title.
	var drip_x := sz.x * 0.5 + 70.0
	var drip_len := 18.0 + sin(_t * 0.7) * 10.0
	draw_line(Vector2(drip_x, ty + 6), Vector2(drip_x, ty + 6 + drip_len), Color(TITLE_COL.r, TITLE_COL.g, TITLE_COL.b, 0.25 * _flick), 2.0)

	draw_string(_font, Vector2(0, ty + 34), subtitle_text, HORIZONTAL_ALIGNMENT_CENTER, sz.x, 18, SUB_COL)

	# Menu / profile select.
	if _mode == 0:
		_item_rects.clear()
		var my := sz.y * 0.62
		for i in _items.size():
			var s : String = _items[i]
			var col := MENU_SEL if i == _selected else MENU_COL
			var fs := 30 if i == _selected else 26
			var y := my + i * 48.0
			draw_string(_font, Vector2(0, y), s, HORIZONTAL_ALIGNMENT_CENTER, sz.x, fs, col)
			_item_rects.append(Rect2(sz.x * 0.5 - 120, y - 28, 240, 40))
			if i == _selected:
				var mx := sz.x * 0.5 - 130 + sin(_t * 6.0) * 3.0
				draw_circle(Vector2(mx, y - 9), 3.0, MENU_SEL)
		draw_string(_font, Vector2(0, sz.y - 28), "arrows / mouse  ·  enter to select", HORIZONTAL_ALIGNMENT_CENTER, sz.x, 14, Color(SUB_COL.r, SUB_COL.g, SUB_COL.b, 0.6))
	else:
		_draw_profiles(sz)

func _draw_profiles(sz: Vector2) -> void:
	draw_string(_font, Vector2(0, sz.y * 0.5), "SELECT VESSEL", HORIZONTAL_ALIGNMENT_CENTER, sz.x, 22, SUB_COL)
	_prects.clear()
	var my := sz.y * 0.56
	for i in 3:
		var sel := i == _psel
		var col := MENU_SEL if sel else MENU_COL
		var y := my + i * 44.0
		var name := "VESSEL %d" % (i + 1)
		var sub : String = SaveSystem.summary(i)
		draw_string(_font, Vector2(sz.x * 0.5 - 200, y), name, HORIZONTAL_ALIGNMENT_LEFT, 200, 24 if sel else 22, col)
		draw_string(_font, Vector2(sz.x * 0.5 - 10, y), sub, HORIZONTAL_ALIGNMENT_LEFT, 260, 18, Color(col.r, col.g, col.b, 0.8))
		_prects.append(Rect2(sz.x * 0.5 - 210, y - 26, 470, 38))
		if sel:
			draw_circle(Vector2(sz.x * 0.5 - 220 + sin(_t * 6.0) * 3.0, y - 9), 3.0, MENU_SEL)
	# BACK row
	var by := my + 3 * 44.0 + 14.0
	var bcol := MENU_SEL if _psel == 3 else MENU_COL
	draw_string(_font, Vector2(0, by), "BACK", HORIZONTAL_ALIGNMENT_CENTER, sz.x, 24 if _psel == 3 else 22, bcol)
	_prects.append(Rect2(sz.x * 0.5 - 80, by - 26, 160, 38))
	draw_string(_font, Vector2(0, sz.y - 28), "enter: play  ·  X / Del: erase  ·  esc: back", HORIZONTAL_ALIGNMENT_CENTER, sz.x, 14, Color(SUB_COL.r, SUB_COL.g, SUB_COL.b, 0.6))

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
	if event.is_action_pressed("ui_down"):
		_psel = (_psel + 1) % 4
		_play_blip(660.0)
	elif event.is_action_pressed("ui_up"):
		_psel = (_psel + 3) % 4
		_play_blip(660.0)
	elif event.is_action_pressed("ui_accept"):
		_activate()
	elif event.is_action_pressed("ui_cancel"):
		_mode = 0
		_play_blip(440.0)
	elif event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_DELETE or event.keycode == KEY_X):
		if _psel < 3:
			SaveSystem.clear(_psel)        # erase that vessel
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
