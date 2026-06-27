extends Area2D
class_name ShipPart
## A piece of your wrecked ship, sitting out in the world behind an ability gate.
## You SEE it on the first pass and can't reach it; you come back when you can.
## Banks one fragment on the player and reveals it; doesn't respawn once taken.
## Gating is PHYSICAL (geometry), so `required` is only for the codex/flavor hint.

@export var fragment_id: String = ""
@export var display_name: String = "SHIP FRAGMENT"
@export var required: String = ""           # flavor: which graft this sits behind
@export var color: Color = Color("#9fe6ff")

var _t: float = 0.0
var _taken := false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 3                       # the player (layer 1 or 2)
	monitoring = true
	if get_child_count() == 0:
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = Vector2(26, 26)
		cs.shape = rs
		add_child(cs)
	body_entered.connect(_on_body)
	set_process(true)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	if _taken:
		return
	var pulse := 0.65 + 0.35 * sin(_t * 3.0)
	# a turning shard of hull
	var r := 13.0
	draw_circle(Vector2.ZERO, r + 4.0, Color(color.r, color.g, color.b, 0.14 * pulse))
	var pts := PackedVector2Array()
	for i in 4:
		var a := _t * 0.8 + float(i) * PI * 0.5
		var rad := r if (i % 2 == 0) else r * 0.6
		pts.append(Vector2(cos(a), sin(a)) * rad)
	draw_colored_polygon(pts, Color(color.r, color.g, color.b, 0.85))
	draw_circle(Vector2.ZERO, 3.0, Color(0.9, 0.98, 1.0, pulse))

func _on_body(b: Node) -> void:
	if _taken or not b.is_in_group("player"):
		return
	if not b.has_method("collect_fragment"):
		return
	if b.collect_fragment(fragment_id):
		_taken = true
		Audio.play("charge_ready")
		get_tree().call_group("game", "reveal", fragment_id, display_name)
		get_tree().call_group("level", "save_progress")
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(1.6, 1.6), 0.25)
		tw.parallel().tween_property(self, "modulate:a", 0.0, 0.25)
		tw.tween_callback(queue_free)
