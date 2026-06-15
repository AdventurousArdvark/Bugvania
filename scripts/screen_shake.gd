extends Node
class_name ScreenShake
## Attach as a child of a Camera2D (player.gd does this automatically). Call
## shake(strength, duration) for a decaying random offset. Uses Camera2D.offset,
## which is independent of position and limits, so room confinement is unaffected.

var _cam: Camera2D = null
var _t: float = 0.0
var _dur: float = 0.0001
var _strength: float = 0.0

func _ready() -> void:
	var p := get_parent()
	if p is Camera2D:
		_cam = p

func shake(strength: float, duration: float) -> void:
	_strength = maxf(_strength, strength)   # stronger hit wins
	_dur = maxf(_dur, duration)
	_t = _dur

func _process(delta: float) -> void:
	if _cam == null:
		return
	if _t > 0.0:
		_t -= delta
		var amt := _strength * (_t / _dur)   # decays to zero
		_cam.offset = Vector2(randf_range(-amt, amt), randf_range(-amt, amt))
	elif _cam.offset != Vector2.ZERO:
		_cam.offset = Vector2.ZERO
		_strength = 0.0
