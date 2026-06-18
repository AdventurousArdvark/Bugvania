extends RefCounted
class_name Rumble
## Controller vibration, one call from anywhere: Rumble.pulse(weak, strong, dur).
## No-ops harmlessly if no gamepad is connected. (weak = high-freq buzz,
## strong = low-freq thump; both 0..1.)

static func pulse(weak: float, strong: float, dur: float) -> void:
	Input.start_joy_vibration(0, weak, strong, dur)
