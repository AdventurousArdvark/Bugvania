extends RefCounted
class_name Regions
## The six-region spine, as data. Each region knows its name, its mood tint, the
## apex you harvest there, and the graft that harvest grants. `on_clear` is the
## Mega Man X hook: defeating this region's apex changes ANOTHER region (lights go
## out, a flow freezes, a way opens) — wired up when those regions are built.
##
## A region's rooms are tagged with its id; the level shows the intro banner and
## sets the ambience tint from here, and the apex calls player.harvest(graft).

const SPINE := [
	{
		"id": "hollow", "order": 1,
		"name": "THE HOLLOW MOUTH", "sub": "the hive breathes",
		"tint": Color(0.34, 0.30, 0.24, 0.12),
		"apex": "THE BURROWER", "graft": "has_wall_jump",
		"on_clear": {"region": "marrow", "effect": "tunnels_settle"},
	},
	{
		"id": "glimmerwet", "order": 2,
		"name": "THE GLIMMERWET", "sub": "the lights are watching",
		"tint": Color(0.16, 0.26, 0.42, 0.12),
		"apex": "THE LANTERN-MOTHER", "graft": "has_double_jump",
		"on_clear": {"region": "weeping", "effect": "the_dark_floods_in"},
	},
	{
		"id": "marrow", "order": 3,
		"name": "THE MARROW RUN", "sub": "you are being digested",
		"tint": Color(0.40, 0.22, 0.20, 0.12),
		"apex": "THE TUNNEL-BORER", "graft": "has_dash",
		"on_clear": {"region": "hollow", "effect": "a_shortcut_opens"},
	},
	{
		"id": "weeping", "order": 4,
		"name": "THE WEEPING GALLERY", "sub": "this is a nursery",
		"tint": Color(0.20, 0.34, 0.30, 0.12),
		"apex": "THE SESSILE CHOIR", "graft": "has_charge",
		"on_clear": {"region": "cold", "effect": "the_falls_thaw"},
	},
	{
		"id": "cold", "order": 5,
		"name": "THE COLD CHOIR", "sub": "preserved, mid-scream",
		"tint": Color(0.30, 0.40, 0.50, 0.14),
		"apex": "THE PALE PREDATOR", "graft": "has_ice",
		"on_clear": {"region": "glimmerwet", "effect": "the_brood_goes_quiet"},
	},
	{
		"id": "brood", "order": 6,
		"name": "THE BROOD HEART", "sub": "the center of everything",
		"tint": Color(0.50, 0.12, 0.12, 0.14),
		"apex": "THE BROODMOTHER", "graft": "",          # finale — no graft, the escape
		"on_clear": {},
	},
]

static func by_id(id: String) -> Dictionary:
	for r in SPINE:
		if r.id == id:
			return r
	return {}

static func tint_of(id: String) -> Color:
	var r := by_id(id)
	return r.get("tint", Color(0.3, 0.3, 0.3, 0.10)) if not r.is_empty() else Color(0.3, 0.3, 0.3, 0.10)

static func name_of(id: String) -> String:
	return str(by_id(id).get("name", ""))

static func sub_of(id: String) -> String:
	return str(by_id(id).get("sub", ""))

static func graft_of(id: String) -> String:
	return str(by_id(id).get("graft", ""))
