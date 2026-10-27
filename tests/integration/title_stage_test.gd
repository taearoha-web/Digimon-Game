extends Node
## The character select platform: slot N's hero stands on painted circle N at every
## screen shape, an empty platform shows no hero, "สร้างตัวละคร" takes the first free
## circle in number order, a created hero lands on its circle and stays selected, a
## tap picks the hero under it, deleting takes the hero off its circle, and nothing
## of the screen is left behind when it closes.
var failures := 0
var checks := 0
var main: Node

## Desktop 16:9, phone app 2.16, tablet 4:3, a phone browser under its toolbar (2.5),
## an ultrawide window (2.8) and a portrait window.
const SHAPES := [Vector2(1280, 720), Vector2(1688, 780), Vector2(1024, 768), Vector2(2400, 960), Vector2(2016, 720), Vector2(800, 1000)]


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.set_process(false)
	await get_tree().process_frame
	for i in range(1, Game.SLOT_COUNT + 1):
		Game.delete_save(i)
	_check_cover()
	await _check_empty()
	await _check_heroes()
	await _check_flow()
	for i in range(1, Game.SLOT_COUNT + 1):
		Game.delete_save(i)
	print("title_stage_test: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


## Pure layout maths: every circle is on screen at every shape, front row below back row.
func _check_cover() -> void:
	for shape in SHAPES:
		var canvas: Vector2 = shape
		var rect := TitleStage.cover_rect(canvas)
		var s := rect.size.x / TitleStage.IMAGE_SIZE.x
		check(is_equal_approx(rect.size.y / TitleStage.IMAGE_SIZE.y, s), "%s: the painting keeps its aspect" % canvas)
		check(rect.position.y <= 0.5 or rect.end.y >= canvas.y - 0.5 or rect.position.x <= 0.5, "%s: the painting fills one axis (mirrored past its edges on the other)" % canvas)
		for slot in range(1, 11):
			var spot: Array = TitleStage.SPOTS[slot - 1]
			var at: Vector2 = rect.position + (spot[0] as Vector2) * s
			var half := float(spot[1]) * s * 0.5
			check(at.x - half >= -1.0 and at.x + half <= canvas.x + 1.0 and at.y > 0.0 and at.y < canvas.y, "%s: circle %d is on screen" % [canvas, slot])
		var keep_top := rect.position.y + TitleStage.KEEP.position.y * s
		var keep_bottom := rect.position.y + TitleStage.KEEP.end.y * s
		check(keep_top >= -1.0 and keep_bottom <= canvas.y + 1.0, "%s: the plates above the back row and the bar under the front row fit (%.0f..%.0f)" % [canvas, keep_top, keep_bottom])
	for slot in range(1, 6):
		check((TitleStage.SPOTS[slot + 4][0] as Vector2).y > (TitleStage.SPOTS[slot - 1][0] as Vector2).y + 200.0, "circle %d is in the front row below circle %d" % [slot + 5, slot])
		check((TitleStage.SPOTS[slot - 1][0] as Vector2).x < (TitleStage.SPOTS[mini(slot, 4)][0] as Vector2).x or slot == 5, "back row runs 1..5 left to right")


func _open_main() -> void:
	get_window().size = Vector2i(1280, 720)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await frames(4)


func _check_empty() -> void:
	await _open_main()
	var menu: MainMenu = main.title_screen
	check(menu != null and menu.stage != null and menu.stage.camera != null and menu.stage.camera.current, "the title is the platform stage with its own camera")
	await frames(6)
	check(menu.stage.heroes.is_empty(), "no heroes yet: the platform stands empty")
	check(menu._plates.is_empty(), "no name plates on an empty platform")
	check(not menu._play.visible and not menu._delete.visible, "nothing to play or delete without a hero")
	check(menu._create.visible and not menu._create.disabled, "the create button is there")
	var backdrop: MeshInstance3D = menu.stage.get_node("Backdrop")
	var tex: Texture2D = (backdrop.material_override as ShaderMaterial).get_shader_parameter("image")
	check(tex != null and tex.get_width() == 1536 and tex.get_height() == 1024, "the painting is the backdrop")
	var emitted := [0]
	menu.new_game_pressed.connect(func(slot: int): emitted[0] = slot)
	menu._create.pressed.emit()
	check(emitted[0] == 1, "the first hero is made for circle 1")
	main.queue_free()
	await frames(3)


func _make(slot: int, cls: StringName, name: String, level: int) -> void:
	Game.slot = slot
	var look := FaceKit.default_look()
	look["gender"] = slot % 2
	Game.new_profile(cls, name, look)
	Game.profile["level"] = level
	Game.save()


func _check_heroes() -> void:
	_make(1, &"warrior", "หนึ่ง", 12)
	_make(2, &"mage", "สอง", 30)
	_make(3, &"priest", "สาม", 45)
	_make(7, &"defender", "เจ็ด", 100)
	# The screen on its own (Main would start the game on "เริ่มผจญภัย").
	get_window().size = Vector2i(1280, 720)
	var menu := MainMenu.new()
	add_child(menu)
	await frames(10)
	var stage := menu.stage
	check(stage.heroes.size() == 4 and stage.heroes.has(1) and stage.heroes.has(2) and stage.heroes.has(3) and stage.heroes.has(7), "each saved hero stands on its own slot's circle (%s)" % str(stage.heroes.keys()))
	check(menu._plates.size() == 4, "each hero has a name plate")
	for shape in SHAPES:
		get_window().size = Vector2i(shape)
		await frames(3)
		var canvas := get_viewport().get_visible_rect().size
		for slot in stage.heroes:
			var feet := stage.camera.unproject_position(stage.heroes[slot].feet)
			var spot := stage.spot_screen(int(slot))
			check(feet.distance_to(spot) < 2.0, "%s: hero %d's feet are on circle %d (%.1f px off)" % [canvas, slot, slot, feet.distance_to(spot)])
			var head := stage.head_screen(int(slot))
			var tall := feet.y - head.y
			check(tall > stage.spot_width(int(slot)) * 0.6 and tall < stage.spot_width(int(slot)) * 1.0, "%s: hero %d is sized to its circle" % [canvas, slot])
			var plate: Control = menu._plates[slot]
			check(plate.position.y >= -2.0 and plate.position.x >= -2.0 and plate.position.x + plate.size.x <= canvas.x + 2.0, "%s: hero %d's plate is on screen" % [canvas, slot])
			check(stage.slot_at(Vector2(spot.x, (spot.y + head.y) * 0.5)) == int(slot), "%s: a tap on hero %d picks it" % [canvas, slot])
		check(stage.slot_at(stage.spot_screen(5)) == 0, "%s: a tap on an empty circle picks nobody" % canvas)
		var back: Vector3 = stage.heroes[2].feet
		var front: Vector3 = stage.heroes[7].feet
		check(stage.camera.global_position.distance_to(front) < stage.camera.global_position.distance_to(back), "%s: the front row stands nearer the camera" % canvas)
	get_window().size = Vector2i(1280, 720)
	await frames(3)
	check(menu._selected == 1 or stage.heroes.has(menu._selected), "a hero is selected")
	menu._on_tap(stage.spot_screen(3) + Vector2(0, -20))
	check(menu._selected == 3 and stage.selected == 3, "tapping hero 3 selects it")
	await get_tree().create_timer(0.5).timeout
	var mat := (stage.get_node("Backdrop") as MeshInstance3D).material_override as ShaderMaterial
	check(is_equal_approx(stage.gold_amount(), 1.0), "hero 3's circle has turned gold")
	check((mat.get_shader_parameter("circle_centre") as Vector2).distance_to((TitleStage.SPOTS[2][0] as Vector2) / TitleStage.IMAGE_SIZE) < 0.001, "the gold circle is circle 3")
	check(is_zero_approx(float(mat.get_shader_parameter("old_amount"))), "the circle picked before is blue again")
	check(menu._play.visible and menu._delete.visible and menu._name.text == "สาม", "the bar shows the selected hero")
	var cheering: HeroVisual = stage.heroes[3].visual
	check(cheering.current == "Cheer", "the picked hero cheers")
	menu._on_tap(stage.spot_screen(2) + Vector2(0, -20))
	check(menu._selected == 2 and (stage.heroes[3].visual as HeroVisual).current != "Cheer", "the hero picked before stops cheering")
	await get_tree().create_timer(4.0).timeout
	check((stage.heroes[2].visual as HeroVisual).current != "Cheer", "the cheer plays once, then the hero stands again")
	var defender: Node3D = stage.heroes[7].visual
	var warrior: Node3D = stage.heroes[1].visual
	check(absf(wrapf(defender.rotation.y - warrior.rotation.y, -PI, PI)) > deg_to_rad(20.0), "the Defender turns its shield aside")
	menu._on_tap(stage.spot_screen(3) + Vector2(0, -20))
	var played := [0]
	menu.continue_pressed.connect(func(slot: int): played[0] = slot)
	menu._play.pressed.emit()
	check(played[0] == 3, "start plays the selected hero")
	var made := [0]
	menu.new_game_pressed.connect(func(slot: int): made[0] = slot)
	menu._create.pressed.emit()
	check(made[0] == 4, "the next hero takes the first free circle (4)")
	# Delete without the dialog: what the confirm does.
	Game.delete_save(3)
	menu._slots.erase(3)
	stage.remove_hero(3)
	check(not stage.heroes.has(3), "a deleted hero is off the stage at once")
	await get_tree().create_timer(0.7).timeout
	await frames(2)
	check(not stage.heroes.has(3) and stage.get_node_or_null("Slot3") == null, "a deleted hero leaves its circle")
	check(stage.selected != 3, "the deleted hero is no longer selected")
	menu.queue_free()
	await frames(3)


## Create → class select → confirm: the hero lands on its circle, selected; leaving
## for the game frees the stage, its heroes and the painting.
func _check_flow() -> void:
	Game.playing = false
	await _open_main()
	await frames(10)
	var menu: MainMenu = main.title_screen
	var free := Game.free_slot()
	check(free == 3, "slot 3 is free again after the delete")
	menu._create.pressed.emit()
	await frames(2)
	check(main.class_screen != null and main.title_screen == null, "create opens the hero creator")
	var look := FaceKit.default_look()
	main.class_screen.confirmed.emit(ClassData.START, "ใหม่", look)
	await frames(4)
	check(main.class_screen == null and main.title_screen != null, "after creating, the platform comes back")
	check(Game.has_save(free) and Game.slot_info(free).name == "ใหม่", "the new hero is saved in slot %d" % free)
	menu = main.title_screen
	check(menu.arrival_slot == free or menu.stage.heroes.has(free), "the new hero arrives on circle %d" % free)
	await frames(14)
	check(menu.stage.heroes.has(free) and menu._selected == free and menu.stage.selected == free, "the new hero stands on circle %d, selected" % free)
	check(main.zone == null and not Game.playing, "creating does not start the game by itself")
	var stage_ref: WeakRef = weakref(menu.stage)
	var visual_ref: WeakRef = weakref(menu.stage.heroes[free].visual)
	menu._play.pressed.emit()
	var waited := 0
	while main.zone == null and waited < 600:
		await get_tree().process_frame
		waited += 1
	check(main.zone != null and Game.slot == free and String(Game.profile.name) == "ใหม่", "start enters the game as the new hero")
	await frames(3)
	check(stage_ref.get_ref() == null and visual_ref.get_ref() == null, "the stage and its heroes are freed in the game")
	check(get_viewport().get_camera_3d() != null and not (get_viewport().get_camera_3d().get_parent() is TitleStage), "the zone's camera takes over")
	main.queue_free()
	await frames(3)
