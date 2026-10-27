extends Node3D
## The Bard in its gear, playing its lute: the lutes of Lv.10, Lv.50 and Lv.100 held in
## the idle, the attack, the stance, the cheer and the long cast; the 200-star star set
## and the divine set with the Lv.100 wings and with the star wings (front and back); a
## close-up of the face over the lute; every lute side by side (ten tiers, the divine
## lute and the four star lutes); and the character select with four Bards.
##   godot --rendering-driver opengl3 --path . res://tests/tools/bard_preview.tscn -- OUT_DIR [MODE tiers|sets|close|lutes|title] [RIG 0|1|2] [STYLE 0-2]
## RIG 0 is the chibi boy, 1 the chibi girl, 2 the KayKit body (world players).
## Writes bard_<mode>_rig<RIG>_s<STYLE>_<shot>.png. Run "title" with an isolated
## XDG_DATA_HOME: it writes and deletes the save slots.

const CLIPS := [["Idle", 0.25], ["Spellcast_Shoot", 0.41], ["Spellcasting", 0.3], ["Cheer", 0.5], ["Spellcast_Long", 0.55], ["Running_A", 0.3]]
const BARD := &"bard"

var out_dir := ""
var rig := 0
var style := 0
var rng := RandomNumberGenerator.new()
var camera: Camera3D


func _ready() -> void:
	Game.set_process(false)
	GameSettings.quality = 2
	get_window().size = Vector2i(1280, 720)
	var args := OS.get_cmdline_user_args()
	if args.size() > 1 and args[1] == "title":
		out_dir = args[0]
		await _title()
		get_tree().quit()
		return
	var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color("cfeaff")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.95, 0.97, 1.0); e.ambient_light_energy = 0.75
	var we := WorldEnvironment.new(); we.environment = e; add_child(we)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-35, 20, 0); l.light_energy = 0.95; add_child(l)
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(30, 30); g.mesh = pm
	g.material_override = MeshKit.toon(Color("9fdc8c")); add_child(g)
	out_dir = args[0]
	var mode := args[1] if args.size() > 1 else "tiers"
	rig = int(args[2]) if args.size() > 2 else 0
	style = int(args[3]) if args.size() > 3 else 0
	rng.seed = 7
	camera = Camera3D.new(); add_child(camera); camera.fov = 34
	match mode:
		"sets": await _sets()
		"close": await _close()
		"lutes": await _lutes()
		_: await _tiers()
	get_tree().quit()


func _look() -> Dictionary:
	if rig == 2:
		return {}
	var look := FaceKit.default_look()
	look["gender"] = rig
	ChibiLook.apply_style(look, style)
	return look


func _hero(equip: Dictionary, at: Vector3, yaw := 15.0) -> HeroVisual:
	var h := HeroVisual.new(); add_child(h)
	h.setup(BARD, "", true, equip, _look())
	h.position = at
	h.rotation_degrees.y = yaw
	return h


func _pose(h: HeroVisual, clip: String, phase: float) -> void:
	h.release()
	h.play(clip, 0.0)
	h.anim.seek(h.anim.get_animation(h.current).length * phase, true)
	h.anim.pause()


func _shot(name: String) -> void:
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/bard_%s.png" % [out_dir, name])


func _clear(nodes: Array) -> void:
	for n in nodes:
		(n as Node).queue_free()
	await get_tree().process_frame


func _weapon(level: int) -> Dictionary:
	var item := ItemData.generate(level, BARD, rng, 2, "weapon")
	item["plus"] = 0
	return item


## Lv.10, Lv.50 and Lv.100 lutes side by side, in each clip.
func _tiers() -> void:
	camera.position = Vector3(0, 1.35, 6.4); camera.rotation_degrees = Vector3(-5, 0, 0)
	var weapons := [_weapon(10), _weapon(50), _weapon(100)]
	for clip in CLIPS:
		var heroes: Array = []
		for i in 3:
			var h := _hero({"weapon": weapons[i]}, Vector3((i - 1) * 1.75, 0, 0))
			_pose(h, clip[0], clip[1])
			heroes.append(h)
		await _shot("tiers_rig%d_s%d_%s" % [rig, style, clip[0]])
		await _clear(heroes)


## The 200-star star set, the divine set with the Lv.100 wings and with the star
## wings, from the front and from the back.
func _sets() -> void:
	var star := {}
	for slot in ["weapon", "armor", "helm", "boots", "ring", "amulet"]:
		star[slot] = StarProgression.item(BARD, 200, slot, rng)
	var divine := {}
	for slot in ["weapon", "armor", "helm", "boots"]:
		divine[slot] = DivineGearData.item(BARD, slot, rng)
	var with_wings := divine.duplicate(); with_wings["wings"] = ItemData.wings(rng, String(BARD), 3)
	var with_star := divine.duplicate(); with_star["wings"] = StarWingData.item(String(BARD), rng, 4)
	var star_wings := star.duplicate(); star_wings["wings"] = StarWingData.item(String(BARD), rng, 4)
	for view in ["front", "back"]:
		for clip in [["Idle", 0.25], ["Spellcast_Shoot", 0.41], ["Cheer", 0.5]]:
			if view == "back" and clip[0] != "Idle":
				continue
			var heroes: Array = []
			var sets := [star, with_wings, with_star]
			for i in 3:
				var h := _hero(sets[i], Vector3((i - 1) * 3.3, 0, 0), 15.0 if view == "front" else 180.0)
				h.set_wing_mode(HeroVisual.WING_STAND, true)
				heroes.append(h)
			await get_tree().process_frame
			for h in heroes:
				_pose(h, clip[0], clip[1])
			if view == "front":
				camera.position = Vector3(0, 1.7, 11.0); camera.rotation_degrees = Vector3(-5, 0, 0)
			else:
				camera.position = Vector3(0, 1.9, 11.0); camera.rotation_degrees = Vector3(-6, 0, 0)
			await _shot("sets_rig%d_s%d_%s_%s" % [rig, style, view, clip[0]])
			await _clear(heroes)
	# The star set with the star wings, flying.
	var flyer := _hero(star_wings, Vector3(0, Hero.FLY_HEIGHT, 0), 20.0)
	flyer.set_wing_mode(HeroVisual.WING_FLY, true)
	camera.position = Vector3(0, 2.2, 5.6); camera.rotation_degrees = Vector3(-6, 0, 0)
	await get_tree().create_timer(0.8).timeout
	await _shot("sets_rig%d_s%d_starfly" % [rig, style])
	await _clear([flyer])


## One hero up close, three-quarter front (lutes of Lv.30, Lv.70 and Lv.100, the divine set):
## the face over the lute, the hands on the neck and the strings.
func _close() -> void:
	var gear := [{"weapon": _weapon(30)}, {"weapon": _weapon(70)}, {"weapon": _weapon(100)}]
	var divine := {}
	for slot in ["weapon", "armor", "helm", "boots"]:
		divine[slot] = DivineGearData.item(BARD, slot, rng)
	gear.append(divine)
	for i in gear.size():
		for clip in [["Idle", 0.25], ["Spellcast_Shoot", 0.41], ["Cheer", 0.5], ["Spellcasting", 0.3]]:
			var h := _hero(gear[i], Vector3.ZERO, 25.0)
			_pose(h, clip[0], clip[1])
			camera.position = Vector3(0.0, 1.55, 4.6); camera.rotation_degrees = Vector3(-4, 0, 0)
			await _shot("close_rig%d_s%d_%d_%s" % [rig, style, i, clip[0]])
			await _clear([h])


## The character select with four Bards (boy and girl; Lv.12, Lv.58, the star set and
## the divine set with the star wings), standing, then the second one cheering.
## Run with an isolated XDG_DATA_HOME: it writes and deletes the save slots.
func _title() -> void:
	for i in range(1, Game.SLOT_COUNT + 1):
		Game.delete_save(i)
	rng.seed = 7
	for i in 4:
		Game.slot = i + 1
		var look := FaceKit.default_look()
		look["gender"] = i % 2
		ChibiLook.apply_style(look, i % 3)
		Game.new_profile(BARD, ["ลิร่า", "Aria", "เมโลดี้", "Sonata"][i], look)
		Game.profile["level"] = [12, 58, 100, 100][i]
		Game.profile["adv"] = 4 if int(Game.profile.level) >= 80 else (2 if int(Game.profile.level) >= 40 else 1)
		match i:
			0, 1:
				Game.profile.equip["weapon"] = _weapon(int(Game.profile.level))
			2:
				for slot in ["weapon", "armor", "helm", "boots"]:
					Game.profile.equip[slot] = StarProgression.item(BARD, 200, slot, rng)
			3:
				for slot in ["weapon", "armor", "helm", "boots"]:
					Game.profile.equip[slot] = DivineGearData.item(BARD, slot, rng)
				Game.profile.equip["wings"] = StarWingData.item(String(BARD), rng, 4)
		Game.save()
	var menu := MainMenu.new()
	add_child(menu)
	for f in 30:
		await get_tree().process_frame
	await _shot("title_stand")
	menu.stage.select(2)
	await get_tree().create_timer(0.3).timeout
	await _shot("title_cheer")
	menu.queue_free()
	await get_tree().process_frame
	for i in range(1, Game.SLOT_COUNT + 1):
		Game.delete_save(i)


## Every lute: tiers Lv.10-100, the divine lute (top row) and the four star lutes.
func _lutes() -> void:
	get_window().size = Vector2i(1600, 900)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.3
	camera.position = Vector3(0, 0.95, 8); camera.rotation_degrees = Vector3.ZERO
	var nodes: Array = []
	var looks: Array[String] = []
	for t in 10:
		looks.append("lute_%d" % t)
	looks.append("divine_lute_bard_200")
	for stars in [50, 100, 150, 200]:
		looks.append("star_lute_%d" % stars)
	for i in looks.size():
		var look := looks[i]
		var item: Node3D
		if look.begins_with("star_"):
			item = StarGearArt.build(look)
		else:
			item = WeaponKit.build(look)
		var holder := Node3D.new(); add_child(holder)
		holder.add_child(item)
		var row := 0 if i < 11 else 1
		var col := i if row == 0 else i - 11
		holder.position = Vector3(-2.55 + col * 0.51, 1.75, 0) if row == 0 else Vector3(-1.0 + col * 0.66, 0.25, 0)
		holder.rotation_degrees.y = -16.0
		nodes.append(holder)
	await _shot("lutes_front")
	for n in nodes:
		(n as Node3D).rotation_degrees.y = 160.0
	await _shot("lutes_back")
	await _clear(nodes)
