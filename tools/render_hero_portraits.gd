extends SceneTree
## Bake the real player's bare head, once at build time. The HUD uses only PNGs.
## DISPLAY=:99 godot --path . -s tools/render_hero_portraits.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	GameSettings.quality = 2
	DirAccess.make_dir_recursive_absolute("res://assets/ui/portraits")
	for gender in 2:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(512, 512)
		viewport.own_world_3d = true
		viewport.transparent_bg = true
		viewport.msaa_3d = Viewport.MSAA_4X
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var environment := Environment.new()
		environment.background_mode = Environment.BG_CLEAR_COLOR
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color("e5eaff")
		environment.ambient_light_energy = 0.8
		var world := WorldEnvironment.new()
		world.environment = environment
		viewport.add_child(world)
		var key := DirectionalLight3D.new()
		key.rotation_degrees = Vector3(-24, -28, 0)
		key.light_color = Color("fff1e2")
		key.light_energy = 1.2
		viewport.add_child(key)
		var fill := DirectionalLight3D.new()
		fill.rotation_degrees = Vector3(-12, 135, 0)
		fill.light_color = Color("bacfee")
		fill.light_energy = 0.55
		viewport.add_child(fill)
		var hero := HeroVisual.new()
		viewport.add_child(hero)
		hero.setup(ClassData.START, "", false, {}, {"gender": gender})
		_isolate_head(hero)
		hero.anim.play("Idle")
		hero.anim.seek(0.0, true)
		hero.anim.pause()
		hero.rotation_degrees.y = -8.0
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 1.16
		camera.position = Vector3(-0.03, 1.96, 5.0)
		viewport.add_child(camera)
		for frame in 5:
			await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		image.resize(256, 256, Image.INTERPOLATE_LANCZOS)
		var path := "res://assets/ui/portraits/hero_%s.png" % ("girl" if gender == 1 else "boy")
		var error := image.save_png(path)
		if error != OK:
			push_error("Could not save portrait: %s" % path)
			quit(1)
			return
		print("Baked ", path)
		viewport.free()
	quit(0)


## Keep triangles weighted to the Head subtree, including facial and hair
## bones. A height crop would cut off long hair while still showing shoulders.
func _isolate_head(hero: HeroVisual) -> void:
	var skeleton := hero.model.find_child("Skeleton3D", true, false) as Skeleton3D
	var head := skeleton.find_bone("Head")
	for node in hero.model.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if instance.skin == null or instance.mesh == null:
			continue
		var head_binds: Dictionary = {}
		for bind in instance.skin.get_bind_count():
			var bone := skeleton.find_bone(instance.skin.get_bind_name(bind))
			if bone < 0:
				bone = instance.skin.get_bind_bone(bind)
			while bone >= 0:
				if bone == head:
					head_binds[bind] = true
					break
				bone = skeleton.get_bone_parent(bone)
		var source := instance.mesh
		var cropped := ArrayMesh.new()
		for surface in source.get_surface_count():
			var arrays := source.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var stride := bones.size() / vertices.size()
			var included: PackedByteArray = []
			included.resize(vertices.size())
			for vertex in vertices.size():
				var head_weight := 0.0
				for slot in stride:
					var at := vertex * stride + slot
					if head_binds.has(bones[at]):
						head_weight += weights[at]
				included[vertex] = 1 if head_weight >= 0.45 else 0
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var kept: PackedInt32Array = []
			for triangle in range(0, indices.size(), 3):
				if included[indices[triangle]] and included[indices[triangle + 1]] and included[indices[triangle + 2]]:
					kept.append(indices[triangle])
					kept.append(indices[triangle + 1])
					kept.append(indices[triangle + 2])
			arrays[Mesh.ARRAY_INDEX] = kept
			cropped.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, source.surface_get_format(surface) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
			cropped.surface_set_material(cropped.get_surface_count() - 1, source.surface_get_material(surface))
		instance.mesh = cropped
