class_name WorldPresence
extends Node
## Shows the world players (WorldPlayers) who are online in this zone right now: they walk
## in, hunt the field's monsters, level up as their schedule says and log off when their
## session ends. Checked every few seconds; a phone shows fewer at once (quality). Also
## announces milestones (job advancement levels, Lv.100, star tiers, the divine set) of any
## world player, wherever it is, like a server message.

const CHECK := 12.0
const LIMITS := [2, 3, 4]
const ANNOUNCE_LEVELS := [10, 20, 40, 60, 80, 100]
const ANNOUNCE_STARS := [50, 100, 150, 200]

## Seconds added to the clock (tests move time forward). TOON_WORLD_DAYS=x starts the
## clock x days after the world opened (for screenshots and soak runs).
static var clock_offset := _days_offset()
## Off in headless runs so every other test meets the same field whatever the time of day;
## tests of the world players switch it on (so does TOON_WORLD_PLAYERS=1).
static var enabled := DisplayServer.get_name() != "headless" or OS.get_environment("TOON_WORLD_PLAYERS") == "1"
## Last progress seen per world player, kept across zones so a milestone is told once.
static var _seen := {}

var zone: Zone
var shown := {}
var _timer := 0.0


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
	for i in WorldPlayers.size():
		var s := WorldPlayers.state(i, t)
		_announce(s)
		if bool(s.online) and StringName(s.place) == zone.zone_id and not Game.in_party(i):
			here.append(s)
	# Those already shown stay first, then the roster order turned by the hour so the
	# same few are not always the ones picked.
	var turn := int(t / 3600.0) % WorldPlayers.size()
	here.sort_custom(func(a, b):
		var sa := 0 if shown.has(int(a.index)) else 1
		var sb := 0 if shown.has(int(b.index)) else 1
		if sa != sb:
			return sa < sb
		return (int(a.index) - turn + 40) % WorldPlayers.size() < (int(b.index) - turn + 40) % WorldPlayers.size())
	var limit: int = maxi(1, int(LIMITS[clampi(GameSettings.quality, 0, 2)]) - Game.party().size())
	var keep := {}
	for k in mini(limit, here.size()):
		keep[int(here[k].index)] = here[k]
	for i in shown.keys():
		if not keep.has(i):
			var gone: FieldPlayer = shown[i]
			if is_instance_valid(gone):
				gone.leave()
			shown.erase(i)
	for i in keep:
		var s: Dictionary = keep[i]
		if shown.has(i) and is_instance_valid(shown[i]):
			(shown[i] as FieldPlayer).sync_progress(s)
			continue
		_spawn(i, t, initial)


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


func _spawn(i: int, t: float, initial: bool) -> void:
	var p := FieldPlayer.new()
	p.setup_world(i, WorldPlayers.member(i, t), zone.hero, zone)
	zone.add_child(p)
	var at := zone.entrance()
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


## A server message when someone reaches a milestone (only for progress seen happening).
func _announce(s: Dictionary) -> void:
	var i := int(s.index)
	var now := [int(s.level), int(s.stars), bool(s.divine)]
	if not _seen.has(i):
		_seen[i] = now
		return
	var was: Array = _seen[i]
	_seen[i] = now
	var tag := "[%s] %s" % [WorldPlayers.guild_name(int(s.guild)), s.name]
	for lv in ANNOUNCE_LEVELS:
		if int(was[0]) < lv and int(now[0]) >= lv:
			Game.say("ประกาศ: %s ถึงเลเวล %d แล้ว!" % [tag, lv], &"info")
	for st in ANNOUNCE_STARS:
		if int(was[1]) < st and int(now[1]) >= st:
			Game.say("ประกาศ: %s ถึง %d ดาวแล้ว!" % [tag, st], &"quest")
	if not bool(was[2]) and bool(now[2]):
		Game.say("ประกาศ: %s ได้ชุดเทพประจำอาชีพครบชุดแล้ว!" % tag, &"quest")
