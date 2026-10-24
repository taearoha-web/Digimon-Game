extends SceneTree
## Offline production step: godot --headless --path . -s res://tools/bake_weapon_poses.gd [-- FAMILY ...]
## With family names after "--" only those libraries are rebaked (e.g. a new class).


func _initialize() -> void:
	call_deferred("_bake")


func _bake() -> void:
	WeaponPoses.authoring = true
	var families: Array[StringName] = [ClassData.START]
	families.append_array(ClassData.IDS)
	var only := OS.get_cmdline_user_args()
	if not only.is_empty():
		families = families.filter(func(family: StringName) -> bool: return String(family) in only)
	var baked := 0
	for rig in 3:
		for family in families:
			var hero := HeroVisual.new()
			root.add_child(hero)
			hero.setup(family, "", true, {}, {} if rig == 2 else {"gender": rig})
			print("BAKED: rig %d / %s" % [rig, family])
			hero.free()
			baked += 1
	print("WEAPON POSES: %d rig/class libraries baked" % baked)
	quit()
