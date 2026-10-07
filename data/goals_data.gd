class_name GoalsData
extends RefCounted
## Things to do again and again: three daily quests (new every day) and a list
## of achievements with one-time rewards.

# --- Daily quests: templates; counts scale with the hero's level ---------------
## kind: kills (any monster), zone_kills (in the current best zone), boss, gold (picked up), skills (casts)
const DAILY_POOL := [
	{"id": "kills_a", "kind": "kills", "name": "นักล่าประจำวัน", "desc": "ปราบมอนสเตอร์ %d ตัว", "base": 20, "per_level": 0.4},
	{"id": "kills_b", "kind": "kills", "name": "กวาดล้างใหญ่", "desc": "ปราบมอนสเตอร์ %d ตัว", "base": 40, "per_level": 0.7},
	{"id": "zone_kills", "kind": "zone_kills", "name": "ยึดพื้นที่", "desc": "ปราบมอนสเตอร์ในโซนปัจจุบัน %d ตัว", "base": 15, "per_level": 0.3},
	{"id": "boss", "kind": "boss", "name": "ล่าบอส", "desc": "ปราบบอส %d ตัว", "base": 1, "per_level": 0.0},
	{"id": "gold", "kind": "gold", "name": "นักเก็บเหรียญ", "desc": "เก็บเหรียญจากพื้น %d เหรียญ", "base": 200, "per_level": 40.0},
	{"id": "skills", "kind": "skills", "name": "จอมสกิล", "desc": "ใช้สกิล %d ครั้ง", "base": 20, "per_level": 0.5},
]


static func today() -> String:
	return Time.get_date_string_from_system()


## Three template ids chosen by the date (the same all day, the same on every device).
static func pick_for_date(date: String) -> Array:
	var local := RandomNumberGenerator.new()
	local.seed = hash(date)
	var pool := DAILY_POOL.duplicate()
	var picked: Array = []
	for i in 3:
		var index := local.randi() % pool.size()
		picked.append(pool[index])
		pool.remove_at(index)
	return picked


static func yesterday() -> String:
	return Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) - 86400)


static func target_for(template: Dictionary, level: int) -> int:
	return maxi(1, int(round(float(template.base) + float(template.per_level) * level)))


static func reward_for(level: int) -> Dictionary:
	return {"exp": int(HeroStats.exp_to_next(level) * 0.3) + 50, "gold": 120 + level * 60}


# --- Achievements ---------------------------------------------------------------
## check: key understood by Game.achievement_value(); goal: needed value; reward: gold / sp / gem
const ACHIEVEMENTS := [
	{"id": "first_blood", "name": "ก้าวแรก", "desc": "ปราบมอนสเตอร์ตัวแรก", "check": "kills", "goal": 1, "reward": {"gold": 100}},
	{"id": "hunter100", "name": "นักล่าฝึกหัด", "desc": "ปราบมอนสเตอร์ 100 ตัว", "check": "kills", "goal": 100, "reward": {"gold": 500}},
	{"id": "hunter1000", "name": "นักล่าตัวจริง", "desc": "ปราบมอนสเตอร์ 1,000 ตัว", "check": "kills", "goal": 1000, "reward": {"sp": 2}},
	{"id": "hunter5000", "name": "ตำนานนักล่า", "desc": "ปราบมอนสเตอร์ 5,000 ตัว", "check": "kills", "goal": 5000, "reward": {"sp": 3, "gold": 10000}},
	{"id": "lv10", "name": "มือใหม่หัวใจกล้า", "desc": "ถึงเลเวล 10", "check": "level", "goal": 10, "reward": {"gold": 300}},
	{"id": "lv30", "name": "นักผจญภัยตัวจริง", "desc": "ถึงเลเวล 30", "check": "level", "goal": 30, "reward": {"gold": 3000, "gem": ["ruby", 1]}},
	{"id": "lv50", "name": "จุดสูงสุด", "desc": "ถึงเลเวล 50", "check": "level", "goal": 50, "reward": {"sp": 5, "gold": 30000}},
	{"id": "job1", "name": "เปลี่ยนชะตา", "desc": "เปลี่ยนอาชีพขั้นที่สอง", "check": "job", "goal": 1, "reward": {"gold": 1000}},
	{"id": "job3", "name": "ขั้นสุดยอด", "desc": "เลื่อนขั้นสุดยอด (Lv.40)", "check": "job3", "goal": 1, "reward": {"gold": 6000, "gem": ["amethyst", 2]}},
	{"id": "job5", "name": "ในตำนาน", "desc": "เลื่อนเป็นขั้นในตำนาน (Lv.80)", "check": "job5", "goal": 1, "reward": {"gold": 60000, "sp": 5}},
	{"id": "lv100", "name": "สุดขอบฟ้า", "desc": "ถึงเลเวล 100", "check": "level", "goal": 100, "reward": {"sp": 10, "gold": 200000}},
	{"id": "boss1", "name": "ผู้ล้มยักษ์", "desc": "ปราบบอสตัวแรก", "check": "bosses", "goal": 1, "reward": {"gold": 800}},
	{"id": "boss5", "name": "ราชาบอส", "desc": "ปราบบอสครบทั้ง 5 ชนิด", "check": "boss_types", "goal": 5, "reward": {"gold": 12000, "sp": 3}},
	{"id": "boss10", "name": "ผู้ล้มเทพมังกร", "desc": "ปราบบอสครบทั้ง 10 ชนิด", "check": "boss_types", "goal": 10, "reward": {"gold": 500000, "sp": 8}},
	{"id": "plus7", "name": "ช่างตีมือทอง", "desc": "ตีบวกไอเทมให้ถึง +7", "check": "best_plus", "goal": 7, "reward": {"gem": ["topaz", 2]}},
	{"id": "mythic", "name": "เทพนิยายมีจริง", "desc": "ได้ไอเทมระดับเทพนิยาย", "check": "got_mythic", "goal": 1, "reward": {"gold": 50000, "sp": 3}},
	{"id": "streak7", "name": "ไม่ขาดสาย", "desc": "รับรางวัลรายวันติดต่อกัน 7 วัน", "check": "best_streak", "goal": 7, "reward": {"gold": 20000, "gem": ["ruby", 3]}},
	{"id": "legend", "name": "ของในตำนาน", "desc": "ได้ไอเทมระดับตำนาน", "check": "got_legend", "goal": 1, "reward": {"gold": 2000}},
	{"id": "gems5", "name": "นักฝังอัญมณี", "desc": "ฝังอัญมณีรวม 5 เม็ด", "check": "gems_set", "goal": 5, "reward": {"gem": ["sapphire", 1]}},
	{"id": "rich", "name": "เศรษฐีใหม่", "desc": "มีเหรียญ 50,000", "check": "gold", "goal": 50000, "reward": {"sp": 1}},
	{"id": "pvp1", "name": "นักสู้หน้าใหม่", "desc": "ชนะดวลจัดอันดับ 1 ครั้ง", "check": "pvp_wins", "goal": 1, "reward": {"gold": 2000}},
	{"id": "pvp10", "name": "จอมประลอง", "desc": "ชนะดวลจัดอันดับ 10 ครั้ง", "check": "pvp_wins", "goal": 10, "reward": {"gold": 20000, "gem": ["ruby", 2]}},
	{"id": "pvp_gold", "name": "ลีกทอง", "desc": "ไต่แรงก์ถึงระดับทอง", "check": "pvp_best_step", "goal": 6, "reward": {"gold": 30000, "sp": 2}},
	{"id": "pvp_diamond", "name": "ราชาเพชร", "desc": "ไต่แรงก์ถึงระดับเพชร", "check": "pvp_best_step", "goal": 12, "reward": {"gold": 150000, "sp": 5}},
	{"id": "para10", "name": "เหนือขีดจำกัด", "desc": "ถึงระดับเหนือเลเวล ★10", "check": "paragon_level", "goal": 10, "reward": {"gold": 50000}},
	{"id": "para50", "name": "ผู้ก้าวข้ามเทพ", "desc": "ถึงระดับเหนือเลเวล ★50", "check": "paragon_level", "goal": 50, "reward": {"gold": 300000, "sp": 3}},
	{"id": "para100", "name": "ตำนานอมตะ", "desc": "ถึงระดับเหนือเลเวล ★100", "check": "paragon_level", "goal": 100, "reward": {"gold": 1000000, "gem": ["ruby", 3]}},
	{"id": "para200", "name": "สุดขอบจักรวาล", "desc": "ถึงระดับเหนือเลเวล ★200 (สูงสุด)", "check": "paragon_level", "goal": 200, "reward": {"gold": 5000000, "sp": 10}},
	{"id": "arena1", "name": "ผู้กล้าสนามประลอง", "desc": "ชนะสนามประลอง 1 ครั้ง", "check": "arena_clears", "goal": 1, "reward": {"gold": 1500}},
	{"id": "arena10", "name": "แชมป์สนามประลอง", "desc": "ชนะสนามประลอง 10 ครั้ง", "check": "arena_clears", "goal": 10, "reward": {"sp": 3, "gem": ["emerald", 2]}},
	{"id": "daily7", "name": "ขยันทุกวัน", "desc": "ทำเควสต์รายวันสำเร็จ 7 ครั้ง", "check": "dailies", "goal": 7, "reward": {"gold": 2000}},
]
