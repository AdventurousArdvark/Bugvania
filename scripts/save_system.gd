extends RefCounted
class_name SaveSystem
## Run-progress persistence. The level decides WHAT to save (abilities, missiles,
## visited rooms, checkpoint, milestones); this just reads/writes the JSON. A new
## game is "clear() then reload".

const PATH := "user://instar_save.json"

static func has_save() -> bool:
	return FileAccess.file_exists(PATH)

static func save(data: Dictionary) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()

static func load_data() -> Dictionary:
	if not has_save():
		return {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {}
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return data if typeof(data) == TYPE_DICTIONARY else {}

static func clear() -> void:
	if has_save():
		DirAccess.remove_absolute(PATH)
