extends RefCounted
class_name Settings
## Global, persisted player options. Static so any system can read them
## (CameraRig reads shake_scale, Rumble reads rumble_on, the player reads
## grip_toggle, Audio volume routes through the Master bus). Loaded once at
## startup; the settings tab writes through here and calls save_settings().

const PATH := "user://instar_settings.json"

static var master_volume: float = 1.0    # 0..1
static var shake_scale: float = 1.0      # 0..1.5
static var rumble_on: bool = true
static var grip_toggle: bool = false     # wall-grip: hold vs toggle
static var loaded: bool = false

static func load_settings() -> void:
	loaded = true
	if FileAccess.file_exists(PATH):
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			var data: Variant = JSON.parse_string(f.get_as_text())
			f.close()
			if typeof(data) == TYPE_DICTIONARY:
				master_volume = float(data.get("master_volume", 1.0))
				shake_scale = float(data.get("shake_scale", 1.0))
				rumble_on = bool(data.get("rumble_on", true))
				grip_toggle = bool(data.get("grip_toggle", false))
	apply()

static func save_settings() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"master_volume": master_volume,
		"shake_scale": shake_scale,
		"rumble_on": rumble_on,
		"grip_toggle": grip_toggle,
	}))
	f.close()

static func apply() -> void:
	var idx := AudioServer.get_bus_index("Master")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(master_volume, 0.0001, 1.0)))
		AudioServer.set_bus_mute(idx, master_volume <= 0.001)
