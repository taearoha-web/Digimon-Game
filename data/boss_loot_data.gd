class_name BossLootData
extends RefCounted
## Drop tables of the 11 field bosses. Each boss owns two or three equipment
## slots (its guaranteed pieces are cut from them), a favourite gem and one or
## two "chase" pieces with a pity counter: every kill without the chase piece
## raises the chance, and a hard pity guarantees it. The counters live in the
## save as profile.boss_pity {key: kills since the last chase piece}.
##
## chase: {key suffix, rarity, base chance, soft pity start, per-kill step, hard pity}
## Odds with the default numbers below: 4% on the first kill, +6% per kill after
## the soft start, certain on the hard-pity kill.

const TABLES := {
	&"mush_king": {"epithet": "ราชาเห็ด", "slots": ["helm", "armor"], "gem": "emerald",
		"chase": [{"key": "", "rarity": 3, "base": 0.04, "soft": 6, "step": 0.06, "hard": 12}]},
	&"fire_dragon": {"epithet": "มังกรเพลิง", "slots": ["weapon", "ring"], "gem": "ruby",
		"chase": [{"key": "", "rarity": 3, "base": 0.04, "soft": 6, "step": 0.06, "hard": 12}]},
	&"sand_dragon": {"epithet": "มังกรทราย", "slots": ["boots", "amulet"], "gem": "topaz",
		"chase": [{"key": "", "rarity": 3, "base": 0.04, "soft": 6, "step": 0.06, "hard": 12}]},
	&"yeti_king": {"epithet": "ราชาหิมะ", "slots": ["armor", "helm"], "gem": "sapphire",
		"chase": [{"key": "", "rarity": 3, "base": 0.04, "soft": 6, "step": 0.06, "hard": 12}]},
	&"magma_dragon": {"epithet": "มังกรแมกมา", "slots": ["weapon", "ring"], "gem": "ruby",
		"chase": [{"key": "", "rarity": 3, "base": 0.04, "soft": 6, "step": 0.06, "hard": 12}]},
	&"bone_lord": {"epithet": "ราชาโครงกระดูก", "slots": ["weapon", "amulet"], "gem": "amethyst",
		"chase": [{"key": "", "rarity": 3, "base": 0.04, "soft": 6, "step": 0.06, "hard": 12}]},
	&"toad_king": {"epithet": "ราชากบพิษ", "slots": ["boots", "armor"], "gem": "emerald",
		"chase": [{"key": "", "rarity": 3, "base": 0.04, "soft": 6, "step": 0.06, "hard": 12}]},
	&"storm_dragon": {"epithet": "มังกรสายฟ้า", "slots": ["weapon", "boots"], "gem": "topaz",
		"chase": [{"key": "", "rarity": 3, "base": 0.04, "soft": 6, "step": 0.06, "hard": 12}]},
	&"gold_dragon": {"epithet": "มังกรทอง", "slots": ["ring", "amulet", "helm"], "gem": "topaz",
		"chase": [{"key": "", "rarity": 3, "base": 0.05, "soft": 6, "step": 0.07, "hard": 11},
			{"key": "mythic", "rarity": 4, "base": 0.01, "soft": 25, "step": 0.04, "hard": 40}]},
	&"abyss_dragon": {"epithet": "ราชามังกรอเวจี", "slots": ["weapon", "armor", "ring"], "gem": "ruby",
		"chase": [{"key": "", "rarity": 3, "base": 0.05, "soft": 6, "step": 0.07, "hard": 11},
			{"key": "mythic", "rarity": 4, "base": 0.01, "soft": 25, "step": 0.04, "hard": 40}]},
	&"void_emperor": {"epithet": "จักรพรรดิห้วงวิบัติ", "slots": ["weapon", "armor", "helm", "boots", "ring", "amulet"], "gem": "amethyst",
		"chase": [{"key": "", "rarity": 3, "base": 0.06, "soft": 5, "step": 0.08, "hard": 9},
			{"key": "mythic", "rarity": 4, "base": 0.015, "soft": 22, "step": 0.04, "hard": 35}]},
}
## Chance that a boss gem is the boss's favourite kind instead of a random one.
const FAVOURITE_GEM := 0.6


static func has(boss_id: StringName) -> bool:
	return TABLES.has(boss_id)


## The i-th guaranteed piece of a kill is cut from the boss's own slots.
static func slot_for(boss_id: StringName, index: int) -> String:
	var slots: Array = TABLES[boss_id].slots
	return String(slots[index % slots.size()])


static func gem_kind(boss_id: StringName, rng: RandomNumberGenerator) -> String:
	if rng.randf() < FAVOURITE_GEM:
		return String(TABLES[boss_id].gem)
	var kinds := ItemData.GEMS.keys()
	return String(kinds[rng.randi() % kinds.size()])


## Profile key of one counter: "magma_dragon" or "gold_dragon:mythic".
static func pity_key(boss_id: StringName, chase: Dictionary) -> String:
	return String(boss_id) if String(chase.key) == "" else "%s:%s" % [boss_id, chase.key]


## Chance of the chase piece on a kill when [param misses] kills have gone without it.
static func chance(chase: Dictionary, misses: int) -> float:
	if misses + 1 >= int(chase.hard):
		return 1.0
	var c := float(chase.base)
	if misses >= int(chase.soft):
		c += float(misses - int(chase.soft) + 1) * float(chase.step)
	return clampf(c, 0.0, 1.0)


## A chase piece: gear of the boss's slots at [param rarity], tagged with the boss.
static func chase_item(boss_id: StringName, chase: Dictionary, gear_level: int, class_id: StringName, rng: RandomNumberGenerator, index := 0) -> Dictionary:
	var item := ItemData.generate(gear_level, class_id, rng, int(chase.rarity), slot_for(boss_id, index))
	item["name"] = "%s แห่ง%s" % [item.get("name", ""), TABLES[boss_id].epithet]
	item["boss"] = String(boss_id)
	return item


## Settles every chase of [param boss_id] for one kill. [param pity] is the save's
## counter dictionary and is updated in place. Returns the pieces won.
static func roll_chases(boss_id: StringName, pity: Dictionary, gear_level: int, class_id: StringName, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var won: Array[Dictionary] = []
	for chase in TABLES[boss_id].chase:
		var key := pity_key(boss_id, chase)
		var misses := int(pity.get(key, 0))
		if rng.randf() < chance(chase, misses):
			pity[key] = 0
			won.append(chase_item(boss_id, chase, gear_level, class_id, rng, won.size()))
		else:
			pity[key] = misses + 1
	return won


## Shortest "kills until guaranteed" over the boss's chases, for the kill toast.
static func kills_left(boss_id: StringName, pity: Dictionary) -> int:
	var best := 999
	for chase in TABLES[boss_id].chase:
		best = mini(best, int(chase.hard) - int(pity.get(pity_key(boss_id, chase), 0)))
	return best
