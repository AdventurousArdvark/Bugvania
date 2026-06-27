extends RefCounted
class_name Codex
## The recovered-log store. Datalogs picked up in the world land here; the world saves
## and restores them so a read log stays read. Order preserved for the codex reader.

static var entries: Dictionary = {}      # id -> {title, body, order}
static var _order: int = 0

static func add(id: String, title: String, body: String) -> bool:
	if entries.has(id):
		return false
	entries[id] = {"title": title, "body": body, "order": _order}
	_order += 1
	return true

static func has(id: String) -> bool:
	return entries.has(id)

static func count() -> int:
	return entries.size()

static func all() -> Array:
	var a := entries.values()
	a.sort_custom(func(x, y): return int(x["order"]) < int(y["order"]))
	return a

static func clear() -> void:
	entries = {}
	_order = 0

static func to_array() -> Array:
	var a := []
	for id in entries:
		var e: Dictionary = entries[id]
		a.append({"id": id, "title": e["title"], "body": e["body"], "order": e["order"]})
	return a

static func load_array(arr: Variant) -> void:
	if not (arr is Array):
		return
	for e in arr:
		if e is Dictionary and e.has("id"):
			entries[str(e["id"])] = {
				"title": str(e.get("title", "")),
				"body": str(e.get("body", "")),
				"order": int(e.get("order", _order)),
			}
			_order = maxi(_order, int(e.get("order", 0)) + 1)
