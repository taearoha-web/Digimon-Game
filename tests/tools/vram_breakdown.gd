extends Node
## Video memory by kind (textures, buffers, total) in a field and back in the village,
## and the largest textures in use, for a class at a level.
##   godot --rendering-driver opengl3 --path . res://tests/tools/vram_breakdown.tscn -- darklord 58 graveyard
func _report(tag: String) -> void:
	await RenderingServer.frame_post_draw
	print("%s total=%.1fMB textures=%.1fMB buffers=%.1fMB nodes=%d" % [tag,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED) / 1048576.0,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var cls := StringName(args[0]) if args.size() > 0 else &"darklord"
	var level := int(args[1]) if args.size() > 1 else 58
	var field := StringName(args[2]) if args.size() > 2 else &"graveyard"
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(0.3).timeout
	Game.new_profile(cls, "Probe", FaceKit.default_look())
	main.title_screen.queue_free()
	main.title_screen = null
	main.hud.visible = true
	Game.profile.level = level
	Game.profile.adv = JobData.adv_for_level(level)
	for slot in ["weapon", "armor", "helm", "boots", "amulet", "ring"]:
		Game.profile.equip[slot] = ItemData.generate(level, cls, Game.rng, 3, slot)
	await _report("empty")
	await main.go(&"town", true)
	await get_tree().create_timer(2.0).timeout
	await _report("town-first")
	var fields: Array = [field] if args.size() <= 3 else Array(args[3].split(","))
	for f in fields:
		await main.go(StringName(f), true)
		main.zone.hero.set_auto(true)
		await get_tree().create_timer(20.0).timeout
		await _report("field %s" % f)
		await main.go(&"town", true)
		await get_tree().create_timer(3.0).timeout
		await _report("town-back")
	for pair in [["SkillInk", SkillInk._meshes], ["SpellSpectacle", SpellSpectacle._meshes], ["SpellSpectacle.tube", SpellSpectacle._tube_meshes],
			["VfxKit.flight", VfxKit._flight_meshes], ["EliteSkillArt", EliteSkillArt._meshes], ["LordSkillArt", LordSkillArt._meshes],
			["VfxArt.spiral", VfxArt._spiral_meshes], ["VfxArt.art", VfxArt._art_meshes], ["ShaderBurst", ShaderBurst._meshes],
			["BardSkillArt", BardSkillArt._meshes], ["ShadowSkillArt", ShadowSkillArt._meshes], ["ThunderStormArt", ThunderStormArt._bolt_meshes],
			["StarMonsterArt", StarMonsterArt._meshes], ["StarRegionArt", StarRegionArt._meshes], ["Scenery.props", Scenery._prop_meshes],
			["BuffArt", BuffArt._meshes], ["MeshKit", MeshKit._meshes], ["NatureKit", NatureKit._cache], ["MeshMerge", MeshMerge._cache], ["HeroParts", HeroParts._cache]]:
		print("CACHE %-20s %7.2fMB (%d)" % [pair[0], _bytes(pair[1], {}) / 1048576.0, (pair[1] as Dictionary).size()])
	var sizes := {}
	for tex in _textures(get_tree().root, {}):
		var t := tex as Texture2D
		sizes["%s %dx%d" % [t.resource_path.get_file() if t.resource_path != "" else t.get_class(), t.get_width(), t.get_height()]] = t.get_width() * t.get_height() * 4
	var keys := sizes.keys()
	keys.sort_custom(func(a, b): return sizes[a] > sizes[b])
	for k in keys.slice(0, 25):
		print("TEX %6.2fMB %s" % [sizes[k] / 1048576.0, k])
	get_tree().quit()


func _textures(node: Node, seen: Dictionary) -> Array:
	var out := []
	var mats := []
	if node is GeometryInstance3D:
		var g := node as GeometryInstance3D
		mats.append(g.material_override)
		if node is MeshInstance3D and (node as MeshInstance3D).mesh:
			var m := (node as MeshInstance3D).mesh
			for s in m.get_surface_count():
				mats.append(m.surface_get_material(s))
				mats.append((node as MeshInstance3D).get_surface_override_material(s))
	for mat in mats:
		if mat == null or seen.has(mat):
			continue
		seen[mat] = true
		for p in mat.get_property_list():
			var v: Variant = mat.get(p.name)
			if v is Texture2D and not seen.has(v):
				seen[v] = true
				out.append(v)
		if mat is ShaderMaterial and (mat as ShaderMaterial).shader:
			for u in (mat as ShaderMaterial).shader.get_shader_uniform_list():
				var v2: Variant = (mat as ShaderMaterial).get_shader_parameter(u.name)
				if v2 is Texture2D and not seen.has(v2):
					seen[v2] = true
					out.append(v2)
	for c in node.get_children():
		out.append_array(_textures(c, seen))
	return out


func _bytes(v: Variant, seen: Dictionary) -> int:
	if v is Dictionary:
		var n := 0
		for k in v:
			n += _bytes(v[k], seen)
		return n
	if v is Array:
		var n2 := 0
		for x in v:
			n2 += _bytes(x, seen)
		return n2
	if v is Mesh and not seen.has(v):
		seen[v] = true
		var m := v as Mesh
		var n3 := 0
		for s in m.get_surface_count():
			var arr := m.surface_get_arrays(s)
			for a in arr:
				if a is PackedVector3Array: n3 += a.size() * 12
				elif a is PackedVector2Array: n3 += a.size() * 8
				elif a is PackedColorArray: n3 += a.size() * 16
				elif a is PackedFloat32Array: n3 += a.size() * 4
				elif a is PackedInt32Array: n3 += a.size() * 4
		return n3
	if v is Node and is_instance_valid(v):
		var n4 := 0
		for c in (v as Node).find_children("*", "MeshInstance3D", true, false):
			n4 += _bytes((c as MeshInstance3D).mesh, seen)
		return n4
	return 0
