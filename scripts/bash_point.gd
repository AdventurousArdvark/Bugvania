extends Area2D
class_name BashPoint
## A fixed hook the player can bash off to cross a gap. Put these over chasms.
## Bash detection is handled by the player's sensor; this just sits in the world
## on layer 4 and in group "bashable". Draws a slowly pulsing ring so it reads.

@export var color: Color = Color("#bff0c0")
@export var radius: float = 12.0

var _t: float = 0.0
var _draw_node: Node2D = null

func _ready() -> void:
	add_to_group("bashable")
	collision_layer = 4
	collision_mask = 0
	monitorable = true
	monitoring = false
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius
	cs.shape = c
	add_child(cs)
	_draw_node = _Ring.new()
	_draw_node.owner_point = self
	add_child(_draw_node)

func _process(delta: float) -> void:
	_t += delta
	if _draw_node != null:
		_draw_node.queue_redraw()

class _Ring extends Node2D:
	var owner_point: BashPoint = null
	func _draw() -> void:
		if owner_point == null:
			return
		var pulse: float = 0.5 + 0.5 * sin(owner_point._t * 3.0)
		var r: float = owner_point.radius
		var col: Color = owner_point.color
		draw_circle(Vector2.ZERO, r * (0.9 + 0.25 * pulse), Color(col.r, col.g, col.b, 0.18))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(col.r, col.g, col.b, 0.7), 2.0)
		draw_circle(Vector2.ZERO, 2.5, col)
