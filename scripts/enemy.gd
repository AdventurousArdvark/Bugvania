extends CharacterBody2D
class_name Enemy
## A minimal target so the beam has something to matter against. Patrols a short
## range, takes damage (with a hook for elemental reactions like Ice freeze), and
## deals contact damage to the player. Self-contained: builds its own shape,
## visual, and contact hitbox if you don't give it children.

@export var max_health: int = 5
@export var move_speed: float = 60.0
@export var patrol: bool = true
@export var patrol_range: float = 80.0
@export var contact_damage: int = 10
@export var size: Vector2 = Vector2(24, 24)
@export var color: Color = Color("#c0432f")

var health: int
var _dir: int = 1
var _gravity: float = 1300.0
var _origin_x: float = 0.0
var _have_origin: bool = false
var _frozen_t: float = 0.0
var _hitbox: Area2D = null

func _ready() -> void:
	health = max_health
	collision_layer = 4      # Enemies layer (so beams hit it, pickups/doors ignore it)
	collision_mask = 1       # collide with World only
	add_to_group("enemy")
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

	# Contact-damage hitbox (sees the player only).
	var hb := Area2D.new()
	hb.collision_layer = 0
	hb.collision_mask = 2
	add_child(hb)
	_hitbox = hb
	var hcs := CollisionShape2D.new()
	var hrect := RectangleShape2D.new()
	hrect.size = size
	hcs.shape = hrect
	hb.add_child(hcs)
	hb.body_entered.connect(_on_contact)

func _physics_process(delta: float) -> void:
	if not _have_origin:
		_origin_x = global_position.x
		_have_origin = true

	if _frozen_t > 0.0:
		_frozen_t -= delta
		velocity = Vector2.ZERO
		move_and_slide()
		if _frozen_t <= 0.0:
			modulate = Color.WHITE
			collision_layer = 4              # back to a normal (non-solid) enemy
			if _hitbox != null:
				_hitbox.monitoring = true
		return

	velocity.y = 0.0 if is_on_floor() else velocity.y + _gravity * delta

	if patrol:
		velocity.x = _dir * move_speed
		if global_position.x > _origin_x + patrol_range:
			_dir = -1
		elif global_position.x < _origin_x - patrol_range:
			_dir = 1
		if is_on_wall():
			_dir = -_dir

	move_and_slide()

func take_damage(amount: int, props: Dictionary = {}) -> void:
	health -= amount
	if props.get("element", "") == "ice":
		_frozen_t = 2.0                 # Ice: freeze it...
		modulate = Color("#bfe9ff")
		collision_layer = 1 | 4         # ...and make it solid World so you can stand on it
		if _hitbox != null:
			_hitbox.monitoring = false  # harmless while frozen
	else:
		_flash()
	if health <= 0:
		die()

func _flash() -> void:
	modulate = Color(2, 2, 2)
	var t := get_tree().create_timer(0.08)
	t.timeout.connect(func():
		if is_instance_valid(self) and _frozen_t <= 0.0:
			modulate = Color.WHITE)

func die() -> void:
	# Later: drop a pickup / play an effect here.
	queue_free()

func _on_contact(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(contact_damage, global_position)
