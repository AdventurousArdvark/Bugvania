extends CharacterBody2D
class_name ApexLantern
## Glimmerwet's apex. A floating lure that hovers, telegraphs, and dives. Airborne,
## so you fight it with the beam and base jumps (you don't have wings yet). On death
## it grants the Wing-Segment (double-jump). Same boss contract as the others.

signal health_changed(current, maximum)
signal engaged
signal disengaged
signal cleared

@export var max_health: int = 40
@export var dive_speed: float = 320.0

const GRAFT := "has_double_jump"

enum St { SLEEP, HOVER, TELL, DIVE, RECOVER, DEAD }

var size := Vector2(48, 54)
var health: int
var _state: int = St.SLEEP
var _t: float = 0.0
var _flash: float = 0.0
var _started := false
var _player: Node2D = null
var _home_y: float = 0.0
var _visual: Node2D = null
var _hitbox: Area2D = null

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	collision_layer = 4
	collision_mask = 1
	health = max_health
	_home_y = global_position.y
	var col := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = size
	col.shape = rs
	add_child(col)
	_hitbox = Area2D.new()
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = 2
	add_child(_hitbox)
	var hc := CollisionShape2D.new()
	var hrs := RectangleShape2D.new()
	hrs.size = size
	hc.shape = hrs
	_hitbox.add_child(hc)
	_hitbox.body_entered.connect(_on_touch)
	_visual = _LanternVisual.new()
	_visual.host = self
	add_child(_visual)

func engage() -> void:
	if _started or _state == St.DEAD:
		return
	_started = true
	_state = St.HOVER
	_t = 0.0
	engaged.emit()
	health_changed.emit(health, max_health)
	get_tree().call_group("game", "boss_intro", "THE LANTERN-MOTHER")

func _physics_process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
	if _state == St.SLEEP or _state == St.DEAD:
		return
	_player = get_tree().get_first_node_in_group("player")
	_t += delta
	match _state:
		St.HOVER:
			var ty := _home_y + sin(_t * 2.0) * 16.0
			if _player != null:
				global_position.x = move_toward(global_position.x, (_player as Node2D).global_position.x, 60.0 * delta)
			global_position.y = move_toward(global_position.y, ty, 80.0 * delta)
			velocity = Vector2.ZERO
			if _t > 1.6:
				_set_state(St.TELL)
		St.TELL:
			velocity = Vector2.ZERO
			if _t > 0.5:
				_set_state(St.DIVE)
		St.DIVE:
			if _player != null:
				var d := ((_player as Node2D).global_position - global_position).normalized()
				velocity = d * dive_speed
			move_and_slide()
			if _t > 0.55 or is_on_floor() or is_on_wall():
				_set_state(St.RECOVER)
		St.RECOVER:
			velocity = Vector2.ZERO
			global_position.y = move_toward(global_position.y, _home_y, 160.0 * delta)
			if _t > 0.5:
				_set_state(St.HOVER)

func _set_state(s: int) -> void:
	_state = s
	_t = 0.0

func take_damage(amount: int, _props: Dictionary = {}) -> void:
	if _state == St.DEAD or _state == St.SLEEP:
		return
	health -= amount
	_flash = 0.1
	health_changed.emit(maxi(health, 0), max_health)
	get_tree().call_group("game", "hitstop", 0.05)
	if health <= 0:
		_die()

func _on_touch(body: Node) -> void:
	if _state == St.DEAD:
		return
	if body.has_method("take_damage") and body.is_in_group("player"):
		body.take_damage(2, global_position)

func _die() -> void:
	_state = St.DEAD
	disengaged.emit()
	health_changed.emit(0, max_health)
	if _hitbox != null:
		_hitbox.set_deferred("monitoring", false)
	var p := get_tree().get_first_node_in_group("player")
	if p != null and p.has_method("harvest"):
		p.harvest(GRAFT)
	cleared.emit()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.8)
	tw.parallel().tween_property(self, "scale", Vector2(1.3, 1.3), 0.8)
	tw.tween_callback(queue_free)


class _LanternVisual extends Node2D:
	var host: ApexLantern

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if host == null:
			return
		var col := Color(0.82, 0.76, 0.42)
		if host._flash > 0.0:
			col = Color(1.0, 0.85, 0.7)
		draw_circle(Vector2.ZERO, host.size.x * 0.55, Color(col.r, col.g, col.b, 0.22))   # halo
		draw_circle(Vector2.ZERO, host.size.x * 0.36, col)                                  # body
		for i in range(-2, 3):
			draw_line(Vector2(float(i) * 8.0, host.size.y * 0.3), Vector2(float(i) * 8.0, host.size.y * 0.62),
				Color(0.4, 0.37, 0.2), 2.0)                                                  # filaments
		var glow := 0.5
		if host._state == St.TELL:
			glow = 0.6 + 0.4 * sin(host._t * 30.0)
		draw_circle(Vector2.ZERO, 5.0, Color(0.08, 0.08, 0.1, glow))                         # cold eye
