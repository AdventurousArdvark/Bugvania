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
var _hostile: bool = false   # true = boss/enemy shot (hits the player instead)
var _hit: Dictionary = {}     # enemies already damaged (so a piercing shot hits each once)

func _ready() -> void:
	collision_layer = 0
	monitoring = true
	body_entered.connect(_on_body_entered)

# Called by the weapon/boss right after adding the projectile to the world.
func setup(pos: Vector2, dir: Vector2, stats: Dictionary) -> void:
	_velocity = dir * float(stats.get("speed", 450.0))
	damage = int(stats.get("damage", 1))
	_lifetime = float(stats.get("lifetime", 1.2))
	_pierce = bool(stats.get("pierce", false))
	_hostile = bool(stats.get("hostile", false))
	collision_mask = 3 if _hostile else 5   # hostile: World+Player; friendly: World+Enemies
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
	if _hostile:
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(damage, global_position)
			queue_free()
		elif body is StaticBody2D:
			queue_free()
		return
	# Reactive world: missile doors, switches, breakable blocks.
	if body.has_method("on_projectile_hit"):
		body.on_projectile_hit(properties, damage)
		if not _pierce:
			queue_free()
		return
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		var id := body.get_instance_id()
		if _hit.has(id):
			return                 # already damaged this enemy (piercing shot)
		_hit[id] = true
		var p := properties.duplicate()
		p["hit_dir"] = _velocity.normalized()
		body.take_damage(damage, p)
		if not _pierce:
			queue_free()
		return
	# Hit solid world: stop, unless this beam pierces walls (Wave).
	if body is StaticBody2D and not _pierce:
		queue_free()
