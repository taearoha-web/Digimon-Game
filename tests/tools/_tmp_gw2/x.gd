extends Node
## TEMP (deleted after use): renders the two-switch castle for the report.
## xvfb-run godot --rendering-driver opengl3 --resolution 1600x900 --path . res://tests/tools/_tmp_gw2/x.tscn -- <out_dir>
var out_dir := "user://shots"
var main: Node
var font: FontFile


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, name]
	img.save_png(path)
	print("SHOT ", path)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	font = load("res://assets/fonts/NotoSansThai-Variable.ttf")
	get_window().size = Vector2i(1600, 900)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _wait(0.5)
	var cls := &"lancer"
	Game.new_profile(cls, "ทดสอบ")
	Game.profile["level"] = 100
	Game.profile["adv"] = 4
	Game.profile["paragon"] = {"level": 200, "exp": 0, "points": 0, "spent": 0, "alloc": Game.party_star_alloc(200)}
	var gear_rng := RandomNumberGenerator.new()
	gear_rng.seed = 11
	for slot in ItemData.SLOTS:
		Game.profile.equip[slot] = StarProgression.item(cls, 200, slot, gear_rng)
	Game.profile.hp = Game.stats_now().max_hp
	main.title_screen.queue_free()
	main.title_screen = null
	main.hud.visible = true
	Game.playing = true
	await main.go(&"town", true)
	await _wait(1.0)
	await main.go(&"guildwar", false, true)
	await _wait(1.0)
	var zone: Zone = main.zone
	var m: GuildWarMatch = zone.gw_match
	var play_camera := get_viewport().get_camera_3d()
	# --- 1. the map from straight above, labelled -------------------------------
	main.hud.visible = false
	await _wait(6.0)
	var hidden: Array = []
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if n is ToastLayer or n.name.to_lower().contains("toast"):
			(n as CanvasLayer).visible = false
			hidden.append(n)
	for env in zone.find_children("*", "WorldEnvironment", true, false):
		(env as WorldEnvironment).environment.fog_enabled = false
		(env as WorldEnvironment).environment.volumetric_fog_enabled = false
	var top := Camera3D.new()
	zone.add_child(top)
	top.projection = Camera3D.PROJECTION_ORTHOGONAL
	top.size = 214.0
	top.near = 1.0
	top.far = 600.0
	top.global_position = Vector3(0, 240.0, -60.0)
	top.rotation_degrees = Vector3(-90, 0, 0)
	top.current = true
	await _wait(0.6)
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var lines := Control.new()
	lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(lines)
	_title(layer, "แมพกิลวอแบบใหม่ (มองจากด้านบน) — สวิตช์ซ้าย/ขวา + แท่นยึดชิดท้ายห้องบัลลังก์")
	var S := SiegeArena
	_tag(layer, lines, top, S.SWITCHES[0], Vector2(-330, -40), "สวิตช์ซ้าย", Color("ffd34d"))
	_tag(layer, lines, top, S.SWITCHES[1], Vector2(150, -40), "สวิตช์ขวา", Color("ffd34d"))
	_tag(layer, lines, top, S.ALTAR, Vector2(150, -10), "แท่นยึดปราสาท (ชิดผนังหลัง)", Color("ffffff"))
	_tag(layer, lines, top, S.KEEP_CAMP, Vector2(160, 20), "จุดเกิดใหม่ของผู้ครองปราสาท", Color("ffb35a"))
	_tag(layer, lines, top, Vector3(0, 0, S.GATE_Z[2]), Vector2(-300, 8), "ประตูชั้น 3 (ประตูห้องบัลลังก์)", Color("b8f0c0"))
	_tag(layer, lines, top, Vector3(-S.LANE_X, 0, S.GATE_Z[1]), Vector2(-260, 0), "ประตูชั้น 2 ซ้าย/ขวา", Color("b8f0c0"))
	_tag(layer, lines, top, Vector3(-S.LANE_X, 0, S.GATE_Z[0]), Vector2(-260, 10), "ประตูชั้น 1 ซ้าย/ขวา", Color("b8f0c0"))
	_tag(layer, lines, top, S.camp(0), Vector2(-90, -80), "ค่ายกิล A (ตะวันตก)", Color("8fc4ff"))
	_tag(layer, lines, top, S.camp(1), Vector2(-120, -80), "ค่ายกิล B (ตะวันออก)", Color("ff9a8a"))
	_rule(layer, "กติกา: บาเรียแท่นเปิดให้กิลด์ที่ถือ \"ครบทั้งสองสวิตช์\" เท่านั้น — สวิตช์แยกกันคนละกิลด์ = บาเรียปิด การนับหยุดรอ")
	await _wait(0.3)
	await _shot("gw2_map")
	layer.queue_free()
	top.queue_free()
	for n in hidden:
		(n as CanvasLayer).visible = true
	# --- 2. the war in the throne room ------------------------------------------
	main.hud.visible = true
	play_camera.current = true
	for g in m.gates:
		g.set_broken_quietly()
	m._update_breakable()
	m._assign_objectives()
	await _wait(5.2)
	# Ours just inside the door, theirs spread over the room: two on each switch, the
	# rest round the altar; the hero leads ours and splits the guild between the switches.
	var k := 0
	for f in m.allies:
		f.global_position = Vector3(float(k % 8 - 4) * 1.8, 0.3, S.GATE_Z[2] - 3.0 - float(k / 8) * 1.8)
		k += 1
	k = 0
	for f in m.enemies:
		var spot: Vector3
		if k < 2:
			spot = S.SWITCHES[0] + Vector3(float(k) * 1.2 - 0.6, 0.3, 0)
		elif k < 4:
			spot = S.SWITCHES[1] + Vector3(float(k - 2) * 1.2 - 0.6, 0.3, 0)
		else:
			spot = S.ALTAR + Vector3(cos(float(k)) * 6.0, 0.3, sin(float(k)) * 4.0 + 2.0)
		f.global_position = spot
		k += 1
	zone.hero.global_position = Vector3(0, 0.3, S.GATE_Z[2] - 8.0)
	var said := m.order_guild("switches")
	print("ORDER ", said)
	await _wait(9.0)
	print("SWITCHES ", m.switch_owners, " ", m.switch_text(), " | ", m.barrier_open_text())
	var cam := Camera3D.new()
	zone.add_child(cam)
	cam.fov = 58.0
	cam.global_position = Vector3(0, 52.0, S.GATE_Z[2] + 8.0)
	cam.look_at(Vector3(0, 0, S.SWITCH_Z - 14.0), Vector3.UP)
	cam.current = true
	await _wait(0.4)
	await _shot("gw2_throne")
	# --- 3. the leader's orders panel over the split ----------------------------
	var hud: GuildWarHud = null
	for n in get_tree().root.find_children("*", "GuildWarHud", true, false):
		hud = n as GuildWarHud
	if hud != null:
		hud.open_orders()
	await _wait(0.5)
	await _shot("gw2_orders")
	if hud != null:
		hud.close_orders()
	await _wait(3.0)
	await _shot("gw2_split")
	print("PLANS ", m.plans_line())
	get_tree().quit()


func _title(layer: CanvasLayer, text: String) -> void:
	var bar := ColorRect.new()
	bar.color = Color(0.07, 0.09, 0.13, 0.95)
	bar.position = Vector2.ZERO
	bar.size = Vector2(1600, 52)
	layer.add_child(bar)
	var l := _label(text, Color.WHITE, 24)
	l.position = Vector2(20, 8)
	layer.add_child(l)


func _rule(layer: CanvasLayer, text: String) -> void:
	var l := _label(text, Color("ffe08a"), 20)
	l.position = Vector2(20, 860)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.09, 0.13, 0.9)
	bg.position = Vector2(0, 852)
	bg.size = Vector2(1600, 48)
	layer.add_child(bg)
	layer.add_child(l)


func _label(text: String, color: Color, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _tag(layer: CanvasLayer, lines: Control, cam: Camera3D, at: Vector3, offset: Vector2, text: String, color: Color) -> void:
	var p := cam.unproject_position(at)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.09, 0.13, 0.9)
	sb.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", sb)
	panel.add_child(_label(text, color, 22))
	panel.position = p + offset
	layer.add_child(panel)
	var line := Line2D.new()
	line.width = 2.0
	line.default_color = color
	var end := p + offset + Vector2(0, 18)
	if offset.x < 0:
		end.x += 0.0
	line.points = PackedVector2Array([p, end])
	lines.add_child(line)
	var dot := Line2D.new()
	dot.width = 8.0
	dot.default_color = color
	dot.points = PackedVector2Array([p - Vector2(4, 0), p + Vector2(4, 0)])
	lines.add_child(dot)
