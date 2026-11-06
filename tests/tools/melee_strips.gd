extends Node3D
## Frame strips of the Warrior / Lancer / Defender skills through the real cast
## path (Hero._cast with live mobs): one PNG per skill, a 3x2 grid of the wind-up
## and five moments after the release. For before/after art reviews.
## xvfb-run -a godot --rendering-driver opengl3 --audio-driver Dummy --path . res://tests/tools/melee_strips.tscn -- OUT_DIR SPEC [q=0..2] [p=0..2]
## SPEC: warrior | lancer | defender | stars | gods | all | id,id,...

const FRAME := Vector2i(560, 360)
var cam: Camera3D
var title: Label
var out_dir := ""
## "solo": hide every effect but the class layers (MeleeArt) to judge them alone.
var solo := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("Expected OUT_DIR SPEC [q=N] [p=N]")
		get_tree().quit(1)
		return
	out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	Game.set_process(false)
	InputSetup.ensure_defaults()
	GameSettings.load_settings()
	GameSettings.quality = 2
	var pressure := 0
	solo = "solo" in args
	for a in args.slice(2):
		if a.begins_with("q="): GameSettings.quality = int(a.substr(2))
		if a.begins_with("p="): pressure = int(a.substr(2))
	MemoryGuard.force(pressure, get_tree())
	# Software rendering is slow: a slowed clock keeps the captures on their marks.
	Engine.time_scale = 0.25
	get_window().size = FRAME * 2
	get_window().content_scale_size = FRAME * 2
	Scenery.environment(self, Color("6d91ac"), Color("7f9b9c"), Color("d3e5f0"), Color("ffedda"))
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120, 120)
	ground.mesh = plane
	ground.material_override = MeshKit.toon(Color("526e60"))
	add_child(ground)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(cam)
	cam.make_current()
	var layer := CanvasLayer.new()
	add_child(layer)
	title = Label.new()
	title.position = Vector2(14, 8)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 6)
	layer.add_child(title)
	for entry in _skills(args[1]):
		await _strip(entry[0], entry[1])
	Game.has_profile = false
	print("MELEE STRIPS DONE")
	get_tree().quit()


func _skills(spec: String) -> Array:
	var out: Array = []
	for cls in [&"warrior", &"lancer", &"defender"]:
		# The class pool carries the star skills after the levelled ones.
		for skill in ClassData.pool(cls):
			if not skill.has("star"):
				if spec in [String(cls), "all"] or String(skill.id) in spec.split(","):
					out.append([cls, skill])
				continue
			var god := StarSkillData.is_god(skill)
			if (spec in ["stars", "all"] and not god) or (spec in ["gods", "all"] and god) or String(skill.id) in spec.split(","):
				out.append([cls, skill])
	return out


func _profile(cls: StringName, stars: int) -> void:
	Game.new_profile(cls, "Melee Art QA")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile.paragon = {"level": stars, "points": stars, "spent": 0, "exp": 0, "alloc": {}}
	Game.profile.look = {"gender": 0}
	Game.profile.equip = {}
	for slot in ItemData.EQUIP_SLOTS:
		Game.profile.equip[slot] = (StarWingData.item(String(cls), Game.rng) if stars >= 100 else ItemData.wings(Game.rng, String(cls))) if slot == "wings" else StarProgression.item(cls, stars if stars in StarProgression.TIERS else 50, slot, Game.rng)
	Game.profile.hp = 100000
	Game.profile.mp = 100000
	Game.profile.party = []
	Game.fill_loadout()


func _strip(cls: StringName, skill: Dictionary) -> void:
	seed(4242)
	var star := skill.has("star")
	_profile(cls, 300 if star and StarSkillData.is_god(skill) else 200)
	var field := Node3D.new()
	add_child(field)
	var hero := Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	hero.position = Vector3.ZERO
	var spots := [Vector3(4.2, 0, 0), Vector3(7.0, 0, 0.6), Vector3(3.2, 0, -2.6), Vector3(2.4, 0, 2.8)]
	var mobs: Array[Mob] = []
	for spot in spots:
		var mob := Mob.new()
		mob.setup(&"eclipse_warrior", 100, spot, hero)
		mob.position = spot
		field.add_child(mob)
		mob.set_physics_process(false)
		mob.hp = 100000000
		mob.max_hp = mob.hp
		mobs.append(mob)
	hero.target = mobs[0]
	await get_tree().create_timer(0.25).timeout
	var radius := float(skill.get("radius", 3.0))
	var shape := String(skill.get("shape", "single"))
	var look_at := Vector3(2.2, 1.0, 0) if shape in ["single", "chain", "fan", "blast"] else Vector3(0.6, 1.0, 0)
	cam.size = (clampf(radius * 2.1, 8.5, 20.0) if shape in ["burst", "blast"] else 8.5) * (1.6 if star else 1.0)
	cam.position = look_at + Vector3(3.0, 11.0, 13.0)
	cam.look_at(look_at)
	title.text = "%s  %s" % [String(skill.id), "★%d" % int(skill.star) if star else "Lv.%d" % int(skill.get("level", 1))]
	Game.profile.mp = 100000
	hero.cooldowns.clear()
	var release := float(skill.hit_delay) * (1.0 if star else 1.0 - hero._haste())
	hero._cast(skill)
	var after: Array = [0.05, 0.16, 0.32, 0.55, 0.95]
	if star:
		after = [0.05, 0.3, 0.7, 1.2, 1.9]
	var marks: Array = [release * 0.7]
	for t in after:
		marks.append(release + float(t))
	var sheet := Image.create(FRAME.x * 3, FRAME.y * 2, false, Image.FORMAT_RGB8)
	var clock := 0.0
	for i in marks.size():
		var wait := float(marks[i]) - clock
		if wait > 0.0:
			await get_tree().create_timer(wait).timeout
			clock = float(marks[i])
		if solo:
			for child in field.get_children():
				if child is Node3D and not (child is Hero or child is Mob or child is MeleeArt):
					(child as Node3D).visible = false
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var frame := get_viewport().get_texture().get_image()
		frame.convert(Image.FORMAT_RGB8)
		frame.resize(FRAME.x, FRAME.y, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, FRAME), Vector2i((i % 3) * FRAME.x, (i / 3) * FRAME.y))
		if i == 0:
			title.text = ""
	sheet.save_png("%s/%s.png" % [out_dir, String(skill.id)])
	print("STRIP ", skill.id, " layers=", MeleeArt.built_layers, " parts=", MeleeArt.built_particles, " budget=", VfxBudget.counters(), " limit=", VfxBudget.decoration_limit())
	field.queue_free()
	await field.tree_exited
	await get_tree().process_frame
