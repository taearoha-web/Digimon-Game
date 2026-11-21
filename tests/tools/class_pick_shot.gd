extends Node
## The create screen with its class picker, or (MODE "old") the class pick an old
## Vagabond save gets on load:
##   godot --rendering-driver opengl3 --resolution 1688x780 --path . res://tests/tools/class_pick_shot.tscn -- out.png [create|old] [CLASS]
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[1] if args.size() > 1 else "create"
	var screen := ClassSelect.new()
	if mode == "old":
		Game.new_profile(ClassData.LEGACY, "Assotix", FaceKit.default_look())
		Game.profile["level"] = 14
		screen.pick_only = true
		screen.hero_name_fixed = "Assotix"
	add_child(screen)
	await get_tree().process_frame
	screen.set_class(StringName(args[2]) if args.size() > 2 else &"mage")
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(args[0])
	get_tree().quit()
