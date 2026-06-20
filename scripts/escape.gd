extends CanvasLayer
class_name Escape
## The climax after the boss dies: the hive collapses. A countdown runs, debris
## rains, the screen pulses red and shakes. Reach room A (the entrance) before the
## timer hits zero to escape; otherwise the hive takes you.

@export var duration: float = 28.0
@export var goal_room: String = "A"

var _time_left: float = 0.0
var _player: Node = null
var _level: Node = null
var _over: bool = false
var _debris_t: float = 0.0
var _alarm_t: float = 0.0
var _rng := RandomNumberGenerator.new()

var _vignette: ColorRect = null
var _timer_label: Label = null
var _sub_label: Label = null

func _ready() -> void:
	add_to_group("escape")
	layer = 48
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_rng.randomize()
	_time_left = duration
	_player = get_tree().get_first_node_in_group("player")
	_level = get_tree().get_first_node_in_group("level")
	_build_ui()
	Audio.play("boss_roar")
	get_tree().call_group("camera_rig", "shake", 14.0, 0.6)

func _build_ui() -> void:
	_vignette = ColorRect.new()
	_vignette.color = Color(0.6, 0.05, 0.05, 0.0)
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vignette)
	var vp := get_viewport().get_visible_rect().size
	_timer_label = Label.new()
	_timer_label.add_theme_font_size_override("font_size", 44)
	_timer_label.add_theme_color_override("font_color", Color("#ff5d5d"))
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.size = Vector2(vp.x, 52)
	_timer_label.position = Vector2(0, vp.y * 0.10)
	add_child(_timer_label)
	_sub_label = Label.new()
	_sub_label.text = "HIVE COLLAPSE — FLEE TO THE SURFACE"
	_sub_label.add_theme_font_size_override("font_size", 18)
	_sub_label.add_theme_color_override("font_color", Color("#ffb0b0"))
	_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_label.size = Vector2(vp.x, 24)
	_sub_label.position = Vector2(0, vp.y * 0.10 + 54)
	add_child(_sub_label)

func _process(delta: float) -> void:
	if _over:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_fail()
		return

	var secs := int(ceil(_time_left))
	_timer_label.text = str(secs)
	# Red pulse intensifies as time runs out.
	var urgency: float = clampf(1.0 - _time_left / duration, 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0)
	_vignette.color.a = lerpf(0.08, 0.34, urgency) * (0.6 + 0.4 * pulse)

	# Rain debris around the player; faster as it gets worse.
	_debris_t -= delta
	if _debris_t <= 0.0:
		_debris_t = lerpf(0.7, 0.22, urgency)
		_spawn_debris()
	# Periodic shake + alarm.
	_alarm_t -= delta
	if _alarm_t <= 0.0:
		_alarm_t = lerpf(1.1, 0.5, urgency)
		Audio.play("alarm")
		get_tree().call_group("camera_rig", "shake", 5.0, 0.25)

func _spawn_debris() -> void:
	if _player == null or _level == null:
		return
	var ppos: Vector2 = (_player as Node2D).global_position
	var x := ppos.x + _rng.randf_range(-260.0, 260.0)
	var d := HazardDebris.new()
	_level.add_child(d)
	d.setup(Vector2(x, ppos.y - 240.0), _rng.randf_range(-30.0, 30.0), _rng.randf_range(8.0, 14.0))

# Called by the level when the player enters a room.
func room_entered(room_name: String) -> void:
	if _over:
		return
	if room_name == goal_room:
		_succeed()

func _succeed() -> void:
	_over = true
	get_tree().call_group("camera_rig", "shake", 8.0, 0.4)
	_clear_ui()
	get_tree().call_group("game", "show_end", "YOU ESCAPED")

func _fail() -> void:
	_over = true
	_clear_ui()
	Audio.play("die")
	get_tree().call_group("camera_rig", "shake", 16.0, 0.7)
	get_tree().call_group("game", "show_end", "CONSUMED BY THE HIVE")

func _clear_ui() -> void:
	if _vignette != null:
		_vignette.queue_free()
	if _timer_label != null:
		_timer_label.queue_free()
	if _sub_label != null:
		_sub_label.queue_free()
