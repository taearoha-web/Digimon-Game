extends Node
## What the worst scenes cost a phone, through the real game (Main, the HUD, the zone):
##   village   the village on its busiest day, world players with their pets, the hero's
##             god-form pet beside it
##   field     the busiest hunting field: monsters, world players hunting with their pets,
##             a party of two, the hero casting its skills
##   raid      the party raid's boss floor (the party of three fighting the boss)
##   guildwar  a guild war 8v8 fight (no pets there)
##   spam      the field again with the hero casting its god skill and its ultimates back
##             to back (cooldowns reset)
## For each it prints one line: frame time (median / mean / p95 of the whole frame; headless
## that is the CPU work alone, the engine's idle sleep is turned off), draw calls, primitives and objects drawn (median / max),
## node and object counts, video / texture / buffer memory, particle emitters and
## particles alive, pets out and VfxBudget's counters. Frame times on a shared machine
## are noisy: compare the draw calls, primitives and node counts between runs.
##   xvfb-run godot --rendering-driver opengl3 --resolution 1266x585 --path . res://tests/tools/phone_perf_probe.tscn -- SCENE [QUALITY] [FRAMES] [CLASS] [smooth] [pressure=N]
##   godot --headless --path . res://tests/tools/phone_perf_probe.tscn -- SCENE [QUALITY] [FRAMES]
## QUALITY 0-2 (default 1, the phone default), "smooth" = high quality "ลื่น" (the phone
## mode), "pressure=N" pins MemoryGuard at level N, "nopets" leaves the other players'
## pets out, "bare" the world players. CLASS defaults to mage (its ultimates).

## The shortest measured stretch (seconds).
const MIN_SECONDS := 12
var main: Node
var frame_us: PackedInt32Array = []
var draws: PackedInt32Array = []
var prims: PackedInt32Array = []
var objs: PackedInt32Array = []
var _last := 0
var _recording := false
var _caster: Hero = null
var _cast_skills: Array = []
var _cast_every := 1.0
var _cast_timer := 0.0
var _cast_i := 0


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var scene := args[0] if args.size() > 0 else "village"
	var quality := int(args[1]) if args.size() > 1 else 1
	var frames := int(args[2]) if args.size() > 2 else 600
	var cls := StringName(args[3]) if args.size() > 3 and args[3] != "-" else &"mage"
	# Headless, the engine sleeps this long every frame (nothing to draw): measure the work.
	OS.low_processor_usage_mode_sleep_usec = 0
	GameSettings.load_settings()
	GameSettings.quality = quality
	GameSettings.high_smooth = "smooth" in args
	GameSettings.combat_hitstop = false
	GameSettings.show_world_players = not "bare" in args
	PetCrowd.enabled = not "nopets" in args
	MemoryGuard.phone_override = 1
	# A desktop's memory is not a phone's: the pressure level is pinned (0 unless asked).
	var pressure := 0
	for a in args:
		if String(a).begins_with("pressure="):
			pressure = int(String(a).substr(9))
	MemoryGuard.force(pressure, get_tree())
	WorldPresence.enabled = true
	WorldPlayers.persist = false
	var days := {"village": 20.7, "field": 10.3, "spam": 10.3}.get(scene, 3.4) as float
	WorldPresence.clock_offset = float(WorldPlayers.START_UNIX) + days * 86400.0 - WorldPlayers.now()
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _wait(0.5)
	Game.new_profile(cls, "Perf")
	Game.profile["level"] = 100
	Game.profile["adv"] = 4
	Game.paragon().level = 300
	Game.profile["paragon"]["alloc"] = Game.party_star_alloc(300)
	Game.profile.flags[Tutorial.FLAG] = Tutorial.DONE
	Game.choose_pet("fire")
	var gear_rng := RandomNumberGenerator.new()
	gear_rng.seed = 11
	for slot in ItemData.SLOTS:
		Game.profile.equip[slot] = StarProgression.item(cls, 300, slot, gear_rng)
	Game.profile.equip["wings"] = StarWingData.item(String(cls), gear_rng)
	for s in ClassData.pool(cls):
		Game.profile.skills[String(s.id)] = 5
	Game.profile.hp = Game.stats_now().max_hp
	main.title_screen.queue_free()
	main.title_screen = null
	main.hud.visible = true
	Game.playing = true
	GameSettings.apply_live(get_tree())
	match scene:
		"village":
			await main.go(&"town", true)
			await _wait(4.0)
			_among_players(main.zone)
		"field", "spam":
			Game.party_invite(WorldPlayers.first_of(&"priest"), true)
			Game.party_invite(WorldPlayers.first_of(&"defender"), true)
			await main.go(_busiest_field(), true)
			await _wait(4.0)
			_among_players(main.zone)
			_spawn_pack(main.zone, 10)
			_start_casting(main.zone.hero, cls, scene == "spam")
		"raid":
			Game.party_invite(WorldPlayers.first_of(&"defender"), true)
			Game.party_invite(WorldPlayers.first_of(&"priest"), true)
			RaidData.enter()
			await main.go(RaidData.ID, false, true)
			await _wait(2.0)
			await _to_boss(main.zone)
			_start_casting(main.zone.hero, cls, false)
		"guildwar":
			await main.go(&"guildwar", false, true)
			await _wait(7.0)
			_start_casting(main.zone.hero, cls, false)
	var hero: Hero = main.zone.hero
	hero._invulnerable_until = Time.get_ticks_msec() + 3600000
	await _wait(3.0)
	# Shader compiles and first casts are not what is measured: settle first.
	await _measure(scene, quality, frames)
	get_tree().quit()


func _busiest_field() -> StringName:
	var places := {}
	for i in WorldPlayers.size():
		var s := WorldPlayers.state(i, WorldPresence.clock())
		if bool(s.online) and String(s.place) != "town" and String(s.place) != "":
			places[String(s.place)] = int(places.get(String(s.place), 0)) + 1
	var field := &"meadow"
	var most := 0
	for p in places:
		if int(places[p]) > most:
			most = int(places[p])
			field = StringName(p)
	return field


## The hero (and its camera) in the middle of the world players here.
func _among_players(zone: Zone) -> void:
	var bots := get_tree().get_nodes_in_group("world_players")
	if bots.is_empty():
		return
	var best: Node3D = null
	var best_n := -1
	for b in bots:
		var n := 0
		for o in bots:
			if (o as Node3D).global_position.distance_to((b as Node3D).global_position) < 14.0:
				n += 1
		if n > best_n:
			best_n = n
			best = b
	zone.hero.global_position = best.global_position + Vector3(0, 0.2, 5.0)
	zone.camera_rig.snap_to_target()


## A pack of the zone's monsters around the hero, so its casts have something to hit.
func _spawn_pack(zone: Zone, n: int) -> void:
	var mobs := get_tree().get_nodes_in_group("mobs")
	if mobs.is_empty():
		return
	var at := zone.hero.global_position
	var k := 0
	for m in mobs:
		if k >= n:
			break
		var mob := m as Node3D
		if mob == null:
			continue
		mob.global_position = at + Vector3(cos(k * 0.7) * (3.0 + k * 0.3), 0.2, sin(k * 0.7) * (3.0 + k * 0.3))
		if "max_hp" in mob:
			mob.max_hp = 1000000000
			mob.hp = 1000000000
		k += 1


## Through the raid's floors to its boss (the floors' monsters fall at once).
func _to_boss(zone: Zone) -> void:
	var run: RaidRun = zone.raid_run
	if run == null:
		return
	for i in 3:
		var guard := 0
		while run.state != "fight" and guard < 600:
			await get_tree().process_frame
			guard += 1
		if run.boss != null:
			break
		for m in run.mobs.duplicate():
			if is_instance_valid(m) and not m.is_dead():
				m.take_hit(m.hp + 1, false, Color.WHITE, zone.hero)
		await _wait(0.5)
		if run.state == "rest":
			run.step(RaidRun.REST + 0.1)
	if run.boss:
		run.boss.max_hp = 1000000000
		run.boss.hp = 1000000000
		zone.hero.global_position = run.boss.global_position + Vector3(0, 0.3, 6.0)
		zone.camera_rig.snap_to_target()


func _start_casting(hero: Hero, cls: StringName, spam: bool) -> void:
	_caster = hero
	_cast_skills.clear()
	var pool := ClassData.pool(cls)
	if spam:
		# The god skill and every star skill, and the three biggest class skills.
		var regular := pool.filter(func(s): return int(s.get("star", 0)) == 0)
		for s in pool:
			if int(s.get("star", 0)) > 0:
				_cast_skills.append(s)
		for s in regular.slice(maxi(0, regular.size() - 3)):
			_cast_skills.append(s)
		_cast_every = 0.8
	else:
		_cast_skills = pool.filter(func(s): return int(s.get("star", 0)) == 0)
		_cast_every = 1.4


func _process(delta: float) -> void:
	if _caster != null and is_instance_valid(_caster) and not _cast_skills.is_empty():
		_cast_timer -= delta
		if _cast_timer <= 0.0:
			_cast_timer = _cast_every
			_caster.cooldowns.clear()
			_caster._cast_until = 0
			Game.profile.mp = 10000000
			var mobs := get_tree().get_nodes_in_group("mobs")
			if not mobs.is_empty() and (_caster.target == null or not is_instance_valid(_caster.target)):
				_caster.target = mobs[0]
			_caster._cast(_cast_skills[_cast_i % _cast_skills.size()])
			_cast_i += 1
	var now := Time.get_ticks_usec()
	if _recording and _last > 0:
		frame_us.append(now - _last)
		draws.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		prims.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
		objs.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
	_last = now


static func _stat(a: PackedInt32Array) -> Dictionary:
	var s := Array(a)
	s.sort()
	if s.is_empty():
		return {"med": 0, "mean": 0.0, "p95": 0, "max": 0}
	var total := 0
	for v in s:
		total += v
	return {"med": s[s.size() / 2], "mean": float(total) / s.size(), "p95": s[int(s.size() * 0.95)], "max": s[-1]}


func _particles() -> Vector2i:
	var emitters := 0
	var alive := 0
	for n in get_tree().root.find_children("*", "CPUParticles3D", true, false):
		var p := n as CPUParticles3D
		if p.is_visible_in_tree() and p.emitting:
			emitters += 1
			alive += p.amount
	for n in get_tree().root.find_children("*", "GPUParticles3D", true, false):
		var p := n as GPUParticles3D
		if p.is_visible_in_tree() and p.emitting:
			emitters += 1
			alive += p.amount
	return Vector2i(emitters, alive)


func _measure(scene: String, quality: int, frames: int) -> void:
	frame_us.clear()
	_recording = true
	_last = 0
	var peak_nodes := 0
	var peak_particles := Vector2i.ZERO
	var peak_video := 0.0
	# At least [param frames] frames and at least MIN_SECONDS (headless frames are short:
	# the casts and the crowd need time to happen).
	var started := Time.get_ticks_msec()
	var i := 0
	while i < frames or Time.get_ticks_msec() - started < MIN_SECONDS * 1000:
		i += 1
		await get_tree().process_frame
		if i % 120 == 60:
			# Sampled now and then (find_children is itself slow): drop this frame's time.
			var p := _particles()
			if p.y > peak_particles.y:
				peak_particles = p
			peak_nodes = maxi(peak_nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
			peak_video = maxf(peak_video, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
			_last = 0
	_recording = false
	var f := _stat(frame_us)
	var d := _stat(draws)
	var pr := _stat(prims)
	var ob := _stat(objs)
	var pets := 0
	for group in ["pet_followers", "ai_pets", "pets"]:
		for n in get_tree().get_nodes_in_group(group):
			if (n as Node3D).is_visible_in_tree():
				pets += 1
	print("PHONE PERF %s q%d%s p%d: frames %d | frame med %.2f mean %.2f p95 %.2f ms | draws med %d max %d | prims med %d max %d | objs med %d | nodes %d peak %d | objects %d | video %.1f MB (peak %.1f) tex %.1f MB buf %.1f MB | emitters %d particles %d (peak %d/%d) | players %d pets %d | casts %d | vfx %s" % [
		scene, quality, " smooth" if GameSettings.high_smooth else "", MemoryGuard.pressure, frame_us.size(),
		f.med / 1000.0, f.mean / 1000.0, f.p95 / 1000.0,
		d.med, d.max, pr.med, pr.max, ob.med,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), peak_nodes, int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, peak_video / 1048576.0,
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0,
		_particles().x, _particles().y, peak_particles.x, peak_particles.y,
		get_tree().get_nodes_in_group("world_players").size() + get_tree().get_nodes_in_group("gw_fighters").size(), pets, _cast_i, VfxBudget.counters()])
