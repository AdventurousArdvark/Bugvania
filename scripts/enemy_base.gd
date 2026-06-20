extends CharacterBody2D
class_name EnemyBase
## Shared behavior for all enemies: health, ice-freeze (becomes a platform), beam
## knockback, a dissolve death with a killing-blow freeze, and contact damage.
## Subclasses implement _behavior(delta) for their movement/attacks and may set
## use_gravity / size / color / health in _setup().

@export var max_health: int = 4
@export var contact_damage: int = 10
@export var size: Vector2 = Vector2(24, 24)
@export var color: Color = Color("#c0432f")
@export var use_gravity: bool = true

var room_bounds: Rect2 = Rect2()    # set by the level; enemy is clamped inside it
var _bound_hit_x: bool = false
var visual_kind: String = "crawler" # which creature the visual draws (set in _setup)
var _visual: Node2D = null
var health: int
var _gravity: float = 1300.0
var _frozen_t: float = 0.0
var _knock_t: float = 0.0
var _hitbox: Area2D = null
var _player: Node = null
var _dying: bool = false

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("bashable")
	collision_layer = 4
	collision_mask = 1
	_setup()                       # subclass sets size/color/health first
	health = max_health
	if get_child_count() == 0:
		_build()                   # ...so the built body uses the right size/color

func _setup() -> void:
	pass

func _behavior(_delta: float) -> void:
	pass

# Subclasses call this to make the creature visual react to their state.
func _set_pose(p: String) -> void:
	if _visual is EnemyVisual:
		(_visual as EnemyVisual).pose = p

func _build() -> void:
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	add_child(cs)
	var _visual_node := EnemyVisual.new()
	_visual_node.kind = visual_kind
	_visual_node.base_color = color
	_visual_node.box = size
	_visual = _visual_node
	add_child(_visual)
	_hitbox = Area2D.new()
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = 2
	add_child(_hitbox)
	var hcs := CollisionShape2D.new()
	var hr := RectangleShape2D.new()
	hr.size = size
	hcs.shape = hr
	_hitbox.add_child(hcs)
	_hitbox.body_entered.connect(_on_contact)

func _physics_process(delta: float) -> void:
	if _dying:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")

	if _frozen_t > 0.0:
		_frozen_t -= delta
		velocity = Vector2.ZERO
		move_and_slide()
		if _frozen_t <= 0.0:
			modulate = Color.WHITE
			collision_layer = 4
			if _hitbox != null:
				_hitbox.monitoring = true
		return

	if use_gravity:
		velocity.y = 0.0 if is_on_floor() else velocity.y + _gravity * delta

	if _knock_t > 0.0:
		_knock_t -= delta
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	else:
		_behavior(delta)

	move_and_slide()
	_apply_bounds()

# Keep the enemy in its room. Flyers are boxed on all sides; grounded enemies are
# boxed horizontally, but if they fall past the floor (knocked into a pit) they die
# instead of floating, and ledge detection (below) keeps them from walking off.
func _apply_bounds() -> void:
	_bound_hit_x = false
	if room_bounds.size == Vector2.ZERO:
		return
	var hw := size.x * 0.5
	var hh := size.y * 0.5
	var minx := room_bounds.position.x + hw
	var maxx := room_bounds.position.x + room_bounds.size.x - hw
	var miny := room_bounds.position.y + hh
	var maxy := room_bounds.position.y + room_bounds.size.y - hh
	var p := global_position
	if p.x < minx:
		p.x = minx
		velocity.x = 0.0
		_bound_hit_x = true
	elif p.x > maxx:
		p.x = maxx
		velocity.x = 0.0
		_bound_hit_x = true
	if p.y < miny:                          # top clamp for everyone
		p.y = miny
		if velocity.y < 0.0:
			velocity.y = 0.0
	if use_gravity:
		if p.y > room_bounds.position.y + room_bounds.size.y + hh:
			die()                           # fell into a pit -> clean death, no floating
			return
	elif p.y > maxy:                        # flyers: bottom clamp too
		p.y = maxy
		if velocity.y > 0.0:
			velocity.y = 0.0
	global_position = p

# True if there's solid world just ahead of the leading foot in direction `dir`.
# Grounded enemies use this to turn around at ledges instead of walking into pits.
func _ground_ahead(dir: int) -> bool:
	if not is_on_floor():
		return true                         # only matters while grounded
	var hw := size.x * 0.5
	var hh := size.y * 0.5
	var space := get_world_2d().direct_space_state
	var from := global_position + Vector2(float(dir) * (hw + 4.0), hh - 2.0)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, 16.0), 1)
	q.exclude = [self]
	return not space.intersect_ray(q).is_empty()

func take_damage(amount: int, props: Dictionary = {}) -> void:
	if _dying:
		return
	health -= amount
	var hd = props.get("hit_dir", Vector2.ZERO)
	if hd != Vector2.ZERO:
		velocity = hd * 160.0
		_knock_t = 0.15
	if props.get("element", "") == "ice":
		_frozen_t = 2.0
		modulate = Color("#bfe9ff")
		collision_layer = 1 | 4
		if _hitbox != null:
			_hitbox.monitoring = false
	else:
		_flash()
		Audio.play("hit")
	if health <= 0:
		die()

func _flash() -> void:
	modulate = Color(2, 2, 2)
	var t := get_tree().create_timer(0.08)
	t.timeout.connect(func():
		if is_instance_valid(self) and _frozen_t <= 0.0 and not _dying:
			modulate = Color.WHITE)

func die() -> void:
	if _dying:
		return
	_dying = true
	Audio.play("enemy_die")
	Fx.burst(get_parent(), global_position, color, 9, 180.0)
	get_tree().call_group("camera_rig", "shake", 4.0, 0.15)
	get_tree().call_group("game", "hitstop", 0.06)
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
