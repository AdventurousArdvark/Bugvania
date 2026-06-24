extends CanvasLayer
class_name Hud
## Bug-themed HUD. Health reads as a row of CHITIN PLATES that crack and darken as
## you take hits; missile ammo reads as organic PODS. Listens to the player's
## health_changed / missiles_changed signals (no per-frame polling).
##
## Extension point for later: a small silhouette of your bug showing the parts
## you've assembled (double-jump wing, beam mandible, etc.). Draw it in _render.

@export var plate_count: int = 8

# Chitin palette.
const CHITIN      := Color("#5fa86b")
const CHITIN_EDGE := Color("#9be0a8")
const CRACKED     := Color("#24332a")
const CRACK_LINE  := Color("#0e1612")
const POD_ON      := Color("#ff8c42")
const POD_OFF     := Color("#3a2a1e")

var _player: Node = null
var _health: int = 0
var _max_health: int = 1
var _missiles: int = 0
var _max_missiles: int = 0
var _boss_hp: int = 0
var _boss_max: int = 1
var _boss_show: bool = false
var _boss_phase: int = 1
var _font: Font
var _draw_node: Control = null

# Inner Control whose _draw delegates back to the HUD.
class HudDraw extends Control:
	var hud
	func _draw() -> void:
		if hud != null:
			hud._render(self)

func _ready() -> void:
	layer = 10
	add_to_group("hud")
	_font = ThemeDB.fallback_font
	_draw_node = HudDraw.new()
	(_draw_node as HudDraw).hud = self
	_draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_draw_node)

func _process(_delta: float) -> void:
	pass

func bind(player: Node) -> void:
	_player = player
	if player == null:
		return
	_max_health = int(player.get("max_health"))
	_health = int(player.get("health"))
	_max_missiles = int(player.get("max_missiles"))
	_missiles = int(player.get("missiles"))
	if player.has_signal("health_changed"):
		player.health_changed.connect(_on_health)
	if player.has_signal("missiles_changed"):
		player.missiles_changed.connect(_on_missiles)
	_redraw()

func _on_health(current: int, maximum: int) -> void:
	_health = current
	_max_health = maximum
	_redraw()

func _on_missiles(current: int, maximum: int) -> void:
	_missiles = current
	_max_missiles = maximum
	_redraw()

func bind_boss(boss: Node) -> void:
	if boss == null:
		return
	_boss_max = int(boss.get("max_health"))
	_boss_hp = int(boss.get("health"))
	_boss_show = false                      # stays hidden until the fight is engaged
	if boss.has_signal("health_changed"):
		boss.health_changed.connect(_on_boss_health)
	if boss.has_signal("engaged"):
		boss.engaged.connect(_on_boss_engaged)
	if boss.has_signal("disengaged"):
		boss.disengaged.connect(_on_boss_disengaged)
	if boss.has_signal("phase_changed"):
		boss.phase_changed.connect(_on_boss_phase)
	_boss_phase = 1

func _on_boss_phase(phase: int) -> void:
	_boss_phase = phase
	_boss_show = true                       # the second bar appears (don't stay hidden)
	_redraw()

func _on_boss_disengaged() -> void:
	_boss_show = false
	_redraw()
	_redraw()

func _on_boss_engaged() -> void:
	_boss_show = true
	_redraw()

func _on_boss_health(current: int, maximum: int) -> void:
	_boss_hp = current
	_boss_max = maximum
	if current <= 0:
		_boss_show = false                  # hide on death; only "engaged" shows it
	_redraw()

func _redraw() -> void:
	if _draw_node != null:
		_draw_node.queue_redraw()

func _render(c: Control) -> void:
	var x0 := 16.0
	var y0 := 16.0
	var pw := 26.0
	var ph := 20.0
	var gap := 6.0
	var filled := int(round(float(_health) / float(maxi(_max_health, 1)) * plate_count))
	for i in range(plate_count):
		_plate(c, Vector2(x0 + i * (pw + gap), y0), Vector2(pw, ph), i < filled)

	# Ammo pods only once you've assembled the stinger (have missiles).
	if _player != null and _player.get("has_missiles") == true:
		var ay := y0 + ph + 12.0
		for i in range(_max_missiles):
			var ax := x0 + i * 14.0
			c.draw_circle(Vector2(ax + 5.0, ay + 6.0), 5.0, POD_ON if i < _missiles else POD_OFF)

	# Boss bar at the BOTTOM center, clear of the top-left chitin plates.
	if _boss_show:
		var vw := c.size.x
		var bw := vw * 0.5
		var bx := (vw - bw) * 0.5
		var by := c.size.y - 50.0
		var bar_col := Color("#ff7a3c") if _boss_phase >= 2 else Color("#c8455f")
		var label := "VESSEL — ASCENDANT" if _boss_phase >= 2 else "VESSEL"
		c.draw_string(_font, Vector2(0, by - 6), label, HORIZONTAL_ALIGNMENT_CENTER, vw, 14, bar_col)
		c.draw_rect(Rect2(bx - 2, by, bw + 4, 16), Color("#1a0f1f"))
		c.draw_rect(Rect2(bx, by + 2, bw, 12), Color("#2a1830"))
		var frac := clampf(float(_boss_hp) / float(maxi(_boss_max, 1)), 0.0, 1.0)
		c.draw_rect(Rect2(bx, by + 2, bw * frac, 12), bar_col)

func _plate(c: Control, pos: Vector2, size: Vector2, full: bool) -> void:
	var w := size.x
	var h := size.y
	# A hexagonal plate reads as carapace rather than a UI bar.
	var pts := PackedVector2Array([
		pos + Vector2(w * 0.2, 0), pos + Vector2(w * 0.8, 0),
		pos + Vector2(w, h * 0.5),
		pos + Vector2(w * 0.8, h), pos + Vector2(w * 0.2, h),
		pos + Vector2(0, h * 0.5),
	])
	if full:
		c.draw_colored_polygon(pts, CHITIN)
		var outline := pts.duplicate()
		outline.append(pts[0])
		c.draw_polyline(outline, CHITIN_EDGE, 1.5)
	else:
		c.draw_colored_polygon(pts, CRACKED)
		# Cracks across the dead plate.
		c.draw_line(pos + Vector2(w * 0.3, h * 0.2), pos + Vector2(w * 0.65, h * 0.85), CRACK_LINE, 1.5)
		c.draw_line(pos + Vector2(w * 0.6, h * 0.3), pos + Vector2(w * 0.45, h * 0.6), CRACK_LINE, 1.0)
