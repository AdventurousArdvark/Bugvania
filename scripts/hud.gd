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
var _draw_node: Control = null

# Inner Control whose _draw delegates back to the HUD.
class HudDraw extends Control:
	var hud
	func _draw() -> void:
		if hud != null:
			hud._render(self)

func _ready() -> void:
	layer = 10
	_draw_node = HudDraw.new()
	(_draw_node as HudDraw).hud = self
	_draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_draw_node)

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
