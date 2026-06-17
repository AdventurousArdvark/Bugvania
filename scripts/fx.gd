extends Node
class_name Fx
## Tiny effects helper. Static so anything can call Fx.burst(...) without a ref.

static func burst(world: Node, pos: Vector2, color: Color, count: int = 8, speed: float = 170.0) -> void:
	if world == null:
		return
	for i in count:
		var bit := FxBit.new()
		world.add_child(bit)
		bit.global_position = pos
		var dir := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 0.3)).normalized()
		bit.setup(color, dir * randf_range(speed * 0.4, speed), randf_range(3.0, 6.0), randf_range(0.3, 0.6))
