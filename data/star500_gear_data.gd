class_name Star500Gear
extends RefCounted
## The 500-star class sets of ดินแดนเทวาลัย (ชุดเทวาลัย<theme>): seven pieces a class,
## the class weapon, armour, helm, boots, ring, amulet and a pair of wings (the Dark
## Lord's and the Muay Thai fighter's: a cape, as their wing slot always is).
##
## A piece is { kind:"equip", slot, base, class:<class>, star500:1, level:600, rarity:4,
## sockets:3, plus:0, gems:[], set:"", stats, name, price } (wings add wing:<class> and
## base "wings"). Worn from ★500 (Game.equip_problem: Lv.100 + a star a level). It
## carries no star_tier / collection / set_gear / dragon key, so the 50-250 star sets,
## their bonuses, recipes and checks never count it; HeroStats.compute adds its own
## 2/4/6/7 piece bonus (apply_bonus). valid() is the save check (Game._valid_item;
## accounts.js validStar500Gear keeps the same fixed fields).
##
## Stats are fixed (no roll): every stat of a +0 piece is the best any other source
## gives in that slot at +0 (stats_for), times MARGIN: the weapon over the Dragon God
## weapon's top roll, the other five over the 250★ set piece (itself the best divine /
## mythic piece at +10 and 15% more), the wings over the Dragon God wings' top roll
## (and never under the Legendary Guild Wings: LEGEND_MARGIN). So at any equal + a
## ★500 piece beats every older piece in every stat. Up to +15 and gems like any piece.
##
## Two ways to get one: drop() (ดินแดนเทวาลัย, the region calls it per kill: rare,
## a boss far likelier, own class likelier) and craft() at the forge (the ผสมชุดเซต
## page): แก่นเทวาลัย (ItemData.JEWELS CORE, dropped by drop() too) and gold, a sure
## success.

const KEY := "star500"
const STARS := 500
## Gear above Lv.100 needs a star per level (Game.equip_problem): 100 + 500.
const LEVEL := 100 + STARS
const RARITY := 4
const SLOTS: Array[String] = ["weapon", "armor", "helm", "boots", "ring", "amulet", "wings"]
const TAG := "เทวาลัย"
const FIELD := "ดินแดนเทวาลัย"
## The tier's own colour in names and tiles (ItemData.color_of): celestial gold.
const COLOR := Color("ffe07a")
## Every stat over the best other piece of the slot at the same +.
const MARGIN := 1.3
## The wings never fall under the Legendary Guild Wings (LegendWings.STATS) by stat.
const LEGEND_MARGIN := 1.1
const PRICE := 1500000

## The set's theme per class (ชุดเทวาลัย<theme>) and its English name.
const THEMES := {"warrior": "สุริยราชันย์", "archer": "วายุสวรรค์", "lancer": "อสนีทิพย์", "mage": "จักรวาลทิพย์", "priest": "อรุณเทวะ",
	"summoner": "จันทราทิพย์", "defender": "ปราการสวรรค์", "assassin": "ราตรีทิพย์", "darklord": "ราชันสุริยคราส", "bard": "ทิพยคีตา", "muaythai": "เทพมวยสุราลัย"}
const ENGLISH := {"warrior": "Solar Sovereign", "archer": "Heaven's Gale", "lancer": "Celestial Thunder", "mage": "Celestial Cosmos", "priest": "Divine Dawn",
	"summoner": "Celestial Moon", "defender": "Heaven's Bastion", "assassin": "Celestial Night", "darklord": "Eclipse King", "bard": "Song of Heaven", "muaythai": "Heavenly Boxer"}
const PIECE_PREFIX := {"armor": "เกราะ", "helm": "มงกุฎ", "boots": "รองเท้า", "ring": "แหวน", "amulet": "สร้อย", "wings": "ปีก"}

## Worn pieces of the hero's own class: cumulative shares HeroStats.compute applies.
const BONUS := {
	2: {"hp": 0.08},
	4: {"atk": 0.08, "def": 0.08},
	6: {"atk": 0.06, "crit": 0.05, "crit_dmg": 0.2},
	7: {"atk": 0.05, "def": 0.05, "hp": 0.05, "lifesteal": 0.02},
}
const BONUS_TEXT := ["2 ชิ้น: HP สูงสุด +8%", "4 ชิ้น: พลังโจมตี +8% พลังป้องกัน +8% และออร่าเทวาลัยรอบตัว",
	"6 ชิ้น: พลังโจมตีอีก +6% คริติคอล +5% ดาเมจคริติคอล +20%", "7 ชิ้น (รวมปีก): พลังโจมตี/ป้องกัน/HP อีก +5% ดูดเลือด +2%"]
## Worn pieces from which the celestial aura shows (HeroVisual, Star500GearArt.aura).
const AURA_PIECES := 4

## Drops (drop()): a piece per kill, a stack of cores per kill, a boss's odds.
const PIECE_CHANCE := 0.002
const BOSS_PIECE_CHANCE := 0.1
const CORE_CHANCE := 0.01
const BOSS_CORE_CHANCE := 0.6
const BOSS_CORES := [1, 3]
## A boss's piece is for the hero's own class this often (a monster's: ItemData.drop_class).
const BOSS_OWN_CLASS := 0.5
## How often each slot drops, relative (the wings a little rarer).
const SLOT_WEIGHT := {"weapon": 1.0, "armor": 1.0, "helm": 1.0, "boots": 1.0, "ring": 1.0, "amulet": 1.0, "wings": 0.6}

## The forge (craft()): แก่นเทวาลัย a piece and gold, at CRAFT_CHANCE (the owner's 25%); a
## failed try uses up the cores and the gold, like the 250★ set's.
const CRAFT_CHANCE := 0.25
const CORE := "heaven_core"
const CRAFT_CORES := {"weapon": 30, "armor": 20, "helm": 20, "boots": 20, "ring": 15, "amulet": 15, "wings": 30}
const CRAFT_GOLD := 3000000

## The celestial colours every class shares (Star500GearArt adds the class accent).
const GOLD := Color("f6d36e")
const GOLD_LIGHT := Color("fff3c4")
const PEARL := Color("fffaf0")
const JADE := Color("3fd6a8")
const JADE_DEEP := Color("135a4c")

static var _stats_cache := {}


static func _class(cls: Variant) -> String:
	var id := String(cls)
	return id if THEMES.has(id) else "warrior"


static func is_item(item: Variant) -> bool:
	return item is Dictionary and int((item as Dictionary).get(KEY, 0)) > 0


static func is_wings(item: Variant) -> bool:
	return is_item(item) and String((item as Dictionary).get("slot", "")) == "wings"


static func is_weapon(item: Variant) -> bool:
	return is_item(item) and String((item as Dictionary).get("slot", "")) == "weapon"


static func item_class(item: Dictionary) -> String:
	return _class(item.get("class", "warrior"))


static func weapon_kind(cls: String) -> String:
	return SetGearData.weapon_kind(cls)


static func base_of(cls: String, slot: String) -> String:
	if slot == "weapon":
		return weapon_kind(cls)
	return slot


static func set_label(cls: String) -> String:
	return "ชุด" + TAG + String(THEMES.get(cls, THEMES.warrior))


static func item_name(cls: String, slot: String) -> String:
	var theme := TAG + String(THEMES.get(cls, THEMES.warrior))
	match slot:
		"weapon":
			return String(DivineGearData.PREFIXES.get(cls, "อาวุธ")) + theme
		"wings":
			if cls == "darklord":
				return "ผ้าคลุม" + theme
			if cls == "muaythai":
				return "ผ้าคลุมนักมวย" + theme
	return String(PIECE_PREFIX.get(slot, "")) + theme


## "heaven_sword_warrior", "heaven_armor_mage", "heaven_wings_bard": icon file and model id.
static func look_of(item: Dictionary) -> String:
	return look_id(item_class(item), String(item.get("slot", "weapon")))


static func look_id(cls: String, slot: String) -> String:
	return "heaven_%s_%s" % [weapon_kind(cls) if slot == "weapon" else slot, cls]


static func icon_ids() -> Array[String]:
	var out: Array[String] = []
	for cls in StarGearData.CLASSES:
		for slot in SLOTS:
			out.append(look_id(cls, slot))
	return out


# --- Stats ---------------------------------------------------------------------

## The best any other piece can be in [param slot] for the class at +0, per stat.
static func top_stats(cls: String, slot: String) -> Dictionary:
	var top := {}
	match slot:
		"weapon":
			var ranges := DragonGearData.weapon_ranges(cls)
			for key in ranges:
				top[key] = float(ranges[key][1])
			var set_weapon := SetGearData.stats_for(cls, slot)
			for key in set_weapon:
				top[key] = maxf(float(top.get(key, 0.0)), float(set_weapon[key]))
		"wings":
			var ranges := DragonGearData.wing_ranges(cls)
			for key in ranges:
				top[key] = float(ranges[key][1])
		_:
			var stats := SetGearData.stats_for(cls, slot)
			for key in stats:
				top[key] = float(stats[key])
	return top


## A +0 piece's stats: top_stats times MARGIN (the wings also LEGEND_MARGIN over the
## Legendary Guild Wings in each of their stats).
static func stats_for(cls: String, slot: String) -> Dictionary:
	var id := _class(cls)
	var key_id := id + "/" + slot
	if not _stats_cache.has(key_id):
		var stats := {}
		var top := top_stats(id, slot)
		for key in top:
			var value := float(top[key]) * MARGIN
			if slot == "wings" and LegendWings.STATS.has(key):
				value = maxf(value, float(LegendWings.STATS[key]) * LEGEND_MARGIN)
			stats[key] = ceilf(value * 1000.0 - 0.0001) / 1000.0 if key == "crit" else int(ceil(value - 0.0001))
		_stats_cache[key_id] = stats
	return (_stats_cache[key_id] as Dictionary).duplicate()


## One piece of [param cls]'s set ({} for an unknown class or slot).
static func item(cls: String, slot: String) -> Dictionary:
	if not THEMES.has(cls) or not SLOTS.has(slot):
		return {}
	var result := {
		"kind": "equip", "uid": ItemData.make_uid(), "slot": slot, "base": base_of(cls, slot) if slot != "wings" else "wings",
		"plus": 0, "sockets": ItemData.sockets_for(RARITY), "gems": [], "set": "",
		"name": item_name(cls, slot), "rarity": RARITY, "level": LEVEL, "class": cls, KEY: 1,
		"stats": stats_for(cls, slot), "price": PRICE,
	}
	if slot == "wings":
		result["wing"] = cls
	return result


static func _number(value: Variant, want: float) -> bool:
	return (value is int or value is float) and float(value) == want


## Whether a saved piece is a well-formed ★500 piece (Game._valid_item). A look sent
## over the network carries no stats (PlayerLook.WIRE_DROP): the fixed fields only.
## Stats must be the slot's own keys, none above what the table gives (a little room
## for a later retune: a stored piece keeps its numbers).
static func valid(item: Dictionary) -> bool:
	if not _number(item.get(KEY), 1.0) or item.get("kind") != "equip":
		return false
	var cls: Variant = item.get("class")
	if not cls is String or not THEMES.has(cls):
		return false
	for key in ["star_tier", "star_class", "collection", "set_gear", DragonGearData.KEY, "legend_week", "legend_guild"]:
		if item.has(key):
			return false
	if not _number(item.get("level"), float(LEVEL)) or not _number(item.get("rarity"), float(RARITY)):
		return false
	var slot := String(item.get("slot", ""))
	if not SLOTS.has(slot):
		return false
	if slot == "wings":
		if String(item.get("base", "")) != "wings" or item.get("wing") != cls:
			return false
	elif String(item.get("base", "")) != base_of(cls, slot):
		return false
	var plus: Variant = item.get("plus", 0)
	if not (plus is int or plus is float) or float(plus) < 0.0 or float(plus) > float(ItemData.MAX_PLUS):
		return false
	var stats: Variant = item.get("stats", {})
	if not stats is Dictionary:
		return false
	var table := stats_for(cls, slot)
	for key in stats:
		var value: Variant = stats[key]
		if not table.has(key) or not (value is int or value is float):
			return false
		if float(value) < 0.0 or float(value) > float(table[key]) * 1.5 + 0.0005:
			return false
	return true


# --- The set bonus -----------------------------------------------------------------

## Pieces of [param cls]'s ★500 set worn in [param equip].
static func worn_count(equip: Variant, cls: String) -> int:
	if not equip is Dictionary:
		return 0
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


## The bonus of the hero's own class's pieces in [param profile].
static func profile_bonus(profile: Dictionary) -> Dictionary:
	return bonus(worn_count(profile.get("equip", {}), String(profile.get("class", ""))))


## Adds the set bonus to what HeroStats.compute worked out (stats["star500"]: pieces worn).
static func apply_bonus(stats: Dictionary, profile: Dictionary) -> Dictionary:
	var count := worn_count(profile.get("equip", {}), String(profile.get("class", "")))
	stats["star500"] = count
	var shares := bonus(count)
	for key in shares:
		var share := float(shares[key])
		match String(key):
			"atk", "def":
				stats[key] = float(stats[key]) * (1.0 + share)
			"hp":
				stats["max_hp"] = int(float(stats.max_hp) * (1.0 + share))
			"crit":
				stats["crit"] = clampf(float(stats.crit) + share, 0.0, HeroStats.MAX_CRIT)
			_:
				stats[key] = float(stats.get(key, 0.0)) + share
	return stats


static func bonus_text() -> String:
	return " · ".join(BONUS_TEXT)


## Tooltip lines (ItemData.detail_lines).
static func detail_lines(item: Dictionary) -> Array[String]:
	var cls := item_class(item)
	var worn := 0
	if Game.has_profile and String(Game.profile.get("class", "")) == cls:
		worn = worn_count(Game.profile.get("equip", {}), cls)
	return [
		"%s (%s) · อุปกรณ์ %d ดาว · สวมใส่ได้ที่ ดาว %d" % [set_label(cls), String(ENGLISH.get(cls, "")), STARS, STARS],
		"ดรอปที่%s (บอสดรอปบ่อยกว่า) หรือผสมที่ช่างตีเหล็กด้วย%s · ตีบวกได้ถึง +%d" % [FIELD, String(ItemData.JEWELS[CORE].name) if ItemData.JEWELS.has(CORE) else "แก่นเทวาลัย", ItemData.MAX_PLUS],
		"โบนัสเซต (สวมอยู่ %d/%d): %s" % [worn, SLOTS.size(), bonus_text()],
	]


# --- Drops and the forge -------------------------------------------------------------

## What one kill in ดินแดนเทวาลัย gives of this set: {} (nothing, the usual), a piece
## (PIECE_CHANCE, a boss BOSS_PIECE_CHANCE; for [param cls] or, as every class drop,
## another class: ItemData.drop_class, a boss BOSS_OWN_CLASS own) or a stack of
## แก่นเทวาลัย (CORE_CHANCE one, a boss BOSS_CORE_CHANCE BOSS_CORES).
static func drop(rng: RandomNumberGenerator, cls: StringName, from_boss: bool) -> Dictionary:
	var own := _class(cls)
	if rng.randf() < (BOSS_PIECE_CHANCE if from_boss else PIECE_CHANCE):
		var for_class := own
		if from_boss:
			if rng.randf() >= BOSS_OWN_CLASS:
				for_class = _class(ItemData.drop_class(StringName(own), rng))
		else:
			for_class = _class(ItemData.drop_class(StringName(own), rng))
		return item(for_class, roll_slot(rng))
	if rng.randf() < (BOSS_CORE_CHANCE if from_boss else CORE_CHANCE):
		return ItemData.jewel(CORE, rng.randi_range(int(BOSS_CORES[0]), int(BOSS_CORES[1])) if from_boss else 1)
	return {}


## A slot by SLOT_WEIGHT.
static func roll_slot(rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for slot in SLOTS:
		total += float(SLOT_WEIGHT[slot])
	var pick := rng.randf() * total
	for slot in SLOTS:
		pick -= float(SLOT_WEIGHT[slot])
		if pick < 0.0:
			return slot
	return SLOTS[SLOTS.size() - 1]


static func cost_text(slot: String) -> String:
	var core_name := String(ItemData.JEWELS[CORE].name) if ItemData.JEWELS.has(CORE) else "แก่นเทวาลัย"
	return "%s %d + เหรียญ %s" % [core_name, int(CRAFT_CORES.get(slot, 0)), _gold_text(CRAFT_GOLD)]


static func _gold_text(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out


## Why the hero cannot forge its class's [param slot] piece now ("" = it can).
static func craft_problem(slot: String) -> String:
	if not Game.has_profile:
		return "ยังไม่มีตัวละคร"
	if not SLOTS.has(slot):
		return "ไม่มีชิ้นนี้"
	var cls := String(Game.profile.get("class", ""))
	if not THEMES.has(cls):
		return "เลือกอาชีพก่อน"
	if Game.jewel_count(CORE) < int(CRAFT_CORES[slot]):
		return "%sไม่พอ (ต้องใช้ %d)" % [String(ItemData.JEWELS[CORE].name), int(CRAFT_CORES[slot])]
	if int(Game.profile.get("gold", 0)) < CRAFT_GOLD:
		return "เหรียญไม่พอ (ต้องใช้ %s)" % _gold_text(CRAFT_GOLD)
	return ""


## The bag's line for แก่นเทวาลัย ("" for anything else).
static func core_help(id: String) -> String:
	if id != CORE:
		return ""
	return "วัตถุดิบผสม%s (★%d) ที่ช่างตีเหล็ก ปุ่ม \"ผสมชุดเซต\" ในกระเป๋า: อาวุธ/ปีก %d แก่น · เสื้อ/หมวก/รองเท้า %d แก่น · แหวน/สร้อย %d แก่น + ทอง %s ต่อครั้ง โอกาสสำเร็จ %d%% (พลาดแล้วแก่นกับทองหาย) · ดรอปที่%s (มอนทั่วไป %d%% บอส %d%% ได้ %d-%d แก่น)" % ["ชุดเทวาลัย", STARS, int(CRAFT_CORES.weapon), int(CRAFT_CORES.armor), int(CRAFT_CORES.ring), PlayerStall.thousands(CRAFT_GOLD), int(CRAFT_CHANCE * 100.0), FIELD, int(CORE_CHANCE * 100.0), int(BOSS_CORE_CHANCE * 100.0), int(BOSS_CORES[0]), int(BOSS_CORES[1])]


## Forges one piece of the hero's class's set: CRAFT_CORES[slot] cores and CRAFT_GOLD,
## spent on every try; it succeeds at CRAFT_CHANCE. `roll` (0-1) replaces the random
## roll (tests); below 0 rolls Game.rng. Returns "ok", "fail" or why not (Thai).
static func craft(slot: String, roll := -1.0) -> String:
	var problem := craft_problem(slot)
	if problem != "":
		return problem
	var cls := String(Game.profile.get("class", ""))
	if not Game.spend_gold(CRAFT_GOLD):
		return "เหรียญไม่พอ"
	Game._spend_jewels(CORE, int(CRAFT_CORES[slot]))
	if roll < 0.0:
		roll = Game.rng.randf()
	if roll >= CRAFT_CHANCE:
		Game.inventory_changed.emit()
		Game.profile_changed.emit()
		Game.mark_dirty()
		return "fail"
	Game.give_or_store(item(cls, slot))
	Game.inventory_changed.emit()
	Game.profile_changed.emit()
	Game.mark_dirty()
	return "ok"


## Every piece (for icons, previews and tests).
static func catalogue() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for cls in StarGearData.CLASSES:
		for slot in SLOTS:
			out.append(item(cls, slot))
	return out
