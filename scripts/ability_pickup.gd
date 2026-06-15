extends Area2D
class_name AbilityPickup
## Reusable pickup that grants ONE flat ability flag to the player.
## Set `ability` to the exact player property name, e.g. "has_double_jump".
##
## Flat-flag design: this never touches a progress counter or fires a cutscene.
## It flips one boolean and frees itself. That's the whole contract, which is why
## grabbing abilities out of order can never desync the world.
##
## Self-contained: works whether you drop it in the editor or create it in code
## with AbilityPickup.new() — it builds its own collision shape and placeholder
## visual if you don't give it children.

@export var ability: String = "has_double_jump"
@export var size: Vector2 = Vector2(20, 20)
@export var color: Color = Color("#ffd34d")
@export var bob_height: float = 5.0
@export var bob_speed: float = 2.5

signal collected(ability_name)

var _base_y: float
var _t: float = 0.0

func _ready() -> void:
	collision_mask = 3   # detect the player whether it's on physics layer 1 or 2
	monitoring = true
	if get_child_count() == 0:
		_build_visual()
	body_entered.connect(_on_body_entered)
	_base_y = position.y

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

func _process(delta: float) -> void:
	_t += delta * bob_speed
	position.y = _base_y + sin(_t) * bob_height   # gentle bob so it reads as a pickup

func _on_body_entered(body: Node) -> void:
	if not (body is CharacterBody2D):
		return
	body.set(ability, true)        # flip the flat flag
	collected.emit(ability)
	# NOTE: across save/load you'd persist "this pickup is taken" in a save system;
	# for now it just disappears for the session.
	queue_free()
