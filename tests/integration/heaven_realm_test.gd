extends Node3D
## ดินแดนเทวาลัย (HeavenRealmData), the hunting field from ★300 toward ★500: the ★300
## gate, the abyss's side portal and the warp row, the zone's flags and drop table, the
## bestiary's band above the ★200-300 fields and the isle, the boss (its two moves, its
## spawn gated at ENTRY_STAR), the ★500 gear hook with and without Star500Gear, the world
## players who hunt there from ★300, the region quests, its music and sky, and the
## scenery (builds inside its budget at every quality, keeps its ways, camps and court
## clear, no lights or particles).
## godot --headless --path . res://tests/integration/heaven_realm_test.tscn
var checks := 0
var failures := 0

const ID := HeavenRealmData.ID
const STUB := "user://heaven_star500_stub.gd"


func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", note)


func _ready() -> void:
	Game.set_process(false)
	WorldEvents.festival_enabled = false
	ZoneData.ensure()
	_gate_and_travel()
	_bestiary()
	_drops()
	_gear_hook()
	_world_players()
	_quests()
	_scenery()
	await _in_game()
	await _abyss_portal()
	print("HEAVEN REALM: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _gate_and_travel() -> void:
	var z := ZoneData.get_zone(ID)
	check(ID == &"heaven_realm" and ZoneData.ZONES.has(ID) and String(z.name) == "ดินแดนเทวาลัย" and HeavenRealmData.TITLE == "ดินแดนเทวาลัย", "the realm exists with its Thai name")
	check(HeavenRealmData.ENTRY_STAR == 300 and int(z.star) == 300, "it opens at ★300")
	check(ZoneData.access_reason(ID, 100, 299) != "" and ZoneData.access_reason(ID, 100, 299).contains("300"), "299 stars cannot enter, the lock names 300")
	check(ZoneData.access_reason(ID, 99, 300) != "", "below Lv.100 cannot enter")
	for stars in [300, 400, 500]:
		check(ZoneData.access_reason(ID, 100, stars) == "", "%d stars enter" % stars)
	check(StringName(z.prev) == DrownedAbyssData.ID and String(z.next) == "", "its way back leads to the abyss")
	var route := WarpScreen.destinations()
	check(not route.has(ID) and route[-1] == SkyIsleData.ID, "the travel chain is unchanged (the realm is a side destination)")
	check(HeavenRealmData.sign_text() == "ดินแดนเทวาลัย • ดาว 300 ขึ้นไป", "the sign reads ดินแดนเทวาลัย • ดาว 300 ขึ้นไป")
	check(bool(z.divine_region) and bool(z.heaven_loot) and not bool(z.get("endgame_loot", false)) and not bool(z.get("sky_isle_loot", false)), "its own loot table, ★-field rules")
	check(z.camps.size() >= 6 and z.camps.size() <= 7, "six or seven camps (%d)" % z.camps.size())
	check(StringName(z.boss.monster) == HeavenMonsters.BOSS and int(z.boss.star) == HeavenRealmData.ENTRY_STAR and float(z.boss.respawn) > 0.0, "the boss stands from ENTRY_STAR and respawns")
	check(BossWorld.has_boss(ID) and BossWorld.respawn(ID) == HeavenRealmData.BOSS_RESPAWN, "the boss is a world boss of its own respawn")
	check(AudioManager.has_music(StringName(z.music)) and StringName(z.music) == ID, "its own music")
	check(SkyArt.MOODS.has(ID), "its own sky mood")
	check(MonsterData.ZONE_TUNING.has(ID) and MonsterData.LATE_HP.has(ID), "its own tuning rows")


func _role(table: Dictionary, key: String, role: String) -> float:
	var sum := 0.0
	var n := 0
	for id in table:
		var m: Dictionary = table[id]
		var r := "boss" if bool(m.get("boss", false)) else ("elite" if bool(m.get("elite", false)) else "normal")
		if r == role:
			sum += float(m.get(key, 1.0))
			n += 1
	return sum / float(maxi(n, 1))


func _bestiary() -> void:
	var z := ZoneData.get_zone(ID)
	check(HeavenMonsters.NORMALS.size() == 5 and HeavenMonsters.ELITES.size() == 2, "five kinds and two elites")
	var lives := {}
	for camp in z.camps:
		for mid in camp.monsters:
			lives[mid] = true
			check(HeavenMonsters.has_monster(mid), "%s is of the realm" % mid)
		check(int(camp.levels[0]) >= HeavenRealmData.CAMP_MIN and int(camp.levels[1]) <= HeavenRealmData.CAMP_MAX, "%s inside the band" % camp.name)
	for id in HeavenMonsters.NORMALS + HeavenMonsters.ELITES:
		check(lives.has(id), "%s has a camp" % id)
		check(MonsterData.home_zone(id) == ID, "%s lives here" % id)
	check(MonsterData.home_zone(HeavenMonsters.BOSS) == ID, "the boss lives here")
	check(HeavenRealmData.CAMP_MIN > SkyIsleData.CAMP_MIN and HeavenRealmData.CAMP_MAX > SkyIsleData.CAMP_MAX and HeavenRealmData.BOSS_LEVEL > SkyIsleData.BOSS_LEVEL, "levels above the isle")
	for r in ["normal", "elite", "boss"]:
		for key in ["exp", "gold"]:
			check(_role(HeavenMonsters.MONSTERS, key, r) > _role(SkyIsleData.MONSTERS, key, r), "%s %s above the isle's" % [r, key])
	# Real numbers at the camps' levels: tougher than the ★200-300 fields and the isle.
	var mean := func(ids: Array, levels: Array, stat: String) -> float:
		var s := 0.0
		for id in ids:
			s += float(MonsterData.stats_for(id, int(round((float(levels[0]) + float(levels[1])) * 0.5)))[stat])
		return s / float(ids.size())
	for stat in ["hp", "atk"]:
		var ours: float = mean.call(HeavenMonsters.NORMALS, [HeavenRealmData.CAMP_MIN, HeavenRealmData.CAMP_MAX], stat)
		var abyss: float = mean.call(DrownedAbyssData.NORMALS, [EndgameFields.CAMP_MIN, EndgameFields.CAMP_MAX], stat)
		var isle: float = mean.call(SkyIsleData.NORMALS, [SkyIsleData.CAMP_MIN, SkyIsleData.CAMP_MAX], stat)
		check(ours > abyss * 1.5 and ours > isle and ours < isle * 2.5, "normal %s above the abyss and the isle (%.0f / abyss %.0f / isle %.0f)" % [stat, ours, abyss, isle])
	var boss := MonsterData.stats_for(HeavenMonsters.BOSS, HeavenRealmData.BOSS_LEVEL)
	var god := MonsterData.stats_for(SkyIsleData.BOSS, SkyIsleData.BOSS_LEVEL)
	check(float(boss.hp) > float(god.hp) and float(boss.atk) > float(god.atk) * 0.9, "the boss outlasts the Dragon God (%d / %d HP)" % [int(boss.hp), int(god.hp)])
	var t := HeavenMonsters.monster(HeavenMonsters.BOSS)
	check(bool(t.boss) and BossAttack.MOVES.has(String(t.behavior)) and BossAttack.MOVES.has(String(t.behavior2)) and bool(t.alternate), "the boss takes turns with two BossAttack moves (%s, %s)" % [t.behavior, t.behavior2])
	check(String(t.model) == "summon/WindKing" and String(t.legend) == "wind_king", "the boss is the Wind King grown to a giant")
	for id in HeavenMonsters.NORMALS + HeavenMonsters.ELITES:
		check(MobAttack.knows(HeavenMonsters.monster(id)), "%s fights with a MobAttack move" % id)
	check(MonsterData.get_monster(&"heaven_hound").name == HeavenMonsters.MONSTERS[&"heaven_hound"].name, "MonsterData knows the realm's monsters")
	# The look: tinted rigs with the golden halo; the elites crowned.
	for id in [&"heaven_lantern", &"heaven_gatekeeper"]:
		var tm := MonsterData.get_monster(id)
		var visual := Node3D.new()
		add_child(visual)
		DeepMonsterArt.attach(visual, tm)
		var aura := visual.get_node_or_null("DeepAura")
		check(aura != null and aura.get_child_count() >= (10 if bool(tm.get("elite", false)) else 4), "%s wears its halo" % id)
		check(visual.find_children("*", "Light3D", true, false).is_empty(), "%s: no lights" % id)
		visual.free()


func _drops() -> void:
	var z := ZoneData.get_zone(ID)
	for key in ["purple", "pink", "chaos"]:
		check(float(z.jewel_drop[key]) > float(EndgameFields.JEWEL_DROP[key]), "%s jewels drop more often than the ★200 fields" % key)
	check(float(z.set_core_drop) > EndgameFields.SET_CORE_DROP, "set cores drop more often")
	check(int(z.gear_star) > SkyIsleData.GEAR_STAR, "more EXP a kill than the isle")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var boss := HeavenRealmData.kill_drops(&"warrior", true, false, 0.0, rng)
	check(boss.any(func(it): return String(it.get("id", "")) == HeavenRealmData.SET_CORE), "the boss always drops a set core")
	check(boss.filter(func(it): return String(it.get("kind", "")) == "gem").size() == HeavenRealmData.GEM_BOSS, "the boss drops its gems")
	check(boss.any(func(it): return String(it.get("id", "")) == EndgameFields.SCALE and int(it.get("count", 1)) == HeavenRealmData.SCALE_BOSS), "the boss drops Lotus Scales")
	var gems := 0
	var cores := 0
	for i in 4000:
		for it in HeavenRealmData.kill_drops(&"mage", false, false, 0.0, rng):
			if String(it.get("kind", "")) == "gem": gems += 1
		for it in HeavenRealmData.kill_drops(&"mage", false, true, 0.0, rng):
			if String(it.get("id", "")) == HeavenRealmData.SET_CORE: cores += 1
	check(gems > 4000 * HeavenRealmData.GEM_NORMAL * 0.7 and gems < 4000 * HeavenRealmData.GEM_NORMAL * 1.3, "normal gems about %.0f%% (%d)" % [HeavenRealmData.GEM_NORMAL * 100.0, gems])
	check(cores > 20 and cores < 110, "elites drop extra set cores now and then (%d of 4000)" % cores)
	check(HeavenRealmData.STAR500_NORMAL < HeavenRealmData.STAR500_ELITE and HeavenRealmData.STAR500_ELITE < HeavenRealmData.STAR500_BOSS, "★500 gear: rare from monsters, better from elites and the boss")


func _gear_hook() -> void:
	var real := ResourceLoader.exists(HeavenRealmData.STAR500_GEAR_PATH)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	# Without the gear module: nothing, no error, the table still works.
	HeavenRealmData.star500_path = "res://data/__no_such_star500_gear.gd"
	check(not HeavenRealmData.star500_ready() and HeavenRealmData.star500_drop(rng, &"warrior", true).is_empty(), "without Star500Gear the hook gives nothing")
	var any := false
	for i in 50:
		var drops := HeavenRealmData.kill_drops(&"warrior", true, false, 0.0, rng)
		any = any or drops.any(func(it): return HeavenRealmData.is_star500_item(it))
	check(not any, "without the module no kill drops ★500 gear")
	# With a stand-in module: the boss's pieces come through it, at about its rate.
	var f := FileAccess.open(STUB, FileAccess.WRITE)
	f.store_string("extends RefCounted\nstatic func drop(rng: RandomNumberGenerator, cls: StringName, from_boss: bool) -> Dictionary:\n\tif rng.randf() >= (0.1 if from_boss else 0.002):\n\t\treturn {}\n\treturn {\"kind\": \"gear\", \"slot\": \"weapon\", \"id\": \"stub500_%s\" % cls, \"name\": \"stub\", \"star_tier\": 500, \"cls\": String(cls), \"boss\": from_boss, \"r\": rng.randf()}\n")
	f.close()
	HeavenRealmData.star500_path = STUB
	check(HeavenRealmData.star500_ready(), "the stand-in module is found")
	var piece := {}
	while piece.is_empty():
		piece = HeavenRealmData.star500_drop(rng, &"mage", true)
	check(String(piece.get("id", "")) == "stub500_mage" and bool(piece.boss), "Star500Gear.drop(rng, cls, from_boss) is called as agreed")
	var boss_pieces := 0
	var normal_pieces := 0
	for i in 2000:
		for it in HeavenRealmData.kill_drops(&"warrior", true, false, 0.0, rng):
			if HeavenRealmData.is_star500_item(it): boss_pieces += 1
	for i in 20000:
		for it in HeavenRealmData.kill_drops(&"warrior", false, false, 0.0, rng):
			if HeavenRealmData.is_star500_item(it): normal_pieces += 1
	check(boss_pieces > 2000 * HeavenRealmData.STAR500_BOSS * 0.8 and boss_pieces < 2000 * HeavenRealmData.STAR500_BOSS * 1.2, "the boss drops ★500 gear about %.0f%% (%d / 2000)" % [HeavenRealmData.STAR500_BOSS * 100.0, boss_pieces])
	check(normal_pieces > 10 and normal_pieces < 90, "ordinary monsters seldom do (%d / 20000)" % normal_pieces)
	# A module that gives back something else is ignored.
	f = FileAccess.open(STUB, FileAccess.WRITE)
	f.store_string("extends RefCounted\nstatic func drop(_rng, _cls, _from_boss):\n\treturn null\n")
	f.close()
	HeavenRealmData.star500_path = STUB + ".missing"
	check(HeavenRealmData.star500_drop(rng, &"mage", false).is_empty(), "a missing module gives nothing")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STUB))
	HeavenRealmData.star500_path = HeavenRealmData.STAR500_GEAR_PATH
	# The real module, once it is in the game.
	check(HeavenRealmData.star500_ready() == (real and HeavenRealmData.star500_ready()), "the real path is looked up")
	if real and HeavenRealmData.star500_ready():
		for cls in [&"warrior", &"mage", &"summoner"]:
			var item := HeavenRealmData.star500_drop(rng, cls, true)
			check(item is Dictionary, "Star500Gear.drop gives a Dictionary for %s" % cls)
		print("heaven_realm_test: Star500Gear is in the game, its drops were called")


func _world_players() -> void:
	var at_300 := 0
	var heaven := 0
	var below := 0
	for i in WorldPlayers.size():
		for k in 40:
			var s0 := float(WorldPlayers.START_UNIX) + float(k) * 7200.0 + float(i) * 97.0
			if WorldPlayers.session_zone(i, s0, Game.MAX_LEVEL, 299) == ID:
				below += 1
			at_300 += 1
			if WorldPlayers.session_zone(i, s0, Game.MAX_LEVEL, 300) == ID:
				heaven += 1
	var share := float(heaven) / float(maxi(1, at_300))
	print("heaven_realm_test: %d of %d ★300 hunting sessions in the realm (%.0f%%)" % [heaven, at_300, share * 100.0])
	check(below == 0, "no world player under ★300 hunts there")
	check(share > 0.15 and share < 0.45, "about a quarter of the ★300 sessions hunt in the realm (%.0f%%)" % [share * 100.0])
	check(WorldPlayers.hunting_zone(Game.MAX_LEVEL, 300) == DrownedAbyssData.ID, "the home field's rule is unchanged")
	# The sessions the schedule really plays: ★300 players are seen there.
	var seen := 0
	for d in [180.0, 200.0, 220.0]:
		for h in [3.0, 14.0, 20.0]:
			var t: float = float(WorldPlayers.START_UNIX) + d * 86400.0 + h * 3600.0
			for i in WorldPlayers.size():
				if WorldPlayers.session_at(i, t).is_empty():
					continue
				var s := WorldPlayers.state(i, t)
				if StringName(String(s.place)) == ID:
					check(int(s.stars) >= HeavenRealmData.ENTRY_STAR and int(s.level) >= Game.MAX_LEVEL, "%s is in the realm at ★%d" % [String(s.name), int(s.stars)])
					seen += 1
	check(seen > 0, "★300 world players are hunting in the realm (%d)" % seen)


func _quests() -> void:
	var ids := ["heaven_lanterns", "heaven_guardians", "heaven_monkey_king"]
	var z := ZoneData.get_zone(ID)
	for id in ids:
		var q := QuestData.get_quest(id)
		check(not q.is_empty() and String(q.zone) == String(ID) and int(q.star) >= HeavenRealmData.ENTRY_STAR and QuestData.ORDER.has(id), "quest %s is in the chain" % id)
		var lives := StringName(z.boss.monster) == StringName(q.target)
		for camp in z.camps:
			lives = lives or camp.monsters.has(StringName(q.target))
		check(lives and int(q.exp) > 0 and int(q.gold) > 0, "quest %s hunts a monster of the realm and pays" % id)
	check(String(QuestData.get_quest("lotus_seraph").next) == ids[0], "the chain goes on from the lotus queen")
	check(int(QuestData.get_quest(ids[2]).count) == 1 and String(QuestData.get_quest(ids[2]).target) == String(HeavenMonsters.BOSS), "the last one is the boss")


func _triangles(mesh: Mesh) -> int:
	var n := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var index: Variant = arrays[Mesh.ARRAY_INDEX]
		n += (index.size() if index != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return n


func _scenery() -> void:
	var layout := HeavenRealmArt.layout()
	var saved := GameSettings.quality
	for q in [0, 1, 2]:
		GameSettings.quality = q
		var holder := Node3D.new()
		add_child(holder)
		HeavenRealmArt.build(holder)
		var art := holder.get_child(0)
		check(art != null and art.get_meta("zone_id", &"") == ID and art.get_child_count() > 8, "q%d: the scenery builds" % q)
		check(art.find_children("*", "Light3D", true, false).is_empty() and art.find_children("*", "GPUParticles3D", true, false).is_empty() and art.find_children("*", "CPUParticles3D", true, false).is_empty(), "q%d: no lights or particles" % q)
		var draws := 0
		var instances := 0
		var triangles := 0
		for node in art.get_children():
			if node is MultiMeshInstance3D:
				draws += 1
				var mm: MultiMesh = node.multimesh
				instances += mm.instance_count
				triangles += mm.instance_count * _triangles(mm.mesh)
			elif node is MeshInstance3D:
				draws += 1
				triangles += _triangles(node.mesh)
		print("HEAVEN ART q%d: %d draws, %d instances, %d triangles" % [q, draws, instances, triangles])
		check(draws <= 70, "q%d: %d draws (70 at most)" % [q, draws])
		check(instances > 1500 and instances <= 9000, "q%d: %d batched instances (9000 at most)" % [q, instances])
		check(triangles <= 200000, "q%d: %d triangles (200k at most)" % [q, triangles])
		check(art.get_node_or_null("HeavenGround") != null and art.get_node_or_null("HeavenTerraces") != null and art.get_node_or_null("SkyBelow") != null, "q%d: ground, terraces and the sky below" % q)
		var body := art.get_node_or_null("StarSceneryCollision") as StaticBody3D
		check(body != null and body.get_child_count() > 20, "q%d: scenery colliders" % q)
		var blocked: Array = []
		if body:
			for shape in body.get_children():
				var s := shape as CollisionShape3D
				var xz := Vector2(s.position.x, s.position.z)
				var radius: float = (s.shape as CylinderShape3D).radius
				var bad := StarRegionArt._path_distance(xz, layout.paths) < radius + 1.4
				for camp in layout.camp_positions:
					bad = bad or xz.distance_to(camp) < radius + 8.5
				bad = bad or xz.distance_to(Vector2(layout.spawn.x, layout.spawn.z)) < radius + 4.0 or xz.distance_to(Vector2(layout.boss_pos.x, layout.boss_pos.z)) < radius + 12.0
				if bad:
					blocked.append(xz)
		check(blocked.is_empty(), "q%d: nothing solid on a way, a camp, the spawn or the court %s" % [q, str(blocked)])
		holder.free()
	GameSettings.quality = saved


func _in_game() -> void:
	# Medium quality, as on a phone (the warp crystal's glow light is a high-quality extra).
	GameSettings.quality = 1
	Game.new_profile(&"warrior", "Heaven QA")
	Game.profile.level = 100
	Game.paragon()["level"] = 299
	var stats := Game.stats_now()
	Game.profile.hp = stats.max_hp
	Game.profile.mp = stats.max_mp
	Game.current_zone = ID
	var zone := Zone.new()
	zone.zone_id = ID
	add_child(zone)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(zone.hero != null and zone.get_node_or_null("HeavenRealmArt") != null, "the zone builds the realm")
	check(zone.hero.global_position.distance_to(HeavenRealmArt.layout().spawn) < 6.0, "the hero arrives at the gate")
	check(zone.portals.size() == 1 and StringName(zone.portals[0].to) == DrownedAbyssData.ID, "one portal, back to the abyss")
	check(zone.npcs.any(func(n): return n.role == "warp"), "a warp crystal at the entrance")
	var mobs := get_tree().get_nodes_in_group("mobs")
	check(mobs.size() >= 50, "the camps are populated (%d)" % mobs.size())
	var kinds := {}
	for mob in mobs:
		kinds[(mob as Mob).monster_id] = true
		check(HeavenMonsters.has_monster((mob as Mob).monster_id), "only the realm's monsters live here")
		check(int((mob as Mob).level) >= HeavenRealmData.CAMP_MIN, "camp level in the band")
	check(kinds.size() == 7, "every kind is about (%d)" % kinds.size())
	var aura := 0
	for mob in mobs:
		if (mob as Mob).visual.get_node_or_null("DeepAura") != null:
			aura += 1
	check(aura == mobs.size(), "every monster wears the golden halo")
	var texts := []
	for node in zone.find_children("*", "Label3D", true, false):
		texts.append((node as Label3D).text)
	check(texts.any(func(t): return String(t).contains(HeavenRealmData.sign_text()) and String(t).contains("ดรอป")), "the entrance stele names the realm, ★300 and the drops")
	check(texts.any(func(t): return String(t).contains("ลานทวารเทวาลัย")), "the court carries its name")
	check(zone.get_node_or_null("Weather") != null, "motes and feathers drift over it")
	var lights := zone.find_children("*", "OmniLight3D", true, false) + zone.find_children("*", "SpotLight3D", true, false)
	check(lights.is_empty(), "no local lights %s" % str(lights.map(func(l): return str(zone.get_path_to(l)))))
	# The boss: not below ENTRY_STAR, at its spot from ENTRY_STAR.
	zone._boss_timer = 0.0
	zone._tick_boss(1.0)
	check(zone._boss == null, "no boss for a ★299 hero")
	Game.paragon()["level"] = HeavenRealmData.ENTRY_STAR
	zone._boss_timer = 0.0
	zone._tick_boss(1.0)
	var state := BossWorld.state(ID)
	check(zone._boss != null or not bool(state.alive), "at ★300 the boss stands unless the world brought it down")
	if zone._boss == null:
		zone._spawn_field_boss(false)
	var boss: Mob = zone._boss
	check(boss != null and boss.monster_id == HeavenMonsters.BOSS and boss.is_boss and int(boss.level) == HeavenRealmData.BOSS_LEVEL, "the boss is the Wind King at Lv.%d" % HeavenRealmData.BOSS_LEVEL)
	if boss:
		check(boss.global_position.distance_to(HeavenRealmArt.layout().boss_pos) < 8.0, "it stands in its court")
		check(boss.visual.get_node_or_null("DeepAura") != null, "it wears its aura")
		# A kill's loot runs through the realm's table without the gear module.
		var before := zone.get_children().size()
		zone._heaven_loot(boss, boss.global_position)
		check(zone.get_children().size() > before, "the boss's kill drops its loot")
	zone.queue_free()
	await zone.tree_exited
	await get_tree().process_frame


func _abyss_portal() -> void:
	Game.paragon()["level"] = 300
	Game.current_zone = DrownedAbyssData.ID
	var zone := Zone.new()
	zone.zone_id = DrownedAbyssData.ID
	add_child(zone)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var to_heaven := zone.portals.filter(func(p): return StringName(p.to) == ID)
	check(to_heaven.size() == 1 and String(to_heaven[0].label) == "ดินแดนเทวาลัย • ดาว 300 ขึ้นไป", "the abyss has a portal to the realm, signed ดินแดนเทวาลัย • ดาว 300 ขึ้นไป")
	check(zone.portals.any(func(p): return StringName(p.to) == SkyIsleData.ID), "the way on to the isle is still there")
	if not to_heaven.is_empty():
		var at: Vector3 = to_heaven[0].pos
		check(Vector2(at.x, at.z).length() < 52.0, "the portal stands inside the field")
		for camp in DrownedAbyssArt.layout().camp_positions:
			check(Vector2(at.x, at.z).distance_to(camp) > 10.0, "the portal is off the camp at %s" % str(camp))
		check(StarRegionArt._path_distance(Vector2(at.x, at.z), DrownedAbyssArt.layout().paths) > 2.0, "the portal is off the ways")
	check(zone.get_node_or_null("HeavenPortalSign") != null, "a plaque hangs over it")
	zone.queue_free()
	await zone.tree_exited
	await get_tree().process_frame
