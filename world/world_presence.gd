class_name WorldPresence
extends Node
## Shows the world players (WorldPlayers) who are online in this zone right now: they walk
## in, hunt the field's monsters, level up as their schedule says and log off when their
## session ends; the village shows only the stall keepers (players taking a break, who
## sell what they found: StallStock), each at a stall of its own, and the players in on
## a short errand (WorldPlayers.errand_at), standing at the villager it is for. Checked every
## few seconds; lower quality shows fewer at once (and memory pressure fewer still). Also
## announces milestones (job advancement levels, Lv.100, star tiers, the divine set, its
## enhancement, newcomers) of any world player, wherever it is, like a server message, and
## keeps the world chat going: what the online players say (Game.world_chat), with a
## bubble over the speaker's head when it stands here.

const CHECK := 12.0
## Shown at once in a field and in the village, by quality (low, medium, high).
const LIMITS := [5, 6, 8]
const TOWN_LIMITS := [20, 24, 28]
## Under memory pressure (MemoryGuard 1, 2) at most this many in the village.
const TOWN_PRESSURE := [16, 12]
## Seconds between two lines of the world chat (randomly 0.6-1.4 times this).
const CHAT_EVERY := 7.0
## At most one stall keeper's call about a lot of its (StallStock.announcement) in this
## many seconds of the world chat.
const STALL_ANNOUNCE := 90.0
## The same chat line is never said twice within this many seconds (by anyone).
const REPEAT_WINDOW := 300.0
const REPEAT_TRIES := 6
## Line -> chat_clock() when it was last said (across zones).
static var _said := {}
static var chat_clock_override := -1.0
const ANNOUNCE_LEVELS := [10, 20, 40, 60, 80, 100]
const ANNOUNCE_STARS := [50, 100, 150, 200, 250, 300]

## Seconds added to the clock (tests move time forward). TOON_WORLD_DAYS=x starts the
## clock x days after the world opened (for screenshots and soak runs).
static var clock_offset := _days_offset()
## Off in headless runs so every other test meets the same field whatever the time of day;
## tests of the world players switch it on (so does TOON_WORLD_PLAYERS=1).
static var enabled := DisplayServer.get_name() != "headless" or OS.get_environment("TOON_WORLD_PLAYERS") == "1"
## TOON_WORLD_PLAYERS=1 (probes and shots) also shows them in the zones.
static var _show_env := _apply_show_env()


static func _apply_show_env() -> bool:
	if OS.get_environment("TOON_WORLD_PLAYERS") == "1":
		GameSettings.show_world_players = true
	return true
## Last progress seen per world player, kept across zones so a milestone is told once.
static var _seen := {}

var zone: Zone
var shown := {}
var _timer := 0.0
var _chat_in := 2.5
## Engine seconds when a stall keeper last called out a lot.
var _stall_said_at := -STALL_ANNOUNCE
## The online players' states at the last check (the world chat's speakers).
var _online: Array[Dictionary] = []
## Stall (JapanVillage.STALLS index) -> the world player keeping it.
var _stalls := {}


func setup(p_zone: Zone) -> void:
	zone = p_zone


static func clock() -> float:
	return WorldPlayers.now() + clock_offset


static func _days_offset() -> float:
	var days := OS.get_environment("TOON_WORLD_DAYS")
	if days == "" or not days.is_valid_float():
		return 0.0
	return float(WorldPlayers.START_UNIX) + float(days) * 86400.0 - WorldPlayers.now()


func _ready() -> void:
	sync(true)


func _process(delta: float) -> void:
	if zone == null or not zone.is_built:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = CHECK
		sync(false)
	_chat_in -= delta
	if _chat_in <= 0.0:
		_chat_in = CHAT_EVERY * randf_range(0.6, 1.4)
		chat_once()


## How many world players are online at time t (the hero not counted).
static func online_count(t: float = -1.0) -> int:
	if t < 0.0:
		t = clock()
	var n := 0
	for i in WorldPlayers.size():
		n += 1 if not WorldPlayers.session_at(i, t).is_empty() else 0
	return n


## Who should stand here now; spawns arrivals, removes those who left.
func sync(initial: bool) -> void:
	if zone == null or not is_instance_valid(zone.hero):
		return
	var t := clock()
	# Party members walk with the hero (Zone companions); those whose session ended leave.
	Game.party_refresh(t)
	var here: Array[Dictionary] = []
	_online.clear()
	for i in WorldPlayers.size():
		var s := WorldPlayers.state(i, t)
		_announce(s, t)
		if bool(s.online):
			_online.append(s)
		if bool(s.online) and StringName(s.place) == zone.zone_id and not Game.in_party(i):
			# The village is the stall keepers' and the errand runners' (the scheduled
			# players otherwise are out levelling).
			if zone.is_town and String(s.doing) not in ["stall", "errand"]:
				continue
			here.append(s)
	# Those already shown stay first, then the roster order turned by the hour so the same
	# few are not always the ones picked.
	var n := WorldPlayers.size()
	var turn := int(t / 3600.0) % n
	here.sort_custom(func(a, b):
		var sa := 0 if shown.has(int(a.index)) else 1
		var sb := 0 if shown.has(int(b.index)) else 1
		if sa != sb:
			return sa < sb
		return (int(a.index) - turn + n) % n < (int(b.index) - turn + n) % n)
	var cap := limit_here(zone.is_town)
	var limit: int = maxi(1, cap - Game.party().size()) if cap > 0 else 0
	var keep := {}
	if zone.is_town:
		# Stall keepers first, one a stall (never more than there are stalls), keeping a few
		# places for the errand runners; the errand runners fill the rest of the limit.
		var keepers := here.filter(func(s): return String(s.doing) == "stall")
		var runners := here.filter(func(s): return String(s.doing) == "errand")
		var seats := mini(limit, mini(JapanVillage.STALLS.size(), limit - mini(ERRAND_SEATS, runners.size())))
		for k in mini(seats, keepers.size()):
			keep[int(keepers[k].index)] = keepers[k]
		for k in mini(limit - keep.size(), runners.size()):
			keep[int(runners[k].index)] = runners[k]
	else:
		for k in mini(limit, here.size()):
			keep[int(here[k].index)] = here[k]
	for i in shown.keys():
		if not keep.has(i):
			var gone: FieldPlayer = shown[i]
			if is_instance_valid(gone):
				gone.leave()
			shown.erase(i)
	for k in _stalls.keys():
		if not shown.has(int(_stalls[k])):
			_stalls.erase(k)
	var arrivals: Array[int] = []
	for i in keep:
		var s: Dictionary = keep[i]
		if shown.has(i) and is_instance_valid(shown[i]):
			var p := shown[i] as FieldPlayer
			p.sync_progress(s)
			if p.doing == "stall" and not p.stall_at.is_finite():
				_give_stall(p)
			if p.doing == "errand" and (p.errand != String(s.errand) or not p.errand_at.is_finite()):
				_give_errand(p, s)
			continue
		if initial:
			_spawn(i, t, initial, s)
		else:
			arrivals.append(i)
	if not arrivals.is_empty():
		_spawn_arrivals(arrivals, t, keep)


## Building a player (its rig, outfit, gear and glow) is a few milliseconds of work: the
## arrivals of one sync come one per frame instead of all in the same frame.
func _spawn_arrivals(arrivals: Array[int], t: float, keep: Dictionary) -> void:
	for i in arrivals:
		if zone == null or not is_instance_valid(zone) or not is_inside_tree():
			return
		if shown.has(i) and is_instance_valid(shown[i]):
			continue
		_spawn(i, t, false, keep[i])
		await get_tree().process_frame


## How many world players this zone shows at once now.
static func limit_here(town: bool) -> int:
	if GameSettings.safe_picture or not GameSettings.show_world_players:
		return 0
	var q := clampi(GameSettings.quality, 0, 2)
	if not town:
		return int(LIMITS[q])
	var limit := int(TOWN_LIMITS[q])
	if MemoryGuard.pressure > 0:
		limit = mini(limit, int(TOWN_PRESSURE[clampi(MemoryGuard.pressure - 1, 0, 1)]))
	return limit


## Player i standing here joins the hero's party where it is (Zone._spawn_party): it is
## handed over and no longer shown as hunting alone. null when it is not here.
func adopt(i: int) -> FieldPlayer:
	var p: Variant = shown.get(i)
	shown.erase(i)
	if p == null or not is_instance_valid(p) or (p as Node).is_queued_for_deletion():
		return null
	return p as FieldPlayer


## A member let go while still online goes back to hunting here.
func release(p: FieldPlayer) -> void:
	p.leave_party()
	shown[p.world_index] = p


func _spawn(i: int, t: float, initial: bool, s: Dictionary = {}) -> void:
	var p := FieldPlayer.new()
	p.setup_world(i, WorldPlayers.member(i, t), zone.hero, zone)
	p.doing = String(s.get("doing", ""))
	zone.add_child(p)
	var at := zone.entrance()
	shown[i] = p
	if p.doing == "stall" and zone.is_town and _give_stall(p):
		p.global_position = p.stall_at + Vector3(0, 0.3, 0)
		return
	if p.doing == "errand" and zone.is_town and _give_errand(p, s):
		# Already at the villager when the hero arrives, otherwise in from the warp stone.
		at = p.errand_at if initial else p.errand_exit
		p.global_position = at + Vector3(0, 0.3, 0)
		if not initial:
			VfxKit.flash(zone, p.global_position + Vector3(0, 1.0, 0), Color("bfe8ff"), 1.4)
		return
	if initial and not zone.is_town:
		var camp := p.camp()
		if not camp.is_empty():
			at = Vector3(camp.pos.x, 0.0, camp.pos.y)
	elif initial:
		at += Vector3(randf_range(-6.0, 6.0), 0, randf_range(-8.0, -2.0))
	p.global_position = at + Vector3(randf_range(-2.0, 2.0), 0.3, randf_range(-2.0, 2.0))
	if not initial:
		VfxKit.flash(zone, p.global_position + Vector3(0, 1.0, 0), Color("bfe8ff"), 1.4)
	shown[i] = p


## Hands a stall keeper in the village a free stall (its own favourite first); false when
## every stall is taken (sync never shows more keepers than there are stalls).
func _give_stall(p: FieldPlayer) -> bool:
	if not zone.is_town:
		return false
	var n := JapanVillage.STALLS.size()
	var first := hash("stall|%s" % p.member.name) % n
	for k in n:
		var at := (first + k) % n
		if not _stalls.has(at):
			_stalls[at] = p.world_index
			p.stall_at = JapanVillage.STALLS[at]
			p.stall_face = JapanVillage.stall_face(p.stall_at)
			return true
	return false


## The villager each errand goes to (Zone._villagers roles).
const ERRAND_NPC := {"quest": "elder", "enhance": "forge", "skill": "skill"}
## Places in the village kept for the errand runners while any are about.
const ERRAND_SEATS := 4


## Sends an errand runner to its villager: a spot of its own in front of it (by its name),
## facing it, and the warp stone to walk back to as the errand ends; false outside the
## village or without that villager.
func _give_errand(p: FieldPlayer, s: Dictionary) -> bool:
	if not zone.is_town:
		return false
	p.errand = String(s.get("errand", ""))
	p.errand_until = float(s.get("errand_until", 0.0))
	if p._label != null:
		p._label.text = p._level_text()
	var role := String(ERRAND_NPC.get(p.errand, ""))
	for v in zone._villagers():
		if String(v[0]) != role:
			continue
		var pos: Vector3 = v[4]
		var front := Vector3(v[6].x - pos.x, 0, v[6].z - pos.z).normalized()
		var side := Vector3(front.z, 0, -front.x)
		var h := hash("errand_spot|%s" % p.member.name)
		p.errand_at = pos + front * (2.2 + float(h / 7 % 2) * 1.3) + side * (float(h % 7) - 3.0) * 0.9
		p.errand_face = -front
		p.errand_exit = zone.entrance()
		for npc in zone.npcs:
			if is_instance_valid(npc) and "role" in npc and String(npc.role) == "warp":
				p.errand_exit = (npc as Node3D).global_position + side * 1.5
		return true
	return false


## A server message when someone reaches a milestone (only for progress seen happening):
## the big ones also as a toast, every one in the world chat.
func _announce(s: Dictionary, t: float) -> void:
	var i := int(s.index)
	var plus := WorldPlayers.divine_plus(s)
	var joined := t >= WorldPlayers.joined_at(i)
	var now := [int(s.level), int(s.stars), bool(s.divine), plus, joined]
	if not _seen.has(i):
		_seen[i] = now
		return
	var was: Array = _seen[i]
	_seen[i] = now
	var tag := ("[%s] %s" % [WorldPlayers.guild_name(int(s.guild)), s.name]) if int(s.guild) > 0 else String(s.name)
	if not bool(was[4]) and joined:
		_server("ผู้เล่นใหม่ %s เข้าสู่โลกแล้ว ยินดีต้อนรับ!" % s.name, &"info")
	for lv in ANNOUNCE_LEVELS:
		if int(was[0]) < lv and int(now[0]) >= lv:
			_server("%s ถึงเลเวล %d แล้ว!" % [tag, lv], &"info", lv >= Game.GUILD_LEVEL)
	if int(was[0]) < Game.GUILD_LEVEL and int(now[0]) >= Game.GUILD_LEVEL and int(s.joins) > 0:
		_server("%s เข้าร่วมกิลด์ %s แล้ว!" % [s.name, WorldPlayers.guild_name(int(s.joins))], &"quest", true)
	for st in ANNOUNCE_STARS:
		if int(was[1]) < st and int(now[1]) >= st:
			_server("%s ถึง %d ดาวแล้ว!" % [tag, st], &"quest", true)
	if not bool(was[2]) and bool(now[2]):
		_server("%s ได้ชุดเทพประจำอาชีพครบชุดแล้ว!" % tag, &"quest", true)
	if plus > int(was[3]) and plus >= 5:
		_server("%s ตีบวกชุดเทพ +%d สำเร็จ!" % [tag, plus], &"quest", plus >= 9)


func _server(text: String, kind: StringName, toast := false) -> void:
	Game.world_chat.emit("ประกาศ", text, Color("ffd24a"))
	if toast:
		Game.say("ประกาศ: " + text, kind)


## One line of the world chat: an online player says something that fits what it is doing,
## with a bubble over its head when it stands here.
func chat_once() -> void:
	if _online.is_empty():
		return
	if _stall_announcement():
		return
	var s: Dictionary = _online[randi() % _online.size()]
	# Most lines come from players nearby, so the bubbles are seen.
	var near := shown.keys().filter(func(k): return is_instance_valid(shown[k]))
	if not near.is_empty() and randf() < 0.6:
		var k: int = near[randi() % near.size()]
		for o in _online:
			if int(o.index) == k:
				s = o
				break
	var text := fresh_line(s)
	if text == "":
		return
	var g := int(s.guild)
	Game.world_chat.emit(String(s.name), text, WorldPlayers.GUILD_COLORS.get(g, Color("bfe8ff")))
	var p: Variant = shown.get(int(s.index))
	if p != null and is_instance_valid(p):
		(p as FieldPlayer).bubble(text)


## A line for player state s that nobody said in the last REPEAT_WINDOW seconds (another
## pick up to REPEAT_TRIES times; "" when all were said, and this turn stays quiet). Two
## players asking the very same thing seconds apart read like bots.
static func fresh_line(s: Dictionary) -> String:
	var now := chat_clock()
	for text in _said.keys():
		if now - float(_said[text]) > REPEAT_WINDOW:
			_said.erase(text)
	for i in REPEAT_TRIES:
		var text := WorldChat.line_for(s, randi())
		if not _said.has(text):
			_said[text] = now
			return text
	return ""


## Seconds for the repeat window (tests set chat_clock_override; below 0 the engine clock).
static func chat_clock() -> float:
	return chat_clock_override if chat_clock_override >= 0.0 else Time.get_ticks_msec() * 0.001


## Now and then (at most once in STALL_ANNOUNCE seconds, and about every other chance after
## that) a stall keeper standing here calls out one of its lots instead of the usual line.
func _stall_announcement() -> bool:
	var ticks := float(Time.get_ticks_msec()) / 1000.0
	if ticks - _stall_said_at < STALL_ANNOUNCE or randf() < 0.5:
		return false
	var keepers := shown.keys().filter(func(k): return is_instance_valid(shown[k]) and (shown[k] as FieldPlayer).doing == "stall")
	if keepers.is_empty():
		return false
	var k: int = keepers[randi() % keepers.size()]
	var text := StallStock.announcement(k)
	if text == "":
		return false
	_stall_said_at = ticks
	Game.world_chat.emit(String(WorldPlayers.entry(k).name), text, Color("8ff0ff"))
	(shown[k] as FieldPlayer).bubble(text)
	return true
