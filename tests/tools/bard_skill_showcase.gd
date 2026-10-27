extends Node3D
## The Bard's skill art on real casts (Hero._cast): a Lv.100 Bard with every skill at
## ★5 (or ★1), a pack of dummy monsters round the target and two allies beside the
## Bard who show the song aura when a song reaches the party. Each cast is captured
## at its wind-up, its release / contact and its peak, from a gameplay-like camera
## behind and above the Bard. Does not use the user's saves.
## godot --rendering-driver opengl3 --path . res://tests/tools/bard_skill_showcase.tscn -- OUT_DIR [ids,comma|every] [medium|low] [rank1] [noflourish]
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
var quality := 2
var rank := 5
var records: Array[Dictionary] = []
## Seconds of game time (process delta): the casts, the art and the captures share it.
var game_clock := 0.0

func _process(delta: float) -> void:
	game_clock += delta

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	Game.set_process(false)
	GameSettings.load_settings()
	quality = 0 if "low" in args else (1 if "medium" in args else 2)
	rank = 1 if "rank1" in args else 5
	# "noflourish" hides the shared ClassFlourish finish to judge the Bard's own layers.
	ClassFlourish.enabled = not "noflourish" in args
	GameSettings.quality = quality
	GameSettings.combat_hitstop = false
	get_window().size = Vector2i(1280, 720)
	get_window().content_scale_size = Vector2i(1280, 720)
	seed(909)
	Scenery.environment(self, Color("789bba"), Color("adc2c6"), Color("d9e5f0"), Color("ffe4bf"))
	var paths: Array[PackedVector2Array] = [PackedVector2Array([Vector2(-30, 0), Vector2(0, 0), Vector2(30, 3)])]
	Scenery.ground(self, 60.0, Color("607f61"), Color("779265"), 912, Color("a59f7e"), paths, 2.5, [Vector3.ZERO], &"meadow")
	camera = Camera3D.new()
	camera.fov = 58.0
	add_child(camera)
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
	subtitle.position = Vector2(30, 56)
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color("fff2cb"))
	subtitle.add_theme_color_override("font_shadow_color", Color("283540"))
	subtitle.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(subtitle)
	var selected: Array = ["staccato_shot", "valor_march", "slumber_lullaby", "heroic_anthem", "fortissimo", "grand_dissonance", "aria_of_ruin", "thunder_crescendo", "hymn_of_legends", "grand_finale", "starlight_overture", "heartbreak_sonata", "celestial_stage", "cosmic_encore"]
	if args.size() > 1 and not args[1] in ["medium", "low", "rank1", "noflourish"]:
		selected = Array(args[1].split(","))
		if args[1] == "every":
			selected = []
			for skill in ClassData.pool(&"bard"):
				selected.append(String(skill.id))
	for id in selected:
		var skill := ClassData.find_skill(&"bard", String(id))
		if not skill.is_empty():
			await _case(skill)
	var file := FileAccess.open(out_dir.path_join("bard_showcase.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"quality": quality, "rank": rank, "casts": records}, "\t"))
	print("BARD SKILL SHOWCASE: %d real casts captured" % records.size())
	get_tree().quit()

func _case(skill: Dictionary) -> void:
	var id := String(skill.id)
	Game.new_profile(&"bard", "Bard Art QA", {"gender": 1})
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.paragon().level = 200
	if bool(skill.get("requires_wings", false)):
		# Borrowed mage wings: the review is about the skill art, not the wing models.
		Game.profile.equip["wings"] = ItemData.wings(Game.rng, "mage", 3)
	Game.profile.skills[id] = rank
	Game.profile.loadout[0] = id
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
	hero.position = Vector3(-3.0, 0, 0)
	# The pack: the target and five more round it.
	var target_at := Vector3(3.5, 0, 0)
	var mobs: Array[Dummy] = []
	for k in 6:
		var mob := Dummy.new()
		var spot := target_at if k == 0 else target_at + Vector3(sin(float(k) * 1.3), 0, cos(float(k) * 1.3)) * (1.8 + 0.5 * float(k % 2))
		mob.setup(&"forest_orc", 100, spot, hero)
		field.add_child(mob)
		mob.position = spot
		mob.hp = 10000000
		mob.max_hp = 10000000
		mob.stats.def = 0.0
		mob.set_physics_process(false)
		mobs.append(mob)
	hero.target = mobs[0]
	hero.set_facing(atan2(target_at.x - hero.position.x, target_at.z - hero.position.z))
	# Two allies beside the Bard (visual stand-ins: the song aura shows on them).
	var allies: Array[HeroVisual] = []
	for k in 2:
		var ally := HeroVisual.new()
		field.add_child(ally)
		ally.setup(&"warrior" if k == 0 else &"priest", "", true, {}, {"gender": k})
		ally.position = hero.position + (Vector3(-0.7, 0, -2.0) if k == 0 else Vector3(0.9, 0, -1.7))
		ally.rotation.y = hero.rotation.y
		allies.append(ally)
	var big := float(skill.get("radius", 3.0)) >= 5.0 or int(skill.get("level", 1)) >= 80 or skill.has("star")
	var focus := hero.position.lerp(target_at, 0.4 if String(skill.shape) != "self" else 0.0) + Vector3.UP * 1.3
	var dist := 12.0 if big else 8.5
	camera.position = focus + Vector3(-0.62, 0.48, 0.62).normalized() * dist
	camera.look_at(focus)
	title.text = "TOON TALE  /  " + String(skill.name)
	subtitle.text = "Bard  ·  ★%d  ·  %s quality" % [rank, ["low", "medium", "high"][quality]]
	VfxKit.warm_shaders(field, Vector3.ZERO)
	await get_tree().create_timer(0.6).timeout
	SkillShow._recent_shows.clear()
	hero._cast(skill)
	var cast_at := game_clock
	var delay := float(skill.hit_delay)
	var steps: Array = [[delay * 0.7, "1windup"], [delay + 0.1, "2release"], [delay + 0.4, "3contact"], [delay + 0.85, "4peak"]]
	if skill.has("star"):
		# Star carriers land 0.28 s after each beat; the sonata's heartbreak is beat 6, the encore's crown wave 5.
		steps = [[delay * 0.7, "1windup"], [delay + 0.35, "2release"], [delay + 0.8, "3contact"], [delay + 1.35, "4peak"], [delay + 1.75, "5finale"]]
	var songs_sent := false
	for step in steps:
		# Game time since the cast (the clock every effect and the cast itself run on).
		while game_clock - cast_at < float(step[0]):
			await get_tree().process_frame
		var clock := game_clock - cast_at
		if not songs_sent and clock >= delay and skill.get("fx", {}).has("buff") and not bool(skill.fx.buff.get("self_only", false)):
			songs_sent = true
			for ally in allies:
				var aura := BuffAura.new()
				aura.look = BuffArt.profile(skill)
				ally.add_child(aura)
		await _capture("%s_q%d_%s" % [id, quality, step[1]])
	await get_tree().create_timer(1.2).timeout
	var hits := 0
	for mob in mobs:
		hits += mob.hits
	records.append({"skill": id, "hits_on_pack": hits, "decorations_peak": VfxBudget.counters().decorations})
	field.queue_free()
	await field.tree_exited
	await get_tree().process_frame

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(label + ".png"))
