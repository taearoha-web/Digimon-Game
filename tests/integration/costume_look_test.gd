extends Node
## The reward-shop costumes' own pieces (CostumeArt on HeroVisual): every costume builds
## its parts on the bones it names, the kitsune has its nine tails, gear wings shorten the
## back (no costume wings, a capelet for a long cape), the motes follow the quality, the
## memory pressure and the cheap crowd dressing (decor_light), the silhouettes stay on the
## crowd, meshes and materials are shared between wearers, nothing casts a shadow, and
## taking a costume off (or freeing the body) leaves no node behind.
##   godot --headless --path . res://tests/integration/costume_look_test.tscn
var failures := 0
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _ready() -> void:
	GameSettings.load_settings()
	GameSettings.quality = 2
	MemoryGuard.pressure = 0
	_catalogue()
	await _pieces()
	await _wings()
	await _motes()
	await _leaks()
	_cost()
	GameSettings.quality = 2
	MemoryGuard.pressure = 0
	print("COSTUME LOOK: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _visual(id: String, cls := &"warrior", equip := {}, light := false, gender := 0) -> HeroVisual:
	var v := HeroVisual.new()
	v.costume = id
	v.decor_light = light
	add_child(v)
	var look := FaceKit.default_look()
	look["gender"] = gender
	v.setup(cls, "", true, equip, look)
	return v


## The costume's attach nodes on a body: name -> BoneAttachment3D.
func _attached(v: HeroVisual) -> Dictionary:
	var out := {}
	for node in v.find_children("ChibiCostume*", "BoneAttachment3D", true, false):
		out[String(node.name)] = node
	return out


func _motes_of(v: HeroVisual) -> Array:
	return v.find_children("CostumeMotes", "MeshInstance3D", true, false)


func _catalogue() -> void:
	for id in RewardShop.COSTUMES:
		check(not CostumeArt.parts(String(id)).is_empty(), "costume %s has pieces of its own" % id)
		check(String(RewardShop.COSTUMES[id].get("desc", "")) != "", "costume %s names its pieces on the shop card" % id)
		var bones := []
		for spec in CostumeArt.parts(String(id)):
			bones.append(String(spec[0]))
		check(bones.has("Head") and bones.size() >= 2, "costume %s dresses the head and at least one more bone (%s)" % [id, bones])
	var tails := CostumeArt.mesh_of("kitsune", "tails", false)
	check(tails != null and int(tails.get_meta("sweeps", 0)) == 9, "the kitsune has nine tails (%d)" % (int(tails.get_meta("sweeps", 0)) if tails else -1))
	var horns := CostumeArt.mesh_of("shadow", "head", false)
	check(horns != null and int(horns.get_meta("sweeps", 0)) == 2, "the shadow demon has two horns")
	check(CostumeArt.mesh_of("shadow", "tail", false) != null and int(CostumeArt.mesh_of("shadow", "tail", false).get_meta("sweeps", 0)) == 1, "and one tail")
	check(CostumeArt.mesh_of("kitsune", "tails", false) == tails, "a part's mesh is built once and shared")


func _pieces() -> void:
	for id in RewardShop.COSTUMES:
		var v := _visual(String(id))
		await get_tree().process_frame
		var got := _attached(v)
		for spec in CostumeArt.parts(String(id)):
			var bone := String(spec[0])
			var part := String(spec[1])
			var node_name := "ChibiCostume" if part == "head" else "ChibiCostume_" + part
			var attach := got.get(node_name) as BoneAttachment3D
			check(attach != null and attach.bone_name == bone, "%s: %s on bone %s" % [id, node_name, bone])
			if attach == null:
				continue
			var meshes := attach.find_children("*", "MeshInstance3D", true, false)
			check(meshes.size() == 1, "%s %s: one mesh (%d)" % [id, part, meshes.size()])
			for mi in meshes:
				var m := mi as MeshInstance3D
				check(m.mesh != null and m.mesh.get_surface_count() >= 1 and m.mesh.get_surface_count() <= 4, "%s %s: 1-4 surfaces" % [id, part])
				check(m.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and bool(m.get_meta("no_shadow_lod", false)), "%s %s: casts no shadow, even after the distance LOD" % [id, part])
				for i in m.mesh.get_surface_count():
					var mat := m.get_surface_override_material(i) as ShaderMaterial
					check(mat != null and mat.shader != null, "%s %s: costume shader on surface %d" % [id, part, i])
		check(got.size() == CostumeArt.parts(String(id)).size(), "%s: nothing more than its parts (%d)" % [id, got.size()])
		# The distance LOD keeps the silhouette: the pieces are no far decoration.
		for attach in got.values():
			check(not bool((attach as Node).get_meta("far_decor", false)), "%s: %s stays on far players" % [id, (attach as Node).name])
		v.queue_free()
		await get_tree().process_frame
	# Sway runs in the shader: the tails and capes carry sway data and amplitudes.
	var kit := _visual("kitsune")
	var tails_mi := kit.find_child("Costume_tails", true, false) as MeshInstance3D
	check(tails_mi != null, "the kitsune's tails are worn")
	if tails_mi:
		var mat := tails_mi.get_surface_override_material(0) as ShaderMaterial
		check((mat.get_shader_parameter("sway_amp") as Vector3).length() > 0.0, "the tails sway (shader)")
		check(mat.next_pass is ShaderMaterial, "with the cartoon outline at this quality")
		var uv2: PackedVector2Array = tails_mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
		var tips := 0
		for f in uv2:
			if f.x > 0.95:
				tips += 1
		check(tips > 0, "their tips are free to move")
	check(kit.get_script() != null and not kit.is_processing(), "a costumed chibi still runs no per-frame script at rest")
	kit.queue_free()
	# Every class body and both genders take every costume without errors.
	for cls in [&"darklord", &"mage", &"defender", &"bard", &"archer"]:
		for id in ["kitsune", "royal", "celestial"]:
			var other := _visual(id, cls, {}, false, 1 if cls == &"mage" else 0)
			check(_attached(other).size() == CostumeArt.parts(id).size(), "%s wears %s" % [cls, id])
			other.queue_free()
	await get_tree().process_frame


func _set_equip(cls: String) -> Dictionary:
	var e := {}
	for slot in SetGearData.SLOTS:
		var it := SetGearData.item(cls, slot)
		if not it.is_empty():
			e[slot] = it
	return e


func _wings() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var winged := _set_equip("darklord")
	winged["wings"] = LegendWings.item(3, 1)
	for id in ["celestial", "royal", "midnight"]:
		var open := CostumeArt.mesh_of(id, "back", false)
		var under := CostumeArt.mesh_of(id, "back", true)
		var count := func(m: ArrayMesh) -> int:
			var n := 0
			for i in m.get_surface_count():
				n += m.surface_get_array_len(i)
			return n
		check(under != null and count.call(under) < count.call(open), "%s keeps its back short under gear wings (%d < %d)" % [id, count.call(under), count.call(open)])
	var v := _visual("celestial", &"darklord", winged)
	check(_attached(v).has("ChibiCostume_back") and v.find_child("Wings", true, false) != null, "the celestial capelet stays beside the gear wings")
	v.queue_free()
	# A Dark Lord's cape counts as wings too.
	var caped := {"wings": StarWingData.item("darklord", rng, 4)}
	var lord := _visual("royal", &"darklord", caped)
	var back := lord.find_child("Costume_back", true, false) as MeshInstance3D
	check(back != null and back.mesh == CostumeArt.mesh_of("royal", "back", true), "under the Dark Lord's cape the royal cape is only its mantle")
	lord.queue_free()
	await get_tree().process_frame


func _motes() -> void:
	GameSettings.quality = 2
	MemoryGuard.pressure = 0
	for id in RewardShop.COSTUMES:
		var v := _visual(String(id))
		var motes := _motes_of(v)
		var want := CostumeArt.MOTES.has(id)
		check(motes.size() == (1 if want else 0), "%s: motes at high quality (%d)" % [id, motes.size()])
		if want and motes.size() == 1:
			var m := motes[0] as MeshInstance3D
			check(bool(m.get_meta("far_decor", false)), "%s: the motes are far decoration (a far phone player drops them)" % id)
			check(m.mesh.get_surface_count() == 1 and m.material_override is ShaderMaterial, "%s: the motes are one mesh, one material" % id)
			check(m.mesh.surface_get_array_len(0) == 4 * int(CostumeArt.MOTES[id].n), "%s: %d motes at high quality" % [id, int(CostumeArt.MOTES[id].n)])
		v.queue_free()
	# Fewer at medium, none at the lowest quality, under strict memory pressure or on the crowd.
	GameSettings.quality = 1
	check(CostumeArt.mote_count("sakura") < int(CostumeArt.MOTES.sakura.n) and CostumeArt.mote_count("sakura") > 0, "medium quality: fewer motes")
	GameSettings.quality = 0
	var low := _visual("kitsune")
	check(_motes_of(low).is_empty(), "lowest quality: no motes")
	check(_attached(low).size() == CostumeArt.parts("kitsune").size(), "but the whole silhouette")
	var low_tails := low.find_child("Costume_tails", true, false) as MeshInstance3D
	check(low_tails != null and (low_tails.get_surface_override_material(0) as ShaderMaterial).next_pass == null, "and no outline pass, like the body")
	low.queue_free()
	GameSettings.quality = 2
	MemoryGuard.pressure = 2
	var tight := _visual("celestial")
	check(_motes_of(tight).is_empty(), "strict memory pressure: no motes")
	tight.queue_free()
	MemoryGuard.pressure = 0
	var crowd := _visual("kitsune", &"warrior", {}, true)
	check(_motes_of(crowd).is_empty(), "the cheap crowd dressing: no motes")
	check(_attached(crowd).size() == CostumeArt.parts("kitsune").size(), "but the crowd keeps the silhouette")
	var crowd_tails := crowd.find_child("Costume_tails", true, false) as MeshInstance3D
	check(crowd_tails != null and (crowd_tails.get_surface_override_material(0) as ShaderMaterial).next_pass == null, "without the outline pass")
	# A world player who joins the party is dressed fully again.
	crowd.decor_light = false
	crowd.refresh()
	check(_motes_of(crowd).size() == 1, "joining the party brings the motes")
	# Far on a phone: the motes hide, the pieces stay.
	MemoryGuard.phone_override = 1
	crowd.set_far(true)
	check(not (_motes_of(crowd)[0] as Node3D).visible, "far on a phone the motes hide")
	var pieces_visible := true
	for attach in _attached(crowd).values():
		pieces_visible = pieces_visible and (attach as Node3D).visible
	check(pieces_visible, "and the costume's pieces stay")
	crowd.set_far(false)
	check((_motes_of(crowd)[0] as Node3D).visible, "near again they come back")
	MemoryGuard.phone_override = -1
	crowd.queue_free()
	await get_tree().process_frame


func _count(node: Node) -> int:
	var n := 1
	for child in node.get_children():
		n += _count(child)
	return n


func _leaks() -> void:
	await get_tree().process_frame
	var v := _visual("")
	await get_tree().process_frame
	var bare := _count(v)
	for id in RewardShop.COSTUMES:
		v.set_costume(String(id))
		await get_tree().process_frame
		check(_count(v) > bare, "%s adds its nodes" % id)
		v.set_costume("")
		await get_tree().process_frame
		check(_count(v) == bare, "%s taken off: the body is back to %d nodes (%d)" % [id, bare, _count(v)])
		check(_attached(v).is_empty() and _motes_of(v).is_empty(), "%s taken off: no piece and no mote left" % id)
	v.set_costume("kitsune")
	await get_tree().process_frame
	var once := _count(v)
	for id in ["royal", "sakura", "kitsune"]:
		v.set_costume(id)
		await get_tree().process_frame
	check(_count(v) == once, "switching costumes leaves nothing behind (%d / %d)" % [_count(v), once])
	v.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	var before := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	for id in RewardShop.COSTUMES:
		var w := _visual(String(id))
		await get_tree().process_frame
		w.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) == before, "freeing costumed bodies frees all their nodes (%d / %d)" % [int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), before])


## Prints what each costume adds to one body (triangles, draw surfaces) and its build time.
func _cost() -> void:
	CostumeArt.release_cache()
	for id in RewardShop.COSTUMES:
		var t0 := Time.get_ticks_usec()
		var tris := 0
		var surfaces := 0
		for spec in CostumeArt.parts(String(id)):
			var m := CostumeArt.mesh_of(String(id), String(spec[1]), false)
			if m == null:
				continue
			for i in m.get_surface_count():
				var arr := m.surface_get_arrays(i)
				tris += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
				surfaces += 1
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0
		check(tris < 6000, "%s stays light (%d triangles)" % [id, tris])
		print("costume %-10s %5d tris  %d surfaces  %d motes  built in %.1f ms" % [id, tris, surfaces, int(CostumeArt.MOTES.get(id, {}).get("n", 0)), ms])
