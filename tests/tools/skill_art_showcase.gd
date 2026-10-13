extends Node3D
## Actual Hero._cast footage and stills on a deterministic field. Does not use
## the user's saves. Optional Godot --write-movie captures the same live casts.
## godot --path . res://tests/tools/skill_art_showcase.tscn -- OUT_DIR [ids,comma,separated] [late]
class Dummy extends Mob:
	var hits := 0
	func take_hit(amount: int, critical: bool, color := Color.WHITE, attacker: Node = null) -> bool:
		hits += 1
		return super.take_hit(amount, critical, color, attacker)
	func knock_back(_from: Vector3, _strength := 2.5) -> void:
		pass

var camera: Camera3D
var title: Label
var subtitle: Label
var out_dir := ""
var records: Array[Dictionary] = []

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	Game.set_process(false)
	GameSettings.load_settings()
	GameSettings.quality = 2
	GameSettings.combat_hitstop = false
	get_window().size = Vector2i(960, 540)
	get_window().content_scale_size = Vector2i(960, 540)
	seed(707)
	Scenery.environment(self, Color("789bba"), Color("adc2c6"), Color("d9e5f0"), Color("ffe4bf"))
	var paths: Array[PackedVector2Array] = [PackedVector2Array([Vector2(-30, 0), Vector2(0, 0), Vector2(30, 3)])]
	Scenery.ground(self, 60.0, Color("607f61"), Color("779265"), 912, Color("a59f7e"), paths, 2.5, [Vector3.ZERO], &"meadow")
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12
	add_child(camera)
	camera.position = Vector3(8, 9, 14)
	camera.look_at(Vector3(0, 2.0, 0))
	camera.make_current()
	var layer := CanvasLayer.new()
	add_child(layer)
	title = Label.new()
	title.position = Vector2(28, 20)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_shadow_color", Color("283540"))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(title)
	subtitle = Label.new()
	subtitle.position = Vector2(30, 55)
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color("fff2cb"))
	subtitle.add_theme_color_override("font_shadow_color", Color("283540"))
	subtitle.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(subtitle)
	var selected := ["grand_cross", "gladiator", "phoenix_shot", "meteor_arrow", "watornado", "ice_storm", "last_judgement", "spirit_cat", "world_tree", "elder_dragon", "ragnarok_lance", "armageddon"]
	if args.size() > 1 and args[1] != "late":
		selected = Array(args[1].split(","))
	for id in selected:
		for family in ClassData.IDS:
			var skill := ClassData.find_skill(family, id)
			if not skill.is_empty():
				await _case(family, skill)
	var file := FileAccess.open(out_dir.path_join("showcase.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": ProjectSettings.get_setting("application/config/version"), "casts": records}, "\t"))
	print("SKILL ART SHOWCASE: %d real casts captured" % records.size())
	get_tree().quit()

func _case(family: StringName, skill: Dictionary) -> void:
	Game.new_profile(family, "Skill Art QA", {"gender": 1 if family in [&"mage", &"priest", &"summoner"] else 0})
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.paragon().level = int(skill.get("star", 0))
	Game.profile.skills[String(skill.id)] = 1
	Game.profile.loadout[0] = String(skill.id)
	Game.profile.hp = 100000
	Game.profile.mp = 100000
	var field := Node3D.new()
	add_child(field)
	var hero := Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	hero.stats.atk = 100.0
	hero.stats.crit = 0.0
	hero.stats.haste = 0.0
	hero.position = Vector3(-2.2, 0, 1)
	var mob := Dummy.new()
	mob.setup(&"forest_orc", 100, Vector3.ZERO, hero)
	field.add_child(mob)
	mob.position = Vector3(2, 0, 0)
	mob.hp = 10000000
	mob.max_hp = 10000000
	mob.stats.def = 0.0
	mob.set_physics_process(false)
	hero.target = mob
	hero.set_facing(atan2(mob.position.x - hero.position.x, mob.position.z - hero.position.z))
	camera.size = 15.0 if bool(SkillShow.profile_for(skill).ultimate) else 12.0
	title.text = "TOON TALE  /  " + String(skill.name)
	subtitle.text = String(family).capitalize() + "  ·  Art & motion / High quality"
	VfxKit.warm_shaders(field, Vector3.ZERO)
	await get_tree().create_timer(0.45).timeout
	SkillShow._recent_shows.clear()
	hero._cast(skill)
	var delay := float(skill.hit_delay)
	await get_tree().create_timer(delay * 0.75).timeout
	await _capture(String(skill.id) + "-windup")
	var impact_wait := 0.18
	if String(skill.id) == "armageddon":
		impact_wait = 1.48
	elif String(skill.get("special", "")) in ["meteor", "rain"]:
		impact_wait = 0.72
	await get_tree().create_timer(delay * 0.25 + impact_wait).timeout
	await _capture(String(skill.id))
	if "late" in OS.get_cmdline_user_args():
		# Projectiles land after the release frame: a second still at contact.
		await get_tree().create_timer(0.28).timeout
		await _capture(String(skill.id) + "-late")
	await get_tree().create_timer(5.4 if String(skill.id) == "armageddon" else 1.0).timeout
	records.append({"class": String(family), "skill": String(skill.id), "hits_on_dummy": mob.hits})
	field.queue_free()
	await field.tree_exited
	await get_tree().process_frame

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(label + ".png"))
