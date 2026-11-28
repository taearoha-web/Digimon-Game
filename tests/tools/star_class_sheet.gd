extends Node3D
## One sheet per class of every star skill (StarSkillData: ★50..★300) and the Ascension's
## two (AscendSkillData: ★500), each cast for real by a Hero in full ★500 gear and caught
## at its peak.
##   xvfb-run godot --rendering-driver opengl3 --path . res://tests/tools/star_class_sheet.tscn -- OUT_DIR [class,class]
## Writes OUT_DIR/stars_<class>.png.
const TILE := Vector2i(640, 360)
const COLS := 4
const HEAD := 64

var cam: Camera3D
var title: Label


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0]
	var only: PackedStringArray = args[1].split(",") if args.size() > 1 else PackedStringArray()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Game.set_process(false)
	InputSetup.ensure_defaults()
	GameSettings.load_settings(); GameSettings.quality = 2
	get_window().size = Vector2i(1280, 720); get_window().content_scale_size = Vector2i(1280, 720)
	Scenery.environment(self, Color("6d91ac"), Color("7f9b9c"), Color("d3e5f0"), Color("ffedda"))
	var ground := MeshInstance3D.new(); var plane := PlaneMesh.new(); plane.size = Vector2(160, 160)
	ground.mesh = plane; ground.material_override = MeshKit.toon(Color("526e60")); add_child(ground)
	cam = Camera3D.new(); cam.fov = 40.0; add_child(cam); cam.make_current()
	var layer := CanvasLayer.new(); add_child(layer)
	title = Label.new(); title.position = Vector2(24, 14)
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color("fff1cf"))
	title.add_theme_color_override("font_outline_color", Color("1b1b24"))
	title.add_theme_constant_override("outline_size", 12)
	layer.add_child(title)
	for cls in ClassData.IDS:
		if not StarSkillData.IDS.has(cls) or (not only.is_empty() and not String(cls) in only):
			continue
		var skills: Array = StarSkillData.pool(cls) + AscendSkillData.pool(cls)
		var frames: Array[Image] = []
		for skill in skills:
			frames.append(await _shot(cls, skill))
		var rows := int(ceil(float(frames.size()) / COLS))
		var sheet := Image.create(TILE.x * COLS, HEAD + TILE.y * rows, false, Image.FORMAT_RGBA8)
		sheet.fill(Color("1e2a33"))
		for i in frames.size():
			sheet.blit_rect(frames[i], Rect2i(Vector2i.ZERO, TILE), Vector2i((i % COLS) * TILE.x, HEAD + (i / COLS) * TILE.y))
		# Header strip: the class's name, drawn by a label shot of its own.
		title.text = "สกิลดาว • %s" % String(ClassData.get_class_data(cls).name)
		var hdr := await _label_strip()
		sheet.blit_rect(hdr, Rect2i(0, 0, mini(hdr.get_width(), sheet.get_width()), HEAD), Vector2i.ZERO)
		var path := "%s/stars_%s.png" % [out_dir, cls]
		print("SHEET ", path, " ", sheet.save_png(path))
	Game.has_profile = false
	get_tree().quit()


func _profile(cls: StringName) -> void:
	Game.new_profile(cls, "Star QA")
	Game.profile.level = 100
	Game.profile.adv = JobData.ASCEND_ADV
	Game.profile.paragon = {"level": 500, "points": 500, "spent": 0, "exp": 0, "alloc": {}}
	Game.profile.look = {"gender": 1 if cls in [&"mage", &"priest", &"summoner", &"bard"] else 0}
	Game.profile.equip = {}
	for slot in Star500Gear.SLOTS:
		Game.profile.equip[slot] = Star500Gear.item(String(cls), slot)
	Game.profile.equip["weapon"]["plus"] = 15
	Game.profile.hp = 1000000; Game.profile.mp = 1000000
	Game.profile.party = []
	Game.fill_loadout()


## The moment to catch: a god skill's waves, a summon or a form once it is out, a buff's glow.
func _peak(skill: Dictionary) -> float:
	var d := float(skill.hit_delay)
	var id := String(skill.id)
	if skill.has("companion") or skill.has("summon") or ThotsakanForm.handles(skill):
		return d + 1.6
	if String(skill.shape) == "self":
		# The Ascension's buff opens with its name banner (cut-in): catch it once gone.
		return d + (0.85 if AscendSkillData.is_ascend(skill) else 0.35)
	if AscendSkillData.is_finisher(skill):
		return d + 0.12
	# ดาบเหินฟ้า: its foes in the air, mid-slash; หอกพายุบูมเมอแรง: the storm on its way out.
	if id == "emperor_heavensword":
		return d + 0.74
	if id == "dragon_emperor_lance":
		return d + 0.42
	# เทวทูตคุ้มชีวิต: the angel just landed in its burst; หลอมรวมอสูร: the chimera rearing.
	if id == "eternal_dawn_judgment":
		return d + 0.68
	if id == "primordial_beast_court":
		return d + 1.6
	# กำแพงโล่ถล่ม: the wall mid-drive, carrying its foes; ประหารเลือดพร่อง: the one slash.
	if id == "eternal_bastion_fall":
		return d + 1.05
	if id == "timeless_night_execution":
		return d + 0.58
	# เลนส์ตะวัน: the beam burning its line; ประตูมิติร้อยบาน: the portals mid-volley.
	if id == "starfall_emperor_arrow":
		return d + 1.4
	if id == "cosmos_genesis":
		return d + 1.15
	# สัญญาโลหิต: the blood moon swelling over the thorns; ระบำสะกดใจ: the foes mid-dance.
	if id == "heaven_hell_sovereign":
		return d + 1.55
	if id == "universe_hymn":
		return d + 1.2
	if StarSkillData.is_god(skill):
		return d + 0.7
	if id == "celestial_swordfall":
		return d + 0.9
	return d + 0.35


func _shot(cls: StringName, skill: Dictionary) -> Image:
	_profile(cls)
	var field := Node3D.new(); add_child(field)
	var hero := Hero.new(); hero.field = field; field.add_child(hero)
	hero.set_physics_process(false); hero.position = Vector3(-2, 0, 1)
	var mobs: Array = []
	for p in [Vector3(2.5, 0, -1), Vector3(4.5, 0, 1.5), Vector3(1.0, 0, -3.5)]:
		var mob := Mob.new(); mob.setup(&"eclipse_warrior", 100, p, hero); mob.position = p
		field.add_child(mob); mob.set_physics_process(false)
		mob.hp = 100000000; mob.max_hp = mob.hp
		mobs.append(mob)
	hero.target = mobs[0]
	# The fusion (หลอมรวมอสูร) feeds the summons out: give it the two legends.
	if String(skill.id) == "primordial_beast_court":
		for id in ["moonwolf_pact", "eclipse_sovereign"]:
			hero._summon(ClassData.find_skill(cls, id), 1.0)
	await get_tree().create_timer(0.15).timeout
	Game.profile.mp = 1000000
	var star := int(skill.star)
	title.text = "★%d  %s" % [star, String(skill.name)]
	var far := 21.0 if star >= 300 or skill.has("companion") else 16.0
	cam.position = Vector3(0, 0.62, 1.0).normalized() * far + Vector3(0, 0.5, 0); cam.look_at(Vector3(0, 1.0, -0.4))
	hero._cast(skill)
	await get_tree().create_timer(_peak(skill)).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(TILE.x, TILE.y, Image.INTERPOLATE_LANCZOS)
	field.queue_free(); await field.tree_exited
	await get_tree().process_frame
	return img


## The title alone over a plain backdrop, for the sheet's header.
func _label_strip() -> Image:
	var bg := ColorRect.new(); bg.color = Color("1e2a33"); bg.size = Vector2(1280, 720)
	var layer := title.get_parent()
	layer.add_child(bg); layer.move_child(bg, 0)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	bg.queue_free()
	return img.get_region(Rect2i(0, 0, 1280, HEAD))
