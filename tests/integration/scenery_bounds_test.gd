extends Node3D
## Verify that tighter chunk bounds still contain wind-displaced geometry under
## rotation, mirroring and nonuniform scaling, and preserve distance centres.
## godot --headless --path . res://tests/integration/scenery_bounds_test.tscn

var failures: Array[String] = []
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

func _ready() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.2, 2.5, 0.9)
	var transforms: Array[Transform3D] = [
		Transform3D(Basis.from_euler(Vector3(0.2, 1.1, -0.3)).scaled(Vector3(1.8, 0.7, 2.4)), Vector3(5, 1, 6)),
		Transform3D(Basis.from_euler(Vector3(-0.1, -0.7, 0.4)).scaled(Vector3(-1.3, 2.4, 0.4)), Vector3(29, -0.3, 31)),
	]
	var model_xform := Transform3D(Basis.from_euler(Vector3(0.2, 0.8, -0.1)).scaled(Vector3(0.7, 1.2, 1.4)), Vector3(0.5, 0.2, -0.3))
	for centre in [Vector3(18, 10, 18), Vector3(18, 1, 18)]:
		var bounds := NatureKit.chunk_bounds(mesh, transforms, [0, 1], centre, model_xform)
		check(bounds.get_center().is_equal_approx(centre), "distance-culling centre remains unchanged")
		var source := mesh.get_aabb()
		for placement in transforms:
			for x in [source.position.x, source.end.x]:
				for y in [source.position.y, source.end.y]:
					for z in [source.position.z, source.end.z]:
						# Strongest zone gust: grass tips 0.12 m, foliage 0.09 m (see NatureKit.chunk_bounds).
						for dx in [-0.12, 0.12]:
							for dz in [-0.08, 0.08]:
								var displaced := Vector3(x + dx, y, z + dz)
								var world_point: Vector3 = placement * model_xform * displaced
								check(bounds.has_point(world_point), "transformed windy corner remains visible")
		check(bounds.get_volume() < 52.0 * 80.0 * 52.0, "a sparse chunk drops empty culling volume")
	var empty := NatureKit.chunk_bounds(mesh, transforms, [], Vector3(18, 10, 18))
	check(empty.size == Vector3.ZERO, "empty chunk has no geometry bounds")
	Scenery.ground(self, 130.0, Color("607f61"), Color("779265"))
	var floor_mesh := get_node("Ground") as MeshInstance3D
	var arrays := floor_mesh.mesh.surface_get_arrays(0)
	check((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() == 105 * 105, "terrain shares identical neighbouring corners")
	check((arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() == 104 * 104 * 6, "terrain retains every triangle")
	check(floor_mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "flat floor skips shadow casting")
	var floor_body := get_node("Floor") as StaticBody3D
	check((floor_body.get_child(0) as CollisionShape3D).shape is WorldBoundaryShape3D, "flat floor collision remains unchanged")
	print("SCENERY BOUNDS: %s | %d checks, %d failures" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	get_tree().quit(failures.size())
