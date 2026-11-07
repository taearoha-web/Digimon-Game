class_name PetScreen
extends CanvasLayer
## The pet keeper's screen (ผู้ดูแลสัตว์เลี้ยง, next to the village's pet pen): the three
## pets (PetData) with a turning 3D preview, their element, what they are good at, their
## share of the hero's stats and their eight skills with the levels they unlock at. Before
## the hero has a pet it chooses one here, through a confirm step (เลือกแล้วเปลี่ยนไม่ได้);
## afterwards the screen shows only the hero's own pet.

signal pet_chosen(id: String)

const KEEPER := "ผู้ดูแลสัตว์เลี้ยง"
## How fast the preview turns (radians a second).
const SPIN := 0.6

var is_open := false
## The pet shown now and whether the confirm step is up (tests drive these).
var shown := "fire"
var confirming := false
var _root: Control
var _body: Control
var _preview_pivot: Node3D


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.06, 0.05, 0.94)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var safe := SafeAreaContainer.new()
	_root.add_child(safe)
	var frame := Control.new()
	safe.add_child(frame)
	var panel := UIUtil.panel(&"GlassPanel")
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 24
	panel.offset_top = 10
	panel.offset_right = -24
	panel.offset_bottom = -10
	frame.add_child(panel)
	_body = Control.new()
	panel.add_child(_body)


func open_screen() -> void:
	is_open = true
	get_tree().paused = true
	_root.visible = true
	confirming = false
	shown = Game.pet_id() if Game.pet_id() != "" else (shown if PetData.exists(shown) else PetData.ORDER[0])
	AudioManager.play_ui(&"ui_open")
	_build()


func close_screen() -> void:
	is_open = false
	confirming = false
	_root.visible = false
	_preview_pivot = null
	UIUtil.clear(_body)
	get_tree().paused = false


func _process(delta: float) -> void:
	if is_open and is_instance_valid(_preview_pivot):
		_preview_pivot.rotation.y += SPIN * delta


## Shows pet [param id] (tabs while choosing).
func show_pet(id: String) -> void:
	if not PetData.exists(id) or Game.pet_id() != "":
		return
	shown = id
	confirming = false
	_build()


## The confirm step for the pet shown.
func ask_confirm() -> void:
	if Game.pet_id() != "":
		return
	confirming = true
	_build()


## Chooses the pet shown (after the confirm step). False when the hero already has one.
func confirm_choice() -> bool:
	if not Game.choose_pet(shown):
		return false
	confirming = false
	AudioManager.play_sfx(&"quest_complete")
	pet_chosen.emit(shown)
	_build()
	return true


func _build() -> void:
	UIUtil.clear(_body)
	_preview_pivot = null
	var column := UIUtil.vbox(8)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 16
	column.offset_right = -16
	column.offset_top = 10
	column.offset_bottom = -10
	_body.add_child(column)
	var mine := Game.pet_id()
	var head := UIUtil.hbox(12)
	column.add_child(head)
	var title := UIUtil.label("สัตว์เลี้ยงคู่ใจของคุณ" if mine != "" else "เลือกสัตว์เลี้ยงคู่ใจ (เลือกได้ครั้งเดียว)", &"HeaderLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color("c8f08a"))
	head.add_child(title)
	var close := UIUtil.button("ปิด", &"", Vector2(120, 54))
	close.pressed.connect(close_screen)
	head.add_child(close)
	if mine == "":
		var tabs := UIUtil.hbox(10)
		column.add_child(tabs)
		for id in PetData.ORDER:
			var data := PetData.get_pet(id)
			var tab := UIUtil.button("%s · %s" % [String(data.name), String(data.element_name)], &"PrimaryButton" if id == shown else &"", Vector2(0, 58))
			tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tab.add_theme_color_override("font_color", (data.glow as Color) if id != shown else Color.WHITE)
			tab.pressed.connect(func(): show_pet(id))
			tabs.add_child(tab)
	var row := UIUtil.hbox(14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)
	var pet := PetData.get_pet(shown)
	row.add_child(_preview(pet))
	var scroll := TouchScroll.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	var info := UIUtil.vbox(6)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(info)
	var name_label := UIUtil.label("%s  [%s]" % [String(pet.name), String(pet.element_name)], &"SubHeaderLabel")
	name_label.add_theme_color_override("font_color", pet.glow)
	info.add_child(name_label)
	var desc := UIUtil.label(String(pet.desc), &"SmallLabel")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc)
	var level := int(Game.profile.get("level", 1))
	var r: Dictionary = pet.ratios
	var power := "เลเวลเท่าคุณ (Lv.%d) · พลังโจมตี %d%% · HP %d%% · ป้องกัน %d%% ของค่าสถานะคุณ · ตามคุณทุกแมพและสู้เอง ล้มแล้วกลับมาใน %d วินาที" % [level, int(round(float(r.atk) * 100.0)), int(round(float(r.hp) * 100.0)), int(round(float(r.def) * 100.0)), int(PetData.RESPAWN)]
	var power_label := UIUtil.label(power, &"SmallLabel")
	power_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	power_label.add_theme_color_override("font_color", Color("ffe9a8"))
	info.add_child(power_label)
	info.add_child(UIUtil.label("สกิล 8 อย่าง (ใช้เองอัตโนมัติ):", &"BoldLabel"))
	var skills: Array = pet.skills
	for i in skills.size():
		var line := UIUtil.label(("✓ " if level >= PetData.unlock_level(i) else "• ") + PetData.skill_line(skills[i], i), &"SmallLabel")
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_theme_color_override("font_color", Color("e8ffe0") if level >= PetData.unlock_level(i) else Color("9aa8a0"))
		info.add_child(line)
	var buttons := UIUtil.hbox(12)
	column.add_child(buttons)
	if mine != "":
		var note := UIUtil.label("%s อยู่กับคุณแล้ว เดินตามคุณทุกที่ (ยกเว้นดวล 1 ต่อ 1) สัตว์เลี้ยงเลือกแล้วเปลี่ยนไม่ได้" % String(pet.name), &"BoldLabel")
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(note)
	elif confirming:
		var ask := UIUtil.label("เลือก %s เป็นสัตว์เลี้ยงคู่ใจ? เลือกแล้วเปลี่ยนไม่ได้" % String(pet.name), &"BoldLabel")
		ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ask.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ask.add_theme_color_override("font_color", Color("ffd84a"))
		buttons.add_child(ask)
		var yes := UIUtil.button("ยืนยัน", &"PrimaryButton", Vector2(200, 72))
		yes.pressed.connect(func(): confirm_choice())
		buttons.add_child(yes)
		var no := UIUtil.button("ยกเลิก", &"", Vector2(160, 72))
		no.pressed.connect(func():
			confirming = false
			_build())
		buttons.add_child(no)
	else:
		var pick := UIUtil.button("เลือก %s" % String(pet.name), &"PrimaryButton", Vector2(300, 72))
		pick.pressed.connect(ask_confirm)
		buttons.add_child(pick)
		var warn := UIUtil.label("เลือกได้ตัวเดียว เลือกแล้วเปลี่ยนไม่ได้", &"SmallLabel")
		warn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		warn.add_theme_color_override("font_color", Color("ffb0a0"))
		buttons.add_child(warn)


## A small 3D stage with the pet turning on its idle clip (its own world and light).
func _preview(pet: Dictionary) -> Control:
	var holder := SubViewportContainer.new()
	holder.stretch = true
	holder.custom_minimum_size = Vector2(300, 300)
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var view := SubViewport.new()
	view.own_world_3d = true
	view.transparent_bg = true
	view.msaa_3d = Viewport.MSAA_2X
	holder.add_child(view)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.9, 1.0)
	env.ambient_light_energy = 0.7
	world.environment = env
	view.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_energy = 1.2
	view.add_child(sun)
	var h := float(pet.height)
	var camera := Camera3D.new()
	camera.fov = 32.0
	camera.position = Vector3(0, h * 0.62, h * 3.1)
	camera.rotation_degrees = Vector3(-6, 0, 0)
	view.add_child(camera)
	var pivot := Node3D.new()
	view.add_child(pivot)
	var ring := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = h * 0.55
	disc.bottom_radius = h * 0.55
	disc.height = 0.04
	ring.mesh = disc
	ring.material_override = MeshKit.toon((pet.color as Color).darkened(0.2), {"unshaded": true, "alpha": 0.55})
	pivot.add_child(ring)
	var visual := MonsterVisual.new()
	pivot.add_child(visual)
	var skin: Texture2D = load(String(pet.skin)) as Texture2D if String(pet.get("skin", "")) != "" else null
	visual.setup(String(pet.model), h, 0.0, pet.tint, skin)
	pivot.rotation.y = 0.5
	_preview_pivot = pivot
	return holder
