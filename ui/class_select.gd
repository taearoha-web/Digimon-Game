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
var _body: BoxContainer
var _stage: HeroPreview
var _grid: GridContainer
var _options: Control


func _ready() -> void:
	_rng.randomize()
	layer = 50
	add_child(UIUtil.sky_background())
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var safe := SafeAreaContainer.new()
	safe.min_margin = 24
	root.add_child(safe)
	var layout := UIUtil.vbox(14)
	safe.add_child(layout)
	var heading := UIUtil.hbox(12)
	layout.add_child(heading)
	var title := UIUtil.label("สร้างฮีโร่ของคุณ", &"HeaderLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var back := UIUtil.button("กลับ", &"GhostButton", Vector2(110, 52))
	back.pressed.connect(func(): cancelled.emit())
	heading.add_child(back)
	_body = BoxContainer.new()
	_body.add_theme_constant_override("separation", 20)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_body)

	var showcase := UIUtil.panel(&"GlassPanel")
	showcase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	showcase.size_flags_stretch_ratio = 0.85
	_body.add_child(showcase)
	var stage_col := UIUtil.vbox(6)
	showcase.add_child(stage_col)
	stage_col.add_child(UIUtil.label("นักเดินทางตัวน้อย", &"SubHeaderLabel", HORIZONTAL_ALIGNMENT_CENTER))
	_stage = HeroPreview.new(Vector2i(300, 300))
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_col.add_child(_stage)
	_pivot = _stage._pivot
	stage_col.add_child(UIUtil.label("ลากเพื่อหมุน · แต่งได้ในแบบของคุณ", &"SmallLabel", HORIZONTAL_ALIGNMENT_CENTER))

	var backing := UIUtil.panel(&"GlassPanel")
	backing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	backing.size_flags_stretch_ratio = 1.6
	_body.add_child(backing)
	var scroll := TouchScroll.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	backing.add_child(scroll)
	var right := UIUtil.vbox(12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(right)
	_options = right
	var gender_row := UIUtil.hbox(8)
	right.add_child(gender_row)
	for g in 2:
		var button := UIUtil.button(FaceKit.GENDER_NAMES[g], &"ChoiceButton", Vector2(120, 54))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func(): _set_gender(g))
		gender_row.add_child(button)
		_gender_buttons.append(button)
	var random_button := UIUtil.button("สุ่มลุค", &"GhostButton", Vector2(120, 54))
	random_button.pressed.connect(func():
		look = FaceKit.random_look(_rng)
		_refresh())
	gender_row.add_child(random_button)

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 8)
	right.add_child(_grid)
	for row in ROWS:
		_grid.add_child(_option_row(String(row[0]), String(row[1])))
	var note := UIUtil.label("เริ่มเป็นนักเดินทาง แล้วเลือกสาย ดาบ / ธนู / เวทย์ / บวช เมื่อเลเวล 10", &"SmallLabel")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(note)
	right.add_child(UIUtil.label("ชื่อฮีโร่", &"BoldLabel"))
	_name_input = LineEdit.new()
	_name_input.max_length = 14
	_name_input.placeholder_text = "ชื่อที่จะอยู่ในการผจญภัยของคุณ"
	_name_input.custom_minimum_size = Vector2(0, 58)
	_name_input.text = "ฮีโร่"
	right.add_child(_name_input)
	var go := UIUtil.button("เริ่มผจญภัย!", &"PrimaryButton", Vector2(220, 62))
	go.pressed.connect(_on_confirm)
	right.add_child(go)
	root.resized.connect(_layout)
	right.resized.connect(_layout)
	_layout()
	_refresh()


func _layout() -> void:
	if _body == null:
		return
	var portrait := get_viewport().get_visible_rect().size.x < 950.0
	_body.vertical = portrait
	_stage.custom_minimum_size = Vector2(270, 240 if portrait else 300)
	_grid.columns = 1 if _options.size.x < 630.0 else 2


func _option_row(key: String, title: String) -> Control:
	var row := UIUtil.hbox(6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := UIUtil.label(title, &"BoldLabel")
	name_label.custom_minimum_size = Vector2(65, 0)
	row.add_child(name_label)
	var left := UIUtil.button("◀", &"", Vector2(46, 54))
	left.pressed.connect(func(): _step(key, -1))
	row.add_child(left)
	var value := UIUtil.label("", &"BoldLabel", HORIZONTAL_ALIGNMENT_CENTER)
	value.custom_minimum_size = Vector2(96, 0)
	value.clip_text = true
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value)
	_value_labels[key] = value
	var right := UIUtil.button("▶", &"", Vector2(46, 54))
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
		var tint := UIPalette.TEXT
		match key:
			"hair_color": tint = FaceKit.HAIR_COLORS[int(look.hair_color)].lerp(Color.WHITE, 0.6)
			"skin": tint = FaceKit.SKINS[int(look.skin)].lerp(Color.WHITE, 0.4)
			"eye_color": tint = FaceKit.EYE_COLORS[int(look.eye_color)].lerp(Color.WHITE, 0.65)
		label.add_theme_color_override("font_color", tint)
	_stage.show_hero(ClassData.START, {}, "", look)
	_preview = _stage.visual


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
