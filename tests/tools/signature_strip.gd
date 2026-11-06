extends Node3D
## Frame strips of real casts (Hero._cast: wind-up, release, flight, contact,
## landing), one PNG per skill: five moments side by side, for reviewing the
## class signature art of the Archer, the Assassin and the Dark Lord.
##   godot --rendering-driver opengl3 --path . res://tests/tools/signature_strip.tscn -- OUT_DIR CLASS [ids,..|all|stars] [quality] [pressure]
## The times are fractions of the wind-up then seconds after the release.

const FRAME := Vector2i(640, 360)
const STRIP_SCALE := 0.75
const COLUMNS := 3

var cam: Camera3D
var title: Label


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("Expected OUT_DIR CLASS [ids]")
		get_tree().quit(1)
		return
	Game.set_process(false)
	InputSetup.ensure_defaults()
	GameSettings.load_settings()
	GameSettings.quality = int(args[3]) if args.size() > 3 else 2
	MemoryGuard.pressure = int(args[4]) if args.size() > 4 else 0
	get_window().size = FRAME
	get_window().content_scale_size = FRAME
	var out := args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var cls := StringName(args[1])
	Scenery.environment(self, Color("6d91ac"), Color("7f9b9c"), Color("d3e5f0"), Color("ffedda"))
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120, 120)
	ground.mesh = plane
	ground.material_override = MeshKit.toon(Color("526e60"))
	add_child(ground)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 15
	add_child(cam)
	cam.position = Vector3(4.5, 10, 14)
	cam.look_at(Vector3(0.3, 1.0, 0))
	cam.make_current()
	var layer := CanvasLayer.new()
	add_child(layer)
	title = Label.new()
	title.position = Vector2(12, 8)
	title.add_theme_font_size_override("font_size", 20)
	layer.add_child(title)
	var wanted := args[2] if args.size() > 2 else "all"
	var skills: Array = []
	for skill in ClassData.pool(cls):
		if wanted == "all" or (wanted == "stars" and skill.has("star")) or String(skill.id) in wanted.split(","):
			skills.append(skill)
	for skill in skills:
		await _strip(cls, skill, out)
	Game.has_profile = false
	get_tree().quit()


func _profile(cls: StringName) -> void:
	Game.new_profile(cls, "Signature QA")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile.paragon = {"level": 300, "points": 300, "spent": 0, "exp": 0, "alloc": {}}
	Game.profile.look = {"gender": 0}
	Game.profile.equip = {}
	for slot in ItemData.EQUIP_SLOTS:
		Game.profile.equip[slot] = StarWingData.item(String(cls), Game.rng) if slot == "wings" else StarProgression.item(cls, 200, slot, Game.rng)
	Game.profile.hp = 100000
	Game.profile.mp = 100000
	Game.profile.party = []
	Game.fill_loadout()


func _strip(cls: StringName, skill: Dictionary, out: String) -> void:
	_profile(cls)
	var field := Node3D.new()
	add_child(field)
	var hero := Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	hero.position = Vector3(-3.5, 0, 0.5)
	var mobs: Array = []
	for spot in [Vector3(3, 0, 0), Vector3(4.6, 0, -1.8), Vector3(4.4, 0, 1.9), Vector3(1.6, 0, -2.6), Vector3(1.8, 0, 2.6)]:
		var mob := Mob.new()
		mob.setup(&"forest_orc", 60, spot, hero)
		mob.position = spot
		field.add_child(mob)
		mob.set_physics_process(false)
		mob.hp = 100000000
		mob.max_hp = mob.hp
		mobs.append(mob)
	hero.target = mobs[0]
	await get_tree().create_timer(0.3).timeout
	var radius := float(skill.get("radius", 3.0))
	cam.size = clampf(radius * 1.7 + 4.0, 9.5, 19.0)
	var star := skill.has("star")
	var wind := float(skill.hit_delay)
	var times: Array = [wind * 0.4, wind * 0.85, wind + 0.08, wind + 0.24, wind + 0.5, wind + 0.95]
	if String(skill.get("special", "")) in ["rain", "meteor"]:
		times = [wind * 0.5, wind + 0.25, wind + 0.45, wind + 0.6, wind + 0.8, wind + 1.2]
	if star:
		times = [wind * 0.4, wind * 0.85, wind + 0.1, wind + 0.45, wind + 0.9, wind + 1.6]
	var strip := Image.create(int(FRAME.x * STRIP_SCALE) * COLUMNS, int(FRAME.y * STRIP_SCALE) * ceili(times.size() / float(COLUMNS)), false, Image.FORMAT_RGB8)
	var started := Time.get_ticks_msec()
	title.text = "%s  Lv.%d%s" % [skill.name, int(skill.get("level", 0)), ("  ★%d" % int(skill.star)) if star else ""]
	hero._cast(skill)
	for i in times.size():
		var wait := float(times[i]) - float(Time.get_ticks_msec() - started) / 1000.0
		if wait > 0.0:
			await get_tree().create_timer(wait).timeout
		await RenderingServer.frame_post_draw
		var frame := get_viewport().get_texture().get_image()
		frame.convert(Image.FORMAT_RGB8)
		frame.resize(int(FRAME.x * STRIP_SCALE), int(FRAME.y * STRIP_SCALE), Image.INTERPOLATE_BILINEAR)
		strip.blit_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), Vector2i((i % COLUMNS) * frame.get_width(), (i / COLUMNS) * frame.get_height()))
		if i == 2:
			print("  peak ", VfxBudget.counters(), " limit ", VfxBudget.decoration_limit())
	strip.save_png("%s/%s.png" % [out, String(skill.id)])
	print("STRIP ", skill.id, " ", VfxBudget.counters(), " layers ", SignatureKit.layers_built, " casts ", SignatureKit.casts)
	await get_tree().create_timer(2.5).timeout
	field.queue_free()
	await field.tree_exited
