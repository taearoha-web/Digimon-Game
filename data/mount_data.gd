class_name MountData
extends RefCounted
## Mounts (สัตว์ขี่): bought with gold in the game menu (tab "สัตว์ขี่"), one picked as
## the active mount. Riding is for travel only: the hero moves faster, and attacking,
## casting, auto hunting or taking a hit puts the hero back on foot. The town and the
## hunting fields allow it; the arena, ranked duels, the guild war and the tower do not.
## Saved as profile["mounts"] (owned ids) and profile["mount"] (the active id, "" = none).

## id -> name, price (gold), speed (move speed bonus while riding), what it is,
## and the colour of its card in the menu. MountVisual builds each body.
const MOUNTS := {
	"thunder_wolf": {"name": "หมาป่าสายฟ้า", "price": 200_000, "speed": 0.30, "color": Color("5f7fd6"),
		"desc": "หมาป่าขนฟูลายสายฟ้า วิ่งไวดุจสายลม"},
	"glow_stag": {"name": "กวางเรืองแสง", "price": 500_000, "speed": 0.35, "color": Color("7fe7d8"),
		"desc": "กวางขาวนวล เขาเรืองแสงสีฟ้าในยามค่ำคืน"},
	"griffin": {"name": "กริฟฟิน", "price": 2_000_000, "speed": 0.40, "color": Color("e8b24a"),
		"desc": "ครึ่งพญาอินทรีครึ่งสิงโต กระพือปีกพาทะยาน"},
	"fire_drake": {"name": "มังกรน้อยเพลิง", "price": 10_000_000, "speed": 0.50, "color": Color("ff6a3d"),
		"desc": "มังกรน้อยขี้เล่น หางมีเปลวไฟลุกโชน"},
}
## Shop order (cheapest first).
const ORDER: Array[String] = ["thunder_wolf", "glow_stag", "griffin", "fire_drake"]


static func exists(id: String) -> bool:
	return MOUNTS.has(id)


static func info(id: String) -> Dictionary:
	return MOUNTS.get(id, {})


## 200,000 -> "200K", 2,000,000 -> "2M".
static func price_text(price: int) -> String:
	if price >= 1_000_000:
		return ("%dM" % (price / 1_000_000)) if price % 1_000_000 == 0 else ("%.1fM" % (price / 1_000_000.0))
	if price >= 1_000:
		return "%dK" % (price / 1_000)
	return str(price)


static func speed_bonus(id: String) -> float:
	return float(MOUNTS.get(id, {}).get("speed", 0.0))


## True where heroes may ride: the town and the hunting fields (not the arena,
## ranked duels, the guild war or the tower).
static func zone_allows(zone_data: Dictionary) -> bool:
	for key in ["pvp", "guildwar", "tower", "arena"]:
		if bool(zone_data.get(key, false)):
			return false
	return true
