extends Node
## Which static caches keep video memory alive after leaving a zone? Visits zones, returns to
## town, then empties each cache in turn and prints the video memory freed by it.
##   xvfb-run godot --rendering-driver opengl3 --path . res://tests/tools/retained_video_probe.tscn -- meadow,dawn_forest,lotus_sanctum
var main: Node


func _v() -> float:
	return Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0


func _settle() -> void:
	for i in 6:
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout


func _ready() -> void:
	GameSettings.load_settings()
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	Game.delete_save()
	Game.new_profile(&"warrior", "V", FaceKit.default_look())
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.paragon().level = 200
	main.title_screen.queue_free()
	main.title_screen = null
	await main.go(&"town", true)
	await _settle()
	print("VIDEO town first %.1f MB" % _v())
	var args := OS.get_cmdline_user_args()
	var zones := (args[0] if args.size() > 0 else "meadow,dawn_forest,lotus_sanctum").split(",")
	for id in zones:
		await main.go(StringName(id), true)
		await get_tree().create_timer(2.0).timeout
		print("VIDEO in %s %.1f MB" % [id, _v()])
		await main.go(&"town", true)
		await _settle()
		print("VIDEO town after %s %.1f MB" % [id, _v()])
	var caches := {
		"StarRegionArt._meshes": StarRegionArt._meshes, "StarRegionArt._materials": StarRegionArt._materials,
		"StarMonsterArt._meshes": StarMonsterArt._meshes, "StarMonsterArt._materials": StarMonsterArt._materials,
		"Scenery._prop_meshes": Scenery._prop_meshes, "RegionArt._water_mats": RegionArt._water_mats,
		"JapanKit._arrays": JapanKit._arrays, "MeshKit._meshes": MeshKit._meshes,
		"VfxArt._tex": VfxArt._tex, "VfxArt._art_meshes": VfxArt._art_meshes, "VfxArt._spiral_meshes": VfxArt._spiral_meshes,
		"VfxKit._flight_meshes": VfxKit._flight_meshes, "VfxKit._textured_quads": VfxKit._textured_quads,
		"SpellSpectacle._meshes": SpellSpectacle._meshes, "EliteSkillArt._meshes": EliteSkillArt._meshes,
		"SkillTableau._creatures": SkillTableau._creatures, "BuffArt._meshes": BuffArt._meshes,
		"ShaderBurst._meshes": ShaderBurst._meshes, "ThunderStormArt._bolt_meshes": ThunderStormArt._bolt_meshes,
		"SkillInk._meshes": SkillInk._meshes, "WeaponPoses._libraries": WeaponPoses._libraries,
		"HeroPortrait._textures": HeroPortrait._textures, "SkillIcons._textures": SkillIcons._textures,
	}
	for name in caches:
		var dict: Dictionary = caches[name]
		var before := _v()
		var n := dict.size()
		dict.clear()
		await _settle()
		print("RELEASE %-30s entries=%4d freed %.1f MB" % [name, n, before - _v()])
	MaterialKeeper._ring.clear()
	MaterialKeeper._pinned.clear()
	var b := _v()
	await _settle()
	print("RELEASE MaterialKeeper freed %.1f MB" % (b - _v()))
	print("VIDEO town end %.1f MB" % _v())
	get_tree().quit()
