extends Node3D
## Close-ups of the Dark Lord's capes and raven: the Lv.100 cape and the star cape,
## standing and flying, from behind, three-quarter, side and front.
##   godot --rendering-driver opengl3 --path . res://tests/tools/cape_preview.tscn -- OUT_DIR [GENDER]
## Writes OUT_DIR/cape_<set>_<mode>_<view>.png.

## Stands in for the Lord that owns the raven (DarkRaven reads `visual`).
class Lord extends Node3D:
	var visual: HeroVisual

	func raven_target() -> Mob:
		return null

	func raven_strike(_mob: Mob, _group := false) -> void:
		pass

	func is_dead() -> bool:
		return false


const VIEWS := {
	"back": [Vector3(0, 1.0, -4.2), Vector3(-5, 180, 0)],
	"back34": [Vector3(3.0, 1.05, -3.0), Vector3(-6, 135, 0)],
	"side": [Vector3(4.2, 1.0, 0.0), Vector3(-5, 90, 0)],
	"front": [Vector3(0.8, 1.0, 4.2), Vector3(-5, 10, 0)],
}


func _ready() -> void:
	var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color("cfeaff")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.95, 0.97, 1.0); e.ambient_light_energy = 0.75
	var we := WorldEnvironment.new(); we.environment = e; add_child(we)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-35, 160, 0); l.light_energy = 0.95; add_child(l)
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(30, 30); g.mesh = pm
	g.material_override = MeshKit.toon(Color("9fdc8c")); add_child(g)
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0]
	var gender := int(args[1]) if args.size() > 1 else 0
	DirAccess.make_dir_recursive_absolute(out_dir)
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var a := &"darklord"
	var plain := {"weapon": ItemData.generate(95, a, rng, 3, "weapon"), "wings": ItemData.wings(rng, String(a), 3)}
	var star := {}
	for slot in ["weapon", "armor", "helm", "boots"]:
		star[slot] = StarProgression.item(a, 200, slot, rng)
	star["wings"] = StarWingData.item(String(a), rng, 4)
	var cam := Camera3D.new(); add_child(cam)
	cam.fov = 34
	for set_name in ["lv100", "star"]:
		for mode in [HeroVisual.WING_STAND, HeroVisual.WING_FLY]:
			var look := FaceKit.default_look(); look["gender"] = gender
			var lord := Lord.new(); add_child(lord)
			var h := HeroVisual.new(); lord.add_child(h)
			h.setup(a, "", true, plain if set_name == "lv100" else star, look)
			lord.visual = h
			DarkRaven.ensure(lord)
			h.set_wing_mode(mode, true)
			if mode == HeroVisual.WING_FLY:
				h.position.y = Hero.FLY_HEIGHT * 0.5
			await get_tree().create_timer(1.2).timeout
			for view in VIEWS:
				cam.position = VIEWS[view][0] + (Vector3(0, h.position.y, 0))
				cam.rotation_degrees = VIEWS[view][1]
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				var mode_name := "fly" if mode == HeroVisual.WING_FLY else "stand"
				get_viewport().get_texture().get_image().save_png("%s/cape_%s_%s_%s.png" % [out_dir, set_name, mode_name, view])
			lord.queue_free()
			await get_tree().process_frame
	# The raven alone, close up, in each pose.
	var owner := Lord.new(); add_child(owner)
	var raven := DarkRaven.ensure(owner)
	await get_tree().process_frame
	raven.set_process(false)
	raven.global_position = Vector3(0, 1.0, 0)
	raven.rotation = Vector3.ZERO
	for pose in ["perch", "glide", "flap", "stoop", "strike"]:
		for i in 12:
			raven._animate(0.1, pose)
		for view in [["side", Vector3(2.4, 1.15, 0.0), Vector3(-4, 90, 0)], ["front", Vector3(0.7, 1.25, 2.3), Vector3(-6, 17, 0)], ["top", Vector3(0, 3.3, -0.8), Vector3(-76, 180, 0)]]:
			cam.position = view[1]
			cam.rotation_degrees = view[2]
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/raven_%s_%s.png" % [out_dir, pose, view[0]])
	get_tree().quit()
