extends Node
## Pictures of the pets' six forms (PetData.stage_for, PetForm) in the real village: a
## sheet of every pet in every form side by side (3 rows x 6 forms, each form shown as
## the hero's own pet at high quality), a close-up of each pet's god form (★300), and a
## row of the cheap look other players' pets wear (PetFollower) in every form. NPCs and
## players are hidden; the pets face the camera.
##   xvfb-run godot --rendering-driver opengl3 --path . res://tests/tools/pet_stage_shots.tscn -- <out_dir>
var out_dir := "user://pet_stages"
var main: Node
var town: Zone
var _label: Label
var _spot := Vector3.ZERO
var _yaw := 0.0

const CELL := Vector2i(560, 640)
const SHEET_CELL := Vector2i(420, 480)
## Owner level and ★ for each form.
const RANKS := [[20, 0], [50, 0], [90, 0], [100, 100], [100, 200], [100, 300]]


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _grab() -> Image:
	main.hud.visible = false
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameSettings.load_settings()
	GameSettings.quality = 2
	PetCrowd.enabled = false
	get_window().size = CELL
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _wait(0.5)
	Game.new_profile(&"lancer", "เลี้ยงสัตว์")
	Game.profile["level"] = 100
	Game.profile.flags[Tutorial.FLAG] = Tutorial.DONE
	main.title_screen.queue_free()
	main.title_screen = null
	main.hud.visible = false
	Game.playing = true
	await main.go(&"town", true)
	await _wait(3.0)
	town = main.zone
	_hide_people()
	# An open spot of the village a little in front of where the hero arrives.
	_spot = town.hero.global_position
	_yaw = 0.0
	town.hero.visible = false
	town.hero.set_process(false)
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(0, 8)
	_label.size = Vector2(CELL.x, 80)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 8)
	layer.add_child(_label)
	var camera := Camera3D.new()
	camera.fov = 40.0
	town.add_child(camera)
	camera.make_current()
	var sheet := Image.create(SHEET_CELL.x * RANKS.size(), SHEET_CELL.y * PetData.ORDER.size(), false, Image.FORMAT_RGBA8)
	for row in PetData.ORDER.size():
		var id: String = PetData.ORDER[row]
		var h := float(PetData.get_pet(id).height)
		_frame(camera, h * 1.65 + 0.6, 1.0)
		for col in RANKS.size():
			var pet := _show_pet(id, int(RANKS[col][0]), int(RANKS[col][1]), false)
			_label.text = "%s\n%s  %s" % [String(PetData.get_pet(id).name), PetData.form_name(col), PetData.form_requirement(col)]
			await _wait(1.2)
			var img := await _grab()
			img.save_png("%s/cell_%s_%d.png" % [out_dir, id, col])
			img.resize(SHEET_CELL.x, SHEET_CELL.y, Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, SHEET_CELL), Vector2i(col * SHEET_CELL.x, row * SHEET_CELL.y))
			print("PET %s form %d layers %s" % [id, col, PetForm.layers(pet.form_root)])
			pet.queue_free()
			await get_tree().process_frame
	sheet.save_png("%s/pets_6_forms_sheet.png" % out_dir)
	print("SHOT %s/pets_6_forms_sheet.png" % out_dir)
	# Close-ups of the god forms, name tag on.
	get_window().size = Vector2i(1280, 960)
	_label.size = Vector2(1280, 80)
	for id in PetData.ORDER:
		var h := float(PetData.get_pet(id).height)
		_frame(camera, h * 1.65 + 1.2, 1.25)
		var pet := _show_pet(id, 100, 300, true)
		_label.text = "%s · ร่างเทพ (Lv.100 ★300)" % String(PetData.get_pet(id).name)
		await _wait(1.6)
		var img := await _grab()
		img.save_png("%s/god_form_%s.png" % [out_dir, id])
		print("SHOT %s/god_form_%s.png" % [out_dir, id])
		pet.queue_free()
		await get_tree().process_frame
	# Other players' pets (PetFollower, the cheap look) in every form.
	get_window().size = Vector2i(1800, 640)
	_label.size = Vector2(1800, 80)
	for id in PetData.ORDER:
		var h := float(PetData.get_pet(id).height) * PetFollower.SIZE
		_frame(camera, h * 1.65 + 0.4, 2.6)
		var made: Array[Node] = []
		for col in RANKS.size():
			var who := _Owner.new()
			who.member = {"name": "x", "level": int(RANKS[col][0]), "stars": int(RANKS[col][1])}
			town.add_child(who)
			who.global_position = _spot + Vector3((float(col) - 2.5) * h * 1.9, 0, -4.0)
			var f := PetFollower.new()
			town.add_child(f)
			f.build(id)
			f.attach(who)
			f.global_position = who.global_position
			f.set_process(false)
			f.rotation.y = 0.0
			made.append(who)
			made.append(f)
		_label.text = "ผู้เล่นคนอื่น: %s ทั้ง 6 ร่าง (แบบประหยัด)" % String(PetData.get_pet(id).name)
		await _wait(1.0)
		var img := await _grab()
		img.save_png("%s/others_%s.png" % [out_dir, id])
		print("SHOT %s/others_%s.png" % [out_dir, id])
		for n in made:
			n.queue_free()
		await get_tree().process_frame
	get_tree().quit()


## A stand-in owner carrying an AI player's member sheet.
class _Owner extends Node3D:
	var member: Dictionary = {}


## Hides every villager, NPC, player and pet but the ones made here.
func _hide_people() -> void:
	for group in ["world_players", "companions", "remote_players", "pet_followers", "pets", "ai_pets"]:
		for n in get_tree().get_nodes_in_group(group):
			(n as Node3D).visible = false
			n.process_mode = Node.PROCESS_MODE_DISABLED
	for n in town.find_children("*", "Villager", true, false):
		(n as Node3D).visible = false
	for n in town.npcs:
		if is_instance_valid(n):
			(n as Node3D).visible = false
	if is_instance_valid(town.pet):
		town.pet.visible = false
		town.pet.process_mode = Node.PROCESS_MODE_DISABLED


## Puts the camera in front of the spot, [param tall] metres of picture, looking a
## little down; [param far] pushes it back.
func _frame(camera: Camera3D, tall: float, far: float) -> void:
	var dist := tall / (2.0 * tan(deg_to_rad(camera.fov * 0.5))) * 1.25 * far
	var target := _spot + Vector3(0, tall * 0.42, -4.0)
	camera.global_position = target + Vector3(0, tall * 0.18, dist)
	camera.look_at(target, Vector3.UP)


## A pet of [param id] as the hero's own pet (full layers) for an owner Lv.[param level]
## with [param stars] ★, standing on the spot facing the camera, not thinking.
func _show_pet(id: String, level: int, stars: int, tag: bool) -> Pet:
	var pet := Pet.new()
	pet.setup_pet(town.hero, id)
	town.add_child(pet)
	pet.set_process(false)
	pet.scale = Vector3.ONE
	pet.global_position = _spot + Vector3(0, 0, -4.0)
	pet.rotation.y = 0.0
	pet.pstats["level"] = level
	pet.owner_star = stars
	pet.stage = -1
	pet._apply_stage(false)
	if pet._bar:
		pet._bar.visible = false
	if pet._name_tag:
		pet._name_tag.visible = tag
	return pet
