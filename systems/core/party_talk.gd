class_name PartyTalk
extends Node
## The hero's party members talk (FieldPlayer in party_mode): short lines in combat chosen
## by what is going on (the hero bleeding, a boss, a kill streak, their own HP, a level-up,
## the hero standing about in a field), shown as the member's bubble and in the world chat
## under its name. Rate-limited: a member speaks at most once every MEMBER_GAP seconds, and
## no two members within GLOBAL_GAP of each other. One per zone, attached by the first
## party member that walks in (attach); `command` answers the hero's typed orders
## ("ตามมา", "รอตรงนี้", "กลับเมือง"), `route` is the hook for AiChat.

signal line_spoken(member: FieldPlayer, text: String)

const MEMBER_GAP := Vector2(25.0, 60.0)
const GLOBAL_GAP := 4.0
const TICK := 0.5
const HERO_LOW := 0.35
const OWN_LOW := 0.3
const IDLE_AFTER := 40.0
const STREAK_KILLS := 5
const STREAK_WINDOW := 12.0
## A repeated situation (the hero still bleeding) is mentioned again after this long.
const REPEAT_GAP := 30.0
## A line waiting its turn (a level-up while someone else just spoke) is dropped after this.
const QUEUE_LIFE := 15.0
## A boss farther than this is not seen yet.
const SIGHT := 45.0
const CHAT_COLOR := Color("bfe8ff")

const HERO_LOW_LINES := ["เลือดน้อยแล้ว กินยาเร็ว!", "ระวัง! เลือดเหลือน้อยแล้วนะ", "ถอยก่อน กินยาเลือดก่อน!"]
const HERO_LOW_PRIEST := ["เลือดน้อยแล้ว เดี๋ยวฮีลให้!", "อดทนไว้ กำลังฮีลให้นะ!"]
const BOSS_LINES := ["บอสมาแล้ว ระวัง!", "บอสโผล่แล้ว ตั้งใจหน่อย!", "ระวัง บอสตัวนี้แรงนะ!"]
const ELITE_LINES := ["ตัวนี้ไม่ธรรมดา ระวังด้วย!", "มอนหัวหน้ามาแล้ว ช่วยกัน!"]
const STREAK_LINES := ["ล้มรัว ๆ เลย โหดจริง!", "ฟาร์มลื่นมาก ไปต่อ!", "ตีมันส์มาก 555"]
const OWN_LOW_LINES := ["เลือดฉันเหลือน้อย ขอถอยแป๊บ!", "โดนหนักเลย ขอกินยาก่อน", "ช่วยด้วย เลือดจะหมดแล้ว!"]
const LEVEL_LINES := ["เลเวลอัปแล้ว!", "เลเวลอัป! ขอบคุณที่พาเก็บนะ", "เลเวลขึ้นแล้ว ไปต่อกัน!"]
const IDLE_LINES := ["ไปต่อไหม?", "พักพอหรือยัง ไปล่าต่อกันไหม", "มอนรออยู่นะ ไปต่อกันเถอะ"]
const REGROUP_LINES := ["มาแล้ว!", "ตามไปแล้วนะ", "โอเค กำลังไป!"]
const HOLD_LINES := ["โอเค รอตรงนี้นะ", "ได้ ยืนรอตรงนี้", "รับทราบ ไม่ไปไหน"]
const HOME_LINES := ["โอเค กลับเมืองกัน", "ได้เลย กลับหมู่บ้านกัน", "ตกลง ไปพักที่เมืองกัน"]
const IN_TOWN_LINES := ["ก็อยู่ในเมืองแล้วนี่ 555", "อยู่หมู่บ้านอยู่แล้วนะ"]
## What the tutorial's guide (Tutorial) says at each step of the first five minutes: the
## greeting when it joins (1), then the hint for the step, and goodbye when it is over (7).
const GUIDE_LINES := {
	1: ["สวัสดี! มือใหม่ใช่ไหม เดี๋ยวพาเที่ยวหมู่บ้านนะ"],
	2: ["ไปหาผู้ใหญ่บ้านก่อนเลย แกมีเควสให้ทำ", "ผู้ใหญ่บ้านอยู่ทางโน้น คุยรับเควสแรกกัน"],
	3: ["แวะร้านค้าซื้อยาเลือดติดตัวไว้หน่อย", "ก่อนออกสนามซื้อยาเลือดสัก 2-3 ขวดนะ"],
	4: ["ไปสนามแรกกัน ใช้วาร์ปสโตนตรงกลางหมู่บ้าน", "พร้อมแล้วก็ไปทุ่งหญ้ากันเลย วาร์ปสโตนอยู่นี่"],
	5: ["ลองล้มมอนสเตอร์ดูสัก 3 ตัว เดี๋ยวช่วยตี", "ตีตัวนี้ก่อน ฉันคุ้มกันให้เอง!"],
	6: ["ครบแล้ว กลับไปส่งเควสที่ผู้ใหญ่บ้านกัน", "เก่งมาก! กลับหมู่บ้านไปรับรางวัลกันเถอะ"],
	7: ["เก่งขึ้นเยอะเลย ฉันขอตัวไปล่าต่อนะ โชคดี!", "จบบทสอนแล้ว ที่เหลือลุยเองได้แน่นอน บ๊ายบาย!"],
}
## The hero's typed orders: what they do, and the words that mean them.
const COMMANDS := [
	["regroup", ["ตามมา", "ตามฉันมา", "มานี่", "รวมพล", "ตามเรามา"]],
	["hold", ["รอตรงนี้", "รอก่อน", "อยู่ตรงนี้", "หยุดรอ", "รอที่นี่"]],
	["home", ["กลับเมือง", "กลับหมู่บ้าน", "กลับบ้าน"]],
]

## The talk of the zone the hero is in (null between zones).
static var current: PartyTalk

var zone: Zone
var hero: Hero
## Every line said, in order: [name, text] (tests).
var spoken: Array = []
var _rng := RandomNumberGenerator.new()
var _clock := 0.0
var _tick := 0.0
var _last_spoke := -INF
## world_index -> when that member may speak again.
var _member_ok: Dictionary = {}
## situation -> when it was last mentioned.
var _said: Dictionary = {}
var _seen: Dictionary = {}
var _kills: Array[float] = []
var _idle := 0.0
var _hero_at := Vector3.INF
var _queue: Array = []


## The zone's talk, made on first call (the first party member to walk in asks for it).
static func attach(p_zone: Zone) -> PartyTalk:
	if p_zone == null or not is_instance_valid(p_zone):
		return null
	if current != null and is_instance_valid(current) and current.zone == p_zone:
		return current
	var talk := PartyTalk.new()
	talk.name = "PartyTalk"
	talk.zone = p_zone
	talk.hero = p_zone.hero
	current = talk
	p_zone.add_child.call_deferred(talk)
	return talk


## The hook for the typed chat (AiChat): true when the line was an order to the party.
static func route(text: String) -> bool:
	return current != null and is_instance_valid(current) and current.command(text)


## A line for the tutorial's guide at `step` (GUIDE_LINES), "" for a step without one.
static func guide_line(step: int) -> String:
	var pool: Array = GUIDE_LINES.get(step, [])
	return "" if pool.is_empty() else String(pool[randi() % pool.size()])


func _ready() -> void:
	_rng.randomize()
	if hero == null:
		hero = zone.hero
	zone.child_entered_tree.connect(_on_child)
	for node in get_tree().get_nodes_in_group("mobs"):
		_on_child(node)
	if not Game.party_leveled.is_connected(_on_leveled):
		Game.party_leveled.connect(_on_leveled)


func _exit_tree() -> void:
	if Game.party_leveled.is_connected(_on_leveled):
		Game.party_leveled.disconnect(_on_leveled)
	if current == self:
		current = null


func _on_child(node: Node) -> void:
	var mob := node as Mob
	if mob != null and not mob.died.is_connected(_on_mob_died):
		mob.died.connect(_on_mob_died)


func _on_mob_died(_mob: Mob) -> void:
	_kills.append(_clock)


func _on_leveled(k: int, _level: int) -> void:
	var m := _member_at(k)
	if m != null:
		_queue.append({"who": m, "text": _pick(LEVEL_LINES), "until": _clock + QUEUE_LIFE})


func _process(delta: float) -> void:
	_clock += delta
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = TICK
	if hero == null or not is_instance_valid(hero) or not is_instance_valid(zone) or not zone.is_built:
		return
	var members := _members()
	if members.is_empty():
		return
	_watch_idle()
	if _flush_queue():
		return
	if hero.is_dead():
		return
	if not hero.safe_zone:
		if _hero_low(members) or _boss(members) or _own_low(members) or _streak(members):
			return
	if _idle > IDLE_AFTER and not _said.has("idle"):
		var m := _speaker(members)
		if m != null:
			_said["idle"] = _clock
			_speak(m, _pick(IDLE_LINES))


# --- Situations ------------------------------------------------------------------------

func _hero_low(members: Array) -> bool:
	if _hero_hp() >= HERO_LOW or not _due("hero_low"):
		return false
	var m := _speaker(members, &"priest")
	if m == null:
		return false
	_said["hero_low"] = _clock
	_speak(m, _pick(HERO_LOW_PRIEST if StringName(m.member.get("class", "")) == &"priest" else HERO_LOW_LINES))
	return true


## A boss or elite monster seen for the first time, within sight of the hero.
func _boss(members: Array) -> bool:
	for node in get_tree().get_nodes_in_group("mobs"):
		var mob := node as Mob
		if mob == null or mob.is_dead() or _seen.has(mob.get_instance_id()):
			continue
		var elite := bool(mob.template.get("elite", false))
		if not mob.is_boss and not elite:
			continue
		if _flat(mob.global_position - hero.global_position).length() > SIGHT:
			continue
		var m := _speaker(members)
		if m == null:
			return false
		_seen[mob.get_instance_id()] = true
		_speak(m, _pick(BOSS_LINES if mob.is_boss else ELITE_LINES))
		return true
	return false


func _own_low(members: Array) -> bool:
	for m in members:
		var p := m as FieldPlayer
		if float(p.hp) / float(maxi(1, p.max_hp)) >= OWN_LOW:
			continue
		var key := "own_low|%d" % p.world_index
		if _due(key) and _can_speak(p):
			_said[key] = _clock
			_speak(p, _pick(OWN_LOW_LINES))
			return true
	return false


func _streak(members: Array) -> bool:
	_kills = _kills.filter(func(t: float) -> bool: return _clock - t <= STREAK_WINDOW)
	if _kills.size() < STREAK_KILLS or not _due("streak"):
		return false
	var m := _speaker(members)
	if m == null:
		return false
	_said["streak"] = _clock
	_kills.clear()
	_speak(m, _pick(STREAK_LINES))
	return true


## The hero standing about in a field with nothing to fight: the party asks to move on.
func _watch_idle() -> void:
	var at := hero.global_position
	var still := _hero_at.is_finite() and _flat(at - _hero_at).length() < 0.3
	var fighting := hero.target != null and is_instance_valid(hero.target)
	if still and not fighting and not hero.safe_zone and not hero.is_dead():
		_idle += TICK
	else:
		_idle = 0.0
		_said.erase("idle")
	_hero_at = at


# --- Orders ----------------------------------------------------------------------------

## The hero's typed line as an order to the party: true when it was one and was carried
## out ("ตามมา" regroup, "รอตรงนี้" hold where they stand, "กลับเมือง" head home).
func command(text: String) -> bool:
	var t := text.strip_edges()
	var members := _members(false)
	if t == "" or members.is_empty():
		return false
	for entry in COMMANDS:
		for word in entry[1]:
			if t.contains(String(word)):
				_run(String(entry[0]), members)
				return true
	return false


func _run(order: String, members: Array) -> void:
	var m := _speaker(members, &"", true)
	match order:
		"regroup":
			Game.set_party_stance("follow")
			for p in members:
				(p as FieldPlayer).hold_at = Vector3.INF
				(p as FieldPlayer).target = null
			_speak(m, _pick(REGROUP_LINES), true)
		"hold":
			Game.set_party_stance("guard")
			for p in members:
				(p as FieldPlayer).hold_at = (p as FieldPlayer).global_position
			_speak(m, _pick(HOLD_LINES), true)
		"home":
			if zone.is_town:
				_speak(m, _pick(IN_TOWN_LINES), true)
				return
			_speak(m, _pick(HOME_LINES), true)
			Game.say("ใช้ใบวาร์ปกลับเมืองในกระเป๋าเพื่อกลับหมู่บ้าน", &"info")


# --- Saying it -------------------------------------------------------------------------

## The member's bubble and its line in the world chat; `force` answers an order even when
## it just spoke (the gaps still start over).
func _speak(m: FieldPlayer, text: String, force := false) -> void:
	if m == null or not is_instance_valid(m) or (not force and not _can_speak(m)):
		return
	m.bubble(text)
	var g := WorldPlayers.guild_at(m.world_index, int(m.member.get("level", 1)))
	Game.world_chat.emit(String(m.member.get("name", "")), text, WorldPlayers.GUILD_COLORS.get(g, CHAT_COLOR))
	_last_spoke = _clock
	_member_ok[m.world_index] = _clock + _rng.randf_range(MEMBER_GAP.x, MEMBER_GAP.y)
	spoken.append([String(m.member.get("name", "")), text])
	line_spoken.emit(m, text)


func _flush_queue() -> bool:
	while not _queue.is_empty():
		var entry: Dictionary = _queue[0]
		var m := entry.who as FieldPlayer
		if m == null or not is_instance_valid(m) or m.is_dead() or _clock > float(entry.until):
			_queue.pop_front()
			continue
		if not _can_speak(m):
			return false
		_queue.pop_front()
		_speak(m, String(entry.text))
		return true
	return false


func _can_speak(m: FieldPlayer) -> bool:
	return _clock - _last_spoke >= GLOBAL_GAP and _clock >= float(_member_ok.get(m.world_index, -INF))


func _due(situation: String) -> bool:
	return _clock - float(_said.get(situation, -INF)) >= REPEAT_GAP


## A member allowed to speak now, a `prefer`red class first (a priest for healing talk);
## `any` ignores the gaps (answering an order).
func _speaker(members: Array, prefer: StringName = &"", any := false) -> FieldPlayer:
	var ok: Array = []
	for m in members:
		var p := m as FieldPlayer
		if any or _can_speak(p):
			ok.append(p)
	if ok.is_empty():
		return null
	if prefer != &"":
		for p in ok:
			if StringName((p as FieldPlayer).member.get("class", "")) == prefer:
				return p
	return ok[_rng.randi() % ok.size()]


## The party members here: alive and on screen unless `alive_only` is off.
func _members(alive_only := true) -> Array:
	var out: Array = []
	for c in zone.companions:
		var p := c as FieldPlayer
		if p == null or not is_instance_valid(p) or not p.party_mode:
			continue
		if alive_only and (p.is_dead() or not p.visible):
			continue
		out.append(p)
	return out


func _member_at(k: int) -> FieldPlayer:
	if k < 0 or k >= zone.companions.size():
		return null
	var p := zone.companions[k] as FieldPlayer
	return p if p != null and is_instance_valid(p) and p.party_mode else null


func _hero_hp() -> float:
	if not Game.has_profile or hero.stats.is_empty():
		return 1.0
	return float(Game.profile.get("hp", 0)) / float(maxi(1, int(hero.stats.get("max_hp", 1))))


func _pick(lines: Array) -> String:
	return String(lines[_rng.randi() % lines.size()])


static func _flat(v: Vector3) -> Vector3:
	v.y = 0.0
	return v


## Forgets every gap and mention so the next situation speaks at once (tests).
func reset_cooldowns() -> void:
	_last_spoke = -INF
	_member_ok.clear()
	_said.clear()
	_queue.clear()
