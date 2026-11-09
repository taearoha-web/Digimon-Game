extends Node3D
## The world's props and foliage (PropDressing, Scenery's grass, bushes and flowers):
##   - their density follows the quality setting: fewer at quality 0, the most at 2
##   - hunting field props keep off the trail, the camps, the portals and the boss spot
##   - the guild war's grass, flowers, torches, racks and banners keep off the camps and
##     their roads, the plaza, the gates' approaches, the switch circle and the altar
##   - the village's street props keep off every villager, the spot in front of them,
##     every stall, the plaza and the gate, and off every collider (walls, buildings)
##   - the Drowned Abyss's shells and starfish keep off its paths, camps and spawn
##   - none of it has a collider
## godot --headless --path . res://tests/integration/prop_dressing_test.tscn
var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


## Where every prop under `root` stands (x, z), from the placements PropDressing.place
## records (a headless server keeps no MultiMesh data). Every holder sits at the origin.
func _origins(root: Node) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for node in root.find_children("*", "MultiMeshInstance3D", true, false):
		if node.is_in_group(PropDressing.GROUP):
			out.append_array(Array(node.get_meta("spots", PackedVector2Array())))
	return out


func _inside(points: Array[Vector2], circles: Array) -> int:
	var bad := 0
	for p in points:
		for c in circles:
			if p.distance_to(Vector2(c.x, c.y)) < float(c.z):
				bad += 1
				break
	return bad


func _no_colliders(root: Node, label: String) -> void:
	var bodies := 0
	for node in root.find_children("*", "CollisionObject3D", true, false):
		bodies += 1
	check(bodies == 0, "%s: props and foliage carry no colliders (%d)" % [label, bodies])


## A hunting field's clear circles as Zone._build_field makes them (trail, camps, portals).
func _field_clear(radius: float) -> Array[Vector3]:
	var data := ZoneData.get_zone(&"meadow")
	var start := Vector3(-radius + 8.0, 0, 0)
	var clear: Array[Vector3] = [Vector3(start.x, start.z, 6.0), Vector3(radius - 8.0, 0, 6.0), Vector3(30, 26, 9.0)]
	var path := PackedVector2Array([Vector2(-radius, 0), Vector2(-20, 4), Vector2(0, -2), Vector2(26, 6), Vector2(radius, 0)])
	for i in path.size() - 1:
		for t in 8:
			var p := path[i].lerp(path[i + 1], t / 8.0)
			clear.append(Vector3(p.x, p.y, 2.2))
	for c in data.camps:
		clear.append(Vector3(c.pos.x, c.pos.y, float(c.radius) + 2.0))
	return clear


func _field(quality: int) -> Dictionary:
	GameSettings.quality = quality
	var node := Node3D.new()
	add_child(node)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var radius := 82.0
	var clear := _field_clear(radius)
	await Scenery.populate(node, &"meadow", rng, radius, clear, 1.0, false)
	WorldArt.region_edges(node, &"meadow", radius, 5, clear, true)
	var props := _origins(node)
	var grass := 0
	for mmi in node.get_node("Grass").get_children():
		grass += (mmi as MultiMeshInstance3D).multimesh.instance_count
	var out := {"props": props.size(), "grass": grass, "bad": _inside(props, clear)}
	var holder := node.get_node_or_null("PropDressing")
	if holder:
		_no_colliders(holder, "field q%d" % quality)
	node.free()
	return out


func _ready() -> void:
	Game.set_process(false)
	GameSettings.load_settings()
	Game.new_profile(&"warrior", "Props QA")
	# Hunting field: density by quality, and nothing on the trail or in a camp.
	var by_q: Array = []
	for q in 3:
		var r: Dictionary = await _field(q)
		by_q.append(r)
		check(int(r.bad) == 0, "field q%d: no prop on the trail, a camp, a portal or the boss spot (%d)" % [q, r.bad])
	check(by_q[0].props < by_q[1].props and by_q[1].props < by_q[2].props, "field props grow with quality %s" % [by_q.map(func(r): return r.props)])
	check(by_q[0].grass < by_q[1].grass and by_q[1].grass < by_q[2].grass, "field grass grows with quality %s" % [by_q.map(func(r): return r.grass)])
	check(by_q[0].props >= 20, "quality 0 still dresses the field a little (%d)" % by_q[0].props)
	# The guild war's castle field.
	for q in [0, 2]:
		GameSettings.quality = q
		var siege := Node3D.new()
		add_child(siege)
		var rng := RandomNumberGenerator.new()
		rng.seed = 41
		SiegeArena.build(siege, rng, [Color("c83a3a"), Color("2f4f8a"), Color("e8c050"), Color("4a8f5c")])
		var holder := siege.get_node("Siege/PropDressing")
		var all := _origins(holder)
		var excl := PropDressing.siege_exclusions(4)
		check(_inside(all, excl) == 0, "guild war q%d: no grass, flower, torch, rack or banner on a camp, road, the plaza, a gate, the switch or the altar (%d of %d)" % [q, _inside(all, excl), all.size()])
		check(all.size() > 10, "guild war q%d: props are placed (%d)" % [q, all.size()])
		var near_switch := 0
		for p in all:
			if p.distance_to(Vector2(SiegeArena.SWITCH.x, SiegeArena.SWITCH.z)) < SiegeArena.SWITCH_RADIUS + 1.0 or p.distance_to(Vector2(SiegeArena.ALTAR.x, SiegeArena.ALTAR.z)) < SiegeArena.ALTAR_RADIUS + 1.0:
				near_switch += 1
		check(near_switch == 0, "guild war q%d: the switch circle and the altar stay bare" % q)
		var kinds := {}
		for node in holder.get_children():
			if node.is_in_group(PropDressing.GROUP):
				kinds[node.get_meta("prop_kind")] = true
		check(kinds.has("torch") and kinds.has("weapon_rack") and kinds.has("war_banner"), "guild war q%d: torches, weapon racks and guild banners (%s)" % [q, kinds.keys()])
		_no_colliders(holder, "guild war q%d" % q)
		siege.free()
	# The Drowned Abyss: shells and starfish off the paths, camps and spawn (read from
	# the batches PropDressing.abyss queues).
	GameSettings.quality = 1
	var c := {"batches": {}, "colliders": []}
	PropDressing.abyss(c)
	var sea := 0
	var bad_sea := 0
	for key in c.batches:
		for xf in c.batches[key].transforms:
			sea += 1
			if not DrownedAbyssArt._clear((xf as Transform3D).origin, 0.0):
				bad_sea += 1
	check(sea > 40 and bad_sea == 0, "abyss: shells, starfish, grass and coral (%d) keep off its paths and camps (%d)" % [sea, bad_sea])
	var lotus := {"batches": {}, "colliders": []}
	PropDressing.lotus(lotus)
	var petals: int = lotus.batches.get("divine_petal:solid", {"transforms": []}).transforms.size()
	check(petals > 40 and lotus.colliders.is_empty(), "lotus: fallen petals (%d), no colliders" % petals)
	# The village at the phone default: street props off the villagers, stalls and walls.
	GameSettings.quality = 1
	Game.current_zone = &"town"
	var zone := Zone.new()
	zone.zone_id = &"town"
	zone.layout_seed = 88
	add_child(zone)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var holder := zone.get_node("PropDressing")
	var street := _origins(holder)
	check(street.size() >= 15, "village: street props are placed (%d)" % street.size())
	var keep_off: Array = []
	for npc in zone.npcs:
		if npc is NoticeBoard or npc.role == "warp" or npc.visual == null:
			continue
		var front := Vector3(sin(npc.visual.rotation.y), 0, cos(npc.visual.rotation.y))
		for spot in [npc.global_position, npc.global_position + front * 2.0]:
			keep_off.append(Vector3(spot.x, spot.z, 2.0))
	for stall in JapanVillage.STALLS:
		keep_off.append(Vector3(stall.x, stall.z, 2.0))
	keep_off.append(Vector3(0, 0, JapanVillage.PLAZA_RADIUS))
	keep_off.append(Vector3(JapanVillage.GATE.x, JapanVillage.GATE.z, 6.0))
	check(_inside(street, keep_off) == 0, "village: no prop on a villager, the spot in front of them, a stall, the plaza or the gate (%d)" % _inside(street, keep_off))
	var boxes := PropDressing._collider_boxes(zone.get_node("Village"))
	var in_wall := 0
	for p in street:
		if p.distance_to(Vector2(JapanVillage.POND.x, JapanVillage.POND.z)) < 8.0:
			continue
		if not PropDressing.clear_of_boxes(p, 0.3, boxes):
			in_wall += 1
	check(in_wall == 0, "village: no street prop inside a wall, building or booth (%d)" % in_wall)
	_no_colliders(holder, "village")
	print("prop_dressing_test: %d checks, %d failures" % [checks, failures])
	if failures == 0:
		print("PASS")
	get_tree().quit(1 if failures > 0 else 0)
