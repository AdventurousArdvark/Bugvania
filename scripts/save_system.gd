extends RefCounted
class_name SaveSystem
## Run-progress persistence with 3 profile slots. The level decides WHAT to save;
## this reads/writes the JSON for the ACTIVE slot. The title screen sets the active
## slot and can query each slot's summary for the profile menu. New game on a slot
## is "clear(slot) then start".

const SLOTS := 3
static var active_slot: int = 0

static func _path(slot: int = -1) -> String:
	var s := active_slot if slot < 0 else slot
	return "user://instar_save_%d.json" % s

static func set_slot(i: int) -> void:
	active_slot = clampi(i, 0, SLOTS - 1)

static func has_save(slot: int = -1) -> bool:
	return FileAccess.file_exists(_path(slot))

static func save(data: Dictionary) -> void:
	var f := FileAccess.open(_path(), FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()

static func load_data(slot: int = -1) -> Dictionary:
	if not has_save(slot):
		return {}
	var f := FileAccess.open(_path(slot), FileAccess.READ)
	if f == null:
		return {}
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return data if typeof(data) == TYPE_DICTIONARY else {}

static func clear(slot: int = -1) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(_path(slot))

# A one-line description of a slot for the profile menu.
static func summary(slot: int) -> String:
	if not has_save(slot):
		return "— empty —"
	var d := load_data(slot)
	if d.is_empty():
		return "— empty —"
	var grafts := 0
	var ab: Variant = d.get("abilities", {})
	if ab is Dictionary:
		for k in ab:
			if bool(ab[k]):
				grafts += 1
	var room := str(d.get("current_room", "?"))
	return "%d grafts  ·  area %s" % [grafts, room]
