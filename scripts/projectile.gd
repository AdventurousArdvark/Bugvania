extends Area2D
class_name Projectile
## One beam, driven entirely by a stats dictionary. Normal shot, charged shot,
## and (later) Ice / Wave / Plasma are all THIS object with different numbers.
## That's the whole point of the Metroid upgrade model: upgrades modify one beam.

var damage: int = 1
var properties: Dictionary = {}     # e.g. {"element": "ice"} for later upgrades

var _velocity: Vector2 = Vector2.ZERO
var _lifetime: float = 1.2
var _age: float = 0.0
var _pierce: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 5      # World (1) + Enemies (4). NOT the player (2) -> no self-hit.
	monitoring = true
	body_entered.connect(_on_body_entered)

# Called by the weapon right after adding the projectile to the world.
func setup(pos: Vector2, dir: Vector2, stats: Dictionary) -> void:
	_velocity = dir * float(stats.get("speed", 450.0))
	damage = int(stats.get("damage", 1))
	_lifetime = float(stats.get("lifetime", 1.2))
	_pierce = bool(stats.get("pierce", false))
	properties = {"element": stats.get("element", "")}
	rotation = dir.angle()
	_build_visual(float(stats.get("size", 8.0)), stats.get("color", Color("#9fe6ff")))
	global_position = pos

func _build_visual(s: float, color: Color) -> void:
	var w := s * 2.0   # elongated along travel direction (rotation handles orientation)
	var h := s
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, h)
	col.shape = rect
	add_child(col)
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-w * 0.5, -h * 0.5), Vector2(w * 0.5, -h * 0.5),
		Vector2(w * 0.5, h * 0.5), Vector2(-w * 0.5, h * 0.5),
	])
	poly.color = color
	add_child(poly)

func _physics_process(delta: float) -> void:
	global_position += _velocity * delta
	_age += delta
	if _age >= _lifetime:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		body.take_damage(damage, properties)
		if not _pierce:
			queue_free()
		return
	# Hit solid world: stop, unless this beam pierces walls (Wave, later).
	if body is StaticBody2D and not _pierce:
		queue_free()
