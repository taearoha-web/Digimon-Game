class_name ClassSelect
extends CanvasLayer
## Pick one of four classes (3D preview, description, skills) and a name.

signal confirmed(class_id: StringName, hero_name: String)
signal cancelled()

var _selected: StringName = &"warrior"
var _preview: HeroVisual
var _cards: Dictionary = {}
var _name_input: LineEdit
var _desc: Label
var _title: Label
var _skills_box: VBoxContainer
var _pivot: Node3D


func _ready() -> void:
	layer = 50
	add_child(UIUtil.digital_background())
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var safe := SafeAreaContainer.new()
	root.add_child(safe)
	var frame := Control.new()
	safe.add_child(frame)
	var header := UIUtil.label("เลือกอาชีพของคุณ", &"HeaderLabel")
	header.position = Vector2(8, 4)
	frame.add_child(header)

	# 3D preview on the left.
	var container := SubViewportContainer.new()
	container.stretch = true
	container.position = Vector2(8, 60)
	container.size = Vector2(430, 560)
	frame.add_child(container)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.size = Vector2i(430, 560)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.92, 1.0)
	env.ambient_light_energy = 0.9
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 35, 0)
	viewport.add_child(light)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.15, 5.4)
	cam.rotation_degrees = Vector3(-6, 0, 0)
	cam.fov = 38
	viewport.add_child(cam)
	_pivot = Node3D.new()
	viewport.add_child(_pivot)

	# Class cards + details on the right.
	var right := UIUtil.vbox(10)
	right.position = Vector2(460, 56)
	right.size = Vector2(780, 600)
	frame.add_child(right)
	var row := UIUtil.hbox(10)
	right.add_child(row)
	for id in ClassData.IDS:
		var data := ClassData.get_class_data(id)
		var card := UIUtil.button(String(data.name), &"", Vector2(180, 74))
		card.pressed.connect(func(): _select(id))
		row.add_child(card)
		_cards[id] = card
	_title = UIUtil.label("", &"SubHeaderLabel")
	right.add_child(_title)
	_desc = UIUtil.label("", &"BoldLabel")
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(740, 0)
	right.add_child(_desc)
	_skills_box = UIUtil.vbox(4)
	right.add_child(_skills_box)
	var name_row := UIUtil.hbox(10)
	right.add_child(name_row)
	name_row.add_child(UIUtil.label("ชื่อ:", &"BoldLabel"))
	_name_input = LineEdit.new()
	_name_input.max_length = 14
	_name_input.placeholder_text = "ตั้งชื่อฮีโร่"
	_name_input.custom_minimum_size = Vector2(300, 60)
	_name_input.text = "ฮีโร่"
	name_row.add_child(_name_input)
	var go := UIUtil.button("เริ่มผจญภัย!", &"PrimaryButton", Vector2(240, 68))
	go.pressed.connect(_on_confirm)
	name_row.add_child(go)
	var back := UIUtil.button("กลับ", &"", Vector2(120, 68))
	back.pressed.connect(func(): cancelled.emit())
	name_row.add_child(back)
	_select(&"warrior")


func _process(delta: float) -> void:
	if _pivot:
		_pivot.rotation.y += delta * 0.6


func _select(id: StringName) -> void:
	_selected = id
	var data := ClassData.get_class_data(id)
	for key in _cards:
		_cards[key].disabled = key == id
	if _preview:
		_preview.queue_free()
	_preview = HeroVisual.new()
	_pivot.add_child(_preview)
	_preview.setup(id)
	_title.text = "%s — %s" % [data.name, data.title]
	_desc.text = data.desc
	UIUtil.clear(_skills_box)
	for skill in data.skills:
		var line := UIUtil.label("• %s (Lv.%d)  %s" % [skill.name, int(skill.level), skill.desc], &"SmallLabel")
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(740, 0)
		_skills_box.add_child(line)
	AudioManager.play_ui(&"ui_select")


func _on_confirm() -> void:
	var hero_name := _name_input.text.strip_edges()
	if hero_name == "":
		hero_name = "ฮีโร่"
	confirmed.emit(_selected, hero_name)
