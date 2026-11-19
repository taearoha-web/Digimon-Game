class_name MazeMatch
extends Node
## The live free-for-all in เขาวงกตหนึ่งในใต้หล้า while the hero is inside (Zone builds it
## for the maze, MazeWar the rules):
## - the world players in the maze now (MazeWar.inside_at: interested, online, in a block of
##   their session they give to the maze; the hero's own party left out) fight here for
##   real as MazeFighters with their real gear, level, stars and skills
##   (WorldPlayers.fighter), at most MazeWar.MAX_LIVE at a time; who comes and goes follows
##   the clock (every ROSTER_EVERY seconds). Each one fighting here holds its slots
##   (MazeWar.hold): its simulated fights of those slots are dropped and its live kills
##   count instead;
## - every kill between players is counted (MazeWar.record_kill), the same killer at most
##   once in REKILL_GAP on the same victim; the kill feed goes to the war chat;
## - the hero: the shrines (protected for SAFE_MAX a visit, then that shrine's blessing is
##   spent for SAFE_COOLDOWN; leaving one, SAFE_LEAVE more seconds untouchable and unable
##   to strike), a fall brings it back after RESPAWN seconds at a random spot
##   (MazeLayout.spawn_point, away from everyone, never in a shrine), untouchable for
##   SPAWN_GUARD seconds;
## - online: a real player in the maze is a foe too (MazeProxy: the hero's hits go out as
##   `maze_hit`, the server relays them only between two players in the maze; the victim's
##   own game applies its defence and decides its fall, `maze_down` names who took it). The
##   zone's host runs the world players for everyone (EntitySync mirrors them); a mirror
##   runs none of its own. The hero's kills of world players go to the server as
##   `maze_kill` (it keeps the week's board of real players: MazeWar.receive).

signal feed(text: String)
signal hero_down(seconds: float)
signal hero_back()

const ROSTER_EVERY := 6.0
## The war chat channel the kill feed goes to (WorldChat tags it).
const CHAT_CHANNEL := "war"
const FEED_COLOR := Color("ffd27a")
## Fighters farther than this from the camera are hidden (their brains still run).
const DRAW_RADIUS := [50.0, 62.0, 80.0]
## Damage a real player's hit may carry (of the hero's max HP), as a duel's.
const MAX_HIT_FACTOR := 0.6

var zone: Node3D
var hero: Hero
var fighters: Array[MazeFighter] = []
## world index -> its fighter (the live ones).
var live := {}
var hero_respawn_left := 0.0
## The hero's shrine state (as MazeFighter's).
var shrine := -1
var shrine_time := 0.0
var _shrine_cool := {}
var _leave_until := 0
var _guard_until := 0
## The real players in the maze: id -> MazeProxy.
var proxies := {}
## Kills counted lately: "killer|victim" -> msec (REKILL_GAP).
var _recent := {}
var _next_team := 1
var _roster_timer := 0.0
var _cull_timer := 0.0
var _proxy_timer := 0.0
var _slot := -1
var _week := -1
var rng := RandomNumberGenerator.new()
## The real player whose hit landed on the hero last, and when (msec).
var _real_hitter := ""
var _real_hit_at := 0
var hero_kills := 0
var hero_deaths := 0


func setup(p_zone: Node3D, p_hero: Hero) -> void:
	zone = p_zone
	hero = p_hero
	rng.randomize()
	name = "MazeMatch"


func _ready() -> void:
	hero.died.connect(_on_hero_died)
	# The walls are low: the camera looks over them (its spring arm would pull in at
	# every corridor wall).
	var rig: Variant = zone.get("camera_rig")
	if rig != null and is_instance_valid(rig) and rig.get("_arm") != null:
		(rig._arm as SpringArm3D).collision_mask = 0
	if not Online.message.is_connected(_on_message):
		Online.message.connect(_on_message)
	_week = MazeWar.week_of(MazeWar.now())
	MazeCrown.settle(MazeWar.now())
	_guard_until = Time.get_ticks_msec() + int(MazeWar.SPAWN_GUARD * 1000.0)


func _exit_tree() -> void:
	if Online.message.is_connected(_on_message):
		Online.message.disconnect(_on_message)
	for id in proxies.keys():
		_drop_proxy(String(id))


## Spawns the world players in the maze now (none while another real player's game runs
## them: EntitySync mirrors those).
func build(tree: SceneTree = null) -> void:
	_slot = MazeWar.slot_of(MazeWar.now())
	if EntitySync.mirror_zone(MazeWar.ID):
		return
	await refresh_roster(tree)


## Who is in the maze now: the ones gone leave, the ones come in arrive (MAX_LIVE).
func refresh_roster(tree: SceneTree = null) -> void:
	if not MazeWar.ai_on():
		return
	var t := MazeWar.now()
	var want := MazeWar.inside_at(t).filter(func(i): return not Game.in_party(int(i)))
	# The cap: a fair turn of the ones in (by the slot, so it changes now and then).
	if want.size() > MazeWar.MAX_LIVE:
		var turn := posmod(MazeWar.slot_of(t), want.size())
		want = (want.slice(turn) + want.slice(0, turn)).slice(0, MazeWar.MAX_LIVE)
	for i in live.keys():
		if not want.has(int(i)):
			_leave(live[i])
	for i in want:
		if live.has(int(i)):
			MazeWar.hold(int(i), t)
			continue
		spawn_world_player(int(i), t)
		if tree != null:
			await FrameSlicer.pace(tree)


## World player i arrives at a random spot, as it really is at t.
func spawn_world_player(i: int, t: float) -> MazeFighter:
	var info := WorldPlayers.fighter(i, t)
	var f := MazeFighter.new()
	var at := spawn_point()
	f.setup_maze(info, _next_team, hero, at, self)
	_next_team += 1
	f.position = at + Vector3(0, 0.3, 0)
	zone.add_child(f)
	f.fell.connect(_on_fell)
	fighters.append(f)
	live[i] = f
	MazeWar.hold(i, t)
	return f


func _leave(f: MazeFighter) -> void:
	if not is_instance_valid(f):
		return
	live.erase(f.world_index)
	fighters.erase(f)
	if f.visual.visible:
		VfxKit.flash(zone, f.global_position + Vector3(0, 1.0, 0), Color("bfe8ff"), 1.6)
	if is_instance_valid(hero) and hero.target == f:
		hero.set_target(null)
	f.remove_from_group("mobs")
	f.queue_free()


func _free_all() -> void:
	for f in fighters.duplicate():
		_leave(f)


# --- Where one comes back ------------------------------------------------------------

## Everyone standing now (positions), for a spawn spot away from them.
func standing() -> Array:
	var out: Array = []
	if is_instance_valid(hero) and not hero.is_dead():
		out.append(hero.global_position)
	for f in fighters:
		if is_instance_valid(f) and not f.is_dead():
			out.append(f.global_position)
	for node in get_tree().get_nodes_in_group("gw_fighters"):
		if node is MirrorFighter and not (node as MirrorFighter).is_dead():
			out.append((node as Node3D).global_position)
	for id in proxies:
		var p: MazeProxy = proxies[id]
		if is_instance_valid(p):
			out.append(p.global_position)
	return out


func spawn_point() -> Vector3:
	return MazeLayout.spawn_point(rng, standing())


func spawn_for(f: MazeFighter) -> Vector3:
	var others := standing()
	others.erase(f.global_position)
	return MazeLayout.spawn_point(rng, others)


# --- Who may be struck -----------------------------------------------------------------

## Whether `who` is out of reach now: in a shrine with its blessing, just out of one or
## just back from a fall.
func shields(who: Variant) -> bool:
	if who == null or not is_instance_valid(who):
		return false
	if who is MazeFighter:
		return (who as MazeFighter).protected()
	if who == hero:
		return hero_protected()
	if who is MazeProxy or who is MirrorFighter or (who is Node and (who as Node).is_in_group("remote_players")):
		# Another game's player: protected in a shrine's circle (its own game guards the rest).
		return MazeLayout.safe_at((who as Node3D).global_position) >= 0
	return false


func hero_protected() -> bool:
	return hero_sheltered() or Time.get_ticks_msec() < _leave_until or Time.get_ticks_msec() < _guard_until


func hero_sheltered() -> bool:
	return shrine >= 0 and shrine_time < MazeWar.SAFE_MAX


## Seconds of shelter left for the hero in its shrine (0 when in none).
func shelter_left() -> float:
	return maxf(0.0, MazeWar.SAFE_MAX - shrine_time) if shrine >= 0 else 0.0


## The fight power of anyone here (a fighter's own, the hero's, a real player's by level).
func power_of(who: Variant) -> float:
	if who is MazeFighter:
		return (who as MazeFighter).power
	if who == hero:
		return GuildWarData.hero_power()
	if who is GuildFighter:
		return GuildWarData.power_of((who as GuildFighter).rstats)
	return GuildWarData.hero_power()


# --- The clock ----------------------------------------------------------------------

func _process(delta: float) -> void:
	if not is_instance_valid(hero):
		return
	_update_hero_shrine(delta)
	var t := MazeWar.now()
	var mirror := EntitySync.mirroring()
	if mirror and not fighters.is_empty():
		_free_all()
	_roster_timer -= delta
	var slot := MazeWar.slot_of(t)
	if _roster_timer <= 0.0 or slot != _slot:
		_roster_timer = ROSTER_EVERY
		_slot = slot
		if not mirror:
			refresh_roster()
	var week := MazeWar.week_of(t)
	if week != _week:
		_week = week
		MazeCrown.settle(t)
		zone.emit_signal("banner_requested", "ตัดรอบสัปดาห์ %s แล้ว! เริ่มนับใหม่" % MazeWar.TITLE)
	for f in fighters:
		if is_instance_valid(f) and f.is_dead() and f.respawn_left <= 0.0:
			f.respawn()
	if hero_respawn_left > 0.0:
		hero_respawn_left -= delta
		if hero_respawn_left <= 0.0:
			_respawn_hero()
	_cull_timer -= delta
	if _cull_timer <= 0.0:
		_cull_timer = 0.25
		_cull_far()
	_proxy_timer -= delta
	if _proxy_timer <= 0.0:
		_proxy_timer = 0.5
		_sync_proxies()


func _update_hero_shrine(delta: float) -> void:
	if hero.is_dead():
		hero.safe_zone = false
		return
	var now := Time.get_ticks_msec()
	var k := MazeLayout.safe_at(hero.global_position)
	if k >= 0 and int(_shrine_cool.get(k, 0)) > now:
		k = -1
	if k != shrine:
		if shrine >= 0 and k < 0:
			_leave_until = now + int(MazeWar.SAFE_LEAVE * 1000.0)
			if shrine_time >= MazeWar.SAFE_MAX:
				_shrine_cool[shrine] = now + int(MazeWar.SAFE_COOLDOWN * 1000.0)
		elif k >= 0:
			Game.say("เข้าที่หลบภัย: ไม่มีใครทำร้ายคุณได้ %d วินาที (และคุณก็โจมตีใครไม่ได้)" % int(MazeWar.SAFE_MAX), &"info")
		shrine = k
		shrine_time = 0.0
	if shrine >= 0:
		shrine_time += delta
		if shrine_time >= MazeWar.SAFE_MAX:
			_shrine_cool[shrine] = now + int(MazeWar.SAFE_COOLDOWN * 1000.0)
			shrine = -1
			_leave_until = 0
			Game.say("พรของที่หลบภัยจางหายแล้ว — ที่นี่จะคุ้มครองคุณอีกครั้งใน %d วินาที" % int(MazeWar.SAFE_COOLDOWN), &"warning")
		else:
			var stats := hero.stats
			if not stats.is_empty():
				Game.profile.hp = mini(int(stats.max_hp), int(Game.profile.hp) + int(ceil(float(stats.max_hp) * MazeWar.SAFE_REGEN * delta)))
				Game.profile.mp = minf(float(stats.max_mp), float(Game.profile.mp) + float(stats.max_mp) * MazeWar.SAFE_REGEN * delta)
	# Hero.safe_zone: no harm, no strikes (the village's rule), while sheltered or leaving.
	hero.safe_zone = hero_sheltered() or now < _leave_until
	hero._invulnerable_until = maxi(hero._invulnerable_until, _guard_until)


func _cull_far() -> void:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null:
		return
	var limit: float = DRAW_RADIUS[clampi(GameSettings.quality, 0, 2)]
	for f in fighters:
		if is_instance_valid(f):
			f.visual.visible = f.global_position.distance_squared_to(camera.global_position) < limit * limit


# --- Kills ------------------------------------------------------------------------------

## Who struck the last blow, as MazeWar counts it: {kind, name, index, id} ({} nobody).
func who_is(node: Variant) -> Dictionary:
	if node == null or not is_instance_valid(node):
		return {}
	if node is Summon and is_instance_valid((node as Summon).summoner):
		node = (node as Summon).summoner
	if node is SummonMob and is_instance_valid((node as SummonMob).caster):
		node = (node as SummonMob).caster
	if node == hero:
		return {"kind": "hero", "name": MazeWar.hero_name(), "index": -1}
	if node is MazeFighter:
		return {"kind": "ai", "name": (node as MazeFighter).rival_name, "index": (node as MazeFighter).world_index}
	if node is MazeProxy:
		return {"kind": "real", "name": OnlineTrade.player_name((node as MazeProxy).player_id), "index": -1, "id": (node as MazeProxy).player_id}
	if node is MirrorFighter:
		return {"kind": "ai", "name": String((node as MirrorFighter).member.get("name", "")), "index": WorldPlayers.index_of(String((node as MirrorFighter).member.get("name", ""))), "mirror": true}
	var real := EntitySync.name_of(node)
	if real != "":
		return {"kind": "real", "name": real, "index": -1, "id": EntitySync.current.id_of(node) if EntitySync.current != null else ""}
	return {}


## Counts a kill once (the same killer on the same victim at most once in REKILL_GAP);
## [param report]: tell the server (not for a kill the server itself just told us of).
func count_kill(killer: Dictionary, victim: Dictionary, report := true) -> bool:
	if killer.is_empty() or victim.is_empty():
		return false
	var key := "%s|%s" % [killer.name, victim.name]
	var now := Time.get_ticks_msec()
	if int(_recent.get(key, -100000000)) + int(MazeWar.REKILL_GAP * 1000.0) > now:
		return false
	_recent[key] = now
	if _recent.size() > 256:
		_recent.clear()
	var counted := MazeWar.record_kill(killer, victim)
	if String(killer.kind) == "hero":
		hero_kills += 1
		if report and Online.is_online():
			Online.send("maze_kill", {"victim": String(victim.name).left(MazeWar.NAME_MAX), "ai": String(victim.kind) == "ai"})
	elif report and String(killer.kind) == "real" and String(killer.get("id", "")) != "" and String(victim.kind) == "ai" and Online.is_online():
		# A real player of this zone took a world player of this game (the host's): the
		# server credits them.
		Online.send("maze_kill", {"victim": String(victim.name).left(MazeWar.NAME_MAX), "ai": true, "by": String(killer.id)})
	return counted


func _on_fell(fighter: GuildFighter, killer: Node) -> void:
	var victim := who_is(fighter)
	var by := who_is(killer)
	if by.is_empty():
		_say("%s ล้มลง" % fighter.rival_name)
		return
	count_kill(by, victim)
	_say("%s ล้ม %s" % [by.name if String(by.kind) != "hero" else "คุณ", fighter.rival_name])


func _on_hero_died() -> void:
	hero_deaths += 1
	var by := {}
	var attacker: Variant = hero.get("last_hit_by")
	by = who_is(attacker)
	if by.is_empty() and _real_hitter != "" and Time.get_ticks_msec() - _real_hit_at < 5000:
		by = {"kind": "real", "name": OnlineTrade.player_name(_real_hitter), "index": -1, "id": _real_hitter}
	var me := {"kind": "hero", "name": MazeWar.hero_name(), "index": -1}
	if not by.is_empty():
		if String(by.kind) == "ai" and not bool(by.get("mirror", false)):
			count_kill(by, me)
		else:
			MazeWar.record_death()
		if String(by.kind) == "real" and Online.is_online():
			Online.send("maze_down", {"by": String(by.get("id", ""))})
		_say("%s ล้มคุณ" % by.name)
	else:
		MazeWar.record_death()
		_say("คุณล้มลง")
	hero_respawn_left = MazeWar.RESPAWN
	hero_down.emit(hero_respawn_left)


func _respawn_hero() -> void:
	var stats := Game.stats_now()
	Game.profile.hp = stats.max_hp
	Game.profile.mp = stats.max_mp
	hero.revive()
	hero.global_position = spawn_point() + Vector3(0, 0.3, 0)
	_guard_until = Time.get_ticks_msec() + int(MazeWar.SPAWN_GUARD * 1000.0)
	hero._invulnerable_until = _guard_until
	shrine = -1
	shrine_time = 0.0
	BurstGuard.forget(hero.get_instance_id())
	VfxKit.flash(zone, hero.global_position + Vector3(0, 1.0, 0), Color("bfe8ff"), 1.8)
	if hero.camera_rig != null:
		hero.camera_rig.snap_to_target()
	hero_back.emit()


func _say(text: String) -> void:
	feed.emit(text)
	Game.channel_chat.emit(CHAT_CHANNEL, "", text, FEED_COLOR)


# --- Real players (online) ----------------------------------------------------------

## A MazeProxy rides on every real player in the maze, so the hero can strike them.
func _sync_proxies() -> void:
	var here := {}
	if Online.is_online():
		for p in Online.players_in_zone(MazeWar.ID):
			var id := String(p.get("id", ""))
			if id == "" or id == Online.my_id():
				continue
			here[id] = true
			if not proxies.has(id) or not is_instance_valid(proxies[id]):
				var node := Online.remote_node(id)
				if node == null:
					continue
				var proxy := MazeProxy.new()
				proxy.setup_maze(self, id, node, hero, p)
				zone.add_child(proxy)
				proxies[id] = proxy
	for id in proxies.keys():
		if not here.has(id):
			_drop_proxy(String(id))


func _drop_proxy(id: String) -> void:
	var proxy: Variant = proxies.get(id)
	proxies.erase(id)
	if proxy != null and is_instance_valid(proxy):
		if is_instance_valid(hero) and hero.target == proxy:
			hero.set_target(null)
		(proxy as Node).remove_from_group("mobs")
		(proxy as Node).queue_free()


## The hero's hit on a real player goes out (the server relays it within the maze).
func send_hit(id: String, amount: int, crit: bool) -> int:
	if amount <= 0 or not Online.is_online() or hero.safe_zone:
		return 0
	var scaled := int(ceil(float(amount) * GuildWarData.damage_scale))
	Online.send("maze_hit", {"to": id, "dmg": scaled, "crit": crit})
	return scaled


func _on_message(type: String, data: Dictionary) -> void:
	match type:
		"maze_hit":
			_take_real_hit(String(data.get("from", "")), data.get("dmg"))
		"maze_kill":
			# The server's board moved. A kill it credits to the hero that another game saw
			# (the victim's own, or the host's world player) is counted here too.
			var by := String(data.get("by", ""))
			if by != "" and by == Online.my_id() and String(data.get("victim", "")) != "":
				var kind := "ai" if bool(data.get("ai", false)) else "real"
				count_kill({"kind": "hero", "name": MazeWar.hero_name(), "index": -1}, {"kind": kind, "name": String(data.victim), "index": -1}, false)


## A real player's hit on the hero: its defence and dodge, as a duel's (Hero.take_damage).
func _take_real_hit(from: String, dmg: Variant) -> void:
	if not (dmg is int or dmg is float) or hero.is_dead() or hero_protected():
		return
	var max_hp := maxi(1, int(hero.stats.get("max_hp", 1)))
	var raw := clampf(float(dmg), 0.0, float(max_hp) * MAX_HIT_FACTOR)
	if raw <= 0.0:
		return
	var amount := maxi(1, int(round(HeroStats.mitigate(raw, hero.effective_def()))))
	var allowed := BurstGuard.take(hero.get_instance_id(), amount, max_hp)
	if allowed < amount:
		raw *= float(allowed) / float(amount)
	_real_hitter = from
	_real_hit_at = Time.get_ticks_msec()
	var proxy: Variant = proxies.get(from)
	hero.take_damage(raw, proxy if proxy != null and is_instance_valid(proxy) else null)
