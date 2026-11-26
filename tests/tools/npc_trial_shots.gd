extends Node
## Trial of free character packs as village NPCs (preview only, nothing live changes):
## in the real town, today's villagers (Npc: class model + FaceKit face + outfit + hat)
## stand beside the trial models found in assets/models/npc_trial/<pack>/, each idling,
## as tall as the player's chibi hero (head tops level) and named like an Npc.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path . res://tests/tools/npc_trial_shots.tscn -- OUT_DIR [raw]
## Writes lineup.png, current.png, <pack>.png (one per pack found) and with_hero.png.
## "raw" keeps the packs' own materials (default: the game's StorybookFinish + outline).
const PACKS := {
	"kenney": "res://assets/models/npc_trial/kenney_mini/",
	"quaternius": "res://assets/models/npc_trial/quaternius_rpg/",
}
## Thai villager names per pack, in the order of the pack's files (sorted).
const NAMES := {
	"kenney": [["ป้าส้มจี๊ด", "แม่ค้าขนม"], ["พี่มะลิ", "คนส่งจดหมาย"], ["แม่ค้าแก้วตา", "ร้านผ้า"],
		["ลุงแว่นใจดี", "ครูประจำหมู่บ้าน"], ["ตาหนวดแดง", "คนเฝ้าสะพาน"], ["หมอยาแว่นทอง", "ร้านยาสมุนไพร"]],
	"quaternius": [["นักดาบพเนจร", "ทหารยาม"], ["หมอผีน้อย", "ร้านยา"], ["นักธนูป่า", "นายพราน"],
		["ลุงขวานใหญ่", "คนตัดไม้"], ["แม่มดใจดี", "หมอดู"], ["อัศวินเฒ่า", "ผู้เฝ้าประตู"]],
}
## Today's villagers: role, name, class, title, model (as World/Zone._villagers).
const CURRENT := [
	["elder", "ผู้ใหญ่บ้านโชคดี", &"warrior", "ผู้ให้เควสต์", "Mage"],
	["shop", "พ่อค้าเก่งกาจ", &"archer", "ร้านค้า", "Rogue"],
	["healer", "ซิสเตอร์เมตตา", &"priest", "รักษาฟรี", "Mage"],
	["forge", "ช่างตีเหล็กหนวดแดง", &"warrior", "ตีบวก / ใส่อัญมณี", "Barbarian"],
]
## Where the lineup stands: across the plaza, the camera looks north from the street.
const SPOT := Vector3(0, 0, 16)
const GAP := 2.0

var out_dir := "user://npc_trial"
var raw := false
var main: Node
var zone: Zone
var cam: Camera3D
var current: Array[Node3D] = []
var trial: Dictionary = {}
var npc_head := 2.3


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	raw = args.has("raw")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1280, 720)
	GameSettings.load_settings()
	DayNight.fixed_hour = 10.5
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _wait(0.5)
	Game.new_profile(&"warrior", "ทดสอบ")
	Game.profile.party = []
	main.title_screen.queue_free()
	main.title_screen = null
	Game.playing = true
	await main.go(&"town", true)
	await _wait(2.0)
	main.hud.visible = false
	zone = main.zone
	if zone.day_night:
		zone.day_night.apply(true)
	_clear_spot()
	# The game's own camera, taken off its rig (the rig and the render watchdog would
	# otherwise hand the view back to the hero's follow camera between shots).
	var rig := (zone.hero as Hero).camera_rig
	rig.process_mode = Node.PROCESS_MODE_DISABLED
	cam = rig.camera
	cam.top_level = true
	cam.fov = 34.0
	# Today's villagers, built the way the zone builds them.
	for c in CURRENT:
		var npc := Npc.new()
		zone.add_child(npc)
		npc.setup(c[0], c[1], c[2], c[3], c[4], Npc.LOOKS.get(c[0], {}))
		current.append(npc)
	await _wait(0.3)
	var tops: Array[float] = []
	for npc in current:
		tops.append(_top(npc, ["Hat"]))
		print("CURRENT %s top %.2f (with hat %.2f)" % [npc.role, tops[-1], _top(npc)])
	tops.sort()
	# The trial models stand as tall as the player's chibi hero (the villagers' measured
	# tops include KayKit's tall bind-pose box; by eye the hero and villagers match).
	var hero_top := _top((zone.hero as Hero).visual, ["Hat", "Weapon", "weapon", "Hold"])
	print("VILLAGER TOP (median) %.2f  HERO TOP %.2f" % [tops[tops.size() / 2], hero_top])
	npc_head = clampf(hero_top, 2.2, 2.7)
	for pack in PACKS:
		var list := _trial_pack(pack)
		if not list.is_empty():
			trial[pack] = list
	print("PACKS ", trial.keys())
	# 1. All groups in one row.
	var all: Array[Node3D] = []
	all.append_array(current)
	for pack in trial:
		all.append_array(trial[pack])
	await _shot("lineup", all, 1.7, false)
	await _shot("lineup", all, 1.7)
	await _shot("current", current, GAP)
	for pack in trial:
		await _shot(pack, trial[pack], 2.3)
	# The hero among them: two villagers, the hero, then the packs' models.
	var mixed: Array[Node3D] = [current[0], current[2]]
	var hero: Node3D = zone.hero
	mixed.append(hero)
	for pack in trial:
		mixed.append_array((trial[pack] as Array).slice(0, 3))
	await _shot("with_hero", mixed, GAP)
	get_tree().quit()


## Hide the town's props on the lineup's patch of street (only for the picture): single
## meshes by their origin, batched props (MultiMesh) by squashing their instances there.
func _clear_spot() -> void:
	var box := AABB(SPOT + Vector3(-13, -1, -3.0), Vector3(26, 10, 28.0))
	var hidden := 0
	for node in zone.find_children("*", "GeometryInstance3D", true, false):
		var g := node as GeometryInstance3D
		if zone.hero.is_ancestor_of(g):
			continue
		if not g.visible or g.get_aabb().size.length() > 40.0 and not g is MultiMeshInstance3D:
			continue
		if g is MultiMeshInstance3D:
			var mm := (g as MultiMeshInstance3D).multimesh
			if mm == null or mm.transform_format != MultiMesh.TRANSFORM_3D:
				continue
			for i in mm.instance_count:
				if box.has_point(g.global_transform * mm.get_instance_transform(i).origin):
					mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.0001), Vector3(0, -100, 0)))
					hidden += 1
		elif box.has_point((g.global_transform * g.get_aabb()).get_center()):
			g.visible = false
			hidden += 1
	print("HIDDEN %d props" % hidden)


## Everything not in the lineup that walks about (world players, pets, companions) and
## the HUD's layers (toasts) stay out of the pictures.
func _hide_crowd() -> void:
	for node in zone.find_children("*", "Node3D", true, false):
		if node == zone.hero or node is Npc or node.get_parent() != zone and not (node is PetFollower or node is Villager):
			continue
		if node is CharacterBody3D or node is PetFollower or node is Villager or node.is_in_group("world_players"):
			(node as Node3D).visible = false
			(node as Node3D).process_mode = Node.PROCESS_MODE_DISABLED
	for npc in zone.npcs:
		if is_instance_valid(npc) and not npc in current and (npc as Node3D).global_position.distance_to(SPOT) < 16.0:
			(npc as Node3D).visible = false
	for node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(node as CanvasLayer).visible = false


## The top of a body's meshes above its feet (names containing a skip word left out).
func _top(root: Node3D, skip: Array = []) -> float:
	var top := 0.0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var skipped := false
		for word in skip:
			if String(mi.name).contains(word) or String(mi.get_parent().name).contains(word):
				skipped = true
		if skipped or mi.get_aabb().size.y < 0.05:
			continue
		var box := mi.global_transform * mi.get_aabb()
		top = maxf(top, box.end.y - root.global_position.y)
	return top


func _trial_pack(pack: String) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var dir: String = PACKS[pack]
	if not DirAccess.dir_exists_absolute(dir):
		return out
	var files: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() in ["glb", "gltf"]:
			files.append(f)
	files.sort()
	var names: Array = NAMES[pack]
	for k in mini(files.size(), 6):
		var label: Array = names[k % names.size()]
		out.append(_trial_npc(dir + files[k], label[0], label[1], k))
	return out


func _trial_npc(path: String, npc_name: String, title: String, k: int) -> Node3D:
	var root := Node3D.new()
	root.name = path.get_file().get_basename()
	zone.add_child(root)
	var model := (load(path) as PackedScene).instantiate() as Node3D
	root.add_child(model)
	var h := _top(root)
	var s := npc_head / maxf(h, 0.01)
	model.scale = Vector3.ONE * s
	print("TRIAL %s raw height %.3f -> scale %.3f" % [path.get_file(), h, s])
	var materials := {}
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i)
			materials[m] = true
			if not raw and m is StandardMaterial3D:
				# The villagers' finish: soft wrap light, rim and the dark outline at the
				# same world width as theirs (0.011 m).
				var done := StorybookFinish.material(m, Color.WHITE, 0.011 / s)
				if done != null:
					mi.set_surface_override_material(i, done)
	if k == 0:
		for m in materials:
			var std := m as StandardMaterial3D
			if std:
				print("  material %s tex %s filter %d" % [std.resource_name, std.albedo_texture.resource_path if std.albedo_texture else "-", std.texture_filter])
	var ap := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap:
		if k == 0:
			print("  clips ", ap.get_animation_list())
		var clip := ""
		for c in ["idle", "Idle", "Idle_Neutral", "Idle_Loop"]:
			if ap.has_animation(c):
				clip = c
				break
		if clip != "":
			var a := ap.get_animation(clip)
			a.loop_mode = Animation.LOOP_LINEAR
			ap.play(clip)
			ap.seek(fmod(k * 0.37, a.length), true)
	var label := Label3D.new()
	label.text = "%s\n%s" % [npc_name, title]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.0048
	label.font_size = 40
	label.outline_size = 12
	label.modulate = Color("fff2c0")
	label.position = Vector3(0, maxf(npc_head + 0.3, 2.75), 0)
	root.add_child(label)
	MeshKit.blob_shadow(root, 0.6)
	return root


## Stand `list` in a row at SPOT (everyone else off to the side) and save a picture.
func _shot(shot: String, list: Array, gap: float, save := true) -> void:
	var everyone: Array[Node3D] = []
	everyone.append_array(current)
	for pack in trial:
		everyone.append_array(trial[pack])
	everyone.append(zone.hero)
	for body in everyone:
		body.visible = false
		body.global_position = Vector3(200, -50, 200) if body != zone.hero else SPOT + Vector3(0, 0, 30)
	_hide_crowd()
	var n := list.size()
	for k in n:
		var body: Node3D = list[k]
		body.visible = true
		body.global_position = SPOT + Vector3((k - (n - 1) * 0.5) * gap, 0, 0)
		if body is Npc:
			(body as Npc).face(body.global_position + Vector3(0, 0, 5))
		elif body == zone.hero:
			(zone.hero as Hero).visual.rotation.y = 0.0
		else:
			body.rotation.y = 0.0
	var width := (n - 1) * gap + 2.0
	var dist := maxf(width * 0.5 / (tan(deg_to_rad(cam.fov * 0.5)) * 16.0 / 9.0) * 1.08, 5.0)
	cam.global_position = SPOT + Vector3(0, 1.7 + dist * 0.07, dist)
	cam.look_at(SPOT + Vector3(0, 1.55, 0))
	cam.make_current()
	# Batched bodies drawn near the camera (crowd imposters, flocks) leave the picture.
	for node in zone.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := node as MultiMeshInstance3D
		var mm := mmi.multimesh
		if mm == null or not mmi.visible or mm.transform_format != MultiMesh.TRANSFORM_3D:
			continue
		var count := mm.instance_count if mm.visible_instance_count < 0 else mm.visible_instance_count
		for i in count:
			if (mmi.global_transform * mm.get_instance_transform(i).origin).distance_to(cam.global_position) < 10.0:
				mmi.visible = false
				break
	# Merged street decor between the camera and the row (hanging lanterns) leaves too.
	var near_box := AABB(cam.global_position + Vector3(-1.5, -3.5, -12), Vector3(3, 4.5, 13.5))
	for node in zone.find_children("*", "MeshInstance3D", true, false):
		var v := node as MeshInstance3D
		if v.visible and v.get_aabb().size.length() < 70.0 and (v.global_transform * v.get_aabb()).intersects(near_box) and not _in_lineup(v):
			v.visible = false
	var probe := _arm_angle(list)
	await _wait(1.2)
	if probe != INF:
		print("  arm-left pose angle %.3f -> %.3f (animating if they differ)" % [probe, _arm_angle(list)])
	if zone.hero:
		(zone.hero as Hero).visual.rotation.y = 0.0
	cam.make_current()
	await RenderingServer.frame_post_draw
	if not save:
		return
	var path := "%s/%s.png" % [out_dir, shot]
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path)


func _arm_angle(list: Array) -> float:
	for body in list:
		var sk := (body as Node).find_child("Skeleton3D", true, false) as Skeleton3D
		if sk and not body is Npc and body != zone.hero and sk.find_bone("arm-left") >= 0:
			return sk.get_bone_pose_rotation(sk.find_bone("arm-left")).get_angle()
	return INF


func _in_lineup(node: Node) -> bool:
	for body in current + [zone.hero]:
		if body.is_ancestor_of(node):
			return true
	for pack in trial:
		for body in trial[pack]:
			if body.is_ancestor_of(node):
				return true
	return false
