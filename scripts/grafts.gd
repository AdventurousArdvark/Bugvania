extends RefCounted
class_name Grafts
## The catalog of graftable parts. A graft is identified by the player flag it
## controls (e.g. "has_dash"). Each carries a SLOT cost (you have limited slots,
## so you can't wear everything at once) and a MASS that shifts the bug's physics:
## heavy grafts make you fall faster, drift less, and resist knockback; light ones
## (wings) make you floaty and easily launched. The loadout screen is a build
## screen — pick the body you want to be.
##
## Beam-mod grafts list an "active" flag; equipping turns the mod on, unequipping off.
## "region" is which area's apex you harvest it from (for the spine / map design).

const CATALOG := {
	"has_double_jump": {"name": "Wing-Segment",      "glyph": "wing",    "slot": 1, "mass": -2, "active": "", "region": "glimmerwet",
		"desc": "Borrowed wings. A second beat — and a lighter, floatier body."},
	"has_dash":        {"name": "Drill-Limb",        "glyph": "drill",   "slot": 1, "mass": 3,  "active": "", "region": "marrow",
		"desc": "A lunging bore. Heavy, fast, and it carries momentum like a wreck."},
	"has_wall_jump":   {"name": "Grip-Claws",        "glyph": "claw",    "slot": 1, "mass": 1,  "active": "", "region": "hollow",
		"desc": "Cling to walls; kick off them to climb."},
	"has_slide":       {"name": "Carapace-Roll",     "glyph": "roll",    "slot": 1, "mass": 1,  "active": "", "region": "hollow",
		"desc": "Tuck and slide low and fast."},
	"has_charge":      {"name": "Charge Gland",      "glyph": "charge",  "slot": 1, "mass": 1,  "active": "charge_active", "region": "weeping",
		"desc": "Hold the trigger to overcharge one heavy lance."},
	"has_ice":         {"name": "Frost Gland",       "glyph": "ice",     "slot": 1, "mass": 2,  "active": "ice_active", "region": "cold",
		"desc": "Shots chill prey solid. Frozen prey becomes a platform."},
	"has_wave":        {"name": "Resonant Membrane", "glyph": "wave",    "slot": 1, "mass": 0,  "active": "wave_active", "region": "cold",
		"desc": "Shots phase through carapace and wall alike."},
	"has_missiles":    {"name": "Stinger Pods",      "glyph": "missile", "slot": 1, "mass": 1,  "active": "", "region": "weeping",
		"desc": "Volatile pods. Burst armored growths and sealed ways."},
}

# Stable display order for the build grid.
const ORDER := ["has_wall_jump", "has_slide", "has_double_jump", "has_dash",
	"has_charge", "has_missiles", "has_ice", "has_wave"]

static func has(key: String) -> bool:
	return CATALOG.has(key)

static func name_of(key: String) -> String:
	return str(CATALOG.get(key, {}).get("name", key))

static func slot_of(key: String) -> int:
	return int(CATALOG.get(key, {}).get("slot", 1))

static func mass_of(key: String) -> int:
	return int(CATALOG.get(key, {}).get("mass", 0))

static func active_flag(key: String) -> String:
	return str(CATALOG.get(key, {}).get("active", ""))

static func desc_of(key: String) -> String:
	return str(CATALOG.get(key, {}).get("desc", ""))

static func glyph_of(key: String) -> String:
	return str(CATALOG.get(key, {}).get("glyph", ""))

# Light / Balanced / Heavy from total equipped mass.
static func profile(mass: int) -> String:
	if mass <= 0:
		return "LIGHT"
	if mass <= 3:
		return "BALANCED"
	return "HEAVY"
