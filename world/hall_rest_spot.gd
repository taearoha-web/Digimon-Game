class_name HallRestSpot
extends Npc
## The rest area's marker in the guild hall (GuildHall.REST): a small incense stand on the
## tatami. Talking to it rests the hero: HP and MP back, and the hall's blessing
## (GuildHallData.grant) for half an hour, once per run (Main._on_npc "hall_rest").


func setup(p_role: String, p_name: String, _p_class: StringName, p_title := "", _p_model := "", _p_look := {}) -> void:
	role = p_role
	display_name = p_name
	var b := JapanKit.Batch.new()
	b.box(Vector3(0, 0.25, 0), Vector3(0.7, 0.5, 0.7), JapanKit.WOOD_DARK)
	b.box(Vector3(0, 0.53, 0), Vector3(0.8, 0.06, 0.8), JapanKit.WOOD_LIGHT)
	b.cyl(Vector3(0, 0.66, 0), 0.22, 0.2, Color("4a6a58"), Vector3.ZERO, 10)
	for k in 3:
		b.cyl(Vector3(-0.06 + k * 0.06, 0.95, 0.03 - k * 0.03), 0.012, 0.4, Color("8a4a30"), Vector3(0, 0, (k - 1) * 6.0), 4)
		b.ball(Vector3(-0.06 + k * 0.06, 1.16, 0.03 - k * 0.03), Vector3(0.05, 0.05, 0.05), Color("ff9a50"), true)
	b.commit(self, "Incense")
	var label := Label3D.new()
	label.text = p_name if p_title == "" else "%s\n%s" % [p_name, p_title]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.0048
	label.font_size = 40
	label.outline_size = 12
	label.modulate = Color("c8f0c8")
	label.position = Vector3(0, 2.4, 0)
	label.visibility_range_end = 22.0
	add_child(label)


func face(_point: Vector3) -> void:
	pass
