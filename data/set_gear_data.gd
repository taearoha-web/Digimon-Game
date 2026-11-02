class_name SetGearData
extends RefCounted
## The 250-star class sets (ชุดเซต). They never drop: the blacksmith forges each
## piece from one set core (ItemData.JEWELS "set_core", the one material for every
## piece of every class) and jewels, at CRAFT_CHANCE (Game.craft_set_piece).
## Six pieces per class: the class weapon, armour, helm, boots, ring and amulet.
##
## Stats are fixed (no roll): every stat of a +0 piece is the best piece any other
## source can give in that slot at +10 (HeroStats.PLUS_BONUS, crit +4% a step),
## times MARGIN. The best pieces are the class's divine piece at its top roll
## (weapon, armour, helm, boots) and the mythic 200-star piece at its top roll
## (every slot), stat by stat (top_stats).
##
## A piece is { kind:"equip", slot, base, set_gear:<class>, class:<class>, level:350,
## rarity:4, sockets:3, plus, gems, stats, name, price, set:"" }: it carries no
## star_tier, so the 50-200 star collections, their set bonus and their checks
## never count it. Its 2/4/6 piece bonus is HeroStats.set_gear_bonus.

const STARS := 250
## Gear above Lv.100 needs a star per level (Game.equip_problem): 100 + 250.
const LEVEL := 100 + STARS
const SLOTS: Array[String] = ["weapon", "armor", "helm", "boots", "ring", "amulet"]
const RARITY := 4
## Every stat of a +0 set piece over the best other piece at +10.
const MARGIN := 1.15
## What one +1 adds at the forge (HeroStats.gear_bonus): +5% a step, crit +4%.
const PLUS_REF := 10
const CRAFT_COST := {"set_core": 1, "purple": 20, "pink": 20, "chaos": 20}
const CRAFT_CHANCE := 0.5
const CORE := "set_core"
const PRICE := 600000

const THEMES := {"warrior": "ราชันอัคนี", "archer": "พายุมรกต", "lancer": "มังกรอัสนี", "mage": "ดาราจักรอนันต์", "priest": "อรุณศักดิ์สิทธิ์",
	"summoner": "ภูตจันทร์เงา", "defender": "ปราการธารน้ำแข็ง", "assassin": "เงาโลหิต", "darklord": "จักรพรรดิอเวจี", "bard": "คีตาแสงเหนือ"}
const ENGLISH := {"warrior": "Flame Sovereign", "archer": "Emerald Gale", "lancer": "Thunder Dragon", "mage": "Infinite Galaxy", "priest": "Holy Dawn",
	"summoner": "Spectral Moon", "defender": "Glacier Bastion", "assassin": "Blood Shadow", "darklord": "Abyss Emperor", "bard": "Aurora Song"}
const PIECE_PREFIX := {"armor": "เกราะ", "helm": "มงกุฎ", "boots": "รองเท้า", "ring": "แหวน", "amulet": "สร้อย"}

## Worn pieces of one class's set: cumulative shares added by HeroStats.compute.
const BONUS := {2: {"hp": 0.06}, 4: {"atk": 0.06, "def": 0.06}, 6: {"atk": 0.06, "crit": 0.04, "crit_dmg": 0.15}}
const BONUS_TEXT := ["2 ชิ้น: HP สูงสุด +6%", "4 ชิ้น: พลังโจมตี +6% พลังป้องกัน +6%", "6 ชิ้น: พลังโจมตีอีก +6% คริติคอล +4% ดาเมจคริติคอล +15% และออร่าเซตรอบตัว"]
## Worn pieces from which the class aura shows (HeroVisual).
const AURA_PIECES := 4

## The look of each class's set (SetGearArt): metal, edge, cloth, gem, dark and
## the emissive glow of its trims, rune halos and aura.
const PALETTES := {
	"warrior": {"metal": Color("e8a23a"), "edge": Color("fff1d0"), "cloth": Color("9c1f1f"), "gem": Color("ff6a2a"), "dark": Color("3a1410"), "glow": Color("ff7a2e")},
	"archer": {"metal": Color("cfe8d8"), "edge": Color("f4fff6"), "cloth": Color("1f7a4d"), "gem": Color("5affb0"), "dark": Color("143a2a"), "glow": Color("6dffc4")},
	"lancer": {"metal": Color("8fa6c8"), "edge": Color("eef4ff"), "cloth": Color("1d3c8a"), "gem": Color("ffe34a"), "dark": Color("141c3a"), "glow": Color("ffe066")},
	"mage": {"metal": Color("c9b2ff"), "edge": Color("fbf4ff"), "cloth": Color("3b1f7a"), "gem": Color("ff7ae0"), "dark": Color("160f33"), "glow": Color("b98aff")},
	"priest": {"metal": Color("f2d27a"), "edge": Color("ffffff"), "cloth": Color("f4efe2"), "gem": Color("7ad9ff"), "dark": Color("8a7a5a"), "glow": Color("fff2a8")},
	"summoner": {"metal": Color("a9c6cc"), "edge": Color("eaffff"), "cloth": Color("1f5a63"), "gem": Color("7affff"), "dark": Color("102a30"), "glow": Color("6ef2ff")},
	"defender": {"metal": Color("d4ecff"), "edge": Color("ffffff"), "cloth": Color("3a78b8"), "gem": Color("a8f0ff"), "dark": Color("1c3350"), "glow": Color("9fe8ff")},
	"assassin": {"metal": Color("8c8c9c"), "edge": Color("ffd0d8"), "cloth": Color("1a1420"), "gem": Color("ff2a4a"), "dark": Color("0c0a10"), "glow": Color("ff3355")},
	"darklord": {"metal": Color("55506a"), "edge": Color("c8ffb0"), "cloth": Color("1e1030"), "gem": Color("7aff6a"), "dark": Color("0e0818"), "glow": Color("8aff5a")},
	"bard": {"metal": Color("f5b8d8"), "edge": Color("fff8ff"), "cloth": Color("b0307a"), "gem": Color("7affea"), "dark": Color("3a1a40"), "glow": Color("ff9ae8")},
}

static var _stats_cache := {}


static func is_item(value: Variant) -> bool:
	return value is Dictionary and (value as Dictionary).has("set_gear")


static func item_class(item: Dictionary) -> String:
	var cls := String(item.get("set_gear", item.get("class", "warrior")))
	return cls if THEMES.has(cls) else "warrior"


static func palette(cls: String) -> Dictionary:
	return PALETTES.get(cls, PALETTES.warrior)


static func weapon_kind(cls: String) -> String:
	return String(StarGearData.WEAPON_KIND.get(cls, "sword"))


static func set_id(cls: String) -> String:
	return "setgear_%s_%d" % [cls, STARS]


static func set_label(cls: String) -> String:
	return "ชุดเซต" + String(THEMES.get(cls, THEMES.warrior))


static func item_name(cls: String, slot: String) -> String:
	var prefix: String = DivineGearData.PREFIXES.get(cls, "อาวุธ") if slot == "weapon" else String(PIECE_PREFIX.get(slot, ""))
	return prefix + String(THEMES.get(cls, THEMES.warrior))


## "set_sword_warrior", "set_armor_mage", ...: icon file and model id (SetGearArt).
static func look_of(item: Dictionary) -> String:
	var cls := item_class(item)
	var slot := String(item.get("slot", "weapon"))
	return "set_%s_%s" % [weapon_kind(cls) if slot == "weapon" else slot, cls]


static func caster(cls: String) -> bool:
	return ClassData.CLASSES.has(StringName(cls)) and String(ClassData.get_class_data(StringName(cls)).main) == "int"


## Spell casters fight with magic attack: their attack is stored as matk (as on
## the divine pieces), which HeroStats adds to their attack like atk.
static func _normalized(stats: Dictionary, cls: String) -> Dictionary:
	var out := {}
	for key in stats:
		out[key] = float(stats[key])
	if caster(cls):
		var offence := float(out.get("atk", 0.0)) + float(out.get("matk", 0.0))
		out.erase("atk")
		if offence > 0.0:
			out["matk"] = offence
	else:
		out.erase("matk")
	return out


## The best any other piece can be in [param slot] for the class, per stat.
static func top_stats(cls: String, slot: String) -> Dictionary:
	var sources: Array[Dictionary] = [StarProgression.top_stats(slot)]
	if DivineGearData.SLOTS.has(slot):
		sources.append(DivineGearData.stats_for(StringName(cls), slot, StarProgression.ROLL_MAX))
	var top := {}
	for source in sources:
		var stats := _normalized(source, cls)
		for key in stats:
			top[key] = maxf(float(top.get(key, 0.0)), float(stats[key]))
	return top


## What the forge's +PLUS_REF makes of one stat (HeroStats.gear_bonus).
static func at_plus(key: String, value: float, plus := PLUS_REF) -> float:
	return value * (1.0 + 0.04 * plus if key == "crit" else 1.0 + HeroStats.PLUS_BONUS * plus)


## A +0 set piece's stats: every stat of top_stats at +10, times MARGIN.
static func stats_for(cls: String, slot: String) -> Dictionary:
	var key_id := cls + "/" + slot
	if not _stats_cache.has(key_id):
		var stats := {}
		var top := top_stats(cls, slot)
		for key in top:
			var value := at_plus(key, float(top[key])) * MARGIN
			stats[key] = ceilf(value * 1000.0) / 1000.0 if key == "crit" else int(ceil(value))
		_stats_cache[key_id] = stats
	return (_stats_cache[key_id] as Dictionary).duplicate()


static func item(cls: String, slot: String) -> Dictionary:
	if not THEMES.has(cls) or not SLOTS.has(slot):
		return {}
	var result := {
		"kind": "equip", "uid": ItemData.make_uid(), "slot": slot, "base": weapon_kind(cls) if slot == "weapon" else slot,
		"plus": 0, "sockets": ItemData.sockets_for(RARITY), "gems": [], "set": "",
		"name": item_name(cls, slot), "rarity": RARITY, "level": LEVEL, "class": cls, "set_gear": cls,
		"stats": stats_for(cls, slot), "price": PRICE,
	}
	return result


## Whether a saved piece is a well-formed set piece (Game._valid_item).
static func valid(item: Dictionary) -> bool:
	var cls: Variant = item.get("set_gear")
	if not cls is String or not THEMES.has(cls) or item.get("class") != cls:
		return false
	var slot := String(item.get("slot", ""))
	if not SLOTS.has(slot) or int(item.get("level", 0)) != LEVEL:
		return false
	return String(item.get("base", "")) == (weapon_kind(cls) if slot == "weapon" else slot)


## Pieces of [param cls]'s set worn in [param equip].
static func worn_count(equip: Dictionary, cls: String) -> int:
	var n := 0
	for slot in equip:
		var piece: Variant = equip[slot]
		if is_item(piece) and item_class(piece) == cls:
			n += 1
	return n


## The cumulative bonus shares for [param count] worn pieces.
static func bonus(count: int) -> Dictionary:
	var out := {}
	for need in BONUS:
		if count >= int(need):
			for key in BONUS[need]:
				out[key] = float(out.get(key, 0.0)) + float(BONUS[need][key])
	return out


static func bonus_text() -> String:
	return " · ".join(BONUS_TEXT)


static func cost_text() -> String:
	var parts: PackedStringArray = []
	for id in CRAFT_COST:
		parts.append("%s %d" % [ItemData.JEWELS[id].name, int(CRAFT_COST[id])])
	return " + ".join(parts)


## Every set piece (for icons, previews and tests).
static func catalogue() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for cls in StarGearData.CLASSES:
		for slot in SLOTS:
			out.append(item(cls, slot))
	return out
