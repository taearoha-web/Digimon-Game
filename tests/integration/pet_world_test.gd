extends Node
## Everyone's pets (PetCrowd, PetFollower, Pet in lite form, Online "pet"): every AI
## player has a pet picked from its name (the same on every device, the three spread
## evenly), shown in its member sheet; in the village the nearest players' pets follow
## them (cheap followers: shared meshes, no lights, particles, labels or colliders, not
## drawn far away, at most PetCrowd.cap() out, fewer under memory pressure, the hero's
## party first); in a field a world player's pet fights along at its owner's level; a real
## online player's pet comes from its state (validated) and follows its RemotePlayer;
## nobody's pet comes into the guild war; no nodes leak over zone changes.
##   XDG_DATA_HOME=/tmp/x godot --headless --audio-driver Dummy --path . res://tests/integration/pet_world_test.tscn
var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


## The nodes that stay: everything in the tree but the short-lived effects of the fight
## still going on in the field (meshes, particles and class signature flashes come and go
## with each swing, so counting them reads the fight, not a leak).
func _lasting_nodes() -> int:
	var n := 0
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var script: Script = node.get_script()
		if script != null and script.resource_path.get_file() == "signature_kit.gd":
			continue
		if node is MeshInstance3D or node is CPUParticles3D or node is GPUParticles3D or node is MultiMeshInstance3D:
			continue
		n += 1
		stack.append_array(node.get_children())
	return n


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _ready() -> void:
	Game.set_process(false)
	GameSettings.load_settings()
	GameSettings.quality = 2
	WorldPlayers.persist = false
	WorldPresence.enabled = true
	GameSettings.show_world_players = true
	# Day 60 of the world: a full village, and a field (the drowned abyss) with hunters.
	WorldPresence.clock_offset = float(WorldPlayers.START_UNIX) + 60.0 * 86400.0 - WorldPlayers.now()
	Game.new_profile(&"warrior", "เพื่อนสัตว์", FaceKit.default_look())
	Game.profile.level = 100
	Game.profile.flags[Tutorial.FLAG] = Tutorial.DONE
	Game.choose_pet("earth")
	_deterministic()
	_online_state()
	var counts: Array[int] = []
	for round in 2:
		await _village(round == 0)
		await _field(round == 0)
		await wait(0.3)
		counts.append(_lasting_nodes())
		check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == 0, "no orphan nodes after a zone change (round %d)" % round)
	check(counts[1] <= counts[0] + 20, "no nodes leak over zone changes (%s)" % str(counts))
	check(get_tree().get_nodes_in_group("pet_followers").is_empty() and get_tree().get_nodes_in_group("ai_pets").is_empty(), "no pet is left once the zone is gone")
	await _guild_war()
	print("PET WORLD TEST: %d checks, %d failures" % [checks, failures])
	if failures == 0:
		print("PASS")
	get_tree().quit(1 if failures > 0 else 0)


## Every AI player's pet: from its name, the same on every device, evenly spread.
func _deterministic() -> void:
	var count := {"fire": 0, "water": 0, "earth": 0}
	var first: Array[String] = []
	var n := WorldPlayers.size()
	for i in n:
		var m := WorldPlayers.member(i, WorldPresence.clock())
		var id := String(m.get("pet", ""))
		check(PetData.exists(id) and id == WorldPlayers.pet_of(i) and id == PetData.of_player(String(m.name)), "%s has a pet (%s)" % [m.name, id])
		count[id] = int(count.get(id, 0)) + 1
		first.append(id)
	for id in PetData.ORDER:
		var share := float(count[id]) / float(n)
		check(share > 0.25 and share < 0.42, "%s pets: %d of %d players (an even spread)" % [id, count[id], n])
	print("pet_world_test: %d players, pets %s" % [n, str(count)])
	# Another device works the world out again from nothing: the same pets.
	WorldPlayers.reset_roster()
	WorldPlayers.size()
	var same := true
	for i in n:
		same = same and WorldPlayers.pet_of(i) == first[i]
	check(same, "the same pets after the world is worked out again (another device)")
	check(PetData.of_player("Kaito") == PetData.of_player("Kaito") and PetData.of_player("") == "", "a name always gives the same pet; no name, no pet")


## The online state: the hero's pet goes out with hello / look, others' are validated.
func _online_state() -> void:
	check(String(Online._hello().get("pet", "x")) == "earth", "the hello carries the hero's pet")
	var p := Online._norm_player({"id": "77", "name": "Real", "pet": "water"})
	check(String(p.pet) == "water", "a player's pet comes through")
	for bad in ["dragon", 5, ["fire"], {"id": "fire"}, null]:
		check(String(Online._norm_player({"id": "78", "pet": bad}).pet) == "", "a bad pet (%s) shows none" % str(bad))
	Online._merge(p, {"pet": "fire"})
	check(String(p.pet) == "fire", "a look with a new pet updates it")


func _zone(id: StringName) -> Zone:
	Game.current_zone = id
	var zone := Zone.new()
	zone.zone_id = id
	add_child(zone)
	while not zone.is_built:
		await get_tree().process_frame
	return zone


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## The village: the nearest players' pets follow them; cheap; capped.
func _village(full: bool) -> void:
	var town: Zone = await _zone(&"town")
	for i in 120:
		await get_tree().physics_frame
	var crowd := town.pet_crowd
	check(crowd != null, "the village has a pet crowd")
	if crowd == null:
		town.queue_free()
		return
	var hero := town.hero
	var players: Array = get_tree().get_nodes_in_group("world_players")
	check(players.size() >= 10, "the village shows players (%d)" % players.size())
	# Stand among them, so many are near.
	var middle := Vector3.ZERO
	for p in players:
		middle += (p as Node3D).global_position
	middle /= maxf(1.0, float(players.size()))
	hero.global_position = Vector3(middle.x, hero.global_position.y, middle.z)
	crowd._release_all()
	crowd.refresh(true)
	await wait(0.5)
	crowd.refresh(true)
	var out := crowd.out_count()
	var followers := get_tree().get_nodes_in_group("pet_followers").filter(func(f): return (f as Node3D).visible)
	check(out > 0 and out <= PetCrowd.cap() and followers.size() == out, "pets follow the nearest players (%d out, cap %d)" % [out, PetCrowd.cap()])
	check(get_tree().get_nodes_in_group("ai_pets").is_empty(), "nobody's pet fights in the village")
	# The CAP nearest within VIEW have their pet; nobody beyond HIDE does.
	var near: Array = players.filter(func(p): return (p as Node3D).visible and _flat((p as Node3D).global_position, hero.global_position) <= PetCrowd.VIEW)
	near.sort_custom(func(a, b): return _flat(a.global_position, hero.global_position) < _flat(b.global_position, hero.global_position))
	var nearest_ok := true
	for k in mini(PetCrowd.cap(), near.size()):
		nearest_ok = nearest_ok and crowd.pet_for(near[k]) != null
	check(nearest_ok, "the %d nearest players have their pet out" % mini(PetCrowd.cap(), near.size()))
	for p in players:
		if _flat((p as Node3D).global_position, hero.global_position) > PetCrowd.HIDE:
			check(crowd.pet_for(p) == null, "%s beyond %d m shows no pet" % [p.member.name, int(PetCrowd.HIDE)])
	# Each pet is its owner's (the pet from its name) and walks with it.
	var shared := {}
	for p in players:
		var f := crowd.pet_for(p) as PetFollower
		if f == null:
			continue
		check(f.pet_id == String(p.member.pet) and f.owner_node == p, "%s walks with its %s" % [p.member.name, f.pet_id])
		check(_flat(f.global_position, p.global_position) < PetFollower.TELEPORT, "%s's pet stays by it" % p.member.name)
		check(f.find_children("*", "CPUParticles3D", true, false).is_empty() and f.find_children("*", "GPUParticles3D", true, false).is_empty()
			and f.find_children("*", "Light3D", true, false).is_empty() and f.find_children("*", "Label3D", true, false).is_empty()
			and f.find_children("*", "CollisionObject3D", true, false).is_empty(), "%s's pet is cheap: no particles, lights, labels or colliders" % p.member.name)
		for mi in f.visual.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			check(m.visibility_range_end > 0.0 and m.visibility_range_end <= PetCrowd.HIDE and m.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s's pet is not drawn far away and casts no shadow" % p.member.name)
			var key := "%s|%s" % [f.pet_id, m.name]
			if shared.has(key):
				check(shared[key] == m.mesh, "pets of one kind share their mesh (%s)" % key)
			shared[key] = m.mesh
	# A player walks off: its pet follows (walk), then idles by it.
	var walker: FieldPlayer = null
	for p in players:
		if crowd.pet_for(p) != null:
			walker = p
			break
	if walker:
		var f := crowd.pet_for(walker) as PetFollower
		# (A party member keeps its pet out wherever it walks: no crowd ranking in the way.)
		town.companions.append(walker)
		walker.set_physics_process(false)
		walker.global_position += Vector3(5, 0, 0)
		await wait(0.25)
		check(f.visual.current in ["walk", "run"], "the pet walks after its owner (%s)" % f.visual.current)
		await wait(2.5)
		check(_flat(f.global_position, walker.global_position) < 2.6 and f.visual.current == "idle", "it catches up and idles by its owner (%.1f m, %s)" % [_flat(f.global_position, walker.global_position), f.visual.current])
		walker.set_physics_process(true)
		town.companions.erase(walker)
	# Memory pressure: fewer pets out; the spares are kept, not rebuilt.
	MemoryGuard.pressure = 2
	crowd.refresh(true)
	check(crowd.out_count() <= int(PetCrowd.PRESSURE_CAPS[1]), "under memory pressure at most %d pets (%d)" % [PetCrowd.PRESSURE_CAPS[1], crowd.out_count()])
	var spares := 0
	for id in crowd._spares:
		spares += (crowd._spares[id] as Array).size()
	check(spares > 0 and spares <= PetCrowd.SPARES * 3, "put-away pets wait as spares (%d)" % spares)
	MemoryGuard.pressure = 0
	var nodes_before := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	crowd.refresh(true)
	crowd.refresh(true)
	await get_tree().process_frame
	check(crowd.out_count() == out or crowd.out_count() >= mini(PetCrowd.cap(), near.size()), "back to the full crowd (%d)" % crowd.out_count())
	print("pet_world_test: village %d players, %d pets out, nodes %d -> %d after handing spares out again" % [players.size(), crowd.out_count(), nodes_before, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	# A real online player shows the pet its state carries; none without one.
	var remote := RemotePlayer.new()
	remote.setup({"id": "901", "name": "RealOne", "pet": "water", "pos": [hero.global_position.x + 2.0, hero.global_position.y, hero.global_position.z + 1.0], "look": {"class": "mage"}})
	remote.hero = hero
	town.add_child(remote)
	var bare := RemotePlayer.new()
	bare.setup({"id": "902", "name": "NoPet", "pet": "", "pos": [hero.global_position.x - 2.0, hero.global_position.y, hero.global_position.z], "look": {"class": "mage"}})
	bare.hero = hero
	town.add_child(bare)
	await get_tree().process_frame
	crowd.refresh(true)
	var rp := crowd.pet_for(remote) as PetFollower
	check(rp != null and rp.pet_id == "water" and rp.owner_node == remote, "a real player's pet follows its RemotePlayer")
	check(crowd.pet_for(bare) == null, "a real player without a pet shows none")
	if full and rp != null:
		remote.player["pet"] = "fire"
		crowd.refresh(true)
		var again := crowd.pet_for(remote) as PetFollower
		check(again != null and again.pet_id == "fire", "a new pet in the state shows at once")
	remote.queue_free()
	bare.queue_free()
	await get_tree().process_frame
	crowd.refresh(true)
	# The hero's party comes first, whatever the distance.
	if full:
		var far_one: FieldPlayer = null
		for p in players:
			if _flat(p.global_position, hero.global_position) > PetCrowd.VIEW + 5.0:
				far_one = p
		if far_one != null:
			town.companions.append(far_one)
			crowd.refresh(true)
			check(crowd.pet_for(far_one) != null, "a party member's pet is always out")
			town.companions.erase(far_one)
	# The hero's own pet still walks with the hero (not one of the crowd's).
	check(is_instance_valid(town.pet) and town.pet.is_in_group("pets") and not town.pet.lite, "the hero's own pet is out as before")
	town.queue_free()
	await wait(0.3)


## A field: the world players' pets fight along, at their owner's level.
func _field(full: bool) -> void:
	var field: Zone = await _zone(&"drowned_abyss")
	for i in 150:
		await get_tree().physics_frame
	var crowd := field.pet_crowd
	var hunters: Array = get_tree().get_nodes_in_group("world_players").filter(func(p): return (p as Node3D).visible)
	check(crowd != null and hunters.size() > 0, "a field with hunters (%d)" % hunters.size())
	if crowd == null or hunters.is_empty():
		field.queue_free()
		return
	var owner: FieldPlayer = hunters[0]
	field.hero.global_position = owner.global_position + Vector3(3, 0, 0)
	crowd.refresh(true)
	var pet := crowd.pet_for(owner) as Pet
	check(pet != null and pet.lite and pet.is_in_group("ai_pets") and not pet.is_in_group("pets") and pet.summoner == owner, "a hunter's pet fights along (lite Pet)")
	if pet == null:
		field.queue_free()
		return
	await wait(1.2)
	var want := PetData.stats_for(pet.pet_id, owner.stats, int(owner.member.level))
	check(int(pet.pstats.level) == int(owner.member.level) and is_equal_approx(float(pet.pstats.atk), float(want.atk)) and pet.max_hp == int(want.max_hp), "its power follows its owner's level and stats (Lv.%d, ATK %.0f)" % [pet.pstats.level, pet.pstats.atk])
	check(pet.find_children("*", "Label3D", true, false).is_empty() and pet.find_children("*", "Light3D", true, false).is_empty(), "a lite pet has no name tag and no light")
	check(not pet.is_in_group("summons") and pet.find_children("*", "FieldHpBar", true, false).is_empty(), "monsters leave a lite pet alone (not a summon, no health bar)")
	check(field.pet != null and not field.pet.lite and get_tree().get_nodes_in_group("pets").size() == 1, "the hero's own pet is the only one in \"pets\"")
	if full:
		# A monster by the owner: the pet hits it.
		var mob: Mob = null
		var best := 1.0e9
		for node in get_tree().get_nodes_in_group("mobs"):
			var m := node as Mob
			if m and not m.is_dead():
				var d := _flat(m.global_position, owner.global_position)
				if d < best:
					best = d
					mob = m
		if mob:
			owner.set_physics_process(false)
			owner.global_position = mob.global_position + Vector3(2.0, 0, 0)
			field.hero.global_position = owner.global_position + Vector3(4, 0, 0)
			mob.stats["hp"] = 1.0e9
			mob.hp = 100000000
			mob.max_hp = 100000000
			for k in 16:
				await wait(0.5)
				if pet.dealt > 0:
					break
			check(pet.dealt > 0, "the hunter's pet fights the monster by its owner (%d damage)" % pet.dealt)
			owner.set_physics_process(true)
	var out := crowd.out_count()
	check(out <= PetCrowd.cap(), "at most %d pets out in the field (%d)" % [PetCrowd.cap(), out])
	field.queue_free()
	await wait(0.3)


## The guild war: nobody's pet (players fight on their own there).
func _guild_war() -> void:
	var war: Zone = await _zone(&"guildwar")
	await wait(1.5)
	check(war.pet == null and war.pet_crowd == null, "no pet and no pet crowd in the guild war")
	var pets := get_tree().get_nodes_in_group("pets").size() + get_tree().get_nodes_in_group("ai_pets").size() + get_tree().get_nodes_in_group("pet_followers").size()
	check(pets == 0 and get_tree().get_nodes_in_group("gw_fighters").size() > 0, "the fighters fight without pets (%d pets, %d fighters)" % [pets, get_tree().get_nodes_in_group("gw_fighters").size()])
	war.queue_free()
	await wait(0.3)
