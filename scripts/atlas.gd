extends RefCounted
class_name Atlas
## THE ATLAS — the whole planet as data. This is the INSTAR-themed realization of
## the survey map: 6 areas, 19 upgrades in intended order (14 organs + 5 hemolymph
## sacs), 5 guardians, the gate taxonomy, and 5 sanctioned sequence breaks. It is the
## single source of truth the region modules, the map screen, and progression build
## against — geometry modules place what the Atlas declares; they never invent it.
##
## Naming: the survey team logged sterile names (Verdant Hollow, Rust Wastes...). The
## planet is a body, so we log it as one. `survey` keeps the original label for cross-
## reference; `name` is what the game shows.
##
## Vanilla equivalents are noted only so the design reads at a glance; the game uses the
## themed name and the flat player flag. `flag` is the independent ability flag (see the
## architecture rule: flags are flat and order-independent, so sequence breaks never desync).

# --- AREAS (in the map's spatial/intended order) --------------------------------------
const AREAS := [
	{
		"id": "hollow", "order": 1, "survey": "Verdant Hollow",
		"name": "THE GREENSHELL HOLLOW", "sub": "you wake in the moss",
		"tint": Color(0.22, 0.34, 0.20, 0.12), "map_color": Color("#5fbf6a"),
		"guardian": "", "role": "start / ship", "spine_id": "hollow",
	},
	{
		"id": "oxide", "order": 2, "survey": "The Rust Wastes",
		"name": "THE OXIDE WASTES", "sub": "the machines rotted here first",
		"tint": Color(0.42, 0.28, 0.14, 0.12), "map_color": Color("#d0872f"),
		"guardian": "THE GANTRY-THING", "role": "early sprawl", "spine_id": "weeping",
	},
	{
		"id": "marrow", "order": 3, "survey": "Emberdeep Caverns",
		"name": "THE MOLTEN MARROW", "sub": "the planet's blood runs hot",
		"tint": Color(0.44, 0.18, 0.15, 0.13), "map_color": Color("#c8412f"),
		"guardian": "THE SLAGJAW", "role": "heat gauntlet", "spine_id": "marrow",
	},
	{
		"id": "spire", "order": 4, "survey": "Frostspire Heights",
		"name": "THE PALE SPIRE", "sub": "frozen mid-scream",
		"tint": Color(0.24, 0.34, 0.48, 0.14), "map_color": Color("#3f8fd0"),
		"guardian": "THE RIME WARDEN", "role": "vertical ascent", "spine_id": "cold",
	},
	{
		"id": "cistern", "order": 5, "survey": "Sunken Cisterns",
		"name": "THE DROWNED CISTERNS", "sub": "something still breathes down here",
		"tint": Color(0.16, 0.34, 0.34, 0.13), "map_color": Color("#2fb8a8"),
		"guardian": "THE TIDEMAW", "role": "submerged", "spine_id": "glimmerwet",
	},
	{
		"id": "core", "order": 6, "survey": "The Hollow Core",
		"name": "THE HOLLOW CORE", "sub": "the center of the wound",
		"tint": Color(0.34, 0.18, 0.42, 0.14), "map_color": Color("#9a5fd0"),
		"guardian": "THE NADIR", "role": "finale", "spine_id": "brood",
	},
]

# --- UPGRADES (19 total: 14 organs + 5 sacs) listed in INTENDED acquisition order -----
# map_no matches the number stamped on the survey map so the two can be read side by side.
const UPGRADES := [
	{"map_no": 1,  "name": "COIL FORM",         "vanilla": "Morph Ball",   "flag": "has_coil",       "area": "hollow",
		"note": "Tuck into a chitin ball; roll through 1-tile gaps."},
	{"map_no": 2,  "name": "PULSE GLAND",       "vanilla": "Bombs",        "flag": "has_pulse",      "area": "hollow",
		"note": "Lay pulse charges; burst the soft red growths."},
	{"map_no": 4,  "name": "STINGER PODS",      "vanilla": "Missiles",     "flag": "has_missiles",   "area": "oxide",
		"note": "Volatile ordnance; opens soft seals."},
	{"map_no": 6,  "name": "CHARGE GLAND",      "vanilla": "Charge Beam",  "flag": "has_charge",     "area": "oxide",
		"note": "Hold to overcharge one heavy lance."},
	{"map_no": 5,  "name": "KICK-TENDON",       "vanilla": "High Jump",    "flag": "has_high_jump",  "area": "oxide",
		"note": "A coiled leap; clears the low mouths toward the Spire."},
	{"map_no": 7,  "name": "FROST GLAND",       "vanilla": "Ice Beam",     "flag": "has_ice",        "area": "spire",
		"note": "Chill prey solid; a frozen body becomes a platform."},
	{"map_no": 8,  "name": "TETHER-TONGUE",     "vanilla": "Grapple",      "flag": "has_grapple",    "area": "spire",
		"note": "A barbed tongue that hauls you across gaps."},
	{"map_no": 9,  "name": "AETHER WING",       "vanilla": "Space Jump",   "flag": "has_space_jump", "area": "spire",
		"note": "Beat wings without end; climb open air."},
	{"map_no": 11, "name": "DROWN-LUNG",        "vanilla": "Gravity Suit", "flag": "has_gravity",    "area": "cistern",
		"note": "Move freely through flooded galleries."},
	{"map_no": 12, "name": "BARB PODS",         "vanilla": "Super Missile","flag": "has_super",      "area": "cistern",
		"note": "Heavier stingers; split armored seals."},
	{"map_no": 14, "name": "CINDER CARAPACE",   "vanilla": "Varia Suit",   "flag": "has_heatshield", "area": "marrow",
		"note": "A slag-proof shell; ignore the marrow's heat."},
	{"map_no": 15, "name": "MOMENTUM SPUR",     "vanilla": "Speed Booster","flag": "has_speed",      "area": "marrow",
		"note": "Build a killing run; store it and spark."},
	{"map_no": 16, "name": "RESONANT MEMBRANE", "vanilla": "Wave Beam",    "flag": "has_wave",       "area": "marrow",
		"note": "Shots phase through carapace and wall alike."},
	{"map_no": 17, "name": "SHRED-SPIN",        "vanilla": "Screw Attack", "flag": "has_screw",      "area": "marrow",
		"note": "A whirling spin that shreds fragile blocks."},
	{"map_no": 3,  "name": "HEMOLYMPH SAC A",   "vanilla": "Energy Tank",  "flag": "cell_a",         "area": "hollow",
		"note": "Bank more hemolymph; a little more life."},
	{"map_no": 10, "name": "HEMOLYMPH SAC B",   "vanilla": "Energy Tank",  "flag": "cell_b",         "area": "spire",
		"note": "Bank more hemolymph; a little more life."},
	{"map_no": 13, "name": "HEMOLYMPH SAC C",   "vanilla": "Energy Tank",  "flag": "cell_c",         "area": "cistern",
		"note": "Bank more hemolymph; a little more life."},
	{"map_no": 18, "name": "HEMOLYMPH SAC D",   "vanilla": "Energy Tank",  "flag": "cell_d",         "area": "marrow",
		"note": "Bank more hemolymph; a little more life."},
	{"map_no": 19, "name": "HEMOLYMPH SAC E",   "vanilla": "Energy Tank",  "flag": "cell_e",         "area": "core",
		"note": "Bank more hemolymph; a little more life."},
]

# --- GUARDIANS (5) --------------------------------------------------------------------
const GUARDIANS := [
	{"name": "THE GANTRY-THING", "area": "oxide",   "survey": "Gantry",      "gates": "the Charge Gland"},
	{"name": "THE SLAGJAW",      "area": "marrow",  "survey": "Magmaw",      "gates": "the deep marrow organs"},
	{"name": "THE RIME WARDEN",  "area": "spire",   "survey": "Rime Warden", "gates": "the Aether Wing"},
	{"name": "THE TIDEMAW",      "area": "cistern", "survey": "Tidemaw",     "gates": "the flooded core route"},
	{"name": "THE NADIR",        "area": "core",    "survey": "The Nadir",   "gates": "the ending"},
]

# --- GATES / DOORS (the map's door taxonomy) ------------------------------------------
const GATES := [
	{"id": "open",    "name": "OPEN MEMBRANE",  "opened_by": "",             "color": Color("#4f7fff")},
	{"id": "soft",    "name": "SOFT SEAL",      "opened_by": "has_missiles", "color": Color("#5fbf6a"),
		"alt": "has_pulse"},
	{"id": "armored", "name": "ARMORED SEAL",   "opened_by": "has_super",    "color": Color("#e8c53a")},
	{"id": "scab",    "name": "SCAB HATCH",     "opened_by": "has_pulse",    "color": Color("#e05050")},
	{"id": "tether",  "name": "TETHER GATE",    "opened_by": "has_grapple",  "color": Color("#2fb8a8")},
	{"id": "resonant","name": "RESONANT DOOR",  "opened_by": "has_wave",     "color": Color("#b070e0")},
	{"id": "slag",    "name": "SLAG SHUTTER",   "opened_by": "has_speed",    "color": Color("#d0872f"),
		"alt": "has_heatshield"},
]

# --- SEQUENCE BREAKS (5) — sanctioned skips; each removes a required organ ------------
const SEQUENCE_BREAKS := [
	{"id": "SB1", "name": "THE DROWNED SHORTCUT", "from": "cistern", "skips": "has_grapple",
		"how": "Pulse-jump the Cistern shaft up to the Drown-Lung — no Tether needed."},
	{"id": "SB2", "name": "THE PALE ASCENT",      "from": "spire",   "skips": "has_high_jump",
		"how": "Wall-kick the Spire shaft raw; skip the Kick-Tendon entirely."},
	{"id": "SB3", "name": "THE EARLY CARAPACE",   "from": "marrow",  "skips": "",
		"how": "Coil-bounce the Marrow shutter for an early Cinder Carapace."},
	{"id": "SB4", "name": "THE OXIDE SPARK",      "from": "oxide",   "skips": "",
		"how": "Momentum-spark from the Oxide Wastes straight into the Core antechamber."},
	{"id": "SB5", "name": "THE LEAP ACROSS",      "from": "spire",   "skips": "has_grapple",
		"how": "Aether-Wing the chasm; skip the Tether crossing to the Cisterns."},
]

# --- accessors ------------------------------------------------------------------------
static func areas_in_order() -> Array:
	return AREAS

static func area(id: String) -> Dictionary:
	for a in AREAS:
		if a["id"] == id:
			return a
	return {}

static func area_name(id: String) -> String:
	return str(area(id).get("name", ""))

static func upgrades_in_order() -> Array:
	return UPGRADES

static func upgrade_by_flag(flag: String) -> Dictionary:
	for u in UPGRADES:
		if u["flag"] == flag:
			return u
	return {}

static func upgrades_in_area(area_id: String) -> Array:
	var out: Array = []
	for u in UPGRADES:
		if u["area"] == area_id:
			out.append(u)
	return out

static func guardian_of(area_id: String) -> String:
	for g in GUARDIANS:
		if g["area"] == area_id:
			return str(g["name"])
	return ""

static func gate(id: String) -> Dictionary:
	for g in GATES:
		if g["id"] == id:
			return g
	return {}

static func sequence_breaks() -> Array:
	return SEQUENCE_BREAKS

# Totals the header of the map quotes: "6 areas · 19 upgrades · 5 guardians".
static func totals() -> Dictionary:
	return {"areas": AREAS.size(), "upgrades": UPGRADES.size(), "guardians": GUARDIANS.size(),
		"sequence_breaks": SEQUENCE_BREAKS.size()}
