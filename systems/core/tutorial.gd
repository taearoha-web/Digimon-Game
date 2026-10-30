class_name Tutorial
extends Node
## The first five minutes: a new hero (below Lv.4, profile.flags["tut"] unfinished) is walked
## through the village step by step. An online world player joins the party as the guide
## (Game.party_invite forced, only when the party is empty) and talks through its bubble and
## the world chat (PartyTalk.guide_line); every step shows a banner and a hint toast, and the
## hint is repeated every HINT_EVERY seconds while the step is pending. Steps finish from the
## game state alone: 1 greeting, 2 a quest taken, 3 a potion bought, 4 the first field,
## 5 three kills, 6 a quest turned in, 7 the gift (five potions). flags["tut"] is the step
## (0 not started, DONE finished or skipped); a hero reaching Lv.6 ends it silently. It lives
## on Main (it survives zone changes) and runs only while a hero is in play.

const FLAG := "tut"
## The guide's world index, the kills and the hp potions when steps 5 and 3 began.
const GUIDE_FLAG := "tut_g"
const KILLS_FLAG := "tut_k"
const POTIONS_FLAG := "tut_p"
const DONE := 99
const LAST_STEP := 6
## Starts only below this level; ends silently at SKIP_AT.
const START_BELOW := 4
const SKIP_AT := 6
const KILLS_NEEDED := 3
const GIFT := 5
const TICK := 0.5
const HINT_EVERY := 25.0
## The greeting step lasts this long before the first task is asked.
const GREET_TIME := 4.0
## The guide says goodbye, then leaves the party this long after the finish.
const GOODBYE_TIME := 2.5
const CHAT_COLOR := Color("ffe9a8")
const HINTS := {
	1: "มือใหม่ยินดีต้อนรับ! เดินสำรวจหมู่บ้านกับไกด์กันก่อน",
	2: "คุยกับผู้ใหญ่บ้านรับเควสแรก",
	3: "ซื้อยาเลือดที่ร้านค้าสัก 2-3 ขวด",
	4: "ไปสนามแรกทางวาร์ปสโตน",
	5: "ล้มมอนสเตอร์ 3 ตัว",
	6: "กลับมาส่งเควสที่ผู้ใหญ่บ้าน",
}
const FINISH_BANNER := "จบบทสอนเล่น! ของขวัญ: ยาเลือด 5 ขวด"

var main: Node
## The step in progress, 0 while nothing runs.
var step := 0
## The guide's world index (-1 none) and whether the tutorial put it in the party.
var guide := -1
var guide_forced := false
## Every banner and hint shown, in order (tests).
var shown: Array[String] = []
var _profile: Dictionary = {}
var _clock := 0.0
var _tick := 0.0
var _hint_at := -INF
var _step_at := 0.0
var _guide_gone := false
var _hero_invited := false


func _ready() -> void:
	name = "Tutorial"
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(delta: float) -> void:
	_clock += delta
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = TICK
	if not _in_play():
		if step != 0:
			_stop()
		return
	if step != 0 and not is_same(Game.profile, _profile):
		_stop()
	if not _zone_ready():
		return  # between zones: the steps wait, nothing is forgotten
	if step == 0:
		_maybe_start()
	else:
		_check()


## A hero is in play (not the title or the character select).
func _in_play() -> bool:
	return main != null and Game.playing and Game.has_profile and main.title_screen == null


## The hero stands on a built zone (false for the frames of a trip between zones).
func _zone_ready() -> bool:
	var zone: Zone = main.zone
	return zone != null and is_instance_valid(zone) and zone.is_built


# --- Starting and stopping ---------------------------------------------------------------

func _maybe_start() -> void:
	var flags: Dictionary = Game.profile["flags"]
	var tut := int(flags.get(FLAG, 0))
	if tut >= DONE:
		return
	var level := int(Game.profile.get("level", 1))
	if level >= SKIP_AT or (tut == 0 and level >= START_BELOW):
		flags[FLAG] = DONE
		Game.mark_dirty()
		return
	_profile = Game.profile
	_guide_gone = false
	_hero_invited = false
	guide = -1
	guide_forced = false
	if tut == 0:
		_enter(1)
		return
	# Picked up where a reload left it: the guide stays if it is still in the party.
	var g := int(flags.get(GUIDE_FLAG, -1))
	if g >= 0 and Game.in_party(g):
		guide = g
	step = tut
	_step_at = _clock
	_show(step)


## The hero left the game (title screen, another character): forget it, the flags keep the step.
func _stop() -> void:
	step = 0
	guide = -1
	guide_forced = false
	_profile = {}


func _enter(s: int) -> void:
	var flags: Dictionary = Game.profile["flags"]
	step = s
	_step_at = _clock
	flags[FLAG] = s
	match s:
		1:
			_greet()
		3:
			flags[POTIONS_FLAG] = _hp_potions()
		5:
			flags[KILLS_FLAG] = int(Game.profile.get("kills", 0))
		7:
			_finish()
			return
	Game.mark_dirty()
	_show(s)


## Step 1: an online world player joins the party as the guide (only an empty party; a hero
## who already has company is guided by its first member) and says hello.
func _greet() -> void:
	var flags: Dictionary = Game.profile["flags"]
	if not Game.world_party.is_empty():
		guide = Game.world_party[0]
	else:
		var i := pick_guide(WorldPresence.clock())
		if i >= 0 and Game.party_invite(i, true) == "":
			guide = i
			guide_forced = true
	flags[GUIDE_FLAG] = guide


## The online world player to guide a newcomer: one without a guild (below Lv.100) and the
## lowest level first, else the first online; -1 when nobody is online.
static func pick_guide(t: float) -> int:
	var best := -1
	var best_key := INF
	for i in WorldPlayers.size():
		var s := WorldPlayers.state(i, t)
		if not bool(s.online):
			continue
		var key := float(int(s.level)) + (10000.0 if int(s.guild) > 0 else 0.0)
		if key < best_key:
			best_key = key
			best = i
	return best


# --- Steps ----------------------------------------------------------------------------------

func _check() -> void:
	var flags: Dictionary = Game.profile["flags"]
	if int(Game.profile.get("level", 1)) >= SKIP_AT:
		_end_silently()
		return
	if guide >= 0:
		if not Game.in_party(guide):
			_guide_gone = true
		elif _guide_gone:
			_hero_invited = true
	if _complete(step, flags):
		_enter(step + 1)
		return
	if _clock - _hint_at >= HINT_EVERY:
		_hint_at = _clock
		Game.say(hint(step), &"info")


## Whether the step is done, read from the game state.
func _complete(s: int, flags: Dictionary) -> bool:
	match s:
		1:
			return _clock - _step_at >= GREET_TIME
		2:
			return _quest_with(["active", "ready", "done"])
		3:
			# The starter pack already holds potions: the step asks for more than the hero
			# walked in with, and lets go when the hero heads for the field anyway.
			return _hp_potions() > int(flags.get(POTIONS_FLAG, 0)) or Game.current_zone != &"town"
		4:
			return Game.current_zone != &"town"
		5:
			return int(Game.profile.get("kills", 0)) - int(flags.get(KILLS_FLAG, 0)) >= KILLS_NEEDED
		6:
			return _quest_with(["done"])
	return false


## The step's hint, with the kill count for step 5.
func hint(s: int) -> String:
	var text := String(HINTS.get(s, ""))
	if s == 5 and Game.has_profile:
		var n := int(Game.profile.get("kills", 0)) - int(Game.profile["flags"].get(KILLS_FLAG, 0))
		text += " (%d/%d)" % [clampi(n, 0, KILLS_NEEDED), KILLS_NEEDED]
	return text


## The banner and the hint of a step, and the guide's line for it.
func _show(s: int) -> void:
	var text := hint(s)
	if text == "":
		return
	shown.append(text)
	if main.hud != null:
		main.hud.show_banner(text)
	Game.say(text, &"info")
	_hint_at = _clock
	_guide_say(PartyTalk.guide_line(s))


func _finish() -> void:
	var flags: Dictionary = Game.profile["flags"]
	flags[FLAG] = DONE
	flags.erase(KILLS_FLAG)
	flags.erase(POTIONS_FLAG)
	shown.append(FINISH_BANNER)
	if main.hud != null:
		main.hud.show_banner(FINISH_BANNER)
	Game.add_item(ItemData.potion("hp_s", GIFT))
	Game.say(FINISH_BANNER, &"success")
	_guide_say(PartyTalk.guide_line(LAST_STEP + 1))
	var g := guide
	var leaves := guide_forced and not _hero_invited
	step = 0
	_profile = {}
	Game.mark_dirty()
	if g >= 0 and leaves:
		var t := get_tree().create_timer(GOODBYE_TIME)
		t.timeout.connect(func():
			if Game.has_profile and Game.in_party(g):
				Game.party_kick(g, "%s ขอตัวไปล่าต่อแล้ว โชคดีนะ!" % _guide_name(g)))


## Lv.6 without finishing: the tutorial is over without a word (the forced guide goes too).
func _end_silently() -> void:
	Game.profile["flags"][FLAG] = DONE
	if guide >= 0 and guide_forced and not _hero_invited and Game.in_party(guide):
		Game.party_kick(guide)
	Game.mark_dirty()
	_stop()


# --- Helpers --------------------------------------------------------------------------------

func _quest_with(statuses: Array) -> bool:
	for state in Game.profile.get("quests", {}).values():
		if state is Dictionary and String(state.get("status", "new")) in statuses:
			return true
	return false


## HP potions of any size in the bag.
func _hp_potions() -> int:
	var n := 0
	for item in Game.profile.get("inv", []):
		if item.get("kind", "") == "potion" and String(item.get("id", "")).begins_with("hp_"):
			n += int(item.get("count", 1))
	return n


## The guide's line: its bubble when it stands in the zone, and the world chat under its name.
func _guide_say(text: String) -> void:
	if guide < 0 or text == "" or not Game.in_party(guide):
		return
	var p := _guide_player()
	if p != null:
		p.bubble(text)
	Game.world_chat.emit(_guide_name(guide), text, CHAT_COLOR)


func _guide_player() -> FieldPlayer:
	var zone: Zone = main.zone
	if zone == null or not is_instance_valid(zone):
		return null
	for c in zone.companions:
		var p := c as FieldPlayer
		if p != null and is_instance_valid(p) and p.party_mode and p.world_index == guide:
			return p
	return null


static func _guide_name(i: int) -> String:
	return String(WorldPlayers.entry(i).get("name", ""))
