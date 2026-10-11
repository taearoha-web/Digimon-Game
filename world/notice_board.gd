class_name NoticeBoard
extends Npc
## The daily-quest notice board on the plaza: a roofed wooden board with pinned
## papers. Talking to it opens the daily quests like a villager would.


func setup(p_role: String, p_name: String, _p_class: StringName, p_title := "", _p_model := "", _p_look := {}) -> void:
	role = p_role
	display_name = p_name
	var b := JapanKit.Batch.new()
	JapanKit.notice_board(b)
	b.commit(self, "Board")
	JapanKit.collider(self, Vector3(0, 1.3, 0), Vector3(2.4, 2.6, 0.4))
	var label := Label3D.new()
	label.text = p_name if p_title == "" else "%s\\n%s" % [p_name, p_title]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.0048
	label.font_size = 40
	label.outline_size = 12
	label.modulate = Color("fff2c0")
	label.position = Vector3(0, 3.6, 0)
	label.visibility_range_end = 22.0
	add_child(label)


func face(_point: Vector3) -> void:
	pass
