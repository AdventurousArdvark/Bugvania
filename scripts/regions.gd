extends RefCounted
class_name Regions
## The six-region spine, as runtime data — the Atlas realized for the live game. Each
## region knows its themed name, mood tint, guardian, and the Mega Man X `on_clear`
## hook (clearing this region's guardian changes ANOTHER region). IDs are stable keys
## the built modules tag rooms with; `atlas_id` links to Atlas.AREAS for the fuller
## design record (upgrades, gates, sequence breaks). See atlas.gd for the whole map.
##
## The level shows the intro banner and sets the ambience tint from here, and the
## apex/guardian calls player.harvest(graft) where wired.

const SPINE := [
	{
		"id": "hollow", "atlas_id": "hollow", "order": 1,
		"name": "THE GREENSHELL HOLLOW", "sub": "you wake in the moss",
		"tint": Color(0.22, 0.34, 0.20, 0.12),
		"guardian": "", "apex": "", "graft": "has_coil",
		"on_clear": {},
	},
	{
		"id": "oxide", "atlas_id": "oxide", "order": 2,
		"name": "THE OXIDE WASTES", "sub": "the machines rotted here first",
		"tint": Color(0.42, 0.28, 0.14, 0.12),
		"guardian": "THE GANTRY-THING", "apex": "THE GANTRY-THING", "graft": "has_charge",
		"on_clear": {"region": "spire", "effect": "the_spire_lifts"},
	},
	{
		"id": "marrow", "atlas_id": "marrow", "order": 3,
		"name": "THE MOLTEN MARROW", "sub": "the planet's blood runs hot",
		"tint": Color(0.44, 0.18, 0.15, 0.13),
		"guardian": "THE SLAGJAW", "apex": "THE SLAGJAW", "graft": "has_screw",
		"on_clear": {"region": "cistern", "effect": "the_cisterns_drain"},
	},
	{
		"id": "spire", "atlas_id": "spire", "order": 4,
		"name": "THE PALE SPIRE", "sub": "frozen mid-scream",
		"tint": Color(0.24, 0.34, 0.48, 0.14),
		"guardian": "THE RIME WARDEN", "apex": "THE RIME WARDEN", "graft": "has_space_jump",
		"on_clear": {"region": "marrow", "effect": "the_marrow_cools_a_path"},
	},
	{
		"id": "cistern", "atlas_id": "cistern", "order": 5,
		"name": "THE DROWNED CISTERNS", "sub": "something still breathes down here",
		"tint": Color(0.16, 0.34, 0.34, 0.13),
		"guardian": "THE TIDEMAW", "apex": "THE TIDEMAW", "graft": "has_gravity",
		"on_clear": {"region": "core", "effect": "the_core_unseals"},
	},
	{
		"id": "core", "atlas_id": "core", "order": 6,
		"name": "THE HOLLOW CORE", "sub": "the center of the wound",
		"tint": Color(0.34, 0.18, 0.42, 0.14),
		"guardian": "THE NADIR", "apex": "THE NADIR", "graft": "",   # finale — the ending
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

static func guardian_of(id: String) -> String:
	return str(by_id(id).get("guardian", ""))
