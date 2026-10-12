extends Node3D
## Count actual meshes, not only reservations: an untracked decoration must fail.
## Covers saturation, delayed ice shatter, zone exit, and natural expiry on all
## three quality settings, while preserving essential projectile silhouettes.
## godot --headless --path . res://tests/integration/element_fx_budget_test.tscn

var failures: Array[String] = []
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

func meshes(node: Node) -> int:
	var total := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		total += meshes(child)
	return total

func _ready() -> void:
	await get_tree().process_frame
	GameSettings.load_settings()
	VfxArt.warm_up()
	var saved_quality := GameSettings.quality
	var factories: Array[Callable] = [
		func(p): ElementFx.flame(p, Vector3.ZERO, 1.0, 2.0),
		func(p): ElementFx.fire_field(p, Vector3.ZERO, 4.0, 4),
		func(p): ElementFx.flame_hit(p, Vector3.UP),
		func(p): ElementFx.flame_puff(p, Vector3.UP),
		func(p): ElementFx._heat_glow(p, Vector3.ZERO, 3.0),
		func(p): ElementFx._scorch(p, Vector3.ZERO, 3.0),
		func(p): ElementFx.crystal(p, Vector3.ZERO, 1.0, 2.0, Vector3.ZERO),
		func(p): ElementFx.shatter(p, Vector3.UP, 1.0, 150),
		func(p): ElementFx.ice_field(p, Vector3.ZERO, 4.0, 4),
		func(p): ElementFx.ice_hit(p, Vector3.UP),
		func(p): ElementFx._frost(p, Vector3.ZERO, 3.0),
		func(p): ElementFx.vine(p, Vector3.ZERO, 1.0, 2.0),
		func(p): ElementFx.vine_field(p, Vector3.ZERO, 4.0, 4),
		func(p): ElementFx.vine_bind(p, Vector3.UP),
		func(p): ElementFx._dirt(p, Vector3.ZERO, 3.0),
		func(p): ElementFx._grow(p, ElementFx.sprout_mesh(2.0, Color.PINK), Vector3.ZERO, 0.7),
		func(p): ElementFx.plant_field(p, Vector3.ZERO, 4.0, "tree", 4),
		func(p): ElementFx.plant_field(p, Vector3.ZERO, 4.0, "spores", 4),
		func(p): ElementFx.plant_field(p, Vector3.ZERO, 4.0, "sprouts", 4),
		func(p): ElementFx._mushroom(p, Vector3.ZERO, 1.4, 0.0),
		func(p): ElementFx.warm(p, Vector3.ZERO),
	]
	for quality in 3:
		GameSettings.quality = quality
		for i in factories.size():
			var sample := Node3D.new()
			add_child(sample)
			factories[i].call(sample)
			var drawn := meshes(sample)
			check(drawn > 0, "effect %d quality %d has a silhouette" % [i, quality])
			check(drawn == int(VfxBudget.counters().decorations), "every effect %d quality %d mesh is tracked" % [i, quality])
			check(drawn <= VfxBudget.decoration_limit(), "effect %d quality %d bounded" % [i, quality])
			sample.queue_free()
			await sample.tree_exited
			check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "effect exit reservations %d q%d" % [i, quality])
		var saturated := Node3D.new()
		add_child(saturated)
		for i in VfxBudget.decoration_limit():
			ElementFx.flame(saturated, Vector3.ZERO, 1.0, 2.0, 1.5)
		var before := meshes(saturated)
		for i in factories.size():
			factories[i].call(saturated)
			check(meshes(saturated) == before, "saturated primitive %d q%d cannot allocate" % [i, quality])
		var carrier := Node3D.new()
		saturated.add_child(carrier)
		ElementFx.ice_lance(carrier, 0.5)
		ElementFx.leaf_swirl(carrier, 0.5)
		check(meshes(carrier) == 4, "essential projectile bodies survive saturated decorations")
		saturated.queue_free()
		await saturated.tree_exited
		check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "saturated exit reservations")
		var delayed := Node3D.new()
		add_child(delayed)
		for i in VfxBudget.decoration_limit():
			ElementFx.crystal(delayed, Vector3.ZERO, 1.0, 2.0, Vector3.ZERO, 0.06)
		for frame in 24:
			await get_tree().create_timer(0.035).timeout
			check(meshes(delayed) <= VfxBudget.decoration_limit(), "delayed crystal shards stay bounded q%d" % quality)
		await get_tree().create_timer(1.3).timeout
		check(meshes(delayed) == 0, "crystals and delayed shards expire naturally")
		check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "natural crystal expiry reservations")
		delayed.queue_free()
		await delayed.tree_exited
		# Natural expiry must release reservations without needing zone removal.
		var garden := Node3D.new()
		add_child(garden)
		ElementFx.flame(garden, Vector3.ZERO, 1.0, 2.0)
		ElementFx._scorch(garden, Vector3.ZERO, 2.0)
		ElementFx._heat_glow(garden, Vector3.ZERO, 2.0)
		ElementFx._frost(garden, Vector3.ZERO, 2.0)
		ElementFx._dirt(garden, Vector3.ZERO, 2.0)
		ElementFx.vine(garden, Vector3.ZERO, 0.7, 2.0, 0.5)
		ElementFx._grow(garden, ElementFx.sprout_mesh(2.0, Color.PINK), Vector3.ZERO, 0.5)
		ElementFx._mushroom(garden, Vector3.ZERO, 1.2, 0.05)
		ElementFx.warm(garden, Vector3.ZERO)
		await get_tree().create_timer(2.7).timeout
		check(garden.get_child_count() == 0, "mixed elements expire all child nodes q%d" % quality)
		check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "natural mixed expiry reservations")
		garden.queue_free()
		await garden.tree_exited
	GameSettings.quality = saved_quality
	print("ELEMENT BUDGET: %s | %d checks, %d failures" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	get_tree().quit(failures.size())
