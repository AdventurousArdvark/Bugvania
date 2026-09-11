extends StaticBody2D
class_name FrontierGate
## A SEALED FRONTIER — the edge of the built world. Where a region borders one that
## isn't built yet, we don't leave a raw opening; we stand a named, sealed door here so
## the world always reads as whole. It shows the neighbor's themed name (from the Atlas),
## a "sealed" sub-line, and pulses hazard chevrons toward what lies beyond.
##
## When that neighbor region ships, its module REPLACES this gate with a real door — the
## coordinates already line up, so nothing has to be reconnected after the fact.
##
## Self-contained: FrontierGate.new(), set `to_area` (an Atlas area id) + `size` + `face`,
## add as a child. It builds its own collision and draws itself.

@export var to_area: String = ""            # Atlas area id of the region beyond
@export var size: Vector2 = Vector2(32.0, 128.0)
@export var face: int = 1                    # +1 = beyond is to the right, -1 = to the left
@export var opens_with: String = ""          # flavor: the ability that will breach it later

var _t: float = 0.0
var _font: Font
var _name: String = "UNCHARTED"
var _sub: String = "the survey ends here"
var _accent: Color = Color("#7f8a9a")

func _ready() -> void:
	_font = ThemeDB.fallback_font
	collision_layer = 1
	collision_mask = 0
	var col := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = size
	col.shape = rs
	add_child(col)
	var a := Atlas.area(to_area)
	if not a.is_empty():
		_name = str(a.get("name", _name))
		_sub = str(a.get("sub", _sub))
		_accent = a.get("map_color", _accent)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var hw := size.x * 0.5
	var hh := size.y * 0.5
	# Sealed slab.
	draw_rect(Rect2(-hw, -hh, size.x, size.y), Color(0.05, 0.06, 0.07, 1.0))
	draw_rect(Rect2(-hw, -hh, size.x, size.y), Color(_accent.r, _accent.g, _accent.b, 0.55), false, 2.0)
	# Seal bars across the door.
	var bars := 5
	for i in bars:
		var y := -hh + size.y * (float(i) + 0.5) / float(bars)
		draw_line(Vector2(-hw + 3.0, y), Vector2(hw - 3.0, y), Color(_accent.r, _accent.g, _accent.b, 0.22), 3.0)
	# Hazard chevrons pulsing toward the beyond.
	var pulse := 0.4 + 0.35 * sin(_t * 3.0)
	var cc := Color(_accent.r, _accent.g, _accent.b, pulse)
	for i in 3:
		var ox := float(face) * (hw + 6.0 + float(i) * 9.0 + sin(_t * 3.0 - float(i)) * 2.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(ox, -8.0), Vector2(ox + float(face) * 7.0, 0.0), Vector2(ox, 8.0)]), cc)
	# Name + sealed sub, on the beyond side of the door.
	var tx := float(face) * (hw + 34.0)
	var align := HORIZONTAL_ALIGNMENT_LEFT if face > 0 else HORIZONTAL_ALIGNMENT_RIGHT
	var box := 260.0
	var lx := tx if face > 0 else tx - box
	draw_string(_font, Vector2(lx, -6.0), _name, align, box, 15,
		Color(_accent.r, _accent.g, _accent.b, 0.9))
	draw_string(_font, Vector2(lx, 14.0), "SEALED · " + _sub, align, box, 11,
		Color(_accent.r, _accent.g, _accent.b, 0.5))
	if opens_with != "":
		draw_string(_font, Vector2(lx, 30.0), "requires: " + opens_with.replace("has_", "").replace("_", " "),
			align, box, 10, Color(_accent.r, _accent.g, _accent.b, 0.4))
