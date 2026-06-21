extends Area2D
class_name Spikes
## A static spike strip. Mount on any surface by pointing `normal` away from it
## (UP = floor spikes, DOWN = ceiling, LEFT/RIGHT = wall). Damages + knocks the
## player back along the normal while overlapping; i-frames gate repeat ticks.

@export var span: float = 96.0          # width along the surface
@export var depth: float = 16.0         # how far the spikes stick out
@export var normal: Vector2 = Vector2.UP
@export var damage: int = 12
@export var color: Color = Color("#cdd6de")

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2                  # the player body
	monitoring = true
	var horiz := absf(normal.y) >= absf(normal.x)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(span, depth) if horiz else Vector2(depth, span)
	cs.shape = r
	cs.position = normal.normalized() * depth * 0.5
	add_child(cs)

func _physics_process(_delta: float) -> void:
	for b in get_overlapping_bodies():
		if b.has_method("take_damage"):
			b.take_damage(damage, global_position - normal.normalized() * 8.0)

func _draw() -> void:
	var n := normal.normalized()
	var tan := Vector2(-n.y, n.x)
	var teeth := maxi(2, int(span / maxf(depth, 1.0)))
	var w := span / float(teeth)
	for i in teeth:
		var c := tan * (-span * 0.5 + (float(i) + 0.5) * w)
		var a := c - tan * w * 0.5
		var b := c + tan * w * 0.5
		var tip := c + n * depth
		draw_colored_polygon(PackedVector2Array([a, b, tip]), color)
		draw_line(a, tip, color.lightened(0.3), 1.0)
	# base rail
	draw_line(tan * -span * 0.5, tan * span * 0.5, color.darkened(0.3), 2.0)
