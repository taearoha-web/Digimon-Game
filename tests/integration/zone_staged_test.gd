extends Node
## A zone built in slices (Main.go: behind the fade, no long freeze) must come out the
## same as one built in a single go, and the indexed ground mesh must keep the exact
## triangle grid and terrain attributes of the old per-corner build.
## godot --headless --path . res://tests/integration/zone_staged_test.tscn
var failures: Array[String] = []
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)


func _build(zone_id: StringName, staged: bool) -> Dictionary:
	Game.current_zone = zone_id
	var zone := Zone.new()
	zone.zone_id = zone_id
	zone.staged = staged
	var frame0 := Engine.get_process_frames()
	add_child(zone)
	if staged:
		check(not zone.is_built, "%s: a staged zone is not finished when it enters the tree" % zone_id)
		if not zone.is_built:
			await zone.built
	check(zone.is_built and zone.hero != null, "%s: finished zone has its hero (staged=%s)" % [zone_id, staged])
	var info := {"frames": Engine.get_process_frames() - frame0, "portals": zone.portals.size(),
		"camps": zone._camps.size(), "mobs": get_tree().get_nodes_in_group("mobs").size(),
		"ground": zone.get_node_or_null("Ground") != null, "colliders": zone.get_node_or_null("Colliders") != null}
	zone.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	return info


## A NaN position on the monster the camera leans towards (or on any monster) must not
## leave the camera at NaN: the world then vanished behind the fog colour for good.
func _nan_guard() -> void:
	Game.current_zone = &"dark_forest"
	var zone := Zone.new()
	zone.zone_id = &"dark_forest"
	add_child(zone)
	var rig: ThirdPersonCamera = zone.camera_rig
	var broken := Node3D.new()
	zone.add_child(broken)
	broken.global_position = Vector3(NAN, 0.0, NAN)
	rig.combat_focus = broken
	for i in 10:
		await get_tree().physics_frame
	check(rig.global_position.is_finite(), "camera stays finite with a NaN combat focus (%s)" % rig.global_position)
	rig.global_position = Vector3(NAN, NAN, NAN)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(rig.global_position.is_finite(), "a NaN camera recovers onto the hero (%s)" % rig.global_position)
	var mob: Mob = get_tree().get_nodes_in_group("mobs")[0]
	mob.global_position = Vector3(NAN, 0.0, NAN)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(mob.global_position.is_finite(), "a monster with a NaN position goes back home (%s)" % mob.global_position)
	zone.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _ready() -> void:
	Game.set_process(false)
	Game.new_profile(&"warrior", "Staged")
	Game.profile.level = 60
	for zone_id in [&"town", &"meadow"]:
		var sync: Dictionary = await _build(zone_id, false)
		var sliced: Dictionary = await _build(zone_id, true)
		check(int(sync.frames) == 0, "%s: an unstaged zone is complete within add_child" % zone_id)
		check(int(sliced.frames) > 0, "%s: a staged zone spreads over several frames" % zone_id)
		for key in ["portals", "camps", "ground", "colliders"]:
			check(sync[key] == sliced[key], "%s: staged and unstaged agree on %s (%s vs %s)" % [zone_id, key, sync[key], sliced[key]])
		if zone_id != &"town":
			check(int(sliced.mobs) > 0 and absi(int(sync.mobs) - int(sliced.mobs)) <= 2, "%s: both builds spawn the camps' monsters (%s vs %s)" % [zone_id, sync.mobs, sliced.mobs])
	await _nan_guard()
	# Ground: an indexed 104 x 104 grid, two triangles per cell, flat, with terrain data in UV/UV2.
	var holder := Node3D.new()
	add_child(holder)
	Scenery.ground(holder, 130.0, Color("607f61"), Color("779265"), 5, Color("c5b394"),
			[PackedVector2Array([Vector2(-130, 0), Vector2(0, 0), Vector2(130, 10)])], 2.8, [Vector3(30, 20, 12)], &"meadow")
	var mesh := (holder.get_node("Ground") as MeshInstance3D).mesh as ArrayMesh
	var arrays := mesh.surface_get_arrays(0)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	check(indices.size() / 3 == 104 * 104 * 2, "ground keeps 104 x 104 x 2 triangles (%d)" % [indices.size() / 3])
	check(verts.size() == 105 * 105, "ground shares its 105 x 105 grid vertices (%d)" % verts.size())
	var flat := true
	for v in verts:
		flat = flat and is_zero_approx(v.y)
	check(flat, "ground stays flat")
	var up := true
	for tri in range(0, indices.size(), 3):
		var a := verts[indices[tri]]
		var b := verts[indices[tri + 1]]
		var c := verts[indices[tri + 2]]
		up = up and (b - a).cross(c - a).y < 0.0  # Godot's front faces are clockwise
	check(up, "every ground triangle faces up (same winding as before)")
	# A vertex on the trail has ~0 path distance, one in the clearing has mask ~1, a far one neither.
	var step := 260.0 / 104.0
	var on_trail := (52) * 105 + 52  # x = 0, z = 0
	check(uv2[on_trail].x < 0.01, "path distance is ~0 on the trail (%f)" % uv2[on_trail].x)
	var clearing_node := int(round((30.0 + 130.0) / step)) * 105 + int(round((20.0 + 130.0) / step))
	check(uv2[clearing_node].y > 0.9, "clearing mask is ~1 at the clearing centre (%f)" % uv2[clearing_node].y)
	check(uv2[0].x > 20.0 and uv2[0].y == 0.0, "a corner far from trail and clearing has neither")
	print("zone_staged_test: %d checks, %d failures" % [checks, failures.size()])
	if failures.is_empty():
		print("PASS")
	get_tree().quit(1 if failures.size() > 0 else 0)
