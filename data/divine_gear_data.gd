class_name DivineGearData
extends RefCounted
## Uploaded class collections, earned only in Lotus Sanctum. Keep their identity
## separate from the crafted Eclipse sets so old equipment and investments survive.
const COLLECTION := "lotus_200"
const STARS := 200
const SLOTS: Array[String] = ["weapon", "armor", "helm", "boots"]
const THEMES := {"warrior":"พันดาบเทวะ", "archer":"พฤกษาเทพ", "lancer":"มังกรเทพเพลิง", "mage":"นภาจักรวาล", "priest":"เซราฟิม", "summoner":"ราชินีผีเสื้อ"}
const PREFIXES := {"warrior":"ดาบ", "archer":"ธนู", "lancer":"หอก", "mage":"คทา", "priest":"คทา", "summoner":"โคม"}

static func is_item(value: Variant) -> bool:
	return value is Dictionary and value.get("collection", "") == COLLECTION

static func set_id(cls: String) -> String:
	return "divine_%s_200" % cls

static func set_label(cls: String) -> String:
	return "ชุดเทพ" + String(THEMES.get(cls, ""))

static func item_name(cls: String, slot: String) -> String:
	var prefix: String = PREFIXES.get(cls, "อาวุธ") if slot == "weapon" else {"armor":"ชุด", "helm":"มงกุฎ", "boots":"รองเท้า"}.get(slot, "")
	return prefix + String(THEMES.get(cls, ""))

static func look_of(item: Dictionary) -> String:
	var cls := String(item.get("star_class", item.get("class", "warrior")))
	var slot := String(item.get("slot", "weapon"))
	var kind: String = StarGearData.WEAPON_KIND.get(cls, "sword") if slot == "weapon" else slot
	return "divine_%s_%s_200" % [kind, cls]

static func item(cls: StringName, slot: String, rng: RandomNumberGenerator) -> Dictionary:
	if not THEMES.has(String(cls)) or not SLOTS.has(slot): return {}
	var result := ItemData.generate(300, cls, rng, 4, slot)
	# Mythic base rolls plus a modest premium. Magic classes carry explicit magic
	# power, physical classes attack; both are understood by HeroStats.compute.
	var stats: Dictionary = result.stats
	for key in stats:
		stats[key] = snappedf(float(stats[key]) * 1.10, 0.001) if key == "crit" else int(ceil(float(stats[key]) * 1.10))
	if cls in [&"mage", &"priest", &"summoner"] and stats.has("atk"):
		stats["matk"] = stats.atk
		stats.erase("atk")
	if slot == "armor":
		match cls:
			&"warrior": stats.def += 100; stats.hp += 500
			&"lancer": stats["atk"] = int(stats.get("atk", 0)) + 100; stats.hp += 300
			&"archer": stats["atk"] = int(stats.get("atk", 0)) + 120; stats["crit"] = float(stats.get("crit", 0)) + 0.015
			&"mage": stats["matk"] = int(stats.get("matk", 0)) + 120; stats["mp"] = int(stats.get("mp", 0)) + 500
			&"priest": stats.hp += 650; stats["mp"] = int(stats.get("mp", 0)) + 500
			&"summoner": stats["matk"] = int(stats.get("matk", 0)) + 100; stats.hp += 400
	result.merge({"collection":COLLECTION, "star_tier":STARS, "star_class":String(cls), "class":String(cls),
		"star_set":set_id(String(cls)), "set":set_id(String(cls)), "name":item_name(String(cls), slot)}, true)
	result["look"] = look_of(result)
	return result

static func drop_chance(elite: bool) -> float:
	return 0.18 if elite else 0.035

## Bosses drop two different slots; ordinary enemies roll a single own-class
## piece. Keeping selection here makes the actual field loot reproducible in QA.
static func drops(cls: StringName, boss: bool, elite: bool, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not THEMES.has(String(cls)): return out
	if not boss and rng.randf() >= drop_chance(elite): return out
	var slots: Array[String] = SLOTS.duplicate()
	for i in (2 if boss else 1):
		var slot: String = slots.pop_at(rng.randi_range(0, slots.size() - 1))
		out.append(item(cls, slot, rng))
	return out
