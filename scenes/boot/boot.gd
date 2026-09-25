extends Control
## Entry scene. Every autoload is ready by now; show a short splash and move
## on to the main menu through SceneManager.


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UIUtil.digital_background())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := UIUtil.vbox(8)
	center.add_child(box)
	box.add_child(UIUtil.texture_rect(load("res://icon.svg"), Vector2(128, 128)))
	box.add_child(UIUtil.label("Loading…", &"SubHeaderLabel", HORIZONTAL_ALIGNMENT_CENTER))
	await get_tree().create_timer(0.35).timeout
	SceneManager.goto_scene(&"main_menu")
