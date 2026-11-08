class_name ChatThreads
extends RefCounted
## Conversations among the world players, made in the game (free, offline): one player
## opens a topic and one to three others answer within a few seconds, now and then with
## a word back from the first (2-3 turn exchanges). The topics follow the opener's own
## state: a newcomer asks for a party or where to level, a mid-level player talks of the
## field boss, a starred one of the drowned abyss (ห้วงสมุทรอสูร), the 250★ set and
## mounts, a ★300 player of its God promotion, a guild member of the guild war; stall
## keepers pitch what they really have (WorldChat.line_for), a player looking to buy a
## jewel gets the real stalls' answers (ChatTrade). Each player's play style colours its
## words (voice). WorldPresence schedules the lines (and keeps the rate readable);
## "guild" and "party" threads run among the hero's guild mates and party members.
##
## The players only say true things. A line names the real field, its boss, the
## speaker's level and stars, class, guild and God title; what it found, enhanced,
## forged or rode comes from its real gear and the last NEWS_WORLD_HOURS world hours of
## its gear events (WorldGear: news): "ตีบวกอาวุธ +7 ติดแล้ว" only after that very
## enhance, "หลอมชุดเซต... ได้ชิ้นที่ 3" only with three pieces, a drop names the real
## find. The topics drop, enhance_ok, enhance_fail, wings and the set / mount news are
## opened only with such an event. A line may start with conditions on its speaker
## ("{god}", "{abyss}", "{set0}"... cond_ok), and a line whose placeholder has no real
## value for this speaker is never said; what is left is game knowledge read from the
## game's own constants (rules), feelings, jokes and questions.

## Answers after the opening line: 1, 2 or 3, by these chances.
const REPLY_ODDS := [0.45, 0.4, 0.15]
## The opener answers back this often (a third turn).
const BACK_CHANCE := 0.45
## Seconds before an answer (one types after the other).
const GAP := Vector2(1.8, 3.6)
## How far back (world hours) a player's gear events still count as news.
const NEWS_WORLD_HOURS := 2.0

## Topics: lines that open it, answers to it ("reply") and the opener's word back ("back").
## Speaker: %me, %to (who it answers), %lv ("Lv.80" / "Lv.100 ★120"), %job, %god, %left
## (stars to ★300), %guild / %rival, %zone (where it stands), %my... (its own gear:
## %mymount, %mymountlv, %mypieces, %mywings, %mydplus, %mydrop). The opener's thread:
## %field / %boss / %respawn (its field, the boss and its respawn minutes), %drop (its
## latest find), %eslot %efrom %eto (its latest enhance), %fslot %ffrom %fnext %flost
## %fjewel %fchance %fails (its latest failed try), %newpiece (set piece forged),
## %mupname %muplv / %mnew (mount levelled / made), %wingsnew, %mat / %nextmount (the
## next mount's material), %setname. Rules: %abyss %abyssstar %deepmob %godstars
## %godfee %wbtime %wartime %regmin %setstars %setmax %setbonus %craft %coreodds
## %jewelx %pbonus %wingdrop %starwing %drake. Also %online and %name2.
const TOPICS := {
	"greet": {
		"open": ["สวัสดีทุกคน~", "หวัดดีชาว%zone", "มาแล้วจ้า วันนี้ออนกันเยอะเลย %online คน", "ดีครับ มาแล้ว", "หวัดดี ใครออนบ้าง", "หวัดดีทุกคน จะเช้าหรือดึกก็ลุย 555"],
		"reply": ["หวัดดี %to!", "ดีจ้า %to", "ยินดีต้อนรับ %to", "หวัดดี มาล่าด้วยกันไหม %to", "ดีจ้า %to วันนี้ไปไหน", "เย้ %to มาแล้ว"],
		"back": ["{field}ไปเก็บเวลที่%field ก่อนนะ", "ขอบคุณทุกคน~", "ไว้ตี้กันนะ"],
	},
	"party": {
		"open": ["หาตี้%field ใครว่างบ้าง", "%lv หาปาร์ตี้เก็บเวลที่%field", "%job %lv หาตี้%field ด่วน ๆ", "ใครไป%field บ้าง ไปด้วยกันไหม", "หาเพื่อนตี้ฟาร์ม%field ยาว ๆ"],
		"reply": ["ไปด้วย ๆ %to รอแป๊บ", "ขอจอยด้วยคน %lv", "เดี๋ยวตามไป ขอเติมยาก่อน", "ตี้เต็มยัง %to", "ไปไม่ได้อ่ะ ขอโทษน้า ไว้รอบหน้านะ", "ลองชวน %name2 ดูสิ"],
		"back": ["โอเค เชิญเลย %to", "ขอบคุณน้า", "มาเลย รอที่จุดวาป", "ได้ ๆ มาเลย"],
	},
	"level": {
		"open": ["%lv ควรไปเก็บเวลที่ไหนดี", "%job อัปสกิลไหนก่อนดี", "เลเวลขึ้นช้าจัง ทำไงดี", "{newbie}มือใหม่ครับ %field มอนตีเจ็บจัง", "มีทริคประหยัดยาเลือดไหม"],
		"reply": ["ไป%field เลย มอนกำลังดี", "อัปท่าหลักก่อน แล้วค่อยเก็บท่าเสริม", "ใจเย็น ๆ %to เดี๋ยวก็ขึ้น", "หาตี้สิ ตี้ได้ EXP รวมเพิ่ม %pbonus เปอร์เซ็นต์ต่อเพื่อนหนึ่งคน", "ยาที่แผงในหมู่บ้านถูกกว่าร้านค้านะ", "ใส่ของที่ดรอปให้ครบก่อน %to", "ช่วง %expname %exptime คุ้มสุดนะ"],
		"back": ["ขอบคุณมากเลย %to", "โอเค จะลองดู", "เข้าใจละ ขอบใจ ๆ"],
	},
	"boss": {
		"open": ["%boss ที่%field ล้มแล้วเกิดใหม่ราว %respawn นาที ใครไปบ้าง", "ใครเห็น%boss ตายยัง", "{field}รอ%boss อยู่ ใครจะมาแย่งไหม 555", "%boss ตีเจ็บมาก ระวังกันด้วย", "บอสโลกมาทุกวัน %wbtime ใครไปบ้าง"],
		"reply": ["ไปด้วย ๆ ขอเก็บ EXP ด้วย", "เมื่อกี้ได้%mydrop มาเหมือนกัน", "%boss ตีเจ็บนะ ระวังท่าแรง", "จองไว้ก่อน 555", "ไม่ทันแล้วอ่ะ ไว้รอบหน้า", "ใครไปบ้าง เดี๋ยวตามไป"],
		"back": ["โอเค เจอกันที่%field", "555 ไม่แย่งหรอก ตีด้วยกัน", "ขอบใจ %to", "รีบมานะ"],
	},
	"drop": {
		"open": ["ได้%drop แล้ว!", "เพิ่งดรอป%drop มือสั่นเลย", "วันนี้ดวงดี ได้%drop", "{field}ล่าที่%field อยู่ เพิ่งได้%drop", "ฟาร์มมานาน ในที่สุดก็ได้%drop"],
		"reply": ["โห ยินดีด้วย %to!", "อยากได้บ้างจัง 555", "ขอแบ่งดวงหน่อย %to", "ขายไหม %to ให้ราคาดี", "อิจฉาเลย", "แคปไว้ยัง 555"],
		"back": ["ยังไม่ขายนะ เก็บไว้ก่อน 555", "ขอบคุณ ๆ", "ดวงล้วน ๆ 555", "ไว้ได้อีกชิ้นจะเอาไปตั้งแผง"],
	},
	"enhance_fail": {
		"open": ["ตีบวก%fslot จาก +%ffrom ไม่ติด %flost", "ลุ้นตี%fslot +%fnext อยู่ ใครมี%fjewel ขายบ้าง", "ตีบวกพลาด %fails รอบแล้ว ร้องไห้", "ช่างตีเหล็กวันนี้ใจร้ายมาก %fslot +%fnext ไม่ติดเลย"],
		"reply": ["ใจเย็น ๆ %to ลองใหม่นะ", "เข้าใจเลย ใจหายแทน 555", "ลองไปดูเพชรตามแผงในหมู่บ้านสิ", "+%fnext โอกาสติด %fchance เปอร์เซ็นต์เองนะ สู้ ๆ", "สู้ ๆ %to", "ตีตอนดึกติดง่ายจริงไหมนะ 555"],
		"back": ["จะลองอีกรอบ ภาวนาด้วย", "ขอบใจนะ %to", "ไม่ไหวละ พักก่อน", "ไปฟาร์มเพชรต่อ T_T"],
	},
	"enhance_ok": {
		"open": ["ตีบวก%eslot +%eto ติดแล้ว!", "%eslot +%efrom ไป +%eto ผ่าน! ช่างตีเหล็กใจดีวันนี้", "ตีบวก%eslot ติด +%eto เลย ดวงมาก", "ในที่สุด%eslot ก็ +%eto ไปล่าต่อ"],
		"reply": ["ยินดีด้วย %to!", "+%eto โหดมาก แบ่งดวงหน่อย", "เทพจริง %to", "เดี๋ยวขอไปตีบ้าง 555", "ใส่แล้วตีแรงขึ้นเยอะไหม"],
		"back": ["แรงขึ้นจริง", "ขอบคุณ ๆ", "555 ดวงล้วน ๆ"],
	},
	"god_done": {
		"open": ["{god}เปลี่ยนเป็น%god แล้ว! สกิลเทพสวยมาก", "{god}ในที่สุดก็เป็น%god ★%godstars แล้ว", "{god}สกิลเทพของ%job แรงเกินคาด", "ใครยังไม่ไปเปลี่ยนเทพเจ้า ไปหาปรมาจารย์ผู้เปลี่ยนชะตาได้เลยนะ"],
		"reply": ["ยินดีด้วย %to โคตรเท่", "ขอดูสกิลเทพหน่อย %to", "{far}ฉันยังอีกไกลเลย 555 %lv เอง", "เทพเจ้าคนที่เท่าไหร่ของเซิร์ฟแล้วเนี่ย", "{notgod}รอฉันด้วย!"],
		"back": ["เดี๋ยวไปโชว์ที่หมู่บ้าน", "ลุยกันต่อ!", "ขอบคุณทุกคน~"],
	},
	"god_soon": {
		"open": ["{waiting}อีก %left ดาวจะถึง ★%godstars แล้ว อยากเป็นเทพเจ้า", "ใครเป็นเทพเจ้าแห่งอาชีพแล้วบ้าง สกิลเทพแรงไหม", "เปลี่ยนเทพเจ้าค่าธรรมเนียม %godfee ทอง ต้องเก็บเงินแล้ว"],
		"reply": ["สู้ ๆ %to", "{god}แรงมาก สกิลเทพเคลียร์มอนสบายเลย", "ถึง ★%abyssstar แล้วไปฟาร์ม%abyss ได้นะ", "เปลี่ยนแล้วค่าพลังขึ้นเยอะเลยนะ", "{waiting}ฉันก็รออยู่เหมือนกัน"],
		"back": ["ลุยต่อ!", "ขอบใจ %to", "ไปเก็บดาวต่อละ"],
	},
	"abyss": {
		"open": ["{abyss}%abyss มอนถึกมาก ใครไปบ้าง", "{abyss}%abyss สวยมาก", "%abyss ดรอปเพชรเยอะจริงไหม", "{inabyss}ฟาร์ม%abyss หาแก่นเทพอยู่ ดรอปยากจัง", "{abyss}%deepmob ถึกมาก ระวังกันด้วย"],
		"reply": ["ต้อง ★%abyssstar ก่อนนะถึงเข้าได้", "จริง เพชรม่วงกับชาออสร่วงเยอะกว่าสนามทั่วไป %jewelx เท่า", "{abyss}ไปด้วย ๆ ฉัน %lv", "%deepmob ถึกมาก ระวัง", "แก่นเทพดรอปแค่ %coreodds เปอร์เซ็นต์ต่อตัวเอง", "ระวังกันด้วยนะ"],
		"back": ["{abyss}ไปกัน รอที่ทางเข้า", "ขอบใจ %to", "{inabyss}จะฟาร์มต่ออีกสักพัก"],
	},
	"set": {
		"open": ["หลอม%setname ได้ชิ้นที่ %newpiece แล้ว!", "%setname มี %mypieces ชิ้นแล้ว", "ใครหลอมชุดเซตแล้วบ้าง แก่นเทพหายากมาก", "ชุดเซต %setstars ดาว ใส่ครบ %setmax ชิ้นโหดจริงไหม", "ถ้าได้แก่นเทพ หลอมชิ้นไหนก่อนดี"],
		"reply": ["ครบ 4 ชิ้นได้พลังโจมตีกับพลังป้องกันเพิ่ม %setbonus เปอร์เซ็นต์", "แก่นเทพดรอปที่%abyss กับ%lotus นะ", "หลอมชิ้นเซตอาวุธ เกราะ หมวก รองเท้า ต้องใช้ชิ้นชุดเทพ +%setdivplus ของช่องนั้นด้วยนะ", "ยินดีด้วย %to!", "{set0}ฉันยังไม่มีชิ้นเซตสักชิ้นเลย 555", "ฉันมี %mypieces ชิ้นแล้ว", "หลอมอาวุธก่อนเลย คุ้มสุด", "หลอมติดแค่ %craft เปอร์เซ็นต์นะ ใจเย็น ๆ"],
		"back": ["โอเค เดี๋ยวลองดู", "ขอบใจ %to", "{setnear}อีกนิดจะครบแล้ว"],
	},
	"mount": {
		"open": ["ได้%mnew แล้ว วิ่งไวขึ้นเยอะ", "อัป%mupname เลเวล %muplv สำเร็จ!", "ขี่%mymount เลเวล %mymountlv อยู่ วิ่งไวดี", "ใครขี่%drake บ้าง ขอดูหน่อย", "กำลังเก็บ%mat เผื่อไว้สร้าง%nextmount ดรอปยากจัง"],
		"reply": ["เท่มาก %to", "ฉันขี่%mymount เลเวล %mymountlv อยู่", "{nomount}ฉันยังไม่มีสัตว์ขี่เลย 555", "%drake คือที่สุด", "ยินดีด้วย!", "%mat ดรอปน้อยจริง อดทนนะ"],
		"back": ["ไว้ขี่ไปให้ดูนะ", "ขอบคุณ ๆ", "ลุยฟาร์มต่อ"],
	},
	"wings": {
		"open": ["ได้%wingsnew แล้ว! บินสบายเลย", "ใส่%mywings อยู่ บินสบายเลย", "อยากได้ปีก ต้องล่าบอส Lv.%wingdrop ใช่ไหม"],
		"reply": ["ยินดีด้วย %to!", "เท่มาก", "{nowings}ฉันยังไม่มีปีกเลย", "ปีกดรอปจากบอส Lv.%wingdrop นะ", "ถึง ★%starwing ก็หลอมปีกดาวได้นะ"],
		"back": ["ขอบคุณ ๆ", "บินไปล่าต่อละ"],
	},
	"war": {
		"open": ["{guild}กิลด์วอรอบหน้า %wartime %guild ลงชื่อด้วยนะ", "{guild}%rival รอบนี้ไม่รอดแน่", "{guild}ใครว่างไปกิลด์วอบ้าง", "กิลด์วอสนุกมาก ชิงปราสาทกันทั้ง 4 กิลด์"],
		"reply": ["ไปแน่นอน!", "{guild}%guild สู้ ๆ", "{guild}%rival เก่งนะ ระวังด้วย", "ฉันขอดูอยู่ข้างสนาม 555", "เตรียมยาไว้เยอะ ๆ", "ลงชื่อได้ถึง %regmin นาทีก่อนเริ่มนะ"],
		"back": ["เจอกันที่สนาม", "จัดไป!", "ขอบใจทุกคน"],
	},
	"joke": {
		"open": ["ต้นซากุระกลางหมู่บ้านสวยจัง", "สไลม์ชมพูน่ารักจนไม่อยากตี 555", "ใครเคยลืมใส่อาวุธออกไปล่าบ้าง 555", "ใครเห็นไก่ป่าวิ่งไล่คนบ้าง", "สัตว์เลี้ยงในคอกหมู่บ้านน่ารักจัง", "ใครเคยกดวาร์ปกลับเมืองกลางบอสบ้าง 555"],
		"reply": ["555 เกิดขึ้นได้", "ฮามาก %to", "555 นึกภาพออกเลย", "แคปไว้ยัง 555", "จริงด้วย 555"],
		"back": ["555 ใช่ไหมล่ะ", "ขำตัวเอง", "555 ไปล่าต่อละ"],
	},
	"help": {
		"open": ["{stars}ใครว่างช่วยพาเก็บดาวหน่อย", "ขอคนช่วยตี%boss หน่อย", "ใครมียาเลือดขายบ้าง", "ใครรู้ทางไป%field บ้าง"],
		"reply": ["เดี๋ยวไปช่วย %to", "ว่างอยู่ ไปกัน", "ยาที่แผงในหมู่บ้านถูกกว่าร้านค้านะ", "ไปที่จุดวาปในหมู่บ้านแล้วเลือก%field เลย", "ติดอยู่อ่ะ ขอโทษนะ %to"],
		"back": ["ขอบคุณมาก %to", "รอที่%field นะ", "เพื่อนกิลด์ดีที่สุด"],
	},
	# A stall keeper's call (its lines name what it really has: WorldPresence passes them
	# as ctx.open_lines) and the answers to it.
	"stall": {
		"open": [],
		"reply": ["ราคาเท่าไหร่ %to", "เดี๋ยวแวะไปดูนะ %to", "ลดได้ไหม 555", "ยังอยู่ไหม %to", "ของ %to ดูดีนะ"],
		"back": ["ยังอยู่จ้า มาเลย", "ต่อราคาได้ลอตละครั้งนะ", "แวะมาดูก่อนได้ ไม่ซื้อไม่ว่า"],
	},
	"next": {
		"open": ["ฟาร์มต่อหรือไปตี%boss ดี", "ไปต่อ%field ไหมทีม", "ใครยาเหลือน้อยบอกนะ", "รอบนี้ฟาร์มลื่นมาก"],
		"reply": ["ไปตีบอสเลย!", "ฟาร์มต่ออีกนิดก่อน", "ไปต่อเลย พร้อมแล้ว", "ลื่นจริง %to ตีโหด", "ตามหัวหน้าตี้เลย"],
		"back": ["โอเค ไปกัน", "จัดไป!", "555 ลุย"],
	},
}
## Said when every line of a turn needs a fact this speaker lacks.
const PLAIN_LINES := {"open": ["สวัสดีทุกคน~"], "reply": ["555 จริง", "เห็นด้วย ๆ", "โอเค ๆ %to"], "back": ["ขอบใจ %to", "555 โอเค"]}
## Topics a guild or party chat may open (the world chat may open any).
const CHANNEL_TOPICS := {
	"guild": ["war", "boss", "help", "god_done", "god_soon", "abyss", "set", "enhance_ok", "enhance_fail", "greet", "drop", "mount", "wings"],
	"party": ["next", "drop", "joke", "boss", "mount", "enhance_ok", "enhance_fail", "wings"],
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
## A speaker below this level calls itself a newcomer.
const NEWBIE_LEVEL := 15
## A 250★ set piece of the four divine slots is forged from that slot's divine piece at
## this + (consumed) and a set core.
const SET_DIVINE_PLUS := 10
## Stars short of ★300 below which "still far" is true.
const FAR_STARS := 50


## Real seconds the news window spans (NEWS_WORLD_HOURS on the world's clock).
static func window() -> float:
	return NEWS_WORLD_HOURS * 3600.0 / WorldPlayers.SPEED


## The world index of player state s, -1 when it is no world player (a test's stand-in
## with another name).
static func index_of_state(s: Dictionary) -> int:
	var i := int(s.get("index", -1))
	if i < 0 or i >= WorldPlayers.size() or String(WorldPlayers.entry(i).name) != String(s.get("name", "")):
		return -1
	return i


## What player i has and did lately at real time t (WorldGear): {gear, enhance_ok,
## enhance_fail, set_piece, divine_piece, wings_up, mount_up, drop (each the latest event
## of the window or {}), fails (failed tries in the window)}; {} for no world player.
static func news(i: int, t: float) -> Dictionary:
	if i < 0 or i >= WorldPlayers.size():
		return {}
	var w := window()
	var out := {"gear": WorldGear.gear(i, t), "fails": 0}
	for kind in ["enhance_ok", "enhance_fail", "set_piece", "divine_piece", "wings_up", "mount_up", "drop"]:
		out[kind] = {}
	for e in WorldGear.events(i, t - w, t):
		var kind := String(e.get("kind", ""))
		if out.has(kind):
			out[kind] = e
		if kind == "enhance_fail":
			out.fails = int(out.fails) + 1
	return out


## A slot's name in a line ("อาวุธ"), "ของ" for none.
static func slot_word(slot: String) -> String:
	return String(ItemData.SLOT_NAMES.get(slot, "ของ"))


## The opener's news as thread placeholders (only those it really has).
static func news_vars(n: Dictionary) -> Dictionary:
	var out := {}
	if n.is_empty():
		return out
	var ok: Dictionary = n.get("enhance_ok", {})
	if not ok.is_empty():
		out["%eslot"] = slot_word(String(ok.get("slot", "")))
		out["%efrom"] = str(int(ok.get("from", 0)))
		out["%eto"] = str(int(ok.get("to", 0)))
	var fail: Dictionary = n.get("enhance_fail", {})
	if not fail.is_empty():
		var from := int(fail.get("from", 0))
		var to := int(fail.get("to", from))
		out["%fslot"] = slot_word(String(fail.get("slot", "")))
		out["%ffrom"] = str(from)
		out["%fnext"] = str(from + 1)
		out["%flost"] = "ตกเหลือ +%d" % to if to < from else "เสียเพชรเปล่า"
		out["%fchance"] = str(int(round(ItemData.enhance_chance(from) * 100.0)))
		var cost := ItemData.enhance_cost({"plus": from})
		var names: PackedStringArray = []
		for id in ["purple", "pink", "chaos"]:
			if int(cost.get(id, 0)) > 0:
				names.append(String(ItemData.JEWELS[id].name))
		out["%fjewel"] = " ".join(names)
	if int(n.get("fails", 0)) >= 2:
		out["%fails"] = str(int(n.fails))
	var drop: Dictionary = n.get("drop", {})
	if not drop.is_empty() and String(drop.get("item", "")) != "":
		out["%drop"] = String(drop.item)
	var piece: Dictionary = n.get("set_piece", {})
	if not piece.is_empty():
		out["%newpiece"] = str(int(piece.get("to", 0)))
	var mount: Dictionary = n.get("mount_up", {})
	if not mount.is_empty():
		var g: Dictionary = n.get("gear", {})
		var name := String(mount.get("item", ""))
		if name == "":
			name = String((g.get("mount", {}) as Dictionary).get("name", ""))
		if name != "":
			if int(mount.get("from", 0)) <= 0:
				out["%mnew"] = name
			else:
				out["%mupname"] = name
				out["%muplv"] = str(int(mount.get("to", 1)))
	var wings: Dictionary = n.get("wings_up", {})
	if not wings.is_empty() and String(wings.get("item", "")) != "":
		out["%wingsnew"] = String(wings.item)
	return out


## The speaker's own gear as placeholders (%my...: only what it has).
static func my_vars(n: Dictionary) -> Dictionary:
	var out := {}
	if n.is_empty():
		return out
	var g: Dictionary = n.get("gear", {})
	var mount: Dictionary = g.get("mount", {})
	if not mount.is_empty() and String(mount.get("name", "")) != "":
		out["%mymount"] = String(mount.name)
		out["%mymountlv"] = str(int(mount.get("level", 1)))
	if int(g.get("set_pieces", 0)) > 0:
		out["%mypieces"] = str(int(g.set_pieces))
	var wings: Dictionary = g.get("wings", {})
	if int(wings.get("tier", 0)) > 0 and String(wings.get("name", "")) != "":
		out["%mywings"] = String(wings.name)
	if int(g.get("divine_pieces", 0)) >= DivineGearData.SLOTS.size() and int(g.get("divine_plus", 0)) > 0:
		out["%mydplus"] = str(int(g.divine_plus))
	if int(g.get("divine_pieces", 0)) > 0:
		out["%mydivine"] = str(int(g.divine_pieces))
	var drop: Dictionary = n.get("drop", {})
	if not drop.is_empty() and String(drop.get("item", "")) != "":
		out["%mydrop"] = String(drop.item)
	return out


## Game knowledge from the game's own constants, for the lines that state a rule.
static func rule_vars(t: float) -> Dictionary:
	# Its everyday monsters (the boss is named only by who hunts there).
	var abyss_mobs: Array = DrownedAbyssData.NORMALS
	return {
		"%abyss": DrownedAbyssData.TITLE,
		"%abyssstar": str(DrownedAbyssData.ENTRY_STAR),
		"%lotus": DivineRegionData.TITLE,
		"%setdivplus": str(SET_DIVINE_PLUS),
		"%deepmob": String(DrownedAbyssData.MONSTERS[abyss_mobs[absi(int(t)) % abyss_mobs.size()]].name),
		"%godstars": str(JobData.GOD_STARS),
		"%godfee": _thousands(int(JobData.TIER_COSTS[JobData.GOD_ADV - 1])),
		"%wbtime": "%02d:%02d" % [WorldEvents.BOSS_START / 3600, (WorldEvents.BOSS_START % 3600) / 60],
		"%expname": WorldEvents.NAME_EXP,
		"%exptime": "%02d:00-%02d:00" % [WorldEvents.EXP_START / 3600, WorldEvents.EXP_END / 3600],
		"%wartime": GuildLeague.clock_text(GuildLeague.next_slot(t)),
		"%regmin": str(GuildLeague.REGISTER_CLOSE / 60),
		"%setstars": str(SetGearData.STARS),
		"%setmax": str(SetGearData.SLOTS.size()),
		"%setbonus": str(int(round(float(SetGearData.BONUS[4].atk) * 100.0))),
		"%craft": str(int(round(SetGearData.CRAFT_CHANCE * 100.0))),
		"%coreodds": str(snappedf(DrownedAbyssData.SET_CORE_DROP * 100.0, 0.01)),
		"%jewelx": str(int(round(float(DrownedAbyssData.JEWEL_DROP.purple) / float(ItemData.JEWEL_DROP.purple)))),
		"%pbonus": str(int(round(Game.PARTY_EXP_BONUS * 100.0))),
		"%wingdrop": str(ItemData.WING_DROP_LEVEL),
		"%starwing": str(StarWingData.REQUIRED_STARS),
		"%drake": String(MountData.info("fire_drake").get("name", "")),
	}


static func _thousands(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out


## The topic player state s opens on `channel`, picked by its own state, its news (news:
## the news topics only with a real event) and rng.
static func topic_for(channel: String, s: Dictionary, rng: RandomNumberGenerator, n := {}) -> String:
	var level := int(s.get("level", 1))
	var stars := int(s.get("stars", 0)) if level >= Game.MAX_LEVEL else 0
	var guild := int(s.get("guild", 0))
	var g: Dictionary = n.get("gear", {})
	var weights := {"greet": 0.8, "joke": 0.8}
	if not (n.get("drop", {}) as Dictionary).is_empty():
		weights["drop"] = 1.2
	if level < Game.MAX_LEVEL or stars < Game.PARAGON_MAX:
		weights["party"] = 1.4
	if level < 60:
		weights["level"] = 1.3
	if level >= 8:
		weights["boss"] = 1.3
	if not (n.get("enhance_fail", {}) as Dictionary).is_empty():
		weights["enhance_fail"] = 0.8
	if not (n.get("enhance_ok", {}) as Dictionary).is_empty():
		weights["enhance_ok"] = 0.8
	if level >= 35:
		weights["mount"] = 0.7 + (0.5 if not (n.get("mount_up", {}) as Dictionary).is_empty() else 0.0)
	if not (n.get("wings_up", {}) as Dictionary).is_empty():
		weights["wings"] = 0.8
	elif int((g.get("wings", {}) as Dictionary).get("tier", 0)) > 0:
		weights["wings"] = 0.2
	if stars >= JobData.GOD_STARS:
		weights["god_done"] = 1.6
	elif stars >= 200:
		weights["god_soon"] = 1.0
	elif level >= Game.MAX_LEVEL:
		weights["god_soon"] = 0.3
	if stars >= 150:
		weights["abyss"] = 1.0
	if stars >= 200 or int(g.get("set_pieces", 0)) > 0:
		weights["set"] = 0.8 + (0.4 if not (n.get("set_piece", {}) as Dictionary).is_empty() else 0.0)
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
## topic (to force one; a news topic without its news falls back to one of the opener's
## own), t (real time, WorldPresence.clock() by default), news (the opener's, tests)}.
static func make(channel: String, people: Array, rng: RandomNumberGenerator, ctx := {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if people.is_empty():
		return out
	var t := float(ctx.get("t", -1.0))
	if t < 0.0:
		t = WorldPresence.clock()
	var opener: Dictionary = people[0]
	var known := {}
	var opener_news: Dictionary = ctx.get("news", news(index_of_state(opener), t))
	known[0] = opener_news
	var vars := thread_vars(opener, rng, ctx, opener_news, t)
	var topic := String(ctx.get("topic", ""))
	var open: Array = []
	if TOPICS.has(topic):
		open = _options(TOPICS[topic].open if not (TOPICS[topic].open as Array).is_empty() else ctx.get("open_lines", ["สวัสดีทุกคน~"]), opener, {}, vars, rng, opener_news)
	if open.is_empty():
		topic = topic_for(channel, opener, rng, opener_news)
		open = _options(TOPICS[topic].open, opener, {}, vars, rng, opener_news)
	if open.is_empty():
		open = _options(PLAIN_LINES.open, opener, {}, vars, rng, opener_news)
	var lines: Dictionary = TOPICS[topic]
	out.append({"who": 0, "options": open, "delay": 0.0, "topic": topic})
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
		var mine := _known(known, who, people[who], t)
		var said := _options(lines.reply, people[who], opener, vars, rng, mine)
		if said.is_empty():
			said = _options(PLAIN_LINES.reply, people[who], opener, vars, rng, mine)
		out.append({"who": who, "options": said, "delay": rng.randf_range(GAP.x, GAP.y)})
	if lines.has("back") and rng.randf() < BACK_CHANCE:
		var last: Dictionary = people[int(out[-1].who)]
		var said := _options(lines.back, opener, last, vars, rng, opener_news)
		if said.is_empty():
			said = _options(PLAIN_LINES.back, opener, last, vars, rng, opener_news)
		out.append({"who": 0, "options": said, "delay": rng.randf_range(GAP.x, GAP.y)})
	return out


static func _known(known: Dictionary, who: int, s: Dictionary, t: float) -> Dictionary:
	if not known.has(who):
		known[who] = news(index_of_state(s), t)
	return known[who]


## What a thread keeps the same from line to line: the opener's field and its boss, its
## news (news_vars), the next mount's material, the game's rules...
static func thread_vars(s: Dictionary, rng: RandomNumberGenerator, ctx := {}, n := {}, t := -1.0) -> Dictionary:
	if t < 0.0:
		t = WorldPresence.clock()
	var level := int(s.get("level", 1))
	var stars := int(s.get("stars", 0)) if level >= Game.MAX_LEVEL else 0
	ZoneData.ensure()
	# The field it is in (from ★200 the abyss or the sanctum, a session each), else the
	# one that fits it.
	var here := StringName(s.get("place", ""))
	var field_id := here if here != &"" and here != &"town" else WorldPlayers.hunting_zone(level, stars)
	var field: Dictionary = ZoneData.get_zone(field_id)
	var boss := ""
	var respawn := 0.0
	if field.has("boss"):
		boss = String(MonsterData.get_monster(StringName(field.boss.monster)).get("name", ""))
		respawn = float(field.boss.get("respawn", 0.0))
	var names: Array = ctx.get("names", [])
	var out := rule_vars(t)
	out["%field"] = String(field.get("name", "สนาม"))
	out["%boss"] = boss if boss != "" else "บอสสนาม"
	if respawn > 0.0:
		out["%respawn"] = str(maxi(1, int(round(respawn / 60.0))))
	out["%online"] = str(int(ctx.get("online", 0))) if int(ctx.get("online", 0)) > 0 else "หลาย"
	out["%name2"] = String(names[rng.randi() % names.size()]) if not names.is_empty() else "เพื่อน"
	out["%setname"] = String((n.get("gear", {}) as Dictionary).get("set_name", SetGearData.set_label(String(s.get("job", s.get("class", "warrior"))))))
	# The next mount up (its material is what a mount keeper gathers), or the drake's own
	# material to level it.
	var have := String(((n.get("gear", {}) as Dictionary).get("mount", {}) as Dictionary).get("name", ""))
	var next_id := "thunder_wolf"
	for k in MountData.ORDER.size():
		if String(MountData.info(MountData.ORDER[k]).get("name", "")) == have:
			next_id = MountData.ORDER[mini(k + 1, MountData.ORDER.size() - 1)]
	out["%mat"] = String(ItemData.JEWELS[MountData.mat_of(next_id)].name)
	if have != "" and String(MountData.info(next_id).get("name", "")) != have:
		out["%nextmount"] = String(MountData.info(next_id).get("name", ""))
	out.merge(news_vars(n), true)
	return out


## Every line of `pool` that holds for `me` (answering `to`; `mine`: its news), filled in
## and in a random order.
static func _options(pool: Array, me: Dictionary, to: Dictionary, vars: Dictionary, rng: RandomNumberGenerator, mine := {}) -> Array:
	var out: Array = []
	for line in pool:
		var text := fill(String(line), me, to, vars, mine)
		if text != "":
			out.append(voice(text, me, rng))
	_shuffle(out, rng)
	return out


## A line with its placeholders filled for speaker `me` answering `to` (`mine`: its news),
## "" when one of its conditions does not hold for `me` or a placeholder has no real value.
static func fill(line: String, me: Dictionary, to: Dictionary, vars: Dictionary, mine := {}) -> String:
	while line.begins_with("{"):
		var close := line.find("}")
		if close < 0:
			break
		for cond in line.substr(1, close - 1).split(","):
			if not cond_ok(String(cond).strip_edges(), me, mine):
				return ""
		line = line.substr(close + 1)
	var level := int(me.get("level", 1))
	var stars := int(me.get("stars", 0)) if level >= Game.MAX_LEVEL else 0
	var cls := StringName(me.get("class", ClassData.START))
	var guild := int(me.get("guild", 0))
	var rep := {}
	rep.merge(vars, true)
	rep["%me"] = String(me.get("name", ""))
	rep["%to"] = String(to.get("name", "เพื่อน"))
	rep["%lv"] = "Lv.%d%s" % [level, " ★%d" % stars if stars > 0 else ""]
	rep["%job"] = String(ClassData.get_class_data(cls).get("name", ""))
	rep["%god"] = JobData.god_name(cls if cls != ClassData.START else &"warrior")
	rep["%left"] = str(maxi(1, JobData.GOD_STARS - stars))
	var mine_name := WorldPlayers.guild_name(guild)
	rep["%guild"] = mine_name if mine_name != "" else "กิลด์เรา"
	rep["%rival"] = WorldPlayers.guild_name(GuildLeague.next_rival(guild)) if guild > 0 else "อีกกิลด์"
	var place := StringName(me.get("place", ""))
	rep["%zone"] = "หมู่บ้าน" if place == &"town" or place == &"" else String(ZoneData.get_zone(place).get("name", "สนาม"))
	rep.merge(my_vars(mine), true)
	return apply(line, rep)


## `line` with every placeholder of `rep` put in (a whole placeholder only, so %n never
## eats %newpiece), "" when a placeholder is left with no value.
static func apply(line: String, rep: Dictionary) -> String:
	var out := ""
	var at := 0
	for m in _placeholder().search_all(line):
		var key := m.get_string()
		if not rep.has(key):
			return ""
		out += line.substr(at, m.get_start() - at) + String(rep[key])
		at = m.get_end()
	return out + line.substr(at)


static var _rx: RegEx


static func _placeholder() -> RegEx:
	if _rx == null:
		_rx = RegEx.new()
		_rx.compile("%[a-z][a-z0-9]*")
	return _rx


## Whether condition `cond` holds for speaker state `me` with news `mine`: god / notgod /
## far (★300 still far) / waiting (Lv.100, not yet God) / stars (Lv.100) / abyss (can
## enter the drowned abyss) / inabyss / field (stands in its hunting field) / town /
## newbie / guild / set0 (no set piece) / setnear (4-5 of them) / nowings / nomount /
## boss (hunting bosses now).
static func cond_ok(cond: String, me: Dictionary, mine: Dictionary) -> bool:
	var level := int(me.get("level", 1))
	var stars := int(me.get("stars", 0)) if level >= Game.MAX_LEVEL else 0
	var god := level >= Game.MAX_LEVEL and stars >= JobData.GOD_STARS
	var place := String(me.get("place", ""))
	var g: Dictionary = mine.get("gear", {})
	match cond:
		"god":
			return god
		"notgod":
			return not god
		"far":
			return not god and (level < Game.MAX_LEVEL or stars < JobData.GOD_STARS - FAR_STARS)
		"waiting":
			return level >= Game.MAX_LEVEL and not god
		"stars":
			return level >= Game.MAX_LEVEL
		"abyss":
			return stars >= DrownedAbyssData.ENTRY_STAR
		"inabyss":
			return place == String(DrownedAbyssData.ID)
		"field":
			return place != "" and place != "town" and place == String(WorldPlayers.hunting_zone(level, stars))
		"town":
			return place == "town"
		"newbie":
			return level < NEWBIE_LEVEL
		"guild":
			return int(me.get("guild", 0)) > 0
		"set0":
			return not g.is_empty() and int(g.get("set_pieces", 0)) == 0
		"setnear":
			return int(g.get("set_pieces", 0)) >= 4 and int(g.get("set_pieces", 0)) < SetGearData.SLOTS.size()
		"nowings":
			return not g.is_empty() and int((g.get("wings", {}) as Dictionary).get("tier", 0)) <= 0
		"nomount":
			return not g.is_empty() and (g.get("mount", {}) as Dictionary).is_empty()
		"boss":
			return String(me.get("doing", "")) == "boss"
	return false


## A play style's own touch at the end of some lines (a newcomer is polite and humble).
static func voice(text: String, s: Dictionary, rng: RandomNumberGenerator) -> String:
	if rng.randf() >= VOICE_RATE or text.ends_with("?"):
		return text
	# Its voice: the way it talks (every scheduled player plays hardcore now, each still
	# talks like the player it is; WorldPlayers' "voice").
	var style := String(s.get("voice", s.get("style", "")))
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
