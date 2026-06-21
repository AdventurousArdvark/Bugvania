extends StaticBody2D
class_name OnewayPlatform
## A one-way membrane: solid from above (you land and stand on it) but passable from
## below (you jump up through it). Uses Godot's one-way collision so it composes with
## the normal movement code for free.

@export var span: float = 96.0
@export var thickness: float = 10.0
@export var color: Color = Color("#46586e")

func _ready() -> void:
	collision_layer = 1                 # solid World (one-way)
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(span, thickness)
	cs.shape = r
	cs.one_way_collision = true         # blocks from the shape's "up" side only
	cs.one_way_collision_margin = 4.0
	add_child(cs)

func _draw() -> void:
	var hw := span * 0.5
	var hh := thickness * 0.5
	draw_rect(Rect2(-hw, -hh, span, thickness), color)
	draw_line(Vector2(-hw, -hh), Vector2(hw, -hh), color.lightened(0.4), 1.5)   # solid top edge
	# Dashed underside to read as permeable from below.
	var dash := 8.0
	var x := -hw
	while x < hw:
		draw_line(Vector2(x, hh), Vector2(minf(x + dash * 0.5, hw), hh), Color(color.r, color.g, color.b, 0.5), 1.0)
		x += dash
