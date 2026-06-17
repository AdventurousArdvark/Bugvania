extends StaticBody2D
class_name MissileDoor
## A solid door that blocks the player AND stops normal beams, but opens when hit
## by a missile. This is the traversal half of the Metroid upgrade model: a weapon
## doubles as a key. The projectile calls on_projectile_hit() on contact.

@export var size: Vector2 = Vector2(16, 96)
@export var color: Color = Color("#b6483c")

signal opened

func _ready() -> void:
	collision_layer = 1     # solid World: blocks the player and stops beams
	collision_mask = 0
	if get_child_count() == 0:
		_build()

func _build() -> void:
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	add_child(cs)
	var hw := size.x * 0.5
	var hh := size.y * 0.5
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh),
	])
	poly.color = color
	add_child(poly)

func on_projectile_hit(properties: Dictionary, _damage: int) -> void:
	if properties.get("element", "") == "missile":
		opened.emit()
		Audio.play("door")
		queue_free()        # door gone -> the way is open
