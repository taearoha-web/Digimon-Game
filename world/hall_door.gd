class_name HallDoor
extends Npc
## The door to the guild halls at the foot of the village keep (JapanVillage.GUILD_HALL):
## a roofed gate with the four guilds' colours on its plaque. Talking to it takes a guild
## member into its own guild's hall (GuildHallData.enter_problem); anyone else is turned
## away in Thai (Main._on_npc "hall_door").


func setup(p_role: String, p_name: String, _p_class: StringName, p_title := "", _p_model := "", _p_look := {}) -> void:
	role = p_role
	display_name = p_name
	var b := JapanKit.Batch.new()
	for x in [-1.3, 1.3]:
		b.box(Vector3(x, 1.5, 0), Vector3(0.3, 3.0, 0.3), JapanKit.WOOD_DARK)
	b.box(Vector3(0, 3.1, 0), Vector3(3.4, 0.3, 0.4), JapanKit.WOOD_DARK)
	b.roof(Vector3(0, 3.55, 0), 4.0, 1.6, 0.6, JapanKit.TILE_DARK, 0.7)
	# The doorway: dark, with a gold crest and the four guilds' squares on the plaque.
	b.box(Vector3(0, 1.4, -0.08), Vector3(2.3, 2.8, 0.08), Color("2a2430"))
	b.cyl(Vector3(0, 2.2, -0.02), 0.32, 0.06, JapanKit.GOLD, Vector3(90, 0, 0), 12)
	var k := 0
	for g in WorldPlayers.GUILDS:
		var color: Color = WorldPlayers.GUILD_COLORS[g]
		b.box(Vector3(-0.75 + k * 0.5, 0.75, -0.02), Vector3(0.36, 0.36, 0.06), color, Vector3.ZERO, true)
		k += 1
	for x in [-1.9, 1.9]:
		JapanKit.chochin(b, Vector3(x, 2.5, 0.2), Color("f0b040"), 0.8)
	b.commit(self, "Door")
	JapanKit.collider(self, Vector3(0, 1.5, -0.05), Vector3(3.0, 3.0, 0.5))
	var label := Label3D.new()
	label.text = p_name if p_title == "" else "%s\n%s" % [p_name, p_title]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.0048
	label.font_size = 40
	label.outline_size = 12
	label.modulate = Color("fff2c0")
	label.position = Vector3(0, 4.4, 0)
	label.visibility_range_end = 22.0
	add_child(label)


func face(_point: Vector3) -> void:
	pass
