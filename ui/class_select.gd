class_name ClassSelect
extends CanvasLayer
## Character creator: every hero starts as a Vagabond in the stock outfit; the
## player picks gender, hair, skin tone, eyes, nose and mouth and a name. The
## sword / bow / mage / priest line is chosen later, at Lv.10.

signal confirmed(class_id: StringName, hero_name: String, look: Dictionary)
signal cancelled()

const ROWS := [
	["hair", "ทรงผม"], ["hair_color", "สีผม"], ["skin", "สีผิว"], ["eyes", "ทรงตา"],
	["eye_color", "สีตา"], ["nose", "จมูก"], ["mouth", "ปาก"], ["outfit", "ชุด"],
]

var look: Dictionary = FaceKit.default_look()
var _preview: HeroVisual
var _name_input: LineEdit
var _pivot: Node3D
var _spin_dragging := false
var _value_labels: Dictionary = {}
var _gender_buttons: Array[Button] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	layer = 50
	add_child(UIUtil.sky_background())
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var safe := SafeAreaContainer.new()
	root.add_child(safe)
	var frame := Control.new()
	safe.add_child(frame)
	var header := UIUtil.label("สร้างตัวละคร", &"HeaderLabel")
	header.position = Vector2(8, 4)
	frame.add_child(header)

	# 3D preview on the left, close on the face; drag to turn.
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.gui_input.connect(_on_preview_input)
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
	cam.position = Vector3(0, 1.75, 6.2)
	cam.rotation_degrees = Vector3(-4, 0, 0)
	cam.fov = 32
	viewport.add_child(cam)
	_pivot = Node3D.new()
	viewport.add_child(_pivot)

	# Options panel on the right.
	var backing := Panel.new()
	var back_style := StyleBoxFlat.new()
	back_style.bg_color = Color(0.05, 0.1, 0.28, 0.72)
	back_style.set_corner_radius_all(22)
	backing.add_theme_stylebox_override("panel", back_style)
	backing.position = Vector2(446, 52)
	backing.size = Vector2(808, 580)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(backing)
	var right := UIUtil.vbox(10)
	right.position = Vector2(466, 64)
	right.size = Vector2(770, 560)
	frame.add_child(right)

	var gender_row := UIUtil.hbox(10)
	right.add_child(gender_row)
	var gender_title := UIUtil.label("เพศ", &"BoldLabel")
	gender_title.custom_minimum_size = Vector2(110, 0)
	gender_row.add_child(gender_title)
	for g in 2:
		var b := UIUtil.button(FaceKit.GENDER_NAMES[g], &"", Vector2(170, 60))
		b.pressed.connect(func(): _set_gender(g))
		gender_row.add_child(b)
		_gender_buttons.append(b)
	var random_button := UIUtil.button("🎲 สุ่ม", &"", Vector2(150, 60))
	random_button.pressed.connect(func():
		look = FaceKit.random_look(_rng)
		_refresh())
	gender_row.add_child(random_button)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 6)
	right.add_child(grid)
	for row in ROWS:
		grid.add_child(_option_row(String(row[0]), String(row[1])))

	var note := UIUtil.label("ทุกคนเริ่มเป็นนักเดินทางในชุดเริ่มต้น พอถึงเลเวล 10 ค่อยเลือกสาย ดาบ / ธนู / เวทย์ / บวช", &"SmallLabel")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(note)
	var name_row := UIUtil.hbox(10)
	right.add_child(name_row)
	name_row.add_child(UIUtil.label("ชื่อ:", &"BoldLabel"))
	_name_input = LineEdit.new()
	_name_input.max_length = 14
	_name_input.placeholder_text = "ตั้งชื่อฮีโร่"
	_name_input.custom_minimum_size = Vector2(280, 60)
	_name_input.text = "ฮีโร่"
	name_row.add_child(_name_input)
	var go := UIUtil.button("เริ่มผจญภัย!", &"PrimaryButton", Vector2(220, 64))
	go.pressed.connect(_on_confirm)
	name_row.add_child(go)
	var back := UIUtil.button("กลับ", &"", Vector2(110, 64))
	back.pressed.connect(func(): cancelled.emit())
	name_row.add_child(back)
	_refresh()


func _option_row(key: String, title: String) -> Control:
	var row := UIUtil.hbox(6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := UIUtil.label(title, &"BoldLabel")
	name_label.custom_minimum_size = Vector2(84, 0)
	row.add_child(name_label)
	var left := UIUtil.button("◀", &"", Vector2(60, 54))
	left.pressed.connect(func(): _step(key, -1))
	row.add_child(left)
	var value := UIUtil.label("", &"BoldLabel", HORIZONTAL_ALIGNMENT_CENTER)
	value.custom_minimum_size = Vector2(130, 0)
	value.clip_text = true
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value)
	_value_labels[key] = value
	var right := UIUtil.button("▶", &"", Vector2(60, 54))
	right.pressed.connect(func(): _step(key, 1))
	row.add_child(right)
	return row


func _set_gender(g: int) -> void:
	if int(look.gender) == g:
		return
	look["gender"] = g
	look["hair"] = 0
	_refresh()


func _step(key: String, delta: int) -> void:
	var count := FaceKit.option_count(key, int(look.gender))
	look[key] = posmod(int(look[key]) + delta, count)
	_refresh()


func _value_text(key: String) -> String:
	var i := int(look[key])
	match key:
		"hair": return "%s  (%d/%d)" % [FaceKit.HAIR_NAMES[int(look.gender)][i], i + 1, FaceKit.option_count(key, int(look.gender))]
		"hair_color": return FaceKit.HAIR_COLOR_NAMES[i]
		"skin": return FaceKit.SKIN_NAMES[i]
		"eyes": return FaceKit.EYE_NAMES[i]
		"eye_color": return FaceKit.EYE_COLOR_NAMES[i]
		"nose": return FaceKit.NOSE_NAMES[i]
		"mouth": return FaceKit.MOUTH_NAMES[i]
		"outfit": return FaceKit.OUTFITS[i][0]
	return ""


func _refresh() -> void:
	look = FaceKit.repair(look)
	for g in _gender_buttons.size():
		_gender_buttons[g].disabled = int(look.gender) == g
	for key in _value_labels:
		var label: Label = _value_labels[key]
		label.text = _value_text(key)
		var tint := Color.WHITE
		match key:
			"hair_color": tint = FaceKit.HAIR_COLORS[int(look.hair_color)].lerp(Color.WHITE, 0.6)
			"skin": tint = FaceKit.SKINS[int(look.skin)].lerp(Color.WHITE, 0.4)
			"eye_color": tint = FaceKit.EYE_COLORS[int(look.eye_color)].lerp(Color.WHITE, 0.65)
		label.add_theme_color_override("font_color", tint)
	if _preview:
		_preview.queue_free()
	_preview = HeroVisual.new()
	_pivot.add_child(_preview)
	_preview.setup(ClassData.START, "", true, {}, look)


## Drag the preview with a finger (or mouse) to turn the hero.
func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		_pivot.rotation.y += event.relative.x * 0.012
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		_spin_dragging = event.pressed
	elif event is InputEventMouseMotion and _spin_dragging and event.device != InputEvent.DEVICE_ID_EMULATION:
		_pivot.rotation.y += event.relative.x * 0.012


func _on_confirm() -> void:
	var hero_name := _name_input.text.strip_edges()
	if hero_name == "":
		hero_name = "ฮีโร่"
	confirmed.emit(ClassData.START, hero_name, FaceKit.repair(look))
