extends Node
## The hero's own skill effects always show, however busy the field is (an iPhone
## report: "when I use a skill I don't see its effect at all").
##
## A hunting field full of AI world players fights for a while at iPhone settings (low /
## medium quality, MemoryGuard pressure 1 and 2, a phone running warm), and their casts
## keep the shared decorative budget (VfxBudget) full. Then the hero casts every skill on
## its bar, for the classes, away from the others: each cast must draw visible effect
## pieces near the hero and its target, and at least a third of what the same skill draws
## on an empty field. Nobody but the hero spends the hero's room, and every reservation
## (the hero's room's too, pooled layers included) comes back once the zone goes.
## Before the hero's room, the hero's casts drew 0-3 pieces on such a field.
##   godot --headless --path . res://tests/integration/hero_vfx_priority_test.tscn

const SCENARIOS := [
	# [label, quality, pressure, hot, classes, crowd]
	["q0 pressure2 hot, field empty", 0, 2, true, [&"warrior", &"mage", &"defender"], false],
	["q1 pressure1", 1, 1, false, [&"archer", &"bard"], true],
	["q0 pressure2", 0, 2, false, [&"darklord", &"priest"], true],
	["q0 pressure2 hot", 0, 2, true, [&"warrior", &"mage", &"defender", &"assassin", &"darklord", &"bard", &"archer", &"summoner", &"priest"], true],
]
## Effect pieces within this distance of the hero or its target count as the hero's.
const NEAR := 9.0
## The other players must be at least this far away while the hero casts.
const CLEAR := 26.0
## Seconds the AI players fight before the hero casts.
const FIGHT_SECONDS := 8.0

## Visible pieces every hero cast must draw (crowd or not).
const MIN_PIECES := 3

var failures := 0
var checks := 0
## Pieces each skill drew on the empty field ("skill/quality/pressure").
var _alone := {}
var place: StringName = &""
var _seen := {}
var _watched: Array = []
var _hero: Hero
var _focus := Vector3.ZERO


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func seconds(s: float) -> void:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame


func _ready() -> void:
	await get_tree().process_frame
	InputSetup.ensure_defaults()
	Game.set_process(false)
	WorldEvents.festival_enabled = false
	GameSettings.load_settings()
	GameSettings.show_world_players = true
	WorldPlayers.persist = false
	WorldPresence.enabled = true
	MemoryGuard.ios_override = 1
	MemoryGuard.phone_override = 1
	get_tree().node_added.connect(_on_node_added)
	_find_moment()
	check(place != &"", "a hunting field with world players was found")
	if place != &"":
		for s in SCENARIOS:
			await _scenario(String(s[0]), int(s[1]), int(s[2]), bool(s[3]), s[4], bool(s[5]))
	MemoryGuard.hot = false
	MemoryGuard.force(-1, get_tree())
	MemoryGuard.ios_override = -1
	MemoryGuard.phone_override = -1
	WorldPresence.clock_offset = 0.0
	print("HERO VFX PRIORITY: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


## The busiest moment of some hunting field (most scheduled world players).
func _find_moment() -> void:
	var best := 0
	for h in 24 * 20:
		var t := float(WorldPlayers.START_UNIX) + 30.0 * 86400.0 + h * 3600.0
		var count := {}
		for i in WorldPlayers.size():
			var s := WorldPlayers.state(i, t)
			if not bool(s.online):
				continue
			var z := StringName(s.place)
			var d := ZoneData.get_zone(z)
			if d.is_empty() or bool(d.get("safe", false)) or bool(d.get("pvp", false)) or bool(d.get("tower", false)) or bool(d.get("arena", false)) or bool(d.get("raid", false)):
				continue
			count[z] = int(count.get(z, 0)) + 1
		for z in count:
			if int(count[z]) > best:
				best = int(count[z])
				place = z
				WorldPresence.clock_offset = t - WorldPlayers.now()
	print("hero_vfx_priority_test: field %s with %d world players" % [place, best])


func _hero_profile(cls: StringName) -> void:
	Game.new_profile(cls, "VFX Priority")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile.party = []
	Game.fill_loadout()
	Game.profile.hp = Game.stats_now().max_hp


func _scenario(label: String, quality: int, pressure: int, hot: bool, classes: Array, crowd: bool) -> void:
	GameSettings.show_world_players = crowd
	GameSettings.quality = quality
	MemoryGuard.hot = hot
	MemoryGuard.force(pressure, get_tree())
	_hero_profile(classes[0])
	Game.current_zone = place
	var zone := Zone.new()
	zone.zone_id = place
	zone.layout_seed = 4242
	add_child(zone)
	while not zone.is_built:
		await get_tree().process_frame
	await frames(3)
	_hero = zone.hero
	_hero.set_physics_process(false)
	# The test watches effects, not a fight the hero could lose.
	_hero._invulnerable_until = Time.get_ticks_msec() + 100000000
	# A Dark Lord's raven hunts on its own and its strikes are the hero's (they rightly use
	# the hero's room): keep it still while only the others fight, then let it fly again.
	var raven_mode := Node.PROCESS_MODE_INHERIT
	if is_instance_valid(_hero.raven):
		raven_mode = _hero.raven.process_mode
		_hero.raven.process_mode = Node.PROCESS_MODE_DISABLED
	# The AI world players hunt and cast for a while.
	var players := _players()
	var peak := {"particles": 0, "decorations": 0}
	var hero_peak := 0
	var full_samples := 0
	var samples := 0
	var end := Time.get_ticks_msec() + int(FIGHT_SECONDS * 1000.0)
	while Time.get_ticks_msec() < end:
		await frames(6)
		var c := VfxBudget.counters()
		var h := VfxBudget.hero_counters()
		peak.particles = maxi(peak.particles, int(c.particles))
		peak.decorations = maxi(peak.decorations, int(c.decorations))
		hero_peak = maxi(hero_peak, int(h.particles) + int(h.decorations))
		samples += 1
		if int(c.decorations) + 3 > VfxBudget.decoration_limit():
			full_samples += 1
	print("hero_vfx_priority_test: %s: %d players fought %.0f s; limits particles %d decorations %d (hero's room %d / %d); peak %d / %d; budget (nearly) full in %d of %d samples" % [
		label, players.size(), FIGHT_SECONDS, VfxBudget.particle_limit(), VfxBudget.decoration_limit(), VfxBudget.hero_particle_room(), VfxBudget.hero_decoration_room(),
		peak.particles, peak.decorations, full_samples, samples])
	check(players.size() >= 3 or not crowd, "%s: the field has AI players fighting (%d)" % [label, players.size()])
	if crowd:
		check(full_samples * 2 >= samples, "%s: the others' casts keep the shared budget full (%d of %d samples)" % [label, full_samples, samples])
	check(hero_peak == 0, "%s: nobody but the hero spends the hero's room (%d)" % [label, hero_peak])
	if is_instance_valid(_hero.raven):
		_hero.raven.process_mode = raven_mode
	# The hero casts every skill on its bar, class after class, away from the crowd.
	var total := 0
	var casts := 0
	var fewest := 1 << 30
	for cls in classes:
		_hero_profile(cls)
		for skill in Game.class_data().skills:
			if skill.is_empty() or not Game.skill_unlocked(skill):
				continue
			var shown := await _cast(zone, skill)
			total += shown
			fewest = mini(fewest, shown)
			casts += 1
			var key := "%s/%d/%d" % [skill.id, quality, pressure]
			if not crowd:
				_alone[key] = shown
			check(shown >= MIN_PIECES, "%s: %s's %s shows its effect to the hero (%d pieces; budget %s / limit %d)" % [label, cls, skill.id, shown, VfxBudget.counters(), VfxBudget.decoration_limit()])
			if crowd and _alone.has(key):
				check(shown * 3 >= int(_alone[key]), "%s: %s's %s draws at least a third of what it draws on an empty field (%d of %d)" % [label, cls, skill.id, shown, int(_alone[key])])
	print("hero_vfx_priority_test: %s: %d hero casts, %.1f visible pieces each, fewest %d" % [label, casts, float(total) / maxf(1.0, casts), fewest])
	# Leaving the zone gives every reservation back, the hero's room too.
	zone.queue_free()
	await frames(4)
	await seconds(0.3)
	var pool := SkillLayerPool.existing(get_tree())
	check(VfxBudget.counters().particles == 0 and VfxBudget.counters().decorations == 0, "%s: the zone change returns every reservation (%s)" % [label, VfxBudget.counters()])
	check(VfxBudget.hero_counters() == {"particles": 0, "decorations": 0}, "%s: and the hero's room (%s)" % [label, VfxBudget.hero_counters()])
	check(pool == null or pool.active_count() == 0, "%s: no pooled layer still plays" % label)


func _players() -> Array:
	return get_tree().get_nodes_in_group("world_players").filter(func(n): return n is FieldPlayer and not n.is_queued_for_deletion())


## A mob far from every other player, the hero beside it, then one cast: the visible
## effect pieces that appear near the two within the cast's time.
func _cast(zone: Zone, skill: Dictionary) -> int:
	var mob := _quiet_mob()
	if mob == null:
		check(false, "a mob away from the crowd for %s" % skill.id)
		return 0
	# The previous cast's lingering art gives the hero's room back first, so every cast is
	# measured from the same start, alone or in the crowd.
	var settle := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < settle and VfxBudget.hero_counters() != {"particles": 0, "decorations": 0}:
		await get_tree().process_frame
	_hero.global_position = mob.global_position + Vector3(2.4, 0, 0)
	_hero.cooldowns.clear()
	_hero._cast_until = 0
	Game.profile.mp = 999999
	_hero.set_target(mob)
	_focus = mob.global_position
	_seen.clear()
	_watched.clear()
	for pool_holder in _pools():
		for n in pool_holder.find_children("*", "GeometryInstance3D", true, false):
			_watched.append(n)
	_hero._cast(skill)
	var end := Time.get_ticks_msec() + int((float(skill.get("hit_delay", 0.4)) + 1.1) * 1000.0)
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame
		_look()
	await seconds(0.2)
	return _seen.size()


func _quiet_mob() -> Mob:
	var best: Mob = null
	var best_d := 0.0
	var players := _players()
	for m in get_tree().get_nodes_in_group("mobs"):
		var mob := m as Mob
		if mob == null or mob.is_dead() or mob.is_queued_for_deletion() or not mob.is_inside_tree():
			continue
		var d := 100000.0
		for p in players:
			d = minf(d, (p as Node3D).global_position.distance_to(mob.global_position))
		if d > best_d:
			best_d = d
			best = mob
	if best != null and best_d < CLEAR:
		# Move it out of everyone's way.
		var away := Vector3.ZERO
		for p in players:
			away += (p as Node3D).global_position
		away /= maxf(1.0, players.size())
		best.global_position = away + (best.global_position - away).normalized() * (CLEAR + 4.0)
	if best != null:
		best.set_physics_process(false)
	return best


func _pools() -> Array:
	var out := []
	var pool := SkillLayerPool.existing(get_tree())
	if pool:
		out.append(pool)
	var vp := get_viewport()
	if vp.has_meta(MeleeArt.HOLDER) and is_instance_valid(vp.get_meta(MeleeArt.HOLDER)):
		out.append(vp.get_meta(MeleeArt.HOLDER))
	return out


func _on_node_added(node: Node) -> void:
	if node is GeometryInstance3D and not node is Label3D:
		_watched.append(node)


func _look() -> void:
	var hero_at := _hero.global_position
	for n in _watched:
		if not is_instance_valid(n):
			continue
		var g := n as GeometryInstance3D
		var id := g.get_instance_id()
		if _seen.has(id) or not g.is_inside_tree() or not g.is_visible_in_tree():
			continue
		if g is CPUParticles3D and not (g as CPUParticles3D).emitting:
			continue
		if g is MeshInstance3D and (g as MeshInstance3D).mesh == null:
			continue
		if _hero.is_ancestor_of(g) and not g.top_level:
			continue
		var at := g.global_position
		var flat := Vector2(at.x, at.z)
		if flat.distance_to(Vector2(hero_at.x, hero_at.z)) < NEAR or flat.distance_to(Vector2(_focus.x, _focus.z)) < NEAR:
			_seen[id] = true
