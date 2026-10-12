extends SceneTree
func _initialize() -> void:
	call_deferred("bake")
func bake() -> void:
	WeaponPoses.authoring=true
	for rig in 3:
		var hero := HeroVisual.new()
		root.add_child(hero)
		hero.setup(&"lancer","",true,{},{} if rig==2 else {"gender":rig})
		print("MARTIAL POSES BAKED: ",rig)
		hero.free()
	quit()
