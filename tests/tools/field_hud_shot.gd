extends Node
## One screenshot of the HUD in a hunting field with the world chat full of long lines:
## the chat must sit between the joystick and the first skill slot.
##   xvfb-run godot --rendering-driver opengl3 --path . res://tests/tools/field_hud_shot.tscn -- <out_dir> [width] [height]
var main: Node


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0] if args.size() > 0 else "user://shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var w := int(args[1]) if args.size() > 1 else 1600
	var h := int(args[2]) if args.size() > 2 else 736
	get_window().size = Vector2i(w, h)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(0.5).timeout
	Game.new_profile(&"warrior", "ทดสอบ")
	Game.profile["level"] = 40
	Game.fill_loadout()
	main.title_screen.queue_free()
	main.title_screen = null
	main.hud.visible = true
	Game.playing = true
	await main.go(&"meadow", true)
	await get_tree().create_timer(1.0).timeout
	for line in ["ร้านเปิดแล้ว ยาเลือดราคาถูก ยามานาก็มี แวะมาก่อนออกล่านะทุกคน ลดราคาช่วงนี้เท่านั้น", "กิลด์ Neverdie รับสมาชิกเลเวล 100 ขึ้นไป ทักมาได้เลย", "ขอบคุณที่ช่วยเมื่อกี้นะ", "ใครไปสนามถัดไปบ้าง ไปด้วยกัน"]:
		Game.world_chat.emit("ผู้เล่นทดสอบชื่อยาวมาก", line, Color("8ff0ff"))
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/field_hud_%dx%d.png" % [out_dir, w, h])
	var chat: Control = main.hud.world_chat
	var first: Control = main.hud.skill_slots[0]
	print("SHOT chat x %.0f..%.0f (size %s) | skill1 x %.0f..%.0f | joystick width %.0f" % [chat.global_position.x, chat.global_position.x + chat.size.x, chat.size, first.global_position.x, first.global_position.x + first.size.x, main.hud.joystick.size.x])
	get_tree().quit()
