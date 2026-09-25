class_name DigimonInstance
extends RefCounted
## A Digimon OWNED by the player (or a temporary wild one in battle).
##
## Holds only per-individual progress; everything shared comes from the
## [DigimonSpecies] resource looked up through GameData. Evolution simply
## changes [member species_id] while keeping level, EXP, skills and friendship.

const MAX_EQUIPPED_SKILLS := 4
const MAX_FRIENDSHIP := 100

var uid: String = ""
var species_id: StringName = &""
var nickname: String = ""
var level: int = 1
## EXP collected towards the next level.
var experience: int = 0
var current_hp: int = 1
var current_sp: int = 0
var known_skills: Array[StringName] = []
var equipped_skills: Array[StringName] = []
var friendship: int = 0
## Small per-individual stat variance so two Agumon are not identical.
var bonus_stats: Dictionary = {}
## Previous species ids, oldest first.
var evolution_history: Array[StringName] = []
var origin: StringName = &"wild"
var obtained_at: int = 0
var battles_won: int = 0

static var _uid_counter := 0


static func create(p_species_id: StringName, p_level: int, rng: RandomNumberGenerator = null) -> DigimonInstance:
	var inst := DigimonInstance.new()
	inst.uid = generate_uid()
	inst.species_id = p_species_id
	inst.level = clampi(p_level, 1, Leveling.MAX_LEVEL)
	inst.obtained_at = int(Time.get_unix_time_from_system())
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	for stat in DigimonStats.ALL:
		inst.bonus_stats[stat] = rng.randi_range(0, 2)
	var species := inst.get_species()
	if species:
		inst.known_skills = species.get_skills_up_to(inst.level)
		inst.auto_equip_skills()
	inst.full_restore()
	return inst


static func generate_uid() -> String:
	_uid_counter += 1
	return "%x%04x%04x" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec() % 0xFFFF, (_uid_counter * 7919 + randi()) % 0xFFFF]


func get_species() -> DigimonSpecies:
	return _registry().get_species(species_id) if _registry() else null


func get_display_name() -> String:
	if nickname != "":
		return nickname
	var species := get_species()
	return species.display_name if species else String(species_id)


## Final stat = base + growth * (level - 1) + individual bonus.
func get_stat(stat: StringName) -> int:
	var species := get_species()
	if species == null:
		return 1
	var value := species.get_base_stat(stat) + species.get_growth(stat) * float(level - 1)
	return maxi(1, int(round(value)) + int(bonus_stats.get(stat, 0)))


func get_all_stats() -> Dictionary:
	var result := {}
	for stat in DigimonStats.ALL:
		result[stat] = get_stat(stat)
	return result


func get_max_hp() -> int:
	return get_stat(DigimonStats.MAX_HP)


func get_max_sp() -> int:
	return get_stat(DigimonStats.MAX_SP)


func get_hp_ratio() -> float:
	return clampf(float(current_hp) / float(maxi(1, get_max_hp())), 0.0, 1.0)


func is_fainted() -> bool:
	return current_hp <= 0


## Returns the amount actually healed. Does nothing to fainted Digimon.
func heal(amount: int) -> int:
	if is_fainted() or amount <= 0:
		return 0
	var before := current_hp
	current_hp = mini(get_max_hp(), current_hp + amount)
	return current_hp - before


func restore_sp(amount: int) -> int:
	var before := current_sp
	current_sp = clampi(current_sp + amount, 0, get_max_sp())
	return current_sp - before


func take_damage(amount: int) -> int:
	var before := current_hp
	current_hp = maxi(0, current_hp - maxi(0, amount))
	return before - current_hp


func revive(percent: int) -> bool:
	if not is_fainted():
		return false
	current_hp = maxi(1, int(get_max_hp() * clampf(percent / 100.0, 0.0, 1.0)))
	return true


func full_restore() -> void:
	current_hp = get_max_hp()
	current_sp = get_max_sp()


## Keeps HP/SP within the (possibly changed) maximums.
func clamp_vitals() -> void:
	current_hp = clampi(current_hp, 0, get_max_hp())
	current_sp = clampi(current_sp, 0, get_max_sp())


func add_friendship(amount: int) -> void:
	friendship = clampi(friendship + amount, 0, MAX_FRIENDSHIP)


## Adds a skill to the known list and equips it if a slot is free.
## Returns true when the skill was new.
func learn_skill(skill_id: StringName) -> bool:
	if skill_id == &"" or known_skills.has(skill_id):
		return false
	known_skills.append(skill_id)
	if equipped_skills.size() < MAX_EQUIPPED_SKILLS:
		equipped_skills.append(skill_id)
	return true


func set_skill_equipped(skill_id: StringName, equipped: bool) -> bool:
	if equipped:
		if not known_skills.has(skill_id) or equipped_skills.has(skill_id):
			return false
		if equipped_skills.size() >= MAX_EQUIPPED_SKILLS:
			return false
		equipped_skills.append(skill_id)
		return true
	if equipped_skills.size() <= 1 or not equipped_skills.has(skill_id):
		return false # Always keep at least one skill.
	equipped_skills.erase(skill_id)
	return true


## Equips the most recent skills when fewer than the max are equipped.
func auto_equip_skills() -> void:
	var kept: Array[StringName] = []
	for skill_id in equipped_skills:
		if known_skills.has(skill_id) and not kept.has(skill_id):
			kept.append(skill_id)
	equipped_skills = kept
	var idx := known_skills.size() - 1
	while equipped_skills.size() < MAX_EQUIPPED_SKILLS and idx >= 0:
		var skill_id: StringName = known_skills[idx]
		if not equipped_skills.has(skill_id):
			equipped_skills.append(skill_id)
		idx -= 1
	# Keep the skill order stable (learn order).
	equipped_skills.sort_custom(func(a, b): return known_skills.find(a) < known_skills.find(b))


func to_dict() -> Dictionary:
	return {
		"uid": uid,
		"species_id": String(species_id),
		"nickname": nickname,
		"level": level,
		"experience": experience,
		"current_hp": current_hp,
		"current_sp": current_sp,
		"known_skills": _to_string_array(known_skills),
		"equipped_skills": _to_string_array(equipped_skills),
		"friendship": friendship,
		"bonus_stats": _stringify_keys(bonus_stats),
		"evolution_history": _to_string_array(evolution_history),
		"origin": String(origin),
		"obtained_at": obtained_at,
		"battles_won": battles_won,
	}


static func from_dict(data: Dictionary) -> DigimonInstance:
	var inst := DigimonInstance.new()
	inst.uid = str(data.get("uid", ""))
	if inst.uid == "":
		inst.uid = generate_uid()
	inst.species_id = StringName(str(data.get("species_id", "")))
	inst.nickname = str(data.get("nickname", ""))
	inst.level = clampi(int(data.get("level", 1)), 1, Leveling.MAX_LEVEL)
	inst.experience = maxi(0, int(data.get("experience", 0)))
	inst.friendship = clampi(int(data.get("friendship", 0)), 0, MAX_FRIENDSHIP)
	inst.origin = StringName(str(data.get("origin", "wild")))
	inst.obtained_at = int(data.get("obtained_at", 0))
	inst.battles_won = int(data.get("battles_won", 0))
	inst.known_skills = _to_stringname_array(data.get("known_skills", []))
	inst.equipped_skills = _to_stringname_array(data.get("equipped_skills", []))
	inst.evolution_history = _to_stringname_array(data.get("evolution_history", []))
	var bonus = data.get("bonus_stats", {})
	if bonus is Dictionary:
		for key in bonus.keys():
			inst.bonus_stats[StringName(str(key))] = int(bonus[key])
	inst.current_hp = int(data.get("current_hp", 1))
	inst.current_sp = int(data.get("current_sp", 0))
	if inst.get_species():
		if inst.known_skills.is_empty():
			inst.known_skills = inst.get_species().get_skills_up_to(inst.level)
		if inst.equipped_skills.is_empty():
			inst.auto_equip_skills()
		inst.clamp_vitals()
	return inst


func _registry() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("GameData")
	return null


static func _to_string_array(values: Array) -> Array:
	var out: Array = []
	for v in values:
		out.append(String(v))
	return out


static func _to_stringname_array(values) -> Array[StringName]:
	var out: Array[StringName] = []
	if values is Array:
		for v in values:
			out.append(StringName(str(v)))
	return out


static func _stringify_keys(dict: Dictionary) -> Dictionary:
	var out := {}
	for key in dict.keys():
		out[String(key)] = dict[key]
	return out
