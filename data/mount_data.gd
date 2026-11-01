class_name MountData
extends RefCounted
## Mounts (สัตว์ขี่): crafted and levelled in the game menu (tab "สัตว์ขี่"), one picked
## as the active mount. Each mount has its own material (a stackable "jewel" item,
## ItemData.JEWELS) that every monster of the hunting fields may drop (its "drop" chance per kill,
## Zone.mount_mat_drops). Lv.1 is crafted and Lv.2-MAX_LEVEL are upgrades: level n
## takes n materials and n x "chaos" chaos jewels, always succeeds.
## While a mount is the active one its HP / ATK / DEF / crit bonus (BONUS x level) is
## part of the hero's stats (HeroStats.compute), ridden or not; riding only adds speed.
## Riding: the hero moves faster and fights from the saddle (attacks, skills, auto
## hunting and hits keep it riding, weapon in hand; SaddlePose keeps the legs seated
## while the upper body swings). Death puts it back on foot. The town and the hunting
## fields allow riding; the arena, ranked duels, the guild war and the tower do not.
## Saved as profile["mounts"] ({id: level 1-MAX_LEVEL}; old saves kept a list of owned
## ids, which Game._repair turns into level 1) and profile["mount"] (active id, "" = none).

const MAX_LEVEL := 5

## id -> name, speed (move speed bonus while riding), mat (its material, an
## ItemData.JEWELS id), drop (material chance per kill), chaos (chaos jewels per
## level of the step), chance (success chance of every step, craft and
## upgrades alike), bonus (stat shares per level: hp / atk / def multiply the
## stat, crit adds crit chance), what it is and the colour of its card in the menu.
## MountVisual builds each body.
const MOUNTS := {
	"thunder_wolf": {"name": "หมาป่าสายฟ้า", "speed": 0.30, "color": Color("5f7fd6"),
		"mat": "wolf_fang", "drop": 0.01, "chaos": 5, "chance": 1.0, "bonus": {"hp": 0.01},
		"desc": "หมาป่าขนฟูลายสายฟ้า วิ่งไวดุจสายลม"},
	"glow_stag": {"name": "กวางเรืองแสง", "speed": 0.35, "color": Color("7fe7d8"),
		"mat": "stag_antler", "drop": 0.0075, "chaos": 8, "chance": 0.60, "bonus": {"hp": 0.02, "def": 0.01},
		"desc": "กวางขาวนวล เขาเรืองแสงสีฟ้าในยามค่ำคืน"},
	"griffin": {"name": "กริฟฟิน", "speed": 0.40, "color": Color("e8b24a"),
		"mat": "griffin_plume", "drop": 0.005, "chaos": 10, "chance": 0.35, "bonus": {"hp": 0.03, "atk": 0.01},
		"desc": "ครึ่งพญาอินทรีครึ่งสิงโต กระพือปีกพาทะยาน"},
	"fire_drake": {"name": "มังกรน้อยเพลิง", "speed": 0.50, "color": Color("ff6a3d"),
		"mat": "drake_scale", "drop": 0.001, "chaos": 15, "chance": 0.10, "bonus": {"hp": 0.05, "atk": 0.02, "crit": 0.01},
		"desc": "มังกรน้อยขี้เล่น หางมีเปลวไฟลุกโชน"},
}
## Menu order (easiest first).
const ORDER: Array[String] = ["thunder_wolf", "glow_stag", "griffin", "fire_drake"]
const BONUS_ORDER: Array[String] = ["hp", "atk", "def", "crit"]


static func exists(id: String) -> bool:
	return MOUNTS.has(id)


static func info(id: String) -> Dictionary:
	return MOUNTS.get(id, {})


static func speed_bonus(id: String) -> float:
	return float(MOUNTS.get(id, {}).get("speed", 0.0))


## The material item id of a mount ("" for an unknown id).
static func mat_of(id: String) -> String:
	return String(MOUNTS.get(id, {}).get("mat", ""))


## The mount a material belongs to ("" when `mat` is no mount material).
static func mount_of_mat(mat: String) -> String:
	for id in ORDER:
		if String(MOUNTS[id].mat) == mat:
			return id
	return ""


## What the step to `level` (1 = craft) takes: {mat: count, chaos: count}.
static func cost(id: String, level: int) -> Dictionary:
	if not exists(id) or level < 1 or level > MAX_LEVEL:
		return {}
	return {"mat": level, "chaos": int(MOUNTS[id].chaos) * level}


## Success chance (0-1) of every craft / level-up step of a mount (0 for an unknown id).
static func chance(id: String) -> float:
	return clampf(float(MOUNTS.get(id, {}).get("chance", 0.0)), 0.0, 1.0)


## "100%" / "35%": the success chance as the menu shows it.
static func chance_text(id: String) -> String:
	return "%d%%" % roundi(chance(id) * 100.0)


## Stat shares of a mount at `level` (0 = not owned: {}): {hp, atk, def, crit}.
static func bonus(id: String, level: int) -> Dictionary:
	var out := {}
	if not exists(id) or level <= 0:
		return out
	level = mini(level, MAX_LEVEL)
	var per: Dictionary = MOUNTS[id].bonus
	for key in per:
		out[key] = float(per[key]) * level
	return out


## "HP +3% · พลังโจมตี +1%" (speed while riding added with `with_speed`).
static func bonus_text(id: String, level: int, with_speed := true) -> String:
	var parts: PackedStringArray = []
	var b := bonus(id, level)
	for key in BONUS_ORDER:
		if b.has(key):
			parts.append("%s +%s%%" % [ItemData.STAT_LABELS.get(key, key), String.num(float(b[key]) * 100.0, 1).trim_suffix(".0")])
	if with_speed:
		parts.append("ความเร็วตอนขี่ +%d%%" % roundi(speed_bonus(id) * 100.0))
	return " · ".join(parts)


## True where heroes may ride: the town, the hunting fields and the guild war (not
## the arena, ranked duels or the tower).
static func zone_allows(zone_data: Dictionary) -> bool:
	# The guild war is flagged pvp too, but riding is allowed there.
	if bool(zone_data.get("guildwar", false)):
		return true
	for key in ["pvp", "tower", "arena"]:
		if bool(zone_data.get(key, false)):
			return false
	return true
