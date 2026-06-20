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

var room_bounds: Rect2 = Rect2()    # set by the level; patroller stays inside it

var health: int
var _dir: int = 1
var _gravity: float = 1300.0
var _origin_x: float = 0.0
var _have_origin: bool = false
var _frozen_t: float = 0.0
var _hitbox: Area2D = null
var _knock_t: float = 0.0

func _ready() -> void:
	health = max_health
	collision_layer = 4      # Enemies layer (so beams hit it, pickups/doors ignore it)
	collision_mask = 1       # collide with World only
	add_to_group("enemy")
	add_to_group("bashable")
	if get_child_count() == 0:
		_build()

func _build() -> void:
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	add_child(cs)

	var visual := EnemyVisual.new()
	visual.kind = "crawler"
	visual.base_color = color
	visual.box = size
	add_child(visual)

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

	if _knock_t > 0.0:
		_knock_t -= delta
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	elif patrol:
		velocity.x = _dir * move_speed
		if global_position.x > _origin_x + patrol_range:
			_dir = -1
		elif global_position.x < _origin_x - patrol_range:
			_dir = 1
		if is_on_wall() or not _ground_ahead(_dir):
			_dir = -_dir
		# Turn before leaving the room.
		if room_bounds.size != Vector2.ZERO:
			var hw := size.x * 0.5
			if global_position.x <= room_bounds.position.x + hw:
				_dir = 1
			elif global_position.x >= room_bounds.position.x + room_bounds.size.x - hw:
				_dir = -1

	move_and_slide()

	# Confine horizontally and to the top; if knocked into a pit, die instead of float.
	if room_bounds.size != Vector2.ZERO:
		var hw2 := size.x * 0.5
		var hh2 := size.y * 0.5
		var p := global_position
		p.x = clampf(p.x, room_bounds.position.x + hw2, room_bounds.position.x + room_bounds.size.x - hw2)
		if p.y < room_bounds.position.y + hh2:
			p.y = room_bounds.position.y + hh2
		global_position = p
		if global_position.y > room_bounds.position.y + room_bounds.size.y + hh2:
			die()

func _ground_ahead(dir: int) -> bool:
	if not is_on_floor():
		return true
	var hw := size.x * 0.5
	var hh := size.y * 0.5
	var space := get_world_2d().direct_space_state
	var from := global_position + Vector2(float(dir) * (hw + 4.0), hh - 2.0)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, 16.0), 1)
	q.exclude = [self]
	return not space.intersect_ray(q).is_empty()

func take_damage(amount: int, props: Dictionary = {}) -> void:
	health -= amount
	var hd = props.get("hit_dir", Vector2.ZERO)
	if hd != Vector2.ZERO:
		velocity.x = hd.x * 160.0
		_knock_t = 0.15
	if props.get("element", "") == "ice":
		_frozen_t = 2.0                 # Ice: freeze it...
		modulate = Color("#bfe9ff")
		collision_layer = 1 | 4         # ...and make it solid World so you can stand on it
		if _hitbox != null:
			_hitbox.monitoring = false  # harmless while frozen
	else:
		_flash()
		Audio.play("hit")
	if health <= 0:
		die()

func _flash() -> void:
	modulate = Color(2, 2, 2)
	var t := get_tree().create_timer(0.08)
	t.timeout.connect(func():
		if is_instance_valid(self) and _frozen_t <= 0.0:
			modulate = Color.WHITE)

func die() -> void:
	Audio.play("enemy_die")
	Fx.burst(get_parent(), global_position, color, 9, 180.0)
	get_tree().call_group("camera_rig", "shake", 4.0, 0.15)
	get_tree().call_group("game", "hitstop", 0.06)   # brief killing-blow freeze
	# Dissolve: stop, shrink, fade, then free.
	set_physics_process(false)
	if _hitbox != null:
		_hitbox.monitoring = false
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.12)
	t.parallel().tween_property(self, "scale", Vector2(0.4, 0.4), 0.12)
	t.tween_callback(queue_free)

func _on_contact(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(contact_damage, global_position)
