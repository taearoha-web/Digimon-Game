extends Node
## Video memory of one zone with the hero in it, as the renderer reports it.
## Needs a real renderer: xvfb-run godot --rendering-driver opengl3 --path . res://tests/tools/vram_probe.tscn -- ZONE [quality]
## Prints texture / buffer / total video memory and the biggest textures it can
## reach from the scene (material albedo and emission maps).


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var zone_id := StringName(args[0] if args.size() > 0 else "guildwar")
	GameSettings.load_settings()
	GameSettings.quality = int(args[1]) if args.size() > 1 else 1
	get_window().size = Vector2i(1280, 720)
	Game.set_process(false)
	Game.new_profile(&"defender", "Vram", FaceKit.default_look())
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile["paragon"] = {"level": 200, "exp": 0, "points": 0, "spent": 0, "alloc": {}}
	Game.current_zone = zone_id
	await RenderingServer.frame_post_draw
	print("VRAM baseline before the zone: video %.1f MB, texture %.1f MB, buffer %.1f MB" % [
		float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)) / 1e6,
		float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)) / 1e6,
		float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED)) / 1e6])
	var zone := Zone.new()
	zone.zone_id = zone_id
	add_child(zone)
	for i in 90:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var rs := RenderingServer
	print("VRAM zone %s quality %d: video %.1f MB, texture %.1f MB, buffer %.1f MB, nodes %d" % [zone_id, GameSettings.quality,
		float(rs.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)) / 1e6,
		float(rs.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)) / 1e6,
		float(rs.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED)) / 1e6,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	print("VRAM world players shown %d" % get_tree().get_nodes_in_group("world_players").size())
	# Mesh buffers per top-level branch of the zone: instances, distinct meshes
	# (shared geometry counts once) and the vertex + index bytes those hold.
	var all_meshes := {}
	for child in zone.get_children():
		var report := _mesh_report(child, all_meshes)
		if report.instances > 0:
			print("VRAM mesh %-26s instances %4d distinct %4d new %4d  %6.2f MB new geometry" % [child.name, report.instances, report.distinct, report.fresh, float(report.bytes) / 1e6])
	# The heaviest distinct meshes in the whole scene, with where they hang.
	var heavy: Array = []
	var seen_mesh := {}
	var walk: Array[Node] = [zone]
	while not walk.is_empty():
		var n: Node = walk.pop_back()
		for ch in n.get_children():
			walk.append(ch)
		var mesh: Mesh = (n as MeshInstance3D).mesh if n is MeshInstance3D else null
		if mesh == null or seen_mesh.has(mesh.get_rid()):
			continue
		seen_mesh[mesh.get_rid()] = true
		heavy.append([_mesh_bytes(mesh), mesh.resource_path if mesh.resource_path != "" else mesh.resource_name, n.name, n.get_parent().name if n.get_parent() else "", mesh.get_surface_count()])
	heavy.sort_custom(func(a, b): return a[0] > b[0])
	for h in heavy.slice(0, 14):
		print("VRAM heavy %6.2f MB surfaces %2d  %s  (node %s under %s)" % [float(h[0]) / 1e6, h[4], h[1], h[2], h[3]])
	var fighters := get_tree().get_nodes_in_group("mobs")
	if fighters.size() > 0:
		var one := _mesh_report(fighters[0], {})
		print("VRAM mesh one fighter: instances %d distinct %d %.2f MB; fighters %d" % [one.instances, one.distinct, float(one.bytes) / 1e6, fighters.size()])
		# Every distinct mesh of that fighter: what the bytes are made of.
		var listed := {}
		var walk2: Array[Node] = [fighters[0]]
		while not walk2.is_empty():
			var n2: Node = walk2.pop_back()
			for ch in n2.get_children():
				walk2.append(ch)
			var mesh2: Mesh = (n2 as MeshInstance3D).mesh if n2 is MeshInstance3D else null
			if mesh2 == null or listed.has(mesh2.get_rid()):
				continue
			listed[mesh2.get_rid()] = true
			print("VRAM fighter mesh %6.3f MB surfaces %2d %-40s node %s / %s" % [float(_mesh_bytes(mesh2)) / 1e6, mesh2.get_surface_count(),
				mesh2.resource_path if mesh2.resource_path != "" else mesh2.resource_name, n2.name, n2.get_parent().name if n2.get_parent() else ""])
	var seen := {}
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for ch in n.get_children():
			stack.append(ch)
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var mats: Array = []
			if mi.material_override:
				mats.append(mi.material_override)
			if mi.mesh:
				for s in mi.mesh.get_surface_count():
					mats.append(mi.get_active_material(s))
			for mat in mats:
				if mat is BaseMaterial3D:
					for key in ["albedo_texture", "emission_texture", "normal_texture"]:
						var tex: Texture2D = mat.get(key)
						if tex and not seen.has(tex.get_rid()):
							seen[tex.get_rid()] = [tex.get_width() * tex.get_height() * 4, tex.resource_path, tex.get_width(), tex.get_height()]
				elif mat is ShaderMaterial:
					for u in (mat as ShaderMaterial).shader.get_shader_uniform_list():
						var v: Variant = mat.get_shader_parameter(u.name)
						if v is Texture2D and not seen.has(v.get_rid()):
							seen[v.get_rid()] = [v.get_width() * v.get_height() * 4, v.resource_path, v.get_width(), v.get_height()]
	var rows := seen.values()
	rows.sort_custom(func(a, b): return a[0] > b[0])
	var total := 0
	for r in rows:
		total += int(r[0])
	print("VRAM %d scene textures, %.1f MB RGBA8-equivalent (before mipmaps/compression)" % [rows.size(), float(total) / 1e6])
	for r in rows.slice(0, 15):
		print("VRAM  %6.2f MB %4dx%-4d %s" % [float(r[0]) / 1e6, r[2], r[3], r[1]])
	get_tree().quit()


static func _mesh_bytes(mesh: Mesh) -> int:
	var total := 0
	for i in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(i)
		if arrays.is_empty():
			continue
		var verts: Variant = arrays[Mesh.ARRAY_VERTEX]
		var vcount: int = verts.size() if verts != null else 0
		var stride := 12
		for k in [Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS]:
			if arrays[k] != null:
				stride += 16 if k in [Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS] else (8 if k in [Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2] else 12)
		var idx: Variant = arrays[Mesh.ARRAY_INDEX]
		total += vcount * stride + (idx.size() * 4 if idx != null else 0)
	return total


static func _mesh_report(root: Node, known: Dictionary) -> Dictionary:
	var out := {"instances": 0, "distinct": 0, "fresh": 0, "bytes": 0}
	var local := {}
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for ch in n.get_children():
			stack.append(ch)
		var mesh: Mesh = null
		if n is MeshInstance3D:
			mesh = (n as MeshInstance3D).mesh
		elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh:
			mesh = (n as MultiMeshInstance3D).multimesh.mesh
		if mesh == null:
			continue
		out.instances += 1
		var rid := mesh.get_rid()
		if not local.has(rid):
			local[rid] = true
			out.distinct += 1
			if not known.has(rid):
				known[rid] = true
				out.fresh += 1
				out.bytes += _mesh_bytes(mesh)
	return out
