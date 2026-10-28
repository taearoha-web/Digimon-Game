extends Node
## The Job Master's class list in the speech panel (ten classes and "later"): every
## answer must fit on screen, wrapping onto more rows.
##   godot --rendering-driver opengl3 --resolution 1000x460 --path . res://tests/tools/dialog_preview.tscn -- OUT.png
func _ready() -> void:
	GameSettings.load_settings()
	var dialog := DialogBox.new()
	add_child(dialog)
	await get_tree().process_frame
	var options: Array = []
	for id in ClassData.IDS:
		options.append({"label": String(ClassData.get_class_data(id).name)})
	options.append({"label": "ไว้ก่อน"})
	dialog.say("ปรมาจารย์ผู้เปลี่ยนชะตา", "ถึงเวลาเลือกเส้นทางแล้ว! สายไหนที่ใจเจ้าเรียกหา? (เลือกแล้วเปลี่ยนไม่ได้ ไม่เสียค่าใช้จ่าย)", options)
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	get_tree().quit()
