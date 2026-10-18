extends Node
## Renders item icons (transparent PNGs) from the procedural gear models.
##   godot --path . res://tests/tools/icons.tscn -- <out_dir> <sheet.png|-> [filter-prefix]
## Writes <out_dir>/<look>.png and optionally one contact sheet of everything.

const SIZE := 128

var viewport: SubViewport
var holder: Node3D
var cam: Camera3D


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0]
	var sheet_path: String = args[1] if args.size() > 1 else "-"
	var prefix: String = args[2] if args.size() > 2 else ""
	DirAccess.make_dir_recursive_absolute(out_dir)
	_setup()
	var ids: Array[String] = ItemLook.all_icon_ids()
	# "ids=a,b,c" renders exactly those looks (star_/divine_ looks included).
	if prefix.begins_with("ids="):
		ids.assign(prefix.trim_prefix("ids=").split(","))
		prefix = ""
	var images: Array[Image] = []
	for id in ids:
		if prefix != "" and not id.begins_with(prefix):
			continue
		var node := _divine_node(id) if id.begins_with("divine_") else ItemLook.build_icon_node(id)
		if node == null:
			continue
		var img := await _render(node)
		img.save_png("%s/%s.png" % [out_dir, id])
		images.append(img)
	if sheet_path != "-" and not images.is_empty():
		var cols := 12
		var rows := ceili(images.size() / float(cols))
		var sheet := Image.create(cols * SIZE, rows * SIZE, false, Image.FORMAT_RGBA8)
		sheet.fill(Color("5a6a8a"))
		for i in images.size():
			sheet.blend_rect(images[i], Rect2i(0, 0, SIZE, SIZE), Vector2i((i % cols) * SIZE, (i / cols) * SIZE))
		sheet.save_png(sheet_path)
	print("icons: ", images.size())
	get_tree().quit()


func _setup() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(SIZE, SIZE)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	viewport.add_child(we)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -30, 0)
	light.light_energy = 0.62
	viewport.add_child(light)
	holder = Node3D.new()
	viewport.add_child(holder)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.position = Vector3(0, 0, 10)
	viewport.add_child(cam)


func _render(node: Node3D) -> Image:
	for c in holder.get_children():
		c.queue_free()
	holder.add_child(node)
	await get_tree().process_frame
	var box := _bounds(node)
	var center := box.get_center()
	cam.size = maxf(box.size.x, box.size.y) * 1.18
	if node.has_meta("frame"):
		var f: Vector3 = node.get_meta("frame")
		center = Vector3(f.x, f.y, 0)
		cam.size = f.z
	cam.position = Vector3(center.x, center.y, 10)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


## A divine piece: the weapon model, or the boy's skinned clothing at its bind pose.
func _divine_node(id: String) -> Node3D:
	var bits := id.split("_")
	var holder := Node3D.new()
	if bits[1] in ["armor", "helm", "boots"]:
		var path := DivineGearArt.DIR + "%s_boy_%s.glb" % [bits[2], bits[1]]
		holder.add_child((load(path) as PackedScene).instantiate())
		holder.rotation_degrees.y = 20.0
	else:
		holder.add_child(WeaponKit.build(id))
		holder.rotation_degrees.z = -12.0
	return holder


func _bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var local := root.global_transform.affine_inverse() * m.global_transform
		var b := local * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return root.global_transform * box
