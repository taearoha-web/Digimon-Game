extends Node
## Renders a class's 200-star divine icons the way the shipped ones look: the hero
## wearing the whole set, cropped to the helm, the armour and the boots, plus the
## weapon alone (transparent 384 px PNGs).
##   godot --rendering-driver opengl3 --path . res://tests/tools/divine_icons.tscn -- OUT_DIR CLASS
const SIZE := 384
## [slot, centre y, view height] as fractions of the hero's height.
const FRAMES := [["helm", 0.8, 0.44], ["armor", 0.5, 0.5], ["boots", 0.16, 0.36]]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0]
	var cls := args[1] if args.size() > 1 else "defender"
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.95, 0.97, 1.0)
	e.ambient_light_energy = 0.8
	var we := WorldEnvironment.new(); we.environment = e; vp.add_child(we)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-30, 25, 0); l.light_energy = 0.9; vp.add_child(l)
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; vp.add_child(cam)
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	var gear := {}
	for slot in ["weapon", "armor", "helm", "boots"]:
		gear[slot] = DivineGearData.item(cls, slot, rng)
	var h := HeroVisual.new(); vp.add_child(h)
	h.setup(StringName(cls), "", false, {"armor": gear.armor, "helm": gear.helm, "boots": gear.boots}, FaceKit.default_look())
	await get_tree().create_timer(0.8).timeout
	var height := _bounds(h).end.y
	for f in FRAMES:
		cam.size = f[2] * height
		cam.position = Vector3(0, f[1] * height, 6)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s/divine_%s_%s_200.png" % [out_dir, f[0], cls])
	h.queue_free()
	var kind: String = DivineGearArt.KINDS[cls]
	var w := Node3D.new(); vp.add_child(w)
	var model := WeaponKit.build("divine_%s_%s_200" % [kind, cls]); w.add_child(model)
	w.rotation_degrees.z = -12.0
	await get_tree().process_frame
	var box := w.transform * _bounds(w)
	cam.size = maxf(box.size.x, box.size.y) * 1.1
	cam.position = Vector3(box.get_center().x, box.get_center().y, 6)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png("%s/divine_%s_%s_200.png" % [out_dir, kind, cls])
	get_tree().quit()


func _bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree():
			continue
		var b: AABB = (root.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
