class_name Achievements
extends RefCounted
## Achievements that grant a title shown above the hero's head (Hero's name plate) and
## listed in the menu's "ตำแหน่ง" tab. Earned ones are kept in Game.profile.ach (id ->
## true, next to the rewarded GoalsData.ACHIEVEMENTS); the chosen title is
## Game.profile.flags["title"] = the index of its achievement in TABLE (flags hold
## integers only). Game._check_achievements calls check_all every couple of seconds,
## at level-up and before a save, and passes what the profile does not hold ("live").
##
## kind: what value_of() measures; goal: the value needed; title: optional, what it grants.

const TITLE_FLAG := "title"
## Sticky counters check_all keeps in the flags for things that are not saved otherwise:
## the party (the members are not saved), haggles and consignments (StallStock drops
## those keys when a window ends or a lot is paid), the hero's first world-chat line
## (Game sets it) and world-boss kills (Game counts Game.world_boss_defeated).
const PARTY_FLAG := "ach_party"
const HAGGLE_FLAG := "ach_haggle"
const CONSIGN_FLAG := "ach_consign"
const CHAT_FLAG := "ach_chat"
const WORLD_BOSS_FLAG := "world_boss_kills"
## The tutorial writes this flag value when it is over.
const TUTORIAL_DONE := 99

const TABLE := [
	{"id": "t_kill1", "name": "เลือดแรก", "desc": "ปราบมอนสเตอร์ตัวแรก", "title": "มือใหม่", "kind": "kills", "goal": 1},
	{"id": "t_kill100", "name": "นักล่าร้อยตัว", "desc": "ปราบมอนสเตอร์ 100 ตัว", "title": "นักล่า", "kind": "kills", "goal": 100},
	{"id": "t_kill1000", "name": "นักล่าพันตัว", "desc": "ปราบมอนสเตอร์ 1,000 ตัว", "title": "จอมล่า", "kind": "kills", "goal": 1000},
	{"id": "t_boss1", "name": "ล้มบอสแรก", "desc": "ปราบบอสตัวแรก", "title": "ผู้ล้มยักษ์", "kind": "bosses", "goal": 1},
	{"id": "t_worldboss", "name": "ล้มบอสโลก", "desc": "ร่วมปราบบอสโลก 1 ครั้ง", "title": "ผู้พิชิตบอสโลก", "kind": "world_boss", "goal": 1},
	{"id": "t_lv10", "name": "เริ่มเติบโต", "desc": "ถึงเลเวล 10", "title": "", "kind": "level", "goal": 10},
	{"id": "t_job1", "name": "เปลี่ยนอาชีพ", "desc": "เปลี่ยนอาชีพขั้นที่สอง", "title": "ผู้ก้าวหน้า", "kind": "job", "goal": 1},
	{"id": "t_lv50", "name": "ครึ่งทาง", "desc": "ถึงเลเวล 50", "title": "ผู้กล้า", "kind": "level", "goal": 50},
	{"id": "t_lv100", "name": "สุดเลเวล", "desc": "ถึงเลเวล 100", "title": "จอมยุทธ์", "kind": "level", "goal": 100},
	{"id": "t_star1", "name": "ดาวดวงแรก", "desc": "ได้ดาวเหนือเลเวลดวงแรก", "title": "", "kind": "stars", "goal": 1},
	{"id": "t_star50", "name": "ดาว 50", "desc": "ถึงดาว 50", "title": "ดาวรุ่ง", "kind": "stars", "goal": 50},
	{"id": "t_star100", "name": "ดาว 100", "desc": "ถึงดาว 100", "title": "ดาวค้างฟ้า", "kind": "stars", "goal": 100},
	{"id": "t_star200", "name": "ดาว 200", "desc": "ถึงดาว 200", "title": "ตำนานดารา", "kind": "stars", "goal": 200},
	{"id": "t_party", "name": "เพื่อนร่วมทาง", "desc": "ตั้งปาร์ตี้ครั้งแรก", "title": "เพื่อนแท้", "kind": "party", "goal": 1},
	{"id": "t_haggle", "name": "ปากหวาน", "desc": "ต่อราคาสำเร็จ 10 ครั้งในรอบเดียว", "title": "นักต่อราคา", "kind": "haggle", "goal": 10},
	{"id": "t_consign", "name": "พ่อค้าฝากขาย", "desc": "ฝากขายพร้อมกันครบ 8 รายการ", "title": "พ่อค้า", "kind": "consign", "goal": 8},
	{"id": "t_plus7", "name": "ตีบวก +7", "desc": "สวมไอเทม +7", "title": "ช่างฝีมือ", "kind": "plus", "goal": 7},
	{"id": "t_plus10", "name": "ตีบวก +10", "desc": "สวมไอเทม +10", "title": "ช่างเทพ", "kind": "plus", "goal": 10},
	{"id": "t_gold", "name": "เศรษฐีล้าน", "desc": "มีเหรียญ 1,000,000", "title": "เศรษฐี", "kind": "gold", "goal": 1000000},
	{"id": "t_guild", "name": "เข้ากิลด์", "desc": "เข้าร่วมกิลด์", "title": "สมาชิกกิลด์", "kind": "guild", "goal": 1},
	{"id": "t_gw_win", "name": "ชนะสงครามกิลด์", "desc": "ชนะสงครามกิลด์ 1 ครั้ง", "title": "วีรชนกิลด์", "kind": "gw_wins", "goal": 1},
	{"id": "t_tower10", "name": "หอคอยชั้น 10", "desc": "ปีนหอคอยถึงชั้น 10", "title": "นักปีน", "kind": "tower", "goal": 10},
	{"id": "t_tower30", "name": "หอคอยชั้น 30", "desc": "ปีนหอคอยถึงชั้น 30", "title": "ผู้พิชิตหอคอย", "kind": "tower", "goal": 30},
	{"id": "t_daily7", "name": "ขยันเจ็ดวัน", "desc": "ทำเควสต์รายวันสำเร็จ 7 ครั้ง", "title": "คนขยัน", "kind": "dailies", "goal": 7},
	{"id": "t_tutorial", "name": "จบบทเรียน", "desc": "ผ่านบทสอนเล่น", "title": "", "kind": "tutorial", "goal": 1},
	{"id": "t_chat", "name": "ทักทาย", "desc": "พูดในแชทโลกครั้งแรก", "title": "ช่างคุย", "kind": "chat", "goal": 1},
	# Appended (a worn title is saved as its index): ★300 and the God promotion.
	{"id": "t_star300", "name": "ดาว 300", "desc": "ถึงดาว 300 (สูงสุด)", "title": "ดาราอมตะ", "kind": "stars", "goal": 300},
	{"id": "t_god", "name": "เทพเจ้า", "desc": "เปลี่ยนอาชีพขั้นเทพเจ้า (เลเวล 100 ดาว 300)", "title": "เทพเจ้าแห่งอาชีพ", "kind": "god", "goal": 1},
]
## The God promotion's achievement: its title is the hero's own "เทพเจ้าแห่ง<อาชีพ>".
const GOD_ID := "t_god"


static func entry(id: String) -> Dictionary:
	var k := index_of(id)
	return TABLE[k] if k >= 0 else {}


static func index_of(id: String) -> int:
	for k in TABLE.size():
		if TABLE[k].id == id:
			return k
	return -1


## How far the profile is on a kind of achievement (compared with its goal).
static func value_of(kind: String, profile: Dictionary) -> int:
	var flags: Dictionary = profile.get("flags", {})
	match kind:
		"kills": return int(profile.get("kills", 0))
		"bosses":
			var n := 0
			for id in profile.get("boss_kills", {}):
				n += int(profile["boss_kills"][id])
			return n
		"world_boss": return int(flags.get(WORLD_BOSS_FLAG, 0))
		"level": return int(profile.get("level", 1))
		"job": return 1 if int(profile.get("adv", 0)) >= 1 else 0
		"god": return 1 if JobData.is_god(int(profile.get("adv", 0))) else 0
		"stars": return int(profile.get("paragon", {}).get("level", 0))
		"party": return int(flags.get(PARTY_FLAG, 0))
		"haggle": return int(flags.get(HAGGLE_FLAG, 0))
		"consign": return int(flags.get(CONSIGN_FLAG, 0))
		"plus":
			var best := 0
			for slot in profile.get("equip", {}):
				var item: Variant = profile["equip"][slot]
				if item is Dictionary:
					best = maxi(best, int(item.get("plus", 0)))
			return best
		"gold": return int(profile.get("gold", 0))
		"guild": return 1 if int(flags.get("guild", 0)) > 0 else 0
		"gw_wins": return int(flags.get("gw_wins", 0))
		"tower": return maxi(int(flags.get("tower_best", 0)), int(profile.get("tower", {}).get("best", 0)))
		"dailies": return int(flags.get("dailies", 0))
		"tutorial": return 1 if int(flags.get("tut", 0)) == TUTORIAL_DONE else 0
		"chat": return int(flags.get(CHAT_FLAG, 0))
		_: return 0


## Haggles accepted (StallStock.HAGGLE_ACCEPTED) and lots consigned among the flags now.
static func stall_counts(flags: Dictionary) -> Array[int]:
	var haggles := 0
	var consigns := 0
	for key in flags:
		var text := String(key)
		if text.begins_with(StallStock.HAGGLE_FLAG):
			if int(flags[key]) == StallStock.HAGGLE_ACCEPTED:
				haggles += 1
		elif text.begins_with(StallStock.CONSIGN_FLAG):
			consigns += 1
	return [haggles, consigns]


## Brings the sticky counters up to date, then marks every achievement whose goal is met
## and returns the ids earned just now (in TABLE order). live: "party" = members in the
## party now (Game.world_party.size()).
static func check_all(profile: Dictionary, live := {}) -> Array:
	if not profile.get("ach") is Dictionary:
		profile["ach"] = {}
	if not profile.get("flags") is Dictionary:
		profile["flags"] = {}
	var flags: Dictionary = profile["flags"]
	if int(live.get("party", 0)) > 0:
		flags[PARTY_FLAG] = 1
	var counts := stall_counts(flags)
	if counts[0] > int(flags.get(HAGGLE_FLAG, 0)):
		flags[HAGGLE_FLAG] = counts[0]
	if counts[1] > int(flags.get(CONSIGN_FLAG, 0)):
		flags[CONSIGN_FLAG] = counts[1]
	var ach: Dictionary = profile["ach"]
	var fresh: Array = []
	for row in TABLE:
		if ach.get(row.id, false) == true or value_of(row.kind, profile) < int(row.goal):
			continue
		ach[row.id] = true
		fresh.append(row.id)
	return fresh


static func is_earned(id: String, profile: Dictionary) -> bool:
	return profile.get("ach", {}).get(id, false) == true


## The ids earned so far, in TABLE order.
static func earned(profile: Dictionary) -> Array:
	var out: Array = []
	for row in TABLE:
		if is_earned(row.id, profile):
			out.append(row.id)
	return out


## "63/100" for the menu (capped at the goal).
static func progress(id: String, profile: Dictionary) -> String:
	var row := entry(id)
	if row.is_empty():
		return ""
	var goal := int(row.goal)
	return "%d/%d" % [mini(value_of(row.kind, profile), goal), goal]


## The index (in TABLE) of the chosen title's achievement, -1 for none.
static func title_index(profile: Dictionary) -> int:
	var k := int(profile.get("flags", {}).get(TITLE_FLAG, -1))
	return k if k >= 0 and k < TABLE.size() else -1


## The title the hero wears: "" when none is chosen, or the chosen one is not earned or
## grants no title (a wiped profile).
static func title_of(profile: Dictionary) -> String:
	var k := title_index(profile)
	if k < 0 or not is_earned(TABLE[k].id, profile):
		return ""
	return title_text(TABLE[k], profile)


## The title an achievement grants this hero: the God one names the hero's class
## (เทพเจ้าแห่งดาร์กลอร์ด), every other one is the same for everyone.
static func title_text(row: Dictionary, profile: Dictionary) -> String:
	if String(row.get("id", "")) == GOD_ID:
		return JobData.god_name(StringName(profile.get("class", "warrior")))
	return String(row.get("title", ""))


## Wears the title of the achievement at index (a negative index takes the title off).
## False when the achievement is not earned or grants no title; nothing changes then.
static func set_title(profile: Dictionary, index: int) -> bool:
	if not profile.get("flags") is Dictionary:
		profile["flags"] = {}
	if index < 0:
		profile["flags"].erase(TITLE_FLAG)
		return true
	if index >= TABLE.size() or not is_earned(TABLE[index].id, profile) or String(TABLE[index].title) == "":
		return false
	profile["flags"][TITLE_FLAG] = index
	return true
