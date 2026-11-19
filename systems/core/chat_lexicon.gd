class_name ChatLexicon
extends RefCounted
## What a typed line names, for the world players' answers (ChatMind): the game's own name
## tables (monsters and where they live, field bosses, fields, items, gems, mounts,
## costumes, classes) read once into an index, and a line cleaned up before it is read.
##
## normalize: lower case, no zero-width marks, a letter typed many times kept once ("ดีีีี",
## "สวัสดีีี"), a laugh of fives kept as "555", common English words and chat short forms
## read as the Thai they mean ("where" -> "ที่ไหน", "lv" -> "เลเวล", "pt" -> "ปาร์ตี้").
## find: every name in the line, longest first; a name typed without its tone marks
## (skeleton) or one letter off (an edit distance of 1, 2 for a long name) still counts.
## Built once (ensure) and kept: a phone reads a line in well under a millisecond.

## English words and short forms (whole words), read as the Thai a Thai line would use.
const EN := {
	"hi": "สวัสดี", "hello": "สวัสดี", "hey": "สวัสดี", "yo": "สวัสดี", "sup": "สวัสดี", "hiya": "สวัสดี", "morning": "อรุณสวัสดิ์",
	"bye": "บาย", "cya": "บาย", "gn": "ฝันดี", "thx": "ขอบคุณ", "thanks": "ขอบคุณ", "thank": "ขอบคุณ", "ty": "ขอบคุณ", "tq": "ขอบคุณ",
	"sorry": "ขอโทษ", "sry": "ขอโทษ", "lol": "555", "lmao": "555", "haha": "555", "hahaha": "555", "xd": "555",
	"where": "ที่ไหน", "how": "ยังไง", "what": "อะไร", "when": "เมื่อไหร่", "why": "ทำไม", "who": "ใคร", "which": "ไหน",
	"level": "เลเวล", "lvl": "เลเวล", "lv": "เลเวล", "exp": "exp", "xp": "exp", "star": "ดาว", "stars": "ดาว",
	"drop": "ดรอป", "drops": "ดรอป", "rate": "เรท", "chance": "โอกาส", "farm": "ฟาร์ม", "grind": "ฟาร์ม", "boss": "บอส",
	"buy": "ซื้อ", "wtb": "หาซื้อ", "sell": "ขาย", "wts": "ขาย", "price": "ราคา", "shop": "ร้าน", "stall": "ร้าน",
	"party": "ปาร์ตี้", "pt": "ปาร์ตี้", "join": "จอย", "inv": "ชวน", "invite": "ชวน", "guild": "กิลด์", "gw": "กิลด์วอ",
	"wing": "ปีก", "wings": "ปีก", "mount": "สัตว์ขี่", "pet": "สัตว์เลี้ยง", "gear": "อุปกรณ์", "weapon": "อาวุธ", "armor": "เกราะ",
	"gem": "อัญมณี", "gems": "อัญมณี", "set": "ชุดเซต", "enhance": "ตีบวก", "upgrade": "ตีบวก", "refine": "ตีบวก", "forge": "ตีบวก",
	"event": "อีเวนต์", "events": "อีเวนต์", "skill": "สกิล", "skills": "สกิล", "class": "อาชีพ", "job": "อาชีพ", "build": "สายไหน",
	"you": "คุณ", "u": "คุณ", "ur": "ของคุณ", "your": "ของคุณ", "me": "ฉัน", "my": "ของฉัน", "i": "ฉัน",
	"ok": "โอเค", "okay": "โอเค", "k": "โอเค", "yes": "ใช่", "yeah": "ใช่", "yep": "ใช่", "no": "ไม่", "nope": "ไม่",
	"nice": "เจ๋ง", "cool": "เจ๋ง", "gg": "เก่ง", "wp": "เก่ง", "pro": "เทพ", "op": "โหด", "noob": "กาก", "afk": "afk",
	"bot": "บอท", "ai": "เอไอ", "real": "คนจริง", "human": "คนจริง", "joke": "มุก", "funny": "ตลก", "bored": "เบื่อ", "sad": "เศร้า",
	"happy": "ดีใจ", "tired": "เหนื่อย", "sleepy": "ง่วง", "hungry": "หิว", "love": "รัก", "cute": "น่ารัก", "pretty": "สวย",
	"handsome": "หล่อ", "strong": "เก่ง", "weak": "อ่อน", "help": "ช่วย", "pls": "หน่อย", "plz": "หน่อย", "please": "หน่อย",
	"now": "ตอนนี้", "doing": "ทำอะไรอยู่", "wyd": "ทำอะไรอยู่", "hru": "สบายดีไหม", "trade": "เทรด", "duel": "ดวล", "pvp": "ดวล",
	"name": "ชื่อ", "time": "เวลา", "today": "วันนี้", "tomorrow": "พรุ่งนี้", "weekend": "เสาร์อาทิตย์",
}
## Whole English questions, read before the words.
const EN_PHRASES := [["where are you", "อยู่ไหน"], ["where r u", "อยู่ไหน"], ["where are u", "อยู่ไหน"], ["what level are you", "เลเวลเท่าไหร่"],
	["what lvl are you", "เลเวลเท่าไหร่"], ["how are you", "สบายดีไหม"], ["how r u", "สบายดีไหม"], ["what are you doing", "ทำอะไรอยู่"],
	["are you a bot", "เป็นบอทเหรอ"], ["are u a bot", "เป็นบอทเหรอ"], ["are you real", "เป็นคนจริงไหม"], ["what's your name", "ชื่ออะไร"],
	["whats your name", "ชื่ออะไร"], ["drop rate", "เรทดรอป"], ["what class", "อาชีพอะไร"], ["your guild", "อยู่กิลด์ไหน"],
	["what do you sell", "ขายอะไร"], ["what are you selling", "ขายอะไร"], ["want to party", "ไปปาร์ตี้ไหม"], ["good morning", "อรุณสวัสดิ์"],
	["good night", "ฝันดี"], ["thank you", "ขอบคุณ"]]
## Thai chat short forms and slips, read as the word they mean (a plain replace).
const TH := [["ปาตี้", "ปาร์ตี้"], ["ปาร์ตี้้", "ปาร์ตี้"], ["กิลล์", "กิลด์"], ["มั้ย", "ไหม"], ["มั๊ย", "ไหม"], ["มัย", "ไหม"],
	["รึเปล่า", "ไหม"], ["หรือเปล่า", "ไหม"], ["ป่าว", "ไหม"], ["ยังงัย", "ยังไง"], ["ยังงี้", "อย่างนี้"], ["ทามไม", "ทำไม"],
	["ทาไม", "ทำไม"], ["เท่าไร", "เท่าไหร่"], ["เท่าหร่าย", "เท่าไหร่"], ["เท่าไหร", "เท่าไหร่"], ["เลเวิล", "เลเวล"], ["เลเวว", "เลเวล"],
	["สวัสดีค่ะ", "สวัสดี ค่ะ"], ["หวัดดีครับ", "หวัดดี ครับ"], ["ขอบคุน", "ขอบคุณ"], ["ขอบคุงฯ", "ขอบคุณ"], ["คับ", "ครับ"],
	["งับ", "ครับ"], ["จ้าา", "จ้า"], ["อัพ", "อัป"], ["ตีบวกก", "ตีบวก"], ["ดรอบ", "ดรอป"], ["ฟาม", "ฟาร์ม"], ["บอด", "บอส"]]
## Thai tone marks and the like a hurried typist leaves out (the name's skeleton is read
## without them).
const MARKS := ["่", "้", "๊", "๋", "์", "็", "ํ"]

static var _built := false
## [{key, skel, kind, id, name}] longest key first.
static var _keys: Array = []
## Two-letter pieces -> indices into _keys (fuzzy candidates).
static var _grams := {}
## monster id -> {name, homes: [{zone, camp, levels}], boss_of: [zone ids]}.
static var monsters := {}
## zone id -> {name, level, star, monsters, boss, respawn, boss_level}.
static var zones := {}
## item key -> {name, kind ("jewel"/"potion"/"gem"/"mount"/"costume"/"isle"), id}.
static var items := {}
static var _seen := {}


static func ensure() -> void:
	if _built:
		return
	_built = true
	ZoneData.ensure()
	for zid in ZoneData.ZONES:
		var z: Dictionary = ZoneData.ZONES[zid]
		var zname := String(z.get("name", ""))
		if zname == "":
			continue
		var kind := String(z.get("scene", ""))
		var info := {"name": zname, "level": z.get("level", []), "star": int(z.get("star", 0)), "monsters": [], "boss": &"", "scene": kind}
		for camp in z.get("camps", []):
			for mid in camp.get("monsters", []):
				var m := _monster(StringName(mid))
				(m.homes as Array).append({"zone": StringName(zid), "camp": String(camp.get("name", "")), "levels": camp.get("levels", [])})
				if not (info.monsters as Array).has(StringName(mid)):
					(info.monsters as Array).append(StringName(mid))
		if z.has("boss"):
			var bid := StringName(z.boss.monster)
			info["boss"] = bid
			info["respawn"] = float(z.boss.get("respawn", 0.0))
			info["boss_level"] = int(z.boss.get("level", 0))
			(_monster(bid).boss_of as Array).append(StringName(zid))
		zones[StringName(zid)] = info
		_add(zname, "zone", String(zid), zname)
		_add(String(zid).replace("_", " "), "zone", String(zid), zname)
		for camp in z.get("camps", []):
			if String(camp.get("name", "")).length() >= 4:
				_add(String(camp.name), "camp", String(zid), String(camp.name))
	_add("หมู่บ้าน", "zone", "town", "หมู่บ้าน")
	_add("เมือง", "zone", "town", "หมู่บ้าน")
	for mid in monsters:
		var m: Dictionary = monsters[mid]
		var kind := "boss" if not (m.boss_of as Array).is_empty() else "monster"
		_add(String(m.name), kind, String(mid), String(m.name))
		_add(String(mid).replace("_", " "), kind, String(mid), String(m.name))
	for id in ItemData.JEWELS:
		_item(String(ItemData.JEWELS[id].name), "jewel", String(id))
		if not String(id).begins_with("wk") and not String(id).begins_with("lk_"):
			_add(String(id).replace("_", " "), "item", "jewel:" + String(id), String(ItemData.JEWELS[id].name))
	for id in ItemData.POTIONS:
		_item(String(ItemData.POTIONS[id].name), "potion", String(id))
	for id in ItemData.GEMS:
		_item(String(ItemData.GEMS[id].name), "gem", String(id))
		_add(String(id), "item", "gem:" + String(id), String(ItemData.GEMS[id].name))
	for id in MountData.ALL:
		_item(String(MountData.info(id).name), "mount", id)
		_add(id.replace("_", " "), "item", "mount:" + id, String(MountData.info(id).name))
	for id in RewardShop.COSTUMES:
		_item(String(RewardShop.COSTUMES[id].name), "costume", String(id))
	_item(ChatThreads.ISLE_WEAPON, "isle", "weapon")
	_item(ChatThreads.ISLE_WINGS, "isle", "wings")
	for id in ClassData.IDS:
		var cname := String(ClassData.get_class_data(id).get("name", ""))
		_add(cname, "class", String(id), cname)
		_add(String(id), "class", String(id), cname)
		_add(JobData.god_name(id), "class", String(id), cname)
	for alias in [["นักดาบ", "warrior"], ["นักรบ", "warrior"], ["อาเชอร์", "archer"], ["นักธนู", "archer"], ["เมจ", "mage"], ["จอมเวท", "mage"],
			["พระ", "priest"], ["ฮีลเลอร์", "priest"], ["ซัมมอน", "summoner"], ["แทงค์", "defender"], ["แทงก์", "defender"], ["แอสซาซิน", "assassin"],
			["บาร์ด", "bard"], ["หอก", "lancer"], ["ดาร์คลอร์ด", "darklord"]]:
		_add(String(alias[0]), "class", String(alias[1]), String(ClassData.get_class_data(StringName(alias[1])).get("name", "")))
	_keys.sort_custom(func(a, b): return String(a.key).length() > String(b.key).length())
	for k in _keys.size():
		var key := String(_keys[k].key)
		for g in _grams_of(key):
			if not _grams.has(g):
				_grams[g] = []
			(_grams[g] as Array).append(k)


static func _monster(id: StringName) -> Dictionary:
	if not monsters.has(id):
		monsters[id] = {"name": String(MonsterData.get_monster(id).get("name", "")), "homes": [], "boss_of": []}
	return monsters[id]


static func _item(name: String, kind: String, id: String) -> void:
	if name == "":
		return
	var key := "%s:%s" % [kind, id]
	items[key] = {"name": name, "kind": kind, "id": id}
	_add(name, "item", key, name)


static func _add(key: String, kind: String, id: String, name: String) -> void:
	key = key.to_lower().strip_edges()
	if key.length() < 2 or name == "":
		return
	var sig := "%s|%s|%s" % [key, kind, id]
	if _seen.has(sig):
		return
	_seen[sig] = true
	_keys.append({"key": key, "skel": skeleton(key), "kind": kind, "id": id, "name": name})


static func _grams_of(s: String) -> PackedStringArray:
	var out := PackedStringArray()
	var sk := skeleton(s)
	for i in sk.length() - 1:
		var g := sk.substr(i, 2)
		if not out.has(g):
			out.append(g)
	return out


## The line without tone marks (a hurried typist's spelling).
static func skeleton(s: String) -> String:
	for m in MARKS:
		s = s.replace(m, "")
	return s


## A line cleaned up for reading (see the class note).
static func normalize(text: String) -> String:
	var s := text.to_lower().replace("​", "").replace("‌", "").replace("‍", "").replace("﻿", "").strip_edges()
	# A run of one letter kept once (a laugh of fives kept as 555).
	var out := ""
	var run := 0
	var last := ""
	for ch in s:
		if ch == last:
			run += 1
		else:
			run = 1
			last = ch
		if ch == "5":
			if run <= 3:
				out += ch
			continue
		var thai_mark := ch.unicode_at(0) >= 0x0E31 and ch.unicode_at(0) <= 0x0E4E and not (ch.unicode_at(0) >= 0x0E3F and ch.unicode_at(0) <= 0x0E46)
		if run >= (2 if thai_mark else 3):
			continue
		out += ch
	for pair in EN_PHRASES:
		out = out.replace(String(pair[0]), String(pair[1]))
	for pair in TH:
		out = out.replace(String(pair[0]), String(pair[1]))
	# English words as the Thai they mean (whole words only; the word stays beside it).
	var rx := _word_rx()
	var parts: PackedStringArray = []
	var at := 0
	for m in rx.search_all(out):
		var w := m.get_string(0)
		parts.append(out.substr(at, m.get_start() - at))
		parts.append(String(EN.get(w, w)) if EN.has(w) else w)
		at = m.get_end()
	parts.append(out.substr(at))
	return "".join(parts).replace("  ", " ").strip_edges()


static var _rx: RegEx


static func _word_rx() -> RegEx:
	if _rx == null:
		_rx = RegEx.new()
		_rx.compile("[a-z]+")
	return _rx


## Every name in normalized line `n`: [{kind, id, name, at, fuzzy}], earlier first, a
## shorter name inside a longer one found left out.
static func find(n: String, fuzzy := true) -> Array:
	ensure()
	var out: Array = []
	var taken := PackedInt32Array()
	taken.resize(n.length())
	var sk := skeleton(n)
	for e in _keys:
		var key := String(e.key)
		var at := n.find(key)
		var fuzz := false
		if at < 0 and String(e.skel).length() >= 3 and String(e.skel) != key:
			at = _skel_at(n, sk, String(e.skel))
			fuzz = at >= 0
		if at < 0:
			continue
		# An English id must stand as a word ("mage" not inside "image").
		if _is_ascii(key) and not _word_at(n, at, key.length()):
			continue
		var free := true
		for k in range(at, mini(at + key.length(), n.length())):
			if taken[k] != 0:
				free = false
				break
		if not free:
			continue
		for k in range(at, mini(at + key.length(), n.length())):
			taken[k] = 1
		out.append({"kind": String(e.kind), "id": String(e.id), "name": String(e.name), "at": at, "fuzzy": fuzz})
	if out.is_empty() and fuzzy:
		var near := _fuzzy(n)
		if not near.is_empty():
			out.append(near)
	out.sort_custom(func(a, b): return int(a.at) < int(b.at))
	return out


static func _is_ascii(s: String) -> bool:
	for ch in s:
		if ch.unicode_at(0) > 127:
			return false
	return true


static func _word_at(n: String, at: int, length: int) -> bool:
	var before := n.substr(at - 1, 1) if at > 0 else " "
	var after := n.substr(at + length, 1) if at + length < n.length() else " "
	return not (before >= "a" and before <= "z") and not (after >= "a" and after <= "z")


## Where skeleton `skel` sits in line `n` (its skeleton `sk`), mapped back to n; -1 if not.
static func _skel_at(n: String, sk: String, skel: String) -> int:
	var at := sk.find(skel)
	if at < 0:
		return -1
	# Map the skeleton offset back: count the line's letters that are not marks.
	var seen := 0
	for k in n.length():
		if MARKS.has(n[k]):
			continue
		if seen == at:
			return k
		seen += 1
	return -1


## The one name line `n` comes closest to (one letter off, two for a long name), {} for none.
static func _fuzzy(n: String) -> Dictionary:
	var sk := skeleton(n)
	var hits := {}
	for i in sk.length() - 1:
		var g := sk.substr(i, 2)
		for k in _grams.get(g, []):
			hits[k] = int(hits.get(k, 0)) + 1
	var cands: Array = []
	for k in hits:
		var skel := String(_keys[k].skel)
		if skel.length() >= 6 and String(_keys[k].kind) in ["monster", "boss", "item", "zone"] and not _is_ascii(skel) and float(hits[k]) >= float(skel.length() - 1) * 0.5:
			cands.append(k)
	cands.sort_custom(func(a, b): return int(hits[a]) > int(hits[b]))
	var best := {}
	var best_d := 99
	for k in cands.slice(0, 10):
		var skel := String(_keys[k].skel)
		var limit := 1 if skel.length() < 9 else 2
		for start in range(0, maxi(1, sk.length() - skel.length() + 2)):
			for size in [skel.length() - 1, skel.length(), skel.length() + 1]:
				if start + size > sk.length() or size < 3:
					continue
				var d := distance(sk.substr(start, size), skel, limit)
				if d <= limit and d < best_d:
					best_d = d
					var e: Dictionary = _keys[k]
					best = {"kind": String(e.kind), "id": String(e.id), "name": String(e.name), "at": start, "fuzzy": true}
	return best


## Levenshtein distance of a and b, stopping early past `limit` (returns limit + 1).
static func distance(a: String, b: String, limit := 2) -> int:
	if absi(a.length() - b.length()) > limit:
		return limit + 1
	var prev := PackedInt32Array()
	prev.resize(b.length() + 1)
	for j in b.length() + 1:
		prev[j] = j
	for i in range(1, a.length() + 1):
		var cur := PackedInt32Array()
		cur.resize(b.length() + 1)
		cur[0] = i
		var row_min := i
		for j in range(1, b.length() + 1):
			var cost := 0 if a[i - 1] == b[j - 1] else 1
			cur[j] = mini(mini(prev[j] + 1, cur[j - 1] + 1), prev[j - 1] + cost)
			row_min = mini(row_min, cur[j])
		if row_min > limit:
			return limit + 1
		prev = cur
	return prev[b.length()]


## The names of `kind` in a find() result.
static func of_kind(found: Array, kinds: Array) -> Array:
	return found.filter(func(f): return kinds.has(String(f.kind)))


## Every known name (the truth checks read claims against them): name -> [{kind, id}].
static func all_names() -> Dictionary:
	ensure()
	var out := {}
	for e in _keys:
		if _is_ascii(String(e.key)):
			continue
		var nm := String(e.name)
		if not out.has(nm):
			out[nm] = []
		(out[nm] as Array).append({"kind": String(e.kind), "id": String(e.id)})
	return out
