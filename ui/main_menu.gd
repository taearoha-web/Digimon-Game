class_name MainMenu
extends CanvasLayer
## Title screen: continue / new game.

signal new_game_pressed()
signal continue_pressed()


func _ready() -> void:
	layer = 50
	var bg := UIUtil.sky_background()
	add_child(bg)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var title := UIUtil.label("TOON TALE", &"TitleLabel", HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_font_size_override("font_size", 92)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -400
	title.offset_right = 400
	title.offset_top = 70
	root.add_child(title)
	var sub := UIUtil.label("ตำนานนักล่าแห่งมิสต์วูด", &"HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER)
	sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	sub.offset_left = -400
	sub.offset_right = 400
	sub.offset_top = 190
	root.add_child(sub)
	var column := UIUtil.vbox(16)
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.offset_left = -190
	column.offset_right = 190
	column.offset_top = 40
	column.offset_bottom = 260
	root.add_child(column)
	var cont := UIUtil.button("เล่นต่อ", &"PrimaryButton", Vector2(0, 76))
	cont.disabled = not Game.has_save()
	cont.pressed.connect(func(): continue_pressed.emit())
	column.add_child(cont)
	var new_game := UIUtil.button("เริ่มเกมใหม่", &"", Vector2(0, 76))
	new_game.pressed.connect(func(): new_game_pressed.emit())
	column.add_child(new_game)
	var foot := UIUtil.label("v0.1 · โมเดลตัวละคร KayKit และมอนสเตอร์ Quaternius (CC0)", &"SmallLabel", HORIZONTAL_ALIGNMENT_CENTER)
	foot.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	foot.offset_left = -500
	foot.offset_right = 500
	foot.offset_top = -50
	root.add_child(foot)
	AudioManager.play_music(&"title")
