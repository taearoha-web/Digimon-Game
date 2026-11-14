class_name SkyIsleLoot
extends RefCounted
## What a kill on เกาะลอยฟ้าเทพมังกร drops besides gold and Zone._drop_jewels: everything
## the two ★200-300 fields drop (EndgameFields) except their Lv.100 wings, plus the isle's
## own: the Dragon God weapon, the 300★ wings, costume fragments, the mount's egg and
## treasure chests. The jackpots are announced to the whole server (Announcer).
##
## The isle's three stackables (ItemData.JEWELS):
## - CHEST กล่องสมบัติเทพมังกร: opened from the bag (open_chest / open_chests), one prize a
##   chest by CHEST_TABLE (the odds are printed in the item's help, chest_help).
## - FRAGMENT ชิ้นส่วนชุดเทพมังกร: COSTUME_FRAGMENTS of them are exchanged for the costume
##   COSTUME (exchange_costume: RewardShop.buy, from the bag or the reward shop).
## - EGG ไข่มังกรฟ้าเทพ: the material of the mount MOUNT (MountData, the menu's mount tab).

## The owner's rates, a kill of any monster. Nothing changes these four: not the hero's
## fortune (Tourmaline gems), not the festival / weekend multipliers of WorldEvents (those
## only touch Zone.jewel_drops), not the monster's rank. Elites and the boss add the
## extras below on top; they never raise or lower these rolls.
const WEAPON_DROP := 0.005
const WING_DROP := 0.001
const FRAGMENT_DROP := 0.001
const EGG_DROP := 0.001
## ItemData.JEWELS ids of the isle's stackable drops.
const FRAGMENT := "dragon_fragment"
const EGG := "sky_dragon_egg"
const CHEST := "dragon_chest"
## The costume the fragments make (RewardShop.COSTUMES id) and how many it takes.
const COSTUME := "dragon_god"
const COSTUME_FRAGMENTS := 50
## The mount the eggs make (MountData.MOUNTS id).
const MOUNT := "sky_dragon"

## Treasure chests: the chance a kill of an ordinary monster / an elite drops one, and
## how many the boss always drops (fortune does not change these either).
const CHEST_NORMAL := 0.01
const CHEST_ELITE := 0.05
const CHEST_BOSS := 2
## The boss's extras on top of the owner's four rolls: fragments it always drops, and
## one more roll each for the weapon, the wings and the egg.
const BOSS_FRAGMENTS := 2
const BOSS_WEAPON_BONUS := 0.05
const BOSS_WING_BONUS := 0.01
const BOSS_EGG_BONUS := 0.02
## The rare dragon (rare_drops): chests and fragments it always drops (fragments
## RARE_FRAGMENTS_MIN..MAX), a set core, and its chances at the three big prizes.
const RARE_CHESTS := 3
const RARE_FRAGMENTS_MIN := 3
const RARE_FRAGMENTS_MAX := 5
const RARE_WEAPON := 0.30
const RARE_WING := 0.10
const RARE_EGG := 0.25
const RARE_GEMS := 3

## One prize a chest: [id, chance, text for the help]. The chances add up to 1.
const CHEST_TABLE := [
	["gold", 0.38, "เหรียญทอง 50,000-150,000"],
	["jewels", 0.25, "เพชรตีบวก (ม่วง 5 / ชมพู 3 / ชาออส 3)"],
	["gem", 0.12, "อัญมณี 1 เม็ด"],
	["potion", 0.10, "ยา HP 20,000 ×5"],
	["feather", 0.05, "ขนนก 1 ขน"],
	["fragment", 0.05, "ชิ้นส่วนชุดเทพมังกร 1 ชิ้น"],
	["core", 0.03, "แก่นเทพหลอมเซต 1 ชิ้น"],
	["egg", 0.01, "ไข่มังกรฟ้าเทพ 1 ฟอง"],
	["weapon", 0.007, "อาวุธเทพมังกร"],
	["wings", 0.003, "ปีกเทพมังกร 300 ดาว"],
]
const CHEST_GOLD_MIN := 50000
const CHEST_GOLD_MAX := 150000
## Chests one press of "เปิดทั้งหมด" opens at most.
const OPEN_ALL_MAX := 100


## Everything the two ★200-300 fields drop (EndgameFields.kill_drops) without the
## Lv.100 wings: divine pieces, 200★ jewellery, Lotus Scales, gems and potions.
static func poseidon_drops(cls: StringName, boss: bool, elite: bool, fortune: float, roll: RandomNumberGenerator) -> Array:
	var out: Array = []
	out.append_array(DivineGearData.drops(ItemData.drop_class(cls, roll), boss, elite, roll))
	if boss or roll.randf() < (EndgameFields.JEWELRY_ELITE if elite else EndgameFields.JEWELRY_NORMAL):
		var slot := "ring" if roll.randf() < 0.5 else "amulet"
		out.append(StarProgression.item(ItemData.drop_class(cls, roll), 200, slot, roll))
	var scales := EndgameFields.scale_count(boss, elite, fortune, roll)
	if scales > 0 and ItemData.JEWELS.has(EndgameFields.SCALE):
		out.append(ItemData.jewel(EndgameFields.SCALE, scales))
	out.append_array(EndgameFields.supply_drops(boss, elite, fortune, roll))
	return out


## Every item one kill drops (gold and the forge jewels aside), for a hero of class cls.
## The owner's four rolls come first and are the same for every monster; fortune only
## reaches the Poseidon part (as it does there).
static func kill_drops(cls: StringName, boss: bool, elite: bool, fortune: float, roll: RandomNumberGenerator) -> Array:
	var out: Array = []
	if roll.randf() < WEAPON_DROP:
		out.append(DragonGearData.weapon(ItemData.drop_class(cls, roll), roll))
	if roll.randf() < WING_DROP:
		out.append(DragonGearData.wings(ItemData.drop_class(cls, roll), roll))
	if roll.randf() < FRAGMENT_DROP:
		out.append(ItemData.jewel(FRAGMENT))
	if roll.randf() < EGG_DROP:
		out.append(ItemData.jewel(EGG))
	# Treasure chests, and the boss's extras.
	if boss:
		out.append(ItemData.jewel(CHEST, CHEST_BOSS))
		out.append(ItemData.jewel(FRAGMENT, BOSS_FRAGMENTS))
		if roll.randf() < BOSS_WEAPON_BONUS:
			out.append(DragonGearData.weapon(ItemData.drop_class(cls, roll), roll))
		if roll.randf() < BOSS_WING_BONUS:
			out.append(DragonGearData.wings(ItemData.drop_class(cls, roll), roll))
		if roll.randf() < BOSS_EGG_BONUS:
			out.append(ItemData.jewel(EGG))
	elif roll.randf() < (CHEST_ELITE if elite else CHEST_NORMAL):
		out.append(ItemData.jewel(CHEST))
	out.append_array(poseidon_drops(cls, boss, elite, fortune, roll))
	return out


## What the rare dragon (Zone, the zone flag "rare_dragon") drops when it falls: chests
## and fragments for sure, a set core, gems, potions and a real chance at the egg, the
## weapon and the wings.
static func rare_drops(cls: StringName, roll: RandomNumberGenerator) -> Array:
	var out: Array = []
	out.append(ItemData.jewel(CHEST, RARE_CHESTS))
	out.append(ItemData.jewel(FRAGMENT, roll.randi_range(RARE_FRAGMENTS_MIN, RARE_FRAGMENTS_MAX)))
	if roll.randf() < RARE_WEAPON:
		out.append(DragonGearData.weapon(ItemData.drop_class(cls, roll), roll))
	if roll.randf() < RARE_WING:
		out.append(DragonGearData.wings(ItemData.drop_class(cls, roll), roll))
	if roll.randf() < RARE_EGG:
		out.append(ItemData.jewel(EGG))
	if ItemData.JEWELS.has(EndgameFields.SET_CORE):
		out.append(ItemData.jewel(EndgameFields.SET_CORE))
	for i in RARE_GEMS:
		out.append(Zone.random_stat_gem(200, 1, true, roll))
	out.append(ItemData.potion("hp_god", 5))
	out.append_array(DivineGearData.drops(ItemData.drop_class(cls, roll), true, false, roll))
	return out


## A drop the whole server hears about: the Dragon God weapon and wings, the egg, and
## the costume the fragments make (a fragment itself is not one).
static func is_jackpot(item: Dictionary) -> bool:
	if DragonGearData.is_item(item):
		return true
	if item.get("kind", "") == "jewel":
		return String(item.get("id", "")) == EGG
	return ItemData.is_costume(item) and String(item.get("id", "")) == COSTUME


## The line the server reads when [param who] got [param item] from [param source] (""
## the isle's monsters, "chest" a treasure chest, "rare" the rare dragon).
static func announce_text(item: Dictionary, who: String, source := "") -> String:
	var thing := ItemData.name_of(item)
	if ItemData.is_costume(item):
		return "★ %s รวบรวมชิ้นส่วนครบ %d ชิ้น ได้ครอบครอง %s แห่ง%s! ★" % [who, COSTUME_FRAGMENTS, thing, SkyIsleData.TITLE]
	var from := "จาก%s" % String(ItemData.JEWELS[CHEST].name) if source == "chest" else ("จากมังกรหายากแห่ง%s" % SkyIsleData.TITLE if source == "rare" else "ที่%s" % SkyIsleData.TITLE)
	return "★ %s ได้รับ %s %s! ★" % [who, thing, from]


## The last lines announce() sent (newest last, at most ANNOUNCED_MAX): tests and logs.
const ANNOUNCED_MAX := 16
static var announced: Array[String] = []


## Tells the server that [param who] (the hero when "") got [param item].
static func announce(item: Dictionary, who := "", source := "") -> void:
	var name := who if who != "" else (String(Game.profile.get("name", "")) if Game.has_profile else "")
	var text := announce_text(item, name, source)
	announced.append(text)
	if announced.size() > ANNOUNCED_MAX:
		announced.pop_front()
	Announcer.broadcast(text, "jackpot")


## The finder's own moment for a jackpot: a toast, a gold flash and a fanfare.
static func celebrate(item: Dictionary) -> void:
	Game.say("แจ็กพอต! ได้รับ %s — ประกาศให้ทั้งเซิร์ฟเวอร์รู้แล้ว!" % ItemData.name_of(item), &"success")
	Game.screen_flash.emit(Color("ffd84a"), 0.22)
	AudioManager.play_sfx(&"level_up", -2.0)


# --- Treasure chests ----------------------------------------------------------------

## The prize id of one chest (CHEST_TABLE) for a roll in 0..1.
static func chest_pick(r: float) -> String:
	var acc := 0.0
	for row in CHEST_TABLE:
		acc += float(row[1])
		if r < acc:
			return String(row[0])
	return String(CHEST_TABLE[0][0])


## The prize of one chest: {"gold": n} or {"item": item}.
static func chest_prize(cls: StringName, roll: RandomNumberGenerator) -> Dictionary:
	match chest_pick(roll.randf()):
		"gold":
			return {"gold": roll.randi_range(CHEST_GOLD_MIN / 1000, CHEST_GOLD_MAX / 1000) * 1000}
		"jewels":
			var pick: Array = [["purple", 5], ["pink", 3], ["chaos", 3]][roll.randi() % 3]
			return {"item": ItemData.jewel(String(pick[0]), int(pick[1]))}
		"gem":
			return {"item": Zone.random_stat_gem(200, 1, true, roll)}
		"potion":
			return {"item": ItemData.potion("hp_god", 5)}
		"feather":
			return {"item": ItemData.jewel("feather")}
		"fragment":
			return {"item": ItemData.jewel(FRAGMENT)}
		"core":
			return {"item": ItemData.jewel(EndgameFields.SET_CORE)}
		"egg":
			return {"item": ItemData.jewel(EGG)}
		"weapon":
			return {"item": DragonGearData.weapon(ItemData.drop_class(cls, roll), roll)}
	return {"item": DragonGearData.wings(ItemData.drop_class(cls, roll), roll)}


## Opens up to [param count] chests from the hero's bag (one press opens at most
## OPEN_ALL_MAX). Every prize goes to the bag, or to the shared storage when the bag is
## full (Game.give_or_store); when neither has room for a prize, that chest stays shut
## and the opening stops. Jackpots are announced. Saves. Returns {"opened": n, "gold": n,
## "items": [item, ...], "jackpots": [item, ...], "stopped": reason or ""}.
## [param roll]: the dice (tests); Game.rng when null.
static func open_chests(count := 1, roll: RandomNumberGenerator = null) -> Dictionary:
	var out := {"opened": 0, "gold": 0, "items": [], "jackpots": [], "stopped": ""}
	if not Game.has_profile:
		out.stopped = "ยังไม่มีตัวละคร"
		return out
	if roll == null:
		roll = Game.rng
	var want := mini(mini(count, OPEN_ALL_MAX), Game.jewel_count(CHEST))
	if want <= 0:
		out.stopped = "ไม่มี%s" % String(ItemData.JEWELS[CHEST].name)
		return out
	for i in want:
		var prize := chest_prize(Game.class_id(), roll)
		if prize.has("item"):
			var item: Dictionary = prize.item
			if not _has_room(item):
				out.stopped = "กระเป๋าและคลังเต็ม — เปิดกล่องที่เหลือไม่ได้"
				break
			Game._spend_jewels(CHEST, 1)
			Game.give_or_store(item)
			(out.items as Array).append(item)
			if is_jackpot(item):
				(out.jackpots as Array).append(item)
				announce(item, "", "chest")
		else:
			Game._spend_jewels(CHEST, 1)
			Game.add_gold(int(prize.gold))
			out.gold = int(out.gold) + int(prize.gold)
		out.opened = int(out.opened) + 1
	if int(out.opened) > 0:
		Game.mark_dirty()
		Game.inventory_changed.emit()
		Game.save()
	return out


## Whether [param item] fits the bag or the shared storage right now.
static func _has_room(item: Dictionary) -> bool:
	if Game.inventory_free() > 0 or Game.storage().size() < Game.STORAGE_SIZE:
		return true
	if not ItemData.is_stackable(item):
		return false
	for pile in Game.profile.inv + Game.storage():
		if pile is Dictionary and pile.get("kind", "") == item.get("kind", "") and pile.get("id") == item.get("id"):
			return true
	return false


## "เหรียญทอง +120,000 · เพชรม่วง ×5 · อัญมณี ..." of an open_chests result.
static func prize_text(result: Dictionary) -> String:
	var parts: PackedStringArray = []
	if int(result.get("gold", 0)) > 0:
		parts.append("เหรียญทอง +%d" % int(result.gold))
	var piles := {}
	var order: Array = []
	for item in result.get("items", []):
		var name := ItemData.name_of(item)
		if not piles.has(name):
			piles[name] = 0
			order.append(name)
		piles[name] = int(piles[name]) + (int(item.get("count", 1)) if ItemData.is_stackable(item) else 1)
	for name in order:
		parts.append("%s ×%d" % [name, int(piles[name])])
	return " · ".join(parts)


## "38%" / "0.7%": a chance as the help prints it.
static func percent(chance: float) -> String:
	return String.num(chance * 100.0, 1).trim_suffix(".0") + "%"


## The chest's help in the bag: what it is and its published odds.
static func chest_help() -> String:
	var rows: PackedStringArray = []
	for row in CHEST_TABLE:
		rows.append("%s %s" % [String(row[2]), percent(float(row[1]))])
	return "เปิดได้จากกระเป๋า สุ่มของรางวัล 1 อย่างต่อกล่อง: %s · ดรอปเฉพาะที่%s (มอนสเตอร์ %s · ตัวเก่ง %s · บอสให้ %d กล่องทุกครั้ง)" % [
		" · ".join(rows), SkyIsleData.TITLE, percent(CHEST_NORMAL), percent(CHEST_ELITE), CHEST_BOSS]


# --- Fragments, the costume and the egg ---------------------------------------------

static func fragments() -> int:
	return Game.jewel_count(FRAGMENT) if Game.has_profile else 0


## Why the fragments cannot be exchanged for the costume now ("" when they can).
static func exchange_problem() -> String:
	return RewardShop.problem("costume", COSTUME)


## COSTUME_FRAGMENTS fragments for the costume item (once a hero, like every costume;
## into the bag, or the storage when the bag is full). Announced. "ok" or a reason.
static func exchange_costume() -> String:
	var result := RewardShop.buy("costume", COSTUME)
	if result == "ok":
		var item := RewardShop.costume_item(COSTUME)
		announce(item)
		celebrate(item)
	return result


static func fragment_help() -> String:
	return "สะสมครบ %d ชิ้นแลก%sได้ (กดปุ่มแลกที่นี่ หรือที่%s แท็บคอสตูม) · คอสตูมเฉพาะ%s ไม่มีขายด้วยเหรียญ · ดรอปจากมอนสเตอร์ทุกตัวบนเกาะ %s บอสให้ %d ชิ้นทุกครั้ง และมีในกล่องสมบัติเทพมังกร" % [
		COSTUME_FRAGMENTS, String(RewardShop.COSTUMES[COSTUME].name), RewardShop.SHOP_NAME, SkyIsleData.TITLE, percent(FRAGMENT_DROP), BOSS_FRAGMENTS]


static func egg_help() -> String:
	var info := MountData.info(MOUNT)
	return "ไข่ของสัตว์ขี่%s: ใช้ฟัก/อัปเลเวลที่เมนู สัตว์ขี่ (เลเวล n ใช้ n ฟอง + เพชรชาออส %d×n เม็ด โอกาสสำเร็จ %s) · สัตว์ขี่ที่เร็วที่สุด ความเร็วตอนขี่ +%d%% · ดรอปเฉพาะที่%s %s ต่อมอนสเตอร์ และมีในกล่องสมบัติเทพมังกร" % [
		String(info.name), int(info.chaos), MountData.chance_text(MOUNT), roundi(float(info.speed) * 100.0), SkyIsleData.TITLE, percent(EGG_DROP)]


## The help line of one of the isle's stackables in the bag ("" for any other id).
static func help(id: String) -> String:
	match id:
		CHEST: return chest_help()
		FRAGMENT: return fragment_help()
		EGG: return egg_help()
	return ""
