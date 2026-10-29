class_name ChatBrain
extends RefCounted
## The world players' own answers, made in the game: free, instant and offline. A line
## is read for what the hero is after (a party, the stall, where to hunt, a level, a
## goodbye...) and the player answers from its own state (class, level, stars, what it is
## doing and where, its play style) with the action that goes with it, like the account
## server's chat would (AiChat.request_body is the input, {reply, action} the output).

## Words that mark what a line is about, checked in this order.
const INTENTS := [
	["bot", ["บอท", "bot", "เป็นคนจริง", "คนจริงไหม", "ai ", " ai", "เอไอ"]],
	["leave", ["ออกจากปาร์ตี้", "ออกจากตี้", "ออกตี้", "แยกกัน", "ไปก่อนนะ", "บาย", "ลาก่อน", "bye", "ไว้เจอกัน"]],
	["party", ["ปาร์ตี้", "ปาตี้", "ตี้", "party", "ไปด้วยกัน", "ไปด้วยไหม", "ไปล่าด้วย", "ล่าด้วยกัน", "เก็บเลเวลด้วย", "เข้ากลุ่ม", "จอยกัน", "จอยไหม"]],
	["shop", ["ขายอะไร", "ขายไหม", "มีอะไรขาย", "ดูร้าน", "ดูของ", "ซื้อ", "ร้าน", "ราคา", "ขายของ", "รับซื้อ", "ของดี"]],
	["where", ["ไปไหนดี", "เก็บเลเวลที่ไหน", "ที่ไหนดี", "สนามไหน", "ด่านไหน", "อยู่ไหน", "ที่ไหน", "แมพไหน"]],
	["level", ["เลเวลเท่าไหร่", "กี่เลเวล", "เวลเท่าไหร่", "กี่เวล", "เลเวลอะไร", "lv", "เวลไร", "กี่ดาว"]],
	["enhance", ["ตีบวก", "หินตีบวก", "+7", "+8", "+9", "+10", "บวกแตก"]],
	["skill", ["สกิล", "skill", "ท่าไหน", "อัปอะไร", "อัพอะไร"]],
	["guild", ["กิลด์", "guild", "กิล"]],
	["class", ["อาชีพ", "คลาส", "class", "เล่นสายไหน"]],
	["thanks", ["ขอบคุณ", "ขอบใจ", "thx", "thank", "แต๊งกิ้ว"]],
	["praise", ["เก่ง", "เทพ", "สุดยอด", "โหด", "เจ๋ง", "ปัง"]],
	["greet", ["สวัสดี", "หวัดดี", "ดีจ้า", "ดีครับ", "ดีค่ะ", "hello", "hi", "ทัก"]],
]

const GREET := ["สวัสดีจ้า!", "หวัดดี~ เล่นสนุกไหม", "ดีจ้า วันนี้มาเก็บเลเวลเหรอ", "สวัสดี! มีอะไรให้ช่วยไหม"]
const THANKS := ["ยินดีจ้า!", "ไม่เป็นไรเลย", "ด้วยความยินดี ไว้มีอะไรทักมาได้นะ"]
const PRAISE := ["555 ยังไม่เทพหรอก ฝึกอยู่", "ขอบคุณนะ เขินเลย", "เดี๋ยวคุณก็เก่งกว่านี้อีก!"]
const BOT := ["เป็นผู้เล่น AI ของเกมนี้แหละ 555 แต่เล่นจริงจังนะ", "ใช่ ผู้เล่น AI เอง แต่ก็เก็บเลเวลเหมือนกันนะ!"]
const YES := ["ได้เลย ไปด้วยกัน!", "โอเค ลุยกัน!", "จัดไป เดี๋ยวตามไปนะ", "ยินดีเลย ไปล่ากัน!"]
const BUSY_STALL := ["ตอนนี้พักขายของอยู่ ไว้รอบหน้านะ", "ขอเฝ้าร้านก่อนนะ ไว้ไปด้วยกันวันหลัง"]
const BUSY_BOSS := ["กำลังล่าบอสอยู่ ไว้รอบหน้านะ", "ติดล่าบอสอยู่ ขอโทษนะ"]
const ALREADY := ["ก็อยู่ด้วยกันอยู่แล้วนี่ 555", "อยู่ในตี้แล้วจ้า ลุยต่อเลย"]
const BYE := ["ไว้เจอกันใหม่นะ!", "บายจ้า ขอบคุณที่ชวนนะ", "ไปล่าต่อแล้วนะ แล้วเจอกัน"]
const BYE_STRANGER := ["บายจ้า!", "ไว้เจอกันใหม่นะ", "โชคดีนะ!"]
const SHOP_OPEN := ["เชิญดูของได้เลย ของดีที่หามาเอง", "แวะดูก่อน ราคาเป็นมิตร!", "มีของดีอยู่หลายชิ้น ดูได้เลย"]
const NO_SHOP := ["ไม่ได้ตั้งร้านนะ ลองไปดูร้านในหมู่บ้านสิ", "ตอนนี้ไม่ได้ขายของ ร้านคนอื่นในหมู่บ้านมีเยอะเลย"]
const ENHANCE := ["ตีบวกถึง +6 ค่อนข้างปลอดภัย หลังจากนั้นลุ้นเอานะ", "เพิ่งตีบวกแตกมา เศร้าเลย 555", "เก็บหินตีบวกเยอะ ๆ ก่อนค่อยตีนะ"]
const SKILL := ["ไปเรียนสกิลกับครูฝึกในหมู่บ้านได้เลย", "อัปสกิลหลักก่อน แล้วค่อยเก็บสกิลเสริม", "สกิลใหม่ปลดตามเลเวล อย่าลืมไปหาครูฝึกนะ"]
const IDLE := ["อืม ๆ", "จริงเหรอ 555", "ใช่ ๆ", "น่าสนใจนะ", "ฮ่า ๆ เข้าใจเลย"]


## {reply, action} for the line in `body` (AiChat.request_body).
static func reply(body: Dictionary) -> Dictionary:
	var text := String(body.get("text", "")).to_lower()
	var p: Dictionary = body.get("player", {})
	var h: Dictionary = body.get("hero", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%s|%d" % [p.get("name", ""), text, (body.get("history", []) as Array).size()])
	var intent := intent_of(text)
	var doing := String(p.get("doing", ""))
	var in_party := bool(p.get("inParty", false))
	match intent:
		"bot":
			return _say(BOT, rng)
		"leave":
			if in_party:
				return _say(BYE, rng, "leave_party")
			return _say(BYE_STRANGER, rng)
		"party":
			if in_party:
				return _say(ALREADY, rng)
			if doing == "stall":
				return _say(BUSY_STALL, rng)
			if doing == "boss" and rng.randf() < 0.6:
				return _say(BUSY_BOSS, rng)
			return _say(YES, rng, "join_party")
		"shop":
			if doing == "stall":
				return _say(SHOP_OPEN, rng, "open_stall")
			return _say(NO_SHOP, rng)
		"where":
			return {"reply": _where(p, h, rng), "action": "none"}
		"level":
			var stars := int(p.get("stars", 0))
			var lv := "Lv.%d%s" % [int(p.get("level", 1)), " ★%d" % stars if stars > 0 else ""]
			return {"reply": ["ตอนนี้ %s แล้ว" % lv, "%s เองจ้า ยังต้องเก็บอีกเยอะ" % lv, "%s แล้ว! ขึ้นช้าแต่ชัวร์ 555" % lv][rng.randi() % 3], "action": "none"}
		"enhance":
			return _say(ENHANCE, rng)
		"skill":
			return _say(SKILL, rng)
		"guild":
			var guild := String(p.get("guild", ""))
			if guild != "":
				return {"reply": "อยู่กิลด์ %s จ้า ถึง Lv.100 แล้วมาสมัครได้นะ" % guild, "action": "none"}
			return {"reply": ["ยังไม่มีกิลด์เลย ต้องถึง Lv.100 ก่อน", "กิลด์รับตอน Lv.100 รีบเก็บเลเวลกัน!"][rng.randi() % 2], "action": "none"}
		"class":
			var cls := String(p.get("class", ""))
			return {"reply": ["เล่น%sอยู่ สนุกดีนะ" % cls, "สาย%s เลย ชอบมาก" % cls, "%s จ้า ลองเล่นดูสิ" % cls][rng.randi() % 3], "action": "none"}
		"thanks":
			return _say(THANKS, rng)
		"praise":
			return _say(PRAISE, rng)
		"greet":
			return _say(GREET, rng)
	return {"reply": _idle(p, rng), "action": "none"}


## What a line is about ("" when nothing matches).
static func intent_of(text: String) -> String:
	var lower := " %s " % text.to_lower()
	for entry in INTENTS:
		for word in entry[1]:
			if lower.contains(String(word)):
				return String(entry[0])
	return ""


static func _say(pool: Array, rng: RandomNumberGenerator, action := "none") -> Dictionary:
	return {"reply": String(pool[rng.randi() % pool.size()]), "action": action}


## Where to hunt: the field that fits the hero's level, and where the player is.
static func _where(p: Dictionary, h: Dictionary, rng: RandomNumberGenerator) -> String:
	var zone := WorldPlayers.hunting_zone(int(h.get("level", 1)), int(h.get("stars", 0)))
	var fit := String(ZoneData.get_zone(zone).get("name", "สนามถัดไป"))
	var here := String(p.get("place", ""))
	if here != "" and rng.randf() < 0.5:
		return "อยู่ที่%s จ้า ส่วนเลเวลคุณไป%sดีกว่านะ" % [here, fit]
	return ["เลเวลคุณไป%sเลย มอนกำลังดี" % fit, "ลอง%sดูสิ EXP ดีเลย" % fit][rng.randi() % 2]


## Small talk from what the player is doing.
static func _idle(p: Dictionary, rng: RandomNumberGenerator) -> String:
	var here := String(p.get("place", ""))
	match String(p.get("doing", "")):
		"stall":
			if rng.randf() < 0.5:
				return "พักขายของอยู่ แวะดูร้านได้นะ"
		"hunt":
			if here != "" and rng.randf() < 0.5:
				return "กำลังเก็บเลเวลอยู่ที่%s เลย" % here
		"boss":
			if rng.randf() < 0.5:
				return "ล่าบอสอยู่ ขอโฟกัสแป๊บ 555"
		"party":
			if rng.randf() < 0.5:
				return "ลุยต่อเลย เดี๋ยวช่วยตีเอง!"
	return String(IDLE[rng.randi() % IDLE.size()])


## Answers in the game itself, after a short typing pause (AiChat's transport).
class LocalTransport:
	extends RefCounted
	## Seconds a player takes to answer (each answer within this range).
	var delay := Vector2(0.7, 1.6)
	var _answers := {}
	var _next := 0

	func send(json: String) -> int:
		_next += 1
		var body: Variant = JSON.parse_string(json)
		var answer: Dictionary = ChatBrain.reply(body if body is Dictionary else {})
		var wait := lerpf(delay.x, delay.y, float(absi(hash(json)) % 1000) / 1000.0)
		_answers[_next] = {"json": JSON.stringify(answer), "at": Time.get_ticks_msec() + int(wait * 1000.0)}
		return _next

	func poll(id: int) -> String:
		if not _answers.has(id):
			return ""
		var entry: Dictionary = _answers[id]
		if Time.get_ticks_msec() < int(entry.at):
			return ""
		_answers.erase(id)
		return String(entry.json)
