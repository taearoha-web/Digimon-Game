extends Node3D
## Frame strips of the caster classes' skills (mage, priest, summoner, bard): one PNG
## per skill, a row of frames from the wind-up to the fade, with two monsters standing
## in the target area so the art can be judged for readability (enemies must stay
## visible). Star skills replay their real beat plan (StarSkillSequence._plan); the
## Mage's Armageddon, Thunder Storm and Judgment Ray run their own sequences.
## xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --audio-driver Dummy --path . \
##   res://tests/tools/caster_strip.tscn -- OUT_DIR [mage|priest|summoner|bard|stars|id,id,...] [t,t,...] [q0|q1|q2] [p0|p1|p2]
## Times are seconds after the release (negative: the wind-up).

const FAMILIES := ["mage", "priest", "summoner", "bard"]
const W := 480
const H := 320
var camera: Camera3D
var caption: Label
## "solo": only the caster signature layers (CasterArt), to judge them alone.
var solo := false
## "zN": a fixed camera size N (a close look at the pieces).
var zoom := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("Expected OUT_DIR")
		get_tree().quit(1)
		return
	var out_dir := String(args[0])
	DirAccess.make_dir_recursive_absolute(out_dir)
	Game.set_process(false)
	GameSettings.load_settings()
	GameSettings.quality = 2
	for a in args:
		if String(a).length() == 2 and String(a)[0] == "q":
			GameSettings.quality = int(String(a)[1])
		if String(a).begins_with("z") and String(a).substr(1).is_valid_float():
			zoom = float(String(a).substr(1))
		if String(a) == "solo":
			solo = true
		if String(a).length() == 2 and String(a)[0] == "p":
			MemoryGuard.pressure = int(String(a)[1])
	get_window().size = Vector2i(720, 480)
	get_window().content_scale_size = Vector2i(720, 480)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("6f93ad")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e3f1ef")
	environment.ambient_light_energy = 0.8
	# The zones' own glow (world/scenery.gd, medium quality and up).
	environment.glow_enabled = true
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	environment.glow_hdr_threshold = 0.96
	environment.glow_intensity = 0.42
	environment.glow_strength = 0.85
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_color = Color("fff1d9")
	sun.light_energy = 1.2
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(90, 90)
	ground.mesh = plane
	# A sunny meadow: the hardest ground for additive light to stay coloured on.
	ground.material_override = MeshKit.toon(Color("6f9a5c"))
	add_child(ground)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(camera)
	var layer := CanvasLayer.new()
	add_child(layer)
	caption = Label.new()
	caption.position = Vector2(14, 8)
	caption.add_theme_font_size_override("font_size", 20)
	caption.add_theme_color_override("font_color", Color("fff6dc"))
	caption.add_theme_color_override("font_outline_color", Color("1a1a24"))
	caption.add_theme_constant_override("outline_size", 6)
	layer.add_child(caption)
	var pick := String(args[1]) if args.size() > 1 else "mage"
	var times: PackedStringArray = (String(args[2]) if args.size() > 2 and "," in String(args[2]) else "-0.2,0.08,0.3,0.6,1.0").split(",")
	var chosen: Array[Dictionary] = []
	for family in FAMILIES:
		for skill in ClassData.pool(StringName(family)):
			var id := String(skill.id)
			if pick == family or (pick == "stars" and skill.has("star")) or id in pick.split(","):
				chosen.append(skill)
	for skill in chosen:
		await _strip(out_dir, skill, times)
	print("CASTER STRIP: %d skills -> %s" % [chosen.size(), out_dir])
	get_tree().quit()


func _strip(out_dir: String, skill: Dictionary, times: PackedStringArray) -> void:
	var family := SkillShow.family_of(skill)
	var id := String(skill.id)
	var fx := Node3D.new()
	fx.name = "Field"
	add_child(fx)
	var hero := HeroVisual.new()
	fx.add_child(hero)
	var rng := RandomNumberGenerator.new()
	rng.seed = 918
	var gear := {"weapon": ItemData.generate(int(skill.get("level", 1)), StringName(family), rng, 2, "weapon")}
	hero.setup(StringName(family), "", true, gear, {"gender": 1 if family in ["mage", "priest", "summoner"] else 0})
	hero.rotation_degrees.y = 90
	var reach := 4.5
	var target := Vector3(reach, 0, 0)
	var radius := float(skill.get("radius", 2.0))
	var mobs: Array[Node3D] = []
	for k in 2:
		var mob := MonsterVisual.new()
		fx.add_child(mob)
		mob.setup("blob/Dog", 1.3, 0.0, Color(1.1, 0.9, 0.8))
		mob.position = target + Vector3(0.2 + 0.9 * float(k), 0, -0.9 + 1.8 * float(k))
		mob.rotation_degrees.y = -90
		mobs.append(mob)
	var shape := String(skill.get("shape", "single"))
	var focus := Vector3(reach * 0.5, 0.9, 0)
	var size := maxf(10.0, radius * 2.0 + 4.0)
	if shape in ["self", "summon", "burst"]:
		focus = Vector3(0.8, 1.0, 0)
		size = maxf(9.0, radius * 2.2 + 2.0)
	if skill.has("star") or int(skill.get("level", 1)) >= 80:
		size = maxf(size, 14.0)
	size = minf(size, 24.0)
	camera.size = zoom if zoom > 0.0 else size
	camera.position = focus + Vector3(7, 8, 11)
	camera.look_at(focus)
	caption.text = "%s  %s  Lv.%d%s" % [family.capitalize(), String(skill.name), int(skill.get("level", 1)), ("  ★%d" % int(skill.star)) if skill.has("star") else ""]
	await get_tree().create_timer(0.15).timeout
	SkillShow._recent_shows.clear()
	var release := float(skill.get("hit_delay", 0.35))
	var start := float(times[0])
	var lead := clampf(-start, 0.0, release)
	# The cast begins `release` before the release; frames before (release - lead) are skipped.
	var clock := -release
	var schedule: Array = []
	schedule.append({"at": -release, "do": "anticipate"})
	if skill.has("star"):
		var seq := StarSkillSequence.new()
		seq.skill = skill
		seq.origin = Vector3.ZERO
		seq.center = Vector3.ZERO if shape in ["burst", "self", "summon"] else target
		seq.forward = Vector3(1, 0, 0)
		seq._plan()
		for event in seq.events:
			var at := float(event.at) - release
			if event.has("launch"):
				schedule.append({"at": at, "do": "launch", "flight": float(event.flight)})
			elif event.has("count") or (event.has("index") and not event.has("drop")):
				schedule.append({"at": at, "do": "strike", "index": int(event.index)})
		seq.free()
	else:
		schedule.append({"at": 0.0, "do": "play"})
	schedule.sort_custom(func(a, b): return float(a.at) < float(b.at))
	var frames: Array[Image] = []
	var shots: Array[float] = []
	for t in times:
		shots.append(float(t))
	var si := 0
	var ei := 0
	while si < shots.size():
		var next_event := float(schedule[ei].at) if ei < schedule.size() else INF
		var next_shot := shots[si]
		if next_event <= next_shot:
			if next_event > clock:
				await get_tree().create_timer(next_event - clock).timeout
				clock = next_event
			_fire(fx, hero, skill, schedule[ei], target, mobs, release)
			ei += 1
			continue
		if next_shot > clock:
			await get_tree().create_timer(next_shot - clock).timeout
			clock = next_shot
		await RenderingServer.frame_post_draw
		var frame := get_viewport().get_texture().get_image()
		frame.resize(W, H, Image.INTERPOLATE_LANCZOS)
		frame.convert(Image.FORMAT_RGBA8)
		frames.append(frame)
		si += 1
	var sheet := Image.create(W * frames.size(), H, false, Image.FORMAT_RGBA8)
	for i in frames.size():
		sheet.blit_rect(frames[i], Rect2i(0, 0, W, H), Vector2i(i * W, 0))
	sheet.save_png("%s/%s.png" % [out_dir, id])
	fx.queue_free()
	await get_tree().create_timer(0.3).timeout


func _fire(fx: Node3D, hero: HeroVisual, skill: Dictionary, event: Dictionary, target: Vector3, mobs: Array[Node3D], release: float) -> void:
	var id := String(skill.id)
	var shape := String(skill.get("shape", "single"))
	var center := Vector3.ZERO if shape in ["burst", "self", "summon"] and skill.has("star") else target
	match String(event.do):
		"anticipate":
			hero.skill_action(skill, release)
			if skill.has("star"):
				StarSkillArt.telegraph(hero, skill, center, release)
			else:
				if solo:
					CasterArt.anticipate(fx, skill, Vector3.ZERO, target, release, hero)
				else:
					SkillShow.anticipate(fx, skill, Vector3.ZERO, release, target, hero)
			if id == "judgment_ray":
				JudgmentRaySequence.launch(fx, hero, mobs[0], release, func(_m: Node3D): pass, hero)
		"launch":
			StarSkillArt.launch(hero, skill, target + Vector3(0, 1, 0), float(event.flight))
		"strike":
			StarSkillArt.strike(fx, skill, center, int(event.index), Vector3.ZERO)
			if shape == "summon" and int(event.index) == 0:
				_summon_arrival(fx, skill)
		"play":
			if id == "armageddon":
				ArmageddonSequence.launch(fx, hero, target, float(skill.radius), float(skill.mult), func(_i: int, _p: Vector3, _r: float, _m: float): pass)
				return
			if id == "thunder_storm":
				ThunderStormSequence.launch(fx, hero, target, float(skill.radius), func(): return mobs, func(_m: Node3D): pass)
				return
			if id == "judgment_ray":
				return
			if solo:
				CasterArt.play(fx, skill, target, Vector3.ZERO)
				return
			SkillShow.play(fx, skill, target, Vector3.ZERO)
			if bool(skill.get("projectile", false)):
				SkillTableau.flight(fx, skill, Vector3(0, 1.2, 0), target + Vector3(0, 1, 0), 0.3)
			elif shape == "single":
				SkillTableau.contact(fx, skill, mobs[0].position + Vector3(0, 0.9, 0), true)
			elif shape in ["chain", "fan"]:
				SkillTableau.link(fx, skill, Vector3(0, 1.2, 0), mobs[0].position + Vector3(0, 1, 0))
				SkillTableau.link(fx, skill, mobs[0].position + Vector3(0, 1, 0), mobs[1].position + Vector3(0, 1, 0))
				for mob in mobs:
					SkillTableau.contact(fx, skill, mob.position + Vector3(0, 0.9, 0), false)
			elif shape in ["blast", "burst"]:
				for mob in mobs:
					SkillTableau.contact(fx, skill, mob.position + Vector3(0, 0.9, 0), false)
			if shape == "summon":
				_summon_arrival(fx, skill)


## What Summon._ready shows when a creature arrives (the hero's summons are real nodes
## with combat state; the strip draws only their arrival).
func _summon_arrival(fx: Node3D, skill: Dictionary) -> void:
	var look := SkillShow.profile_for(skill)
	var spot := Vector3(-0.6, 0, 1.8)
	var arrival := SpellSpectacle._root(fx, spot, "CreatureArrival")
	var mat := SpellSpectacle._material(look, 0.7)
	SkillCraft.portal(arrival, look, mat, 0.8, 0.65)
	SpellSpectacle._finish(arrival, mat, 0.7)
	# The caster art's portal (loaded by path so the tool also renders the old look).
	if ResourceLoader.exists("res://combat/class_art/caster_art.gd"):
		load("res://combat/class_art/caster_art.gd").call("summon_arrival", fx, skill, spot, 1.0)
