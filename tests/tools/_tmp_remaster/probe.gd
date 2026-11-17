extends SceneTree


func _init() -> void:
	var scene := (load("res://assets/models/monsters/remaster/blob/Chicken.glb") as PackedScene).instantiate()
	root.add_child(scene)
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh
		var skin := (mi as MeshInstance3D).skin
		print("MESH ", mi.name, " surfaces ", m.get_surface_count(), " skin binds ", skin.get_bind_count() if skin else -1)
		if skin:
			for b in skin.get_bind_count():
				print("  bind ", b, " ", skin.get_bind_name(b), " bone ", skin.get_bind_bone(b))
		for s in m.get_surface_count():
			var arr := m.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var shown := 0
			for i in v.size():
				if v[i].z < -0.85 and v[i].y > 1.0 and absf(v[i].x) < 0.2 and shown < 3:
					shown += 1
					print("  s", s, " v ", v[i], " bones ", bones.slice(i * 4, i * 4 + 4), " w ", w.slice(i * 4, i * 4 + 4))
	for sk in scene.find_children("*", "Skeleton3D", true, false):
		var s3 := sk as Skeleton3D
		for b in s3.get_bone_count():
			print("BONE ", b, " ", s3.get_bone_name(b))
	quit()
