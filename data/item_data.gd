class_name ItemData
extends RefCounted
## Items: randomly generated equipment (6 slots, 4 rarities) and potions.
## An item is a plain Dictionary so it saves to JSON as-is.
##
## Equipment: { kind:"equip", uid, slot, base, name, rarity, level, class, stats{atk,def,hp,mp,crit}, price }
## Potions:   { kind:"potion", id, count }

const SLOTS: Array[String] = ["weapon", "armor", "helm", "boots", "ring", "amulet"]
const SLOT_NAMES := {"weapon": "อาวุธ", "armor": "เกราะ", "helm": "หมวก", "boots": "รองเท้า", "ring": "แหวน", "amulet": "สร้อย"}
const RARITY_NAMES := ["ธรรมดา", "ดี", "หายาก", "ในตำนาน"]
const RARITY_COLORS := [Color("e6ecff"), Color("5ab8ff"), Color("ffc93c"), Color("c46bff")]
const RARITY_ADJ := ["", "ชั้นดี", "ล้ำค่า", "แห่งตำนาน"]

## Names by base type, one per tier (a tier is 10 levels: Lv.1-10, 11-20 ... 91-100).
const NAMES := {
	"sword": ["ดาบไม้ฝึก", "ดาบเหล็ก", "ดาบเหล็กกล้า", "ดาบอัศวิน", "ดาบเพลิง", "ดาบมังกร", "ดาบอสูรสายฟ้า", "ดาบทูตสวรรค์", "ดาบเทพสงคราม", "ดาบตำนานนิรันดร์"],
	"bow": ["ธนูไม้", "ธนูหนัง", "ธนูนักล่า", "ธนูราชวงศ์", "ธนูเพลิง", "ธนูมังกร", "ธนูสายฟ้าพิโรธ", "ธนูสายลมสวรรค์", "ธนูเทพสุริยะ", "ธนูตำนานนิรันดร์"],
	"staff": ["ไม้เท้าไม้", "ไม้เท้าหินเวท", "ไม้เท้าอัญมณี", "ไม้เท้าจอมขมังเวท", "ไม้เท้าเพลิงฟ้า", "ไม้เท้ามังกร", "ไม้เท้าอสูรจันทรา", "ไม้เท้าเทวทูต", "ไม้เท้ามหาเวท", "ไม้เท้าตำนานนิรันดร์"],
	"wand": ["คทาไม้", "คทาเงิน", "คทาแสง", "คทาศักดิ์สิทธิ์", "คทาอรุณ", "คทามังกร", "คทาจันทราเงิน", "คทาเสราฟิม", "คทาแห่งพระเจ้า", "คทาตำนานนิรันดร์"],
	"armor": ["เสื้อผ้าหนา", "เสื้อหนัง", "เสื้อเกราะโซ่", "เสื้อเกราะเหล็ก", "เสื้อเกราะอัศวิน", "เสื้อเกราะมังกร", "เสื้อเกราะอสูรสายฟ้า", "เสื้อเกราะทูตสวรรค์", "เสื้อเกราะเทพสงคราม", "เสื้อเกราะตำนานนิรันดร์"],
	"helm": ["หมวกผ้า", "หมวกหนัง", "หมวกเหล็ก", "หมวกอัศวิน", "หมวกเพลิง", "หมวกมังกร", "หมวกอสูรสายฟ้า", "มงกุฎทูตสวรรค์", "มงกุฎเทพสงคราม", "มงกุฎตำนานนิรันดร์"],
	"boots": ["รองเท้าผ้า", "รองเท้าหนัง", "รองเท้าเหล็ก", "รองเท้าลมพัด", "รองเท้าเพลิง", "รองเท้ามังกร", "รองเท้าสายฟ้า", "รองเท้าปีกทูตสวรรค์", "รองเท้าเทพสงคราม", "รองเท้าตำนานนิรันดร์"],
	"ring": ["แหวนทองแดง", "แหวนเงิน", "แหวนทอง", "แหวนทับทิม", "แหวนมรกต", "แหวนมังกร", "แหวนสายฟ้า", "แหวนทูตสวรรค์", "แหวนเทพสุริยะ", "แหวนตำนานนิรันดร์"],
	"amulet": ["สร้อยเชือก", "สร้อยเงิน", "สร้อยทอง", "สร้อยไข่มุก", "สร้อยอัญมณี", "สร้อยมังกร", "สร้อยสายฟ้า", "สร้อยเสราฟิม", "สร้อยเทพสงคราม", "สร้อยตำนานนิรันดร์"],
}

const POTIONS := {
	"hp_s": {"name": "ยาเลือดเล็ก", "desc": "ฟื้นฟู HP 120", "hp": 120, "price": 25, "color": Color("ff5a6e")},
	"hp_m": {"name": "ยาเลือดกลาง", "desc": "ฟื้นฟู HP 350", "hp": 350, "price": 70, "color": Color("ff3a5a")},
	"hp_l": {"name": "ยาเลือดใหญ่", "desc": "ฟื้นฟู HP 900", "hp": 900, "price": 180, "color": Color("e0203f")},
	"hp_xl": {"name": "ยาเลือดยักษ์", "desc": "ฟื้นฟู HP 3,000", "hp": 3000, "price": 600, "color": Color("c0102f")},
	"hp_xxl": {"name": "ยาเลือดเทพ", "desc": "ฟื้นฟู HP 9,000", "hp": 9000, "price": 1800, "color": Color("a00828")},
	"mp_xl": {"name": "ยามานายักษ์", "desc": "ฟื้นฟู MP 1,200", "mp": 1200, "price": 600, "color": Color("1038c0")},
	"mp_xxl": {"name": "ยามานาเทพ", "desc": "ฟื้นฟู MP 3,600", "mp": 3600, "price": 1800, "color": Color("0828a0")},
	"mp_s": {"name": "ยามานาเล็ก", "desc": "ฟื้นฟู MP 60", "mp": 60, "price": 25, "color": Color("5a9bff")},
	"mp_m": {"name": "ยามานากลาง", "desc": "ฟื้นฟู MP 180", "mp": 180, "price": 70, "color": Color("3a7bff")},
	"mp_l": {"name": "ยามานาใหญ่", "desc": "ฟื้นฟู MP 450", "mp": 450, "price": 180, "color": Color("2050e0")},
	"town_scroll": {"name": "ใบวาร์ปกลับเมือง", "desc": "วาร์ปกลับหมู่บ้านทันที", "town": true, "price": 120, "color": Color("c9ffb0")},
}

## Gems that go into equipment sockets. value = stat per gem size step.
const GEMS := {
	"ruby": {"name": "ทับทิม", "stat": "atk", "values": [4, 10, 22], "color": Color("ff4a5a")},
	"sapphire": {"name": "ไพลิน", "stat": "mp", "values": [12, 30, 65], "color": Color("4a9bff")},
	"emerald": {"name": "มรกต", "stat": "hp", "values": [25, 70, 150], "color": Color("4ae07a")},
	"topaz": {"name": "บุษราคัม", "stat": "crit", "values": [0.008, 0.018, 0.035], "color": Color("ffd23c")},
	"amethyst": {"name": "อเมทิสต์", "stat": "def", "values": [3, 8, 18], "color": Color("c46bff")},
}
const GEM_SIZES := ["เล็ก", "กลาง", "ใหญ่"]
const STAT_LABELS := {"atk": "พลังโจมตี", "def": "พลังป้องกัน", "hp": "HP", "mp": "MP", "crit": "คริติคอล"}
const SET_NAMES := ["", "ชุดนักเดินทาง", "ชุดนักล่า", "ชุดอัศวิน", "ชุดเพลิงฟ้า", "ชุดมังกร", "ชุดอสูรสายฟ้า", "ชุดเทวทูต", "ชุดเทพสงคราม", "ชุดตำนานนิรันดร์"]
const SET_SLOTS := ["weapon", "armor", "helm", "boots"]
const MAX_PLUS := 10

static var _uid := 0


static func tier_for(level: int) -> int:
	return clampi((level - 1) / 10, 0, 9)


static func base_for(slot: String, class_id: StringName) -> String:
	if slot == "weapon":
		return String(ClassData.get_class_data(class_id).weapon_kind)
	return slot


static func make_uid() -> String:
	_uid += 1
	return "%x%04x" % [int(Time.get_unix_time_from_system()), (_uid * 7919 + randi()) % 0xFFFF]


static func potion(id: String, count := 1) -> Dictionary:
	return {"kind": "potion", "id": id, "count": count}


static func is_stackable(item: Dictionary) -> bool:
	return item.get("kind", "") in ["potion", "gem"]


static func gem(gem_id: String, size: int, count := 1) -> Dictionary:
	return {"kind": "gem", "id": "%s_%d" % [gem_id, size], "count": count}


## {name, stat, value, color, size} of a gem item.
static func gem_info(item: Dictionary) -> Dictionary:
	var bits := String(item.id).split("_")
	var base: Dictionary = GEMS[bits[0]]
	var size := clampi(int(bits[1]), 0, 2)
	return {"name": "%s%s" % [base.name, GEM_SIZES[size]], "stat": base.stat, "value": base.values[size], "color": base.color, "size": size, "type": bits[0]}


static func sockets_for(rarity: int) -> int:
	return [0, 0, 1, 2][clampi(rarity, 0, 3)]


static func set_id_for(slot: String, rarity: int, tier: int) -> String:
	return "set%d" % tier if (slot in SET_SLOTS and rarity >= 1 and tier >= 1) else ""


static func set_label(set_id: String) -> String:
	return SET_NAMES[clampi(int(set_id.trim_prefix("set")), 0, 9)] if set_id != "" else ""


## Chance (0-1) and gold cost of the next +1 at the forge.
static func enhance_chance(plus: int) -> float:
	return [1.0, 1.0, 1.0, 0.85, 0.8, 0.65, 0.6, 0.45, 0.4, 0.25][clampi(plus, 0, 9)]


static func enhance_cost(item: Dictionary) -> int:
	return int((int(item.get("price", 10)) * 0.4 + 40.0) * (1.0 + int(item.get("plus", 0)) * 0.7))


## Rolls rarity. [param boost] shifts odds towards better items (bosses).
static func roll_rarity(rng: RandomNumberGenerator, boost := 0.0) -> int:
	var r := rng.randf() - boost
	if r < 0.012:
		return 3
	if r < 0.07:
		return 2
	if r < 0.30:
		return 1
	return 0


static func generate(level: int, class_id: StringName, rng: RandomNumberGenerator, rarity := -1, slot := "") -> Dictionary:
	level = maxi(1, level)
	if slot == "":
		var weights := [28.0, 26.0, 14.0, 14.0, 9.0, 9.0]
		var roll := rng.randf() * 100.0
		for i in SLOTS.size():
			roll -= weights[i]
			if roll <= 0.0:
				slot = SLOTS[i]
				break
		if slot == "":
			slot = "weapon"
	if rarity < 0:
		rarity = roll_rarity(rng)
	var base := base_for(slot, class_id)
	var tier := tier_for(level)
	var power := 4.0 + level * 2.2
	var stats := {}
	match slot:
		"weapon":
			stats["atk"] = int(round(power * (1.0 + 0.22 * rarity) * rng.randf_range(0.92, 1.08)))
		"armor":
			stats["def"] = int(round(power * 0.75 * (1.0 + 0.2 * rarity) * rng.randf_range(0.92, 1.08)))
			stats["hp"] = int(round(level * 5.0 * (1.0 + 0.2 * rarity)))
		"helm":
			stats["def"] = int(round(power * 0.4 * (1.0 + 0.2 * rarity)))
			stats["hp"] = int(round(level * 3.0 * (1.0 + 0.2 * rarity)))
		"boots":
			stats["def"] = int(round(power * 0.3 * (1.0 + 0.2 * rarity)))
			stats["hp"] = int(round(level * 2.0 * (1.0 + 0.2 * rarity)))
		"ring":
			stats["atk"] = int(round(power * 0.3 * (1.0 + 0.2 * rarity)))
			stats["crit"] = snappedf(0.01 + level * 0.0007 * (1.0 + rarity * 0.3), 0.001)
		"amulet":
			stats["mp"] = int(round(level * 4.0 * (1.0 + 0.2 * rarity)))
			stats["hp"] = int(round(level * 4.0 * (1.0 + 0.2 * rarity)))
	var bonus_pool := ["hp", "mp", "crit", "atk", "def"]
	for i in rarity:
		var key: String = bonus_pool[rng.randi() % bonus_pool.size()]
		match key:
			"hp": stats[key] = int(stats.get(key, 0)) + int(level * 4.0 + 6)
			"mp": stats[key] = int(stats.get(key, 0)) + int(level * 2.0 + 4)
			"crit": stats[key] = snappedf(float(stats.get(key, 0.0)) + 0.01 + level * 0.0004, 0.001)
			"atk": stats[key] = int(stats.get(key, 0)) + int(power * 0.12 + 1)
			"def": stats[key] = int(stats.get(key, 0)) + int(power * 0.1 + 1)
	var names: Array = NAMES[base]
	var base_name: String = names[tier]
	var adjective: String = RARITY_ADJ[rarity]
	return {
		"kind": "equip", "uid": make_uid(), "slot": slot, "base": base,
		"plus": 0, "sockets": sockets_for(rarity), "gems": [], "set": set_id_for(slot, rarity, tier),
		"name": (base_name + " " + adjective).strip_edges(), "rarity": rarity, "level": level,
		"class": String(class_id) if slot == "weapon" else "",
		"stats": stats, "price": int(power * 5.0 * (1.0 + rarity * 1.1)),
	}


static func name_of(item: Dictionary) -> String:
	if item.get("kind", "") == "potion":
		return POTIONS[item.id].name
	if item.get("kind", "") == "gem":
		return gem_info(item).name
	var plus := int(item.get("plus", 0))
	return ("+%d " % plus if plus > 0 else "") + str(item.get("name", "?"))


static func color_of(item: Dictionary) -> Color:
	if item.get("kind", "") == "potion":
		return POTIONS[item.id].color
	if item.get("kind", "") == "gem":
		return gem_info(item).color
	return RARITY_COLORS[int(item.get("rarity", 0))]


## Price of one unit (stackables) or the whole item.
static func unit_sell_price(item: Dictionary) -> int:
	if not is_stackable(item):
		return sell_price(item)
	var single := item.duplicate()
	single["count"] = 1
	return sell_price(single)


static func sell_price(item: Dictionary) -> int:
	if item.get("kind", "") == "gem":
		return 20 * int(pow(3.0, gem_info(item).size)) * int(item.get("count", 1))
	if item.get("kind", "") == "potion":
		return int(POTIONS[item.id].price * 0.4) * int(item.get("count", 1))
	return int(int(item.get("price", 1)) * (0.35 + 0.15 * int(item.get("plus", 0))))


static func buy_price(item: Dictionary) -> int:
	if item.get("kind", "") == "potion":
		return int(POTIONS[item.id].price)
	return int(int(item.get("price", 1)) * 1.2)


## Lines like "ATK +24" for tooltips.
static func stat_lines(item: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if item.get("kind", "") == "potion":
		lines.append(POTIONS[item.id].desc)
		return lines
	if item.get("kind", "") == "gem":
		var info := gem_info(item)
		lines.append("ใส่ช่องอัญมณี: %s +%s" % [STAT_LABELS[info.stat], ("%.1f%%" % (float(info.value) * 100.0)) if info.stat == "crit" else str(info.value)])
		return lines
	var stats: Dictionary = item.get("stats", {})
	if stats.has("atk"): lines.append("พลังโจมตี +%d" % int(stats.atk))
	if stats.has("def"): lines.append("พลังป้องกัน +%d" % int(stats.def))
	if stats.has("hp"): lines.append("HP +%d" % int(stats.hp))
	if stats.has("mp"): lines.append("MP +%d" % int(stats.mp))
	if stats.has("crit"): lines.append("คริติคอล +%.1f%%" % (float(stats.crit) * 100.0))
	return lines


## Stat lines of the whole item including +N and gems, and set / socket info.
static func detail_lines(item: Dictionary) -> Array[String]:
	var lines := stat_lines(item)
	if item.get("kind", "") != "equip":
		return lines
	var plus := int(item.get("plus", 0))
	if plus > 0:
		lines.append("ตีบวก +%d (ค่าพลังเพิ่ม %d%%)" % [plus, plus * 8])
	var sockets := int(item.get("sockets", 0))
	var gems: Array = item.get("gems", [])
	for i in sockets:
		if i < gems.size():
			var info := gem_info({"id": gems[i]})
			lines.append("◆ %s: %s +%s" % [info.name, STAT_LABELS[info.stat], ("%.1f%%" % (float(info.value) * 100.0)) if info.stat == "crit" else str(info.value)])
		else:
			lines.append("◇ ช่องอัญมณีว่าง")
	if str(item.get("set", "")) != "":
		lines.append("เซ็ต: %s (ใส่ 2/3/4 ชิ้นได้โบนัส)" % set_label(item.set))
	return lines
