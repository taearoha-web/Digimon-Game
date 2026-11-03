class_name WorldPresence
extends Node
## Shows the world players (WorldPlayers) who are online in this zone right now: they walk
## in, hunt the field's monsters, level up as their schedule says and log off when their
## session ends; the village shows only the stall keepers (players taking a break, who
## sell what they found: StallStock), each at a stall of its own, and the players in on
## a short errand (WorldPlayers.errand_at), standing at the villager it is for. Checked every
## few seconds; lower quality shows fewer at once (and memory pressure fewer still). Also
## announces milestones (job advancement levels, Lv.100, star tiers, the divine set, its
## enhancement, the God promotion, newcomers) of any world player, wherever it is, like a
## server message, and keeps the chats going: the online players talk to each other
## (ChatThreads conversations and single lines in the world chat, the hero's guild mates
## and party members in theirs; buy requests answered by the stalls, ChatTrade), with a
## bubble over the speaker's head when it stands here, at a rate a phone's chat box can
## follow (RATE_CAP).
##
## Online (docs/ONLINE_PROTOCOL.md "Shared world"), every real player in the zone sees the
## same world players and the same world chat:
## - HOST (Online.is_zone_host, another real player here): runs its players as always and
##   sends `wp_snap` WP_SNAP_EVERY (roster index, x, z, yaw, anim, flags; at most WP_CAP,
##   only those within WP_NEAR of a real player) and `wp_event` for casts (skill id and the
##   target's shared eid), bubbles and leaving.
## - MIRROR (Online.is_mirror_zone): places and runs none of its own; shows exactly the
##   players of the host's latest snapshot as puppets (FieldPlayer.puppet). When the host
##   role comes here, or the link goes, the puppets carry on as ordinary world players
##   where they stand.
## - The AI world chat: while another player is the world host (`whost`), the world-chat
##   lines, conversations, buy requests and stall calls are not made here: the world
##   host's `ai_chat` lines are shown instead (a bubble over the speaker standing here).
##   The world host (or a game offline) makes them as always and, online, sends the lines
##   of each turn as one `ai_chat`. Guild / party chat, the answers to the hero and the
##   milestone announcements stay local.

const CHECK := 12.0
## Shown at once in a field and in the village, by quality (low, medium, high).
const LIMITS := [5, 6, 8]
const TOWN_LIMITS := [20, 24, 28]
## Under memory pressure (MemoryGuard 1, 2) at most this many in the village.
const TOWN_PRESSURE := [16, 12]
## Seconds between two turns of the world chat (randomly 0.6-1.4 times this; the timer
## waits while a conversation is still going). A turn is one line, or a conversation
## (THREAD_CHANCE: ChatThreads, one opens and 1-3 answer a few seconds apart), now and
## then a player looking to buy and the stalls answering (TRADE_CHANCE: ChatTrade).
const CHAT_EVERY := 6.0
const THREAD_CHANCE := 0.6
const TRADE_CHANCE := 0.15
## The chat stays readable on a phone: at most RATE_CAP lines of the players (world, guild
## and party together) in RATE_WINDOW seconds, never two within MIN_GAP seconds, and a
## pause of HERO_QUIET seconds after the hero speaks so the answers to it are read.
const RATE_WINDOW := 60.0
const RATE_CAP := 18
const MIN_GAP := 1.4
const HERO_QUIET := 6.0
## A queued line that waited this many gaps for room is dropped.
const MAX_PUT_OFF := 4
## Seconds between two guild-chat and two party-chat conversations (randomly in range).
const GUILD_EVERY := Vector2(40.0, 80.0)
const PARTY_EVERY := Vector2(50.0, 95.0)
## No party banter this soon after another party line (PartyTalk's warnings first).
const PARTY_HUSH := 12.0
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
var _guild_in := 25.0
var _party_in := 30.0
## Lines of a conversation still to come: [{at (chat_clock), channel, index, speaker,
## options, color, put_off}], the soonest first.
var _queue: Array = []
## chat_clock() of every line said lately (the rate cap).
var _posted: Array[float] = []
var _quiet_until := -1.0
var _party_said_at := -INF
## Engine seconds when a stall keeper last called out a lot.
var _stall_said_at := -STALL_ANNOUNCE
## The online players' states at the last check (the world chat's speakers).
var _online: Array[Dictionary] = []
## Stall (JapanVillage.STALLS index) -> the world player keeping it.
var _stalls := {}

## Online roles of this zone's world players (see the top).
enum { LOCAL, HOST, MIRROR }
const WP_SNAP_EVERY := 0.25
const WP_NEAR := 70.0
const WP_CAP := 40
## Seconds between two looks at the link and the zone host (signals switch at once too).
const MODE_CHECK := 0.5
## New puppets built per snapshot (a body is a few ms of work: no hitch on arrival).
const PUPPETS_PER_SNAP := 4
## wp_event frames a second at most (the snapshot carries the rest), and the burst.
const EVENT_RATE := 6.0
const EVENT_BURST := 8.0
const AI_CHAT_MAX := 8
var mode := LOCAL
var _mode_in := 0.0
var _snap_in := 0.0
var _ev_tokens := EVENT_BURST
## Host: reused rows of the snapshot, the real players' spots and who went out last.
var _rows: Array = []
var _row_pool: Array = []
var _real_pos := PackedVector3Array()
var _cands: Array = []
var _wired := {}
## Mirror: indices in the latest snapshot (reused).
var _snap_seen := {}
## World host: world-chat lines of this turn, sent as one `ai_chat`.
var _ai_out: Array = []


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
	mode = _wanted_mode()
	sync(true)
	Game.world_chat.connect(_on_world_line)
	Game.channel_chat.connect(_on_channel_line)
	Online.message.connect(_on_online_message)
	Online.host_changed.connect(_on_link_changed)
	Online.disconnected.connect(_on_link_changed)
	Online.connected.connect(_on_link_changed)


func _exit_tree() -> void:
	if Game.world_chat.is_connected(_on_world_line):
		Game.world_chat.disconnect(_on_world_line)
	if Game.channel_chat.is_connected(_on_channel_line):
		Game.channel_chat.disconnect(_on_channel_line)
	if Online.message.is_connected(_on_online_message):
		Online.message.disconnect(_on_online_message)
		Online.host_changed.disconnect(_on_link_changed)
		Online.disconnected.disconnect(_on_link_changed)
		Online.connected.disconnect(_on_link_changed)


## The hero just spoke in the world chat: the players hold their talk for HERO_QUIET s.
func _on_world_line(speaker: String, _text: String, _color: Color) -> void:
	if Game.has_profile and speaker == String(Game.profile.get("name", "")):
		_quiet_until = chat_clock() + HERO_QUIET


func _on_channel_line(channel: String, _speaker: String, _text: String, _color: Color) -> void:
	if channel == "party":
		_party_said_at = chat_clock()


func _process(delta: float) -> void:
	if zone == null or not zone.is_built:
		return
	_mode_in -= delta
	if _mode_in <= 0.0:
		update_mode()
	_timer -= delta
	if _timer <= 0.0:
		_timer = CHECK
		sync(false)
	if mode == HOST:
		_ev_tokens = minf(EVENT_BURST, _ev_tokens + EVENT_RATE * delta)
		_snap_in -= delta
		if _snap_in <= 0.0:
			_snap_in = WP_SNAP_EVERY
			send_snapshot()
	chat_tick(delta)


## The chat's clockwork, each frame: the lines of a conversation that are due, and the
## next turn of the world, guild and party chats when their timers run out.
func chat_tick(delta: float) -> void:
	_flush_queue()
	if not _busy("world") and not world_chat_relayed():
		_chat_in -= delta
		if _chat_in <= 0.0:
			_chat_in = CHAT_EVERY * randf_range(0.6, 1.4)
			chat_once()
	if not _busy("guild"):
		_guild_in -= delta
		if _guild_in <= 0.0:
			_guild_in = randf_range(GUILD_EVERY.x, GUILD_EVERY.y)
			guild_once()
	if not _busy("party"):
		_party_in -= delta
		if _party_in <= 0.0:
			_party_in = randf_range(PARTY_EVERY.x, PARTY_EVERY.y)
			party_once()
	flush_ai_chat()


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
		if mode == MIRROR:
			# The host's game places them; the puppets only pick up level, gear and doing.
			var puppet: Variant = shown.get(i)
			if puppet != null and is_instance_valid(puppet):
				(puppet as FieldPlayer).sync_progress(s)
			continue
		if bool(s.online) and StringName(s.place) == zone.zone_id and not Game.in_party(i):
			# The village is the stall keepers' and the errand runners' (the scheduled
			# players otherwise are out levelling).
			if zone.is_town and String(s.doing) not in ["stall", "errand"]:
				continue
			here.append(s)
	if mode == MIRROR:
		return
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
			_drop_shown(i)
	for k in _stalls.keys():
		if not shown.has(int(_stalls[k])):
			_stalls.erase(k)
	var arrivals: Array[int] = []
	for i in keep:
		var s: Dictionary = keep[i]
		if shown.has(i) and is_instance_valid(shown[i]):
			var p := shown[i] as FieldPlayer
			p.sync_progress(s)
			if p.doing == "stall" and not p.stall_at.is_finite() and not _give_stall(p):
				# Every market stall taken: a keeper never stands about anywhere else.
				_drop_shown(i)
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
		if zone == null or not is_instance_valid(zone) or not is_inside_tree() or mode == MIRROR:
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
	if (p as FieldPlayer).puppet:
		# Another game's picture of it: the party member is a body of this game's own.
		(p as FieldPlayer).queue_free()
		return null
	return p as FieldPlayer


## A member let go while still online goes back to hunting here (in a mirrored zone the
## host's game decides where it is: it goes, and shows up when the host lists it).
func release(p: FieldPlayer) -> void:
	if mode == MIRROR:
		p.leave()
		return
	p.leave_party()
	shown[p.world_index] = p


func _spawn(i: int, t: float, initial: bool, s: Dictionary = {}) -> void:
	var p := FieldPlayer.new()
	p.setup_world(i, WorldPlayers.member(i, t), zone.hero, zone)
	p.doing = String(s.get("doing", ""))
	zone.add_child(p)
	var at := zone.entrance()
	shown[i] = p
	if p.doing == "stall" and zone.is_town:
		if _give_stall(p):
			p.global_position = p.stall_at + Vector3(0, 0.3, 0)
		else:
			# Every market stall taken: a keeper is only ever shown at its stall.
			shown.erase(i)
			p.queue_free()
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


## Hands a stall keeper in the village a free stall on the market street (its own
## favourite first); false when every stall is taken (sync never shows more keepers than
## there are stalls, and a keeper without one is not shown).
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
	if int(now[0]) >= Game.MAX_LEVEL and int(was[1]) < JobData.GOD_STARS and int(now[1]) >= JobData.GOD_STARS:
		_server("%s เปลี่ยนอาชีพขั้นเทพเจ้า เป็น%sแล้ว!" % [tag, JobData.god_name(StringName(s["class"]))], &"quest", true)
	if not bool(was[2]) and bool(now[2]):
		_server("%s ได้ชุดเทพประจำอาชีพครบชุดแล้ว!" % tag, &"quest", true)
	if plus > int(was[3]) and plus >= 5:
		_server("%s ตีบวกชุดเทพ +%d สำเร็จ!" % [tag, plus], &"quest", plus >= 9)


func _server(text: String, kind: StringName, toast := false) -> void:
	Game.world_chat.emit("ประกาศ", text, Color("ffd24a"))
	if toast:
		Game.say("ประกาศ: " + text, kind)


## One turn of the world chat: a conversation among the online players (ChatThreads), a
## player looking to buy with the stalls answering (ChatTrade), a stall keeper's call, or
## one line that fits what a player is doing; a bubble over the speaker's head when it
## stands here. Nothing while a conversation is still going, the hero just spoke, or the
## chat is at its rate cap.
func chat_once() -> void:
	_flush_queue()
	if _online.is_empty() or _busy("world") or not _room() or world_chat_relayed():
		return
	if chat_clock() < _quiet_until:
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
	if _online.size() > 1 and randf() < THREAD_CHANCE:
		if String(s.get("doing", "")) != "stall" and randf() < TRADE_CHANCE and _start_trade(s):
			return
		if _start_thread("world", _people(s, _online)):
			return
	var text := fresh_line(s)
	if text == "":
		return
	_say("world", s, text)


## Now and then a conversation in the hero's guild chat among its online guild mates.
func guild_once() -> bool:
	var g := Game.guild() if Game.has_profile else 0
	if g == 0 or _busy("guild") or not _room():
		return false
	var mates := _online.filter(func(o): return int(o.get("guild", 0)) == g and not Game.in_party(int(o.index)))
	if mates.is_empty():
		return false
	return _start_thread("guild", _people(mates[randi() % mates.size()], mates))


## Now and then a word among the hero's party members (not right after PartyTalk spoke).
func party_once() -> bool:
	if not Game.has_profile or Game.world_party.is_empty() or _busy("party") or not _room():
		return false
	if chat_clock() - _party_said_at < PARTY_HUSH:
		return false
	var t := clock()
	var members: Array = []
	for i in Game.world_party:
		members.append(WorldPlayers.state(int(i), t))
	return _start_thread("party", _people(members[randi() % members.size()], members))


## `first` and up to three others of `pool` (those in the same place first): the people
## of a conversation, `first` opening it.
static func _people(first: Dictionary, pool: Array) -> Array:
	var others := pool.filter(func(o): return int(o.index) != int(first.index))
	others.shuffle()
	var place := String(first.get("place", ""))
	others.sort_custom(func(a, b): return (String(a.get("place", "")) == place) and String(b.get("place", "")) != place)
	return [first] + others.slice(0, 3)


## Starts a conversation on `channel` among `people` (people[0] opens): the first line
## now, the answers queued. False when nothing fresh was left to say.
func _start_thread(channel: String, people: Array) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = randi()
	var names: Array = []
	for o in _online:
		names.append(String(o.name))
	var ctx := {"online": _online.size(), "names": names}
	var opener: Dictionary = people[0]
	if String(opener.get("doing", "")) == "stall" and channel == "world" and rng.randf() < 0.6:
		# Its calls (lines naming what it really has), not the small talk anyone may say.
		var calls: Array = []
		for k in 4:
			var call := WorldChat.line_for(opener, randi())
			if not WorldChat.ANY.has(call) and not calls.has(call):
				calls.append(call)
		if not calls.is_empty():
			ctx["topic"] = "stall"
			ctx["open_lines"] = calls
	var lines := ChatThreads.make(channel, people, rng, ctx)
	if lines.is_empty():
		return false
	var first := _fresh_of(lines[0].options)
	if first == "":
		return false
	_say(channel, opener, first)
	var at := chat_clock()
	for k in range(1, lines.size()):
		at += float(lines[k].delay)
		var who: Dictionary = people[int(lines[k].who)]
		_queue.append({"at": at, "channel": channel, "state": who, "options": lines[k].options, "put_off": 0})
	_queue.sort_custom(func(a, b): return float(a.at) < float(b.at))
	return true


## A player (s) looking to buy something that fits its own level asks the world chat; the
## stalls that have it answer (ChatTrade.answers), or someone says nobody sells it now.
func _start_trade(s: Dictionary) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = randi()
	var wants := ["เพชรม่วง", "เพชรชมพู", "ยาเลือด", "ยามานา", "อัญมณี"]
	var level := int(s.get("level", 1))
	if level >= Game.MAX_LEVEL:
		wants.append_array(["เพชรชาออส", "ปีก", "ยาเลือดมหาเทพ", "ขนนก", "สว่านเจาะ"])
	if int(s.get("stars", 0)) >= DrownedAbyssData.ENTRY_STAR:
		wants.append("แก่นเทพหลอมเซต")
	if level >= 35:
		wants.append_array(["เขี้ยวหมาป่าสายฟ้า", "แหวน", "สร้อย"])
	var item: String = wants[rng.randi() % wants.size()]
	var asks := ["หาซื้อ%s ครับ" % item, "ใครขาย%s บ้าง" % item, "WTB %s ด่วน" % item, "มีใครขาย%sไหม" % item, "อยากได้%s ใครมีบ้าง" % item]
	var text := _fresh_of(asks)
	var req := ChatTrade.parse(text)
	if text == "" or req.is_empty():
		return false
	_say("world", s, text)
	var at := chat_clock()
	var t := clock()
	for a in ChatTrade.answers(req, t, rng.randi(), String(s.name), int(s.index)):
		var who := {"name": String(a.speaker), "index": int(a.index), "guild": 0, "trade": true}
		_queue.append({"at": at + float(a.delay), "channel": "world", "state": who, "options": [String(a.text)], "put_off": 0})
	_queue.sort_custom(func(a, b): return float(a.at) < float(b.at))
	return true


## Says the lines of the conversations that are due (one at a time, MIN_GAP apart; put
## off while the chat is at its rate cap, dropped after MAX_PUT_OFF tries).
func _flush_queue() -> void:
	var now := chat_clock()
	while not _queue.is_empty() and float(_queue[0].at) <= now:
		var e: Dictionary = _queue[0]
		if String(e.channel) == "world" and world_chat_relayed():
			# Another game makes the world chat now.
			_queue.pop_front()
			continue
		if not _room():
			e.put_off = int(e.put_off) + 1
			if int(e.put_off) > MAX_PUT_OFF:
				_queue.pop_front()
				continue
			var wait := MIN_GAP
			if not _posted.is_empty():
				wait = maxf(MIN_GAP, float(_posted[-1]) + MIN_GAP - now)
			e.at = now + wait
			_queue.sort_custom(func(a, b): return float(a.at) < float(b.at))
			return
		_queue.pop_front()
		var text := _fresh_of(e.options)
		if text != "":
			_say(String(e.channel), e.state, text)


## Whether a conversation on `channel` still has lines to come.
func _busy(channel: String) -> bool:
	return _queue.any(func(e): return String(e.channel) == channel)


## Whether one more line fits the rate cap now.
func _room() -> bool:
	var now := chat_clock()
	while not _posted.is_empty() and now - _posted[0] > RATE_WINDOW:
		_posted.pop_front()
	if _posted.size() >= RATE_CAP:
		return false
	return _posted.is_empty() or now - _posted[-1] >= MIN_GAP


## Lines said in the last RATE_WINDOW seconds (tests).
func recent_lines() -> int:
	_room()
	return _posted.size()


## Player s says `text` on `channel`: in the chat in its guild's colour (a keeper's answer
## in the stalls' colour), with a bubble when it stands here or walks with the hero.
func _say(channel: String, s: Dictionary, text: String) -> void:
	_posted.append(chat_clock())
	var name := String(s.get("name", ""))
	var color: Color = WorldPlayers.GUILD_COLORS.get(int(s.get("guild", 0)), Color("bfe8ff"))
	if bool(s.get("trade", false)):
		color = ChatTrade.SELLER_COLOR if int(s.get("index", -1)) >= 0 else AiChat.NOTE_COLOR
	if channel == "world":
		Game.world_chat.emit(name, text, color)
		_share_line(name, text, color, int(s.get("index", -1)))
	else:
		AiChat.hold = true
		Game.post_chat(channel, name, text, color)
		AiChat.hold = false
	var body := _body_of(int(s.get("index", -1)))
	if body != null:
		body.bubble(text, channel == "world")


## World player i's body in this zone (shown here or in the hero's party), or null.
func _body_of(i: int) -> FieldPlayer:
	if i < 0:
		return null
	var p: Variant = shown.get(i)
	if p != null and is_instance_valid(p):
		return p as FieldPlayer
	if not is_inside_tree():
		return null
	for node in get_tree().get_nodes_in_group("world_players"):
		var f := node as FieldPlayer
		if f != null and is_instance_valid(f) and f.world_index == i:
			return f
	return null


## The first of `options` nobody said in the last REPEAT_WINDOW seconds (kept as said
## now), "" when all were.
static func _fresh_of(options: Array) -> String:
	var now := chat_clock()
	for text in _said.keys():
		if now - float(_said[text]) > REPEAT_WINDOW:
			_said.erase(text)
	for text in options:
		var line := String(text)
		if line != "" and not _said.has(line):
			_said[line] = now
			return line
	return ""


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
	_posted.append(chat_clock())
	Game.world_chat.emit(String(WorldPlayers.entry(k).name), text, Color("8ff0ff"))
	_share_line(String(WorldPlayers.entry(k).name), text, Color("8ff0ff"), k)
	(shown[k] as FieldPlayer).bubble(text)
	return true


# --- Online: the shared world (docs/ONLINE_PROTOCOL.md "Shared world") ---------------------

## Whether another real player's game makes the AI world chat now (`whost`): this one
## then shows its `ai_chat` lines instead of making its own.
static func world_chat_relayed() -> bool:
	if not Online.is_online():
		return false
	var host := Online.world_host()
	return host != "" and host != Online.my_id()


## The world host's own world-chat line goes into this turn's `ai_chat`.
func _share_line(speaker: String, text: String, color: Color, index: int) -> void:
	if not Online.is_online() or not Online.is_world_host() or _ai_out.size() >= AI_CHAT_MAX:
		return
	var line := {"ch": "world", "speaker": speaker.left(24), "text": text.left(200), "color": color.to_html()}
	if index >= 0:
		line["index"] = index
	_ai_out.append(line)


## Sends the turn's world-chat lines as one `ai_chat` (the world host's game).
func flush_ai_chat() -> void:
	if _ai_out.is_empty():
		return
	if Online.is_online() and Online.is_world_host():
		Online.send("ai_chat", {"lines": _ai_out.duplicate()})
	_ai_out.clear()


## The world host's lines: in the world chat, with a bubble over the speaker standing
## here; kept as said (no repeat when this game makes the chat again).
func _on_ai_chat(msg: Dictionary) -> void:
	if not world_chat_relayed():
		return
	var from := Online.id_of(msg.get("from"))
	if from != "" and from != Online.world_host():
		return
	var lines: Variant = msg.get("lines")
	if not lines is Array:
		return
	var now := chat_clock()
	var n := 0
	for raw in lines:
		if n >= AI_CHAT_MAX:
			break
		if not raw is Dictionary or String(raw.get("ch", "world")) != "world":
			continue
		var speaker := str(raw.get("speaker", "")).strip_edges().left(24)
		var text := str(raw.get("text", "")).strip_edges().left(200)
		if speaker == "" or text == "" or not (raw.get("speaker") is String and raw.get("text") is String):
			continue
		n += 1
		var color := Color("bfe8ff")
		var c: Variant = raw.get("color")
		if c is String and Color.html_is_valid(c):
			color = Color.html(c)
		elif c is Array and (c as Array).size() >= 3:
			color = Color(Online.num_f(c[0], 0.75), Online.num_f(c[1], 0.9), Online.num_f(c[2], 1.0))
		_said[text] = now
		_posted.append(now)
		Game.world_chat.emit(speaker, text, color)
		var index := Online.num(raw.get("index", -1), -1)
		if index >= 0 and index < WorldPlayers.size():
			var body := _body_of(index)
			if body != null:
				body.bubble(text, false)


## The role this zone's world players have now (LOCAL, HOST or MIRROR).
func _wanted_mode() -> int:
	if zone == null or not Online.is_online():
		return LOCAL
	var z := zone.zone_id
	if Online.is_mirror_zone(z):
		return MIRROR
	if Online.is_zone_host(z) and not Online.players_in_zone(z).is_empty():
		return HOST
	return LOCAL


func _on_link_changed(_zone: Variant = null) -> void:
	if is_inside_tree() and zone != null and zone.is_built:
		update_mode()


## Looks at the link and the zone host again and switches at once: into MIRROR the own
## players go (the host's come as puppets); out of it the puppets carry on as ordinary
## world players where they stand.
func update_mode() -> void:
	_mode_in = MODE_CHECK
	var want := _wanted_mode()
	if want == mode:
		return
	var old := mode
	mode = want
	if mode == MIRROR:
		for i in shown.keys():
			var p: Variant = shown[i]
			if p != null and is_instance_valid(p):
				(p as Node).queue_free()
		shown.clear()
		_stalls.clear()
		_queue = _queue.filter(func(e): return String(e.channel) != "world" or not world_chat_relayed())
		return
	if old == MIRROR:
		for i in shown.keys():
			var p: Variant = shown[i]
			if p == null or not is_instance_valid(p) or (p as Node).is_queued_for_deletion():
				shown.erase(i)
				continue
			(p as FieldPlayer).end_puppet()
		# The schedule decides again who stays (the stalls and errands are handed out).
		sync(false)
		_timer = CHECK
	if mode == HOST:
		_snap_in = 0.0
		_wired.clear()


## Host: player i stops being shown here (with `wp_event leave` for the others).
func _drop_shown(i: int) -> void:
	var gone: Variant = shown.get(i)
	shown.erase(i)
	if gone != null and is_instance_valid(gone):
		(gone as FieldPlayer).leave()
	if mode == HOST and _wired.has(i):
		_wired.erase(i)
		_send_event(i, "leave", {}, true)


func _send_event(i: int, ev: String, data: Dictionary, must := false) -> void:
	if mode != HOST or not Online.is_online():
		return
	if _ev_tokens < 1.0 and not must:
		return
	_ev_tokens = maxf(0.0, _ev_tokens - 1.0)
	Online.send("wp_event", {"zone": String(zone.zone_id), "index": i, "ev": ev, "data": data})


## FieldPlayer.bubble: a bubble over a player the others see too.
func shared_bubble(i: int, text: String) -> void:
	if mode == HOST and _wired.has(i):
		_send_event(i, "bubble", {"text": text.left(200)})


## FieldPlayer._cast: the cast and its target monster's shared eid (0: none).
func shared_cast(i: int, skill_id: String, eid: int) -> void:
	if mode == HOST and _wired.has(i):
		_send_event(i, "skill", {"id": skill_id, "eid": eid})


## Host: the players near any other real player here, 4 times a second (rows reused).
func send_snapshot() -> void:
	if mode != HOST or zone == null:
		return
	_real_pos.clear()
	for p in Online.players_in_zone(zone.zone_id):
		var node := Online.remote_node(String(p.get("id", "")))
		if node != null:
			_real_pos.append(node.global_position)
		elif Online.valid_pos(p.get("pos")):
			_real_pos.append(Online.pos_of(p.pos))
	_cands.clear()
	for i in shown:
		var f: Variant = shown[i]
		if f == null or not is_instance_valid(f) or not (f as FieldPlayer).on_wire():
			continue
		var at: Vector3 = (f as FieldPlayer).global_position
		var best := INF
		for r in _real_pos:
			best = minf(best, Vector2(r.x - at.x, r.z - at.z).length())
		if best <= WP_NEAR:
			_cands.append([best, i])
	if _cands.size() > WP_CAP:
		_cands.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		_cands.resize(WP_CAP)
	while _row_pool.size() < _cands.size():
		_row_pool.append([0, 0.0, 0.0, 0.0, "idle", 0])
	_rows.resize(_cands.size())
	_wired.clear()
	for k in _cands.size():
		var i: int = _cands[k][1]
		var f := shown[i] as FieldPlayer
		var row: Array = _row_pool[k]
		row[0] = i
		row[1] = snappedf(f.global_position.x, 0.1)
		row[2] = snappedf(f.global_position.z, 0.1)
		row[3] = snappedf(wrapf(f._facing, -PI, PI), 0.01)
		row[4] = f.wire_anim()
		row[5] = f.wire_flags()
		_rows[k] = row
		_wired[i] = true
	Online.send("wp_snap", {"zone": String(zone.zone_id), "ps": _rows})


func _on_online_message(type: String, msg: Dictionary) -> void:
	match type:
		"wp_snap":
			_on_wp_snap(msg)
		"wp_event":
			_on_wp_event(msg)
		"ai_chat":
			_on_ai_chat(msg)
		"whost":
			if not world_chat_relayed():
				return
			# Another game makes the world chat now: our own conversations stop.
			_queue = _queue.filter(func(e): return String(e.channel) != "world")


## Whether a wp_ frame is for this zone, from its host.
func _from_host(msg: Dictionary) -> bool:
	if zone == null or not zone.is_built or str(msg.get("zone", "")) != String(zone.zone_id):
		return false
	var from := Online.id_of(msg.get("from"))
	return from == "" or from == Online.zone_host(zone.zone_id)


## Mirror: exactly the players of the host's snapshot, as puppets (a few new ones a
## snapshot), the others leave.
func _on_wp_snap(msg: Dictionary) -> void:
	if not _from_host(msg):
		return
	if mode != MIRROR:
		update_mode()
		if mode != MIRROR:
			return
	var ps: Variant = msg.get("ps")
	if not ps is Array:
		return
	var now := Time.get_ticks_msec() * 0.001
	var t := clock()
	var built := 0
	_snap_seen.clear()
	for row in ps:
		if _snap_seen.size() >= WP_CAP:
			break
		if not row is Array or (row as Array).size() < 6:
			continue
		var i := Online.num(row[0], -1)
		var x := Online.num_f(row[1], INF)
		var z := Online.num_f(row[2], INF)
		if i < 0 or i >= WorldPlayers.size() or absf(x) > Online.WORLD_LIMIT or absf(z) > Online.WORLD_LIMIT or Game.in_party(i):
			continue
		_snap_seen[i] = true
		var yaw := Online.num_f(row[3], 0.0)
		var anim := str(row[4]).left(48)
		var flags := Online.num(row[5], 0)
		var p: Variant = shown.get(i)
		if p == null or not is_instance_valid(p) or (p as Node).is_queued_for_deletion():
			if built >= PUPPETS_PER_SNAP:
				_snap_seen.erase(i)
				continue
			built += 1
			p = _spawn_puppet(i, t, Vector3(x, 0.0, z), yaw)
		var f := p as FieldPlayer
		f.puppet_push(Vector3(x, 0.0, z), yaw, now)
		f.puppet_state(anim, flags)
	for i in shown.keys():
		if not _snap_seen.has(i):
			var gone: Variant = shown[i]
			shown.erase(i)
			if gone != null and is_instance_valid(gone):
				(gone as FieldPlayer).leave()


func _spawn_puppet(i: int, t: float, at: Vector3, yaw: float) -> FieldPlayer:
	var p := FieldPlayer.new()
	p.puppet = true
	p.setup_world(i, WorldPlayers.member(i, t), zone.hero, zone)
	var s := WorldPlayers.state(i, t)
	p.doing = String(s.get("doing", ""))
	p.errand = String(s.get("errand", ""))
	p.position = at + Vector3(0, 0.3, 0)
	p.puppet_push(at, yaw, Time.get_ticks_msec() * 0.001)
	zone.add_child(p)
	shown[i] = p
	return p


## Mirror: the host's cast (at the mirrored monster), a bubble, a player leaving.
func _on_wp_event(msg: Dictionary) -> void:
	if mode != MIRROR or not _from_host(msg):
		return
	var i := Online.num(msg.get("index", -1), -1)
	var p: Variant = shown.get(i)
	if p == null or not is_instance_valid(p):
		return
	var f := p as FieldPlayer
	var data: Variant = msg.get("data", {})
	if not data is Dictionary:
		data = {}
	match str(msg.get("ev", "")):
		"skill":
			var skill := f.find_skill(str(data.get("id", "")).left(64))
			if not skill.is_empty():
				f.puppet_cast(skill, mob_by_eid(Online.num(data.get("eid", 0), 0)))
		"bubble":
			if data.get("text") is String and String(data.text).strip_edges() != "":
				f.bubble(String(data.text).left(200), false)
		"leave":
			shown.erase(i)
			f.leave()


## The monster with shared id `eid` here (the shared combat's mirror, or any monster
## carrying that eid), or null.
func mob_by_eid(eid: int) -> Node3D:
	if eid <= 0 or not is_inside_tree():
		return null
	var sync: Variant = EntitySync.current
	if sync != null and is_instance_valid(sync):
		for key in ["mirrors", "ents"]:
			var table: Variant = (sync as Object).get(key)
			if table is Dictionary:
				var node: Variant = (table as Dictionary).get(eid)
				if node != null and is_instance_valid(node) and node is Node3D:
					return node as Node3D
	for node in get_tree().get_nodes_in_group("mobs"):
		if int(node.get_meta("eid", node.get_meta("mirror_eid", 0))) == eid and node is Node3D:
			return node as Node3D
	return null
