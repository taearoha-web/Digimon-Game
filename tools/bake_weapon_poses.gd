extends Node
## Offline production step: godot --headless --path . res://tools/bake_weapon_poses.tscn [-- FAMILY ... BODY ...]
## (a scene, not a -s script: heroes need the autoloads)
## With family names after "--" only those libraries are rebaked (e.g. a new class).
## Every hero body (ChibiBodies, both genders, and KayKit) gets its own libraries;
## with body names ("boy", "silver", "kaykit", ...) after "--" only those bodies are
## baked, and "new" bakes every body except the originals (boy, girl, kaykit).


func _ready() -> void:
	call_deferred("_bake")


func _bake() -> void:
	WeaponPoses.authoring = true
	var families: Array[StringName] = [ClassData.LEGACY]
	families.append_array(ClassData.IDS)
	var args := Array(OS.get_cmdline_user_args())
	var looks: Array = []
	for gender in 2:
		for body in ChibiBodies.count(gender):
			looks.append({"gender": gender, "body": body})
	looks.append({})
	var names := looks.map(func(look: Dictionary) -> String: return WeaponPoses.rig_name_of("" if look.is_empty() else ChibiBodies.path(look)))
	var only_families := families.filter(func(family: StringName) -> bool: return String(family) in args)
	if not only_families.is_empty():
		families = only_families
	var only_bodies: Array = args.filter(func(a: String) -> bool: return a in names or a == "new")
	var baked := 0
	for i in looks.size():
		var name: String = names[i]
		if not only_bodies.is_empty() and name not in only_bodies and not ("new" in only_bodies and name not in ["boy", "girl", "kaykit"]):
			continue
		for family in families:
			var hero := HeroVisual.new()
			add_child(hero)
			hero.setup(family, "", true, {}, looks[i])
			print("BAKED: %s / %s" % [name, family])
			hero.free()
			baked += 1
	print("WEAPON POSES: %d body/class libraries baked" % baked)
	get_tree().quit()
