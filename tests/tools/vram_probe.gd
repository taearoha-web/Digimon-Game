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
