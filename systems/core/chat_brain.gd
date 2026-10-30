class_name ChatBrain
extends RefCounted
## The world players' own answers, made in the game: free, instant and offline. A line
## is read for what the hero is after (a party, the stall, where to hunt, a level, how
## something works, a goodbye...) and the player answers from its own state (class,
## level, stars, what it is doing and where, its play style) with the action that goes
## with it, like the account server's chat would (AiChat.request_body is the input,
## {reply, action} the output). The talk so far (body.history) shapes the answer: a
## second greeting in a row is noticed, and a short "yes" or "no" right after the player
## asked something (FOLLOW_UPS, recognised in its own earlier line) completes it. The
## play style gives a tone (tone_of: short and keen, relaxed, sleepy late at night, a
## keeper pitching its wares, a humble newcomer), and some plain-chat answers end with a
## question back so the talk goes on. Everything is picked by hashes of the player, the
## line and the length of the talk, so the same line gets the same answer on every device.
##
## In the party and guild chats (body.channel "party" / "guild") the line may come from the
## hero or from another member (body.from, its name): CHANNEL_INTENTS read the party's own
## talk first (a boss, low HP, a level-up, moving on, a good run, the loot, the guild war),
## and the answers are a teammate's (a priest offers to heal) or a guild mate's; a line from
## another member never carries an action.

## Words that mark what a line is about, checked in this order.
const INTENTS := [
	["bot", ["บอท", "bot", "เป็นคนจริง", "คนจริงไหม", "ai ", " ai", "เอไอ"]],
	["rude", ["โง่", "กาก", "ควาย", "เหี้ย", "สัส", "ไอ้", "อีดอก", "fuck", "noob", "ห่วย", "ไปตาย", "น่ารำคาญ", "ขยะ", "ไอ้บ้า"]],
	["leave", ["ออกจากปาร์ตี้", "ออกจากตี้", "ออกตี้", "แยกกัน", "ไปก่อนนะ", "บาย", "ลาก่อน", "bye", "ไว้เจอกัน"]],
	["howru", ["เป็นยังไงบ้าง", "เป็นไงบ้าง", "สบายดีไหม", "สบายดีมั้ย", "เป็นไงมั่ง", "เหนื่อยไหม"]],
	["help", ["วิธี", "ยังไง", "ทำไง", "ทำยังไง", "สอนหน่อย", "แนะนำหน่อย", "คืออะไร", "กี่โมง", "เมื่อไหร่", "ตอนไหน", "เวลาไหน", "อีเวนต์", "อีเว้นท์", "อีเว้น", "บอสโลก", "exp x2"]],
	["party", ["ปาร์ตี้", "ปาตี้", "ตี้", "party", "ไปด้วยกัน", "ไปด้วยไหม", "ไปล่าด้วย", "ล่าด้วยกัน", "เก็บเลเวลด้วย", "เข้ากลุ่ม", "จอยกัน", "จอยไหม"]],
	["shop", ["ขายอะไร", "ขายไหม", "มีอะไรขาย", "ดูร้าน", "ดูของ", "ซื้อ", "ร้าน", "ราคา", "ขายของ", "รับซื้อ", "ของดี"]],
	["come", ["มาหา", "เจอกัน", "มาเจอ", "มาที่นี่", "เทรด", "trade", "แลกของ", "แลกเปลี่ยน"]],
	["whereis", ["อยู่ไหน", "อยู่ที่ไหน", "อยู่แถวไหน", "อยู่แมพไหน", "อยู่ตรงไหน"]],
	["where", ["ไปไหนดี", "เก็บเลเวลที่ไหน", "ที่ไหนดี", "สนามไหน", "ด่านไหน", "ที่ไหน", "แมพไหน"]],
	["level", ["เลเวลเท่าไหร่", "กี่เลเวล", "เวลเท่าไหร่", "กี่เวล", "เลเวลอะไร", "lv", "เวลไร", "กี่ดาว"]],
	["enhance", ["ตีบวก", "หินตีบวก", "+7", "+8", "+9", "+10", "บวกแตก"]],
	["skill", ["สกิล", "skill", "ท่าไหน", "อัปอะไร", "อัพอะไร"]],
	["guild", ["กิลด์", "guild", "กิล"]],
	["class", ["อาชีพ", "คลาส", "class", "เล่นสายไหน"]],
	["thanks", ["ขอบคุณ", "ขอบใจ", "thx", "thank", "แต๊งกิ้ว"]],
	["praise", ["เก่ง", "เทพ", "สุดยอด", "โหด", "เจ๋ง", "ปัง"]],
	["greet", ["สวัสดี", "หวัดดี", "ดีจ้า", "ดีครับ", "ดีค่ะ", "hello", "hi", "ทัก"]],
]
## Intents answered with plain chat: these may take the tone's colour and a question back.
const PLAIN := ["", "greet", "thanks", "praise", "level", "class", "enhance", "skill", "guild", "where", "whereis", "bot", "howru"]

const GREET := ["สวัสดีจ้า!", "หวัดดี~ เล่นสนุกไหม", "ดีจ้า วันนี้มาเก็บเลเวลเหรอ", "สวัสดี! มีอะไรให้ช่วยไหม"]
const GREET_AGAIN := "ทักอีกแล้ว 555 มีอะไรให้ช่วยไหม"
const HOWRU := ["สบายดีจ้า เก็บเลเวลอยู่เรื่อย ๆ", "ก็เรื่อย ๆ นะ วันนี้ดรอปไม่ค่อยดี 555", "ดีเลย เพิ่งขึ้นเลเวลมา"]
const THANKS := ["ยินดีจ้า!", "ไม่เป็นไรเลย", "ด้วยความยินดี ไว้มีอะไรทักมาได้นะ"]
const THANKS_PARTY := ["ยินดีจ้า สนุกมาก ไว้ลุยกันใหม่นะ", "ขอบคุณเหมือนกันนะ ตีด้วยกันสนุกดี", "ไม่เป็นไร ไว้ชวนอีกได้เลย"]
const PRAISE := ["555 ยังไม่เทพหรอก ฝึกอยู่", "ขอบคุณนะ เขินเลย", "เดี๋ยวคุณก็เก่งกว่านี้อีก!"]
const BOT := ["เป็นผู้เล่น AI ของเกมนี้แหละ 555 แต่เล่นจริงจังนะ", "ใช่ ผู้เล่น AI เอง แต่ก็เก็บเลเวลเหมือนกันนะ!"]
const RUDE := ["ใจเย็น ๆ นะ คุยกันดี ๆ ดีกว่า", "ขอไม่ตอบแบบนั้นนะ มีอะไรให้ช่วยบอกได้", "เล่นเกมให้สนุกกันดีกว่านะ ไม่ถือโทษ"]
const YES := ["ได้เลย ไปด้วยกัน!", "โอเค ลุยกัน!", "จัดไป เดี๋ยวตามไปนะ", "ยินดีเลย ไปล่ากัน!"]
const BUSY_STALL := ["ตอนนี้พักขายของอยู่ ไว้รอบหน้านะ แวะดูร้านไหม?", "ขอเฝ้าร้านก่อนนะ แวะดูร้านไหม?"]
const BUSY_BOSS := ["กำลังล่าบอสอยู่ ไว้รอบหน้านะ", "ติดล่าบอสอยู่ ขอโทษนะ"]
const ALREADY := ["ก็อยู่ด้วยกันอยู่แล้วนี่ 555", "อยู่ในตี้แล้วจ้า ลุยต่อเลย"]
const BYE := ["ไว้เจอกันใหม่นะ!", "บายจ้า ขอบคุณที่ชวนนะ", "ไปล่าต่อแล้วนะ แล้วเจอกัน"]
const BYE_STRANGER := ["บายจ้า!", "ไว้เจอกันใหม่นะ", "โชคดีนะ!"]
const SHOP_OPEN := ["เชิญดูของได้เลย ของดีที่หามาเอง", "แวะดูก่อน ราคาเป็นมิตร!", "มีของดีอยู่หลายชิ้น ดูได้เลย"]
const NO_SHOP := ["ไม่ได้ตั้งร้านนะ ลองไปดูร้านในหมู่บ้านสิ", "ตอนนี้ไม่ได้ขายของ ร้านคนอื่นในหมู่บ้านมีเยอะเลย"]
const COME := ["ไปหาที่หมู่บ้านนะ เดี๋ยวตามไป", "เจอกันที่หมู่บ้านนะ ตรงหินวาร์ป", "โอเค เดี๋ยวแวะไปหาที่หมู่บ้าน"]
const COME_STALL := ["มาที่ร้านเลย เปิดอยู่ตลอด", "อยู่ที่ร้านนี่แหละ มาเลย"]
const COME_PARTY := ["ก็อยู่ข้าง ๆ นี่ไง 555", "อยู่ตรงนี้แหละ หันมาสิ"]
const WHEREIS_STALL := ["อยู่หมู่บ้าน เฝ้าร้านอยู่ แวะมาได้นะ", "ที่ร้านในหมู่บ้านจ้า มาดูของได้"]
const ENHANCE := ["ตีบวกถึง +6 ค่อนข้างปลอดภัย หลังจากนั้นลุ้นเอานะ", "เพิ่งตีบวกแตกมา เศร้าเลย 555", "เก็บหินตีบวกเยอะ ๆ ก่อนค่อยตีนะ"]
const SKILL := ["ไปเรียนสกิลกับครูฝึกในหมู่บ้านได้เลย", "อัปสกิลหลักก่อน แล้วค่อยเก็บสกิลเสริม", "สกิลใหม่ปลดตามเลเวล อย่าลืมไปหาครูฝึกนะ"]
const IDLE := ["อืม ๆ", "จริงเหรอ 555", "ใช่ ๆ", "น่าสนใจนะ", "ฮ่า ๆ เข้าใจเลย"]
const NO := ["โอเคจ้า ไม่เป็นไร", "ได้ ตามสบายนะ", "โอเค ไว้คราวหน้า"]

## The party's and guild's own talk, checked before INTENTS in those chats.
const CHANNEL_INTENTS := [
	["lowhp", ["เลือดน้อย", "เลือดเหลือน้อย", "เลือดจะหมด", "เลือดหมด", "ฮีล", "heal", "ยาเลือด", "ช่วยด้วย", "hp น้อย", "โดนหนัก"]],
	["boss", ["บอส", "boss", "มอนหัวหน้า", "ไม่ธรรมดา"]],
	["levelup", ["เลเวลอัป", "เลเวลอัพ", "เลเวลขึ้น", "เวลอัป", "เวลขึ้น", "level up"]],
	["war", ["กิลด์วอ", "รบกิลด์", "วอรอบ", "guild war"]],
	["streak", ["ล้มรัว", "ฟาร์มลื่น", "ตีมันส์", "มันส์"]],
	["item", ["ไอเทม", "ดรอป", "ได้ของ", "ของหายาก", "item", "loot", "เก็บของ"]],
	["move", ["ไปต่อ", "ไปล่าต่อ", "ลุยต่อ", "ไปกัน", "พักพอ", "ลุยกัน"]],
]
## The answers in the party chat, by CHANNEL_INTENTS (TO_MATE: to another member's line,
## %name is that member).
const PARTY_BOSS := ["บอสมาแล้ว! เดี๋ยวช่วยตีบอสเลย", "จัดไป ไปตีบอสกัน!", "โอเค เดี๋ยวกันให้ ตีบอสเลย", "ไปตีบอสกัน ระวังท่าแรงด้วยนะ"]
const PARTY_BOSS_MATE := ["เห็นบอสแล้ว ๆ รุมเลย!", "รับทราบ ช่วยตีบอสเลย!", "ระวังท่าบอสด้วยนะทุกคน"]
const PARTY_BOSS_PRIEST := ["ไปตีบอสเลย เดี๋ยวฮีลให้เอง", "ตีบอสได้เลย ฉันคอยฮีลอยู่ข้างหลัง"]
const PARTY_LOWHP := ["ถอยมาก่อน เดี๋ยวกันให้!", "กินยาเลือดก่อนเลย!", "ระวังนะ ถอยมาข้างหลังก่อน"]
const PARTY_LOWHP_PRIEST := ["เดี๋ยวฮีลให้! อดทนไว้", "ฮีลให้แล้วนะ ถอยมาก่อน"]
const PARTY_LOWHP_MATE := ["ถอยมาเลย %name เดี๋ยวกันให้!", "กินยาเลือดก่อน %name เดี๋ยวช่วยดึงมอนไว้"]
const PARTY_LOWHP_MATE_PRIEST := ["เดี๋ยวฮีลให้นะ %name!", "อดทนไว้ %name ฮีลให้แล้ว!"]
const PARTY_LEVELUP := ["ยินดีด้วย! เลเวลอัปแล้ว", "เย้ ยินดีด้วยนะ ขึ้นไวมาก", "ยินดีด้วย ไปต่อกัน!"]
const PARTY_LEVELUP_MATE := ["ยินดีด้วย %name!", "เย้ %name เลเวลอัปแล้ว ยินดีด้วย!", "ยินดีด้วยนะ %name ขึ้นไวจริง"]
const PARTY_MOVE := ["ไปกัน! พร้อมแล้ว", "โอเค ลุยต่อเลย", "ได้เลย ตามไปนะ"]
const PARTY_STREAK := ["ฟาร์มดีจริง ไปต่อ!", "มันส์มาก 555 รัวต่อเลย", "รัวจริง ไม่หยุดเลย"]
const PARTY_ITEM := ["ดรอปดีไหม? ของดีแบ่งกันนะ 555", "เก็บของด้วยนะ เดี๋ยวเต็มกระเป๋า", "ได้ของอะไรดีบ้าง อยากเห็นเลย"]
const PARTY_GREET := ["หวัดดีหัวหน้าตี้! พร้อมลุยแล้ว", "ดีจ้า ตี้เราพร้อมแล้ว", "หวัดดี~ วันนี้ไปไหนกันดี"]
const PARTY_GREET_MATE := ["หวัดดี %name!", "ดีจ้า %name"]
const MATE_IDLE := ["จริง 555", "ใช่ ๆ เห็นด้วย", "โอเค ๆ", "555 ใช่เลย", "%name พูดถูก"]
const GUILD_GREET := ["หวัดดีเพื่อนกิลด์!", "ดีจ้า ชาว %guild", "มาแล้วเหรอ คนของ %guild!"]
const GUILD_THANKS := ["ยินดีจ้า คนกันเองทั้งนั้น", "เพื่อนกิลด์ช่วยกันอยู่แล้ว", "ไม่เป็นไรเลย กิลด์เดียวกัน"]
const GUILD_WAR := ["กิลด์วอรอบหน้ามารวมกันที่หมู่บ้านนะ", "รอบนี้ %guild ต้องชนะ!", "ไปกิลด์วอด้วยแน่นอน"]
const GUILD_SUFFIX := ["%guild สู้ ๆ", "เพื่อนกิลด์ช่วยกันนะ", "ว่าง ๆ มาล่าด้วยกันนะ"]
const GUILD_SUFFIX_RATE := 0.35

## Questions the player asks that a short answer completes: [the question, its kind].
## The kind is read back from the player's own last line in the history.
const FOLLOW_UPS := [
	["อยากให้พาไปสนามไหนไหม?", "party"],
	["แวะดูร้านไหม?", "stall"],
	["มีอะไรให้ช่วยไหม", "help"],
	["อยากรู้เวลาอีเวนต์ไหม?", "events"],
	["มีเคล็ดลับเก็บเลเวลไหม?", "tips"],
	["แล้วคุณเลเวลเท่าไหร่แล้ว?", "hero_level"],
]
const YES_WORDS := ["ได้", "โอเค", "เอา", "ตกลง", "ok", "okay", "yes", "จัด", "ชัวร์", "อยาก", "เยส"]
const NO_WORDS := ["ไม่", "no", "ไว้ก่อน", "ยัง"]
## Particles stripped off a short answer before it is read ("ได้เลยครับ" → "ได้").
const PARTICLES := ["ครับ", "ค่ะ", "คับ", "จ้า", "จ้ะ", "นะ", "เลย", "สิ", "ดิ", "ด้วย", "เถอะ", "ล่ะ", "!", ".", "ๆ", " ", "~"]

## Questions back that end some plain-chat answers; this share of them (by hash).
const ASK_BACK := ["แล้วคุณเลเวลเท่าไหร่แล้ว?", "เล่นสายไหนอยู่?", "วันนี้เก็บเลเวลที่ไหน?", "อยู่กิลด์ไหนหรือยัง?"]
const ASK_PARTY := "อยากให้พาไปสนามไหนไหม?"
const ASK_STALL := "แวะดูร้านไหม?"
const ASK_TIPS := "มีเคล็ดลับเก็บเลเวลไหม?"
const ASK_RATE := 0.3

## Tones by play style (WorldPlayers.STYLES labels); a player under NEWBIE_LEVEL is a
## newcomer whatever its style, and a keeper at a stall pitches its wares.
const TONE_BY_STYLE := {"ขาโหด": "hardcore", "เล่นชิลล์": "casual", "สายนอนดึก": "night", "ตั้งร้าน/AFK": "stall"}
const NEWBIE_LEVEL := 10
const PREFIX := {
	"hardcore": ["ลุย!", "เออ"],
	"casual": ["555", "เอ้อ~"],
	"newbie": ["เพิ่งเล่นเองนะ", "มือใหม่ขอตอบ"],
}
const SUFFIX := {
	"hardcore": ["ลุยต่อ", "ไม่มีเวลา ลุย", "วันนี้ต้องได้อีก 2 เวล"],
	"casual": ["ชิล ๆ นะ", "555", "ไม่รีบ ๆ"],
	"newbie": ["ขอคำแนะนำด้วยนะ", "ยังมือใหม่อยู่ 555", "ผิดถูกบอกได้นะ"],
	"night": ["ไว้ดึก ๆ ค่อยลุยยาว", "กลางคืนคนน้อย มอนเยอะดี"],
	"night_late": ["ง่วงแล้วเนี่ย 555", "ดึกแล้วแต่ยังไม่อยากนอน", "หาวแล้ว แต่ขออีกรอบ"],
	"stall": ["ว่าง ๆ แวะดูร้านด้วยนะ มีของดี", "ร้านเปิดอยู่นะ ของดีราคาเป็นมิตร", "มีของหายากในร้านด้วยนะ"],
}
const TONE_GREET := {
	"hardcore": ["ว่าไง ลุยสนามไหน", "ดี เก็บเวลอยู่ ว่ามาเร็ว", "ไง วันนี้เป้าอีก 3 เวล"],
	"casual": ["ดีจ้า~ ชิล ๆ อยู่ 555", "หวัดดี เล่นชิล ๆ ไปเรื่อย", "ดีจ้า วันนี้ไม่รีบ ค่อย ๆ เก็บ"],
	"newbie": ["สวัสดีค่า เพิ่งเริ่มเล่นเอง", "หวัดดี ยังมือใหม่อยู่เลย", "ดีจ้า เพิ่งเล่นได้ไม่กี่วัน"],
	"stall": ["สวัสดีจ้า แวะดูของในร้านได้นะ", "หวัดดี มีของดีมาใหม่เลย", "ดีจ้า ร้านเปิดอยู่ เชิญดูได้"],
	"night": ["หวัดดี~ สายดึกมารายงานตัว", "ดีจ้า ตื่นสายเลยเพิ่งมา 555"],
}
const TONE_IDLE := {
	"hardcore": ["อืม ลุยต่อ", "เออ", "รีบเก็บเวลดีกว่า", "โอเค ไปล่าต่อละ"],
	"casual": ["555 ชิล ๆ", "เรื่อย ๆ จ้า ไม่รีบ", "ฮ่า ๆ สบาย ๆ", "เออ ๆ ชิลไป"],
	"newbie": ["ยังงง ๆ อยู่เลย 555", "โอเค จำไว้ก่อน", "อ๋อ ขอบคุณที่บอกนะ"],
}
## Words that pick which system a "how do I" line is about, in this order.
const HELP_TOPICS := [
	["enhance", ["ตีบวก", "บวก", "ช่างตี", "เพชรม่วง", "เพชรชมพู"]],
	["stars", ["ดาว", "star", "paragon", "★"]],
	["guild", ["กิลด์", "guild", "กิล"]],
	["stall", ["ฝากขาย", "ต่อราคา", "ร้าน", "แผง", "ขายของ"]],
	["party", ["ปาร์ตี้", "ปาตี้", "ตี้", "party", "ชวน", "สั่งเพื่อน"]],
	["events", ["อีเวนต์", "อีเว้นท์", "อีเว้น", "บอสโลก", "exp", "โบนัส", "กี่โมง", "เมื่อไหร่", "ตอนไหน", "เวลาไหน"]],
	["skill", ["สกิล", "skill"]],
	["level", ["เลเวล", "เวล", "เก่ง"]],
]
const HELP_ANY := "ถามได้เลย ตีบวก ดาว กิลด์ ร้านค้า ปาร์ตี้ หรืออีเวนต์ อยากรู้เรื่องไหน?"
const HELP_READY := "ว่ามาเลย ถามได้ทุกเรื่อง ตีบวก ดาว กิลด์ ร้านค้า ปาร์ตี้ อีเวนต์"


## {reply, action} for the line in `body` (AiChat.request_body).
static func reply(body: Dictionary) -> Dictionary:
	var text := String(body.get("text", "")).to_lower().strip_edges()
	var p: Dictionary = body.get("player", {})
	var h: Dictionary = body.get("hero", {})
	var history: Array = body.get("history", [])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%s|%d" % [p.get("name", ""), text, history.size()])
	var tone := tone_of(p)
	var channel := String(body.get("channel", ""))
	var mate := String(body.get("from", ""))
	if channel == "party" or channel == "guild":
		var said := _channel_answer(channel, text, mate, p, rng)
		if not said.is_empty():
			return said
		if mate != "":
			return _mate_answer(text, mate, p, h, history, tone, rng)
	# A short answer to what the player itself just asked completes it.
	var asked := last_question(history)
	if asked != "":
		var done := _follow_up(asked, text, p, rng)
		if not done.is_empty():
			return done
	var intent := intent_of(text)
	var out := _answer(intent, text, p, h, history, tone, rng)
	if String(out.action) == "none" and intent in PLAIN:
		out.reply = _flavor(String(out.reply), tone, int(body.get("hour", -1)), rng)
		out.reply = _ask_back(String(out.reply), p, tone, rng)
	if channel == "guild":
		out.reply = _guild_flavor(String(out.reply), p, rng)
	return out


# --- The party and guild chats -----------------------------------------------------------

## What a party or guild line is about (CHANNEL_INTENTS), "" when none of it.
static func channel_intent_of(text: String) -> String:
	var lower := " %s " % text.to_lower()
	for entry in CHANNEL_INTENTS:
		for word in entry[1]:
			if lower.contains(String(word)):
				return String(entry[0])
	return ""


## The party's / guild's own answer to a line (`mate`: the member who said it, "" for the
## hero), {} when the line is not about the party's own talk.
static func _channel_answer(channel: String, text: String, mate: String, p: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var intent := channel_intent_of(text)
	var priest := String(p.get("class", "")) == String(ClassData.get_class_data(&"priest").get("name", "-"))
	var pool: Array = []
	match intent:
		"lowhp":
			if mate != "":
				pool = PARTY_LOWHP_MATE_PRIEST if priest else PARTY_LOWHP_MATE
			else:
				pool = PARTY_LOWHP_PRIEST if priest else PARTY_LOWHP
		"boss":
			pool = PARTY_BOSS_PRIEST if priest else (PARTY_BOSS_MATE if mate != "" else PARTY_BOSS)
		"levelup":
			pool = PARTY_LEVELUP_MATE if mate != "" else PARTY_LEVELUP
		"war":
			pool = GUILD_WAR
		"streak":
			pool = PARTY_STREAK
		"item":
			pool = PARTY_ITEM
		"move":
			pool = PARTY_MOVE
	if pool.is_empty():
		var plain := intent_of(text)
		# "สวัสดีเพื่อนกิลด์", "หวัดดีตี้": a line opening with a hello is a greeting.
		if plain == "greet" or _opens_with_greet(text):
			if channel == "guild":
				pool = GUILD_GREET
			else:
				pool = PARTY_GREET_MATE if mate != "" else PARTY_GREET
		elif plain == "thanks" and channel == "guild":
			pool = GUILD_THANKS
	if pool.is_empty():
		return {}
	return {"reply": _fill(String(pool[rng.randi() % pool.size()]), mate, p), "action": "none"}


static func _opens_with_greet(text: String) -> bool:
	var lower := text.to_lower().strip_edges()
	for entry in INTENTS:
		if String(entry[0]) == "greet":
			for word in entry[1]:
				if String(word).length() > 2 and lower.begins_with(String(word)):
					return true
	return false


## Another member's line answered in the party chat: by what it is about, never an action.
static func _mate_answer(text: String, mate: String, p: Dictionary, h: Dictionary, history: Array, tone: String, rng: RandomNumberGenerator) -> Dictionary:
	var intent := intent_of(text)
	if intent in ["", "party", "shop", "come", "leave", "rude", "bot", "greet"]:
		return {"reply": _fill(String(MATE_IDLE[rng.randi() % MATE_IDLE.size()]), mate, p), "action": "none"}
	var out := _answer(intent, text, p, h, history, tone, rng)
	out.action = "none"
	return out


## A guild mate's answer now and then ends with a word for the guild.
static func _guild_flavor(reply: String, p: Dictionary, rng: RandomNumberGenerator) -> String:
	if String(p.get("guild", "")) == "" or reply.ends_with("?") or reply.length() > 110 or rng.randf() >= GUILD_SUFFIX_RATE:
		return reply
	return "%s %s" % [reply, _fill(String(GUILD_SUFFIX[rng.randi() % GUILD_SUFFIX.size()]), "", p)]


static func _fill(line: String, mate: String, p: Dictionary) -> String:
	var guild := String(p.get("guild", ""))
	return line.replace("%name", mate if mate != "" else "เพื่อน").replace("%guild", guild if guild != "" else "กิลด์เรา")


## The answer by intent, before the tone and a question back are added.
static func _answer(intent: String, text: String, p: Dictionary, h: Dictionary, history: Array, tone: String, rng: RandomNumberGenerator) -> Dictionary:
	var doing := String(p.get("doing", ""))
	var in_party := bool(p.get("inParty", false))
	match intent:
		"bot":
			return _say(BOT, rng)
		"rude":
			return _say(RUDE, rng)
		"leave":
			if in_party:
				return _say(BYE, rng, "leave_party")
			return _say(BYE_STRANGER, rng)
		"howru":
			return _say(HOWRU, rng)
		"help":
			return {"reply": help_text(help_topic(text)), "action": "none"}
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
		"come":
			if doing == "stall":
				return _say(COME_STALL, rng, "open_stall")
			if in_party:
				return _say(COME_PARTY, rng)
			return _say(COME, rng)
		"whereis":
			return {"reply": _where_am_i(p, rng), "action": "none"}
		"where":
			return {"reply": _where(p, h, rng), "action": "none"}
		"level":
			var stars := int(p.get("stars", 0))
			var lv := "Lv.%d%s" % [int(p.get("level", 1)), " ★%d" % stars if stars > 0 else ""]
			if tone == "hardcore":
				return {"reply": "%s เป้าวันนี้อีก %d เวล ลุย" % [lv, 1 + rng.randi() % 3], "action": "none"}
			return {"reply": ["ตอนนี้ %s แล้ว" % lv, "%s เองจ้า ยังต้องเก็บอีกเยอะ" % lv, "%s แล้ว! ขึ้นช้าแต่ชัวร์ 555" % lv][rng.randi() % 3], "action": "none"}
		"enhance":
			return _say(ENHANCE, rng)
		"skill":
			return _say(SKILL, rng)
		"guild":
			var guild := String(p.get("guild", ""))
			if guild != "":
				return {"reply": "อยู่กิลด์ %s จ้า ถึง Lv.%d แล้วมาสมัครได้นะ" % [guild, Game.GUILD_LEVEL], "action": "none"}
			return {"reply": ["ยังไม่มีกิลด์เลย ต้องถึง Lv.%d ก่อน" % Game.GUILD_LEVEL, "กิลด์รับตอน Lv.%d รีบเก็บเลเวลกัน!" % Game.GUILD_LEVEL][rng.randi() % 2], "action": "none"}
		"class":
			var cls := String(p.get("class", ""))
			return {"reply": ["เล่น%sอยู่ สนุกดีนะ" % cls, "สาย%s เลย ชอบมาก" % cls, "%s จ้า ลองเล่นดูสิ" % cls][rng.randi() % 3], "action": "none"}
		"thanks":
			if in_party or text.contains("พา") or text.contains("ล่า") or text.contains("ช่วย"):
				return _say(THANKS_PARTY, rng)
			return _say(THANKS, rng)
		"praise":
			return _say(PRAISE, rng)
		"greet":
			if intent_of(_last(history, "hero")) == "greet":
				return {"reply": GREET_AGAIN, "action": "none"}
			if TONE_GREET.has(tone):
				return _say(TONE_GREET[tone], rng)
			return _say(GREET, rng)
	return {"reply": _idle(p, tone, rng), "action": "none"}


## What a line is about ("" when nothing matches).
static func intent_of(text: String) -> String:
	var lower := " %s " % text.to_lower()
	for entry in INTENTS:
		for word in entry[1]:
			if lower.contains(String(word)):
				return String(entry[0])
	return ""


## The tone a player talks in: "hardcore", "casual", "night", "stall", "newbie" or "".
static func tone_of(p: Dictionary) -> String:
	if int(p.get("level", 1)) < NEWBIE_LEVEL:
		return "newbie"
	var tone := String(TONE_BY_STYLE.get(String(p.get("style", "")), ""))
	if tone == "" and String(p.get("doing", "")) == "stall":
		return "stall"
	return tone


# --- Memory of the talk --------------------------------------------------------------

## The last line `who` ("hero" or "player") said in the history, "" without one.
static func _last(history: Array, who: String) -> String:
	for n in range(history.size() - 1, -1, -1):
		var line: Dictionary = history[n]
		if String(line.get("who", "")) == who:
			return String(line.get("text", ""))
	return ""


## The kind of question the player asked in its last line (FOLLOW_UPS), "" if none.
static func last_question(history: Array) -> String:
	var said := _last(history, "player")
	if said == "":
		return ""
	for pair in FOLLOW_UPS:
		if said.contains(String(pair[0])):
			return String(pair[1])
	return ""


## "yes", "no" or "" for a short answer ("ได้เลยครับ", "โอเค", "ไม่เอา").
static func short_answer(text: String) -> String:
	var core := text.to_lower().strip_edges()
	var trimmed := true
	while trimmed and core != "":
		trimmed = false
		for particle in PARTICLES:
			if core.ends_with(String(particle)) and core.length() > String(particle).length():
				core = core.left(core.length() - String(particle).length())
				trimmed = true
	if core == "":
		return ""
	for word in YES_WORDS:
		var w := String(word)
		if core == w or (core.begins_with(w) and core.length() <= w.length() + 2):
			return "yes"
	for word in NO_WORDS:
		var w := String(word)
		if core == w or (core.begins_with(w) and core.length() <= w.length() + 4):
			return "no"
	return ""


## The first number in a line, 0 without one.
static func _number_in(text: String) -> int:
	var digits := ""
	for ch in text:
		if ch >= "0" and ch <= "9":
			digits += ch
		elif digits != "":
			break
	return int(digits) if digits != "" else 0


## Completes the player's own question `kind` with the hero's answer; {} when the line is
## not an answer to it (it is then read as any other line).
static func _follow_up(kind: String, text: String, p: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var doing := String(p.get("doing", ""))
	if kind == "hero_level":
		var lv := _number_in(text)
		if lv <= 0:
			return {}
		var mine := int(p.get("level", 1))
		if lv > mine:
			return {"reply": "Lv.%d เหรอ เก่งกว่าเราอีก ขอตามด้วยคน" % lv, "action": "none"}
		if lv < mine:
			return {"reply": "Lv.%d เดี๋ยวก็ตามทัน สู้ ๆ นะ" % lv, "action": "none"}
		return {"reply": "เท่ากันเลย 555 ไปล่าด้วยกันก็ได้นะ", "action": "none"}
	var answer := short_answer(text)
	if answer == "no":
		return _say(NO, rng)
	if answer != "yes":
		return {}
	match kind:
		"party":
			if bool(p.get("inParty", false)):
				return _say(ALREADY, rng)
			if doing == "stall":
				return _say(BUSY_STALL, rng)
			return {"reply": "งั้นไปกัน!", "action": "join_party"}
		"stall":
			if doing == "stall":
				return {"reply": "เชิญเลย ดูได้ตามสบาย", "action": "open_stall"}
			return _say(NO_SHOP, rng)
		"help":
			return {"reply": HELP_READY, "action": "none"}
		"events":
			return {"reply": help_text("events"), "action": "none"}
		"tips":
			return {"reply": "เย้ บอกหน่อย ๆ ไปเก็บเลเวลที่ไหนดี?", "action": "none"}
	return {}


# --- Tone and questions back -----------------------------------------------------------

## The tone's colour on a plain answer: now and then a short prefix or suffix (a night
## owl is sleepy from 23:00 to 05:00 Thai time, `hour`; -1 when unknown).
static func _flavor(reply: String, tone: String, hour: int, rng: RandomNumberGenerator) -> String:
	if tone == "":
		return reply
	var roll := rng.randf()
	var prefixes: Array = PREFIX.get(tone, [])
	var suffix_key := tone
	if tone == "night" and hour >= 0 and (hour >= 23 or hour < 5):
		suffix_key = "night_late"
	var suffixes: Array = SUFFIX.get(suffix_key, [])
	if roll < 0.22 and not prefixes.is_empty():
		return "%s %s" % [String(prefixes[rng.randi() % prefixes.size()]), reply]
	if roll < 0.55 and not suffixes.is_empty() and not (reply.ends_with("?") or reply.ends_with("ไหม")):
		return "%s %s" % [reply, String(suffixes[rng.randi() % suffixes.size()])]
	return reply


## About ASK_RATE of the plain answers end with a question back, never one that already
## asks something, never a long one.
static func _ask_back(reply: String, p: Dictionary, tone: String, rng: RandomNumberGenerator) -> String:
	if reply.ends_with("?") or reply.ends_with("ไหม") or reply.length() > 110:
		return reply
	if rng.randf() >= ASK_RATE:
		return reply
	var pool: Array = ASK_BACK.duplicate()
	var doing := String(p.get("doing", ""))
	if tone == "stall" or doing == "stall":
		pool = [ASK_STALL, ASK_STALL] + pool
	elif tone == "newbie":
		pool = [ASK_TIPS, ASK_TIPS] + pool
	elif not bool(p.get("inParty", false)) and doing in ["hunt", ""]:
		pool.append(ASK_PARTY)
	return "%s %s" % [reply, String(pool[rng.randi() % pool.size()])]


# --- Explaining the game -----------------------------------------------------------------

## Which system a "how do I" line asks about ("" for none in particular).
static func help_topic(text: String) -> String:
	var lower := text.to_lower()
	for entry in HELP_TOPICS:
		for word in entry[1]:
			if lower.contains(String(word)):
				return String(entry[0])
	return ""


## A short explanation of a system (its numbers read from the game's own data).
static func help_text(topic: String) -> String:
	match topic:
		"enhance":
			return "ตีบวกที่ช่างตีเหล็ก ถึง +6 ติดชัวร์ +7 ถึง +10 ลุ้น 50%% +11 ถึง +%d ยากขึ้นเรื่อย ๆ พลาดแค่เสียเพชร ครบชุดได้ออร่า" % ItemData.MAX_PLUS
		"stars":
			return "ดาว ★ ได้หลัง Lv.%d เก็บ EXP ต่อเหมือนเลเวล ได้แต้มดาวมาอัปสเตตัส ดาวเยอะถึงเข้าสนามดาวได้" % Game.MAX_LEVEL
		"guild":
			return "กิลด์สมัครที่นายทะเบียนกิลด์ข้างสนามประลอง ต้อง Lv.%d ก่อน มีสองกิลด์ให้เลือก แล้วไปรบกิลด์ด้วยกัน" % Game.GUILD_LEVEL
		"stall":
			return "ร้านในหมู่บ้านเป็นของผู้เล่นที่พัก ของดีกว่าพ่อค้า ต่อราคาได้ลอตละครั้ง ขายให้ร้านได้ราคาดี ฝากขายได้ 1.5 เท่า จ่ายใน %d นาที" % StallStock.CONSIGN_MINUTES
		"party":
			return "ชวนปาร์ตี้ได้จากการ์ดผู้เล่น หรือพิมพ์ชวนในแชท แล้วพิมพ์สั่งเพื่อนได้ ตามมา รอตรงนี้ กลับเมือง"
		"events":
			return "%s ทุกวัน %02d:00-%02d:00 %s เวลา %02d:%02d ในสนามประจำวัน เสาร์อาทิตย์%s" % [WorldEvents.NAME_EXP, WorldEvents.EXP_START / 3600, WorldEvents.EXP_END / 3600, WorldEvents.NAME_BOSS, WorldEvents.BOSS_START / 3600, (WorldEvents.BOSS_START % 3600) / 60, WorldEvents.NAME_GOLD]
		"skill":
			return "สกิลเรียนกับครูฝึกในหมู่บ้าน ปลดตามเลเวล อัปสกิลหลักก่อน แล้วลากใส่ช่องสกิลบนจอ"
		"level":
			return "เก็บเลเวลในสนามที่ตรงเลเวล ถามเราได้ว่าไปไหนดี ช่วง %s %02d:00-%02d:00 คุ้มสุด เข้าปาร์ตี้แล้วล่าด้วยกัน" % [WorldEvents.NAME_EXP, WorldEvents.EXP_START / 3600, WorldEvents.EXP_END / 3600]
	return HELP_ANY


# --- Small talk ----------------------------------------------------------------------------

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


## Where the player is now.
static func _where_am_i(p: Dictionary, rng: RandomNumberGenerator) -> String:
	if String(p.get("doing", "")) == "stall":
		return String(WHEREIS_STALL[rng.randi() % WHEREIS_STALL.size()])
	var here := String(p.get("place", ""))
	if here == "":
		return "อยู่แถวหมู่บ้านจ้า"
	return ["อยู่ที่%s จ้า" % here, "ตอนนี้อยู่%s มาได้นะ" % here][rng.randi() % 2]


## Small talk from what the player is doing, in its tone.
static func _idle(p: Dictionary, tone: String, rng: RandomNumberGenerator) -> String:
	var here := String(p.get("place", ""))
	match String(p.get("doing", "")):
		"stall":
			if rng.randf() < 0.5:
				return "พักขายของอยู่ แวะดูร้านไหม?"
		"hunt":
			if here != "" and rng.randf() < 0.5:
				return "กำลังเก็บเลเวลอยู่ที่%s เลย" % here
		"boss":
			if rng.randf() < 0.5:
				return "ล่าบอสอยู่ ขอโฟกัสแป๊บ 555"
		"party":
			if rng.randf() < 0.5:
				return "ลุยต่อเลย เดี๋ยวช่วยตีเอง!"
	var pool: Array = TONE_IDLE.get(tone, IDLE)
	return String(pool[rng.randi() % pool.size()])


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
