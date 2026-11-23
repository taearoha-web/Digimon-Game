extends Node3D
## Picture sheets of every aura / glow that gear gives a hero, drawn by the real
## HeroVisual (EnhanceFx, SetGearArt.aura, GearKit.halo, StoryChapter2Art.aura,
## CostumeArt, DragonGearArt, the wing arts), each cell captioned in Thai with the
## look's name and what unlocks it.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path . \
##     res://tests/tools/aura_sheets.tscn -- OUT_DIR [SHEET ...]
## SHEET: body weapon set250 other costumes (default: all). Writes OUT_DIR/<sheet>.png
## (body -> enhance_body.png, weapon -> enhance_weapon.png).
## Every hero stands far from the others in one shared world; each cell is its own
## SubViewport camera, snapshotted SETTLE seconds after the heroes are dressed, so the
## particles have run. The sheet is laid out in a 2D SubViewport (any size).

const SETTLE := 1.6
const SPACING := 150.0
const BG := Color("eef3f8")
const INK := Color("1d2a3a")
const SUB := Color("4a5a70")
const WARM := Color("b0541a")
const FILES := {"body": "enhance_body", "weapon": "enhance_weapon", "set250": "set250", "other": "other", "costumes": "costumes"}

var _out := ""
var _spot := 1
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	Game.set_process(false)
	GameSettings.load_settings()
	GameSettings.quality = 2
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://auras"
	DirAccess.make_dir_recursive_absolute(_out)
	var sheets: Array = args.slice(1) if args.size() > 1 else ["body", "weapon", "set250", "other", "costumes"]
	_rng.seed = 7
	var world_env := Scenery.environment(self, Color("4f8fd0"), Color("9cc4e4"), Color("e8eef8"), Color(1.0, 0.97, 0.9),
		{"palette": [Color("3f7fc4"), Color("7fb0dc"), Color("b8d4ea")]})
	# AURA_FOG=0: the stage without the field's distance fog / glow (to tell what they add).
	if OS.get_environment("AURA_FOG") == "0":
		world_env.environment.fog_enabled = false
	if OS.get_environment("AURA_GLOW") == "0":
		world_env.environment.glow_enabled = false
	GameSettings.quality = 2
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(9000, 9000)
	ground.mesh = plane
	ground.material_override = MeshKit.toon(Color("7da36a"))
	ground.position = Vector3(2000, 0, 2000)
	add_child(ground)
	for sheet in sheets:
		match String(sheet):
			"body": await _sheet("body", "ออร่าตีบวกทั้งชุด (EnhanceFx.on_body) · ค่า + ต่ำสุดของ อาวุธ/เกราะ/หมวก/รองเท้า", _body_cells(), 10, Vector2i(340, 480))
			"weapon": await _sheet("weapon", "แสงตีบวกอาวุธ (EnhanceWeaponFx) · +7 เรือง · +10~+14 สายฟ้า · +15 วงสายฟ้ารอบมือ", _weapon_cells(), 9, Vector2i(260, 300))
			"set250": await _sheet("set250", "ออร่าเซต 250★ ประจำอาชีพ (SetGearArt.aura) · สวมชิ้นเซต ≥ 4 ชิ้น", _set_cells(), 6, Vector2i(320, 460))
			"other": await _sheet("other", "ออร่า/แสงอื่น ๆ จากอุปกรณ์ ตำแหน่ง และเนื้อเรื่อง", _other_cells(), 6, Vector2i(300, 440))
			"costumes": await _sheet("costumes", "คอสตูม (RewardShop.COSTUMES · CostumeArt) · ทุกชุดมีแสง/ละอองลอยรอบตัว", _costume_cells(), 5, Vector2i(320, 460))
	get_tree().quit()


# --- Gear helpers -----------------------------------------------------------------------

func _gear(cls: String, level: int, rarity: int, plus := 0, slots: Array = ["weapon", "armor", "helm", "boots"]) -> Dictionary:
	var equip := {}
	for slot in slots:
		var item := ItemData.generate(level, StringName(cls), _rng, rarity, slot)
		item["plus"] = plus if EnhanceFx.can_enhance(item) else 0
		equip[slot] = item
	return equip


func _set250(cls: String) -> Dictionary:
	var equip := {}
	for slot in SetGearData.SLOTS:
		equip[slot] = SetGearData.item(cls, slot)
	return equip


func _cell(title: String, need: String, cls: String, equip: Dictionary, view := "full", extra := {}) -> Dictionary:
	var c := {"title": title, "need": need, "cls": cls, "equip": equip, "view": view}
	c.merge(extra, true)
	return c


# --- The sheets' cells ------------------------------------------------------------------

func _body_cells() -> Array:
	var out := []
	for cls in ["muaythai", "warrior"]:
		var th := ClassData.get_class_data(StringName(cls)).get("name", cls) as String
		for side in ["wide", "wide_back"]:
			for plus in [0, 5, 7, 9, 10, 11, 12, 13, 14, 15]:
				var step := EnhanceFx.aura_step(plus)
				var title := "ทั้งชุด +%d · %s" % [plus, EnhanceFx.AURA_NAMES[step] if step > 0 else "ไม่มีออร่า"]
				var need := "%s · ขั้น %d/9 · ทั้ง 4 ชิ้น ≥ +%d" % [th, step, plus] if step > 0 else "%s · ต่ำกว่า +5 ยังไม่มีออร่าตัว" % th
				need += " · %s" % ("ด้านหน้า" if side == "wide" else "ด้านหลัง")
				out.append(_cell(title, need, cls, _gear(cls, 45, 2, plus), side))
	return out


func _weapon_cells() -> Array:
	var out := []
	# Three weapons of different colours (the glow takes the weapon's own colour).
	var rows := [["warrior", "ดาบ (นักรบ)", 35], ["mage", "คทา (นักเวท)", 65], ["muaythai", "สนับมือ (มวยไทย)", 75]]
	for row in rows:
		for plus in [0, 7, 9, 10, 11, 12, 13, 14, 15]:
			var equip := _gear(row[0], row[2], 2, 0)
			equip.weapon["plus"] = plus
			var p := EnhanceWeaponFx.plan(plus)
			var need := "+0 ~ +6 ไม่มีแสง"
			if plus >= 15:
				need = "สายฟ้า %d สาย + วงสายฟ้ารอบมือ" % int(p.strands)
			elif plus >= 10:
				need = "สายฟ้าแลบตามอาวุธ %d สาย" % int(p.strands)
			elif plus == 9:
				need = "เรืองชัดขึ้น สีของอาวุธเอง"
			elif plus >= 7:
				need = "เรืองจาง ๆ สีของอาวุธเอง"
			out.append(_cell("%s +%d" % [row[1], plus], need, row[0], equip, "weapon"))
	return out


func _set_cells() -> Array:
	var out := []
	for cls in StarGearData.CLASSES:
		var th := ClassData.get_class_data(StringName(cls)).get("name", cls) as String
		out.append(_cell("ชุดเซต%s" % SetGearData.THEMES[cls], "%s · 250★ · สวม ≥ 4 ชิ้นของเซต (+0 ก็ได้)" % th, cls, _set250(cls), "set"))
	return out


func _other_cells() -> Array:
	var out := []
	out.append(_cell("ประกายม่วงของตำนาน", "สวมชิ้นใดก็ได้ระดับ ในตำนาน/เทพนิยาย (rarity ≥ 3) · ของ Lv.45", "warrior", _gear("warrior", 45, 3)))
	for t in [[65, 6], [75, 7], [85, 8], [95, 9]]:
		var lv: int = t[0]
		var title := "ออร่าเกียร์ระดับ %d" % t[1] + (" + วงรัศมี" if t[1] >= 8 else "")
		out.append(_cell(title, "ชิ้นสูงสุด (อาวุธ/เกราะ/หมวก/รองเท้า) Lv.%d-%d%s" % [t[1] * 10 + 1, t[1] * 10 + 10,
			" · หมวกต้องไม่ใช่ของดาว/เซต" if t[1] >= 8 else ""], "warrior", _gear("warrior", lv, 2)))
	var gem_equip := _gear("warrior", 45, 2)
	gem_equip.weapon["gems"] = ["ruby_4"]
	gem_equip.armor["gems"] = ["sapphire_4"]
	gem_equip.helm["gems"] = ["emerald_4"]
	gem_equip.boots["gems"] = ["topaz_4"]
	out.append(_cell("ประกายอัญมณีตำนาน", "ใส่อัญมณีขนาด \"ตำนาน\" (ขั้น 5) ในชิ้นนั้น · สีตามอัญมณี", "warrior", gem_equip, "near"))
	out.append(_cell("รัศมีดาวเงา", "จบเนื้อเรื่องบทที่ 2 (flag ch2_aura)", "warrior", _gear("warrior", 45, 2), "full", {"story": true}))
	for plus in [0, 10, 15]:
		var e := _gear("warrior", 45, 2)
		e["wings"] = StarWingData.item("warrior", _rng, 3)
		e.wings["plus"] = plus
		out.append(_cell("ปีก 100★ +%d%s" % [plus, " · แสงปีก" if plus >= 10 else ""],
			"ปีกตีบวก ≥ +10: ปีกเรือง + ขนนกแสงร่วง (+15 สีรุ้ง)" if plus >= 10 else "อ้างอิง: ปีกดาวไม่ตีบวก", "warrior", e, "back"))
	var lw := _gear("warrior", 45, 2)
	lw["wings"] = LegendWings.item(1, 0)
	out.append(_cell("ปีกตำนานแห่งกิลด์", "กิลด์อันดับ 1 ของฤดูลีก (หัวหน้า/สมาชิกที่ได้รับ) · ละอองทองร่วง", "warrior", lw, "back"))
	for cls in ["warrior", "muaythai"]:
		var d := _set250(cls)
		d["weapon"] = DragonGearData.weapon(StringName(cls), _rng)
		d.weapon["plus"] = 15
		d["wings"] = DragonGearData.wings(StringName(cls), _rng)
		var th := ClassData.get_class_data(StringName(cls)).get("name", cls) as String
		out.append(_cell("เทพมังกร %s · หน้า" % th, "อาวุธเทพมังกร +15 + ปีกเทพมังกร + เซต 250★ · ดรอปเกาะลอยฟ้าเทพมังกร", cls, d, "full"))
		out.append(_cell("เทพมังกร %s · หลัง" % th, "ปีก/ผ้าคลุมเทพมังกร 300★ (ปีก +0)", cls, d.duplicate(true), "back"))
	for cls in ["warrior", "muaythai"]:
		var dv := {}
		for slot in DivineGearData.SLOTS:
			dv[slot] = DivineGearData.item(StringName(cls), slot, _rng)
		out.append(_cell("Lotus 200★ %s" % DivineGearData.THEMES[cls], "ชุดประจำอาชีพ ดรอปที่ Lotus Sanctum · +0 · ไม่มีออร่าเฉพาะของชุด", cls, dv))
	for stars in [50, 100, 150, 200]:
		var sg := {}
		for slot in ItemData.SLOTS:
			sg[slot] = StarProgression.item(&"warrior", stars, slot, _rng)
		out.append(_cell("ชุดดาว %d★ (%s)" % [stars, StarGearData.THEME_NAMES[[50, 100, 150, 200].find(stars)]],
			"คอลเลกชันดาว %d★ · +0 · ไม่มีออร่าเฉพาะ" % stars, "warrior", sg))
	for cls in ["muaythai", "darklord", "assassin", "bard"]:
		var e := _gear(cls, 45, 2)
		e["wings"] = StarWingData.item(cls, _rng, 3)
		out.append(_cell(StarWingData.item_name(cls), "ปีก/ผ้าคลุม 100★ ของอาชีพ (+0) · แสงในตัว (shader)", cls, e, "back"))
	out.append(_cell("เทพราชันหนึ่งในใต้หล้า", "แชมป์สังหารสูงสุดเขาวงกตหนึ่งในใต้หล้าประจำสัปดาห์ · คอสตูม + ตำแหน่ง", "warrior",
		_gear("warrior", 45, 2), "tall", {"costume": MazeCrown.COSTUME_ID, "plate": true}))
	return out


func _costume_cells() -> Array:
	var out := []
	for id in RewardShop.COSTUMES:
		var c: Dictionary = RewardShop.COSTUMES[id]
		var need := ""
		if bool(c.get("crown", false)):
			need = "แชมป์เขาวงกตหนึ่งในใต้หล้าประจำสัปดาห์"
		elif c.has("festival"):
			need = "แลก %d ชิ้นส่วนลอยกระทง ช่วงเทศกาล" % int(c.get("fragments", 0))
		elif c.has("fragments"):
			need = "แลก %d ชิ้นส่วนชุดเทพมังกร (เกาะลอยฟ้า)" % int(c.fragments)
		else:
			need = "ร้านรางวัล %d เหรียญ%s" % [int(c.lc), (" + %d แต้ม" % int(c.ep)) if int(c.ep) > 0 else ""]
		out.append(_cell(String(c.name), need, "warrior", _gear("warrior", 45, 2), "full", {"costume": id}))
	return out


# --- Rendering -------------------------------------------------------------------------

func _sheet(key: String, heading: String, cells: Array, cols: int, size: Vector2i) -> void:
	var made := []
	for spec in cells:
		made.append(_stage(spec, size))
	await get_tree().process_frame
	await get_tree().process_frame
	for m in made:
		_frame(m)
	await get_tree().create_timer(SETTLE - 0.25).timeout
	# Frame again once the idle pose has settled (the held weapon moves with it).
	for m in made:
		_frame(m)
	await get_tree().create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	var shots: Array[Image] = []
	for m in made:
		shots.append((m.vp as SubViewport).get_texture().get_image())
	# Lay the sheet out.
	var cap := 74
	var pad := 10
	var top := 64
	var rows := ceili(float(cells.size()) / float(cols))
	var sheet := SubViewport.new()
	sheet.disable_3d = true
	# Its own empty world: the stage's glow must not soften the captions.
	sheet.own_world_3d = true
	sheet.world_3d = World3D.new()
	sheet.transparent_bg = false
	sheet.size = Vector2i(pad + cols * (size.x + pad), top + rows * (size.y + cap + pad) + pad)
	sheet.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sheet)
	var bg := ColorRect.new()
	bg.color = BG
	bg.size = sheet.size
	sheet.add_child(bg)
	var head := Label.new()
	head.text = "Toon Tale · " + heading
	head.position = Vector2(pad + 4, 12)
	head.add_theme_font_size_override("font_size", 30)
	head.add_theme_color_override("font_color", INK)
	sheet.add_child(head)
	for i in cells.size():
		var spec: Dictionary = cells[i]
		var at := Vector2(pad + (i % cols) * (size.x + pad), top + (i / cols) * (size.y + cap + pad))
		var card := ColorRect.new()
		card.color = Color.WHITE
		card.position = at
		card.size = Vector2(size.x, size.y + cap)
		sheet.add_child(card)
		var pic := TextureRect.new()
		pic.texture = ImageTexture.create_from_image(shots[i])
		pic.position = at
		pic.size = size
		sheet.add_child(pic)
		var t := Label.new()
		t.text = String(spec.title)
		t.position = at + Vector2(8, size.y + 4)
		t.size = Vector2(size.x - 16, 30)
		t.clip_text = true
		t.add_theme_font_size_override("font_size", 19)
		t.add_theme_color_override("font_color", WARM if String(spec.view) != "weapon" else INK)
		sheet.add_child(t)
		var n := Label.new()
		n.text = String(spec.need)
		n.position = at + Vector2(8, size.y + 32)
		n.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		n.add_theme_font_size_override("font_size", 14)
		n.add_theme_constant_override("line_spacing", -3)
		n.add_theme_color_override("font_color", SUB)
		sheet.add_child(n)
		n.custom_minimum_size = Vector2(size.x - 16, 0)
		n.size = Vector2(size.x - 16, 40)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [_out, FILES.get(key, key)]
	sheet.get_texture().get_image().save_png(path)
	print("AURA SHEET ", path, " ", sheet.size)
	sheet.queue_free()
	for m in made:
		(m.hero as Node).queue_free()
		(m.vp as Node).queue_free()
	await get_tree().process_frame


func _stage(spec: Dictionary, size: Vector2i) -> Dictionary:
	var at := Vector3(float(_spot % 20) * SPACING, 0, float(_spot / 20) * SPACING)
	_spot += 1
	var h := HeroVisual.new()
	h.costume = String(spec.get("costume", ""))
	h.story_aura = bool(spec.get("story", false))
	add_child(h)
	h.position = at
	h.setup(StringName(spec.cls), "", true, spec.equip, FaceKit.default_look())
	h.play("Idle")
	if bool(spec.get("plate", false)):
		var label := Label3D.new()
		label.text = "ฮีโร่ทูนเทล"
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = 0.0034
		label.font_size = 34
		label.outline_size = 9
		label.modulate = Color("fff4de")
		label.outline_modulate = Color(0.1, 0.12, 0.2, 0.9)
		label.no_depth_test = true
		label.position = Vector3(0, Hero.NAME_PLATE_Y + CostumeArt.plate_lift(String(spec.costume)), 0)
		h.add_child(label)
		MazeCrown.attach_plate(label, true)
	var vp := SubViewport.new()
	vp.size = size
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.current = true
	return {"hero": h, "vp": vp, "cam": cam, "spec": spec, "at": at}


func _frame(m: Dictionary) -> void:
	var h: HeroVisual = m.hero
	var cam: Camera3D = m.cam
	var at: Vector3 = m.at
	var view := String(m.spec.view)
	match view:
		"weapon":
			# Frame the held weapon's own meshes (not its glow quads and orbs).
			var grip: Node3D = h._emission_grip
			var box := AABB(at + Vector3(0, 1.0, 0), Vector3.ONE * 0.3)
			if is_instance_valid(grip):
				var first := true
				for mi in grip.find_children("*", "MeshInstance3D", true, false):
					var mesh := mi as MeshInstance3D
					var add := mesh.material_override is BaseMaterial3D and (mesh.material_override as BaseMaterial3D).blend_mode == BaseMaterial3D.BLEND_MODE_ADD
					if mesh.mesh == null or mesh.mesh is QuadMesh or add or mesh.name == EnhanceWeaponFx.ARC_NAME:
						continue
					var b := mesh.global_transform * mesh.get_aabb()
					box = b if first else box.merge(b)
					first = false
			var c := box.get_center()
			var reach := maxf(box.size.length(), 0.45)
			cam.fov = 34
			cam.position = c + Vector3(0.35, 0.2, 1.0).normalized() * (reach * 1.15 + 0.55)
			cam.look_at(c, Vector3.UP)
		"armor":
			var c := at + Vector3(0, 0.95, 0)
			cam.fov = 34
			cam.position = c + Vector3(0.45, 0.2, 1.0).normalized() * 3.4
			cam.look_at(c, Vector3.UP)
		"back":
			var c := at + Vector3(0, 1.3, 0)
			cam.fov = 40
			cam.position = c + Vector3(-0.5, 0.22, -1.0).normalized() * 4.8
			cam.look_at(c, Vector3.UP)
		"wide", "wide_back":
			var c := at + Vector3(0, 1.45, 0)
			cam.fov = 40
			var dir := Vector3(0.6, 0.2, 1.0) if view == "wide" else Vector3(-0.75, 0.25, -1.0)
			cam.position = c + dir.normalized() * 5.6
			cam.look_at(c, Vector3.UP)
		"near":
			var c := at + Vector3(0, 1.1, 0)
			cam.fov = 40
			cam.position = c + Vector3(0.35, 0.2, 1.0).normalized() * 4.1
			cam.look_at(c, Vector3.UP)
		"tall":
			var c := at + Vector3(0, 1.75, 0)
			cam.fov = 40
			cam.position = c + Vector3(0.45, 0.12, 1.0).normalized() * 5.6
			cam.look_at(c, Vector3.UP)
		"set":
			var c := at + Vector3(0, 1.05, 0)
			cam.fov = 38
			# The Defender's great shield stands in front of it: look from its open side.
			var dir := Vector3(-1.0, 0.5, 0.55) if String(m.spec.cls) == "defender" else Vector3(0.4, 0.45, 1.0)
			cam.position = c + dir.normalized() * 6.2
			cam.look_at(c, Vector3.UP)
		_:
			var c := at + Vector3(0, 1.25, 0)
			cam.fov = 40
			cam.position = c + Vector3(0.45, 0.22, 1.0).normalized() * 4.6
			cam.look_at(c, Vector3.UP)
