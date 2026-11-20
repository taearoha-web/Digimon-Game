class_name ChatMind
extends RefCounted
## The world players reading what the hero writes, beyond ChatBrain's single intents:
## free conversation, every claim true. ChatBrain.reply asks here first (reply) and falls
## back to its own answers for a plain single intent; its small talk comes from here too
## (small_talk), so nothing ends in a canned loop.
##
## A line is cleaned up (ChatLexicon.normalize: typos, slang, English), the game's names
## in it are found (ChatLexicon.find: monsters, bosses, fields, items, classes, typed a
## little wrong too), and every act it asks for is read, in the order written (ACTS and
## ChatBrain.INTENTS): a greeting, a feeling, a joke, a question about the player itself
## (its level, gear, mount, pet, what it is doing, how long it has played, its guild's
## war...), about the hero's own sheet ("ชุดฉันสวยไหม"), about the game (where a monster
## lives, what a boss drops, where an item comes from and its drop rate, the forge's odds,
## the events, the festival, the dragon hunt), a trade, a duel, a guild invitation.
## Up to MAX_ACTS of them are answered in one reply (a multi-question line), each from
## ChatFacts (the game's tables at that moment) or the player's own sheet (WorldPlayers /
## WorldGear through ChatBrain.news_of). A short follow-up ("แล้วล่ะ", "ทำไม", "จริงดิ",
## "ที่ไหน", "เท่าไหร่") reads the topic and the name of the player's own last answer
## (its history entry keeps them: AiChat._remember). What the game cannot answer is said
## plainly ("ไม่แน่ใจ"), never guessed. A player's voice (VOICES, by its name) shapes the
## endings and the laugh, so two players never sound alike.

const MAX := 150
const MAX_ACTS := 3
## A line with one of these is about it, not the general one.
const PRE_COVERS := {"weekly": ["events", "help"], "loyk": ["events", "help"], "isle": ["events", "help"], "festival": ["events", "help"],
	"dragonhunt": ["events", "help", "isle"], "forge": ["enhance", "help"], "war": ["guild", "help", "events"], "playtime": ["level"]}
## Acts with a topic of their own: a "ที่ไหน" beside one asks about it.
const TOPICAL := ["skill", "guild", "shop", "help", "set", "wings", "mount", "gems", "isle", "events", "weekly", "loyk", "forge", "war", "pet",
	"festival", "dragonhunt", "duel", "trade", "enhance", "class"]
## Words that hold another act's word ("กิล" of "สกิล"): masked out when reading that act.
const MASKS := {"guild": ["สกิล"], "party": ["ปาร์ตี้ทำ"], "praise": ["เทพเจ้า", "ชุดเทพ", "เทพมังกร"], "leave": ["สบาย"], "sad": ["ฝันดี"], "greet": ["พิทักษ์"]}
## An act answered covers these (ChatBrain's own answer to them would say the same again).
const COVERS := {"forge": ["enhance", "help"], "events": ["help"], "festival": ["help", "events"], "war": ["guild", "help"],
	"dragonhunt": ["isle", "help", "events"], "guildinv": ["guild", "party"], "trade": ["come", "shop"], "doing": ["whereis"],
	"strong": ["class", "praise"], "playtime": ["level"], "tired": ["howru"], "sad": ["howru"], "morning": ["greet"], "game": ["happy"], "title": ["praise"], "pet": ["mount"], "joke": ["laugh"], "cute": ["praise"]}

## Acts beyond ChatBrain.INTENTS, all read (not the first only), in the order written.
const ACTS := [
	["privacy", ["อายุเท่าไหร่", "อายุกี่", "กี่ขวบ", "บ้านอยู่", "อยู่จังหวัด", "จังหวัดไหน", "ชื่อจริง", "เบอร์โทร", "ขอเบอร์", "ไอดีไลน์", "ขอไลน์", "แอดไลน์",
		"เฟสบุ๊ค", "facebook", "อินสตา", "instagram", "ที่อยู่จริง", "รหัสผ่าน", "password", "เรียนที่ไหน", "ทำงานที่ไหน", "หน้าตาจริง", "เพศอะไร"]],
	["money", ["เงินจริง", "โอนเงิน", "กี่บาท", "ขายไอดี", "ซื้อไอดี", "พร้อมเพย์", "เติมเงิน", "truemoney"]],
	["joke", ["มุก", "เรื่องตลก", "เล่าเรื่อง", "ตลกหน่อย", "ขำหน่อย"]],
	["sad", ["เศร้า", "เสียใจ", "ท้อ", "เบื่อ", "เซ็ง", "เหงา", "ร้องไห้", "แย่จัง", "หงุดหงิด", "โมโห", "เครียด", "ไม่ไหวแล้ว"]],
	["tired", ["เหนื่อย", "ง่วง", "จะนอน", "ไปนอน", "ฝันดี", "หิว", "กินข้าว", "ข้าวยัง"]],
	["happy", ["ดีใจ", "เย้", "สนุกจัง", "สนุกมาก", "มีความสุข", "ปลื้ม", "ฟินมาก"]],
	["love", ["รักนะ", "รักเธอ", "รักคุณ", "ชอบเธอ", "ชอบคุณ", "เป็นแฟน", "แต่งงาน", "มีแฟน", "จีบ"]],
	["cute", ["น่ารัก", "สวยจัง", "สวยมาก", "หล่อจัง", "หล่อมาก", "ชุดสวย", "ชุดเท่", "เท่จัง", "เท่มาก", "หน้าตาดี"]],
	["sorry", ["ขอโทษ", "โทษที", "ขอโทด", "ซอรี่"]],
	["laugh", ["555", "ฮ่า", "ขำ", "ตลก", "อิอิ"]],
	["name", ["ชื่ออะไร", "ชื่อไร", "เรียกว่าอะไร", "ชื่อเล่น"]],
	["pet", ["สัตว์เลี้ยง", "เพ็ท", "เพท"]],
	["playtime", ["เล่นมานาน", "เล่นมากี่", "เล่นนาน", "เล่นกี่ชั่วโมง", "เล่นมากี่วัน", "เริ่มเล่นเมื่อไหร่", "เล่นมาตั้งแต่"]],
	["doing", ["ทำอะไรอยู่", "ทำไรอยู่", "ทำอะไรอ่ะ", "ทำอะไรกัน", "ว่างไหม", "ยุ่งไหม", "กำลังทำอะไร", "ทำอะไรอยู่หรอ", "afk"]],
	["title", ["ฉายา", "ตำแหน่ง", "ไตเติ้ล", "title", "เทพเจ้าแห่ง", "เป็นเทพเจ้า"]],
	["dragonhunt", ["ล่ามังกร", "แต้มล่า"]],
	["festival", ["เทศกาล", "exp x3", "exp x5", "festival"]],
	["forge", ["ตีบวก", "เรทตี", "โอกาสติด", "ติดกี่", "บวกติด", "สุดสัปดาห์ตีบวก", "ตีบวกเรท"]],
	["events", ["อีเวนต์", "อีเว้น", "อีเว้นท์", "บอสโลก", "มอนทอง", "exp x2", "กิจกรรม", "โบนัส"]],
	["war", ["กิลด์วอ", "วอกิลด์", "รบกิลด์", "ลีก", "ปราสาท", "ใครชนะ", "แชมป์", "วอรอบ"]],
	["duel", ["ดวล", "ประลอง", "ตีกัน", "สู้กันไหม", "1v1"]],
	["trade", ["เทรด", "แลกของ", "แลกเปลี่ยน", "trade"]],
	["guildinv", ["เข้ากิลด์เรา", "มากิลด์", "ชวนเข้ากิลด์", "ย้ายกิลด์", "รับเข้ากิลด์", "มาอยู่กิลด์"]],
	["strong", ["อาชีพไหนเก่ง", "สายไหนเก่ง", "อาชีพไหนดี", "สายไหนดี", "เล่นอะไรดี", "อาชีพไหนโหด", "คลาสไหนดี", "คลาสไหนเก่ง"]],
	["bosskill", ["ใครล้มบอส", "ใครฆ่าบอส", "ใครปราบบอส", "บอสใครล้ม", "บอสตายยัง", "บอสเกิดยัง", "ล้มบอสได้", "บอสโดนล้ม"]],
	["online", ["กี่คน", "คนเยอะไหม", "ใครออน", "คนออน"]],
	# Real life: a world player is one of the game's AI players and says so, never makes up a life.
	["morning", ["อรุณสวัสดิ์", "ราตรีสวัสดิ์", "สวัสดิ์", "good morning"]],
	["game", ["เกมนี้สนุก", "เกมนี้ดี", "ชอบเกมนี้", "เกมนี้เป็นไง", "สนุกไหม", "เล่นสนุกไหม"]],
	["life", ["กินข้าว", "กินอะไร", "กินยัง", "กินหรือยัง", "ข้าวยัง", "นอนกี่โมง", "นอนยัง", "ชอบเพลง", "ฟังเพลง", "ชอบหนัง", "ดูหนัง", "ไปเที่ยว", "เที่ยวไหน",
		"ทำงาน", "เรียนอยู่", "ไปโรงเรียน", "ชอบกิน", "อาหาร", "มีแฟน", "อากาศ", "ฝนตก", "ร้อนจัง", "หนาวจัง", "แมว", "หมา", "ฝันร้าย", "ฝันอะไร", "พรุ่งนี้มาไหม", "พรุ่งนี้เล่นไหม", "มาเล่นอีกไหม"]],
]
## Words asking where, how often, how much and when.
const WHERE := ["ที่ไหน", "อยู่ไหน", "แถวไหน", "ฟาร์มที่", "ฟาร์ม", "หาได้", "ได้จาก", "ได้ที่", "ดรอปที่", "ดรอปจาก", "เก็บที่", "ไปไหน", "หาที่", "จากไหน", "หาไง", "หายังไง"]
const RATE := ["เรท", "กี่%", "กี่เปอร์", "โอกาส", "ดรอปเท่าไหร่", "ดรอปง่าย", "ดรอปยาก", "ดรอปไหม", "ออกง่าย", "%"]
## Asking whether a field boss stands now, and who brought it down.
const BOSS_UP := ["ใครฆ่า", "ใครล้ม", "ใครปราบ", "ใครตี", "ตายยัง", "ตายแล้ว", "ตายไหม", "เกิดยัง", "เกิดแล้ว", "เกิดไหม", "ยังอยู่", "อยู่ไหม", "เกิดตอนไหน", "เกิดเมื่อไหร่", "โดนล้ม", "ล้มยัง"]
const PRICE := ["ราคา", "กี่ทอง", "ขายเท่าไหร่", "เท่าไหร่"]
const LOOT := ["ดรอปอะไร", "ได้อะไร", "ให้อะไร", "ของอะไร", "ดรอป"]
const HAVE := ["มีไหม", "มีหรือยัง", "มียัง", "มีป่ะ", "ได้หรือยัง", "ได้ยัง", "มี", "ขี่", "ใส่"]
## The hero speaking of itself, and words of its public sheet.
const ME := ["ฉัน", "ผม", "หนู", "กู", "ข้า", "ของเรา", "เค้า", "ตัวเรา", "เราเก่ง", "เราเลเวล", "ชุดเรา", "อาวุธเรา"]
const SHEET := ["เลเวล", "ชุด", "อาวุธ", "เกราะ", "เก่ง", "กิลด์", "ใส่", "อาชีพ", "ปีก", "บวก", "คอสตูม", "หน้าตา", "ดาว", "หล่อ", "สวย", "เท่จัง", "เท่ไหม", "ดูเท่", "เท่ดี", "เท่มาก"]
## A short line that follows up the player's own last answer.
const FOLLOW := ["แล้วล่ะ", "ล่ะ", "ละ", "แล้วไง", "อีก", "ทำไม", "จริงเหรอ", "จริงดิ", "จริงหรอ", "จริงป่ะ", "แน่ใจ", "เหรอ", "หรอ", "อันนั้น", "ตัวนั้น", "มันล่ะ", "ต่อสิ", "แล้วยังไง"]
const QUESTION := ["?", "ไหม", "อะไร", "ยังไง", "ทำไม", "ใคร", "ที่ไหน", "เมื่อไหร่", "กี่", "หรือ", "เหรอ", "หรอ", "มั้ง", "ป่ะ", "เปล่า", "รึ"]

## Voices by a hash of the player's name: its laugh, its polite ending (by gender: 0 boy,
## 1 girl; "" none) and how often it uses it.
const VOICES := [
	{"laugh": "555", "end": ["", ""], "rate": 0.0},
	{"laugh": "5555", "end": ["ครับ", "ค่ะ"], "rate": 0.5},
	{"laugh": "ฮ่า ๆ", "end": ["นะ", "นะ"], "rate": 0.35},
	{"laugh": "555+", "end": ["จ้า", "จ้า"], "rate": 0.3},
	{"laugh": "อิอิ", "end": ["ฮะ", "คะ"], "rate": 0.25},
	{"laugh": "55555", "end": ["วะ", "เนอะ"], "rate": 0.2},
]

const JOKES := ["ทำไมสไลม์ไม่เคยแพ้ เพราะมันยืดหยุ่นไง 555", "มอนถามว่าทำไมตีแรง ก็บวกมาไง 555", "ตีบวกไม่ติดไม่เป็นไร ใจเราติดคุณแล้ว 555",
	"ยาเลือดเล็กบอกยาเลือดใหญ่ว่า โตแล้วอย่าลืมกันนะ 555", "ราชาเห็ดยักษ์ขี้เหงา เพราะไม่มีใครอยากเห็ด… เอ้ย เห็นหน้า 555"]
const SAD := ["ไม่เป็นไรนะ เดี๋ยวก็ดีขึ้น ไปล่ามอนด้วยกันไหม", "สู้ ๆ นะ มีอะไรเล่าให้ฟังได้", "พักก่อนก็ได้นะ เกมไม่หนีไปไหน", "ใจเย็น ๆ นะ เป็นกำลังใจให้"]
const TIRED := ["พักบ้างนะ สุขภาพสำคัญกว่าเลเวล", "ไปพักก่อนก็ได้ เดี๋ยวค่อยมาลุยกัน", "หิวก็ไปกินข้าวก่อนสิ มอนรอได้ 555"]
const SAD_ME := ["ไม่เศร้าหรอก สนุกดีออก", "นิดหน่อยตอนตีบวกแตก 555 แต่ไม่เป็นไร", "ไม่หรอก เล่นเกมก็มีความสุขดี"]
const TIRED_ME := ["นิดหน่อย แต่ยังไหว", "ไม่เหนื่อยหรอก สนุกอยู่", "เหนื่อยนิด ๆ เดี๋ยวพักแป๊บ"]
const HAPPY := ["ดีใจด้วยนะ!", "เย้ ดีใจด้วยเลย", "เห็นแล้วพลอยดีใจไปด้วย"]
const LOVE := ["555 เขินเลย เป็นเพื่อนเล่นเกมกันดีกว่านะ", "ขอบคุณนะ แต่ขอเป็นเพื่อนร่วมล่าก็พอ 555", "ใจดีจัง เป็นเพื่อนกันไปนาน ๆ นะ"]
const CUTE := ["ขอบคุณ เขินเลย", "จริงเหรอ ขอบคุณนะ", "ขอบคุณ ๆ วันนี้แต่งเต็มเลย 555"]
const SORRY := ["ไม่เป็นไรเลย", "ไม่ถือ ๆ", "ไม่เป็นไร เรื่องเล็ก"]
const LAUGH := ["%laugh", "%laugh ขำด้วย", "%laugh ใช่ ๆ", "ฮา ๆ"]
const PRIVACY := ["เรื่องส่วนตัวขอไม่บอกนะ คุยเรื่องในเกมกันดีกว่า", "อันนี้ขอเก็บไว้นะ ข้อมูลส่วนตัวไม่บอกใครเลย", "ขอไม่ให้ข้อมูลส่วนตัวนะ ในเกมคุยได้ทุกเรื่อง"]
const MONEY := ["ไม่ซื้อขายด้วยเงินจริงนะ ผิดกฎแล้วอันตรายด้วย", "เงินจริงไม่เอาด้วยนะ ซื้อขายในเกมด้วยทองดีกว่า"]
const DUEL := "ดวลกันตรง ๆ ไม่ได้นะ ไปลานประลองสิ จับคู่ให้เอง"
const TRADE_STALL := "แลกของตรง ๆ ไม่ได้นะ แต่ซื้อของในร้านเราได้ แวะดูเลย"
const TRADE_NONE := "แลกของกับเราตรง ๆ ไม่ได้นะ ถ้าอยากได้ของไปดูร้านในหมู่บ้าน หรือฝากขายที่ร้านก็ได้"
const UNSURE := ["อันนี้ไม่แน่ใจเลยนะ ไม่อยากตอบมั่ว", "ไม่รู้จริง ๆ ขอไม่เดาดีกว่า", "อันนี้ตอบไม่ได้ ไม่อยากบอกผิด ๆ"]
const UNKNOWN_NAME := ["ไม่รู้จักชื่อนั้นเลย พิมพ์ชื่อมอนหรือของอีกทีได้ไหม", "ไม่แน่ใจว่าหมายถึงอันไหน ลองพิมพ์ชื่อเต็มอีกทีสิ"]
const ASKED := ["ถามเรื่องมอน ของดรอป ตีบวก หรืออีเวนต์ได้นะ", "ถ้าเป็นเรื่องในเกมถามมาได้เลย", "อยากรู้เรื่องไหนในเกมบอกได้นะ"]
const SMALL := ["จริงเหรอ เล่าต่อสิ", "อ๋อ เข้าใจ ๆ", "เหมือนกันเลย", "ใช่ ๆ", "อืม น่าสนใจ", "โอเค ๆ", "งั้นเหรอ", "ฟังอยู่นะ ว่าต่อเลย"]
const REPEAT := ["ก็บอกไปแล้วไง", "เหมือนเดิมเลยนะ", "ตอบเหมือนเมื่อกี้แหละ"]


# --- Reading a line -----------------------------------------------------------------------

## What line `text` says: {n (normalized), found (ChatLexicon.find), acts [{act, at}],
## question, me (about the hero), level (a level number in it, 0 none)}.
static func read(text: String) -> Dictionary:
	var n := ChatLexicon.normalize(text)
	var question := QUESTION.any(func(q): return n.contains(String(q))) or _has(n, BOSS_UP)
	# A name typed a little wrong is looked for only in a question about something.
	var found := ChatLexicon.find(n, question or _has(n, WHERE + RATE + PRICE + LOOT))
	var spans: Array = found.map(func(f): return Vector2i(int(f.at), int(f.at) + String(f.name).length()))
	var padded := " %s " % n
	var tight := n.replace(" ", "")
	var acts: Array = []
	var seen := {}
	for table in [ACTS, ChatBrain.INTENTS]:
		for entry in table:
			var act := String(entry[0])
			if seen.has(act):
				continue
			var best := -1
			var pad := padded
			var tig := tight
			for mask in MASKS.get(act, []):
				pad = pad.replace(String(mask), "#".repeat(String(mask).length()))
				tig = tig.replace(String(mask), "#".repeat(String(mask).length()))
			for word in entry[1]:
				var w := String(word)
				var at := pad.find(w)
				var from_tight := false
				if at < 0:
					at = tig.find(w.strip_edges())
					from_tight = at >= 0
				if at < 0:
					continue
				at = maxi(0, at - (0 if from_tight else 1))
				# A word inside a name ("เทพ" of เกาะลอยฟ้าเทพมังกร) is not an act.
				if spans.any(func(s): return at >= s.x and at < s.y):
					continue
				if best < 0 or at < best:
					best = at
			if best >= 0:
				seen[act] = true
				acts.append({"act": act, "at": best})
	acts.sort_custom(func(a, b): return int(a.at) < int(b.at))
	var me := ME.any(func(w): return n.contains(String(w))) and SHEET.any(func(w): return n.contains(String(w)))
	return {"n": n, "found": found, "acts": acts, "question": question, "me": me, "level": _level_in(n)}


## Whether a line asks about something the game names (a monster, a field, an item...).
static func names_something(text: String) -> bool:
	var r := read(text)
	if not (r.found as Array).is_empty() and bool(r.question):
		return true
	# Several questions in one line ("สวัสดี เลเวลเท่าไหร่ อยู่ไหน").
	return bool(r.question) and (r.acts as Array).size() >= 2


static func _level_in(n: String) -> int:
	var rx := RegEx.new()
	rx.compile("(?:เลเวล|เวล|lv\\.?)\\s*(\\d{1,3})")
	var m := rx.search(n)
	return clampi(int(m.get_string(1)), 1, Game.MAX_LEVEL) if m != null else 0


## A feeling asked of the player ("เหนื่อยไหม", "เศร้าป่ะ"), not told by the hero.
static func _asks_me(r: Dictionary) -> bool:
	var n := String(r.n)
	return _has(n, ["ไหม", "หรือเปล่า", "?", "ป่ะ", "รึยัง", "เหรอ", "หรอ"]) and not _has(n, ["ฉัน", "ผม", "หนู", "เรา", "กู"])


static func _has(n: String, words: Array) -> bool:
	return words.any(func(w): return n.contains(String(w)))


static func _acts(r: Dictionary) -> Array:
	return (r.acts as Array).map(func(a): return String(a.act))


# --- Answering ------------------------------------------------------------------------------

## The answer to the line in `body` ({reply, action, topic, slot}), {} when ChatBrain's own
## single-intent answer is the right one (a plain greeting, a party invitation...).
static func reply(body: Dictionary, mine: Dictionary, tone: String, rng: RandomNumberGenerator) -> Dictionary:
	var text := String(body.get("text", ""))
	var p: Dictionary = body.get("player", {})
	var h: Dictionary = body.get("hero", {})
	var history: Array = body.get("history", [])
	var t := float(mine.get("t", body.get("t", WorldPresence.clock())))
	var r := read(text)
	var acts := _acts(r)
	var found: Array = r.found
	# Lines about the hero's own sheet.
	if bool(r.me):
		return _finish(_about_hero(r, p, h, rng), p, rng)
	if acts.is_empty() and found.is_empty():
		var follow := _follow_up(r, body, mine, tone, rng)
		return _finish(follow, p, rng) if not follow.is_empty() else {}
	# A deflection stands alone.
	for alone in ["privacy", "money", "rude"]:
		if acts.has(alone):
			if alone == "rude":
				return {}
			return _finish(_say(PRIVACY if alone == "privacy" else MONEY, rng, alone), p, rng)
	# A single intent ChatBrain answers itself.
	var legacy := ChatBrain.INTENTS.map(func(e): return String(e[0]))
	# (ChatBrain reads the line as typed: one in English or slang is answered here.)
	var same := acts.size() == 1 and ChatBrain.intent_of(text) == String(acts[0])
	var keeper := String(p.get("doing", "")) == "stall" and int(p.get("index", -1)) >= 0
	if found.is_empty() and same and legacy.has(acts[0]) and r.level == 0 and not (keeper and acts[0] == "shop"):
		return {}
	var parts: Array = []
	var action := "none"
	var topic := ""
	var slot := {}
	# The names first: a question about a monster, a field, an item or a class.
	if not found.is_empty():
		var a := _about_name(found[0], r, p, mine, t, rng)
		if not a.is_empty():
			parts.append(String(a.reply))
			topic = String(a.topic)
			slot = found[0]
			if String(a.get("action", "none")) != "none":
				action = String(a.action)
	var covered := {}
	# A line about a particular event is not about the events in general; "ที่ไหน" of
	# another topic ("สกิลอัปที่ไหน") is not where to level.
	for act in acts:
		for c in PRE_COVERS.get(act, []):
			covered[c] = true
		if TOPICAL.has(act):
			covered["where"] = true
			covered["whereis"] = true
		if act == "whereis":
			covered["where"] = true
	for act in acts:
		if parts.size() >= MAX_ACTS:
			break
		if covered.has(act):
			continue
		if not slot.is_empty() and act in ["where", "whereis", "help", "shop", "praise", "wings", "mount", "gems", "set", "gear", "class", "level", "enhance"]:
			# The name's answer already covers it.
			continue
		var a := _act(String(act), r, body, mine, tone, rng, t)
		if a.is_empty() or String(a.reply) == "":
			continue
		if parts.has(String(a.reply)):
			continue
		parts.append(String(a.reply))
		for c in COVERS.get(act, []):
			covered[c] = true
		if topic == "":
			topic = String(a.get("topic", act))
		if action == "none" and String(a.get("action", "none")) != "none":
			action = String(a.action)
	if parts.is_empty():
		return {}
	var out := {"reply": _join(parts), "action": action, "topic": topic}
	if not slot.is_empty():
		out["slot"] = {"kind": String(slot.kind), "id": String(slot.id), "name": String(slot.name)}
	return _finish(out, p, rng)


## One act of a line.
static func _act(act: String, r: Dictionary, body: Dictionary, mine: Dictionary, tone: String, rng: RandomNumberGenerator, t: float) -> Dictionary:
	var p: Dictionary = body.get("player", {})
	var h: Dictionary = body.get("hero", {})
	var history: Array = body.get("history", [])
	var i := int(p.get("index", -1))
	match act:
		"joke":
			return _say(JOKES, rng, act)
		"sad":
			return _say(SAD_ME if _asks_me(r) else SAD, rng, act)
		"tired":
			if _asks_me(r):
				var asked := _say(TIRED_ME, rng, act)
				if int(p.get("index", -1)) >= 0 and rng.randf() < 0.5:
					asked.reply = "%s %s" % [asked.reply, playtime_text(int(p.index), t)]
				return asked
			return _say(TIRED, rng, act)
		"happy":
			return _say(HAPPY, rng, act)
		"love":
			return _say(LOVE, rng, act)
		"cute":
			return _say(CUTE, rng, act)
		"sorry":
			return _say(SORRY, rng, act)
		"laugh":
			return _say(LAUGH, rng, act)
		"name":
			return {"reply": ["ชื่อ %s จ้า", "เรียก %s ก็ได้", "%s นี่แหละ"][rng.randi() % 3] % String(p.get("name", "")), "topic": act}
		"pet":
			return {"reply": pet_text(i, p), "topic": act}
		"playtime":
			return {"reply": playtime_text(i, t), "topic": act}
		"doing":
			return {"reply": doing_text(p, rng), "topic": act}
		"title":
			return {"reply": title_text(p), "topic": act}
		"dragonhunt":
			return {"reply": ChatFacts.dragon_hunt(t), "topic": act}
		"festival":
			return {"reply": ChatFacts.festival(t), "topic": act}
		"forge":
			var plus := _plus_in(String(r.n))
			if _has(String(r.n), ["ได้เท่าไหร่", "ได้กี่", "บวกเท่าไหร่", "บวกกี่", "+กี่", "+เท่าไหร่", "ของคุณ", "ตัวเอง"]):
				return {"reply": ChatBrain.gear_answer("gear", p, mine, rng), "topic": "gear"}
			if _has(String(r.n), ["สุดสัปดาห์", "เสาร์อาทิตย์", "วีคเอนด์"]):
				return {"reply": ChatFacts.forge_weekend(t), "topic": act}
			if plus < 0 and not _has(String(r.n), RATE + ["ยังไง", "วิธี", "เรท", "ติด", "คือ", "สอน"]):
				return {}
			return {"reply": ChatFacts.forge(t, plus), "topic": act}
		"events":
			if _has(String(r.n), ["มอนทอง"]):
				return {"reply": ChatFacts.golden(t), "topic": act}
			return {"reply": ChatFacts.events(t), "topic": act}
		"war":
			var g := WorldPlayers.guild_at(i, int(p.get("level", 1))) if i >= 0 else 0
			var out := ChatFacts.guild_war(t, g, _has(String(r.n), ["ใครชนะ", "แชมป์", "ปราสาท", "ลีก", "นำ", "อันดับ", "ผล", "แต้ม"]))
			var mine_row := ChatFacts.guild_standing(t, g)
			if mine_row != "" and (out + " " + mine_row).length() <= MAX:
				out += " " + mine_row
			return {"reply": out, "topic": act}
		"duel":
			return {"reply": DUEL, "topic": act}
		"trade":
			if String(p.get("doing", "")) == "stall" and i >= 0:
				return {"reply": TRADE_STALL, "action": "open_stall", "topic": act}
			return {"reply": TRADE_NONE, "topic": act}
		"guildinv":
			var guild := String(p.get("guild", ""))
			if guild != "":
				return {"reply": "ขอบคุณที่ชวนนะ แต่อยู่กิลด์ %s แล้ว ไม่ย้ายหรอก" % guild, "topic": act}
			return {"reply": "ยังเข้ากิลด์ไม่ได้เลย ต้อง Lv.%d ก่อน" % Game.GUILD_LEVEL, "topic": act}
		"strong":
			var cls := String(p.get("class", ""))
			return {"reply": "ทุกอาชีพเก่งคนละแบบ อยู่ที่ชอบเล่นแบบไหน อย่างเราเล่น%s %s" % [cls, ["สนุกดี", "ชอบมาก"][rng.randi() % 2]] if cls != "" else "ทุกอาชีพเก่งคนละแบบ ถึง Lv.%d ค่อยเลือกตามที่ชอบนะ" % ClassData.LINE_LEVEL, "topic": act}
		"bosskill":
			return {"reply": ChatFacts.boss_kills(t), "topic": act}
		"life":
			# A remark on the weather ("อากาศดีจัง") is small talk; a question gets the field's own.
			if _has(String(r.n), ["อากาศ", "ฝนตก", "ร้อน", "หนาว"]) and not bool(r.question):
				return {}
			return {"reply": life_text(String(r.n), p, rng), "topic": act}
		"morning":
			var hi := ChatBrain._answer("greet", "", p, h, history, tone, rng, mine)
			hi["topic"] = "greet"
			return hi
		"game":
			var fun := String(["สนุกสิ", "สนุกมาก", "ชอบนะ"][rng.randi() % 3])
			return {"reply": "%s %s" % [fun, playtime_text(i, t)] if i >= 0 else fun + " เล่นได้เรื่อย ๆ เลย", "topic": act}
		"skill":
			if _has(String(r.n), WHERE + ["ยังไง", "วิธี", "ทำไง"]):
				return {"reply": ChatBrain.help_text("skill"), "topic": act}
		"online":
			if not body.has("t"):
				return {}
			var n := 0
			for k in WorldPlayers.size():
				if not WorldPlayers.session_at(k, t).is_empty():
					n += 1
			return {"reply": "ตอนนี้ออนไลน์อยู่ %d คน" % n, "topic": act}
		"where":
			var lv := int(r.level)
			if lv > 0:
				return {"reply": "Lv.%d ไป%sเลย" % [lv, ChatFacts.field_for(lv, 0)], "topic": act}
		"shop":
			if String(p.get("doing", "")) == "stall" and i >= 0:
				var goods := ChatFacts.stall(i, t)
				if goods != "":
					return {"reply": goods, "action": "open_stall", "topic": "stall"}
		"party":
			# A party invitation in a longer line: ChatBrain's own rules decide.
			pass
	if ChatBrain.INTENTS.any(func(e): return String(e[0]) == act):
		var out := ChatBrain._answer(act, String(body.get("text", "")).to_lower(), p, h, history, tone, rng, mine)
		out["topic"] = act
		return out
	return {}


## A line naming a monster, a boss, a field, an item or a class.
static func _about_name(f: Dictionary, r: Dictionary, p: Dictionary, mine: Dictionary, t: float, rng: RandomNumberGenerator) -> Dictionary:
	var n := String(r.n)
	var id := String(f.id)
	var i := int(p.get("index", -1))
	match String(f.kind):
		"monster":
			return {"reply": ChatFacts.monster_where(StringName(id)), "topic": "monster"}
		"boss":
			var info := ChatFacts.boss_info(StringName(id))
			if _has(n, BOSS_UP):
				info = ChatFacts.boss_status(StringName(id), t)
				if info == "":
					info = ChatFacts.boss_info(StringName(id))
			elif _has(n, LOOT + RATE):
				var loot := ChatFacts.boss_loot(StringName(id))
				if loot != "":
					info = "%s %s" % [String(f.name), loot]
			return {"reply": info, "topic": "boss"}
		"zone", "camp":
			var here := String(p.get("place", ""))
			if String(f.kind) == "zone" and _has(n, ["อยู่", "ที่นี่", "แถวนี้"]) and r.question and not _has(n, ["มอน", "บอส", "มีอะไร", "เลเวลไหน"]):
				if here == String(f.name) or (id == "town" and here == "หมู่บ้าน"):
					return {"reply": ["ใช่ อยู่%sนี่แหละ", "อยู่%sจ้า"][rng.randi() % 2] % String(f.name), "topic": "whereis"}
				if here == "":
					return {"reply": "ตอนนี้ไม่ได้อยู่%sนะ" % String(f.name), "topic": "whereis"}
				return {"reply": "ไม่ได้อยู่%sนะ ตอนนี้อยู่%s" % [String(f.name), here], "topic": "whereis"}
			# The sky isle has its own full answer (gate, the owner's drop rates, the rare dragon).
			if StringName(id) == SkyIsleData.ID:
				return {"reply": ChatBrain.help_text("isle"), "topic": "zone"}
			return {"reply": ChatFacts.zone_info(StringName(id)), "topic": "zone"}
		"class":
			var own := String(p.get("class", ""))
			if own == String(f.name) and _has(n, ["เล่น", "เป็น", "สาย"]):
				return {"reply": "ใช่ เล่น%sอยู่ %s" % [own, ChatFacts.class_info(StringName(id)).trim_prefix(own).strip_edges()], "topic": "class"}
			return {"reply": ChatFacts.class_info(StringName(id)), "topic": "class"}
		"item":
			return _about_item(id, String(f.name), r, p, mine, t, rng)
	return {}


## An item named: does it have one (its own mount, wings, set), its price (its stall or the
## cheapest stall now), or where it comes from.
static func _about_item(key: String, name: String, r: Dictionary, p: Dictionary, mine: Dictionary, t: float, rng: RandomNumberGenerator) -> Dictionary:
	var n := String(r.n)
	var i := int(p.get("index", -1))
	var g: Dictionary = mine.get("gear", {})
	var kind := key.split(":")[0]
	var id := key.substr(key.find(":") + 1)
	var asks_have := _has(n, HAVE) and not _has(n, WHERE + RATE)
	if asks_have and kind == "mount" and not g.is_empty():
		var m: Dictionary = g.get("mount", {})
		if String(m.get("name", "")) == name:
			return {"reply": "มีสิ ขี่%s เลเวล %d อยู่" % [name, int(m.get("level", 1))], "topic": "mount"}
		var own := "ตอนนี้ขี่%s" % String(m.name) if not m.is_empty() else "ยังไม่มีสัตว์ขี่เลย"
		return {"reply": "ไม่มี%sนะ %s" % [name, own], "topic": "mount"}
	if asks_have and kind == "isle" and not g.is_empty():
		var w: Dictionary = g.get("wings", {})
		if id == "wings" and String(w.get("name", "")).begins_with(name):
			return {"reply": "มีสิ ใส่%sอยู่" % String(w.name), "topic": "wings"}
		return {"reply": "ยังไม่มี%sเลย %s" % [name, ChatFacts.item_source(key, t)], "topic": "item"}
	if _has(n, PRICE) and not _has(n, WHERE + RATE):
		if String(p.get("doing", "")) == "stall" and i >= 0:
			var own_price := ChatFacts.stall_price(i, key, t)
			if own_price != "":
				return {"reply": own_price, "action": "open_stall", "topic": "price"}
		return {"reply": price_text(key, name, t), "topic": "price"}
	var src := ChatFacts.item_source(key, t)
	if src == "":
		return {"reply": "%s ไม่แน่ใจว่าได้จากไหนนะ ไม่อยากบอกผิด" % name, "topic": "item"}
	return {"reply": src, "topic": "item"}


## The cheapest stall selling item `key` right now (ChatTrade.offers), or that none does.
static func price_text(key: String, name: String, t: float) -> String:
	var it: Dictionary = ChatLexicon.items.get(key, {})
	var kind := String(it.get("kind", ""))
	if kind in ["jewel", "potion", "gem"]:
		var offers := ChatFacts.offers(kind, String(it.id), t)
		if not offers.is_empty():
			var o: Dictionary = offers[0]
			var lot: Dictionary = o.lots[0]
			var what := ItemData.name_of(lot.item)
			if int(lot.item.get("count", 1)) > 1:
				what += " ×%d" % int(lot.item.count)
			return "ตอนนี้ร้าน%s ขาย%s ถูกสุด %s ทอง" % [String(o.name), what, ChatFacts.thousands(int(lot.price))]
		if kind == "potion" and ItemData.POTIONS.has(String(it.id)) and String(it.id) not in ["halloween", "hp_god"]:
			return "%s ร้านค้าในหมู่บ้านขาย %s ทอง ร้านผู้เล่นตอนนี้ไม่มี" % [name, ChatFacts.thousands(int(ItemData.POTIONS[String(it.id)].price))]
	return "ตอนนี้ไม่เห็นร้านไหนขาย%sเลย ลองถามในแชทโลกดู" % name


## The hero's own public sheet, asked about ("ชุดฉันสวยไหม", "ฉันเลเวลเท่าไหร่").
static func _about_hero(r: Dictionary, p: Dictionary, h: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var n := String(r.n)
	var lv := int(h.get("level", 1))
	var st := int(h.get("stars", 0))
	var mine_lv := int(p.get("level", 1))
	var sheet := "Lv.%d%s" % [lv, " ★%d" % st if st > 0 and lv >= Game.MAX_LEVEL else ""]
	if _has(n, ["ชุด", "อาวุธ", "เกราะ", "ใส่", "บวก", "ปีก", "คอสตูม", "หล่อ", "สวย", "เท่จัง", "เท่ไหม", "ดูเท่", "เท่ดี", "เท่มาก", "หน้าตา"]) and not (_has(n, ["เลเวล", "กี่ดาว"]) and not _has(n, ["ชุด", "อาวุธ", "ใส่"])):
		var gear: Dictionary = h.get("gear", {})
		var bits: PackedStringArray = []
		for slot in ["weapon", "armor", "helm", "boots"]:
			var it: Dictionary = gear.get(slot, {})
			if not it.is_empty() and int(it.get("plus", 0)) > 0:
				bits.append("%s +%d" % [ChatThreads.slot_word(slot), int(it.plus)])
		var w: Dictionary = gear.get("wings", {})
		var out := ""
		if String(h.get("costume", "")) != "":
			out = "ใส่%sอยู่ %s" % [String(h.costume), ["สวยดีนะ", "เข้ากับคุณเลย", "เท่ดี"][rng.randi() % 3]]
		elif not w.is_empty() and String(w.get("name", "")) != "":
			out = "มี%sด้วย เท่ดีนะ" % String(w.name)
		else:
			out = ["ชุดดูดีนะ", "ใส่แล้วดูเท่ดี", "ดูเข้ากันดีนะ"][rng.randi() % 3]
		if not bits.is_empty():
			out += " " + " ".join(bits)
		elif gear.is_empty() and not h.has("gear"):
			out = "ดูไม่ค่อยชัดว่าใส่อะไรอยู่ แต่ดูดีนะ"
		return {"reply": out.strip_edges(), "topic": "hero_gear"}
	if _has(n, ["เก่ง", "เทพ", "โหด"]):
		if lv > mine_lv:
			return {"reply": "%s เก่งกว่าเราอีก!" % sheet, "topic": "hero"}
		if lv < mine_lv:
			return {"reply": "%s ก็เก่งแล้ว อีกหน่อยก็ตามทันเรา" % sheet, "topic": "hero"}
		return {"reply": "%s เท่ากันเลย สูสี" % sheet, "topic": "hero"}
	if _has(n, ["กิลด์"]):
		var guild := String(h.get("guild", ""))
		return {"reply": "คุณอยู่กิลด์ %s นี่" % guild if guild != "" else "คุณยังไม่มีกิลด์นะ ถึง Lv.%d ไปสมัครได้" % Game.GUILD_LEVEL, "topic": "hero"}
	if _has(n, ["อาชีพ"]):
		var cls := String(h.get("class", ""))
		return {"reply": "คุณเล่น%sนี่" % cls if cls != "" else "ยังไม่ได้เลือกอาชีพเลยนี่ ถึง Lv.%d ไปเลือกได้" % ClassData.LINE_LEVEL, "topic": "hero"}
	return {"reply": "คุณ %s แล้ว %s" % [sheet, "ไวดีนะ" if lv >= mine_lv else "สู้ ๆ"], "topic": "hero"}


## A short line after the player's own answer: why, really, more, where, how much.
static func _follow_up(r: Dictionary, body: Dictionary, mine: Dictionary, tone: String, rng: RandomNumberGenerator) -> Dictionary:
	var n := String(r.n)
	if n.length() > 30 or not _has(n, FOLLOW + ["ที่ไหน", "เท่าไหร่", "ดรอปอะไร", "คุณล่ะ"]):
		return {}
	var history: Array = body.get("history", [])
	var last := {}
	for k in range(history.size() - 1, -1, -1):
		if String(history[k].get("who", "")) == "player":
			last = history[k]
			break
	var topic := String(last.get("topic", ""))
	var slot: Dictionary = last.get("slot", {})
	if topic == "":
		return {}
	var p: Dictionary = body.get("player", {})
	var t := float(mine.get("t", body.get("t", WorldPresence.clock())))
	# A name carried over: "ดรอปอะไร", "ที่ไหน", "เท่าไหร่" about the same thing.
	if not slot.is_empty():
		var again := read("%s %s" % [String(slot.name), n])
		if not (again.found as Array).is_empty():
			var a := _about_name(again.found[0], again, p, mine, t, rng)
			if not a.is_empty() and String(a.reply) != String(last.get("text", "")):
				a["slot"] = slot
				return a
	if _has(n, ["ทำไม"]):
		return {"reply": _why(topic, p, mine, t, rng), "topic": topic}
	if _has(n, ["จริง", "แน่ใจ", "เหรอ", "หรอ"]):
		return {"reply": cut("%s %s" % [["จริงสิ", "จริง ๆ", "ไม่ได้โม้นะ"][rng.randi() % 3], String(last.get("text", ""))]), "topic": topic}
	if _has(n, ["คุณล่ะ", "แล้วคุณ"]) and topic.begins_with("hero"):
		var lv := ChatBrain._answer("level", "", p, body.get("hero", {}), history, tone, rng, mine)
		return {"reply": String(lv.reply), "topic": "level"}
	return {}


static func _why(topic: String, p: Dictionary, mine: Dictionary, t: float, rng: RandomNumberGenerator) -> String:
	var i := int(p.get("index", -1))
	match topic:
		"level", "stars", "playtime":
			if i >= 0:
				return "ก็เก็บมาเรื่อย ๆ นั่นแหละ %s" % playtime_text(i, t)
		"doing", "whereis":
			return "ก็สนามนี้ตรงเลเวลเราไง EXP ดี"
		"forge", "enhance":
			return "เพราะเกินกว่านั้นโอกาสติดลดลงเรื่อย ๆ ไง ตามกฎช่างตีเลย"
		"item", "boss", "monster":
			return "ก็ตามที่ช่างกับเกมบอกไว้แหละ ของหายากก็ดรอปยากหน่อย"
	return ["ก็นั่นแหละ 555", "อธิบายยากเหมือนกันนะ", "ไม่รู้สิ รู้สึกงั้นแหละ"][rng.randi() % 3]


## Real-life small talk, answered as the AI player it is (nothing made up about a life it
## does not have); the weather is the field's own (its zone's weather) when it stands in one.
static func life_text(n: String, p: Dictionary, rng: RandomNumberGenerator) -> String:
	if _has(n, ["อากาศ", "ฝนตก", "ร้อน", "หนาว"]):
		var here := String(p.get("place", ""))
		var weather := ""
		for z in ChatLexicon.zones:
			if String(ChatLexicon.zones[z].name) == here:
				weather = String(WEATHER.get(String(ZoneData.get_zone(z).get("weather", "")), ""))
		if weather != "":
			return "ที่%sตอนนี้%s สวยดีนะ" % [here, weather]
		return ["ในเกมอากาศดีตลอดแหละ 555", "เราเป็นผู้เล่น AI ไม่รู้สึกร้อนหนาวหรอก แต่คุณดูแลตัวเองด้วยนะ"][rng.randi() % 2]
	if _has(n, ["กิน", "ข้าว", "อาหาร"]):
		return ["เราเป็นผู้เล่น AI ไม่ได้กินข้าวหรอก 555 คุณกินหรือยัง", "ผู้เล่น AI ไม่ต้องกินข้าว แต่คุณอย่าลืมกินนะ"][rng.randi() % 2]
	if _has(n, ["นอน"]):
		return "ผู้เล่น AI ไม่ต้องนอนหรอก แต่ก็ออนตามเวลาของเรานะ คุณพักผ่อนด้วยล่ะ"
	if _has(n, ["เพลง", "หนัง"]):
		return ["ชอบเพลงในเกมนี่แหละ ฟังตอนล่ามอนเพลินดี", "เป็นผู้เล่น AI เลยฟังแต่เพลงในเกม 555 เพลงหมู่บ้านเพราะนะ"][rng.randi() % 2]
	if _has(n, ["พรุ่งนี้", "มาเล่นอีก"]):
		return "ออนตามเวลาเล่นของเรานะ ถ้าเห็นชื่อในเกมก็ทักมาได้เลย"
	if _has(n, ["แมว", "หมา"]):
		return "น่ารักจัง ในเกมก็มีสัตว์เลี้ยงนะ ตามติดตลอดเลย"
	if _has(n, ["ฝันร้าย"]):
		return "ไม่เป็นไรนะ แค่ฝัน เข้าเกมมาล่ามอนให้ลืม ๆ ไปดีกว่า"
	return ["เราเป็นผู้เล่น AI ของเกมนะ ชีวิตนอกเกมไม่มีหรอก 555 แต่ฟังคุณเล่าได้", "ผู้เล่น AI อยู่แต่ในเกมแหละ เล่าเรื่องของคุณให้ฟังหน่อยสิ"][rng.randi() % 2]


## A field's weather (its zone's "weather") as the chat says it.
const WEATHER := {"snow": "หิมะตก", "petals": "กลีบดอกไม้ปลิว", "sand": "พายุทรายพัด", "fireflies": "หิ่งห้อยบินเต็มเลย", "rain": "ฝนตก", "embers": "ประกายไฟลอยฟุ้ง",
	"bubbles": "ฟองน้ำลอยเต็มเลย", "motes": "ละอองแสงลอยฟุ้ง", "wisps": "แสงวิญญาณลอยไปมา", "brimstone": "ควันกำมะถันฟุ้ง", "windstream": "ลมพัดแรง", "runes": "อักษรเวทลอยวนอยู่"}


# --- The player's own sheet -------------------------------------------------------------

static func pet_text(i: int, p: Dictionary) -> String:
	if i < 0:
		return "มีสัตว์เลี้ยงตัวนึงตามอยู่ ไว้ดูที่การ์ดนะ"
	var pet := PetData.get_pet(WorldPlayers.pet_of(i))
	if pet.is_empty():
		return "ยังไม่มีสัตว์เลี้ยงเลย"
	return "สัตว์เลี้ยงเป็น%s %s ตามติดตลอด" % [String(pet.name), String(pet.get("element_name", ""))]


static func playtime_text(i: int, t: float) -> String:
	if i < 0:
		return "เล่นมาสักพักแล้วล่ะ"
	var hours := int(WorldPlayers.played_minutes(i, t) / 60.0)
	var days := int((t - WorldPlayers.joined_at(i)) / 86400.0)
	if days <= 0:
		return "เพิ่งเริ่มเล่นวันนี้เอง เล่นไป %d ชั่วโมง" % hours if hours > 0 else "เพิ่งเริ่มเล่นวันนี้เอง"
	return "เริ่มเล่นมา %d วัน เล่นไปราว %d ชั่วโมง" % [days, hours]


static func doing_text(p: Dictionary, rng: RandomNumberGenerator) -> String:
	var here := String(p.get("place", ""))
	var star := int(p.get("level", 1)) >= Game.MAX_LEVEL
	match String(p.get("doing", "")):
		"party":
			return "ล่าอยู่กับคุณนี่ไง 555"
		"stall":
			return "ตั้งร้านขายของอยู่ในหมู่บ้าน แวะมาได้นะ"
		"boss":
			return "ล่าบอสอยู่ที่%s" % here if here != "" else "ล่าบอสอยู่"
		"help":
			return "พาเพื่อนเก็บดาวอยู่ที่%s" % here if here != "" else "พาเพื่อนเก็บดาวอยู่"
		"errand":
			return "แวะหมู่บ้านทำธุระแป๊บ เดี๋ยวกลับไปล่าต่อ"
		"hunt":
			if here != "":
				return ["เก็บ%sอยู่ที่%s", "ฟาร์ม%sที่%sอยู่"][rng.randi() % 2] % ["ดาว" if star else "เลเวล", here]
	if here == "":
		return "ตอนนี้ไม่ได้ทำอะไร ออฟไลน์อยู่"
	return "อยู่ที่%s" % here


static func title_text(p: Dictionary) -> String:
	var lv := int(p.get("level", 1))
	var st := int(p.get("stars", 0))
	var i := int(p.get("index", -1))
	var god := WorldPlayers.god_title({"level": lv, "stars": st, "class": WorldPlayers.entry(i)["class"]}) if i >= 0 else ""
	var g := WorldPlayers.guild_at(i, lv) if i >= 0 else 0
	var crown := " กิลด์%sเป็น%sสัปดาห์นี้ด้วย" % [WorldPlayers.guild_name(g), GuildLeague.CASTLE_TITLE] if g > 0 and ChatFacts.castle_king(WorldPresence.clock()) == g else ""
	if god != "":
		return "เป็น%sแล้ว%s" % [god, crown]
	return ("ยังไม่ได้เป็นเทพเจ้า ต้อง Lv.%d ★%d ก่อน" % [Game.MAX_LEVEL, JobData.GOD_STARS]) + crown


static func _plus_in(n: String) -> int:
	var rx := RegEx.new()
	rx.compile("\\+\\s*(\\d{1,2})")
	var m := rx.search(n)
	if m == null:
		return -1
	# "+10 ติดกี่%" asks about the try to +10 (from +9).
	return clampi(int(m.get_string(1)) - 1, 0, ItemData.MAX_PLUS - 1)


# --- Small talk -------------------------------------------------------------------------

## Small talk for a line nothing else answers: a question it cannot answer is said so
## (and what it can talk about), a statement gets a reaction, now and then from what the
## player is really doing; never the same as its last answers.
static func small_talk(text: String, p: Dictionary, tone: String, rng: RandomNumberGenerator, history: Array) -> String:
	var r := read(text)
	var said: Array = []
	for line in history:
		if String(line.get("who", "")) == "player":
			said.append(String(line.get("text", "")))
	var pool: Array = []
	if String(r.n).strip_edges().replace("?", "").replace(".", "").replace("!", "") == "":
		pool = ["มีอะไรเหรอ พิมพ์มาได้เลยนะ", "หืม? ว่ามาเลย", "ว่าไง มีอะไรให้ช่วยไหม"]
	elif bool(r.question):
		for u in UNSURE:
			for a in ASKED:
				pool.append("%s %s" % [u, a])
	else:
		pool = SMALL.duplicate()
		var idle := ChatBrain._idle(p, tone, rng)
		pool.append(idle)
		pool.append(idle)
	pool = pool.filter(func(x): return not said.any(func(s): return String(s).begins_with(String(x))))
	if pool.is_empty():
		pool = SMALL.duplicate()
	return String(pool[rng.randi() % pool.size()])


# --- Voice -------------------------------------------------------------------------------

static func voice_of(p: Dictionary) -> Dictionary:
	return VOICES[absi(hash("voice|" + String(p.get("name", "")))) % VOICES.size()]


## The reply in the player's own voice: its laugh, now and then its ending; cut to MAX at a
## space so no number is cut in half.
static func _finish(out: Dictionary, p: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	if out.is_empty():
		return out
	var v := voice_of(p)
	var text := String(out.get("reply", "")).replace("%laugh", String(v.laugh))
	# Its own laugh for a "555" that stands alone (never one inside a price: "16,555").
	if String(v.laugh) != "555":
		text = _laugh_rx().sub(text, String(v.laugh), true)
	var end := String(v.end[clampi(int(p.get("gender", 0)), 0, 1)])
	if end != "" and rng.randf() < float(v.rate) and not text.ends_with("?") and not text.ends_with("ไหม") and text.length() < MAX - 6:
		text = "%s %s" % [text, end]
	out["reply"] = cut(text)
	if not out.has("action"):
		out["action"] = "none"
	return out


static var _laugh: RegEx


static func _laugh_rx() -> RegEx:
	if _laugh == null:
		_laugh = RegEx.new()
		_laugh.compile("(?<![\\d,.])555(?![\\d+,])")
	return _laugh


## `text` at most MAX letters, cut at a space.
static func cut(text: String) -> String:
	if text.length() <= MAX:
		return text
	var at := text.left(MAX).rfind(" ")
	return text.left(at if at > 40 else MAX).strip_edges()


static func _join(parts: Array) -> String:
	var out := ""
	for part in parts:
		var s := String(part)
		if out == "":
			out = s
		elif (out + " " + s).length() <= MAX:
			out += " " + s
	return out


static func _say(pool: Array, rng: RandomNumberGenerator, topic := "") -> Dictionary:
	return {"reply": String(pool[rng.randi() % pool.size()]), "action": "none", "topic": topic}


## The answers each world player gave in this talk (by name), longer than the short
## history the chat keeps: a talk that starts afresh (empty history) clears it.
const SAID_KEEP := 24
static var _said := {}
## The players who said their hello in the talk now (a talk starts with an empty history).
static var _greeted := {}


static func greeted(who: String) -> bool:
	return who != "" and _greeted.has(who)


static func forget_greeting(who: String) -> void:
	_greeted.erase(who)


static func mark_greeted(who: String) -> void:
	if who == "":
		return
	if _greeted.size() > 512:
		_greeted.clear()
	_greeted[who] = true


## A reply already given in this talk (the short history and _said): said once more with a
## word that it was, so the same line is never spammed back word for word.
static func unrepeat(out: Dictionary, history: Array, rng: RandomNumberGenerator, who := "") -> Dictionary:
	var recent: Array = []
	for k in range(history.size() - 1, -1, -1):
		if String(history[k].get("who", "")) != "player":
			continue
		recent.append(String(history[k].get("text", "")))
		if recent.size() >= 8:
			break
	if who != "":
		if history.is_empty():
			_said[who] = []
		recent.append_array(_said.get(who, []))
	var said := String(out.get("reply", ""))
	if recent.has(said):
		var start := rng.randi() % REPEAT.size()
		var found := false
		for k in REPEAT.size():
			var again := cut("%s %s" % [String(REPEAT[(start + k) % REPEAT.size()]), said])
			if not recent.has(again):
				out["reply"] = again
				found = true
				break
		if not found:
			out["reply"] = "ตอบไปหลายรอบแล้วนะ 555 ถามเรื่องอื่นก็ได้"
	if who != "":
		var mine: Array = _said.get(who, [])
		mine.append(String(out.reply))
		while mine.size() > SAID_KEEP:
			mine.remove_at(0)
		_said[who] = mine
	return out
