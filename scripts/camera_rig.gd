extends Node
class_name CameraRig
## Attach as a child of the player's Camera2D (player.gd does this). Adds:
##   - LOOKAHEAD: the view leads toward your movement, and peeks when you aim
##     up/down. This is the single change that makes a 2D camera feel "pro".
##   - SHAKE: a decaying random offset on top of the lookahead.
## Both ride on Camera2D.offset, which is independent of position/limits, so the
## room confinement system is never disturbed. In group "camera_rig" so enemies
## and the boss can trigger shake from anywhere.

@export var look_ahead_x: float = 36.0
@export var look_peek_y: float = 28.0
@export var look_speed: float = 4.0

var _cam: Camera2D = null
var _player: Node = null
var _base: Vector2 = Vector2.ZERO
var _shake_t: float = 0.0
var _shake_dur: float = 0.0001
var _shake_strength: float = 0.0
var _base_zoom: Vector2 = Vector2.ONE
var _zoom_extra: float = 0.0
var _zoom_decay: float = 0.6

func _ready() -> void:
	add_to_group("camera_rig")
	var p := get_parent()
	if p is Camera2D:
		_cam = p
		_base_zoom = _cam.zoom
		var pp := _cam.get_parent()
		if pp is CharacterBody2D:
			_player = pp

func shake(strength: float, duration: float) -> void:
	_shake_strength = maxf(_shake_strength, strength)
	_shake_dur = maxf(_shake_dur, duration)
	_shake_t = _shake_dur

# Quick zoom-in that eases back to normal (boss arrival, big hits).
func punch(zoom_mul: float, duration: float) -> void:
	_zoom_extra = zoom_mul - 1.0
	_zoom_decay = maxf(duration, 0.1)

func _process(delta: float) -> void:
	if _cam == null:
		return
	# Lookahead target from horizontal motion + vertical aim.
	var target := Vector2.ZERO
	if _player != null:
		target.x = signf(_player.velocity.x) * look_ahead_x
		if _act("move_up"):
			target.y = -look_peek_y
		elif _act("move_down"):
			target.y = look_peek_y
	_base = _base.lerp(target, clampf(look_speed * delta, 0.0, 1.0))

	var shake_off := Vector2.ZERO
	if _shake_t > 0.0:
		_shake_t -= delta
		var amt := _shake_strength * (_shake_t / _shake_dur)
		shake_off = Vector2(randf_range(-amt, amt), randf_range(-amt, amt))
	elif _shake_strength != 0.0:
		_shake_strength = 0.0

	_cam.offset = _base + shake_off

	# Zoom punch eases back to the base zoom.
	if _zoom_extra > 0.001:
		_zoom_extra = lerpf(_zoom_extra, 0.0, clampf(delta / _zoom_decay, 0.0, 1.0))
		_cam.zoom = _base_zoom * (1.0 + _zoom_extra)
	elif _cam.zoom != _base_zoom:
		_cam.zoom = _base_zoom

func _act(a: String) -> bool:
	return InputMap.has_action(a) and Input.is_action_pressed(a)
