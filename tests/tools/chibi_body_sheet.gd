extends Node3D
## Contact sheet of a hero body (ChibiBodies) through its clips: idle, walk, run, a
## sword chop, a spell, a bow shot, hit and death, each at a few moments, front
## three-quarter and side.
##   godot --rendering-driver opengl3 --resolution 1600x900 --path . res://tests/tools/chibi_body_sheet.tscn -- OUT.png GENDER BODY [VIEW]
## VIEW: front | side | back (default front). Gear: Lv.100 star gear with wings on the last row.
const CELLS := [
	["warrior", "Idle", 0.3], ["warrior", "Walking_A", 0.25], ["warrior", "Walking_A", 0.75], ["warrior", "Running_A", 0.25], ["warrior", "Running_A", 0.75],
	["warrior", "1H_Melee_Attack_Chop", 0.25], ["warrior", "1H_Melee_Attack_Chop", 0.5], ["warrior", "2H_Melee_Attack_Spin", 0.4], ["mage", "Spellcast_Shoot", 0.3], ["mage", "Spellcast_Long", 0.5],
	["archer", "2H_Ranged_Shoot", 0.2], ["archer", "2H_Ranged_Shoot", 0.5], ["warrior", "Hit_A", 0.3], ["warrior", "Death_A", 0.35], ["warrior", "Death_A", 1.0],
	["warrior", "Jump_Full_Short", 0.4], ["warrior", "Dodge_Backward", 0.3], ["priest", "Cheer", 0.4], ["lancer", "2H_Melee_Attack_Stab", 0.4], ["bard", "Idle", 0.3],
]
const COLS := 5
const CELL := Vector2i(320, 300)


func _ready() -> void:
	var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color("cfeaff")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.95, 0.97, 1.0); e.ambient_light_energy = 0.75
	var we := WorldEnvironment.new(); we.environment = e; add_child(we)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-35, 20, 0); l.light_energy = 0.95; add_child(l)
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var gender := int(args[1]) if args.size() > 1 else 0
	var body := int(args[2]) if args.size() > 2 else 0
	var view := args[3] if args.size() > 3 else "front"
	get_viewport().size = CELL
	var cam := Camera3D.new(); add_child(cam)
	cam.fov = 40; cam.position = Vector3(0, 1.35, 4.6); cam.rotation_degrees = Vector3(-5, 0, 0)
	var sheet := Image.create(CELL.x * COLS, CELL.y * ceili(CELLS.size() / float(COLS)), false, Image.FORMAT_RGBA8)
	var look := FaceKit.default_look(); look["gender"] = gender; look["body"] = body
	for i in CELLS.size():
		var cell: Array = CELLS[i]
		var equip := {}
		if i >= CELLS.size() - COLS:
			for slot in ["weapon", "armor", "helm", "wings"]:
				var item: Variant = StarProgression.item(StringName(cell[0]), 100, slot, RandomNumberGenerator.new()) if slot != "wings" else null
				if item != null:
					equip[slot] = item
		var h := HeroVisual.new(); add_child(h)
		h.setup(StringName(cell[0]), "", true, equip, look)
		h.rotation_degrees.y = {"front": 25.0, "side": 90.0, "back": 180.0}.get(view, 25.0)
		var clip := String(cell[1])
		if h.anim.has_animation(clip):
			h.anim.play(clip, 0.0)
			h.anim.seek(h.anim.get_animation(clip).length * float(cell[2]), true)
			h.anim.pause()
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i((i % COLS) * CELL.x, (i / COLS) * CELL.y))
		h.queue_free()
		await get_tree().process_frame
	sheet.save_png(out)
	get_tree().quit()
