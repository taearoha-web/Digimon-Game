extends Node3D
## A class in its full Dragon God set (the 250★ set, the dragon weapon at +15 and the
## dragon wings / cape): the wing piece from behind, three-quarter and front, flying and
## folded, and the weapon in the hand up close.
##   godot --rendering-driver opengl3 --resolution 640x640 --path . res://tests/tools/dragon_set_preview.tscn -- OUT_DIR [CLASS] [BODY]
## Writes OUT_DIR/<class>_dragon_<shot>.png (BODY: "g:b", a chibi body; default the boy).
const SHOTS := ["back34", "back", "front", "side", "fly", "fold", "fists", "fist_close", "cape_close"]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0]
	var cls := args[1] if args.size() > 1 else "muaythai"
	var look := FaceKit.default_look()
	if args.size() > 2:
		var gb := args[2].split(":")
		look["gender"] = int(gb[0]); look["body"] = int(gb[1])
	DirAccess.make_dir_recursive_absolute(out_dir)
	var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color("cfe3f2")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.95, 0.97, 1.0); e.ambient_light_energy = 0.75
	var we := WorldEnvironment.new(); we.environment = e; add_child(we)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-35, 20, 0); l.light_energy = 0.95; add_child(l)
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(30, 30); g.mesh = pm
	g.material_override = MeshKit.toon(Color("9fcf8c")); add_child(g)
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var equip := {}
	for slot in SetGearData.SLOTS:
		equip[slot] = SetGearData.item(cls, slot)
	equip["weapon"] = DragonGearData.weapon(StringName(cls), rng)
	equip["weapon"]["plus"] = 15
	equip["wings"] = DragonGearData.wings(StringName(cls), rng)
	var cam := Camera3D.new(); add_child(cam); cam.fov = 30
	var only := OS.get_environment("DRAGON_SHOTS")
	for shot in SHOTS:
		if only != "" and not shot in only.split(","):
			continue
		var h := HeroVisual.new(); add_child(h)
		h.setup(StringName(cls), "", true, equip, look)
		var top := 0.0
		for mi in h.find_children("*", "MeshInstance3D", true, false):
			top = maxf(top, (mi as MeshInstance3D).get_aabb().end.y * (mi as Node3D).global_transform.basis.get_scale().y)
		var height := 1.6
		var mid := Vector3(0, height * 0.55, 0)
		match shot:
			"back": cam.position = mid + Vector3(0, 0.25, -4.6)
			"cape_close": cam.position = mid + Vector3(0.0, 0.2, -2.2)
			"back34", "fly", "fold": cam.position = mid + Vector3(3.0, 0.4, -3.6)
			"side": cam.position = mid + Vector3(4.6, 0.25, 0)
			"front": cam.position = mid + Vector3(0.9, 0.25, 4.5)
			_: cam.position = mid + Vector3(1.4, 0.2, 3.2)
		match shot:
			"fly":
				h.set_wing_mode(HeroVisual.WING_FLY, true)
				h.position.y = 0.5
				mid.y += 0.5
			"fold":
				h.set_wing_mode(HeroVisual.WING_FOLD, true)
		cam.look_at(mid, Vector3.UP)
		await get_tree().create_timer(1.6 if shot == "fold" else 1.0).timeout
		if shot.begins_with("fist"):
			var s := h._skeleton
			var hand := "handslot.r"
			var at := s.global_transform * s.get_bone_global_pose(s.find_bone(hand)).origin
			if shot == "fists":
				var other := s.global_transform * s.get_bone_global_pose(s.find_bone("handslot.l")).origin
				at = (at + other) * 0.5
				cam.position = at + Vector3(0.5, 0.25, 1.4)
			else:
				cam.position = at + Vector3(0.75, 0.25, 0.55)
			cam.look_at(at, Vector3.UP)
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s_dragon_%s.png" % [out_dir, cls, shot])
		h.queue_free()
		await get_tree().process_frame
	get_tree().quit()
