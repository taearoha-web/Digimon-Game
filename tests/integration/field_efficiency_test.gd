extends Node3D
## Preserve gear geometry/materials and verify real monster dormancy/wakeup.
var checks := 0
var failures := 0
var summaries: Array[Dictionary] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func geometry(root: Node3D) -> Dictionary:
	var first := true
	var bounds := AABB()
	var surfaces := 0
	var triangles := 0
	var by_material := {}
	for mi in MeshKit.collect_meshes(root):
		var transform := MeshMerge._relative(mi, root)
		var box := transform * mi.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
		for i in mi.mesh.get_surface_count():
			surfaces += 1
			var arrays := mi.mesh.surface_get_arrays(i)
			var n := (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() if arrays[Mesh.ARRAY_INDEX] != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			triangles += n / 3
			var mat := mi.get_active_material(i)
			var key := mat.get_instance_id() if mat else 0
			by_material[key] = int(by_material.get(key, 0)) + n / 3
	return {"bounds": bounds, "surfaces": surfaces, "triangles": triangles, "materials": by_material}

func _ready() -> void:
	Game.set_process(false)
	GameSettings.load_settings()
	GameSettings.quality = 2
	for kind in WeaponKit.MODELS:
		for tier in 10:
			var raw := WeaponKit._model(kind, tier, false)
			var original := geometry(raw)
			MeshMerge.merge(raw, "test_%s_%d" % [kind, tier])
			var merged := geometry(raw)
			check(merged.triangles == original.triangles, "%s_%d triangle details preserved" % [kind, tier])
			check(merged.materials == original.materials, "%s_%d materials and color preserved" % [kind, tier])
			check((merged.bounds as AABB).is_equal_approx(original.bounds), "%s_%d bounds and grip preserved" % [kind, tier])
			check(int(merged.surfaces) <= int(original.surfaces), "%s_%d does not add draw surfaces" % [kind, tier])
			if tier == 9:
				summaries.append({"kind": kind, "before_surfaces": original.surfaces, "after_surfaces": merged.surfaces, "triangles": merged.triangles})
			raw.free()
	for tier in 10:
		var book := WeaponKit.book(tier, false)
		var original := geometry(book)
		MeshMerge.merge(book)
		check(geometry(book).triangles == original.triangles and geometry(book).materials == original.materials, "book tier %d preserves emblem geometry and materials" % tier)
		book.free()
	check(MeshMerge._cache.size() <= MeshMerge.CACHE_LIMIT, "gear cache bounded after more than sixty-four models")
	var live := WeaponKit.build("lantern_9")
	var before := geometry(live)
	MeshMerge.release_cache()
	check(MeshMerge._cache.is_empty() and geometry(live).triangles == before.triangles, "cache release keeps equipped meshes valid")
	live.free()
	var hero := Node3D.new()
	add_child(hero)
	var mob := Mob.new()
	mob.setup(&"pink_slime", 1, Vector3.ZERO, hero)
	add_child(mob)
	mob.set_dormant(true)
	check(mob.is_dormant() and not mob.visible and not mob.is_physics_processing() and mob.visual.process_mode == Node.PROCESS_MODE_DISABLED, "idle far monster stops rendering, physics and animation")
	mob.take_hit(1, false)
	check(not mob.is_dormant() and mob.visible and mob.is_physics_processing(), "hit wakes a sleeping monster")
	mob.set_dormant(true)
	check(not mob.is_dormant(), "active fight never sleeps")
	mob.hostile = false
	mob._returning = true
	mob.set_dormant(true)
	check(not mob.is_dormant(), "returning monster never sleeps")
	mob._returning = false
	mob.is_boss = true
	mob.set_dormant(true)
	check(not mob.is_dormant(), "boss never sleeps")
	mob.free()
	hero.free()
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		var report := FileAccess.open(args[0], FileAccess.WRITE)
		report.store_string(JSON.stringify({"checks": checks, "failures": failures, "models": summaries}, "\t"))
	print("FIELD EFFICIENCY: ", checks, " checks, ", failures, " failures; ", JSON.stringify(summaries))
	get_tree().quit(failures)
