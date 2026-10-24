extends Node3D
## A class's two wing pairs (Lv.100 and star) on the hero in its divine set, from
## several angles and in each wing pose, for judging wing art.
##   godot --rendering-driver opengl3 --path . res://tests/tools/wing_preview.tscn -- OUT_DIR [CLASS] [BG]
## Writes <class>_<lv100|star>_<view>_<pose>.png; BG "night" uses a dark backdrop.
const SHOTS := [["back", "stand"], ["back34", "stand"], ["front", "stand"], ["side", "stand"], ["back", "fly"], ["back34", "fold"]]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0]
	var cls := args[1] if args.size() > 1 else "assassin"
	var night := args.size() > 2 and args[2] == "night"
	var e := Environment.new(); e.background_mode = Environment.BG_COLOR
	e.background_color = Color("1a1426") if night else Color("cfeaff")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.95, 0.97, 1.0)
	e.ambient_light_energy = 0.55 if night else 0.75
	var we := WorldEnvironment.new(); we.environment = e; add_child(we)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-35, 20, 0); l.light_energy = 0.95; add_child(l)
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(30, 30); g.mesh = pm
	g.material_override = MeshKit.toon(Color("2a2438") if night else Color("9fdc8c")); add_child(g)
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var divine := {}
	for slot in ["weapon", "armor", "helm", "boots"]:
		divine[slot] = DivineGearData.item(StringName(cls), slot, rng)
	var pairs := {"lv100": ItemData.wings(rng, cls, 3), "star": StarWingData.item(cls, rng, 4)}
	var cam := Camera3D.new(); add_child(cam); cam.fov = 34
	for kind in pairs:
		var equip := divine.duplicate(); equip["wings"] = pairs[kind]
		for shot in SHOTS:
			var h := HeroVisual.new(); add_child(h); h.setup(StringName(cls), "", true, equip, FaceKit.default_look())
			match shot[0]:
				"back": cam.position = Vector3(0, 2.0, -6.6); cam.rotation_degrees = Vector3(-7, 180, 0)
				"back34": cam.position = Vector3(4.3, 2.1, -5.1); cam.rotation_degrees = Vector3(-8, 140, 0)
				"side": cam.position = Vector3(6.6, 1.9, 0); cam.rotation_degrees = Vector3(-6, 90, 0)
				_: cam.position = Vector3(0, 1.9, 6.6); cam.rotation_degrees = Vector3(-7, 0, 0)
			await get_tree().process_frame
			match shot[1]:
				"fly": h.set_wing_mode(HeroVisual.WING_FLY, true)
				"fold": h.set_wing_mode(HeroVisual.WING_FOLD, true)
			await get_tree().create_timer(1.6 if shot[1] == "fold" else 0.9).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/%s_%s_%s_%s.png" % [out_dir, cls, kind, shot[0], shot[1]])
			h.queue_free()
			await get_tree().process_frame
	get_tree().quit()
