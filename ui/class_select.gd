class_name ClassSelect
extends CanvasLayer
## Character creator: every hero starts as a Vagabond in the stock outfit; the
## player picks the body (boy or girl), one of its three styles (ChibiLook) and may
## change the hair colour, skin tone, eye colour and accessory, then a name. The
## sword / bow / mage / priest line is chosen later, at Lv.10.

signal confirmed(class_id: StringName, hero_name: String, look: Dictionary)
signal cancelled()

const ROWS := [["hair_tint", "สีผม"], ["skin_tone", "สีผิว"], ["eye_tint", "สีตา"], ["acc", "ประดับ"]]

var look: Dictionary = FaceKit.default_look()
var _preview: HeroVisual
var _name_input: LineEdit
var _pivot: Node3D
var _spin_dragging := false
var _value_labels: Dictionary = {}
var _gender_buttons: Array[Button] = []
var _style_buttons: Array[Button] = []
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
	stage_col.add_child(UIUtil.label("ลากเพื่อหมุน · เลือกตัวละคร แล้วปรับสีได้", &"SmallLabel", HORIZONTAL_ALIGNMENT_CENTER))

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
	random_button.pressed.connect(_randomize)
	gender_row.add_child(random_button)
	right.add_child(UIUtil.label("ตัวละคร", &"BoldLabel"))
	var style_row := UIUtil.hbox(8)
	right.add_child(style_row)
	for i in ChibiLook.count("style"):
		var button := UIUtil.button("", &"ChoiceButton", Vector2(120, 54))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		button.pressed.connect(func(): _set_style(i))
		style_row.add_child(button)
		_style_buttons.append(button)

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 8)
	right.add_child(_grid)
	for row in ROWS:
		_grid.add_child(_option_row(String(row[0]), String(row[1])))
	var note := UIUtil.label("เริ่มเป็นนักเดินทาง แล้วเลือกสาย ดาบ / ธนู / เวทย์ / บวช / อสูร / หอก เมื่อเลเวล 10", &"SmallLabel")
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
	ChibiLook.apply_style(look, int(look.get("style", 0)))
	_refresh()


func _set_style(style: int) -> void:
	ChibiLook.apply_style(look, style)
	_refresh()


## A random style with random colours (an accessory one time in two).
func _randomize() -> void:
	look["gender"] = _rng.randi() % 2
	ChibiLook.apply_style(look, _rng.randi() % ChibiLook.count("style"))
	for key in ["skin_tone", "hair_tint", "eye_tint"]:
		look[key] = 1 + _rng.randi() % (ChibiLook.count(key) - 1)
	look["acc"] = 0 if _rng.randf() < 0.5 else 1 + _rng.randi() % (ChibiLook.count("acc") - 1)
	_refresh()


## Steps a part through its values; tints pass "สีเดิม" (the original texture, 0).
func _step(key: String, delta: int) -> void:
	look[key] = posmod(int(look.get(key, 0)) + delta, ChibiLook.count(key))
	_refresh()


func _value_text(key: String) -> String:
	var i := int(look[key])
	if key in ChibiLook.KEYS:
		return ChibiLook.value_name(key, i)
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
	for i in _style_buttons.size():
		_style_buttons[i].text = ChibiLook.style_name(int(look.gender), i)
		_style_buttons[i].disabled = int(look.get("style", 0)) == i
	for key in _value_labels:
		var label: Label = _value_labels[key]
		label.text = _value_text(key)
		var tint := UIPalette.TEXT
		var color: Variant = ChibiLook.tint(key, int(look.get(key, 0)))
		if color is Color:
			tint = (color as Color).lerp(Color.WHITE, 0.3 if key == "skin_tone" else 0.45)
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
