extends Node3D
## Shots of the chibi hero looks (ChibiLook), one PNG per look:
##   godot --rendering-driver opengl3 --path . res://tests/tools/chibi_look_preview.tscn -- OUT_DIR SET [VIEW] [CLASS]
## SET:  styles (3 styles x 2 bodies) | hair_tint | skin_tone | eye_tint | acc (every value, both bodies)
## VIEW: full | face | back (default full); CLASS: wear Lv.100 star gear of that class.
## Writes OUT_DIR/<set>_<view>_<i>.png and OUT_DIR/<set>_<view>.txt (one caption per line).
func _ready() -> void:
	var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color("cfeaff")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.95, 0.97, 1.0); e.ambient_light_energy = 0.75
	var we := WorldEnvironment.new(); we.environment = e; add_child(we)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-35, 20, 0); l.light_energy = 0.95; add_child(l)
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(30, 30); g.mesh = pm
	g.material_override = MeshKit.toon(Color("9fdc8c")); add_child(g)
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0]
	var set_name := args[1] if args.size() > 1 else "styles"
	var view := args[2] if args.size() > 2 else "full"
	var cls := StringName(args[3]) if args.size() > 3 else ClassData.START
	var looks: Array = []
	var captions: PackedStringArray = []
	if set_name == "styles":
		for gender in 2:
			for s in 3:
				var look := FaceKit.default_look(); look["gender"] = gender; ChibiLook.apply_style(look, s)
				looks.append(look); captions.append(ChibiLook.style_name(gender, s))
	else:
		for gender in 2:
			for v in ChibiLook.count(set_name):
				var look := FaceKit.default_look(); look["gender"] = gender; look[set_name] = v
				looks.append(look); captions.append(ChibiLook.value_name(set_name, v))
	var equip := {}
	if args.size() > 3:
		for slot in ["weapon", "armor", "helm", "boots", "amulet", "ring"]:
			equip[slot] = StarProgression.item(cls, 100, slot, RandomNumberGenerator.new())
	var cam := Camera3D.new(); add_child(cam)
	match view:
		"face":
			cam.fov = 30; cam.position = Vector3(0, 2.05, 2.6); cam.rotation_degrees = Vector3(-4, 0, 0)
		"back":
			cam.fov = 34; cam.position = Vector3(0, 1.7, -4.4); cam.rotation_degrees = Vector3(-6, 180, 0)
		_:
			cam.fov = 34; cam.position = Vector3(0, 1.45, 5.2); cam.rotation_degrees = Vector3(-6, 0, 0)
	for i in looks.size():
		var h := HeroVisual.new(); add_child(h); h.setup(cls, "", not equip.is_empty(), equip, looks[i])
		h.rotation_degrees.y = 16 if view != "back" else 0
		await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s_%s_%d.png" % [out_dir, set_name, view, i])
		h.queue_free()
		await get_tree().process_frame
	var f := FileAccess.open("%s/%s_%s.txt" % [out_dir, set_name, view], FileAccess.WRITE)
	f.store_string("\n".join(captions))
	f.close()
	get_tree().quit()
