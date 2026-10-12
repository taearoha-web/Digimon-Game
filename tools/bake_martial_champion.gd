extends SceneTree
## Bake the existing licensed KayKit warrior into one spectral surface.
## Both poses use identical topology; custom0 stores the strike position.
func _initialize() -> void:
	call_deferred("bake")

func sample(hero: HeroVisual, time: float) -> ArrayMesh:
	hero.anim.play("1H_Melee_Attack_Chop")
	hero.anim.seek(time,true)
	hero.anim.pause()
	hero._skeleton.force_update_all_bone_transforms()
	await process_frame
	await process_frame
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for child in hero.find_children("*","MeshInstance3D",true,false):
		var mi := child as MeshInstance3D
		if mi.mesh==null or not mi.is_visible_in_tree() or mi.name=="BlobShadow": continue
		var transform := hero.global_transform.affine_inverse()*mi.global_transform
		for surface in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			if mi.skin!=null:
				var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
				var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
				var influences := bones.size()/vertices.size()
				var sk := mi.get_node(mi.skeleton) as Skeleton3D
				var posed := PackedVector3Array()
				for i in vertices.size():
					var v := Vector3.ZERO
					for j in influences:
						var weight := weights[i*influences+j]
						if weight<=0.0: continue
						var bind := bones[i*influences+j]
						var bone := mi.skin.get_bind_bone(bind)
						if bone<0: bone=sk.find_bone(mi.skin.get_bind_name(bind))
						v+=(sk.get_bone_global_pose(bone)*mi.skin.get_bind_pose(bind)*vertices[i])*weight
					posed.append(v)
				vertices=posed
				transform=hero.global_transform.affine_inverse()*sk.global_transform
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			var mat := mi.get_active_material(surface) as StandardMaterial3D
			var gold := 0.15
			if mat: gold=0.85 if mat.albedo_color.r>mat.albedo_color.b*1.2 else 0.25
			for i in (indices.size() if not indices.is_empty() else vertices.size()):
				st.set_color(Color(gold,1,0))
				st.add_vertex(transform*vertices[indices[i] if not indices.is_empty() else i])
	st.generate_normals()
	return st.commit()

func bake() -> void:
	var hero := HeroVisual.new()
	root.add_child(hero)
	hero.setup(&"warrior")
	hero.set_process(false)
	await process_frame
	var a := await sample(hero,0.25)
	var b := await sample(hero,0.46)
	if a==null or b==null: return
	var arrays := a.surface_get_arrays(0)
	var target: PackedVector3Array=b.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert(target.size()==(arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	var morph := PackedFloat32Array()
	for v in target: morph.append_array(PackedFloat32Array([v.x,v.y,v.z]))
	arrays[Mesh.ARRAY_CUSTOM0]=morph
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	assert(out.get_surface_count()==1)
	out.custom_aabb=a.get_aabb().merge(b.get_aabb())
	DirAccess.make_dir_recursive_absolute("res://assets/vfx/martial")
	assert(ResourceSaver.save(out,"res://assets/vfx/martial/champion.res",ResourceSaver.FLAG_COMPRESS)==OK)
	print("CHAMPION: one surface / ",target.size()/3," triangles / two baked poses")
	hero.free()
	quit()
