extends SceneTree
## Bootstrap generator for the prototype's data resources.
##
## Usage (from the project root):
##   godot --headless --path . -s res://tools/generate_data.gd
##
## By default only MISSING resources are written, so edits made in the Godot
## editor are never lost (the .tres files are the source of truth). Options
## after "--":
##   --update=items/,quests/q_x   overwrite files whose path contains any token
##   --overwrite                  overwrite everything (resets designer edits!)

const DATA := "res://data"

var _count := 0
var _skipped := 0
var _overwrite_all := false
var _update_tokens: PackedStringArray = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--overwrite":
			_overwrite_all = true
		elif arg.begins_with("--update="):
			_update_tokens = arg.trim_prefix("--update=").split(",", false)
	_make_dirs()
	_generate_type_chart()
	_generate_skills()
	_generate_species()
	_generate_items()
	_generate_dialogue()
	_generate_npcs()
	_generate_quests()
	_generate_encounters()
	_generate_maps()
	_generate_configs()
	_generate_shops()
	print("generate_data: wrote %d resources, kept %d existing" % [_count, _skipped])
	quit()


func _make_dirs() -> void:
	for sub in ["digimon", "skills", "items", "quests", "dialogue", "npcs", "encounters", "maps", "config", "shops"]:
		DirAccess.make_dir_recursive_absolute(DATA.path_join(sub))


func _save(res: Resource, path: String) -> void:
	if FileAccess.file_exists(path) and not _should_overwrite(path):
		_skipped += 1
		return
	var err := ResourceSaver.save(res, path)
	if err != OK:
		printerr("Failed to save %s: %s" % [path, error_string(err)])
	else:
		_count += 1


func _should_overwrite(path: String) -> bool:
	if _overwrite_all:
		return true
	for token in _update_tokens:
		if path.contains(token):
			return true
	return false


# ---------------------------------------------------------------------------
# Type chart
# ---------------------------------------------------------------------------

func _generate_type_chart() -> void:
	var chart := TypeChart.new()
	# Vaccine(0) > Virus(2) > Data(1) > Vaccine(0)
	chart.attribute_matchups = {
		"0>2": 1.3, "2>1": 1.3, "1>0": 1.3,
		"2>0": 0.8, "1>2": 0.8, "0>1": 0.8,
	}
	chart.element_matchups = {
		&"fire": {&"plant": 1.5, &"ice": 1.5, &"fire": 0.7, &"earth": 0.7},
		&"ice": {&"wind": 1.5, &"earth": 1.3, &"fire": 0.7, &"ice": 0.7},
		&"wind": {&"plant": 1.5, &"thunder": 0.7, &"earth": 1.2},
		&"earth": {&"thunder": 1.5, &"fire": 1.5, &"wind": 0.7, &"plant": 0.7},
		&"thunder": {&"wind": 1.5, &"ice": 1.3, &"earth": 0.6, &"thunder": 0.7},
		&"plant": {&"earth": 1.5, &"fire": 0.7, &"wind": 0.7, &"plant": 0.7},
		&"light": {&"dark": 1.5, &"light": 0.7},
		&"dark": {&"light": 1.5, &"dark": 0.7},
	}
	chart.element_colors = {
		&"neutral": Color(0.85, 0.87, 0.95),
		&"fire": Color(1.0, 0.47, 0.2),
		&"ice": Color(0.45, 0.82, 1.0),
		&"wind": Color(0.55, 0.95, 0.72),
		&"earth": Color(0.8, 0.6, 0.35),
		&"thunder": Color(1.0, 0.88, 0.25),
		&"plant": Color(0.45, 0.85, 0.35),
		&"light": Color(1.0, 0.95, 0.62),
		&"dark": Color(0.6, 0.4, 0.85),
	}
	chart.same_element_bonus = 1.2
	_save(chart, DATA + "/config/type_chart.tres")


# ---------------------------------------------------------------------------
# Skills
# ---------------------------------------------------------------------------

func _effect(type: int, opts := {}) -> SkillEffect:
	var e := SkillEffect.new()
	e.type = type
	e.target = opts.get("target", SkillEffect.EffectTarget.SKILL_TARGET)
	e.stat = opts.get("stat", &"")
	e.amount = opts.get("amount", 1)
	e.status_id = opts.get("status", &"")
	e.chance = opts.get("chance", 1.0)
	e.duration = opts.get("duration", 3)
	return e


func _dmg() -> SkillEffect:
	return _effect(SkillEffect.Type.DAMAGE)


func _skill(id: StringName, name: String, desc: String, category: int, element: StringName, power: int,
		accuracy: int, sp: int, effects: Array, opts := {}) -> void:
	var s := SkillData.new()
	s.id = id
	s.display_name = name
	s.description = desc
	s.category = category
	s.element = element
	s.power = power
	s.accuracy = accuracy
	s.sp_cost = sp
	s.target = opts.get("target", SkillData.Target.ENEMY)
	s.crit_bonus = opts.get("crit", 0.0)
	s.priority = opts.get("priority", 0)
	var typed: Array[SkillEffect] = []
	for e in effects:
		typed.append(e)
	s.effects = typed
	s.animation = opts.get("anim", &"skill" if category == SkillData.Category.SPECIAL else &"attack")
	s.vfx = opts.get("vfx", &"impact")
	s.projectile = opts.get("projectile", false)
	s.sfx = opts.get("sfx", &"hit_physical" if category == SkillData.Category.PHYSICAL else &"hit_special")
	_save(s, "%s/skills/%s.tres" % [DATA, id])


func _generate_skills() -> void:
	var P := SkillData.Category.PHYSICAL
	var S := SkillData.Category.SPECIAL
	var U := SkillData.Category.SUPPORT
	var SELF := {"target": SkillData.Target.SELF, "anim": &"skill", "vfx": &"aura", "sfx": &"buff"}
	var USER := SkillEffect.EffectTarget.USER
	var BUFF := SkillEffect.Type.BUFF
	var DEBUFF := SkillEffect.Type.DEBUFF
	var STATUS := SkillEffect.Type.STATUS

	_skill(&"tackle", "Tackle", "A full-body charge. Costs no SP.", P, &"neutral", 35, 95, 0, [_dmg()])
	_skill(&"bubble_puff", "Bubble Puff", "Blows a stream of stinging bubbles.", S, &"neutral", 35, 100, 0, [_dmg()],
		{"projectile": true, "vfx": &"bubbles"})

	# Starter lines
	_skill(&"ember_breath", "Ember Breath", "Spits a burst of hot embers at the foe.", S, &"fire", 45, 95, 4, [_dmg()],
		{"projectile": true, "vfx": &"fireball", "sfx": &"fire"})
	_skill(&"claw_swipe", "Claw Swipe", "Rakes the foe with sharp claws. Lands critical hits more often.", P, &"neutral", 50, 90, 3, [_dmg()],
		{"crit": 0.12, "vfx": &"slash"})
	_skill(&"battle_cry", "Battle Cry", "A mighty roar that raises the user's Attack.", U, &"neutral", 0, 100, 4,
		[_effect(BUFF, {"target": USER, "stat": &"attack", "amount": 1})], SELF)
	_skill(&"inferno_burst", "Inferno Burst", "Unleashes a roaring fireball. May burn the target.", S, &"fire", 80, 90, 10,
		[_dmg(), _effect(STATUS, {"status": &"burn", "chance": 0.2, "duration": 3})],
		{"projectile": true, "vfx": &"fireball", "sfx": &"fire"})
	_skill(&"horn_crash", "Horn Crash", "Rams the foe with an armoured horn.", P, &"neutral", 70, 90, 7, [_dmg()], {"vfx": &"impact"})

	_skill(&"frost_howl", "Frost Howl", "Breathes a freezing blue gale.", S, &"ice", 45, 95, 4, [_dmg()],
		{"projectile": true, "vfx": &"frost", "sfx": &"ice"})
	_skill(&"horn_ram", "Horn Ram", "Charges horn-first into the foe.", P, &"neutral", 50, 90, 3, [_dmg()])
	_skill(&"pelt_guard", "Pelt Guard", "Wraps up in its pelt, raising Defense and Sp. Defense.", U, &"neutral", 0, 100, 4,
		[_effect(BUFF, {"target": USER, "stat": &"defense", "amount": 1}),
		_effect(BUFF, {"target": USER, "stat": &"special_defense", "amount": 1})], SELF)
	_skill(&"glacial_fang", "Glacial Fang", "Bites with icy fangs. May lower the target's Speed.", P, &"ice", 80, 90, 10,
		[_dmg(), _effect(DEBUFF, {"stat": &"speed", "amount": 1, "chance": 0.3})], {"vfx": &"frost", "sfx": &"ice"})

	_skill(&"air_pop", "Air Pop", "Fires a compressed puff of air.", S, &"wind", 45, 95, 4, [_dmg()],
		{"projectile": true, "vfx": &"wind", "sfx": &"wind"})
	_skill(&"wing_slap", "Wing Slap", "Smacks the foe with flapping wings.", P, &"wind", 45, 95, 3, [_dmg()], {"vfx": &"wind"})
	_skill(&"soothing_light", "Soothing Light", "A warm glow that restores 35% of max HP.", U, &"light", 0, 100, 6,
		[_effect(SkillEffect.Type.HEAL, {"target": USER, "amount": 35})],
		{"target": SkillData.Target.SELF, "anim": &"skill", "vfx": &"heal", "sfx": &"heal"})
	_skill(&"radiant_strike", "Radiant Strike", "A punch wrapped in holy light.", P, &"light", 80, 95, 10, [_dmg()],
		{"vfx": &"light", "sfx": &"hit_special"})

	# Wild Digimon
	_skill(&"static_silk", "Static Silk", "Shoots electrified thread. May stun the target.", S, &"thunder", 35, 90, 3,
		[_dmg(), _effect(STATUS, {"status": &"stun", "chance": 0.25, "duration": 2})],
		{"projectile": true, "vfx": &"thunder", "sfx": &"thunder"})
	_skill(&"pincer_nip", "Pincer Nip", "A quick pinch with tiny mandibles.", P, &"neutral", 40, 95, 2, [_dmg()])
	_skill(&"club_smash", "Club Smash", "Swings a heavy club with gusto.", P, &"earth", 50, 85, 4, [_dmg()], {"vfx": &"rock"})
	_skill(&"menace", "Menace", "A scary glare that lowers the target's Attack.", U, &"dark", 0, 95, 3,
		[_effect(DEBUFF, {"stat": &"attack", "amount": 1})], {"anim": &"skill", "vfx": &"debuff", "sfx": &"debuff"})
	_skill(&"thorn_whip", "Thorn Whip", "Lashes out with a thorny vine.", P, &"plant", 45, 95, 3, [_dmg()], {"vfx": &"leaf"})
	_skill(&"pollen_cloud", "Pollen Cloud", "Scatters toxic pollen that poisons the target.", U, &"plant", 0, 85, 4,
		[_effect(STATUS, {"status": &"poison", "chance": 0.9, "duration": 4})],
		{"anim": &"skill", "vfx": &"poison", "sfx": &"debuff"})
	_skill(&"leaf_drain", "Leaf Drain", "Saps energy from the foe, healing the user by half the damage.", S, &"plant", 40, 100, 4,
		[_dmg(), _effect(SkillEffect.Type.DRAIN, {"target": USER, "amount": 50})], {"vfx": &"leaf", "sfx": &"heal"})
	_skill(&"spark_tail", "Spark Tail", "Whips crackling tails at the foe.", S, &"thunder", 45, 95, 4, [_dmg()],
		{"vfx": &"thunder", "sfx": &"thunder"})
	_skill(&"quick_dash", "Quick Dash", "A lightning-fast strike that always goes first.", P, &"neutral", 35, 100, 2, [_dmg()],
		{"priority": 1, "vfx": &"slash"})
	_skill(&"flame_peck", "Flame Peck", "Pecks with a beak wreathed in fire.", P, &"fire", 45, 95, 3, [_dmg()],
		{"vfx": &"fireball", "sfx": &"fire"})
	_skill(&"whirlwind", "Whirlwind", "Whips up a cutting whirlwind.", S, &"wind", 50, 90, 5, [_dmg()],
		{"projectile": true, "vfx": &"wind", "sfx": &"wind"})
	_skill(&"focus", "Focus", "Concentrates to raise Sp. Attack and Accuracy.", U, &"neutral", 0, 100, 3,
		[_effect(BUFF, {"target": USER, "stat": &"special_attack", "amount": 1}),
		_effect(BUFF, {"target": USER, "stat": &"accuracy", "amount": 1})], SELF)

	# Champion signature skills
	_skill(&"needle_storm", "Needle Storm", "Fires a barrage of cactus needles.", P, &"plant", 75, 90, 9, [_dmg()], {"vfx": &"leaf"})
	_skill(&"meteor_wing", "Meteor Wing", "Rains blazing feathers on the foe.", S, &"fire", 80, 90, 10, [_dmg()],
		{"projectile": true, "vfx": &"fireball", "sfx": &"fire"})
	_skill(&"beast_fist", "Beast Fist", "A mighty punch backed by a lion's roar.", P, &"earth", 75, 95, 8, [_dmg()], {"vfx": &"impact"})
	_skill(&"heavy_bash", "Heavy Bash", "A crushing overhead club blow.", P, &"earth", 80, 85, 9, [_dmg()], {"vfx": &"rock"})
	_skill(&"buzz_dive", "Buzz Dive", "Dives in with a venomous sting. May poison.", P, &"wind", 70, 95, 8,
		[_dmg(), _effect(STATUS, {"status": &"poison", "chance": 0.25, "duration": 3})], {"vfx": &"wind"})
	_skill(&"guardian_wall", "Guardian Wall", "Raises a barrier that sharply boosts Defense.", U, &"light", 0, 100, 6,
		[_effect(BUFF, {"target": USER, "stat": &"defense", "amount": 2})], SELF)


# ---------------------------------------------------------------------------
# Species
# ---------------------------------------------------------------------------

const ROOKIE := {"hp": 40, "sp": 20, "atk": 12, "def": 10, "spa": 12, "spd": 10, "spe": 11,
	"ghp": 7.0, "gsp": 2.0, "gatk": 2.0, "gdef": 1.8, "gspa": 2.0, "gspd": 1.8, "gspe": 1.6}
const CHAMPION := {"hp": 62, "sp": 28, "atk": 19, "def": 16, "spa": 19, "spd": 16, "spe": 15,
	"ghp": 9.0, "gsp": 2.5, "gatk": 2.6, "gdef": 2.3, "gspa": 2.6, "gspd": 2.3, "gspe": 2.0}
const IN_TRAINING := {"hp": 30, "sp": 14, "atk": 9, "def": 8, "spa": 9, "spd": 8, "spe": 10,
	"ghp": 5.5, "gsp": 1.5, "gatk": 1.5, "gdef": 1.3, "gspa": 1.5, "gspd": 1.3, "gspe": 1.3}


func _evo(target: StringName, level: int, item: StringName = &"", hint := "") -> EvolutionPath:
	var e := EvolutionPath.new()
	e.target_species_id = target
	e.min_level = level
	e.required_item_id = item
	e.hint = hint
	return e


## Quaternius "Ultimate Monsters" (CC0) model per species:
## [file under assets/models/monsters, target height in m, hovers].
const MODELS := {
	&"koromon": ["blob/PinkBlob", 0.6, false],
	&"tsunomon": ["blob/Birb", 0.6, false],
	&"tokomon": ["blob/Chicken", 0.6, false],
	&"agumon": ["big/Dino", 1.1, false],
	&"gabumon": ["big/Yeti", 1.05, false],
	&"patamon": ["blob/Dog", 0.75, true],
	&"biyomon": ["flying/Pigeon", 0.75, true],
	&"elecmon": ["big/Frog", 0.85, false],
	&"goburimon": ["big/Orc", 1.0, false],
	&"palmon": ["blob/Cactoro", 0.85, false],
	&"kunemon": ["flying/Armabee", 0.7, true],
	&"greymon": ["flying/Dragon_Evolved", 1.6, true],
	&"garurumon": ["big/Fish", 1.4, false],
	&"angemon": ["big/Bunny", 1.75, false],
	&"birdramon": ["flying/Dragon", 0.75, true],
	&"flymon": ["flying/Armabee_Evolved", 0.8, true],
	&"leomon": ["big/Ninja", 1.1, false],
	&"ogremon": ["big/Orc_Skull", 0.95, false],
	&"togemon": ["big/Cactoro", 1.0, false],
}


func _species(id: StringName, def: Dictionary) -> void:
	var s := DigimonSpecies.new()
	s.id = id
	s.display_name = def.name
	s.description = def.desc
	s.stage = def.stage
	s.attribute = def.attr
	s.digimon_type = def.type
	s.element = def.element
	s.rarity = def.get("rarity", DigimonSpecies.Rarity.COMMON)
	var base: Dictionary = def.base.duplicate()
	var mods: Dictionary = def.get("mods", {})
	for key in mods.keys():
		base[key] = base[key] + mods[key]
	s.base_hp = base.hp
	s.base_sp = base.sp
	s.base_attack = base.atk
	s.base_defense = base.def
	s.base_special_attack = base.spa
	s.base_special_defense = base.spd
	s.base_speed = base.spe
	s.growth_hp = base.ghp
	s.growth_sp = base.gsp
	s.growth_attack = base.gatk
	s.growth_defense = base.gdef
	s.growth_special_attack = base.gspa
	s.growth_special_defense = base.gspd
	s.growth_speed = base.gspe
	var innate: Array[StringName] = []
	for sk in def.innate:
		innate.append(sk)
	s.innate_skills = innate
	s.learnset = def.get("learnset", {})
	var evos: Array[EvolutionPath] = []
	for e in def.get("evos", []):
		evos.append(e)
	s.evolutions = evos
	s.base_exp_yield = def.get("exp", 40)
	s.recruit_modifier = def.get("recruit", 1.0)
	s.drop_table = def.get("drops", {&"small_patch": 0.2})
	s.placeholder_body = def.body
	s.placeholder_colors = PackedColorArray(def.colors)
	s.placeholder_options = def.get("options", {})
	s.model_scale = def.get("scale", 1.0)
	s.hovers = def.get("hovers", false)
	if MODELS.has(id):
		var m: Array = MODELS[id]
		s.model_path = "res://assets/models/monsters/%s.gltf" % m[0]
		s.model_target_height = m[1]
		s.hovers = m[2]
	s.move_speed = def.get("speed", 3.5)
	s.animation_set = &"creature_default"
	s.sounds = {&"cry": &"cry_%s" % def.get("cry", "small")}
	_save(s, "%s/digimon/%s.tres" % [DATA, id])


func _generate_species() -> void:
	var ST := DigimonSpecies.Stage
	var AT := DigimonSpecies.Attribute
	var RA := DigimonSpecies.Rarity

	# --- Starters (Rookie) -------------------------------------------------
	_species(&"agumon", {
		"name": "Agumon", "stage": ST.ROOKIE, "attr": AT.VACCINE, "type": "Reptile", "element": &"fire",
		"rarity": RA.RARE, "base": ROOKIE, "mods": {"hp": 2, "atk": 2, "spd": -1, "spe": 0},
		"desc": "A small, brave reptile Digimon with a big appetite and an even bigger heart. It puffs out little flames when excited.",
		"innate": [&"tackle", &"ember_breath"], "learnset": {6: &"claw_swipe", 9: &"battle_cry"},
		"evos": [_evo(&"greymon", 10, &"", "Grows with experience."), _evo(&"greymon", 7, &"evo_shard", "An Evo Shard can speed things up.")],
		"exp": 55, "body": &"dino",
		"colors": [Color(1.0, 0.62, 0.18), Color(1.0, 0.9, 0.66), Color(0.98, 0.97, 0.92), Color(0.28, 0.62, 0.28)],
		"options": {"tail": true, "claws": true}, "cry": "roar",
	})
	_species(&"gabumon", {
		"name": "Gabumon", "stage": ST.ROOKIE, "attr": AT.DATA, "type": "Reptile", "element": &"ice",
		"rarity": RA.RARE, "base": ROOKIE, "mods": {"hp": 4, "def": 3, "atk": 0, "spe": -1},
		"desc": "A shy horned Digimon that hides under a warm striped pelt. Loyal and calm, it breathes chilly blue gusts.",
		"innate": [&"tackle", &"frost_howl"], "learnset": {6: &"horn_ram", 9: &"pelt_guard"},
		"evos": [_evo(&"garurumon", 10, &"", "Grows with experience."), _evo(&"garurumon", 7, &"evo_shard", "An Evo Shard can speed things up.")],
		"exp": 55, "body": &"beast",
		"colors": [Color(1.0, 0.84, 0.36), Color(0.36, 0.58, 0.95), Color(0.95, 0.97, 1.0), Color(0.75, 0.2, 0.2)],
		"options": {"horn": true, "pelt": true}, "cry": "howl",
	})
	_species(&"patamon", {
		"name": "Patamon", "stage": ST.ROOKIE, "attr": AT.DATA, "type": "Mammal", "element": &"wind",
		"rarity": RA.RARE, "base": ROOKIE, "mods": {"hp": -2, "sp": 4, "atk": -1, "spa": 1, "spd": 2, "spe": 2},
		"desc": "A round, cheerful Digimon that flies by flapping its big ear-wings. Said to bring good luck to its Tamer.",
		"innate": [&"tackle", &"air_pop"], "learnset": {6: &"wing_slap", 9: &"soothing_light"},
		"evos": [_evo(&"angemon", 10, &"", "Grows with experience."), _evo(&"angemon", 7, &"evo_shard", "An Evo Shard can speed things up.")],
		"exp": 55, "body": &"winged", "hovers": true,
		"colors": [Color(1.0, 0.72, 0.38), Color(1.0, 0.94, 0.8), Color(0.62, 0.42, 0.3), Color(0.24, 0.42, 0.82)],
		"cry": "chirp",
	})

	# --- Starter Champions -------------------------------------------------
	_species(&"greymon", {
		"name": "Greymon", "stage": ST.CHAMPION, "attr": AT.VACCINE, "type": "Dinosaur", "element": &"fire",
		"rarity": RA.RARE, "base": CHAMPION, "mods": {"atk": 3, "hp": 4},
		"desc": "A towering armoured dinosaur Digimon. Its helmeted head can shrug off heavy blows.",
		"innate": [&"tackle", &"ember_breath", &"horn_crash"], "learnset": {12: &"inferno_burst", 15: &"battle_cry"},
		"exp": 110, "body": &"big_dino", "scale": 1.0, "speed": 4.0,
		"colors": [Color(1.0, 0.55, 0.16), Color(0.26, 0.36, 0.74), Color(0.62, 0.48, 0.32), Color(0.9, 0.2, 0.1)],
		"cry": "roar",
	})
	_species(&"garurumon", {
		"name": "Garurumon", "stage": ST.CHAMPION, "attr": AT.DATA, "type": "Beast", "element": &"ice",
		"rarity": RA.RARE, "base": CHAMPION, "mods": {"spe": 4, "def": 1},
		"desc": "A swift wolf Digimon with a coat that shimmers like ice. It runs across the Digital World like the wind.",
		"innate": [&"tackle", &"frost_howl", &"horn_ram"], "learnset": {12: &"glacial_fang", 15: &"pelt_guard"},
		"exp": 110, "body": &"wolf", "speed": 5.0,
		"colors": [Color(0.86, 0.92, 1.0), Color(0.3, 0.5, 0.92), Color(0.97, 0.98, 1.0), Color(0.85, 0.15, 0.15)],
		"cry": "howl",
	})
	_species(&"angemon", {
		"name": "Angemon", "stage": ST.CHAMPION, "attr": AT.VACCINE, "type": "Angel", "element": &"light",
		"rarity": RA.RARE, "base": CHAMPION, "mods": {"spa": 2, "spd": 3},
		"desc": "A radiant guardian Digimon with several pairs of wings. It protects the weak with a steady light.",
		"innate": [&"tackle", &"air_pop", &"soothing_light"], "learnset": {12: &"radiant_strike", 15: &"guardian_wall"},
		"exp": 110, "body": &"angel", "hovers": true, "speed": 4.2,
		"colors": [Color(0.97, 0.97, 1.0), Color(0.3, 0.45, 0.9), Color(1.0, 0.84, 0.36), Color(0.3, 0.5, 0.9)],
		"cry": "chime",
	})

	# --- Wild Rookies ------------------------------------------------------
	_species(&"kunemon", {
		"name": "Kunemon", "stage": ST.ROOKIE, "attr": AT.VIRUS, "type": "Larva", "element": &"thunder",
		"rarity": RA.COMMON, "base": ROOKIE, "mods": {"hp": -6, "atk": -2, "def": -1, "spe": -1},
		"desc": "A mischievous larva Digimon that spins crackling threads from its mouth.",
		"innate": [&"tackle", &"static_silk"], "learnset": {5: &"pincer_nip"},
		"evos": [_evo(&"flymon", 12)], "exp": 36, "body": &"larva", "speed": 2.6,
		"drops": {&"small_patch": 0.3},
		"colors": [Color(1.0, 0.86, 0.22), Color(0.22, 0.2, 0.26), Color(0.92, 0.26, 0.22), Color(0.1, 0.1, 0.1)],
		"cry": "buzz",
	})
	_species(&"goburimon", {
		"name": "Goburimon", "stage": ST.ROOKIE, "attr": AT.VIRUS, "type": "Goblin", "element": &"earth",
		"rarity": RA.COMMON, "base": ROOKIE, "mods": {"hp": -2, "atk": 1, "spa": -4, "spd": -2, "spe": -2},
		"desc": "A cheeky goblin Digimon that swings a knobbly club at anything that moves.",
		"innate": [&"tackle", &"club_smash"], "learnset": {6: &"menace"},
		"evos": [_evo(&"ogremon", 12)], "exp": 40, "body": &"goblin", "speed": 3.2,
		"drops": {&"small_patch": 0.25, &"sp_capsule": 0.1},
		"colors": [Color(0.46, 0.74, 0.36), Color(0.56, 0.36, 0.2), Color(0.64, 0.5, 0.34), Color(0.95, 0.85, 0.2)],
		"cry": "grunt",
	})
	_species(&"palmon", {
		"name": "Palmon", "stage": ST.ROOKIE, "attr": AT.DATA, "type": "Plant", "element": &"plant",
		"rarity": RA.UNCOMMON, "base": ROOKIE, "mods": {"atk": -2, "spd": 2},
		"desc": "A plant Digimon with a big flower on its head. It loves sunshine and can stretch its vines.",
		"innate": [&"tackle", &"thorn_whip"], "learnset": {5: &"pollen_cloud", 8: &"leaf_drain"},
		"evos": [_evo(&"togemon", 12)], "exp": 46, "body": &"plant", "speed": 3.0,
		"drops": {&"small_patch": 0.25, &"friend_treat": 0.1},
		"colors": [Color(0.46, 0.8, 0.42), Color(1.0, 0.46, 0.62), Color(1.0, 0.86, 0.3), Color(0.12, 0.3, 0.12)],
		"cry": "chirp",
	})
	_species(&"elecmon", {
		"name": "Elecmon", "stage": ST.ROOKIE, "attr": AT.DATA, "type": "Mammal", "element": &"thunder",
		"rarity": RA.UNCOMMON, "base": ROOKIE, "mods": {"hp": -3, "spa": 1, "spe": 4, "def": -1},
		"desc": "A spirited mammal Digimon whose bundle of tails crackles with static.",
		"innate": [&"tackle", &"spark_tail"], "learnset": {5: &"quick_dash", 8: &"focus"},
		"evos": [_evo(&"leomon", 12)], "exp": 46, "body": &"critter", "speed": 4.5,
		"drops": {&"sp_capsule": 0.2},
		"colors": [Color(0.92, 0.3, 0.26), Color(0.3, 0.42, 0.88), Color(0.66, 0.42, 0.92), Color(0.1, 0.1, 0.12)],
		"cry": "squeak",
	})
	_species(&"biyomon", {
		"name": "Biyomon", "stage": ST.ROOKIE, "attr": AT.VACCINE, "type": "Bird", "element": &"wind",
		"rarity": RA.UNCOMMON, "base": ROOKIE, "mods": {"spe": 2, "spa": 1, "def": -2},
		"desc": "A bright bird Digimon that is still learning to fly. It pecks with a beak that glows with heat.",
		"innate": [&"tackle", &"flame_peck"], "learnset": {6: &"whirlwind", 9: &"focus"},
		"evos": [_evo(&"birdramon", 12)], "exp": 46, "body": &"bird", "hovers": true, "speed": 3.6,
		"drops": {&"small_patch": 0.2, &"friend_treat": 0.1},
		"colors": [Color(1.0, 0.58, 0.72), Color(1.0, 0.82, 0.3), Color(0.42, 0.72, 0.96), Color(0.18, 0.28, 0.6)],
		"cry": "chirp",
	})

	# --- In-Training (rare wild) -------------------------------------------
	_species(&"koromon", {
		"name": "Koromon", "stage": ST.IN_TRAINING, "attr": AT.FREE, "type": "Lesser", "element": &"neutral",
		"rarity": RA.UNCOMMON, "base": IN_TRAINING,
		"desc": "A bouncy pink ball of a Digimon with long floppy ears. It hops everywhere.",
		"innate": [&"tackle", &"bubble_puff"], "evos": [_evo(&"agumon", 6)], "exp": 30, "body": &"blob", "speed": 3.0,
		"colors": [Color(1.0, 0.56, 0.7), Color(1.0, 0.8, 0.86), Color(0.9, 0.3, 0.5), Color(0.9, 0.2, 0.2)],
		"options": {"ears": &"long"}, "cry": "squeak",
	})
	_species(&"tsunomon", {
		"name": "Tsunomon", "stage": ST.IN_TRAINING, "attr": AT.FREE, "type": "Lesser", "element": &"neutral",
		"rarity": RA.UNCOMMON, "base": IN_TRAINING,
		"desc": "A small round Digimon with a single horn and soft blue fur.",
		"innate": [&"tackle", &"bubble_puff"], "evos": [_evo(&"gabumon", 6)], "exp": 30, "body": &"blob", "speed": 3.0,
		"colors": [Color(0.52, 0.72, 1.0), Color(0.86, 0.92, 1.0), Color(0.95, 0.9, 0.75), Color(0.8, 0.2, 0.2)],
		"options": {"horn": true}, "cry": "squeak",
	})
	_species(&"tokomon", {
		"name": "Tokomon", "stage": ST.IN_TRAINING, "attr": AT.FREE, "type": "Lesser", "element": &"neutral",
		"rarity": RA.UNCOMMON, "base": IN_TRAINING,
		"desc": "A tiny white Digimon with little feet and a surprisingly big mouth.",
		"innate": [&"tackle", &"bubble_puff"], "evos": [_evo(&"patamon", 6)], "exp": 30, "body": &"blob", "speed": 3.0,
		"colors": [Color(0.98, 0.96, 0.92), Color(1.0, 0.8, 0.7), Color(1.0, 0.6, 0.55), Color(0.2, 0.2, 0.25)],
		"options": {"ears": &"short", "feet": true}, "cry": "squeak",
	})

	# --- Wild Champions (evolution targets) -------------------------------
	_species(&"flymon", {
		"name": "Flymon", "stage": ST.CHAMPION, "attr": AT.VIRUS, "type": "Insect", "element": &"wind",
		"rarity": RA.UNCOMMON, "base": CHAMPION, "mods": {"spe": 3, "def": -2},
		"desc": "A huge buzzing insect Digimon. The sound of its wings unsettles its foes.",
		"innate": [&"tackle", &"static_silk", &"pincer_nip"], "learnset": {14: &"buzz_dive"},
		"exp": 100, "body": &"larva", "hovers": true, "options": {"wings": true}, "scale": 1.3,
		"colors": [Color(0.95, 0.72, 0.2), Color(0.22, 0.2, 0.26), Color(0.7, 0.9, 1.0), Color(0.9, 0.2, 0.2)],
		"cry": "buzz",
	})
	_species(&"ogremon", {
		"name": "Ogremon", "stage": ST.CHAMPION, "attr": AT.VIRUS, "type": "Ogre", "element": &"earth",
		"rarity": RA.UNCOMMON, "base": CHAMPION, "mods": {"atk": 4, "spa": -4},
		"desc": "A hulking ogre Digimon carrying a bone-white club. Rough, but it respects strength.",
		"innate": [&"tackle", &"club_smash", &"menace"], "learnset": {14: &"heavy_bash"},
		"exp": 100, "body": &"goblin", "scale": 1.45,
		"colors": [Color(0.3, 0.58, 0.3), Color(0.4, 0.26, 0.18), Color(0.94, 0.92, 0.86), Color(1.0, 0.8, 0.2)],
		"cry": "grunt",
	})
	_species(&"togemon", {
		"name": "Togemon", "stage": ST.CHAMPION, "attr": AT.DATA, "type": "Plant", "element": &"plant",
		"rarity": RA.UNCOMMON, "base": CHAMPION, "mods": {"hp": 8, "def": 3, "spe": -3},
		"desc": "A giant cactus Digimon wearing boxing gloves. Prickly outside, kind inside.",
		"innate": [&"tackle", &"thorn_whip", &"leaf_drain"], "learnset": {14: &"needle_storm"},
		"exp": 100, "body": &"plant", "scale": 1.5, "options": {"cactus": true},
		"colors": [Color(0.4, 0.7, 0.3), Color(1.0, 0.4, 0.4), Color(1.0, 0.85, 0.35), Color(0.1, 0.2, 0.1)],
		"cry": "grunt",
	})
	_species(&"leomon", {
		"name": "Leomon", "stage": ST.CHAMPION, "attr": AT.VACCINE, "type": "Beast Man", "element": &"earth",
		"rarity": RA.RARE, "base": CHAMPION, "mods": {"atk": 3, "spe": 1},
		"desc": "A noble lion-like warrior Digimon with a flowing mane and a strong sense of justice.",
		"innate": [&"tackle", &"quick_dash", &"spark_tail"], "learnset": {14: &"beast_fist"},
		"exp": 110, "body": &"beast", "scale": 1.4, "options": {"pelt": false, "mane": true, "horn": false},
		"colors": [Color(1.0, 0.8, 0.4), Color(0.85, 0.5, 0.2), Color(0.95, 0.9, 0.8), Color(0.2, 0.2, 0.2)],
		"cry": "roar",
	})
	_species(&"birdramon", {
		"name": "Birdramon", "stage": ST.CHAMPION, "attr": AT.VACCINE, "type": "Giant Bird", "element": &"fire",
		"rarity": RA.RARE, "base": CHAMPION, "mods": {"spe": 3, "spa": 2, "def": -2},
		"desc": "A great bird Digimon whose wings blaze like a sunrise.",
		"innate": [&"tackle", &"flame_peck", &"whirlwind"], "learnset": {14: &"meteor_wing"},
		"exp": 110, "body": &"bird", "hovers": true, "scale": 1.5,
		"colors": [Color(1.0, 0.5, 0.2), Color(1.0, 0.85, 0.3), Color(1.0, 0.3, 0.15), Color(0.3, 0.2, 0.1)],
		"cry": "chirp",
	})


# ---------------------------------------------------------------------------
# Items
# ---------------------------------------------------------------------------

func _item(id: StringName, name: String, desc: String, category: int, effect: int, value: int, opts := {}) -> void:
	var it := ItemData.new()
	it.id = id
	it.display_name = name
	it.description = desc
	it.category = category
	it.use_effect = effect
	it.effect_value = value
	it.max_stack = opts.get("stack", 99)
	it.usable_in_field = opts.get("field", false)
	it.usable_in_battle = opts.get("battle", false)
	it.consumed_on_use = opts.get("consumed", true)
	it.icon_color = opts.get("color", Color(0.4, 0.8, 1.0))
	it.icon_path = "res://assets/icons/items/%s.svg" % id
	it.buy_price = opts.get("price", 0)
	it.sell_price = int(opts.get("price", 0) / 2)
	it.equip_bonuses = opts.get("bonuses", {})
	_save(it, "%s/items/%s.tres" % [DATA, id])


func _generate_items() -> void:
	var C := ItemData.Category
	var E := ItemData.UseEffect
	_item(&"small_patch", "Small Data Patch", "Restores 40 HP to one Digimon.", C.CONSUMABLE, E.HEAL_HP, 40,
		{"field": true, "battle": true, "color": Color(0.36, 0.86, 0.5), "price": 20})
	_item(&"medium_patch", "Medium Data Patch", "Restores 100 HP to one Digimon.", C.CONSUMABLE, E.HEAL_HP, 100,
		{"field": true, "battle": true, "color": Color(0.24, 0.74, 0.95), "price": 60})
	_item(&"sp_capsule", "SP Capsule", "Restores 20 SP to one Digimon.", C.CONSUMABLE, E.RESTORE_SP, 20,
		{"field": true, "battle": true, "color": Color(0.62, 0.48, 1.0), "price": 40})
	_item(&"reboot_chip", "Reboot Chip", "Revives a fainted Digimon with 50% HP.", C.CONSUMABLE, E.REVIVE, 50,
		{"field": true, "battle": true, "color": Color(1.0, 0.82, 0.3), "price": 150, "stack": 20})
	_item(&"full_recovery_disk", "Full Recovery Disk", "Fully restores HP and SP of one Digimon.", C.CONSUMABLE, E.FULL_RESTORE, 0,
		{"field": true, "battle": true, "color": Color(1.0, 0.45, 0.62), "price": 300, "stack": 20})
	_item(&"friend_treat", "Friendly Treat", "A tasty snack. Using it in battle makes a wild Digimon easier to befriend (+15%).",
		C.CONSUMABLE, E.BEFRIEND_BOOST, 15, {"battle": true, "color": Color(1.0, 0.64, 0.3), "price": 30})
	_item(&"evo_shard", "Evo Shard", "A crystal humming with evolution data. Lets a Rookie evolve early (Lv 7+). Used up on evolution.",
		C.EVOLUTION, E.NONE, 0, {"color": Color(0.3, 0.95, 0.9), "stack": 10})
	_item(&"data_fragment", "Data Fragment", "A glowing piece of Byte's scattered archive.", C.QUEST, E.NONE, 0,
		{"color": Color(0.35, 0.9, 1.0), "stack": 10})
	_item(&"training_badge", "Training Badge", "Proof that you finished Mira's training.", C.QUEST, E.NONE, 0,
		{"color": Color(1.0, 0.75, 0.25), "stack": 1})
	_item(&"gate_pass", "Gate Pass", "Opens the gateway in the Starter Zone.", C.KEY, E.NONE, 0,
		{"color": Color(0.95, 0.4, 0.95), "stack": 1})

	# Equipment chips: one can be held per Digimon (see EquipmentService).
	_item(&"power_chip", "Power Chip", "A red circuit that sharpens every strike.", C.EQUIPMENT, E.NONE, 0,
		{"color": Color(1.0, 0.42, 0.32), "price": 250, "stack": 9, "bonuses": {DigimonStats.ATTACK: 6}})
	_item(&"guard_chip", "Guard Chip", "A sturdy blue circuit that hardens data shells.", C.EQUIPMENT, E.NONE, 0,
		{"color": Color(0.35, 0.6, 1.0), "price": 250, "stack": 9, "bonuses": {DigimonStats.DEFENSE: 6}})
	_item(&"speed_chip", "Speed Chip", "A light green circuit that hums with momentum.", C.EQUIPMENT, E.NONE, 0,
		{"color": Color(0.4, 0.95, 0.5), "price": 300, "stack": 9, "bonuses": {DigimonStats.SPEED: 5}})
	_item(&"focus_chip", "Focus Chip", "A violet circuit that amplifies special techniques.", C.EQUIPMENT, E.NONE, 0,
		{"color": Color(0.72, 0.5, 1.0), "price": 250, "stack": 9, "bonuses": {DigimonStats.SPECIAL_ATTACK: 6}})
	_item(&"vital_chip", "Vital Chip", "A warm golden circuit that reinforces the core.", C.EQUIPMENT, E.NONE, 0,
		{"color": Color(1.0, 0.8, 0.3), "price": 300, "stack": 9, "bonuses": {DigimonStats.MAX_HP: 20}})


# ---------------------------------------------------------------------------
# Dialogue
# ---------------------------------------------------------------------------

func _dialogue(id: StringName, lines: Array, skippable := true) -> void:
	var d := DialogueData.new()
	d.id = id
	d.skippable = skippable
	var typed: Array[DialogueLine] = []
	for entry in lines:
		var line := DialogueLine.new()
		if entry is Array:
			line.speaker = entry[0]
			line.text = entry[1]
			if entry.size() > 2:
				line.emotion = entry[2]
		else:
			line.speaker = "{npc_name}"
			line.text = entry
		typed.append(line)
	d.lines = typed
	_save(d, "%s/dialogue/%s.tres" % [DATA, id])


func _generate_dialogue() -> void:
	# Intro narration (speaker "" = narrator).
	_dialogue(&"intro_sequence", [
		["", "A soft chime wakes you. Lines of light stream past like shooting stars…"],
		["", "When the glow fades, you are standing somewhere impossible: a world built from living data."],
		["{partner_name}", "…Hey! Hey, are you okay? You're {player_name}, right? I've been waiting for you!", &"happy"],
		["{partner_name}", "This is the Digital World. It's where Digimon like me live. And now… you're my Tamer!", &"happy"],
		["", "Your adventure begins."],
	])

	# Mira — Tamer Guide
	_dialogue(&"mira_offer", [
		"Oh! You must be {player_name}. Welcome to the Digital World!",
		"And that must be your partner, {partner_name}. You two already look like a great team.",
		"I'm Mira. I help new Tamers find their footing. Let's start with the basics!",
		"Cross the bridge to the east and visit the Training Grounds. Then show me you can win a battle against a wild Digimon.",
		"Walk into a wild Digimon to challenge it. Skills cost SP, so watch your gauge!",
	])
	_dialogue(&"mira_hint", [
		"Head east across the bridge to the Training Grounds, then win a battle against a wild Digimon.",
		"If {partner_name} gets hurt, the Recovery Terminal here in the plaza will patch you right up.",
	])
	_dialogue(&"mira_turn_in", [
		"You did it, {player_name}! {partner_name} fought brilliantly.",
		"Here, take these supplies. That Evo Shard is special: once {partner_name} reaches Lv 7 it can trigger an early evolution.",
		"I've also given you a Gate Pass. The gateway to the north-east will open for you now.",
	])
	_dialogue(&"mira_friend_offer", [
		"Digimon don't join Tamers because they're forced to. They join because they want to.",
		"When a wild Digimon is weakened, try the Befriend command in battle. A Friendly Treat helps, too.",
		"Why don't you try to make a new friend? Come back when someone joins your team!",
	])
	_dialogue(&"mira_friend_hint", [
		"Weaken a wild Digimon, then use Befriend. Sometimes they even ask to join after a good fight!",
	])
	_dialogue(&"mira_friend_done", [
		"Look at that, a new friend! Your party can hold three Digimon. The rest wait safely in your Collection.",
		"Open the menu to manage your Party and Collection. Take these and keep exploring!",
	])
	_dialogue(&"mira_default", [
		"The Digital World is huge, {player_name}. Keep training with {partner_name}!",
	])

	# Byte — Data Archivist
	_dialogue(&"byte_offer", [
		"Bzzt! Greetings, Tamer {player_name}. I am Byte, archivist of this zone.",
		"A data storm scattered fragments of my archive all over the place. They glow like little floating cubes.",
		"Could you collect three Data Fragments for me? Just walk up to one and pick it up.",
	])
	_dialogue(&"byte_hint", [
		"My sensors detect fragments near the river, in the Wild Meadow and on the northern hill. Three is all I need!",
	])
	_dialogue(&"byte_turn_in", [
		"Archive restored! Splendid work, {player_name}.",
		"Please accept some equipment from my storage. That Power Chip boosts the attack of whichever Digimon holds it.",
		"Open your Inventory, pick the Gear tab and choose who should hold it. Use it well!",
	])
	_dialogue(&"byte_after", [
		"Did you know? Vaccine beats Virus, Virus beats Data, and Data beats Vaccine. Knowledge is power!",
		"Element matters too: fire melts ice, ice chills wind, thunder zaps wind. Experiment!",
	])

	# Kai — Rookie Tamer
	_dialogue(&"kai_default", [
		"Hey! I'm Kai. I'm training to become the strongest Tamer around!",
		"Tip: push the joystick all the way to run, or tap the Sprint button to keep running.",
		"In battle, Defend halves damage and restores some SP. Super handy when you're running low!",
	])

	# Pip — Item Vendor (Starter Zone plaza)
	_dialogue(&"pip_default", [
		"Welcome to Pip's Patch Stand! Patches, capsules, treats… everything a new Tamer needs.",
	])

	# Lumi — Forest Ranger (Data Forest)
	_dialogue(&"lumi_offer", [
		"Oh! A Tamer came through the Gateway? Welcome to the Data Forest, {player_name}. I'm Lumi, the ranger here.",
		"The forest's data has been restless lately. I need someone to survey it for me.",
		"Visit the Crystal Lake to the north and the Old Ruins in the east, and win three battles against wild Digimon along the way.",
		"Stronger Digimon live here than in the Starter Zone. My shop has chips and supplies if you need them!",
	])
	_dialogue(&"lumi_hint", [
		"The Crystal Lake is north of camp, the Old Ruins are to the east. Stay safe, {player_name}!",
	])
	_dialogue(&"lumi_turn_in", [
		"Your survey is perfect! The forest feels calmer already.",
		"Take this Speed Chip and an Evo Shard. {partner_name} has earned them.",
	])
	_dialogue(&"lumi_after", [
		"Thanks to you the forest is peaceful again. Need anything? Take a look at my wares.",
	])

	# Signposts & objects
	_dialogue(&"sign_plaza", [
		["Signpost", "PLAZA — Recovery Terminal here.\nEAST (over the bridge): Training Grounds & Wild Meadow.\nNORTH-EAST: Gateway."],
	])
	_dialogue(&"sign_meadow", [
		["Signpost", "WILD MEADOW — Wild Digimon roam the tall grass. Tamers, stay alert!"],
	])
	_dialogue(&"sign_training", [
		["Signpost", "TRAINING GROUNDS — Wild Digimon often wander in here. Perfect for practice battles."],
	])
	_dialogue(&"portal_locked", [
		["Gateway", "The gateway is sealed. A shimmering message reads: \"Gate Pass required.\""],
	])
	_dialogue(&"portal_unlocked", [
		["Gateway", "The gateway hums with energy… but the path beyond is still forming."],
		["Gateway", "(A new zone will be reachable here in a future update.)"],
	])
	_dialogue(&"sign_forest_camp", [
		["Signpost", "RANGER CAMP — Recovery Terminal and Lumi's shop.\nNORTH: Crystal Lake.  EAST: Old Ruins.  SOUTH-WEST: Gateway home."],
	])
	_dialogue(&"sign_lake", [
		["Signpost", "CRYSTAL LAKE — Its water mirrors the data sky. Do not drink the code."],
	])
	_dialogue(&"sign_ruins", [
		["Signpost", "OLD RUINS — Remains of an ancient server. Strong Digimon gather here."],
	])
	_dialogue(&"terminal_heal", [
		["Recovery Terminal", "Scanning party… Restoring data… Done! Your Digimon are fully healed."],
	])


# ---------------------------------------------------------------------------
# NPCs
# ---------------------------------------------------------------------------

func _npc(id: StringName, name: String, title: String, default_dialogue: StringName, appearance: Dictionary,
		shop_id: StringName = &"", radius := 2.6) -> void:
	var n := NpcData.new()
	n.interaction_radius = radius
	n.id = id
	n.display_name = name
	n.title = title
	n.default_dialogue_id = default_dialogue
	n.appearance = appearance
	if shop_id != &"":
		n.service = &"shop"
		n.shop_id = shop_id
	_save(n, "%s/npcs/%s.tres" % [DATA, id])


func _generate_npcs() -> void:
	_npc(&"mira", "Mira", "Tamer Guide", &"mira_default", {
		"body_type": "female", "hair_style": "long", "hair_color": "2bb3a3", "face": "cheerful",
		"eye_color": "3c9a5f", "skin_tone": "f6d2b3", "top": "jacket", "top_color": "34c3ff",
		"bottom": "long_pants", "bottom_color": "2f4a8a", "shoes": "boots", "shoes_color": "8b5e3c",
		"accessories": ["backpack"], "accessory_color": "ffd166",
	})
	_npc(&"byte", "Byte", "Data Archivist", &"byte_after", {
		"body_type": "male", "hair_style": "short", "hair_color": "c9ccd6", "face": "cool",
		"eye_color": "8a5ad6", "skin_tone": "e8b98f", "top": "adventure_shirt", "top_color": "8a5ad6",
		"bottom": "adventure_pants", "bottom_color": "3a3f4b", "shoes": "sneakers", "shoes_color": "34c3ff",
		"accessories": ["glasses"], "accessory_color": "3a3f4b",
	})
	_npc(&"kai", "Kai", "Rookie Tamer", &"kai_default", {
		"body_type": "male", "hair_style": "spiky", "hair_color": "c8412f", "face": "bright",
		"eye_color": "d18a2a", "skin_tone": "c99468", "top": "hoodie", "top_color": "5ac86e",
		"bottom": "shorts", "bottom_color": "3a3f4b", "shoes": "sneakers", "shoes_color": "e04f5f",
		"accessories": ["hat"], "accessory_color": "e04f5f",
	})
	_npc(&"pip", "Pip", "Item Vendor", &"pip_default", {
		"body_type": "female", "hair_style": "twin_tails", "hair_color": "f08cb4", "face": "bright",
		"eye_color": "3b6fd1", "skin_tone": "f9e0cc", "top": "t_shirt", "top_color": "ffd166",
		"bottom": "shorts", "bottom_color": "3a6ee8", "shoes": "sneakers", "shoes_color": "ff7a45",
		"accessories": ["backpack"], "accessory_color": "ff7a45",
	}, &"plaza_shop")
	_npc(&"lumi", "Lumi", "Forest Ranger", &"lumi_after", {
		"body_type": "female", "hair_style": "ponytail", "hair_color": "6b4226", "face": "cool",
		"eye_color": "3c9a5f", "skin_tone": "c99468", "top": "adventure_shirt", "top_color": "5ac86e",
		"bottom": "adventure_pants", "bottom_color": "8b5e3c", "shoes": "boots", "shoes_color": "3a3f4b",
		"accessories": ["hat"], "accessory_color": "5ac86e",
	}, &"forest_shop", 3.4)


# ---------------------------------------------------------------------------
# Quests
# ---------------------------------------------------------------------------

func _objective(type: int, target: StringName, count: int, desc: String, waypoint: StringName = &"") -> QuestObjective:
	var o := QuestObjective.new()
	o.type = type
	o.target_id = target
	o.required_count = count
	o.description = desc
	o.waypoint_id = waypoint
	return o


func _quest(def: Dictionary) -> void:
	var q := QuestData.new()
	q.id = def.id
	q.title = def.title
	q.summary = def.summary
	q.giver_npc_id = def.get("giver", &"")
	q.turn_in_npc_id = def.get("turn_in", &"")
	q.sort_order = def.get("order", 0)
	var prereq: Array[StringName] = []
	for p in def.get("prereq", []):
		prereq.append(p)
	q.prerequisite_quest_ids = prereq
	var objectives: Array[QuestObjective] = []
	for o in def.objectives:
		objectives.append(o)
	q.objectives = objectives
	q.offer_dialogue_id = def.get("offer", &"")
	q.in_progress_dialogue_id = def.get("hint", &"")
	q.turn_in_dialogue_id = def.get("turn_in_dialogue", &"")
	q.after_dialogue_id = def.get("after", &"")
	q.reward_exp = def.get("exp", 0)
	q.reward_currency = def.get("currency", 0)
	q.reward_items = def.get("items", {})
	var flags: Array[StringName] = []
	for f in def.get("flags", []):
		flags.append(f)
	q.reward_flags = flags
	_save(q, "%s/quests/%s.tres" % [DATA, def.id])


func _generate_quests() -> void:
	var T := QuestObjective.Type
	_quest({
		"id": &"q_first_steps", "title": "First Steps", "order": 0,
		"summary": "Mira wants to see you and {partner_name} handle yourselves. Visit the Training Grounds and win a battle.",
		"giver": &"mira", "turn_in": &"mira",
		"objectives": [
			_objective(T.REACH_AREA, &"training_grounds", 1, "Visit the Training Grounds (east, over the bridge)", &"training_grounds"),
			_objective(T.WIN_BATTLES, &"", 1, "Win a battle against a wild Digimon", &"training_grounds"),
		],
		"offer": &"mira_offer", "hint": &"mira_hint", "turn_in_dialogue": &"mira_turn_in",
		"exp": 100, "currency": 150,
		"items": {&"small_patch": 3, &"reboot_chip": 1, &"evo_shard": 1, &"friend_treat": 2, &"training_badge": 1, &"gate_pass": 1},
		"flags": [&"gateway_unlocked"],
	})
	_quest({
		"id": &"q_new_friend", "title": "A New Friend", "order": 1,
		"summary": "Befriend a wild Digimon so it joins your team.",
		"giver": &"mira", "turn_in": &"mira", "prereq": [&"q_first_steps"],
		"objectives": [
			_objective(T.RECRUIT_DIGIMON, &"", 1, "Befriend a wild Digimon (weaken it, then use Befriend)", &"wild_meadow"),
		],
		"offer": &"mira_friend_offer", "hint": &"mira_friend_hint", "turn_in_dialogue": &"mira_friend_done",
		"after": &"mira_default",
		"exp": 150, "currency": 100, "items": {&"medium_patch": 2, &"friend_treat": 3},
	})
	_quest({
		"id": &"q_scattered_data", "title": "Scattered Data", "order": 2,
		"summary": "Byte's archive was scattered by a data storm. Collect three glowing Data Fragments.",
		"giver": &"byte", "turn_in": &"byte",
		"objectives": [
			_objective(T.COLLECT_ITEM, &"data_fragment", 3, "Collect Data Fragments"),
		],
		"offer": &"byte_offer", "hint": &"byte_hint", "turn_in_dialogue": &"byte_turn_in", "after": &"byte_after",
		"exp": 120, "currency": 200, "items": {&"sp_capsule": 3, &"full_recovery_disk": 1, &"power_chip": 1},
	})
	_quest({
		"id": &"q_forest_survey", "title": "Forest Survey", "order": 3,
		"summary": "Lumi asked you to survey the Data Forest: see the Crystal Lake and the Old Ruins, and win three battles.",
		"giver": &"lumi", "turn_in": &"lumi", "prereq": [&"q_first_steps"],
		"objectives": [
			_objective(T.REACH_AREA, &"crystal_lake", 1, "Visit the Crystal Lake (north of camp)", &"crystal_lake"),
			_objective(T.REACH_AREA, &"old_ruins", 1, "Explore the Old Ruins (east)", &"old_ruins"),
			_objective(T.WIN_BATTLES, &"", 3, "Win battles against wild Digimon", &"old_ruins"),
		],
		"offer": &"lumi_offer", "hint": &"lumi_hint", "turn_in_dialogue": &"lumi_turn_in", "after": &"lumi_after",
		"exp": 260, "currency": 300, "items": {&"speed_chip": 1, &"evo_shard": 1, &"medium_patch": 2},
		"flags": [&"forest_surveyed"],
	})


# ---------------------------------------------------------------------------
# Encounters / maps / configs
# ---------------------------------------------------------------------------

func _spawn(species: StringName, min_level: int, max_level: int, weight: float) -> SpawnEntry:
	var e := SpawnEntry.new()
	e.species_id = species
	e.min_level = min_level
	e.max_level = max_level
	e.weight = weight
	return e


func _table(id: StringName, region: StringName, entries: Array, max_active: int, chance: float, interval: float, respawn: float) -> void:
	var t := EncounterTable.new()
	t.id = id
	t.region_id = region
	var typed: Array[SpawnEntry] = []
	for e in entries:
		typed.append(e)
	t.entries = typed
	t.max_active = max_active
	t.spawn_chance = chance
	t.check_interval = interval
	t.respawn_delay = respawn
	_save(t, "%s/encounters/%s.tres" % [DATA, id])


func _generate_encounters() -> void:
	_table(&"starter_meadow", &"wild_meadow", [
		_spawn(&"kunemon", 3, 5, 3.0),
		_spawn(&"goburimon", 3, 5, 3.0),
		_spawn(&"palmon", 4, 6, 2.0),
		_spawn(&"elecmon", 4, 6, 1.5),
		_spawn(&"biyomon", 4, 6, 1.5),
		_spawn(&"koromon", 3, 4, 0.6),
		_spawn(&"tsunomon", 3, 4, 0.6),
		_spawn(&"tokomon", 3, 4, 0.6),
	], 4, 0.7, 3.0, 8.0)
	_table(&"training_grounds", &"training_grounds", [
		_spawn(&"kunemon", 3, 4, 1.0),
		_spawn(&"goburimon", 3, 4, 1.0),
	], 2, 0.8, 2.5, 6.0)
	_table(&"forest_grove", &"forest_grove", [
		_spawn(&"palmon", 6, 8, 3.0),
		_spawn(&"elecmon", 6, 8, 2.5),
		_spawn(&"biyomon", 6, 8, 2.5),
		_spawn(&"kunemon", 6, 7, 2.0),
		_spawn(&"goburimon", 6, 7, 1.5),
		_spawn(&"togemon", 9, 10, 0.3),
	], 4, 0.7, 3.0, 8.0)
	_table(&"old_ruins", &"old_ruins", [
		_spawn(&"elecmon", 8, 10, 2.0),
		_spawn(&"goburimon", 8, 10, 2.0),
		_spawn(&"flymon", 9, 10, 0.5),
		_spawn(&"ogremon", 10, 11, 0.5),
		_spawn(&"leomon", 10, 11, 0.3),
	], 3, 0.7, 3.0, 9.0)


func _generate_maps() -> void:
	var m := MapData.new()
	m.id = &"starter_zone"
	m.display_name = "Starter Zone"
	m.scene_path = "res://maps/starter_zone/starter_zone.tscn"
	m.default_spawn_id = &"start"
	m.music_id = &"field"
	m.description = "A peaceful corner of the Digital World where new Tamers arrive."
	_save(m, "%s/maps/starter_zone.tres" % DATA)

	var forest := MapData.new()
	forest.id = &"data_forest"
	forest.display_name = "Data Forest"
	forest.scene_path = "res://maps/data_forest/data_forest.tscn"
	forest.default_spawn_id = &"from_starter_zone"
	forest.music_id = &"forest"
	forest.battle_arena = &"forest"
	forest.description = "A glowing forest of crystal trees beyond the Gateway, home to stronger wild Digimon."
	_save(forest, "%s/maps/data_forest.tres" % DATA)


func _generate_configs() -> void:
	var roster := StarterRoster.new()
	var ids: Array[StringName] = [&"agumon", &"gabumon", &"patamon"]
	roster.starter_ids = ids
	roster.starting_level = 5
	roster.taglines = {
		&"agumon": "Brave & fiery",
		&"gabumon": "Loyal & cool-headed",
		&"patamon": "Gentle & lucky",
	}
	roster.starting_items = {&"small_patch": 3, &"friend_treat": 1}
	roster.starting_currency = 100
	_save(roster, DATA + "/config/starter_roster.tres")

	_save(RecruitmentConfig.new(), DATA + "/config/recruitment_config.tres")

	var cat := CustomizationCatalog.new()
	var bodies: Array[Dictionary] = [
		{"id": &"male", "name": "Male", "shoulder": 1.0, "hip": 0.92, "torso": 1.0, "head": 1.0, "height": 1.0, "eyelashes": false},
		{"id": &"female", "name": "Female", "shoulder": 0.88, "hip": 1.0, "torso": 0.96, "head": 1.02, "height": 0.97, "eyelashes": true},
	]
	cat.body_types = bodies
	cat.hair_styles = _options([["spiky", "Spiky"], ["short", "Short Crop"], ["messy", "Messy"], ["bob", "Bob"],
		["long", "Long"], ["ponytail", "Ponytail"], ["twin_tails", "Twin Tails"]])
	var faces: Array[Dictionary] = [
		{"id": &"cheerful", "name": "Cheerful", "eyes": &"round", "mouth": &"smile", "brows": &"soft"},
		{"id": &"cool", "name": "Cool", "eyes": &"sharp", "mouth": &"smirk", "brows": &"angled"},
		{"id": &"sleepy", "name": "Sleepy", "eyes": &"sleepy", "mouth": &"small", "brows": &"soft"},
		{"id": &"bright", "name": "Bright", "eyes": &"sparkle", "mouth": &"open", "brows": &"raised"},
	]
	cat.faces = faces
	cat.tops = _options([["t_shirt", "T-Shirt"], ["jacket", "Jacket"], ["hoodie", "Hoodie"], ["adventure_shirt", "Adventure Shirt"]])
	cat.bottoms = _options([["shorts", "Shorts"], ["long_pants", "Long Pants"], ["adventure_pants", "Adventure Pants"]])
	cat.shoes = _options([["sneakers", "Sneakers"], ["boots", "Boots"]])
	cat.accessories = _options([["hat", "Cap"], ["glasses", "Glasses"], ["backpack", "Backpack"]])
	cat.hair_colors = _palette(["3b2a20", "6b4226", "8a4b2f", "f2cf73", "1f1d24", "c8412f", "ef8a3c", "f08cb4", "4b77d1", "2bb3a3", "c9ccd6", "8a5ad6"])
	cat.eye_colors = _palette(["6b4226", "3b6fd1", "3c9a5f", "d18a2a", "8a5ad6", "c8412f", "7d8796"])
	cat.skin_tones = _palette(["f9e0cc", "f6d2b3", "e8b98f", "c99468", "a06d47", "7a4e32"])
	cat.clothing_colors = _palette(["ff7a45", "ffd166", "5ac86e", "34c3ff", "3a6ee8", "2f4a8a", "8a5ad6", "ff8fb1", "e04f5f", "f2f2f2", "3a3f4b", "8b5e3c", "c9b79c"])
	_save(cat, DATA + "/config/customization_catalog.tres")


# ---------------------------------------------------------------------------
# Shops
# ---------------------------------------------------------------------------

func _shop(id: StringName, name: String, greeting: String, stock: Array) -> void:
	var shop := ShopData.new()
	shop.id = id
	shop.display_name = name
	shop.greeting = greeting
	var typed: Array[StringName] = []
	for item_id in stock:
		typed.append(item_id)
	shop.stock = typed
	_save(shop, "%s/shops/%s.tres" % [DATA, id])


func _generate_shops() -> void:
	_shop(&"plaza_shop", "Pip's Patch Stand", "Everything a new Tamer needs!",
		[&"small_patch", &"sp_capsule", &"friend_treat", &"reboot_chip", &"guard_chip"])
	_shop(&"forest_shop", "Ranger Supplies", "Forest-grade gear for serious Tamers.",
		[&"medium_patch", &"sp_capsule", &"reboot_chip", &"full_recovery_disk", &"friend_treat",
		&"power_chip", &"guard_chip", &"speed_chip", &"focus_chip", &"vital_chip"])


func _options(pairs: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p in pairs:
		out.append({"id": StringName(p[0]), "name": p[1]})
	return out


func _palette(hexes: Array) -> PackedColorArray:
	var out := PackedColorArray()
	for h in hexes:
		out.append(Color.html(h))
	return out
