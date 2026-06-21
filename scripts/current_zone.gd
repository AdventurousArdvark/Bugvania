extends Area2D
class_name CurrentZone
## A region that pushes the player while inside — updraft, wind, or water flow.
## Feeds the push to the player's apply_current(); it fades on exit so you carry a
## little momentum out. Purely additive: your own movement still works inside it.

@export var area_size: Vector2 = Vector2(96, 192)
@export var push: Vector2 = Vector2(0, -540)   # default: an updraft
@export var color: Color = Color("#7fdcff")

var _t: float = 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2                  # the player
	monitoring = true
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = area_size
	cs.shape = r
	add_child(cs)

func _physics_process(delta: float) -> void:
	_t += delta
	for b in get_overlapping_bodies():
		if b.has_method("apply_current"):
			b.apply_current(push)
	queue_redraw()

func _draw() -> void:
	var hw := area_size.x * 0.5
	var hh := area_size.y * 0.5
	draw_rect(Rect2(-hw, -hh, area_size.x, area_size.y), Color(color.r, color.g, color.b, 0.08))
	draw_rect(Rect2(-hw, -hh, area_size.x, area_size.y), Color(color.r, color.g, color.b, 0.22), false, 1.5)
	# Drifting chevrons that flow along the push direction.
	var dir := push.normalized()
	var tan := Vector2(-dir.y, dir.x)
	var span := area_size.y if absf(dir.y) > absf(dir.x) else area_size.x
	var lanes := 3
	for L in lanes:
		var off := tan * lerpf(-0.6, 0.6, float(L) / float(lanes - 1)) * (hw if absf(dir.y) > absf(dir.x) else hh)
		for k in 3:
			var phase := fmod(_t * 0.6 + float(k) / 3.0, 1.0)
			var c := off + dir * (span * (phase - 0.5))
			var s := 7.0
			draw_line(c - tan * s - dir * s, c, Color(color.r, color.g, color.b, 0.5), 1.5)
			draw_line(c + tan * s - dir * s, c, Color(color.r, color.g, color.b, 0.5), 1.5)
