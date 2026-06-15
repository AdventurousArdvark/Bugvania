extends Area2D
class_name LevelExit
## Reusable end-of-level trigger. Emits `reached`, prints a marker, and optionally
## loads the next scene. Self-contained (builds its own shape + visual in code).

@export var size: Vector2 = Vector2(48, 96)
@export var color: Color = Color("#7fd3ff")
@export var next_scene: String = ""   # res:// path; leave empty to just signal

signal reached

func _ready() -> void:
	collision_mask = 3
	monitoring = true
	if get_child_count() == 0:
		_build_visual()
	body_entered.connect(_on_body_entered)

func _build_visual() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	add_child(shape)
	var hw := size.x * 0.5
	var hh := size.y * 0.5
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh),
	])
	poly.color = color
	add_child(poly)

func _on_body_entered(body: Node) -> void:
	if not (body is CharacterBody2D):
		return
	reached.emit()
	print("LEVEL COMPLETE")
	if next_scene != "":
		get_tree().change_scene_to_file(next_scene)
