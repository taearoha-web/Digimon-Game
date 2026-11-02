class_name ChatTrade
extends RefCounted
## Buying through the world chat, free and offline like ChatBrain. The hero (or a world
## player in the chatter, ChatThreads) types a buy request ("หาซื้อเพชรม่วง", "ซื้อยาแดง",
## "มีใครขายปีกไหม", "อยากได้ดาบ", "WTB chaos"): parse reads what is wanted (a buy word and
## an item word: potions, forge jewels, mount materials, gems, weapons by kind or class,
## armour pieces, wings, set pieces; the longest item word wins, so "ยาเลือดมหาเทพ" is
## not just "ยาเลือด"), offers looks through the stalls kept right now (every online
## world player whose state is doing "stall": the stall keepers and the ★300 players on a
## break) for lots that match, and answers makes the replies: up to MAX_SELLERS keepers
## who have it name the lot, the price and where their stall stands in the village; when
## nobody has it, one player (or the system) says so and where it comes from.

## Keepers answering one request, at most.
const MAX_SELLERS := 3
## Seconds before the first answer, and between two answers.
const FIRST_WAIT := Vector2(1.6, 2.8)
const NEXT_WAIT := Vector2(1.4, 2.8)
const SELLER_COLOR := Color("8ff0ff")
const NOTE_NAME := "ระบบ"
## Words that make a line a buy request ("ขาย…ไหม" too: SELL_ASK).
const BUY_WORDS := ["หาซื้อ", "อยากซื้อ", "จะซื้อ", "ขอซื้อ", "ซื้อ", "มีใครขาย", "ใครขาย", "ใครมี", "อยากได้", "ต้องการ", "รับซื้อ", "wtb", "want to buy", "buy "]
const SELL_ASK := ["ไหม", "มั้ย", "มั๊ย", "ป่าว", "?"]
## Item words: [words, what they mean]. Every potion, jewel and gem by its own name and
## id is added to these (_table).
const WORDS := [
	[["ยาแดง", "ยาเลือด", "ยาhp", "ยา hp", "hp potion", "โพชั่นแดง", "ยาฮีล"], {"label": "ยาเลือด", "kind": "potion", "ids": ["hp_s", "hp_m", "hp_l", "hp_xl", "hp_war", "hp_xxl", "hp_god"]}],
	[["ยาฟ้า", "ยามานา", "ยามา", "ยาmp", "ยา mp", "mp potion", "ยาน้ำเงิน"], {"label": "ยามานา", "kind": "potion", "ids": ["mp_s", "mp_m", "mp_l", "mp_xl", "mp_xxl"]}],
	[["ยา", "potion", "โพชั่น", "pot"], {"label": "ยา", "kind": "potion", "ids": ["hp_s", "hp_m", "hp_l", "hp_xl", "hp_war", "hp_xxl", "hp_god", "mp_s", "mp_m", "mp_l", "mp_xl", "mp_xxl"]}],
	[["ชาออส", "เคออส", "เพชรเหลือง"], {"label": "เพชรชาออส", "kind": "jewel", "ids": ["chaos"]}],
	[["เพชร", "หินตีบวก", "เพชรตีบวก", "jewel"], {"label": "เพชรตีบวก", "kind": "jewel", "ids": ["purple", "pink", "chaos"]}],
	[["สว่าน"], {"label": "สว่านเจาะ", "kind": "jewel", "ids": ["drill"]}],
	[["แก่นเทพ", "แก่นเซต", "หลอมเซต", "set core", "core"], {"label": "แก่นเทพหลอมเซต", "kind": "jewel", "ids": ["set_core"]}],
	[["เขี้ยวหมาป่า", "เขี้ยว"], {"label": "เขี้ยวหมาป่าสายฟ้า", "kind": "jewel", "ids": ["wolf_fang"]}],
	[["เขากวาง"], {"label": "เขากวางเรืองแสง", "kind": "jewel", "ids": ["stag_antler"]}],
	[["กริฟฟิน"], {"label": "ขนปีกกริฟฟิน", "kind": "jewel", "ids": ["griffin_plume"]}],
	[["เกล็ดมังกร", "เกล็ด"], {"label": "เกล็ดมังกรเพลิง", "kind": "jewel", "ids": ["drake_scale"]}],
	[["ของทำมอนท์", "ของมอนท์", "วัตถุดิบมอนท์", "ของสัตว์ขี่", "วัตถุดิบสัตว์ขี่", "มอนท์", "สัตว์ขี่", "mount"], {"label": "วัตถุดิบสัตว์ขี่", "kind": "jewel", "ids": ["wolf_fang", "stag_antler", "griffin_plume", "drake_scale"]}],
	[["นิล"], {"label": "นิลดำ", "kind": "gem", "ids": ["onyx"]}],
	[["มุก"], {"label": "มุกจันทรา", "kind": "gem", "ids": ["pearl"]}],
	[["โอปอล"], {"label": "โอปอลกาลเวลา", "kind": "gem", "ids": ["opal"]}],
	[["ทัวร์มาลีน"], {"label": "ทัวร์มาลีนนำโชค", "kind": "gem", "ids": ["tourmaline"]}],
	[["อัญมณี", "เจม", "gem", "หินใส่รู"], {"label": "อัญมณี", "kind": "gem", "ids": ["ruby", "emerald", "amethyst", "sapphire", "topaz", "onyx", "pearl", "opal", "tourmaline"]}],
	[["ปีก", "wing", "ผ้าคลุม"], {"label": "ปีก", "kind": "equip", "slot": "wings"}],
	[["ดาบ", "sword"], {"label": "ดาบ", "kind": "equip", "slot": "weapon", "bases": ["sword"]}],
	[["หอก", "spear"], {"label": "หอก", "kind": "equip", "slot": "weapon", "bases": ["spear"]}],
	[["มีดคู่", "มีด", "dagger"], {"label": "มีดคู่", "kind": "equip", "slot": "weapon", "bases": ["dagger"]}],
	[["ธนู", "bow"], {"label": "ธนู", "kind": "equip", "slot": "weapon", "bases": ["bow"]}],
	[["คทาราชัน", "scepter"], {"label": "คทาราชัน", "kind": "equip", "slot": "weapon", "bases": ["scepter"]}],
	[["คทา", "staff", "wand"], {"label": "คทา", "kind": "equip", "slot": "weapon", "bases": ["staff", "wand", "scepter"]}],
	[["โคม", "lantern"], {"label": "โคมวิญญาณ", "kind": "equip", "slot": "weapon", "bases": ["lantern"]}],
	[["พิณ", "lute"], {"label": "พิณ", "kind": "equip", "slot": "weapon", "bases": ["lute"]}],
	[["โล่", "shield"], {"label": "โล่", "kind": "equip", "slot": "weapon", "bases": ["greatshield"]}],
	[["อาวุธ", "weapon"], {"label": "อาวุธ", "kind": "equip", "slot": "weapon"}],
	[["เกราะ", "เสื้อ", "armor", "armour"], {"label": "เกราะ", "kind": "equip", "slot": "armor"}],
	[["หมวก", "มงกุฎ", "helm"], {"label": "หมวก", "kind": "equip", "slot": "helm"}],
	[["รองเท้า", "boots"], {"label": "รองเท้า", "kind": "equip", "slot": "boots"}],
	[["แหวน", "ring"], {"label": "แหวน", "kind": "equip", "slot": "ring"}],
	[["สร้อย", "amulet", "necklace"], {"label": "สร้อย", "kind": "equip", "slot": "amulet"}],
	[["ชิ้นเซต", "ชุดเซต", "ของเซต", "เซต"], {"label": "ของเซต", "kind": "equip", "set": true}],
]
const SELL_LINES := [
	"มี%what ราคา %price ร้านอยู่%where",
	"มีจ้า %hero! %what ราคา %price อยู่%where",
	"%what ราคา %price มาที่%where ได้เลย",
	"ร้านฉันมี%what %price อยู่%where",
	"%hero ทางนี้ ๆ มี%what %price ที่%where",
]
const NONE_LINES := [
	"ตอนนี้ไม่มีใครขาย%what เลย ลองใหม่ทีหลังนะ",
	"ดูทุกแผงแล้ว ไม่มีใครขาย%what เลยอ่ะ ลองใหม่ทีหลังนะ",
	"%hero ตอนนี้ไม่มีใครขาย%what เลย แผงเติมของทุก 2 ชั่วโมงนะ",
]

static var _words: Array = []


## Every item word with its meaning, the full names of potions, jewels and gems, and the
## classes' weapons ("อาวุธสายธนู", "ของนักฆ่า") included.
static func _table() -> Array:
	if not _words.is_empty():
		return _words
	var out: Array = WORDS.duplicate(true)
	for id in ItemData.POTIONS:
		if id == "halloween" or id == "town_scroll":
			continue
		out.append([[String(ItemData.POTIONS[id].name), String(id)], {"label": String(ItemData.POTIONS[id].name), "kind": "potion", "ids": [String(id)]}])
	for id in ItemData.JEWELS:
		out.append([[String(ItemData.JEWELS[id].name), String(id)], {"label": String(ItemData.JEWELS[id].name), "kind": "jewel", "ids": [String(id)]}])
	for id in ItemData.GEMS:
		out.append([[String(ItemData.GEMS[id].name), String(id)], {"label": String(ItemData.GEMS[id].name), "kind": "gem", "ids": [String(id)]}])
	for cls in ClassData.IDS:
		var name := String(ClassData.get_class_data(cls).name)
		out.append([["อาวุธ" + name, "ของ" + name, name], {"label": "อาวุธ" + name, "kind": "equip", "slot": "weapon", "class": String(cls)}])
	_words = out
	return out


## What a line asks to buy: {label, kind, ids / slot / bases / class / set, level, text},
## or {} when it is not a buy request (no buy word, or nothing it names).
static func parse(text: String) -> Dictionary:
	var lower := text.to_lower().strip_edges()
	if lower == "":
		return {}
	var buying := false
	for word in BUY_WORDS:
		if lower.contains(String(word)):
			buying = true
			break
	if not buying and lower.contains("ขาย"):
		for word in SELL_ASK:
			if lower.contains(String(word)):
				buying = true
				break
	if not buying and lower.begins_with("หา"):
		buying = true
	if not buying:
		return {}
	var best := {}
	var best_len := 0
	for entry in _table():
		for word in entry[0]:
			var w := String(word).to_lower()
			if w.length() > best_len and lower.contains(w):
				best = entry[1]
				best_len = w.length()
	if best.is_empty():
		return {}
	var out: Dictionary = best.duplicate(true)
	out["level"] = _level_in(lower)
	out["text"] = text
	return out


## A level in the line ("lv50", "เลเวล 80"), 0 when none.
static func _level_in(lower: String) -> int:
	var rx := RegEx.new()
	rx.compile("(?:lv\\.?|เลเวล|เวล)\\s*(\\d{1,3})")
	var m := rx.search(lower)
	return int(m.get_string(1)) if m != null else 0


## Whether `item` is what request `req` asks for.
static func matches(req: Dictionary, item: Dictionary) -> bool:
	var kind := String(item.get("kind", ""))
	match String(req.get("kind", "")):
		"potion", "jewel":
			return kind == String(req.kind) and (req.get("ids", []) as Array).has(String(item.get("id", "")))
		"gem":
			return kind == "gem" and (req.get("ids", []) as Array).has(String(item.get("id", "")).split("_")[0])
		"equip":
			if kind != "equip":
				return false
			if String(req.get("slot", "")) != "" and String(item.get("slot", "")) != String(req.slot):
				return false
			if not (req.get("bases", []) as Array).is_empty() and not (req.bases as Array).has(String(item.get("base", ""))):
				return false
			if String(req.get("class", "")) != "" and String(item.get("class", "")) != String(req["class"]):
				return false
			if bool(req.get("set", false)) and String(item.get("set", "")) == "":
				return false
			var lv := int(req.get("level", 0))
			if lv > 0 and absi(int(item.get("level", 0)) - lv) > 10:
				return false
			return true
	return false


## The stalls kept at time t that have what `req` asks for: [{index, name, lots, count,
## price}] (count: pieces or units in all its lots, price: its cheapest lot), the
## cheapest stall first.
static func offers(req: Dictionary, t: float = -1.0) -> Array[Dictionary]:
	if t < 0.0:
		t = WorldPresence.clock()
	var out: Array[Dictionary] = []
	for i in WorldPlayers.size():
		var s := WorldPlayers.state(i, t)
		if not bool(s.online) or String(s.doing) != "stall":
			continue
		var lots := StallStock.stock(i, t).filter(func(e): return matches(req, e.item))
		if lots.is_empty():
			continue
		lots.sort_custom(func(a, b): return int(a.price) < int(b.price))
		var count := 0
		for e in lots:
			count += int(e.item.get("count", 1))
		out.append({"index": i, "name": String(s.name), "lots": lots, "count": count, "price": int(lots[0].price)})
	out.sort_custom(func(a, b): return int(a.price) < int(b.price) or (int(a.price) == int(b.price) and int(a.index) < int(b.index)))
	return out


## The world chat's answers to `req` at time t: [{index (-1: the system), speaker, text,
## delay}], delay counted from the request. Up to MAX_SELLERS keepers who have it, or one
## line saying nobody sells it now (from an online player who keeps no stall, otherwise
## the system) with where it comes from. `seed_value` picks the wording and who speaks;
## `hero` is who asked (named in some answers), `asker` its world index (never answers).
static func answers(req: Dictionary, t: float = -1.0, seed_value := 0, hero := "", asker := -1) -> Array[Dictionary]:
	if t < 0.0:
		t = WorldPresence.clock()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("trade|%s|%d" % [String(req.get("text", req.get("label", ""))), seed_value])
	if hero == "":
		hero = String(Game.profile.get("name", "")) if Game.has_profile else ""
	var out: Array[Dictionary] = []
	var wait := rng.randf_range(FIRST_WAIT.x, FIRST_WAIT.y)
	var found := offers(req, t)
	for o in found.filter(func(f): return int(f.index) != asker).slice(0, MAX_SELLERS):
		out.append({"index": int(o.index), "speaker": String(o.name), "text": offer_line(o, req, hero, rng), "delay": wait})
		wait += rng.randf_range(NEXT_WAIT.x, NEXT_WAIT.y)
	if not out.is_empty():
		return out
	var line := String(NONE_LINES[rng.randi() % NONE_LINES.size()]).replace("%what", String(req.get("label", "ของ")))
	line = line.replace("%hero", hero if hero != "" else "เพื่อน")
	var tip := hint(req)
	if tip != "":
		line += " " + tip
	var speakers: Array[int] = []
	for i in WorldPlayers.size():
		var s := WorldPlayers.state(i, t)
		if bool(s.online) and String(s.doing) != "stall" and i != asker:
			speakers.append(i)
	if speakers.is_empty():
		out.append({"index": -1, "speaker": NOTE_NAME, "text": line, "delay": wait})
		return out
	var who: int = speakers[rng.randi() % speakers.size()]
	out.append({"index": who, "speaker": String(WorldPlayers.entry(who).name), "text": line, "delay": wait})
	return out


## A keeper's line about offer `o` (offers) for `req`.
static func offer_line(o: Dictionary, req: Dictionary, hero: String, rng: RandomNumberGenerator) -> String:
	var lot: Dictionary = o.lots[0]
	var item: Dictionary = lot.item
	var what := ItemData.name_of(item)
	var price := StallStock._thousands(int(lot.price))
	if String(item.get("kind", "")) == "equip":
		what = "%s (%s %s)" % [what, ItemData.RARITY_NAMES[clampi(int(item.get("rarity", 2)), 0, 4)], ItemData.level_text(int(item.get("level", 1)))]
		if (o.lots as Array).size() > 1:
			what += " กับอีก %d ชิ้น" % ((o.lots as Array).size() - 1)
	else:
		var unit := _unit(item)
		if (o.lots as Array).size() > 1:
			what = "%s รวม %d %s" % [what, int(o.count), unit]
			price = "เริ่ม %s (%d %s)" % [price, int(item.get("count", 1)), unit]
		else:
			what = "%s %d %s" % [what, int(item.get("count", 1)), unit]
	var line := String(SELL_LINES[rng.randi() % SELL_LINES.size()])
	if hero == "" and line.contains("%hero"):
		line = String(SELL_LINES[0])
	return line.replace("%what", what).replace("%price", price).replace("%where", where_text(int(o.index))).replace("%hero", hero)


static func _unit(item: Dictionary) -> String:
	match String(item.get("kind", "")):
		"potion":
			return "ขวด"
		"gem":
			return "เม็ด"
	return "เม็ด" if String(item.get("id", "")) in ["purple", "pink", "chaos"] else "ชิ้น"


## Where stall keeper i sits in the village, in words ("ลานกลางหมู่บ้านฝั่งตะวันออก"):
## the stall its body stands at here, otherwise its own favourite stall.
static func where_text(i: int) -> String:
	return place_words(stall_spot(i))


## The stall of keeper i: its body's here (WorldPresence gave it one), otherwise the stall
## it asks for first (WorldPresence._give_stall).
static func stall_spot(i: int) -> Vector3:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		for node in tree.get_nodes_in_group("world_players"):
			var p := node as FieldPlayer
			if p != null and is_instance_valid(p) and p.world_index == i and p.stall_at.is_finite():
				return p.stall_at
	var n := JapanVillage.STALLS.size()
	return JapanVillage.STALLS[hash("stall|%s" % WorldPlayers.entry(i).name) % n]


## A village spot in words: the plaza and its side, or the street it is on.
static func place_words(spot: Vector3) -> String:
	var flat := Vector2(spot.x, spot.z)
	var side := ""
	if absf(spot.x) >= absf(spot.z):
		side = "ตะวันออก" if spot.x > 0.0 else "ตะวันตก"
	else:
		side = "ใต้" if spot.z > 0.0 else "เหนือ"
	if flat.length() < JapanVillage.PLAZA_RADIUS + 1.0:
		return "ลานกลางหมู่บ้านฝั่ง" + side
	match side:
		"ตะวันออก":
			return "ถนนตลาดฝั่งตะวันออก"
		"ตะวันตก":
			return "ถนนฝั่งโดโจ"
		"เหนือ":
			return "ทางขึ้นศาลเจ้า"
	return "ทางไปประตูหมู่บ้าน"


## Where what `req` asks for comes from, for the "nobody sells it" answer.
static func hint(req: Dictionary) -> String:
	var ids: Array = req.get("ids", [])
	match String(req.get("kind", "")):
		"potion":
			if ids.size() == 1 and String(ids[0]) == "hp_god":
				return "ยาเลือดมหาเทพร้านค้าขายตอน Lv.100 หรือแลกที่ร้านแต้มกิลด์ก็ได้"
			return "ร้านค้าในหมู่บ้านก็มีขายนะ"
		"jewel":
			if ids.size() == 1:
				match String(ids[0]):
					"set_core":
						return "แก่นเทพดรอปที่%sเท่านั้น (★%d ขึ้นไป)" % [DrownedAbyssData.TITLE, DrownedAbyssData.ENTRY_STAR]
					"feather":
						return "ขนนกดรอปในสนามดาว %d ขึ้นไป" % ItemData.FEATHER_STARS
					"drill":
						return "สว่านแลกได้ที่ร้านแต้มกิลด์นะ"
					"wolf_fang", "stag_antler", "griffin_plume", "drake_scale":
						return "%sดรอปจากมอนตอนล่า โอกาสน้อยหน่อย" % String(ItemData.JEWELS[String(ids[0])].name)
			return "เพชรดรอปจากมอนทุกสนาม ที่%sดรอปเยอะสุด" % DrownedAbyssData.TITLE
		"gem":
			return "อัญมณีดรอปจากมอน หรือแลกผลึกที่หอคอยได้"
		"equip":
			if String(req.get("slot", "")) == "wings":
				return "ปีกดรอปจากบอส Lv.100 นะ"
			return "ลองล่าบอสสนามดู ของดีดรอปบ่อย"
	return ""
