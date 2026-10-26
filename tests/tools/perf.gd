extends Node
## Frame-cost profile of the hunting fields: the hero auto-fights (skills,
## companion, summons) for a while in each zone and the frame costs are printed.
##   godot --rendering-driver opengl3 --path . res://tests/tools/perf.tscn -- <class> [zone,zone,...] [seconds]

var main: Node


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var class_id := StringName(args[0] if args.size() > 0 else "summoner")
	var zones: Array = (args[1] if args.size() > 1 else "meadow,desert,volcano,void").split(",")
	var seconds := float(args[2]) if args.size() > 2 else 12.0
	GameSettings.load_settings()
	if args.size() > 3:
		GameSettings.quality = int(args[3])
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(0.5).timeout
	Game.new_profile(class_id, "perf")
	Game.profile["level"] = 100
	Game.profile["adv"] = 4
	Game.profile["loadout"] = ClassData.default_loadout(class_id, 100, [], ClassData.tier_of(class_id, 4))
	for skill in ClassData.pool(class_id):
		Game.profile.skills[skill.id] = 10
	if Game.party().is_empty():
		Game.party_invite(WorldPlayers.first_of(&"priest"), true)
	if main.title_screen:
		main.title_screen.queue_free()
		main.title_screen = null
	if zones[0] == "hero":
		await main.go(&"meadow", true)
		await get_tree().create_timer(1.5).timeout
		for body in [main.zone.hero] + get_tree().get_nodes_in_group("companions"):
			var vis := 0
			var surf := 0
			var lines := {}
			for mi in (body as Node).find_children("*", "MeshInstance3D", true, false):
				var m := mi as MeshInstance3D
				if not m.is_visible_in_tree():
					continue
				vis += 1
				surf += m.mesh.get_surface_count() if m.mesh else 0
				var mat := m.get_active_material(0)
				var key := "%s <- %s | skin %s | outline %s" % [m.name.left(22), m.get_parent().name.left(16), m.skin != null or m.get_parent() is Skeleton3D, mat != null and mat.next_pass != null]
				lines[key] = int(lines.get(key, 0)) + 1
			print("BODY %s visible meshes %d surfaces %d" % [body.name, vis, surf])
			for k in lines:
				print("   %3d %s" % [lines[k], k])
		get_tree().quit()
		return
	if zones[0] == "diag":
		await _diag()
		get_tree().quit()
		return
	for zone_id in zones:
		await main.go(StringName(zone_id), true)
		await get_tree().create_timer(1.0).timeout
		var hero: Hero = main.zone.hero
		hero.set_auto(true)
		await get_tree().create_timer(2.0).timeout
		var frames := 0
		var proc_sum := 0.0
		var phys_sum := 0.0
		var worst_proc := 0.0
		var worst_phys := 0.0
		var wall_sum := 0.0
		var worst_wall := 0.0
		var draw_max := 0
		var prim_max := 0
		var obj_max := 0
		var t_prev := Time.get_ticks_usec()
		var t_end := Time.get_ticks_msec() + int(seconds * 1000.0)
		while Time.get_ticks_msec() < t_end:
			await get_tree().process_frame
			Game.profile.mp = 99999
			Game.profile.hp = maxi(int(Game.profile.hp), 1000000)
			var t := Time.get_ticks_usec()
			var wall := float(t - t_prev) / 1000.0
			t_prev = t
			var p := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			var ph := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			frames += 1
			proc_sum += p
			phys_sum += ph
			wall_sum += wall
			worst_proc = maxf(worst_proc, p)
			worst_phys = maxf(worst_phys, ph)
			worst_wall = maxf(worst_wall, wall)
			draw_max = maxi(draw_max, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
			prim_max = maxi(prim_max, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
			obj_max = maxi(obj_max, int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
		var z: Node = main.zone
		print("PERF %s: frames %d | wall avg %.1f worst %.1f ms | process avg %.2f worst %.2f | physics avg %.2f worst %.2f | draw<=%d prims<=%d objs<=%d | nodes %d" % [
			zone_id, frames, wall_sum / frames, worst_wall, proc_sum / frames, worst_proc, phys_sum / frames, worst_phys, draw_max, prim_max, obj_max, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
		print("  mobs %d summons %d meshes %d mmi %d skeletons %d anim %d particles %d lights %d bodies %d" % [
			get_tree().get_nodes_in_group("mobs").size(), get_tree().get_nodes_in_group("summons").size(),
			_count(z, "MeshInstance3D"), _count(z, "MultiMeshInstance3D"), _count(z, "Skeleton3D"), _count(z, "AnimationPlayer"),
			_count(z, "CPUParticles3D") + _count(z, "GPUParticles3D"), _count(z, "Light3D"), _count(z, "PhysicsBody3D")])
		hero.set_auto(false)
	get_tree().quit()


func _count(root: Node, cls: String) -> int:
	return root.find_children("*", cls, true, false).size()


## What each part of a field costs to draw: turns groups off one at a time.
func _diag() -> void:
	await main.go(&"meadow", true)
	await get_tree().create_timer(2.0).timeout
	var z: Node = main.zone
	var report := func(label: String):
		var d := 0
		var p := 0
		var o := 0
		var wall := 0.0
		for i in 8:
			var t0 := Time.get_ticks_usec()
			await get_tree().process_frame
			wall += float(Time.get_ticks_usec() - t0) / 1000.0
			d = maxi(d, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
			p = maxi(p, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
			o = maxi(o, int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
		print("DIAG %-28s draw %5d prims %7d objs %5d wall %.0f ms" % [label, d, p, o, wall / 8.0])
	await report.call("all")
	var mobs := get_tree().get_nodes_in_group("mobs")
	for m in mobs:
		m.visible = false
	await report.call("no mobs")
	for m in mobs:
		m.visible = true
	var nature: Array = []
	for n in z.find_children("*", "MultiMeshInstance3D", true, false):
		nature.append(n)
		n.visible = false
	await report.call("no multimesh scenery")
	for n in nature:
		n.visible = true
	var suns := get_tree().get_nodes_in_group("sun")
	for sun in suns:
		sun.shadow_enabled = false
	await report.call("no shadows")
	for sun in suns:
		sun.shadow_enabled = true
	var outlined := 0
	var saved := {}
	for mi in z.find_children("*", "MeshInstance3D", true, false):
		for i in (mi as MeshInstance3D).get_surface_override_material_count():
			var mat := (mi as MeshInstance3D).get_active_material(i)
			if mat and mat.next_pass:
				saved[[mi, i]] = mat
				var copy := mat.duplicate()
				copy.next_pass = null
				(mi as MeshInstance3D).set_surface_override_material(i, copy)
				outlined += 1
	await report.call("no outlines (%d)" % outlined)
	for key in saved:
		(key[0] as MeshInstance3D).set_surface_override_material(key[1], saved[key])
	var other: Array = []
	for mi in z.find_children("*", "MeshInstance3D", true, false):
		if not (mi as Node).get_parent() is Skeleton3D and not mobs.any(func(m): return m.is_ancestor_of(mi)):
			other.append(mi)
	print("  non-mob mesh instances: %d" % other.size())
	var mob_meshes := 0
	var mob_tris := 0
	for m in mobs:
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			mob_meshes += 1
			var mesh := (mi as MeshInstance3D).mesh
			if mesh:
				for sidx in mesh.get_surface_count():
					var arr := mesh.surface_get_arrays(sidx)
					mob_tris += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 if arr[Mesh.ARRAY_INDEX] != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	print("  mobs %d mesh instances %d triangles %d (%.0f per mob)" % [mobs.size(), mob_meshes, mob_tris, float(mob_tris) / maxf(mobs.size(), 1)])
	# Where the other meshes live (by the node right under the field).
	var groups := {}
	for mi in other:
		var n: Node = mi
		while n.get_parent() != z and n.get_parent() != null:
			n = n.get_parent()
		var key := "%s/%s" % [n.name.left(18), n.get_class()]
		var surfaces := 0
		var tris := 0
		var m := (mi as MeshInstance3D).mesh
		if m:
			surfaces = m.get_surface_count()
		groups[key] = (groups.get(key, Vector3i()) as Vector3i) + Vector3i(1, surfaces, 0)
	var mm_groups := {}
	for n0 in z.find_children("*", "MultiMeshInstance3D", true, false):
		var n: Node = n0
		while n.get_parent() != z and n.get_parent() != null:
			n = n.get_parent()
		var mmi := n0 as MultiMeshInstance3D
		var inst := mmi.multimesh.visible_instance_count if mmi.multimesh.visible_instance_count >= 0 else mmi.multimesh.instance_count
		var key := "%s" % n.name.left(18)
		mm_groups[key] = (mm_groups.get(key, Vector3i()) as Vector3i) + Vector3i(1, mmi.multimesh.mesh.get_surface_count() if mmi.multimesh.mesh else 0, inst)
	for key in groups:
		print("  MESH %-30s n %d surfaces %d" % [key, groups[key].x, groups[key].y])
	for key in mm_groups:
		print("  MMI %-30s n %d surfaces %d instances %d" % [key, mm_groups[key].x, mm_groups[key].y, mm_groups[key].z])
