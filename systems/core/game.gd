extends Node
## Autoload "Game": the player's profile (class, level, items, quests), saving
## and loading, and every rule that changes it (EXP, equipment, potions, gold).
## The 3D hero node reads and writes current HP / MP here so they persist.

signal profile_changed()
signal inventory_changed()
signal gold_changed(gold: int)
signal exp_changed()
signal leveled_up(level: int)
signal toast(text: String, kind: StringName)
signal item_gained(item: Dictionary)
signal quest_changed()

const SAVE_PATH := "user://toon_tale_save.json"
const SAVE_VERSION := 1
const INVENTORY_SIZE := 30
const STAT_POINTS_PER_LEVEL := 3
const MAX_LEVEL := 50
const MAX_SKILL_RANK := 5

var profile: Dictionary = {}
var has_profile := false
var current_zone: StringName = &"town"
var rng := RandomNumberGenerator.new()
var _autosave_timer := 0.0
var _dirty := false


func _ready() -> void:
	rng.randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if not has_profile:
		return
	profile["play_time"] = float(profile.get("play_time", 0.0)) + delta
	_autosave_timer += delta
	if _autosave_timer > 30.0 and _dirty:
		save()


# ---------------------------------------------------------------------------
# Profile
# ---------------------------------------------------------------------------

func new_profile(class_id: StringName, hero_name: String) -> void:
	profile = {
		"version": SAVE_VERSION, "class": String(class_id), "name": hero_name.strip_edges(),
		"level": 1, "exp": 0, "points": 0, "skill_points": 1,
		"attrs": {"str": 0, "int": 0, "dex": 0, "vit": 0},
		"skills": {}, "gold": 150, "equip": {}, "inv": [],
		"hp": 1, "mp": 1, "zone": "town", "quests": {}, "kills": 0, "deaths": 0, "play_time": 0.0,
		"flags": {}, "boss_kills": {},
	}
	has_profile = true
	var starter := ItemData.generate(1, class_id, rng, 0, "weapon")
	starter["name"] = "%s ของมือใหม่" % ItemData.NAMES[starter.base][0]
	profile["equip"]["weapon"] = starter
	profile["inv"] = [ItemData.potion("hp_s", 5), ItemData.potion("mp_s", 3), ItemData.potion("town_scroll", 1)]
	var stats := stats_now()
	profile["hp"] = stats.max_hp
	profile["mp"] = stats.max_mp
	current_zone = &"town"
	save()
	profile_changed.emit()
	inventory_changed.emit()


func class_id() -> StringName:
	return StringName(profile.get("class", "warrior"))


func class_data() -> Dictionary:
	return JobData.resolve(class_id(), job_id())


func job_id() -> StringName:
	return StringName(profile.get("job", ""))


## Job change at the Job Master: needs the level, the fee and a class branch.
func change_job(job: StringName) -> bool:
	var info := JobData.get_job(job)
	if info.is_empty() or info["class"] != class_id() or job_id() != &"":
		return false
	if int(profile["level"]) < JobData.JOB_LEVEL or int(profile["gold"]) < JobData.JOB_COST:
		return false
	profile["gold"] -= JobData.JOB_COST
	profile["job"] = String(job)
	profile["skill_points"] += 2
	var stats := stats_now()
	profile["hp"] = stats.max_hp
	profile["mp"] = stats.max_mp
	gold_changed.emit(profile["gold"])
	profile_changed.emit()
	mark_dirty()
	return true


func stats_now(buffs := {}) -> Dictionary:
	return HeroStats.compute(profile, buffs)


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save() -> void:
	if not has_profile:
		return
	profile["zone"] = String(current_zone)
	var file := FileAccess.open(SAVE_PATH + ".tmp", FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(profile))
	file.close()
	var dir := DirAccess.open("user://")
	if dir:
		dir.rename(SAVE_PATH.get_file() + ".tmp", SAVE_PATH.get_file())
	_autosave_timer = 0.0
	_dirty = false


func load_game() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.has("class"):
		return false
	profile = _repair(parsed)
	has_profile = true
	current_zone = StringName(profile.get("zone", "town"))
	profile_changed.emit()
	inventory_changed.emit()
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	has_profile = false
	profile = {}


## JSON turns ints into floats: restore the types the game expects.
func _repair(data: Dictionary) -> Dictionary:
	for key in ["level", "exp", "points", "skill_points", "gold", "hp", "mp", "kills", "deaths"]:
		data[key] = int(data.get(key, 0))
	data["level"] = maxi(1, int(data["level"]))
	for key in ["attrs", "skills", "equip", "quests", "flags", "boss_kills"]:
		if not data.get(key) is Dictionary:
			data[key] = {}
	if not data.get("inv") is Array:
		data["inv"] = []
	for key in ["str", "int", "dex", "vit"]:
		data.attrs[key] = int(data.attrs.get(key, 0))
	for skill_id in data.skills.keys():
		data.skills[skill_id] = int(data.skills[skill_id])
	for item in data.inv:
		_repair_item(item)
	for slot in data.equip:
		_repair_item(data.equip[slot])
	return data


func _repair_item(item: Dictionary) -> void:
	for key in ["count", "rarity", "level", "price"]:
		if item.has(key):
			item[key] = int(item[key])
	for key in item.get("stats", {}):
		if key != "crit":
			item.stats[key] = int(item.stats[key])


func mark_dirty() -> void:
	_dirty = true


func say(text: String, kind: StringName = &"info") -> void:
	toast.emit(text, kind)


# ---------------------------------------------------------------------------
# EXP / level
# ---------------------------------------------------------------------------

func add_exp(amount: int) -> void:
	if profile["level"] >= MAX_LEVEL:
		return
	profile["exp"] += amount
	var gained := false
	while profile["level"] < MAX_LEVEL and profile["exp"] >= HeroStats.exp_to_next(profile["level"]):
		profile["exp"] -= HeroStats.exp_to_next(profile["level"])
		profile["level"] += 1
		profile["points"] += STAT_POINTS_PER_LEVEL
		profile["skill_points"] += 1
		gained = true
	exp_changed.emit()
	if gained:
		var stats := stats_now()
		profile["hp"] = stats.max_hp
		profile["mp"] = stats.max_mp
		leveled_up.emit(profile["level"])
		profile_changed.emit()
		save()
	mark_dirty()


func exp_ratio() -> float:
	return float(profile["exp"]) / float(HeroStats.exp_to_next(profile["level"]))


func spend_point(attr: String) -> bool:
	if profile["points"] <= 0 or not profile["attrs"].has(attr):
		return false
	profile["points"] -= 1
	profile["attrs"][attr] += 1
	profile_changed.emit()
	mark_dirty()
	return true


func skill_rank(skill_id: String) -> int:
	return int(profile["skills"].get(skill_id, 0))


func skill_unlocked(skill: Dictionary) -> bool:
	return profile["level"] >= int(skill.level)


## Skills start at rank 1 once their level is reached; ranks 2-5 cost a skill point.
func effective_rank(skill: Dictionary) -> int:
	return maxi(1, skill_rank(skill.id)) if skill_unlocked(skill) else 0


func upgrade_skill(skill: Dictionary) -> bool:
	if profile["skill_points"] <= 0 or not skill_unlocked(skill):
		return false
	var rank := effective_rank(skill)
	if rank >= MAX_SKILL_RANK:
		return false
	profile["skill_points"] -= 1
	profile["skills"][skill.id] = rank + 1
	profile_changed.emit()
	mark_dirty()
	return true


# ---------------------------------------------------------------------------
# Gold & inventory
# ---------------------------------------------------------------------------

func add_gold(amount: int) -> void:
	profile["gold"] = maxi(0, int(profile["gold"]) + amount)
	gold_changed.emit(profile["gold"])
	mark_dirty()


func spend_gold(amount: int) -> bool:
	if profile["gold"] < amount:
		return false
	add_gold(-amount)
	return true


func inventory_free() -> int:
	return INVENTORY_SIZE - profile["inv"].size()


## Adds an item (stacking potions). Returns false when the bag is full.
func add_item(item: Dictionary) -> bool:
	if ItemData.is_stackable(item):
		for existing in profile["inv"]:
			if existing.get("kind", "") == "potion" and existing.id == item.id:
				existing["count"] = int(existing["count"]) + int(item.get("count", 1))
				inventory_changed.emit()
				item_gained.emit(item)
				mark_dirty()
				return true
	if profile["inv"].size() >= INVENTORY_SIZE:
		return false
	profile["inv"].append(item)
	inventory_changed.emit()
	item_gained.emit(item)
	mark_dirty()
	return true


func remove_item_at(index: int, count := 1) -> void:
	if index < 0 or index >= profile["inv"].size():
		return
	var item: Dictionary = profile["inv"][index]
	if ItemData.is_stackable(item) and int(item.count) > count:
		item["count"] = int(item.count) - count
	else:
		profile["inv"].remove_at(index)
	inventory_changed.emit()
	mark_dirty()


func potion_count(id: String) -> int:
	for item in profile["inv"]:
		if item.get("kind", "") == "potion" and item.id == id:
			return int(item.count)
	return 0


func total_potions(kind: String) -> int:
	var total := 0
	for item in profile["inv"]:
		if item.get("kind", "") == "potion" and ItemData.POTIONS[item.id].has(kind):
			total += int(item.count)
	return total


## Uses the smallest potion that still helps: "hp" or "mp". Returns its id or "".
func quick_potion(kind: String) -> String:
	var stats := stats_now()
	var missing: int = (stats.max_hp - profile["hp"]) if kind == "hp" else (stats.max_mp - profile["mp"])
	if missing <= 0:
		return ""
	var best_index := -1
	var best_value := 0
	for i in profile["inv"].size():
		var item: Dictionary = profile["inv"][i]
		if item.get("kind", "") != "potion" or not ItemData.POTIONS[item.id].has(kind):
			continue
		var value: int = ItemData.POTIONS[item.id][kind]
		if best_index == -1 or (best_value < missing and value > best_value) or (value >= missing and value < best_value):
			best_index = i
			best_value = value
	if best_index == -1:
		return ""
	var id: String = profile["inv"][best_index].id
	use_potion_at(best_index)
	return id


func use_potion_at(index: int) -> String:
	var item: Dictionary = profile["inv"][index]
	if item.get("kind", "") != "potion":
		return ""
	var def: Dictionary = ItemData.POTIONS[item.id]
	var stats := stats_now()
	if def.has("hp"):
		profile["hp"] = mini(stats.max_hp, profile["hp"] + int(def.hp))
	if def.has("mp"):
		profile["mp"] = mini(stats.max_mp, profile["mp"] + int(def.mp))
	var id: String = item.id
	remove_item_at(index)
	profile_changed.emit()
	return id


# ---------------------------------------------------------------------------
# Equipment
# ---------------------------------------------------------------------------

## null-safe reason an item cannot be worn ("" = ok).
func equip_problem(item: Dictionary) -> String:
	if item.get("kind", "") != "equip":
		return "ใส่ไม่ได้"
	if int(item.level) > profile["level"]:
		return "ต้องเลเวล %d" % int(item.level)
	if item.get("class", "") != "" and item["class"] != profile["class"]:
		return "สำหรับอาชีพอื่น"
	return ""


func equip_from_bag(index: int) -> bool:
	var item: Dictionary = profile["inv"][index]
	var problem := equip_problem(item)
	if problem != "":
		say(problem, &"warning")
		return false
	var slot: String = item.slot
	var old: Variant = profile["equip"].get(slot)
	profile["equip"][slot] = item
	profile["inv"].remove_at(index)
	if old != null:
		profile["inv"].insert(index, old)
	clamp_vitals()
	inventory_changed.emit()
	profile_changed.emit()
	mark_dirty()
	return true


func unequip(slot: String) -> bool:
	if not profile["equip"].has(slot) or profile["inv"].size() >= INVENTORY_SIZE:
		return false
	profile["inv"].append(profile["equip"][slot])
	profile["equip"].erase(slot)
	clamp_vitals()
	inventory_changed.emit()
	profile_changed.emit()
	mark_dirty()
	return true


func clamp_vitals() -> void:
	var stats := stats_now()
	profile["hp"] = clampi(profile["hp"], 0, stats.max_hp)
	profile["mp"] = clampi(profile["mp"], 0, stats.max_mp)


func sell_item(index: int, count := 1) -> void:
	var item: Dictionary = profile["inv"][index]
	var each := ItemData.sell_price(item) if not ItemData.is_stackable(item) else int(ItemData.POTIONS[item.id].price * 0.4)
	var qty := count if ItemData.is_stackable(item) else 1
	add_gold(each * qty)
	remove_item_at(index, qty)


func buy_item(item: Dictionary) -> bool:
	var price := ItemData.buy_price(item) * (int(item.get("count", 1)) if ItemData.is_stackable(item) else 1)
	if profile["gold"] < price:
		say("เหรียญไม่พอ", &"warning")
		return false
	if not ItemData.is_stackable(item) and inventory_free() <= 0:
		say("กระเป๋าเต็ม", &"warning")
		return false
	spend_gold(price)
	add_item(item)
	return true


# ---------------------------------------------------------------------------
# Quests (see QuestData)
# ---------------------------------------------------------------------------

func quest_state(quest_id: String) -> Dictionary:
	return profile["quests"].get(quest_id, {})


func quest_status(quest_id: String) -> String:
	return String(quest_state(quest_id).get("status", "new"))


func set_quest(quest_id: String, status: String, progress := -1) -> void:
	var state: Dictionary = profile["quests"].get(quest_id, {"progress": 0})
	state["status"] = status
	if progress >= 0:
		state["progress"] = progress
	profile["quests"][quest_id] = state
	quest_changed.emit()
	mark_dirty()


## Counts a kill for every active quest hunting this monster.
func report_kill(monster_id: StringName, is_boss := false) -> void:
	profile["kills"] = int(profile["kills"]) + 1
	for quest_id in profile["quests"]:
		var state: Dictionary = profile["quests"][quest_id]
		if state.get("status", "") != "active":
			continue
		var quest := QuestData.get_quest(quest_id)
		if quest.is_empty() or StringName(quest.target) != monster_id:
			continue
		state["progress"] = mini(int(state.get("progress", 0)) + 1, int(quest.count))
		if int(state["progress"]) >= int(quest.count):
			state["status"] = "ready"
			say("เควสต์ \"%s\" เสร็จแล้ว! กลับไปรายงาน" % quest.name, &"quest")
		quest_changed.emit()
	if is_boss:
		profile["boss_kills"][String(monster_id)] = int(profile["boss_kills"].get(String(monster_id), 0)) + 1
	mark_dirty()
