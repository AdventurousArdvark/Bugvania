extends StaticBody2D
class_name BreakableWall
## A solid block that blocks the player and stops beams, but takes damage from shots
## (via the projectile's on_projectile_hit hook) and shatters. Optionally only a
## missile can break it — a soft gate for hiding shortcuts and optional pickups.

@export var block: Vector2 = Vector2(32, 96)
@export var hp: int = 6
@export var requires_missile: bool = false
@export var color: Color = Color("#5f4a35")

var _max: int = 1

func _ready() -> void:
	collision_layer = 1                 # solid World
	collision_mask = 0
	_max = maxi(hp, 1)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = block
	cs.shape = r
	add_child(cs)

# Called by Projectile when a shot overlaps this body.
func on_projectile_hit(props: Dictionary, dmg: int) -> void:
	if requires_missile and str(props.get("element", "")) != "missile":
		Fx.burst(get_parent(), global_position, color.lightened(0.3), 3, 70.0)
		return
	hp -= maxi(dmg, 1)
	Fx.burst(get_parent(), global_position, color.lightened(0.3), 5, 110.0)
	Audio.play("hit")
	if hp <= 0:
		Fx.burst(get_parent(), global_position, color.lightened(0.4), 14, 200.0)
		Audio.play("missile_door")
		get_tree().call_group("camera_rig", "shake", 3.0, 0.2)
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	var hw := block.x * 0.5
	var hh := block.y * 0.5
	draw_rect(Rect2(-hw, -hh, block.x, block.y), color)
	draw_rect(Rect2(-hw, -hh, block.x, block.y), color.darkened(0.3), false, 2.0)
	# Brick seams.
	var rows := maxi(2, int(block.y / 24.0))
	for r in range(1, rows):
		var y := -hh + block.y * float(r) / float(rows)
		draw_line(Vector2(-hw, y), Vector2(hw, y), color.darkened(0.25), 1.0)
	# Cracks grow as it takes damage.
	var dmg01 := 1.0 - float(hp) / float(_max)
	if dmg01 > 0.0:
		var seed := 3
		for i in int(dmg01 * 8.0) + 1:
			var a := Vector2(sin(float(i) * 2.3) * hw * 0.7, cos(float(i * seed) * 1.7) * hh * 0.7)
			var b := a + Vector2(sin(float(i) * 5.1), cos(float(i) * 3.3)) * 14.0
			draw_line(a, b, color.darkened(0.55), 1.5)
