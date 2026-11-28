extends Node3D
## Screenshots of two ★500 buffs (AscendBuffsB): the Summoner's Titan (พันธสัญญาไททัน)
## beside its summoner, and dark fire (เพลิงมืดเผาผลาญ) burning on a monster the Dark Lord hit.
## Into ASCEND_SHOTS (env) or user://.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path . res://tools/ascend_buffs_b_shots.tscn

var cam: Camera3D
var title: Label
var out := ""


func _profile(cls: StringName) -> void:
	Game.new_profile(cls, "เทวาลัย", FaceKit.default_look())
	Game.profile.level = 100
	Game.profile.adv = JobData.ASCEND_ADV
	Game.profile.paragon = {"level": 500, "points": 0, "spent": 300, "exp": 0, "alloc": {}}
	Game.profile.equip = {}
	for slot in ItemData.EQUIP_SLOTS:
		var piece := Star500Gear.item(String(cls), slot)
		if not piece.is_empty():
			Game.profile.equip[slot] = piece
	Game.profile.hp = 1000000
	Game.profile.mp = 1000000
	Game.profile.party = []
	Game.fill_loadout()


func _capture(file: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(file + ".png"))
	print("CAPTURE ", out.path_join(file + ".png"))


func _ready() -> void:
	out = OS.get_environment("ASCEND_SHOTS")
	if out == "":
		out = "user://"
	DirAccess.make_dir_recursive_absolute(out)
	Game.set_process(false)
	InputSetup.ensure_defaults()
	GameSettings.load_settings()
	GameSettings.quality = 2
	get_window().size = Vector2i(1280, 720)
	get_window().content_scale_size = Vector2i(1280, 720)
	Scenery.environment(self, Color("5a7aa0"), Color("a8c8e8"), Color("f0f8ff"), Color("ffe8c0"))
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(140, 140)
	ground.mesh = plane
	ground.material_override = MeshKit.toon(Color("9fb48a"))
	add_child(ground)
	cam = Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	cam.make_current()
	var layer := CanvasLayer.new()
	add_child(layer)
	title = Label.new()
	title.position = Vector2(22, 16)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_outline_color", Color("1a1030"))
	title.add_theme_constant_override("outline_size", 6)
	layer.add_child(title)
	await _titan()
	await _dark_fire()
	Game.has_profile = false
	get_tree().quit()


func _titan() -> void:
	_profile(&"summoner")
	var hero := Hero.new()
	hero.field = self
	add_child(hero)
	hero.set_physics_process(false)
	hero.refresh_stats()
	hero.set_facing(0.0)
	var skill := ClassData.find_skill(&"summoner", "covenant_of_beasts")
	hero.receive_buff(skill.fx.buff, skill.color, skill.name, false, skill.id)
	var titan := AscendBuffsB.call_titan(hero, 60.0)
	titan.set_process(false)
	await get_tree().create_timer(0.6).timeout
	titan.global_position = hero.global_position + Vector3(3.2, 0, -0.6)
	titan.rotation.y = 0.0
	cam.position = hero.global_position + Vector3(1.6, 4.2, 11.0)
	cam.look_at(hero.global_position + Vector3(1.6, 2.2, 0))
	title.text = "พันธสัญญาไททัน — ไททันยักษ์เคียงข้างผู้อัญเชิญ"
	await get_tree().create_timer(0.5).timeout
	await _capture("titan_beside_summoner")
	var tv := (titan as Summon)._visual
	tv.action("attack", 900)
	await get_tree().create_timer(0.22).timeout
	await _capture("titan_slam_windup")
	hero.queue_free()
	titan.queue_free()
	await get_tree().process_frame


func _dark_fire() -> void:
	_profile(&"darklord")
	var hero := Hero.new()
	hero.field = self
	add_child(hero)
	hero.set_physics_process(false)
	hero.refresh_stats()
	var skill := ClassData.find_skill(&"darklord", "crown_of_dual_realms")
	hero.receive_buff(skill.fx.buff, skill.color, skill.name, false, skill.id)
	var mob := Mob.new()
	mob.setup(&"forest_orc", 100, hero.global_position + Vector3(0, 0, -3.0), hero)
	add_child(mob)
	mob.set_physics_process(false)
	mob.global_position = hero.global_position + Vector3(0, 0, -3.0)
	mob.hp = 100000000
	mob.max_hp = 100000000
	await get_tree().process_frame
	hero.set_facing(PI)
	hero._deal(mob, 0.01, Color.WHITE, &"slash", false)
	cam.position = mob.global_position + Vector3(4.5, 2.4, -4.5)
	cam.look_at(mob.global_position + Vector3(0, 1.1, 0))
	title.text = "เพลิงมืดเผาผลาญ — ศัตรูติดเพลิงมืด รับดาเมจ +15%% (x%.2f)" % mob.taken_mult()
	await get_tree().create_timer(0.7).timeout
	await _capture("dark_fire_on_mob")
	hero.queue_free()
	mob.queue_free()
	await get_tree().process_frame
