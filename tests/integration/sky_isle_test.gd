extends Node3D
## เกาะลอยฟ้าเทพมังกร (SkyIsleData), the ★300 hunting field beyond ห้วงสมุทรอสูร: the
## 300★ gate, the travel chain and warp list, the zone's flags (its own loot table, the
## rare dragon, the abyss's jewel and set core rolls, no shared endgame table), the
## all-dragon bestiary and the Dragon God with his two signature moves, the level band
## and tuning above the ★200-300 fields with better EXP and gold, its own music, sky,
## weather and sign, and the scenery (builds inside its budget, keeps its ways, camps and
## court clear, fences its sky bays, frees itself).
## godot --headless --path . res://tests/integration/sky_isle_test.tscn
var checks := 0
var failures := 0

const ID := SkyIsleData.ID


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
	_flags()
	_bestiary()
	_band()
	_boss_moves()
	_scenery()
	await _kirin()
	await _in_game()
	print("SKY ISLE: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _gate_and_travel() -> void:
	var z := ZoneData.get_zone(ID)
	check(ZoneData.ZONES.has(ID) and String(z.name) == "เกาะลอยฟ้าเทพมังกร" and SkyIsleData.ENTRY_STAR == 300, "the field exists with its Thai name at ★300")
	check(ZoneData.access_reason(ID, 100, 299) != "", "299 stars cannot enter")
	check(ZoneData.access_reason(ID, 99, 300) != "", "below Lv.100 cannot enter")
	for stars in [300, 301, 400]:
		check(ZoneData.access_reason(ID, 100, stars) == "", "%d stars enter" % stars)
	check(ZoneData.access_reason(ID, 100, 250).contains("300"), "the lock names the 300 stars it needs (%s)" % ZoneData.access_reason(ID, 100, 250))
	var route := WarpScreen.destinations()
	check(route[-1] == ID and route[-2] == DrownedAbyssData.ID, "the warp list ends with the abyss then the isle")
	check(StringName(ZoneData.get_zone(DrownedAbyssData.ID).next) == ID and StringName(z.prev) == DrownedAbyssData.ID and String(z.next) == "", "travel chain: abyss <-> isle, and the chain ends here")
	Game.new_profile(&"darklord", "Isle QA")
	Game.profile.level = 100
	Game.paragon()["level"] = 299
	check(not WarpScreen.unlocked(ID, 100), "the warp list keeps it locked at 299 stars")
	Game.paragon()["level"] = 300
	check(WarpScreen.unlocked(ID, 100), "the warp list opens it at 300 stars")
	check(StringName(z.music) == ID and AudioManager.has_music(ID), "its own music track")
	check(SkyArt.MOODS.has(ID) and Color(SkyArt.mood(ID).rays).a > 0.0, "its own sky mood with light shafts")
	check(Zone.WEATHER.has(StringName(z.weather)) and StringName(z.weather) not in [&"bubbles", &"petals", &"motes"], "its own weather (%s)" % z.weather)
	check(StringName(z.ambience) == &"wind", "the wind is its ambience")
	for word in ["อาวุธเทพมังกร", "ปีก 300 ดาว", "คอสตูม", "ไข่", "หีบสมบัติ"]:
		check(SkyIsleData.drop_text().contains(word), "the sign names %s" % word)


func _flags() -> void:
	var z := ZoneData.get_zone(ID)
	var abyss := ZoneData.get_zone(DrownedAbyssData.ID)
	check(bool(z.get("sky_isle_loot", false)) and bool(z.get("rare_dragon", false)), "its own loot table and the rare dragon")
	check(z.has("endgame_loot") and not bool(z.endgame_loot) and not EndgameFields.has(ID), "not the shared endgame table (no Lv.100 wings)")
	check(z.get("jewel_drop") == abyss.get("jewel_drop") and is_equal_approx(float(z.get("set_core_drop", 0.0)), float(abyss.set_core_drop)), "the abyss's jewel and set core rolls")
	check(bool(z.get("divine_region", false)) and int(z.star) == 300 and int(z.boss.star) == 300, "a ★ field gated at 300, boss included")
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var purple := 0
	for i in 60000:
		for item in Zone.jewel_drops(z, 0.0, 1.0, rng):
			if item.id == "purple": purple += 1
	check(absf(purple / 60000.0 - 0.03) < 0.004, "purple jewels at the abyss's 3%% (%.4f)" % (purple / 60000.0))


func _bestiary() -> void:
	var z := ZoneData.get_zone(ID)
	var seen := {}
	for camp in z.camps:
		for m in camp.monsters:
			seen[m] = true
			check(SkyIsleData.has_monster(m), "camp monster %s belongs to the field" % m)
		check(int(camp.levels[0]) >= SkyIsleData.CAMP_MIN and int(camp.levels[1]) <= SkyIsleData.CAMP_MAX and int(camp.levels[0]) > EndgameFields.CAMP_MAX, "camp %s is Lv.%d-%d, above the abyss" % [camp.name, SkyIsleData.CAMP_MIN, SkyIsleData.CAMP_MAX])
		check(float(camp.radius) > 0.0 and int(camp.count) >= 8, "camp %s is populated" % camp.name)
	check(z.camps.size() == 6, "six farm camps")
	check(SkyIsleData.NORMALS.size() == 5 and SkyIsleData.ELITES.size() == 2 and SkyIsleData.MONSTERS.size() == 8, "five kinds, two elites and the boss")
	var names := {}
	var models := {}
	for id in SkyIsleData.MONSTERS:
		var data := MonsterData.get_monster(id)
		var raw: Dictionary = SkyIsleData.MONSTERS[id]
		check(not MonsterData.MONSTERS.has(id) and not StarMonsters.has(id) and not DivineRegionData.has_monster(id) and not DrownedAbyssData.has_monster(id), "%s is a new monster" % id)
		check(data.name == raw.name and not names.has(raw.name), "%s dispatch and its own name" % id)
		names[raw.name] = true
		models[raw.model] = true
		check(ResourceLoader.exists("res://assets/models/monsters/%s.glb" % data.model) or ResourceLoader.exists("res://assets/models/monsters/%s.gltf" % data.model) or ResourceLoader.exists("res://assets/models/monsters/%s.fbx" % data.model), "%s model exists" % id)
		check(raw.has("aura") and raw.has("tint") and raw.has("color") and raw.has("paint") and raw.has("decor"), "%s is re-dressed (aura, tint, paint, colour, decor)" % id)
		check(is_equal_approx(float(data.hp), float(raw.hp) * SkyIsleData.TOUGH_HP), "%s ten times health" % id)
		check(seen.has(id) or id == SkyIsleData.BOSS, "%s lives in a camp" % id)
		check(MonsterData.home_zone(id) == ID, "%s is tuned as this field's" % id)
		if not bool(raw.get("boss", false)):
			check(MobAttack.knows(data), "%s has a MobAttack move" % id)
	check(models.size() >= 6, "the bestiary uses six or more rigs (%d)" % models.size())
	var moves := {}
	for id in SkyIsleData.NORMALS:
		moves[SkyIsleData.MONSTERS[id].behavior] = true
	check(moves.size() == 5, "every normal monster fights its own way")
	# Per role the multipliers sit above the abyss's.
	var role := func(table: Dictionary, key: String, want: String) -> float:
		var sum := 0.0
		var n := 0
		for id in table:
			var m: Dictionary = table[id]
			var r := "boss" if m.get("boss", false) else ("elite" if m.get("elite", false) else "normal")
			if r == want:
				sum += float(m.get(key, 1.0))
				n += 1
		return sum / float(maxi(n, 1))
	for r in ["normal", "elite", "boss"]:
		for key in ["exp", "gold"]:
			check(role.call(SkyIsleData.MONSTERS, key, r) > role.call(DrownedAbyssData.MONSTERS, key, r) * 1.15, "%s %s multiplier above the abyss's" % [r, key])
		for key in ["hp", "atk", "def"]:
			var ours: float = role.call(SkyIsleData.MONSTERS, key, r)
			var theirs: float = role.call(DrownedAbyssData.MONSTERS, key, r)
			check(ours >= theirs * 0.95 and ours <= theirs * 1.35, "%s %s multiplier in a sane range of the abyss's (%.2f / %.2f)" % [r, key, ours, theirs])
	# The look: the dragon-shaped ones are the Summoner's god-skill dragon (CelestialDragon),
	# each its own kind (palette, horns, pose, move); the kirin is sculpted the same way
	# (Kirin, KirinVisual: _kirin); the drake keeps its rig.
	var kinds := {}
	var palettes := {}
	var poses := {}
	for id in SkyIsleData.MONSTERS:
		var kind := String(SkyIsleData.MONSTERS[id].get("celestial", ""))
		if kind != "":
			check(CelestialDragon.has(kind) and not kinds.has(kind), "%s is its own celestial dragon (%s)" % [id, kind])
			kinds[kind] = true
			palettes[CelestialDragon.KINDS[kind].palette] = true
			poses[CelestialDragon.KINDS[kind].pose] = true
	check(kinds.size() == 6 and palettes.size() == 6 and poses.size() == 6, "six dragons, six palettes, six poses")
	check(SkyIsleData.MONSTERS[SkyIsleData.BOSS].get("celestial", "") == "god" and not SkyIsleData.MONSTERS[&"jade_drake"].has("celestial") and not SkyIsleData.MONSTERS[&"cloud_kirin"].has("celestial"), "the god is the Dragon God; the drake and the kirin keep their own shapes")
	check(String(SkyIsleData.MONSTERS[&"cloud_kirin"].get("beast", "")) == "kirin" and not SkyIsleData.MONSTERS[&"jade_drake"].has("beast"), "the kirin is the sculpted kirin, the drake its rig")
	# The dressing.
	for id in SkyIsleData.MONSTERS:
		var t := MonsterData.get_monster(id)
		var visual := CelestialDragonVisual.make(self, t)
		check((visual is CelestialDragonVisual) == t.has("celestial") and (visual is KirinVisual) == (String(t.get("beast", "")) == "kirin"), "%s is drawn as it should be" % id)
		if visual is CelestialDragonVisual:
			var body := visual.get_node_or_null("CelestialDragon/DragonBody") as MeshInstance3D
			check(body != null and body.mesh == CelestialDragon.mesh(String(t.celestial)) and is_equal_approx(visual.height, float(t.height) + float(t.get("hover", 0.0))), "%s: one shared mesh, fitted to %.1f m" % [id, float(t.height)])
		DragonMonsterArt.attach(visual, t)
		var aura := visual.get_node_or_null("DragonAura")
		check(aura != null and aura.get_child_count() >= 3 and aura.get_child_count() <= (60 if id == SkyIsleData.BOSS else 20), "%s wears its dressing (%d pieces)" % [id, aura.get_child_count() if aura else 0])
		check(visual.find_children("*", "Light3D", true, false).is_empty() and visual.find_children("*", "GPUParticles3D", true, false).is_empty(), "%s: no lights or particles" % id)
		var before := aura.get_child_count() if aura else 0
		DragonMonsterArt.attach(visual, t)
		check(aura != null and aura.get_child_count() == before, "%s is dressed once" % id)
		visual.free()
	var god := Node3D.new()
	add_child(god)
	DragonMonsterArt.attach(god, SkyIsleData.monster(SkyIsleData.BOSS))
	check(god.get_node_or_null("DragonAura") != null and god.get_node("DragonAura").get_child_count() >= 40, "the Dragon God wears his halo, crown and pearl")
	god.free()


func _band() -> void:
	var z := ZoneData.get_zone(ID)
	var abyss := ZoneData.get_zone(DrownedAbyssData.ID)
	check(MonsterData.ZONE_TUNING[ID] == SkyIsleData.TUNING and is_equal_approx(float(MonsterData.LATE_HP[ID]), SkyIsleData.LATE_HP), "its own tuning rows")
	check(MonsterData.ZONE_TUNING[ID] != EndgameFields.TUNING, "the tuning is no longer the stub's")
	var boss: Dictionary = z.boss
	check(StringName(boss.monster) == SkyIsleData.BOSS and bool(MonsterData.get_monster(boss.monster).get("boss", false)), "the Dragon God is the field boss")
	check(int(boss.level) == SkyIsleData.BOSS_LEVEL and int(boss.level) > SkyIsleData.CAMP_MAX and int(boss.level) > int(abyss.boss.level), "the boss outranks the camps and Poseidon")
	check(float(boss.respawn) >= float(abyss.boss.respawn), "the boss respawns no faster than Poseidon")
	# Stronger, and richer, than the abyss at the middle of each field.
	var ours := MonsterData.stats_for(&"jade_drake", 220)
	var theirs := MonsterData.stats_for(&"reef_crab", 190)
	check(ours.hp > theirs.hp and ours.atk > theirs.atk * 2.0 and ours.def > theirs.def, "an isle drake outclasses an abyss crab (%s / %s)" % [ours, theirs])
	var our_boost := 1.0 + float(z.gear_star) / 25.0
	var their_boost := 1.0 + float(abyss.gear_star) / 25.0
	var exp_gain := float(ours.exp) * our_boost / (float(theirs.exp) * their_boost)
	var gold_gain := float(ours.gold) / float(theirs.gold)
	check(exp_gain > 1.4 and exp_gain < 3.0, "EXP a kill clearly better than the abyss (x%.2f)" % exp_gain)
	check(gold_gain > 1.3 and gold_gain < 3.0, "gold a kill clearly better than the abyss (x%.2f)" % gold_gain)
	var god := MonsterData.stats_for(SkyIsleData.BOSS, int(boss.level))
	var tyrant := MonsterData.stats_for(DrownedAbyssData.BOSS, int(abyss.boss.level))
	check(god.hp > tyrant.hp * 2.0 and god.atk > tyrant.atk * 3.0 and god.def > tyrant.def and god.exp > tyrant.exp and god.gold > tyrant.gold, "the Dragon God is the hardest field boss (%s / %s)" % [god, tyrant])
	for zone_id in ZoneData.ZONES:
		var other: Dictionary = ZoneData.ZONES[zone_id]
		if zone_id != ID and other.has("boss") and other.has("camps"):
			var rival := MonsterData.stats_for(StringName(other.boss.monster), int(other.boss.level))
			check(god.hp > rival.hp and god.atk > rival.atk, "the Dragon God outclasses %s's boss" % zone_id)
	# The fight itself, for the hero the field is made for: ★300, the 250★ set at +15.
	Game.new_profile(&"darklord", "Isle QA")
	var p := Game.profile
	p.level = 100
	p.adv = JobData.adv_for_level(100)
	var main := String(JobData.resolve(&"darklord", int(p.adv)).main)
	var points := Game.STAT_POINTS_PER_LEVEL * 99
	p.attrs = {"str": 0, "int": 0, "dex": 0, "vit": 0}
	p.attrs[main] = int(points * 2 / 3)
	p.attrs["vit"] = points - int(points * 2 / 3)
	var para := Game.paragon()
	para.level = 300
	var spend := 300
	for key in ["atk", "hp", "def", "crit"]:
		var put := mini(spend / 2 if key == "atk" else spend, int(Game.PARAGON_STATS[key][2]))
		para.alloc[key] = put
		spend -= put
	p.equip = {}
	for slot in SetGearData.SLOTS:
		var item := SetGearData.item("darklord", slot)
		item.plus = ItemData.MAX_PLUS
		p.equip[slot] = item
	var hero := HeroStats.compute(p)
	var basic := float(ours.hp) / HeroStats.mitigate(float(hero.atk), float(ours.def))
	var die := float(hero.max_hp) / HeroStats.mitigate(float(ours.atk), float(hero.def))
	var die_boss := float(hero.max_hp) / HeroStats.mitigate(float(god.atk) * 1.6, float(hero.def))
	check(basic > 110.0 and basic < 300.0, "a ★300 Dark Lord in the 250★ set +15 needs a farmable number of basic hits (%.0f)" % basic)
	check(die > 8.0 and die < 40.0, "the monsters can hurt that hero (%.1f hits to fall)" % die)
	check(die_boss > 3.0 and die_boss < 10.0, "the Dragon God's slam is deadly, not instant (%.1f hits to fall)" % die_boss)


func _boss_moves() -> void:
	var t := MonsterData.get_monster(SkyIsleData.BOSS)
	check(BossAttack.has_moves(t) and BossAttack.MOVES.has(String(t.behavior2)) and String(t.behavior) != String(t.behavior2), "two signature moves")
	check(bool(t.get("alternate", false)), "he uses both from the first slam")
	for move in [String(t.behavior), String(t.behavior2)]:
		check(BossAttack.title(move) != move and BossAttack.STYLE_COLORS.has(String(BossAttack.MOVES[move].style)), "%s has a Thai name and its own style" % move)
		for other in MonsterData.MONSTERS:
			var m: Dictionary = MonsterData.MONSTERS[other]
			check(String(m.get("behavior", "")) != move and String(m.get("behavior2", "")) != move, "%s is no other boss's move" % move)
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		var shots := BossAttack.plan(move, Vector3.ZERO, Vector3.RIGHT, Vector3(6, 0, 0), Vector3.ZERO, rng)
		check(shots.size() >= 9 and shots.size() <= 12, "%s is a big pattern inside the VFX budget (%d circles)" % [move, shots.size()])
		var waves := {}
		for shot in shots:
			waves[int(shot.wave)] = true
			check(float(shot.at) >= 0.9 and float(shot.dmg) <= 1.6 and float(shot.r) <= 3.2, "%s: a fair circle" % move)
		check(waves.size() >= 3, "%s lands in three or more waves" % move)
	var breath := BossAttack.plan("dragon_breath", Vector3.ZERO, Vector3.RIGHT, Vector3(6, 0, 0), Vector3.ZERO, RandomNumberGenerator.new())
	check(breath.any(func(s): return float(s.get("linger", 0.0)) > 0.0), "the breath leaves fire burning")
	check(float(BossAttack.MOVES.heavens_fall.slow) > 0.0, "heaven's lightning slows")


func _scenery() -> void:
	var layout := SkyIsleArt.layout()
	var z := ZoneData.get_zone(ID)
	check(layout.camp_positions.size() == z.camps.size(), "a spot for every camp")
	for i in layout.camp_positions.size():
		var p: Vector2 = layout.camp_positions[i]
		check(p.length() + 9.0 < 50.0, "camp %d inside the walkable disc" % i)
		check(p.length() + 10.0 < SkyIsleArt.edge(atan2(p.y, p.x)), "camp %d stands on the isle" % i)
		for j in i:
			check(p.distance_to(layout.camp_positions[j]) > 18.0, "camps %d and %d stand apart" % [i, j])
		check(p.distance_to(Vector2(layout.boss_pos.x, layout.boss_pos.z)) > 24.0, "camp %d keeps off the court" % i)
	# The rim: beyond the boundary wall everywhere but the bays, which stay off every way.
	var bay_samples := 0
	for step in 720:
		var a := TAU * float(step) / 720.0
		var r := SkyIsleArt.edge(a)
		check(r > 44.0 and r < 76.0, "the rim is sane at %.2f" % a)
		if r < 56.0:
			bay_samples += 1
			var at := Vector2(cos(a), sin(a)) * r
			check(StarRegionArt._path_distance(at, layout.paths) > 5.0, "a bay keeps off the ways at %.2f" % a)
	check(bay_samples > 40 and bay_samples < 240, "five sky bays cut the rim (%d of 720 samples)" % bay_samples)
	for key in ["spawn", "boss_pos"]:
		var q: Vector3 = layout[key]
		check(Vector2(q.x, q.z).length() + 6.0 < SkyIsleArt.edge(atan2(q.z, q.x)), "%s stands on the isle" % key)
	for path in layout.paths:
		for point in path:
			check((point as Vector2).length() < SkyIsleArt.edge(atan2(point.y, point.x)) - 3.0, "the ways stay on the isle")
	for q in [0, 1, 2]:
		GameSettings.quality = q
		var holder := Node3D.new()
		add_child(holder)
		SkyIsleArt.build(holder)
		var art := holder.get_child(0)
		check(art != null and art.get_meta("zone_id", &"") == ID and art.get_child_count() > 8, "q%d: the scenery builds" % q)
		check(art.find_children("*", "Light3D", true, false).is_empty() and art.find_children("*", "GPUParticles3D", true, false).is_empty() and art.find_children("*", "CPUParticles3D", true, false).is_empty(), "q%d: no lights or particles in the scenery" % q)
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
		print("ISLE ART q%d: %d draws, %d instances, %d triangles" % [q, draws, instances, triangles])
		check(draws <= 70, "q%d: %d draws (70 at most)" % [q, draws])
		check(instances > 1500 and instances <= 9000, "q%d: %d batched instances (9000 at most)" % [q, instances])
		check(triangles <= 200000, "q%d: %d triangles (200k at most)" % [q, triangles])
		check(art.get_node_or_null("SkyIsleGround") != null and art.get_node_or_null("SkyIsleCliff") != null and art.get_node_or_null("SkyBelow") != null, "q%d: ground, cliff and the sky below" % q)
		var falls := 0
		for node in art.get_children():
			if String(node.name).contains("Fall_"):
				falls += 1
		check(falls >= 12, "q%d: waterfalls off the bays, the rim and the isles (%d)" % [q, falls])
		# Solid scenery keeps off the ways, the spawn, the camps and the court.
		var body := art.get_node_or_null("StarSceneryCollision") as StaticBody3D
		check(body != null and body.get_child_count() > 40, "q%d: scenery colliders, bay fences included" % q)
		var blocked := 0
		if body:
			for shape in body.get_children():
				var s := shape as CollisionShape3D
				var xz := Vector2(s.position.x, s.position.z)
				var radius: float = (s.shape as CylinderShape3D).radius
				if StarRegionArt._path_distance(xz, layout.paths) < radius + 1.4:
					blocked += 1
				for camp in layout.camp_positions:
					if xz.distance_to(camp) < radius + 8.5:
						blocked += 1
				if xz.distance_to(Vector2(layout.spawn.x, layout.spawn.z)) < radius + 4.0 or xz.distance_to(Vector2(layout.boss_pos.x, layout.boss_pos.z)) < radius + 12.0:
					blocked += 1
		check(blocked == 0, "q%d: nothing solid on a way, a camp, the spawn or the court (%d)" % [q, blocked])
		# Every bay is fenced: a walker heading out over it meets a collider.
		if body:
			for bay in SkyIsleArt.BAYS:
				for offset in [-0.6, 0.0, 0.6]:
					var a: float = float(bay[0]) + float(bay[1]) * offset
					var lip := Vector2(cos(a), sin(a)) * (SkyIsleArt.edge(a) + 1.2)
					var fenced := false
					for shape in body.get_children():
						var s := shape as CollisionShape3D
						if Vector2(s.position.x, s.position.z).distance_to(lip) < (s.shape as CylinderShape3D).radius:
							fenced = true
					check(fenced, "q%d: the bay at %.2f is fenced" % [q, a])
		holder.free()
	GameSettings.quality = 1
	check(is_instance_valid(StarRegionArt._meshes.get("isle_roof")) and is_instance_valid(StarRegionArt._meshes.get("isle_dragon")), "the isle's shapes are cached once")
	check(SkyIsleArt._materials.size() <= 4, "four moving materials at most (%d)" % SkyIsleArt._materials.size())


func _triangles(mesh: Mesh) -> int:
	if mesh == null:
		return 0
	var total := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var index: Variant = arrays[Mesh.ARRAY_INDEX]
		if index != null and (index as PackedInt32Array).size() > 0:
			total += (index as PackedInt32Array).size() / 3
		else:
			total += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


## กิเลนเหยียบเมฆ: the code-sculpted kirin (Kirin, KirinVisual). One shared mesh inside the
## isle dragons' budget (lighter at quality 0), its own material, no lights, particles or
## textures; the gait, the horn charge, the flinch, the fall and the hit flash move its
## shader; it frees cleanly.
func _kirin() -> void:
	var t := MonsterData.get_monster(&"cloud_kirin")
	check(float(t.height) >= 2.4 and float(t.height) <= 3.0 and String(t.behavior) == "lunge" and String(t.attack) == "melee", "the kirin keeps its height band and its horn charge (lunge)")
	var saved := GameSettings.quality
	var tris := {}
	for q in [0, 1, 2]:
		GameSettings.quality = q
		tris[q] = _triangles(Kirin.mesh())
	check(tris[1] == tris[2] and tris[2] >= 1500 and tris[2] <= 2600, "q1-2: one kirin mesh about the dragons' budget (%d triangles)" % tris[2])
	check(tris[0] < tris[2] * 0.75 and tris[0] >= 900, "q0: a lighter kirin (%d triangles)" % tris[0])
	GameSettings.quality = saved
	check(not Kirin.SHADER.code.contains("sampler2D"), "the kirin's shader needs no texture")
	var holder := Node3D.new()
	add_child(holder)
	var a := CelestialDragonVisual.make(holder, t) as KirinVisual
	var b := CelestialDragonVisual.make(holder, t) as KirinVisual
	check(a != null and b != null, "the monster factory builds the kirin")
	if a == null or b == null:
		holder.free()
		return
	check(a.body_mesh.mesh == Kirin.mesh() and b.body_mesh.mesh == a.body_mesh.mesh and a.mat != b.mat and a.mat.shader == Kirin.SHADER, "two kirins share the mesh, each with its own material")
	check(is_equal_approx(a.height, float(t.height)) and Kirin.mesh().custom_aabb.has_volume(), "fitted to %.1f m, with room for its moves in its bounds" % float(t.height))
	DragonMonsterArt.attach(a, t)
	var aura := a.get_node_or_null("DragonAura")
	check(aura != null and aura.get_child_count() >= 3 and aura.get_child_count() <= 12, "it stands on its ring of light")
	check(a.find_children("*", "Light3D", true, false).is_empty() and a.find_children("*", "GPUParticles3D", true, false).is_empty() and a.find_children("*", "CPUParticles3D", true, false).is_empty(), "no lights or particles")
	var pf := func(key: String) -> float: return float(a.mat.get_shader_parameter(key))
	var clock0: float = pf.call("clock")
	a.play("run")
	await get_tree().create_timer(0.8).timeout
	check(pf.call("stride") > 0.3 and pf.call("gallop") > 0.3 and pf.call("stream") > 0.3 and pf.call("clock") > clock0 + 0.5, "it gallops: legs swing, mane and tail stream (stride %.2f)" % pf.call("stride"))
	a.play("idle")
	a.action("attack", 1200)
	await get_tree().create_timer(0.44).timeout
	check(pf.call("rear") > 0.4 and pf.call("tuck") > 0.6, "the charge: it rears, forehooves curled (rear %.2f)" % pf.call("rear"))
	await get_tree().create_timer(0.3).timeout
	check(pf.call("head_pitch") > 0.4 and pf.call("lunge") > 0.2 and pf.call("charge") > 0.6, "then plunges, head low, the horn alight (head %.2f)" % pf.call("head_pitch"))
	await get_tree().create_timer(0.6).timeout
	check(absf(pf.call("rear")) < 0.05 and absf(pf.call("lunge")) < 0.05 and absf(pf.call("head_pitch")) < 0.05, "and stands again")
	a.flash(Color(1, 0.3, 0.2), 0.3)
	check(pf.call("glow") > 0.4, "the hit flash lights it")
	a.action("hurt", 320)
	await get_tree().create_timer(0.09).timeout
	check(pf.call("rear") > 0.05, "it flinches")
	a.hold("die")
	await get_tree().create_timer(0.8).timeout
	check(pf.call("fold") > 0.9 and pf.call("roll") > 1.0 and a.current == "die", "it falls on its side, legs folded")
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) - 1 - holder.find_children("*", "", true, false).size()
	holder.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	check(not is_instance_valid(a) and int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) <= nodes, "the kirins free cleanly (%d -> %d nodes)" % [nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	check(Kirin.mesh() != null and _triangles(Kirin.mesh()) == tris[clampi(GameSettings.quality, 0, 2)], "the shared mesh outlives them")


## The zone as the game builds it: the hero arrives, the camps fill, the boss stands in
## his court, the signs hang, the weather blows, and leaving frees everything.
func _in_game() -> void:
	Game.new_profile(&"darklord", "Isle QA")
	Game.profile.level = 100
	Game.paragon()["level"] = 300
	var stats := Game.stats_now()
	Game.profile.hp = stats.max_hp
	Game.profile.mp = stats.max_mp
	Game.current_zone = ID
	var zone := Zone.new()
	zone.zone_id = ID
	add_child(zone)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(zone.hero != null and zone.get_node_or_null("SkyIsleArt") != null, "the zone builds the isle")
	var spawn: Vector3 = SkyIsleArt.layout().spawn
	check(zone.hero.global_position.distance_to(spawn) < 6.0, "the hero arrives on the terrace")
	check(zone.portals.size() == 1 and StringName(zone.portals[0].to) == DrownedAbyssData.ID, "one portal, back to the abyss")
	check(zone.npcs.any(func(n): return n.role == "warp"), "a warp crystal at the entrance")
	var mobs := get_tree().get_nodes_in_group("mobs")
	check(mobs.size() >= 40, "the camps are populated (%d)" % mobs.size())
	var kinds := {}
	for mob in mobs:
		kinds[(mob as Mob).monster_id] = true
		check(SkyIsleData.has_monster((mob as Mob).monster_id), "only dragons of the isle live here")
	check(kinds.size() >= 7, "every kind is about (%d)" % kinds.size())
	var kirins := mobs.filter(func(m): return (m as Mob).monster_id == &"cloud_kirin")
	check(not kirins.is_empty() and kirins.all(func(m): return (m as Mob).visual is KirinVisual and (m as Mob).visual.body_mesh.mesh == Kirin.mesh()), "the kirin camp is the sculpted kirin, one shared mesh (%d)" % kirins.size())
	var texts := []
	for node in zone.find_children("*", "Label3D", true, false):
		texts.append((node as Label3D).text)
	check(texts.any(func(t): return String(t).contains("ดรอป") and String(t).contains("อาวุธเทพมังกร") and String(t).contains("300")), "the entrance sign names the drops and the stars")
	check(texts.any(func(t): return String(t).contains("ลานศาลเทพมังกร")), "the court carries its name")
	check(zone.get_node_or_null("Weather") != null, "the wind blows leaves across it")
	check(zone.find_children("*", "OmniLight3D", true, false).is_empty() and zone.find_children("*", "SpotLight3D", true, false).is_empty(), "no local lights")
	zone.queue_free()
	await zone.tree_exited
	await get_tree().process_frame
	check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "leaving the isle releases its temporary art")
