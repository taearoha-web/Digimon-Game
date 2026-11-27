extends Node
## Screenshots of the star page with the special pool (ค่าสถานะพิเศษ ★301+): locked at
## ★300, open at ★420 with some points spent. Into the directory in the STAR500_SHOTS env var.
##   xvfb-run -a godot --rendering-driver opengl3 --path . res://tools/star500_shots.tscn

var out := ""


func _ready() -> void:
	out = OS.get_environment("STAR500_SHOTS")
	if out == "":
		out = "user://"
	Game.set_process(false)
	Game.new_profile(&"lancer", "ดาวห้าร้อย", FaceKit.default_look())
	Game.profile.level = Game.MAX_LEVEL
	Game.profile.adv = JobData.GOD_ADV
	Game.profile.gold = 5000000
	Game.profile.paragon = {"level": 300, "exp": 0, "points": 0, "spent": 300, "alloc": {"atk": 60, "def": 60, "hp": 60, "crit": 60, "haste": 60}}
	var menu := GameMenu.new()
	add_child(menu)
	menu.open_menu(&"character")
	await _frames(4)
	_scroll_to_special(menu)
	await _frames(3)
	_shot("0_star300_locked")
	Game.paragon().level = 420
	Game.paragon().exp = 12345
	Game.special_spend("cdmg", 40)
	Game.special_spend("pierce", 25)
	Game.special_spend("guard", 8)
	menu._rebuild()
	await _frames(4)
	_scroll_to_special(menu)
	await _frames(3)
	_shot("1_star420_special")
	get_tree().quit()


## Scrolls the page so the special section is in view.
func _scroll_to_special(menu: Node) -> void:
	var box := menu.find_child("SpecialStats", true, false) as Control
	if box == null:
		return
	var node: Node = box.get_parent()
	while node != null and not node is ScrollContainer:
		node = node.get_parent()
	if node is ScrollContainer:
		(node as ScrollContainer).ensure_control_visible(box)
		(node as ScrollContainer).scroll_vertical = int(box.global_position.y - (node as ScrollContainer).global_position.y + (node as ScrollContainer).scroll_vertical - 260)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join(shot_name + ".png"))
	print("shot ", shot_name)
