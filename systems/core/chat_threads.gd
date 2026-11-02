class_name ChatThreads
extends RefCounted
## Conversations among the world players, made in the game (free, offline): one player
## opens a topic and one to three others answer within a few seconds, now and then with
## a word back from the first (2-3 turn exchanges). The topics follow the opener's own
## state: a newcomer asks for a party or where to level, a mid-level player talks of the
## field boss, drops and the forge, a starred one of the drowned abyss (ห้วงสมุทรอสูร), the
## 250★ set and mounts, a ★300 player of its God promotion, a guild member of the guild
## war; stall keepers pitch what they really have (WorldChat.line_for), a player looking
## to buy a jewel gets the real stalls' answers (ChatTrade). The lines name the real
## field, its boss, the speaker's level and stars, its class, guild and the God title,
## and mention the others by name. Each player's play style colours its words (voice).
## WorldPresence schedules the lines (and keeps the rate readable); "guild" and "party"
## threads run among the hero's guild mates and party members.

## Answers after the opening line: 1, 2 or 3, by these chances.
const REPLY_ODDS := [0.45, 0.4, 0.15]
## The opener answers back this often (a third turn).
const BACK_CHANCE := 0.45
## Seconds before an answer (one types after the other).
const GAP := Vector2(1.8, 3.6)

## Topics: lines that open it, answers to it ("reply") and the opener's word back ("back").
## %me the speaker, %to who it answers, %field / %boss the opener's hunting field and its
## boss, %lv the speaker's "Lv.80" / "Lv.100 ★120", %job its class, %god its God title,
## %left stars it lacks to ★300, %guild / %rival its guild and the other one, %abyss the
## drowned abyss, %deepmob its monster, %mount / %mat a mount and its material, %set the
## speaker's 250★ set, %drop a find fitting the opener, %plus a forge grade, %min minutes,
## %online players online, %name2 another online player.
const TOPICS := {
	"greet": {
		"open": ["สวัสดีทุกคน~", "หวัดดีชาว%zone", "มาแล้วจ้า วันนี้ออนกันเยอะเลย %online คน", "ดีครับ เพิ่งเข้าเกม", "หวัดดี ใครออนบ้าง", "อรุณสวัสดิ์ทุกคน (ถึงจะดึกแล้วก็เถอะ 555)"],
		"reply": ["หวัดดี %to!", "ดีจ้า %to", "ยินดีต้อนรับ %to", "หวัดดี มาล่าด้วยกันไหม %to", "ดีจ้า %to วันนี้ไปไหน", "เย้ %to มาแล้ว"],
		"back": ["ไปเก็บเวลที่%field ก่อนนะ", "ขอบคุณทุกคน~", "ไว้ตี้กันนะ"],
	},
	"party": {
		"open": ["หาตี้%field ขาดอีก 1 ใครว่างบ้าง", "%lv หาปาร์ตี้เก็บเวลที่%field", "ตี้%field รับ%job ด่วน ๆ", "ใครไป%field บ้าง ไปด้วยกันไหม", "หาเพื่อนตี้ฟาร์ม%field ยาว ๆ"],
		"reply": ["ไปด้วย ๆ %to รอแป๊บ", "ขอจอยด้วยคน %lv", "เดี๋ยวตามไป ขอเติมยาก่อน", "ตี้เต็มยัง %to", "ไปไม่ได้อ่ะ ติดเควสอยู่ ขอโทษน้า", "%name2 ก็ว่างนะ ลองชวนดู"],
		"back": ["โอเค เชิญเลย %to", "เต็มแล้ว ขอบคุณน้า", "มาเลย รอที่หินวาร์ป", "ได้ ๆ ส่งคำเชิญแล้ว"],
	},
	"level": {
		"open": ["%lv ควรไปเก็บเวลที่ไหนดี", "%job อัปสกิลไหนก่อนดี", "เลเวลขึ้นช้าจัง ทำไงดี", "มือใหม่ครับ %field มอนตีเจ็บจัง", "ยาเลือดหมดบ่อยมาก มีทริคไหม"],
		"reply": ["ไป%field เลย มอนให้ EXP ดี", "อัปท่าหลักก่อน แล้วค่อยเก็บท่าเสริม", "ใจเย็น ๆ %to เดี๋ยวก็ขึ้น", "หาตี้สิ แบ่ง EXP ไวขึ้นเยอะ", "ซื้อยาที่แผงในหมู่บ้าน ถูกกว่าร้านค้านิดนึง", "ใส่ของที่ดรอปให้ครบก่อน %to"],
		"back": ["ขอบคุณมากเลย %to", "โอเค จะลองดู", "เข้าใจละ ขอบใจ ๆ"],
	},
	"boss": {
		"open": ["%boss ที่%field เกิดอีก %min นาที ใครไปบ้าง", "ใครเห็น%boss ตายยัง", "%boss เพิ่งล้มไป รอบหน้าอีกราว %min นาที", "รอ%boss อยู่ ใครจะมาแย่งไหม 555", "%boss ท่าใหม่ตีเจ็บมาก ระวังกันด้วย"],
		"reply": ["ไปด้วย ๆ ขอเก็บ EXP ด้วย", "เมื่อกี้ตีไปแล้ว ได้%drop", "%boss ตีเจ็บนะ ระวังท่าแรง", "จองไว้ก่อน 555", "ไม่ทันแล้วอ่ะ ไว้รอบหน้า", "เมื่อกี้ %name2 ตีคนเดียวเลย โหดมาก"],
		"back": ["โอเค เจอกันที่%field", "555 ไม่แย่งหรอก ตีด้วยกัน", "ขอบใจ %to", "รีบมานะ ใกล้เกิดแล้ว"],
	},
	"drop": {
		"open": ["ได้%drop จาก%boss ด้วย!", "เพิ่งดรอป%drop มือสั่นเลย", "วันนี้ดวงดี ได้%drop", "%field ดรอปดีมาก เพิ่งได้%drop", "ฟาร์มมาสามชั่วโมง ในที่สุดก็ได้%drop"],
		"reply": ["โห ยินดีด้วย %to!", "เกลือมาก ฉันฟาร์มทั้งวันไม่ได้สักชิ้น 555", "ขอแบ่งดวงหน่อย %to", "ขายไหม %to ให้ราคาดี", "อิจฉาเลย", "แคปไว้ยัง 555"],
		"back": ["ยังไม่ขายนะ ใช้เองก่อน 555", "ขอบคุณ ๆ", "ดวงล้วน ๆ 555", "ไว้ได้อีกชิ้นจะเอาไปตั้งแผง"],
	},
	"enhance_fail": {
		"open": ["ตีบวก +%plus แตกอีกแล้ว เพชรหมดตัว", "ลุ้นตี +%plus อยู่ ใครมีเพชรชมพูขายบ้าง", "ตีบวกพลาดสามรอบติด ร้องไห้", "ช่างตีเหล็กวันนี้ใจร้ายมาก +%plus ไม่ติดเลย"],
		"reply": ["ใจเย็น ๆ %to รอบหน้าติดแน่", "ฉันตี +9 แตกห้ารอบ เข้าใจเลย 555", "ลองไปดูเพชรตามแผงในหมู่บ้านสิ", "ตีตอนดึก ๆ ติดง่ายนะ (เชื่อเถอะ 555)", "สู้ ๆ %to"],
		"back": ["จะลองอีกรอบ ภาวนาด้วย", "ขอบใจนะ %to", "ไม่ไหวละ พักก่อน", "ไปฟาร์มเพชรต่อ T_T"],
	},
	"enhance_ok": {
		"open": ["ตีบวก +%plus ติดแล้ว!", "+%plus ผ่าน! ช่างตีเหล็กใจดีวันนี้", "ตีบวกครั้งเดียวติด +%plus เลย ดวงมาก", "ในที่สุดก็ +%plus ไปล่าต่อ"],
		"reply": ["ยินดีด้วย %to!", "+%plus โหดมาก แบ่งดวงหน่อย", "เทพจริง %to", "เดี๋ยวขอไปตีบ้าง 555", "ใส่แล้วตีแรงขึ้นเยอะไหม"],
		"back": ["แรงขึ้นจริง มอนล้มไวขึ้นเยอะ", "ขอบคุณ ๆ", "555 ดวงล้วน ๆ"],
	},
	"god_done": {
		"open": ["เปลี่ยนเป็น%god แล้ว! สกิลเทพสวยมาก", "ในที่สุดก็เป็น%god ★300 แล้ว", "สกิลเทพของ%job แรงเกินคาด เคลียร์มอนทั้งจอ", "ใครยังไม่ไปเปลี่ยนเทพเจ้า ไปหาปรมาจารย์ได้เลยนะ"],
		"reply": ["ยินดีด้วย %to โคตรเท่", "ขอดูสกิลเทพหน่อย %to", "ฉันยังอีกไกลเลย 555 %lv เอง", "เทพเจ้าคนที่เท่าไหร่ของเซิร์ฟแล้วเนี่ย", "รอฉันด้วย อีกไม่นาน!"],
		"back": ["เดี๋ยวไปโชว์ที่หมู่บ้าน", "ลุยกันต่อ!", "ขอบคุณทุกคน~"],
	},
	"god_soon": {
		"open": ["อีก %left ดาวจะถึง ★300 แล้ว อยากเป็นเทพเจ้า", "ใครเป็นเทพเจ้าแห่งอาชีพแล้วบ้าง สกิลเทพแรงไหม", "เก็บเงินไว้ล้านนึงรอเปลี่ยนเทพเจ้าละ", "ดาวช่วงหลัง 200 ขึ้นช้ามาก"],
		"reply": ["สู้ ๆ %to อีกนิดเดียว", "แรงมาก สกิลเทพเคลียร์ทั้งจอ", "ไปฟาร์มที่%abyss ดาวขึ้นไวสุดแล้ว", "เปลี่ยนแล้วค่าพลังขึ้นเยอะเลยนะ", "ฉันก็รออยู่เหมือนกัน"],
		"back": ["ลุยต่อ!", "ขอบใจ %to", "อีกไม่นานแน่"],
	},
	"abyss": {
		"open": ["%abyss มอนตีเจ็บมาก ใครไปบ้าง", "เพิ่งเข้า%abyss ครั้งแรก สวยมาก", "%abyss ดรอปเพชรเยอะจริงไหม", "ฟาร์ม%abyss หาแก่นเทพอยู่ ยังไม่ได้สักเม็ด", "%deepmob ยิงไกลมาก ระวังกันด้วย"],
		"reply": ["ต้อง ★200 ก่อนนะถึงเข้าได้", "จริง เพชรร่วงเยอะมาก", "ไปด้วย ๆ ฉัน %lv", "%deepmob ตีแรงมาก ระวัง", "แก่นเทพดรอปยากสุด ๆ", "ฉันตายไปสามรอบแล้ว 555"],
		"back": ["ไปกัน รอที่ทางเข้า", "ขอบใจ %to", "จะฟาร์มต่ออีกชั่วโมง"],
	},
	"set": {
		"open": ["หลอม%set ได้ชิ้นที่ %count แล้ว", "ใครหลอมชุดเซตแล้วบ้าง แก่นเทพหายากมาก", "ชุดเซต 250 ดาว ใส่ครบ 6 ชิ้นโหดจริงไหม", "ได้แก่นเทพมาเม็ดนึง หลอมอะไรก่อนดี"],
		"reply": ["ครบ 4 ชิ้นก็แรงขึ้นเยอะแล้ว", "แก่นเทพดรอปที่%abyss เท่านั้นนะ", "ยินดีด้วย %to!", "ยังเก็บแก่นเทพไม่ได้สักเม็ด 555", "หลอมอาวุธก่อนเลย คุ้มสุด"],
		"back": ["โอเค เดี๋ยวลองดู", "ขอบใจ %to", "อีกนิดจะครบแล้ว"],
	},
	"mount": {
		"open": ["ได้%mount แล้ว วิ่งไวขึ้นเยอะ", "อัป%mount เลเวล %count สำเร็จ!", "ใครขี่%mount บ้าง ขอดูหน่อย", "ฟาร์ม%mat อยู่ ดรอปยากจัง"],
		"reply": ["เท่มาก %to", "ฉันยังขี่หมาป่าอยู่เลย 555", "มังกรน้อยเพลิงคือที่สุด", "ยินดีด้วย!", "%mat ดรอปน้อยจริง อดทนนะ"],
		"back": ["ขี่วนหมู่บ้านอยู่ มาดูได้", "ขอบคุณ ๆ", "ลุยฟาร์มต่อ"],
	},
	"war": {
		"open": ["กิลด์วอรอบหน้า %guild ไปรวมที่หมู่บ้านนะ", "%rival รอบนี้ไม่รอดแน่", "ใครว่างไปกิลด์วอบ้าง ขาดอีก 2", "กิลด์วอรอบที่แล้วมันส์มาก"],
		"reply": ["ไปแน่นอน!", "%guild สู้ ๆ", "%rival เก่งนะ ระวังด้วย", "ฉันขอดูอยู่ข้างสนาม 555", "เตรียมยาไว้เยอะ ๆ"],
		"back": ["เจอกันที่หมู่บ้าน", "จัดไป!", "ขอบใจทุกคน"],
	},
	"joke": {
		"open": ["เมื่อกี้วิ่งชนต้นซากุระในหมู่บ้าน 555", "สไลม์ชมพูตีฉันตายต่อหน้าคนอื่น อายมาก", "ลืมใส่อาวุธออกไปล่า 555", "ใครเห็นไก่ป่าวิ่งไล่คนบ้าง", "แมวในหมู่บ้านน่ารักจัง", "กดสกิลผิดเลยวาร์ปกลับเมืองกลางบอส 555"],
		"reply": ["555 เกิดขึ้นได้", "ฮามาก %to", "เคยเป็นเหมือนกัน 555", "แคปไว้ยัง 555", "%name2 ก็เคย 555"],
		"back": ["อย่าบอกใครนะ 555", "ขำตัวเอง", "555 ไปล่าต่อละ"],
	},
	"help": {
		"open": ["ใครว่างช่วยพาเก็บดาวหน่อย", "ขอคนช่วยตี%boss หน่อย", "ใครมียาเลือดเหลือบ้าง หมดเกลี้ยง", "ใครรู้ทางไป%field บ้าง"],
		"reply": ["เดี๋ยวไปช่วย %to", "ว่างอยู่ ไปกัน", "แผงในหมู่บ้านมียาถูกนะ", "เดินผ่านหินวาร์ปไปเลย", "ติดอยู่อ่ะ ขอโทษนะ %to"],
		"back": ["ขอบคุณมาก %to", "รอที่%field นะ", "เพื่อนกิลด์ดีที่สุด"],
	},
	# A stall keeper's call (its lines name what it really has: WorldPresence passes them
	# as ctx.open_lines) and the answers to it.
	"stall": {
		"open": [],
		"reply": ["ราคาเท่าไหร่ %to", "เดี๋ยวแวะไปดูนะ %to", "ลดได้ไหม 555", "ยังอยู่ไหม %to", "ของ %to ดีจริง ซื้อไปรอบที่แล้ว"],
		"back": ["ยังอยู่จ้า มาเลย", "ต่อราคาได้ที่ร้านนะ", "แวะมาดูก่อนได้ ไม่ซื้อไม่ว่า"],
	},
	"next": {
		"open": ["ฟาร์มต่อหรือไปตี%boss ดี", "ไปต่อ%field ไหมทีม", "ใครยาเหลือน้อยบอกนะ", "รอบนี้ฟาร์มลื่นมาก"],
		"reply": ["ไปตีบอสเลย!", "ฟาร์มต่ออีกนิดก่อน", "ยายังเหลือเยอะ ไปต่อ", "ลื่นจริง %to ตีโหด", "ตามหัวหน้าตี้เลย"],
		"back": ["โอเค ไปกัน", "จัดไป!", "555 ลุย"],
	},
}
## Topics a guild or party chat may open (the world chat may open any).
const CHANNEL_TOPICS := {
	"guild": ["war", "boss", "help", "god_done", "god_soon", "abyss", "set", "enhance_ok", "enhance_fail", "greet", "drop", "mount"],
	"party": ["next", "drop", "joke", "boss", "mount", "enhance_ok", "enhance_fail"],
}
## Words a play style ends some lines with (voice).
const VOICE := {
	"hardcore": ["", "", " ลุย", "!"],
	"casual": ["", " 555", " ~", " ชิล ๆ"],
	"student": ["", " อ่ะ", " งับ", " เดี๋ยวต้องไปทำการบ้าน"],
	"night_owl": ["", " (หาว)", " ดึกแล้วยังไม่นอน 555"],
	"afk": ["", " แวะดูร้านได้นะ"],
	"newbie": [" ครับ", " (มือใหม่)", ""],
}
const VOICE_RATE := 0.35


## The topic player state s opens on `channel`, picked by its own state and rng.
static func topic_for(channel: String, s: Dictionary, rng: RandomNumberGenerator) -> String:
	var level := int(s.get("level", 1))
	var stars := int(s.get("stars", 0)) if level >= Game.MAX_LEVEL else 0
	var guild := int(s.get("guild", 0))
	var weights := {"greet": 0.8, "drop": 1.2, "joke": 0.8}
	if level < Game.MAX_LEVEL or stars < Game.PARAGON_MAX:
		weights["party"] = 1.4
	if level < 60:
		weights["level"] = 1.3
	if level >= 8:
		weights["boss"] = 1.3
	if level >= 20:
		weights["enhance_fail"] = 0.8
		weights["enhance_ok"] = 0.8
	if level >= 35:
		weights["mount"] = 0.7
	if stars >= JobData.GOD_STARS:
		weights["god_done"] = 1.6
	elif stars >= 200:
		weights["god_soon"] = 1.0
	elif level >= Game.MAX_LEVEL:
		weights["god_soon"] = 0.3
	if stars >= 150:
		weights["abyss"] = 1.0
	if stars >= 200:
		weights["set"] = 0.8
	if guild > 0:
		weights["war"] = 0.9
	if channel == "guild":
		weights["help"] = 1.0
		if guild > 0:
			weights["war"] = 1.8
	if channel == "party":
		weights["next"] = 1.6
	if CHANNEL_TOPICS.has(channel):
		for key in weights.keys():
			if not (CHANNEL_TOPICS[channel] as Array).has(key):
				weights.erase(key)
		if weights.is_empty():
			return String(CHANNEL_TOPICS[channel][0])
	var total := 0.0
	for key in weights:
		total += float(weights[key])
	var r := rng.randf() * total
	for key in weights:
		r -= float(weights[key])
		if r <= 0.0:
			return String(key)
	return String(weights.keys()[0])


## A conversation on `channel` among `people` (player states, people[0] opens it): its
## lines in order, [{who (index in people), options (texts to say, the first one not
## said lately wins), delay (seconds after the line before)}]. ctx: {online, names,
## topic (to force one)}.
static func make(channel: String, people: Array, rng: RandomNumberGenerator, ctx := {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if people.is_empty():
		return out
	var opener: Dictionary = people[0]
	var topic := String(ctx.get("topic", ""))
	if not TOPICS.has(topic):
		topic = topic_for(channel, opener, rng)
	var lines: Dictionary = TOPICS[topic]
	var vars := thread_vars(opener, rng, ctx)
	var open: Array = lines.open
	if open.is_empty():
		open = ctx.get("open_lines", ["สวัสดีทุกคน~"])
	out.append({"who": 0, "options": _options(open, opener, {}, vars, rng), "delay": 0.0, "topic": topic})
	var others := people.size() - 1
	if others <= 0:
		return out
	var r := rng.randf()
	var replies := 1
	if r > float(REPLY_ODDS[0]):
		replies = 2 if r <= float(REPLY_ODDS[0]) + float(REPLY_ODDS[1]) else 3
	replies = mini(replies, others)
	var order: Array = range(1, people.size())
	_shuffle(order, rng)
	for k in replies:
		var who: int = order[k]
		out.append({"who": who, "options": _options(lines.reply, people[who], opener, vars, rng), "delay": rng.randf_range(GAP.x, GAP.y)})
	if lines.has("back") and rng.randf() < BACK_CHANCE:
		var last: Dictionary = people[int(out[-1].who)]
		out.append({"who": 0, "options": _options(lines.back, opener, last, vars, rng), "delay": rng.randf_range(GAP.x, GAP.y)})
	return out


## What a thread keeps the same from line to line: the opener's field and its boss, the
## find, the forge grade, the mount...
static func thread_vars(s: Dictionary, rng: RandomNumberGenerator, ctx := {}) -> Dictionary:
	var level := int(s.get("level", 1))
	var stars := int(s.get("stars", 0)) if level >= Game.MAX_LEVEL else 0
	ZoneData.ensure()
	var field_id := WorldPlayers.hunting_zone(level, stars)
	var field: Dictionary = ZoneData.get_zone(field_id)
	var boss := ""
	if field.has("boss"):
		boss = String(MonsterData.get_monster(StringName(field.boss.monster)).get("name", ""))
	var mount_id := "thunder_wolf"
	if stars >= 100:
		mount_id = ["griffin", "fire_drake"][rng.randi() % 2]
	elif level >= Game.MAX_LEVEL:
		mount_id = "griffin"
	elif level >= 60:
		mount_id = "glow_stag"
	var abyss_mobs: Array = DrownedAbyssData.MONSTERS.keys()
	var names: Array = ctx.get("names", [])
	return {
		"%field": String(field.get("name", "สนาม")),
		"%boss": boss if boss != "" else "บอสสนาม",
		"%drop": drop_for(level, stars, rng),
		"%plus": str(rng.randi_range(7, 12) if level >= 40 else rng.randi_range(4, 8)),
		"%min": str(rng.randi_range(2, 9)),
		"%count": str(rng.randi_range(2, 5)),
		"%mount": String(MountData.info(mount_id).get("name", "หมาป่าสายฟ้า")),
		"%mat": String(ItemData.JEWELS[MountData.mat_of(mount_id)].name),
		"%abyss": DrownedAbyssData.TITLE,
		"%deepmob": String(DrownedAbyssData.MONSTERS[abyss_mobs[rng.randi() % abyss_mobs.size()]].name),
		"%online": str(int(ctx.get("online", 0))) if int(ctx.get("online", 0)) > 0 else "หลาย",
		"%name2": String(names[rng.randi() % names.size()]) if not names.is_empty() else "เพื่อน",
	}


## A find that fits a player of `level` and `stars` (what it could really drop).
static func drop_for(level: int, stars: int, rng: RandomNumberGenerator) -> String:
	var pool: Array[String] = [ItemData.JEWELS.purple.name, "แหวนระดับหายาก"]
	if level >= 20:
		pool.append_array([ItemData.JEWELS.pink.name, "ของระดับในตำนาน"])
	if level >= 35:
		pool.append(String(ItemData.JEWELS.wolf_fang.name))
	if level >= Game.MAX_LEVEL:
		pool.append_array([ItemData.JEWELS.chaos.name, "ปีก", "ของระดับเทพนิยาย"])
	if stars >= ItemData.FEATHER_STARS:
		pool.append(String(ItemData.JEWELS.feather.name))
	if stars >= 100:
		pool.append(String(ItemData.JEWELS.drake_scale.name))
	if stars >= DrownedAbyssData.ENTRY_STAR:
		pool.append_array([ItemData.JEWELS.set_core.name, ItemData.POTIONS.hp_god.name])
	return pool[rng.randi() % pool.size()]


## Every line of `pool` filled in for `me` (answering `to`), in a random order.
static func _options(pool: Array, me: Dictionary, to: Dictionary, vars: Dictionary, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for line in pool:
		out.append(voice(fill(String(line), me, to, vars), me, rng))
	_shuffle(out, rng)
	return out


## A line with its placeholders filled for speaker `me` answering `to`.
static func fill(line: String, me: Dictionary, to: Dictionary, vars: Dictionary) -> String:
	var level := int(me.get("level", 1))
	var stars := int(me.get("stars", 0)) if level >= Game.MAX_LEVEL else 0
	var cls := StringName(me.get("class", ClassData.START))
	var guild := int(me.get("guild", 0))
	line = line.replace("%me", String(me.get("name", ""))).replace("%to", String(to.get("name", "เพื่อน")))
	line = line.replace("%lv", "Lv.%d%s" % [level, " ★%d" % stars if stars > 0 else ""])
	line = line.replace("%job", String(ClassData.get_class_data(cls).get("name", "")))
	line = line.replace("%god", JobData.god_name(cls if cls != ClassData.START else &"warrior"))
	line = line.replace("%left", str(maxi(1, JobData.GOD_STARS - stars)))
	line = line.replace("%set", "ชุดเซต%s" % String(ClassData.get_class_data(cls).get("name", "")))
	var mine := WorldPlayers.guild_name(guild)
	line = line.replace("%guild", mine if mine != "" else "กิลด์เรา")
	line = line.replace("%rival", WorldPlayers.guild_name(WorldPlayers.other_guild(guild)) if guild > 0 else "อีกกิลด์")
	var place := StringName(me.get("place", ""))
	var here := "หมู่บ้าน" if place == &"town" or place == &"" else String(ZoneData.get_zone(place).get("name", "สนาม"))
	line = line.replace("%zone", here)
	for key in vars:
		line = line.replace(String(key), String(vars[key]))
	return line


## A play style's own touch at the end of some lines (a newcomer is polite and humble).
static func voice(text: String, s: Dictionary, rng: RandomNumberGenerator) -> String:
	if rng.randf() >= VOICE_RATE or text.ends_with("?"):
		return text
	var style := String(s.get("style", ""))
	if int(s.get("level", 1)) < 10:
		style = "newbie"
	var ends: Array = VOICE.get(style, ["", " ค่ะ" if int(s.get("gender", 0)) == 1 else " ครับ"])
	if style == "newbie" and int(s.get("gender", 0)) == 1:
		ends = [" ค่ะ", " (มือใหม่)", ""]
	return text + String(ends[rng.randi() % ends.size()])


static func _shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	for k in range(list.size() - 1, 0, -1):
		var j := rng.randi() % (k + 1)
		var tmp: Variant = list[k]
		list[k] = list[j]
		list[j] = tmp
