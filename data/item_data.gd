class_name ItemData
extends RefCounted
## Items: randomly generated equipment (6 slots, 4 rarities) and potions.
## An item is a plain Dictionary so it saves to JSON as-is.
##
## Equipment: { kind:"equip", uid, slot, base, name, rarity, level, class, stats{atk,def,hp,mp,crit}, price }
## Potions:   { kind:"potion", id, count }

const SLOTS: Array[String] = ["weapon", "armor", "helm", "boots", "ring", "amulet"]
const SLOT_NAMES := {"weapon": "อาวุธ", "armor": "เกราะ", "helm": "หมวก", "boots": "รองเท้า", "ring": "แหวน", "amulet": "สร้อย", "wings": "ปีก"}
## Every equipment slot on the paper doll (wings only drop from the Lv.100 boss).
const EQUIP_SLOTS: Array[String] = ["weapon", "armor", "helm", "boots", "ring", "amulet", "wings"]

## Wings drop for the class being played: one model per class, a main stat
## that class fights with (rolled in a range) and one more bonus stat per rarity
## step (a common pair has the main stat only, a mythic pair has all four).
const WING_INFO := {
	"warrior": {"name": "ปีกใบมีด", "stat": "atk", "base": 210, "bonus": ["hp", "def", "crit", "mp"], "color": Color("c9d3e6")},
	"archer": {"name": "ปีกขนนกเอลฟ์", "stat": "atk", "base": 200, "bonus": ["crit", "hp", "mp", "def"], "color": Color("7fd66a")},
	"lancer": {"name": "ปีกมังกร", "stat": "atk", "base": 205, "bonus": ["crit", "hp", "def", "mp"], "color": Color("e0503a")},
	"mage": {"name": "ปีกอาร์เคน", "stat": "matk", "base": 215, "bonus": ["mp", "crit", "hp", "def"], "color": Color("9a6bff")},
	"summoner": {"name": "ปีกผีเสื้อวิญญาณ", "stat": "matk", "base": 205, "bonus": ["mp", "hp", "crit", "def"], "color": Color("5ad0e6")},
	"defender": {"name": "ปีกอีจิสเทพพิทักษ์", "stat": "atk", "base": 200, "bonus": ["def", "hp", "crit", "mp"], "color": Color("8fb8e0")},
	"assassin": {"name": "ปีกเงาราตรี", "stat": "atk", "base": 205, "bonus": ["crit", "hp", "def", "mp"], "color": Color("9a6bff")},
	# The Dark Lord wears a cape instead of wings: it floats the Lord like wings do.
	"darklord": {"name": "ผ้าคลุมราชันเหยี่ยว", "stat": "atk", "base": 205, "bonus": ["hp", "def", "crit", "mp"], "color": Color("b02a3a")},
	"priest": {"name": "ปีกนางฟ้า", "stat": "matk", "base": 195, "bonus": ["hp", "mp", "def", "crit"], "color": Color("f2d47a")},
}
## Bonus stat ranges a rarity step can add.
const WING_BONUS := {"hp": [300, 700], "mp": [150, 350], "crit": [0.02, 0.05], "def": [50, 120]}
## The priest's first wand names (old items are renamed to the modelled wands on load).
const LEGACY_WAND_NAMES := ["คทาไม้", "คทาเงิน", "คทาแสง", "คทาศักดิ์สิทธิ์", "คทาอรุณ", "คทามังกร", "คทาจันทราเงิน", "คทาเสราฟิม", "คทาเทวะ", "คทาเทพเจ้า"]
## Wing types from before class wings (old saves are converted on load).
const LEGACY_WING_KINDS: Array[String] = ["atk", "def", "hp", "matk"]
const WING_DROP_LEVEL := 100
## Legacy random drops remain capped at 20; authored star equipment reaches 200.
const MAX_GEAR_STAR := 200
const MAX_GEAR_LEVEL := 100 + MAX_GEAR_STAR
const RARITY_NAMES := ["ธรรมดา", "ดี", "หายาก", "ในตำนาน", "เทพนิยาย"]
const RARITY_COLORS := [Color("e6ecff"), Color("5ab8ff"), Color("ffc93c"), Color("c46bff"), Color("ff4a5e")]
const RARITY_ADJ := ["", "ชั้นดี", "ล้ำค่า", "แห่งตำนาน", "แห่งเทพนิยาย"]

## Names by base type, one per tier (a tier is 10 levels: Lv.1-10, 11-20 ... 91-100).
const NAMES := {
	"sword": ["ดาบอัศวิน", "ดาบเหล็กกล้า", "ดาบมิธริล", "ดาบราชวงศ์", "ดาบมังกรเพลิง", "ดาบน้ำแข็ง", "ดาบเงามืด", "ดาบศักดิ์สิทธิ์", "ดาบสายฟ้า", "ดาบเทพเจ้า"],
	"spear": ["หอกฝึกหัด", "หอกเหล็กกล้า", "หอกมิธริล", "หอกราชวงศ์", "หอกมังกรเพลิง", "หอกน้ำแข็ง", "หอกเงามืด", "หอกศักดิ์สิทธิ์", "หอกสายฟ้า", "หอกเทพเจ้า"],
	"dagger": ["มีดคู่ฝึกหัด", "มีดคู่เหล็กกล้า", "มีดคู่มิธริล", "มีดคู่ราชวงศ์", "มีดคู่เขี้ยวมังกรเพลิง", "มีดคู่น้ำแข็ง", "มีดคู่เงามืด", "มีดคู่ศักดิ์สิทธิ์", "มีดคู่สายฟ้า", "มีดคู่เทพเจ้า"],
	"scepter": ["คทาราชันฝึกหัด", "คทาราชันเหล็กกล้า", "คทาราชันมิธริล", "คทาราชันราชวงศ์", "คทาราชันมังกรเพลิง", "คทาราชันน้ำแข็ง", "คทาราชันเงามืด", "คทาราชันศักดิ์สิทธิ์", "คทาราชันสายฟ้า", "คทาจักรพรรดิเทพ"],
	"greatshield": ["โล่ปราการไม้เหล็ก", "โล่ป้อมปราการเหล็กกล้า", "โล่กำแพงมิธริลคมใบ", "โล่ปราการราชองครักษ์", "โล่ป้อมเกล็ดมังกรเพลิง", "โล่ป้อมธารน้ำแข็ง", "โล่ปราการเงาอเวจี", "โล่กำแพงตะวันศักดิ์สิทธิ์", "โล่ป้อมอัสนีบาต", "โล่อีจิสเทพพิทักษ์"],
	"bow": ["ธนูล่าสัตว์", "ธนูเหล็กกล้า", "ธนูมิธริล", "ธนูราชวงศ์", "ธนูมังกรเพลิง", "ธนูน้ำแข็ง", "ธนูเงามืด", "ธนูศักดิ์สิทธิ์", "ธนูสายฟ้า", "ธนูเทพเจ้า"],
	"wand": ["คทาสามเณร", "คทาเหล็กศรัทธา", "คทาจันทร์มิธริล", "คทาราชาผู้ทรงศีล", "คทาสุริยะเพลิง", "คทาเกล็ดหิมะ", "คทาสุริยุปราคา", "คทากางเขนเทวา", "คทาดาราสายฟ้า", "คทาบัวสวรรค์"],
	"lantern": ["โคมกระดาษวิญญาณ", "โคมเหล็กผูกวิญญาณ", "โคมผลึกมิธริล", "โคมเจดีย์ราชันย์", "โคมกรงเล็บมังกร", "โคมวิญญาณน้ำแข็ง", "โคมยมโลก", "โคมเทวาผู้นำทาง", "โคมพายุอสนี", "โคมดวงดาวสวรรค์"],
	"staff": ["คทาฝึกหัด", "คทาเหล็กกล้า", "คทามิธริล", "คทาราชวงศ์", "คทามังกรเพลิง", "คทาน้ำแข็ง", "คทาเงามืด", "คทาศักดิ์สิทธิ์", "คทาสายฟ้า", "คทาเทพเจ้า"],
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
	"hp_war": {"name": "ยาเลือดสงคราม", "desc": "ฟื้นฟู HP 5,000", "hp": 5000, "price": 1500, "color": Color("d8142f")},
	"hp_xxl": {"name": "ยาเลือดเทพ", "desc": "ฟื้นฟู HP 9,000", "hp": 9000, "price": 1800, "color": Color("a00828")},
	"hp_god": {"name": "ยาเลือดมหาเทพ", "desc": "ฟื้นฟู HP 20,000", "hp": 20000, "price": 4000, "color": Color("7a0a2a")},
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
const STAT_LABELS := {"atk": "พลังโจมตี", "def": "พลังป้องกัน", "hp": "HP", "mp": "MP", "crit": "คริติคอล", "matk": "พลังโจมตีเวทย์"}
const SET_NAMES := ["", "ชุดนักเดินทาง", "ชุดนักล่า", "ชุดอัศวิน", "ชุดเพลิงฟ้า", "ชุดมังกร", "ชุดอสูรสายฟ้า", "ชุดเทวทูต", "ชุดเทพสงคราม", "ชุดตำนานนิรันดร์"]
const SET_SLOTS := ["weapon", "armor", "helm", "boots"]
const MAX_PLUS := 10

static var _uid := 0


## "Lv.80", or "Lv.100 ดาว2" for gear above Lv.100 (worn with paragon levels).
static func level_text(level: int) -> String:
	if level <= 100:
		return "Lv.%d" % level
	return "Lv.100 ดาว%d" % (level - 100)


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
	return [0, 0, 1, 2, 3][clampi(rarity, 0, 4)]


static func set_id_for(slot: String, rarity: int, tier: int) -> String:
	return "set%d" % tier if (slot in SET_SLOTS and rarity >= 1 and tier >= 1) else ""


static func set_label(set_id: String) -> String:
	if set_id.begins_with("divine_"):
		return DivineGearData.set_label(set_id.get_slice("_", 1))
	if set_id.begins_with("star_"):
		var parts := set_id.split("_")
		return StarGearData.set_label(parts[1], int(parts[2])) if parts.size() == 3 else ""
	return SET_NAMES[clampi(int(set_id.trim_prefix("set")), 0, 9)] if set_id != "" else ""


## Chance (0-1) and gold cost of the next +1 at the forge.
static func enhance_chance(plus: int) -> float:
	return [1.0, 1.0, 1.0, 0.85, 0.8, 0.65, 0.6, 0.45, 0.4, 0.25][clampi(plus, 0, 9)]


static func enhance_cost(item: Dictionary) -> int:
	return int((int(item.get("price", 10)) * 0.4 + 40.0) * (1.0 + int(item.get("plus", 0)) * 0.7))


## Stat multiplier of a rarity; the mythic tier jumps well above legendary.
static func rarity_mult(rarity: int, per: float) -> float:
	return 1.0 + per * rarity + (per * 1.5 if rarity >= 4 else 0.0)


## Rolls rarity. [param boost] shifts odds towards better items (bosses).
static func roll_rarity(rng: RandomNumberGenerator, boost := 0.0) -> int:
	var r := rng.randf() - boost
	if r < 0.0008 - boost * 0.8:
		return 4
	if r < 0.012:
		return 3
	if r < 0.07:
		return 2
	if r < 0.30:
		return 1
	return 0


## Base stat power of gear. Up to Lv.100 it grows 2.2 per level; star gear
## (Lv.101-300, worn with ★) grows 0.9 per level so a 200-star piece is about
## 1.8x a Lv.100 one, not 3x: damage numbers stay readable at the top.
static func gear_power(level: int) -> float:
	if level <= 100:
		return 4.0 + float(level) * 2.2
	return 224.0 + float(level - 100) * 0.9

## The slot's own stats before any bonus line. [param roll] only scales the
## attack of a weapon and the defence of an armour, as it always has.
static func main_stats(slot: String, level: int, rarity: int, roll := 1.0) -> Dictionary:
	var power := gear_power(level)
	var stats := {}
	match slot:
		"weapon":
			stats["atk"] = int(round(power * rarity_mult(rarity, 0.22) * roll))
		"armor":
			stats["def"] = int(round(power * 0.75 * rarity_mult(rarity, 0.2) * roll))
			stats["hp"] = int(round(level * 5.0 * rarity_mult(rarity, 0.2)))
		"helm":
			stats["def"] = int(round(power * 0.4 * rarity_mult(rarity, 0.2)))
			stats["hp"] = int(round(level * 3.0 * rarity_mult(rarity, 0.2)))
		"boots":
			stats["def"] = int(round(power * 0.3 * rarity_mult(rarity, 0.2)))
			stats["hp"] = int(round(level * 2.0 * rarity_mult(rarity, 0.2)))
		"ring":
			stats["atk"] = int(round(power * 0.3 * rarity_mult(rarity, 0.2)))
			stats["crit"] = snappedf(0.01 + level * 0.0004 * (1.0 + rarity * 0.3), 0.001)
		"amulet":
			stats["mp"] = int(round(level * 4.0 * rarity_mult(rarity, 0.2)))
			stats["hp"] = int(round(level * 4.0 * rarity_mult(rarity, 0.2)))
	return stats


## What one bonus line adds to [param key].
static func bonus_line(key: String, level: int) -> Variant:
	var power := gear_power(level)
	match key:
		"hp": return int(level * 4.0 + 6)
		"mp": return int(level * 2.0 + 4)
		"crit": return snappedf(0.006 + level * 0.0002, 0.001)
		"atk": return int(power * 0.12 + 1)
		_: return int(power * 0.1 + 1)


## Stats of a piece whose grade is fixed by its tier instead of by luck: the
## slot's own stats plus the bonus lines spread evenly over all five stats
## ([param lines] of them, the average a random piece would carry), then one
## shared [param roll] on everything. Every stat therefore grows with the
## level, so a piece of a higher tier is better in each stat as long as the
## roll spread (about 8%) is smaller than the gap between the tiers.
static func tiered_stats(slot: String, level: int, rarity: int, lines: float, roll: float) -> Dictionary:
	var stats := main_stats(slot, level, rarity)
	for key in ["hp", "mp", "crit", "atk", "def"]:
		var extra: float = float(bonus_line(key, level)) * lines / 5.0
		stats[key] = float(stats.get(key, 0)) + extra
	for key in stats:
		stats[key] = snappedf(float(stats[key]) * roll, 0.001) if key == "crit" else int(round(float(stats[key]) * roll))
	return stats


static func generate(level: int, class_id: StringName, rng: RandomNumberGenerator, rarity := -1, slot := "") -> Dictionary:
	level = clampi(level, 1, MAX_GEAR_LEVEL)
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
	var power := gear_power(level)
	var stats := main_stats(slot, level, rarity, rng.randf_range(0.92, 1.08) if slot in ["weapon", "armor"] else 1.0)
	var bonus_pool := ["hp", "mp", "crit", "atk", "def"]
	for i in rarity:
		var key: String = bonus_pool[rng.randi() % bonus_pool.size()]
		var total: Variant = stats.get(key, 0) + bonus_line(key, level)
		stats[key] = snappedf(float(total), 0.001) if key == "crit" else total
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


## A level-100 pair of class wings. The main stat rolls in a range; each rarity
## step adds one bonus stat (HP, MP, crit, def) from the class's pool.
static func wings(rng: RandomNumberGenerator, class_id := "", rarity := -1) -> Dictionary:
	if not WING_INFO.has(class_id):
		class_id = "warrior" if class_id != "" else WING_INFO.keys()[rng.randi() % WING_INFO.size()]
	var info: Dictionary = WING_INFO[class_id]
	if rarity < 0:
		var r := rng.randf()
		rarity = 4 if r < 0.03 else (3 if r < 0.12 else (2 if r < 0.30 else (1 if r < 0.60 else 0)))
	rarity = clampi(rarity, 0, 4)
	var roll := rng.randf_range(0.8, 1.2) * (1.0 + 0.04 * rarity)
	var stats := {}
	stats[info.stat] = int(round(float(info.base) * roll))
	var pool: Array = (info.bonus as Array).duplicate()
	for i in rarity:
		var key: String = pool.pop_at(rng.randi() % pool.size())
		var span: Array = WING_BONUS[key]
		stats[key] = snappedf(rng.randf_range(span[0], span[1]), 0.001) if key == "crit" else rng.randi_range(span[0], span[1])
	return {
		"kind": "equip", "uid": make_uid(), "slot": "wings", "base": "wings", "wing": class_id,
		"plus": 0, "sockets": sockets_for(rarity), "gems": [], "set": "",
		"name": ("%s %s" % [info.name, RARITY_ADJ[rarity]]).strip_edges(), "rarity": rarity, "level": WING_DROP_LEVEL,
		"class": class_id, "stats": stats, "price": int(20000.0 * roll * (1.0 + 0.5 * rarity)),
	}


## Old (pre-class) wings become the class wings of [param class_id] with a fresh
## roll at the same rarity; plus and gems carry over.
static func migrate_wings(item: Dictionary, class_id: String) -> void:
	if item.get("slot", "") != "wings" or WING_INFO.has(String(item.get("wing", ""))):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(item.get("uid", "")))
	var fresh := wings(rng, class_id, clampi(int(item.get("rarity", 2)), 0, 4))
	for key in ["wing", "class", "stats", "name", "price"]:
		item[key] = fresh[key]
	item["sockets"] = maxi(int(fresh.sockets), (item.get("gems", []) as Array).size())


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
	if stats.has("matk"): lines.append("พลังโจมตีเวทย์ +%d (ใช้กับสายเวทย์/นักบวช)" % int(stats.matk))
	if stats.has("mp"): lines.append("MP +%d" % int(stats.mp))
	if stats.has("crit"): lines.append("คริติคอล +%.1f%%" % (float(stats.crit) * HeroStats.GEAR_CRIT_SCALE * 100.0))
	return lines


## Stat lines of the whole item including +N and gems, and set / socket info.
static func detail_lines(item: Dictionary) -> Array[String]:
	var lines := stat_lines(item)
	if item.get("kind", "") != "equip":
		return lines
	if StarGearData.is_star(item):
		lines.append("อุปกรณ์แห่งดวงดาว %d" % int(item.star_tier))
		if DivineGearData.is_item(item):
			lines.append("ดรอปเฉพาะวิหารบัวดารา • เลเวล 100 และ 200 ดาว")
			if item.slot == "armor": lines.append("ชุดครบเสื้อ กางเกง และถุงมือ • ใช้ได้ทั้งตัวละครชายและหญิง")
		if String(item.get("set", "")).begins_with("star_") or DivineGearData.is_item(item): lines.append(StarProgression.set_bonus_text(String(item.star_class)))
	var plus := int(item.get("plus", 0))
	if plus > 0:
		var look_name: String = EnhanceFx.NAMES[EnhanceFx.grade(plus)]
		lines.append("ตีบวก +%d (ค่าพลังเพิ่ม %d%%) · เอฟเฟกต์: %s" % [plus, int(round(plus * HeroStats.PLUS_BONUS * 100.0)), look_name])
	var sockets := int(item.get("sockets", 0))
	var gems: Array = item.get("gems", [])
	for i in sockets:
		if i < gems.size():
			var info := gem_info({"id": gems[i]})
			lines.append("ใส่แล้ว %s: %s +%s" % [info.name, STAT_LABELS[info.stat], ("%.1f%%" % (float(info.value) * 100.0)) if info.stat == "crit" else str(info.value)])
		else:
			lines.append("ช่องอัญมณีว่าง")
	if str(item.get("set", "")) != "":
		lines.append("เซ็ต: %s (ใส่ 2/3/4 ชิ้นได้โบนัส)" % set_label(item.set))
	return lines
