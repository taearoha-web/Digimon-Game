extends Node3D
## Repeated skill geometry must reuse mesh resources while each cast keeps its
## own animated material. Caches must stay finite and not invalidate live art.

var failures: Array[String] = []
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)


func sample_skill(skill: Dictionary) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var look := SkillShow.profile_for(skill)
	SpellSpectacle.cast(root, skill, look, Vector3(3, 0, 0), Vector3.ZERO, int(look.tier))
	return root


func _ready() -> void:
	await get_tree().process_frame
	GameSettings.load_settings()
	var saved_quality := GameSettings.quality
	GameSettings.quality = 2
	var red := VfxKit._particles(self, Vector3.ZERO, Color.RED, 4, 0.3)
	var blue := VfxKit._particles(self, Vector3.ZERO, Color.BLUE, 4, 0.3)
	check(red.mesh == blue.mesh, "hit bursts share one immutable GPU quad")
	check(red.material_override != blue.material_override, "hit bursts keep independent colours")
	check((red.material_override as StandardMaterial3D).albedo_color.r == 1.0 and (blue.material_override as StandardMaterial3D).albedo_color.b == 1.0, "particle material override retains the requested colour")
	red.queue_free()
	blue.queue_free()
	await blue.tree_exited
	var retained := MeshKit.toon(Color("4acde8"))
	var live_mesh := MeshInstance3D.new()
	live_mesh.mesh = MeshKit.box()
	live_mesh.material_override = retained
	add_child(live_mesh)
	for index in MeshKit.MATERIAL_CACHE_LIMIT + 10:
		MeshKit.toon(Color.from_hsv(float(index) / 220.0, 0.7, 0.8), {"emission": float(index) / 100.0})
	check(MeshKit._materials.size() <= MeshKit.MATERIAL_CACHE_LIMIT, "generated palettes cannot grow without limit")
	MeshKit.release_material_cache()
	check(live_mesh.material_override == retained and retained.albedo_color == Color("4acde8"), "eviction does not alter a live scene's materials")
	live_mesh.queue_free()
	await live_mesh.tree_exited
	var selected: Array[Dictionary] = []
	for family in [&"vagabond", &"mage", &"summoner", &"lancer"]:
		for skill in ClassData.pool(family):
			if String(skill.id) in ["power_strike", "hell_meteor", "elder_dragon", "ragnarok_lance"]:
				selected.append(skill)
	check(selected.size() == 4, "all representative skill families included")
	for quality in 3:
		GameSettings.quality = quality
		SpellSpectacle.warm_geometry()
		for skill in selected:
			var first := sample_skill(skill)
			var first_meshes := first.find_children("*", "MeshInstance3D", true, false)
			var second := sample_skill(skill)
			var second_meshes := second.find_children("*", "MeshInstance3D", true, false)
			check(not first_meshes.is_empty() and first_meshes.size() == second_meshes.size(), "repeat silhouette: %s q%d" % [skill.id, quality])
			for i in mini(first_meshes.size(), second_meshes.size()):
				var a := first_meshes[i] as MeshInstance3D
				var b := second_meshes[i] as MeshInstance3D
				check(a.mesh == b.mesh, "mesh reused: %s q%d part%d" % [skill.id, quality, i])
				check(a.material_override != b.material_override, "independent material: %s q%d part%d" % [skill.id, quality, i])
			if not first_meshes.is_empty() and not second_meshes.is_empty():
				var first_material := (first_meshes[0] as MeshInstance3D).material_override as ShaderMaterial
				var second_material := (second_meshes[0] as MeshInstance3D).material_override as ShaderMaterial
				first_material.set_shader_parameter("fade", 0.15)
				check(second_material.get_shader_parameter("fade") != 0.15, "one cast cannot fade another: " + String(skill.id))
			first.queue_free()
			second.queue_free()
			await second.tree_exited
			check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "repeat casts release reservations")
	# Different sizes share a unit-size trail while their transforms and
	# independently animated materials retain each projectile's appearance.
	GameSettings.quality = 2
	var flight_a := Node3D.new()
	var flight_b := Node3D.new()
	add_child(flight_a)
	add_child(flight_b)
	VfxKit.flight_ribbons(flight_a, Color.ORANGE, 0.4, 2.7, true)
	VfxKit.flight_ribbons(flight_b, Color.CYAN, 0.8, 2.7, true)
	for i in 2:
		var a := flight_a.get_child(i) as MeshInstance3D
		var b := flight_b.get_child(i) as MeshInstance3D
		check(a.mesh == b.mesh, "projectile sizes share trail mesh")
		check(a.scale.is_equal_approx(Vector3.ONE * 0.4) and b.scale.is_equal_approx(Vector3.ONE * 0.8), "projectile size retained in instance scale")
		check(a.material_override != b.material_override, "projectile material stays independent")
	flight_a.queue_free()
	flight_b.queue_free()
	await flight_b.tree_exited
	var ribbon := VfxArt._spiral_mesh(3.2, 2.8, 1.25, 0, 48)
	check(ribbon == VfxArt._spiral_mesh(3.2, 2.8, 1.25, 0, 48), "ground ribbon reuse")
	check(ribbon != VfxArt._spiral_mesh(3.3, 2.8, 1.25, 0, 48), "different ribbon geometry remains distinct")
	for index in VfxArt.SPIRAL_CACHE_LIMIT + 1:
		VfxArt._spiral_mesh(4.0 + index * 0.1, 2.8, 1.25, 0, 48)
	check(VfxArt._spiral_meshes.size() <= VfxArt.SPIRAL_CACHE_LIMIT, "dynamic spiral cache remains bounded")
	check(ribbon.get_surface_count() == 1 and ribbon.get_aabb().size.y > 3.0, "eviction retains live mesh resources")
	var slash := SpellSpectacle._slash_mesh(5, 0)
	for index in SpellSpectacle.TUBE_CACHE_LIMIT + 1:
		SpellSpectacle._remember_tube("future_recipe:%d" % index, slash)
	check(SpellSpectacle._tube_meshes.size() <= SpellSpectacle.TUBE_CACHE_LIMIT, "authored tube cache remains bounded")
	check(slash.get_surface_count() == 1, "eviction retains live authored art")
	check(MeteorArt._shock_ring_mesh() == MeteorArt._shock_ring_mesh(), "all meteor impacts share pressure ring geometry")
	check(VfxKit._fade_ramp() == VfxKit._fade_ramp(), "hit particles share immutable fade ramp")
	for kind in 3:
		var ink := SkillInk.ribbon_mesh(kind)
		check(ink == SkillInk.ribbon_mesh(kind), "ink ribbon cache reused")
		var vertices: PackedVector3Array = ink.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			check(vertex.is_finite(), "ink ribbon has finite tapered endpoints")
	for kind in ["cat", "treant"]:
		var creature := SkillTableau.creature_mesh(kind)
		var arrays := creature.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			indices = arrays[Mesh.ARRAY_INDEX]
		var drawn_height := 0.0
		if indices.is_empty():
			for vertex in vertices:
				drawn_height = maxf(drawn_height, vertex.y)
		else:
			for index in indices:
				drawn_height = maxf(drawn_height, vertices[index].y)
		check(drawn_height > (2.7 if kind == "treant" else 2.3), "merged totems actually draw their leaves/ears")
	GameSettings.quality = saved_quality
	print("VFX MESH CACHE: %s | %d checks, %d failures" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	get_tree().quit(failures.size())
