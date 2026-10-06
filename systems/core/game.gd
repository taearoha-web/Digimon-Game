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
signal autosaved()
signal item_gained(item: Dictionary)
signal quest_changed()
signal party_changed()
signal party_leveled(index: int, level: int)
signal party_roster_changed()
signal achievement_unlocked(name: String)
signal ending_requested()
signal screen_flash(color: Color, strength: float)

const SAVE_PATH := "user://toon_tale_save.json"
const SAVE_VERSION := 1
const AUTOSAVE_INTERVAL := 10.0
const INVENTORY_SIZE := 30
const STAT_POINTS_PER_LEVEL := 3
const MAX_LEVEL := 50
const MAX_SKILL_RANK := 5
## Area skills (burst / blast) grow this much wider per extra star.
const RADIUS_PER_STAR := 0.08

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
	if _autosave_timer > AUTOSAVE_INTERVAL and _dirty:
		save()
		autosaved.emit()


func _notification(what: int) -> void:
	# Leaving the tab / app, or closing it, saves right away.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if has_profile:
			save()


# ---------------------------------------------------------------------------
# Profile
# ---------------------------------------------------------------------------

func new_profile(class_id: StringName, hero_name: String, look := {}) -> void:
	profile = {
		"version": SAVE_VERSION, "class": String(class_id), "name": hero_name.strip_edges(),
		"level": 1, "exp": 0, "points": 0, "skill_points": 1,
		"attrs": {"str": 0, "int": 0, "dex": 0, "vit": 0},
		"skills": {}, "loadout": ["", "", "", ""], "gold": 150, "equip": {}, "inv": [],
		"hp": 1, "mp": 1, "zone": "town", "quests": {}, "kills": 0, "deaths": 0, "play_time": 0.0,
		"flags": {}, "boss_kills": {},
	}
	if not look.is_empty():
		profile["look"] = FaceKit.repair(look)
	has_profile = true
	var starter := ItemData.generate(1, class_id, rng, 0, "weapon")
	starter["name"] = "%s ของมือใหม่" % ItemData.NAMES[starter.base][0]
	profile["equip"]["weapon"] = starter
	profile["inv"] = [ItemData.potion("hp_s", 5), ItemData.potion("mp_s", 3), ItemData.potion("town_scroll", 1)]
	fill_loadout()
	var stats := stats_now()
	profile["hp"] = stats.max_hp
	profile["mp"] = stats.max_mp
	current_zone = &"town"
	save()
	profile_changed.emit()
	inventory_changed.emit()


func class_id() -> StringName:
	return StringName(profile.get("class", "warrior"))


## The class with the skill bar loadout as [code]skills[/code] (always 4 entries, {} = empty slot).
func class_data() -> Dictionary:
	var data := JobData.resolve(class_id(), job_id(), bool(profile.get("job3", false))).duplicate()
	data["skills"] = loadout_skills()
	return data


## Every active skill of the class (the pool the bar is filled from).
func skill_pool() -> Array:
	return ClassData.pool(class_id())


func passive_pool() -> Array:
	return ClassData.PASSIVES.get(class_id(), [])


func loadout_skills() -> Array:
	var out: Array = []
	for id in loadout():
		out.append(ClassData.find_skill(class_id(), String(id)))
	return out


func loadout() -> Array:
	if not profile.get("loadout") is Array or (profile["loadout"] as Array).size() != ClassData.SLOTS:
		fill_loadout()
	return profile["loadout"]


## Keeps the bar valid and puts newly unlocked skills into empty slots.
func fill_loadout() -> void:
	profile["loadout"] = ClassData.default_loadout(class_id(), int(profile.get("level", 1)), profile.get("loadout", []), class_tier())


## Puts a skill on a bar slot; a skill already on the bar swaps places.
func equip_skill(skill_id: String, slot: int) -> bool:
	var skill := ClassData.find_skill(class_id(), skill_id)
	if skill.is_empty() or not skill_unlocked(skill) or slot < 0 or slot >= ClassData.SLOTS:
		return false
	var bar: Array = loadout()
	var from := bar.find(skill_id)
	if from >= 0:
		bar[from] = bar[slot]
	bar[slot] = skill_id
	profile_changed.emit()
	mark_dirty()
	return true


## Vagabond -> one of the four lines (Lv.10, free). Vagabond weapons turn into
## the new line's weapon type with the same level, rarity and enhancement.
func change_class(new_class: StringName) -> bool:
	if class_id() != ClassData.START or not ClassData.IDS.has(new_class) or int(profile["level"]) < ClassData.LINE_LEVEL:
		return false
	profile["class"] = String(new_class)
	var local := RandomNumberGenerator.new()
	local.randomize()
	for slot in profile["equip"]:
		_convert_weapon(profile["equip"][slot], new_class, local)
	for item in profile["inv"]:
		_convert_weapon(item, new_class, local)
	profile["loadout"] = ["", "", "", ""]
	fill_loadout()
	var stats := stats_now()
	profile["hp"] = stats.max_hp
	profile["mp"] = stats.max_mp
	if party().is_empty():
		ensure_party()
	profile_changed.emit()
	inventory_changed.emit()
	party_changed.emit()
	mark_dirty()
	check_achievements()
	save()
	return true


func _convert_weapon(item: Dictionary, new_class: StringName, rng: RandomNumberGenerator) -> void:
	if item.get("kind", "") != "equip" or item.get("class", "") != String(ClassData.START):
		return
	var fresh := ItemData.generate(int(item.level), new_class, rng, int(item.rarity), "weapon")
	item["class"] = String(new_class)
	item["base"] = fresh.base
	var starter := String(item.get("name", "")).ends_with("ของมือใหม่")
	item["name"] = ("%s ของมือใหม่" % ItemData.NAMES[fresh.base][0]) if starter else fresh.name


func job_id() -> StringName:
	return StringName(profile.get("job", ""))


## Third advancement (Lv.30, after a job).
func change_master() -> bool:
	if job_id() == &"" or bool(profile.get("job3", false)) or not JobData.MASTERS.has(job_id()):
		return false
	if int(profile["level"]) < JobData.MASTER_LEVEL or int(profile["gold"]) < JobData.MASTER_COST:
		return false
	profile["gold"] -= JobData.MASTER_COST
	profile["job3"] = true
	fill_loadout()
	profile["skill_points"] += 3
	var stats := stats_now()
	profile["hp"] = stats.max_hp
	profile["mp"] = stats.max_mp
	gold_changed.emit(profile["gold"])
	profile_changed.emit()
	check_achievements()
	mark_dirty()
	return true


## Job change at the Job Master: needs the level, the fee and a class branch.
func change_job(job: StringName) -> bool:
	var info := JobData.get_job(job)
	if info.is_empty() or info["class"] != class_id() or job_id() != &"":
		return false
	if int(profile["level"]) < JobData.JOB_LEVEL or int(profile["gold"]) < JobData.JOB_COST:
		return false
	profile["gold"] -= JobData.JOB_COST
	profile["job"] = String(job)
	fill_loadout()
	profile["skill_points"] += 2
	var stats := stats_now()
	profile["hp"] = stats.max_hp
	profile["mp"] = stats.max_mp
	gold_changed.emit(profile["gold"])
	profile_changed.emit()
	mark_dirty()
	check_achievements()
	return true


func stats_now(buffs := {}) -> Dictionary:
	return HeroStats.compute(profile, buffs)


## The whole save as one copyable text code (base64 of the JSON).
func export_code() -> String:
	if not has_profile:
		return ""
	profile["zone"] = String(current_zone)
	return Marshalls.utf8_to_base64(JSON.stringify(profile))


## Replaces the current profile with a pasted code. Returns false when invalid.
func import_code(code: String) -> bool:
	var text := Marshalls.base64_to_utf8(code.strip_edges())
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary or not parsed.has("class") or not parsed.has("level"):
		return false
	profile = _repair(parsed)
	has_profile = true
	clamp_vitals()
	profile_changed.emit()
	inventory_changed.emit()
	quest_changed.emit()
	party_changed.emit()
	save()
	return true


func save_code_roundtrip() -> bool:
	var before := JSON.stringify(profile)
	var code := export_code()
	if code == "" or not import_code(code):
		return false
	return JSON.stringify(profile).length() == before.length()


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
	if data.get("look") is Dictionary:
		data["look"] = FaceKit.repair(data["look"])
	for key in ["attrs", "skills", "equip", "quests", "flags", "boss_kills"]:
		if not data.get(key) is Dictionary:
			data[key] = {}
	if not data.get("inv") is Array:
		data["inv"] = []
	for key in ["str", "int", "dex", "vit"]:
		data.attrs[key] = int(data.attrs.get(key, 0))
	for skill_id in data.skills.keys():
		data.skills[skill_id] = int(data.skills[skill_id])
	if data.get("job", "") != "":
		data["job"] = String(JobData.migrate_job(StringName(data.get("class", "warrior")), StringName(data["job"])))
	_migrate_skills(data)
	for item in data.inv:
		_repair_item(item)
	for slot in data.equip:
		_repair_item(data.equip[slot])
	return data


## Saves from before the Priston Tale skill system: refund the skill points
## spent on the old skills and start with a fresh bar.
func _migrate_skills(data: Dictionary) -> void:
	var cls := StringName(data.get("class", "warrior"))
	var valid := {}
	for skill in ClassData.pool(cls):
		valid[skill.id] = true
	for skill in ClassData.PASSIVES.get(cls, []):
		valid[skill.id] = true
	for skill_id in data.skills.keys():
		if not valid.has(skill_id):
			data["skill_points"] = int(data["skill_points"]) + maxi(0, int(data.skills[skill_id]) - 1)
			data.skills.erase(skill_id)
	if not data.get("loadout") is Array:
		data["loadout"] = ["", "", "", ""]
	data["loadout"] = ClassData.default_loadout(cls, int(data["level"]), data["loadout"], ClassData.tier_of(cls, StringName(data.get("job", "")), bool(data.get("job3", false))))


func _repair_item(item: Dictionary) -> void:
	for key in ["count", "rarity", "level", "price", "plus", "sockets"]:
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
		fill_loadout()
		var stats := stats_now()
		profile["hp"] = stats.max_hp
		profile["mp"] = stats.max_mp
		leveled_up.emit(profile["level"])
		profile_changed.emit()
		check_achievements()
		if profile.has("party"):
			party_catch_up()
		save()
	mark_dirty()


# ---------------------------------------------------------------------------
# AI party: two companions that fight beside the hero and share EXP
# ---------------------------------------------------------------------------

const PARTY_NAMES := {&"warrior": ["บราโว่", "ทอม"], &"archer": ["ลูน่า", "ฟ้า"], &"mage": ["มิกะ", "เจน"], &"priest": ["นีน่า", "ใบบัว"]}
const PARTY_BLURBS := {
	&"warrior": "นักรบเกราะหนา ยืนหน้าคอยรับดาเมจ",
	&"archer": "นักธนู ยิงไกลและคริติคอลสูง",
	&"mage": "จอมเวท ตีหมู่แรง แต่เลือดน้อย",
	&"priest": "พรีสต์ ฮีลและเสริมพลังให้คุณ",
}
var _party_gear: Dictionary = {}


## One AI companion. New and old saves without a party get a default one
## (a priest, or a mage for a priest); older saves with two keep the first.
func ensure_party() -> void:
	var party: Variant = profile.get("party")
	if party is Array:
		if party.size() > 1:
			profile["party"] = party.slice(0, 1)
		for member in profile["party"]:
			member["level"] = maxi(1, int(member.get("level", 1)))
			member["exp"] = int(member.get("exp", 0))
		return
	recruit(&"mage" if class_id() == &"priest" else &"priest", false)


## Hire a companion of the given class (replaces the current one).
func recruit(c: StringName, announce := true) -> void:
	var names: Array = PARTY_NAMES[c]
	profile["party"] = [{"class": String(c), "name": names[randi() % names.size()], "level": maxi(1, int(profile["level"]) - 1), "exp": 0, "stance": "follow", "trait": ["brave", "careful"][randi() % 2]}]
	mark_dirty()
	party_changed.emit()
	if announce:
		party_roster_changed.emit()


const STANCES := ["follow", "aggressive", "guard"]
const STANCE_NAMES := {"follow": "ตามติด", "aggressive": "บุกลุย", "guard": "ป้องกัน"}
const TRAIT_NAMES := {"brave": "กล้าหาญ", "careful": "ระมัดระวัง"}


## Tap the party card: follow -> aggressive -> guard.
func cycle_stance() -> String:
	var list := party()
	if list.is_empty():
		return ""
	var member: Dictionary = list[0]
	var i := STANCES.find(String(member.get("stance", "follow")))
	member["stance"] = STANCES[(i + 1) % STANCES.size()]
	mark_dirty()
	party_changed.emit()
	return String(member.stance)


func dismiss_party() -> void:
	profile["party"] = []
	mark_dirty()
	party_changed.emit()
	party_roster_changed.emit()


func party() -> Array:
	ensure_party()
	return profile["party"]


## A fake profile so [HeroStats] can work out a companion's stats.
func party_profile(member: Dictionary) -> Dictionary:
	var job := ""
	if int(member.level) >= JobData.JOB_LEVEL:
		var branches := JobData.jobs_for(StringName(member["class"]))
		job = String(branches[hash(member.name) % branches.size()])
	return {"class": member["class"], "level": int(member.level), "attrs": {}, "equip": party_equip(member), "job": job, "job3": int(member.level) >= JobData.MASTER_LEVEL and job != ""}


## Gear that grows with the companion's level (same pieces until the next tier).
func party_equip(member: Dictionary) -> Dictionary:
	var tier := ItemData.tier_for(int(member.level))
	var key := "%s|%d|%d" % [member.name, tier, int(member.level) / 3]
	if _party_gear.has(key):
		return _party_gear[key]
	var local := RandomNumberGenerator.new()
	local.seed = hash(key)
	var gear := {}
	for slot in ["weapon", "armor", "helm"]:
		gear[slot] = ItemData.generate(maxi(1, int(member.level)), StringName(member["class"]), local, 1, slot)
	_party_gear[key] = gear
	return gear


## Every kill's EXP goes to the whole party too: they level up together.
func party_add_exp(amount: int) -> void:
	for i in party().size():
		var member: Dictionary = profile["party"][i]
		if int(member.level) >= MAX_LEVEL:
			continue
		member["exp"] = int(member.exp) + amount
		var gained := false
		while int(member.level) < MAX_LEVEL and int(member.exp) >= HeroStats.exp_to_next(int(member.level)):
			member["exp"] = int(member.exp) - HeroStats.exp_to_next(int(member.level))
			member["level"] = int(member.level) + 1
			gained = true
		if gained:
			party_leveled.emit(i, int(member.level))
	party_changed.emit()
	mark_dirty()


## Companions never fall far behind the hero's level.
func party_catch_up() -> void:
	for i in party().size():
		var member: Dictionary = profile["party"][i]
		var floor_level := maxi(1, int(profile["level"]) - 2)
		if int(member.level) < floor_level:
			member["level"] = floor_level
			member["exp"] = 0
			party_leveled.emit(i, floor_level)
	party_changed.emit()


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
	return profile["level"] >= int(skill.level) and class_tier() >= ClassData.skill_tier(skill)


## 0 Vagabond, 1 line, 2 advanced job (Lv.20), 3 master job (Lv.40).
func class_tier() -> int:
	return ClassData.tier_of(class_id(), job_id(), bool(profile.get("job3", false)))


## Why a skill cannot be used yet ("" when it can).
func skill_lock_reason(skill: Dictionary) -> String:
	if profile["level"] < int(skill.level):
		return "ปลดล็อกที่เลเวล %d" % int(skill.level)
	var need := ClassData.skill_tier(skill)
	if class_tier() < need:
		return "ต้องเปลี่ยนเป็น%s (Lv.%d)" % [ClassData.tier_name(need), ClassData.LINE_LEVEL if need == 1 else (JobData.JOB_LEVEL if need == 2 else JobData.MASTER_LEVEL)]
	return ""


## Skills start at rank 1 once their level is reached; ranks 2-5 cost a skill point.
func effective_rank(skill: Dictionary) -> int:
	return maxi(1, skill_rank(skill.id)) if skill_unlocked(skill) else 0


## Radius multiplier of an area skill at a star rank.
func radius_scale(rank: int) -> float:
	return 1.0 + RADIUS_PER_STAR * float(maxi(rank, 1) - 1)


## Gold the Skill Master charges to raise a skill from its current rank.
func skill_upgrade_cost(skill: Dictionary) -> int:
	return 60 * effective_rank(skill) * maxi(1, int(skill.level) / 5)


## Done at the Skill Master: costs one skill point and gold per rank.
func upgrade_skill(skill: Dictionary) -> bool:
	if profile["skill_points"] <= 0 or not skill_unlocked(skill):
		return false
	var rank := effective_rank(skill)
	if rank >= MAX_SKILL_RANK or int(profile["gold"]) < skill_upgrade_cost(skill):
		return false
	profile["gold"] -= skill_upgrade_cost(skill)
	gold_changed.emit(profile["gold"])
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
			if existing.get("kind", "") == item.get("kind", "") and existing.id == item.id:
				existing["count"] = int(existing["count"]) + int(item.get("count", 1))
				inventory_changed.emit()
				item_gained.emit(item)
				mark_dirty()
				return true
	if profile["inv"].size() >= INVENTORY_SIZE:
		return false
	profile["inv"].append(item)
	if item.get("kind", "") == "equip" and int(item.get("rarity", 0)) >= 3:
		flag_max("got_legend", 1)
		check_achievements()
	inventory_changed.emit()
	item_gained.emit(item)
	mark_dirty()
	return true


## One forge attempt (+1). Returns "ok", "fail" (gold spent, nothing else lost) or a reason.
func enhance_item(item: Dictionary) -> String:
	if item.get("kind", "") != "equip":
		return "ไอเทมนี้ตีบวกไม่ได้"
	var plus := int(item.get("plus", 0))
	if plus >= ItemData.MAX_PLUS:
		return "บวกสูงสุดแล้ว"
	var cost := ItemData.enhance_cost(item)
	if int(profile["gold"]) < cost:
		return "เหรียญไม่พอ (ต้องใช้ %d)" % cost
	add_gold(-cost)
	if rng.randf() < ItemData.enhance_chance(plus):
		item["plus"] = plus + 1
		item["price"] = int(int(item.price) * 1.12)
		flag_max("best_plus", plus + 1)
		check_achievements()
		clamp_vitals()
		inventory_changed.emit()
		profile_changed.emit()
		mark_dirty()
		return "ok"
	inventory_changed.emit()
	mark_dirty()
	return "fail"


## Puts the gem at bag index into the item's next free socket.
func socket_gem(item: Dictionary, gem_index: int) -> bool:
	if gem_index < 0 or gem_index >= profile["inv"].size():
		return false
	var gem: Dictionary = profile["inv"][gem_index]
	if gem.get("kind", "") != "gem" or item.get("kind", "") != "equip":
		return false
	if not item.has("gems"):
		item["gems"] = []
	if (item["gems"] as Array).size() >= int(item.get("sockets", 0)):
		return false
	(item["gems"] as Array).append(String(gem.id))
	flag_add("gems_set")
	remove_item_at(gem_index, 1)
	check_achievements()
	clamp_vitals()
	profile_changed.emit()
	inventory_changed.emit()
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
	var each := ItemData.unit_sell_price(item)
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
	if is_boss and monster_id == &"magma_dragon" and int(profile["flags"].get("ending_seen", 0)) == 0:
		profile["flags"]["ending_seen"] = 1
		get_tree().create_timer(2.5).timeout.connect(func(): ending_requested.emit())
	daily_progress("kills", 1)
	daily_progress("zone_kills", 1)
	if is_boss:
		daily_progress("boss", 1)
	check_achievements()
	mark_dirty()


# ---------------------------------------------------------------------------
# Daily quests and achievements (see GoalsData)
# ---------------------------------------------------------------------------

## Today's three daily quests, created the first time they are needed each day.
func daily() -> Dictionary:
	var today := GoalsData.today()
	var current: Variant = profile.get("daily")
	if current is Dictionary and current.get("date", "") == today and (current.get("quests", []) as Array).size() == 3:
		return current
	var quests: Array = []
	for template in GoalsData.pick_for_date(today):
		quests.append({"id": template.id, "progress": 0, "claimed": false})
	profile["daily"] = {"date": today, "quests": quests, "zone": String(current_zone)}
	return profile["daily"]


func daily_template(id: String) -> Dictionary:
	for template in GoalsData.DAILY_POOL:
		if template.id == id:
			return template
	return {}


func daily_target(entry: Dictionary) -> int:
	return GoalsData.target_for(daily_template(entry.id), int(profile["level"]))


func daily_progress(kind: String, amount: int) -> void:
	if not has_profile:
		return
	if kind == "zone_kills" and (current_zone == &"town" or current_zone == &"arena"):
		return
	for entry in daily().quests:
		var template := daily_template(entry.id)
		if template.get("kind", "") != kind or entry.claimed:
			continue
		var target := daily_target(entry)
		if int(entry.progress) < target:
			entry["progress"] = mini(int(entry.progress) + amount, target)
			if int(entry.progress) >= target:
				say("เควสต์รายวัน \"%s\" เสร็จแล้ว! รับรางวัลที่กระดานในหมู่บ้าน" % template.name, &"quest")


## Claims every finished daily quest; returns how many were paid out.
func daily_claim_all() -> int:
	var count := 0
	for entry in daily().quests:
		if entry.claimed or int(entry.progress) < daily_target(entry):
			continue
		entry["claimed"] = true
		var reward := GoalsData.reward_for(int(profile["level"]))
		add_exp(reward.exp)
		party_add_exp(reward.exp)
		add_gold(reward.gold)
		profile["flags"]["dailies"] = int(profile["flags"].get("dailies", 0)) + 1
		count += 1
	if count > 0:
		check_achievements()
		mark_dirty()
	return count


## Current value of an achievement's counter.
func achievement_value(key: String) -> int:
	match key:
		"kills": return int(profile["kills"])
		"level": return int(profile["level"])
		"job": return 1 if job_id() != &"" else 0
		"job3": return 1 if bool(profile.get("job3", false)) else 0
		"bosses":
			var n := 0
			for id in profile["boss_kills"]:
				n += int(profile["boss_kills"][id])
			return n
		"boss_types": return (profile["boss_kills"] as Dictionary).size()
		"gold": return int(profile["gold"])
		_: return int(profile["flags"].get(key, 0))


func check_achievements() -> void:
	if not has_profile:
		return
	if not profile.get("ach") is Dictionary:
		profile["ach"] = {}
	for ach in GoalsData.ACHIEVEMENTS:
		if profile["ach"].has(ach.id) or achievement_value(ach.check) < int(ach.goal):
			continue
		profile["ach"][ach.id] = true
		var reward: Dictionary = ach.reward
		if reward.has("gold"):
			add_gold(int(reward.gold))
		if reward.has("sp"):
			profile["skill_points"] += int(reward.sp)
		if reward.has("gem"):
			add_item(ItemData.gem(String(reward.gem[0]), int(reward.gem[1]) - 1, 1))
		profile_changed.emit()
		achievement_unlocked.emit(String(ach.name))
		say("ความสำเร็จ: %s — รับรางวัลแล้ว" % ach.name, &"success")
		mark_dirty()


func flag_add(key: String, amount := 1) -> void:
	profile["flags"][key] = int(profile["flags"].get(key, 0)) + amount


func flag_max(key: String, value: int) -> void:
	profile["flags"][key] = maxi(int(profile["flags"].get(key, 0)), value)
