class_name DragonGearData
extends RefCounted
## The Dragon God's gear, dropped only on เกาะลอยฟ้าเทพมังกร (SkyIsleLoot): one weapon a
## class (อาวุธเทพมังกร) and one pair of 300★ wings a class (ปีกเทพมังกร 300 ดาว).
## The function names and the "dragon" marker key are the contract (docs/SKY_ISLE_PLAN.md).
##
## The weapon: { kind:"equip", slot:"weapon", base:<class weapon kind>, class, level:400,
## rarity:4, sockets:3, plus:0, gems:[], set:"", stats, name, price, dragon:1 }. Worn from
## ★300 (Game.equip_problem: Lv.100 + a star a level). Every stat is the class's 250★ set
## weapon's (SetGearData.stats_for) times a roll of WEAPON_ROLL (+15% to +20%), so at any
## equal + it beats the set weapon in every stat, and it carries one fixed line of the
## Dragon God for its class (SIGNATURE, added by HeroStats.compute through
## apply_signature; never rolled, never raised by the forge). It counts as the weapon
## piece of its class's 250★ set (SetGearData.worn_count), so swapping it in keeps the
## 2/4/6 bonus and the set aura. It carries no set_gear / star_tier / collection key, so
## the forge recipes and the star collections never take it for one of theirs.
##
## The wings: { kind:"equip", slot:"wings", base:"wings", wing:<class>, class, level:400,
## rarity:4, sockets:3, ..., dragon:1 }. Every stat is the class's best 100★ pair (the
## mythic top roll of StarWingData.INFO) enhanced to +WING_REF_PLUS, times a roll of
## WING_ROLL (+4% to +8%): a +0 pair beats any 100★ pair at +7 in every stat, and stays
## under the Legendary Guild Wings (LegendWings.STATS: the best 100★ pair at +15 and a
## tenth more, any class, plus the party aura) at every equal +.
##
## Both drop at +0, go up to +15 and take gems like any weapon / wings, are never sold
## in bulk (Game.auto_sell_indices, pickup_sale) and are always picked up
## (Game.keeps_loot); they trade, go on a stall and into the storage as the 250★ set
## pieces do. valid() is the save check (Game._valid_item; accounts.js validDragonGear
## keeps the same fixed fields).

## item["dragon"]: 1 on every piece of this file.
const KEY := "dragon"
const WING_STARS := 300
const STARS := 300
## Gear above Lv.100 needs a star per level (Game.equip_problem): 100 + 300.
const LEVEL := 100 + STARS
const RARITY := 4
const TAG := "เทพมังกร"
## The tier's own colour in names and tiles (ItemData.color_of): dragon jade.
const COLOR := Color("4dffc3")
const FIELD := "เกาะลอยฟ้าเทพมังกร"
## A weapon stat over the 250★ set weapon's.
const WEAPON_ROLL := [1.15, 1.20]
## The 100★ pair's + a +0 pair must beat, and a wing stat over that.
const WING_REF_PLUS := 7
const WING_ROLL := [1.04, 1.08]
## The mythic 100★ pair's factor (StarWingData.item).
const STAR_WING_MYTHIC := 1.08
const WEAPON_PRICE := 900000
const WING_PRICE := 900000

## The class epithet in the names (the 250★ set's element).
const EPITHETS := {"warrior": "อัคนี", "archer": "วายุ", "lancer": "อัสนี", "mage": "ดารา", "priest": "อรุณ",
	"summoner": "จันทรา", "defender": "ธารน้ำแข็ง", "assassin": "โลหิต", "darklord": "อเวจี", "bard": "แสงเหนือ", "muaythai": "อัคนี"}
## The Dragon God's line of each class's weapon: shares HeroStats.compute adds.
const SIGNATURE := {
	"warrior": {"crit_dmg": 0.12}, "archer": {"crit": 0.05}, "lancer": {"atk": 0.04}, "mage": {"cdr": 0.06}, "priest": {"hp": 0.08},
	"summoner": {"cdr": 0.06}, "defender": {"def": 0.10}, "assassin": {"crit_dmg": 0.15}, "darklord": {"lifesteal": 0.02}, "bard": {"cdr": 0.06},
	"muaythai": {"hp": 0.06},
}
const SIGNATURE_LABELS := {"crit_dmg": "ดาเมจคริติคอล", "crit": "คริติคอล", "atk": "พลังโจมตี", "cdr": "ลดคูลดาวน์", "hp": "HP สูงสุด", "def": "พลังป้องกัน", "lifesteal": "ดูดเลือด"}
## The dragon's own colours, shared by every class (the class adds its set glow).
const JADE := Color("2fc79a")
const JADE_DEEP := Color("0e5a4c")
const JADE_LIGHT := Color("b9ffe6")
const GOLD := Color("f4c552")
const GOLD_LIGHT := Color("fff1b8")
const GLOW := Color("6dffd2")


static func _class(cls: Variant) -> String:
	var id := String(cls)
	return id if EPITHETS.has(id) else "warrior"


static func weapon_kind(cls: String) -> String:
	return SetGearData.weapon_kind(cls)


static func weapon_name(cls: String) -> String:
	return "%s%s%s" % [String(DivineGearData.PREFIXES.get(cls, "อาวุธ")), TAG, String(EPITHETS.get(cls, ""))]


## The Dark Lord wears a cape in the wing slot: the Dragon God's is an emperor's cape of
## dragon scales with a small pair of wings at the shoulders.
static func wing_name(cls: String) -> String:
	if cls == "darklord":
		return "ผ้าคลุมจักรพรรดิ%s%s" % [TAG, String(EPITHETS[cls])]
	return "ปีก%s%s" % [TAG, String(EPITHETS.get(cls, ""))]


## [low, high] of every stat a weapon of [param cls] can roll.
static func weapon_ranges(cls: String) -> Dictionary:
	var out := {}
	var base := SetGearData.stats_for(cls, "weapon")
	for key in base:
		out[key] = [_fix(key, float(base[key]) * float(WEAPON_ROLL[0])), _fix(key, float(base[key]) * float(WEAPON_ROLL[1]))]
	return out


## The best 100★ pair of [param cls] (mythic, top roll), per stat.
static func star_wing_top(cls: String) -> Dictionary:
	var out := {}
	var spans: Dictionary = StarWingData.INFO[_class(cls)].stats
	for key in spans:
		var top := float(spans[key][1]) * STAR_WING_MYTHIC
		out[key] = snappedf(top, 0.001) if key == "crit" else int(round(top))
	return out


## [low, high] of every stat a pair of [param cls] can roll.
static func wing_ranges(cls: String) -> Dictionary:
	var out := {}
	var top := star_wing_top(cls)
	for key in top:
		var ref := SetGearData.at_plus(key, float(top[key]), WING_REF_PLUS)
		out[key] = [_fix(key, ref * float(WING_ROLL[0])), _fix(key, ref * float(WING_ROLL[1]))]
	return out


## A stat as stored: whole numbers rounded up, crit to a thousandth (rounded up).
static func _fix(key: String, value: float) -> Variant:
	if key == "crit":
		return ceilf(value * 1000.0 - 0.0001) / 1000.0
	return int(ceil(value - 0.0001))


static func _roll(ranges: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var stats := {}
	for key in ranges:
		var low := float(ranges[key][0])
		var high := float(ranges[key][1])
		var value := rng.randf_range(low, high)
		if key == "crit":
			stats[key] = clampf(snappedf(value, 0.001), low, high)
		else:
			stats[key] = clampi(int(round(value)), int(low), int(high))
	return stats


## The Dragon God weapon of class [param cls].
static func weapon(cls: StringName, rng: RandomNumberGenerator) -> Dictionary:
	var id := _class(cls)
	return {
		"kind": "equip", "uid": ItemData.make_uid(), "slot": "weapon", "base": weapon_kind(id),
		"plus": 0, "sockets": ItemData.sockets_for(RARITY), "gems": [], "set": "",
		"name": weapon_name(id), "rarity": RARITY, "level": LEVEL, "class": id, KEY: 1,
		"stats": _roll(weapon_ranges(id), rng), "price": WEAPON_PRICE,
	}


## The 300★ Dragon God wings of class [param cls].
static func wings(cls: StringName, rng: RandomNumberGenerator) -> Dictionary:
	var id := _class(cls)
	return {
		"kind": "equip", "uid": ItemData.make_uid(), "slot": "wings", "base": "wings", "wing": id,
		"plus": 0, "sockets": ItemData.sockets_for(RARITY), "gems": [], "set": "",
		"name": wing_name(id), "rarity": RARITY, "level": LEVEL, "class": id, KEY: 1,
		"stats": _roll(wing_ranges(id), rng), "price": WING_PRICE,
	}


static func is_item(item: Variant) -> bool:
	return item is Dictionary and int((item as Dictionary).get(KEY, 0)) > 0


static func is_weapon(item: Variant) -> bool:
	return is_item(item) and String((item as Dictionary).get("slot", "")) == "weapon"


static func is_wings(item: Variant) -> bool:
	return is_item(item) and String((item as Dictionary).get("slot", "")) == "wings"


static func item_class(item: Dictionary) -> String:
	return _class(item.get("class", "warrior"))


## "dragon_sword_warrior" / "dragon_wings_mage": icon file and model id.
static func look_of(item: Dictionary) -> String:
	var cls := item_class(item)
	if String(item.get("slot", "")) == "wings":
		return "dragon_wings_%s" % cls
	return "dragon_%s_%s" % [weapon_kind(cls), cls]


static func icon_ids() -> Array[String]:
	var out: Array[String] = []
	for cls in StarGearData.CLASSES:
		out.append("dragon_%s_%s" % [weapon_kind(cls), cls])
	for cls in StarGearData.CLASSES:
		out.append("dragon_wings_%s" % cls)
	return out


## True when [param piece] stands in for the weapon of [param cls]'s 250★ set.
static func counts_for_set(piece: Variant, cls: String) -> bool:
	return is_weapon(piece) and String((piece as Dictionary).get("class", "")) == cls


## The Dragon God's line the hero's worn weapon gives ({} without one of its class).
static func signature(profile: Dictionary) -> Dictionary:
	var equip: Variant = profile.get("equip", {})
	var worn: Variant = (equip as Dictionary).get("weapon") if equip is Dictionary else null
	var cls := String(profile.get("class", ""))
	if not counts_for_set(worn, cls):
		return {}
	return SIGNATURE.get(cls, {})


## Adds the line to what HeroStats.compute worked out.
static func apply_signature(stats: Dictionary, profile: Dictionary) -> Dictionary:
	var line := signature(profile)
	for key in line:
		var share := float(line[key])
		match String(key):
			"atk", "def":
				stats[key] = float(stats[key]) * (1.0 + share)
			"hp":
				stats["max_hp"] = int(float(stats.max_hp) * (1.0 + share))
			"crit":
				stats["crit"] = clampf(float(stats.crit) + share, 0.0, HeroStats.MAX_CRIT)
			_:
				stats[key] = float(stats.get(key, 0.0)) + share
	stats["dragon_line"] = not line.is_empty()
	return stats


## "พลังเทพมังกร: ดาเมจคริติคอล +12%".
static func signature_text(cls: String) -> String:
	var parts: PackedStringArray = []
	var line: Dictionary = SIGNATURE.get(cls, {})
	for key in line:
		parts.append("%s +%s%%" % [String(SIGNATURE_LABELS.get(key, key)), String.num(float(line[key]) * 100.0, 1).trim_suffix(".0")])
	return "พลัง%s: %s" % [TAG, " ".join(parts)]


## Tooltip lines (ItemData.detail_lines).
static func detail_lines(item: Dictionary) -> Array[String]:
	var cls := item_class(item)
	if is_wings(item):
		return [
			"%s %d ดาว · ระดับ%s" % ["ผ้าคลุม" if cls == "darklord" else "ปีก", WING_STARS, TAG],
			"ดรอปเฉพาะที่%s · สวมใส่ได้ที่ ดาว %d" % [FIELD, STARS],
			"แรงกว่าปีก 100 ดาว +%d ทุกค่า · ตีบวกได้ถึง +%d" % [WING_REF_PLUS, ItemData.MAX_PLUS],
		]
	return [
		"อาวุธ%s · ดรอปเฉพาะที่%s · สวมใส่ได้ที่ ดาว %d" % [TAG, FIELD, STARS],
		signature_text(cls) + " (ติดตัวอาวุธ ไม่ต้องตีบวก)",
		"นับเป็นอาวุธของ%s: ใส่แทนแล้วโบนัสเซตไม่หาย" % SetGearData.set_label(cls),
		"โบนัสเซต: " + SetGearData.bonus_text(),
	]


static func _number(value: Variant, want: float) -> bool:
	return (value is int or value is float) and float(value) == want


## Whether a saved piece is a well-formed Dragon God piece (Game._valid_item). A look
## sent over the network carries no stats (PlayerLook.WIRE_DROP): the fixed fields only.
static func valid(item: Dictionary) -> bool:
	if not _number(item.get(KEY), 1.0):
		return false
	var cls: Variant = item.get("class")
	if not cls is String or not EPITHETS.has(cls):
		return false
	for key in ["star_tier", "star_class", "collection", "set_gear", "legend_week", "legend_guild"]:
		if item.has(key):
			return false
	if not _number(item.get("level"), float(LEVEL)) or not _number(item.get("rarity"), float(RARITY)):
		return false
	var ranges: Dictionary
	match String(item.get("slot", "")):
		"weapon":
			if String(item.get("base", "")) != weapon_kind(cls):
				return false
			ranges = weapon_ranges(cls)
		"wings":
			if String(item.get("base", "")) != "wings" or item.get("wing") != cls:
				return false
			ranges = wing_ranges(cls)
		_:
			return false
	var stats: Variant = item.get("stats", {})
	if not stats is Dictionary:
		return false
	if (stats as Dictionary).is_empty():
		return true
	if (stats as Dictionary).size() != ranges.size():
		return false
	for key in ranges:
		var value: Variant = stats.get(key)
		if not (value is int or value is float):
			return false
		if float(value) < float(ranges[key][0]) - 0.0005 or float(value) > float(ranges[key][1]) + 0.0005:
			return false
	return true


## One piece of each class and kind (for icons, previews and tests).
static func catalogue() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 300
	for cls in StarGearData.CLASSES:
		out.append(weapon(StringName(cls), rng))
	for cls in StarGearData.CLASSES:
		out.append(wings(StringName(cls), rng))
	return out
