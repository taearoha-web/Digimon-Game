class_name DivineGearData
extends RefCounted
## Uploaded class collections, earned only in Lotus Sanctum. Keep their identity
## separate from the crafted Eclipse sets so old equipment and investments survive.
const COLLECTION := "lotus_200"
const STARS := 200
const SLOTS: Array[String] = ["weapon", "armor", "helm", "boots"]
const PREMIUM := 1.4
## Mythic gear carries four bonus lines (spread over hp, mp, crit, atk, def).
const MYTHIC_LINES := 4.0
const THEMES := {"warrior":"พันดาบเทวะ", "archer":"พฤกษาเทพ", "lancer":"มังกรเทพเพลิง", "mage":"นภาจักรวาล", "priest":"เซราฟิม", "summoner":"ราชินีผีเสื้อ", "defender":"ดาราจักรนิรันดร์", "assassin":"ราตรีสุริยคราส", "darklord":"จักรพรรดิอีกาทมิฬ", "bard":"คีตาสวรรค์"}
const PREFIXES := {"warrior":"ดาบ", "archer":"ธนู", "lancer":"หอก", "mage":"คทา", "priest":"คทา", "summoner":"โคม", "defender":"โล่", "assassin":"มีดคู่", "darklord":"คทา", "bard":"พิณ"}

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
	# The strongest gear in the game: the same fixed-by-tier stats as the 200-star
	# set but at mythic grade with all four bonus lines, times PREMIUM. Every
	# stat, not just the main one, is far above the best 200-star roll.
	var stats: Dictionary = ItemData.tiered_stats(slot, ItemData.MAX_GEAR_LEVEL, 4, MYTHIC_LINES, StarProgression.roll_of(result))
	for key in stats:
		stats[key] = snappedf(float(stats[key]) * PREMIUM, 0.001) if key == "crit" else int(ceil(float(stats[key]) * PREMIUM))
	# And clearly above the best 200-star piece in every stat, whatever the roll.
	var top := StarProgression.top_stats(slot)
	for key in top:
		var floor_value := float(top[key]) * 1.1
		stats[key] = maxf(float(stats.get(key, 0)), snappedf(floor_value, 0.001)) if key == "crit" else maxi(int(stats.get(key, 0)), int(ceil(floor_value)))
	result["stats"] = stats
	# Never left to luck: the slot's main stat clears the best roll any other
	# piece can reach (mythic Lv.300 with every bonus line on it) by 15%.
	var main := "atk" if slot == "weapon" else "def"
	stats[main] = maxi(int(stats.get(main, 0)), int(ceil(best_other_roll(slot) * 1.15)))
	if cls in [&"mage", &"priest", &"summoner", &"bard"] and stats.has("atk"):
		stats["matk"] = stats.atk
		stats.erase("atk")
	if slot == "armor":
		match cls:
			&"warrior": stats.def += 200; stats.hp += 1000
			&"lancer": stats["atk"] = int(stats.get("atk", 0)) + 200; stats.hp += 600
			&"defender": stats.def += 80; stats.hp += 900
			&"assassin": stats["atk"] = int(stats.get("atk", 0)) + 220; stats["crit"] = float(stats.get("crit", 0)) + 0.04
			&"darklord": stats["atk"] = int(stats.get("atk", 0)) + 200; stats.hp += 700
			&"archer": stats["atk"] = int(stats.get("atk", 0)) + 240; stats["crit"] = float(stats.get("crit", 0)) + 0.03
			&"mage": stats["matk"] = int(stats.get("matk", 0)) + 240; stats["mp"] = int(stats.get("mp", 0)) + 1000
			&"priest": stats.hp += 1300; stats["mp"] = int(stats.get("mp", 0)) + 1000
			&"summoner": stats["matk"] = int(stats.get("matk", 0)) + 200; stats.hp += 800
			&"bard": stats["matk"] = int(stats.get("matk", 0)) + 200; stats.hp += 700
	result.merge({"collection":COLLECTION, "star_tier":STARS, "star_class":String(cls), "class":String(cls),
		"star_set":set_id(String(cls)), "set":set_id(String(cls)), "name":item_name(String(cls), slot)}, true)
	result["look"] = look_of(result)
	return result

## Rare by design: 0.5% from an ordinary enemy, 4% from an elite and a 30%
## chance of one piece from the guardian boss.
const DROP_NORMAL := 0.005
const DROP_ELITE := 0.04
const DROP_BOSS := 0.30

## The highest main stat (attack on a weapon, defence elsewhere) that any
## non-divine piece can roll: Lv.300 mythic, top random roll, all four bonus
## lines on that stat. Mirrors ItemData.generate.
static func best_other_roll(slot: String) -> float:
	var power := ItemData.gear_power(ItemData.MAX_GEAR_LEVEL)
	var level := float(ItemData.MAX_GEAR_LEVEL)
	match slot:
		"weapon": return power * ItemData.rarity_mult(4, 0.22) * 1.08 + 4.0 * (power * 0.12 + 1.0)
		"armor": return power * 0.75 * ItemData.rarity_mult(4, 0.2) * 1.08 + 4.0 * (power * 0.1 + 1.0)
		"helm": return power * 0.4 * ItemData.rarity_mult(4, 0.2) + 4.0 * (power * 0.1 + 1.0)
		"boots": return power * 0.3 * ItemData.rarity_mult(4, 0.2) + 4.0 * (power * 0.1 + 1.0)
	return 0.0

static func drop_chance(elite: bool, boss := false) -> float:
	return DROP_BOSS if boss else (DROP_ELITE if elite else DROP_NORMAL)

## One own-class piece in a random slot when the roll succeeds. Keeping the
## selection here makes the actual field loot reproducible in QA.
static func drops(cls: StringName, boss: bool, elite: bool, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not THEMES.has(String(cls)): return out
	if rng.randf() >= drop_chance(elite, boss): return out
	out.append(item(cls, SLOTS[rng.randi() % SLOTS.size()], rng))
	return out
