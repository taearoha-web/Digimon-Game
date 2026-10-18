extends Node
## The character creator with a chosen body and style:
##   godot --rendering-driver opengl3 --resolution 1600x740 --path . res://tests/tools/creator_shot.tscn -- out.png GENDER STYLE
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var screen := ClassSelect.new()
	add_child(screen)
	await get_tree().process_frame
	screen._set_gender(int(args[1]) if args.size() > 1 else 0)
	screen._set_style(int(args[2]) if args.size() > 2 else 0)
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(args[0])
	get_tree().quit()
