class_name ClassSelect
extends CanvasLayer
## Character creator: the player picks the class (one of the ten, sword to lute: it
## plays from Lv.1), the gender (boy or girl), one of that gender's four characters
## (ChibiBodies: the original chibi and three more, shown as portrait cards), then a
## name. Hair, eyes, skin and accessories are not customised: the hero wears its
## character's own designed look (FaceKit.hero_look).
## With [member pick_only] it is only the class picker: an old save still a Vagabond
## (ClassData.LEGACY) picks its class once on load (main.gd _pick_class).

signal confirmed(class_id: StringName, hero_name: String, look: Dictionary)
signal cancelled()

const MAIN_NAMES := {"str": "STR พลัง", "int": "INT ปัญญา", "dex": "DEX ความคล่อง", "vit": "VIT ความทนทาน"}
var look: Dictionary = FaceKit.hero_look({})
## The class picked (one of ClassData.IDS).
var picked: StringName = ClassData.DEFAULT
## Only the class picker (an old Vagabond save on load): no look, no name.
var pick_only := false
## The name shown in pick_only mode (the hero's own).
var hero_name_fixed := ""
var _class_buttons: Dictionary = {}
var _class_grid: GridContainer
var _class_title: Label
var _class_desc: Label
var _class_role: Label
var _class_main: Label
var _class_skills: Label
var _stage_title: Label
var _preview: HeroVisual
var _name_input: LineEdit
var _pivot: Node3D
var _spin_dragging := false
var _gender_buttons: Array[Button] = []
var _body_cards: Array[Button] = []
var _body_names: Array[Label] = []
var _body_pics: Array[TextureRect] = []
var _body: BoxContainer
var _stage: HeroPreview
var _options: Control


func _ready() -> void:
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
	var title := UIUtil.label("เลือกอาชีพของ %s" % hero_name_fixed if pick_only else "สร้างฮีโร่ของคุณ", &"HeaderLabel")
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var back := UIUtil.button("กลับ", &"GhostButton", Vector2(110, 52))
	back.name = "Back"
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
	_stage_title = UIUtil.label("", &"SubHeaderLabel", HORIZONTAL_ALIGNMENT_CENTER)
	stage_col.add_child(_stage_title)
	_stage = HeroPreview.new(Vector2i(300, 300))
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_col.add_child(_stage)
	_pivot = _stage._pivot
	var hint := UIUtil.label("ลากเพื่อหมุน · เลือกอาชีพ" if pick_only else "ลากเพื่อหมุน · เลือกอาชีพและตัวละคร", &"SmallLabel", HORIZONTAL_ALIGNMENT_CENTER)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stage_col.add_child(hint)

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
	_build_class_picker(right)
	if pick_only:
		look = FaceKit.hero_look(Game.profile.get("look", {}))
		var keep := UIUtil.label("เลเวล ค่าประสบการณ์ และไอเทมยังอยู่ครบ อาวุธนักเดินทางจะเปลี่ยนเป็นอาวุธของอาชีพที่เลือก แต้มสถานะและแต้มสกิลที่ใช้ไปได้คืนให้แจกใหม่ เลือกแล้วเปลี่ยนไม่ได้", &"SmallLabel")
		keep.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		keep.custom_minimum_size = Vector2(120, 0)
		right.add_child(keep)
		var pick := UIUtil.button("เลือกอาชีพนี้!", &"PrimaryButton", Vector2(220, 62))
		pick.name = "Confirm"
		pick.pressed.connect(_on_confirm)
		right.add_child(pick)
		root.resized.connect(_layout)
		right.resized.connect(_layout)
		_layout()
		_refresh()
		return
	var gender_row := UIUtil.hbox(8)
	right.add_child(gender_row)
	for g in 2:
		var button := UIUtil.button(FaceKit.GENDER_NAMES[g], &"ChoiceButton", Vector2(120, 54))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.name = "Gender_%d" % g
		button.pressed.connect(func(): _set_gender(g))
		gender_row.add_child(button)
		_gender_buttons.append(button)
	right.add_child(UIUtil.label("ตัวละคร", &"BoldLabel"))
	# The gender's four characters as portrait cards (a baked picture, so no model
	# loads until one is picked); the row wraps on a narrow phone.
	var cards := HFlowContainer.new()
	cards.name = "Bodies"
	cards.add_theme_constant_override("h_separation", 8)
	cards.add_theme_constant_override("v_separation", 8)
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(cards)
	for i in ChibiBodies.count(0):
		var card := UIUtil.button("", &"ChoiceButton", Vector2(118, 150))
		card.name = "Body_%d" % i
		card.toggle_mode = true
		card.pressed.connect(func(): set_body(i))
		cards.add_child(card)
		var col := UIUtil.vbox(2)
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(col)
		var pic := TextureRect.new()
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.size_flags_vertical = Control.SIZE_EXPAND_FILL
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(pic)
		var name_label := UIUtil.label("", &"SmallLabel", HORIZONTAL_ALIGNMENT_CENTER)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(name_label)
		_body_cards.append(card)
		_body_pics.append(pic)
		_body_names.append(name_label)
	right.add_child(UIUtil.label("ชื่อฮีโร่", &"BoldLabel"))
	_name_input = LineEdit.new()
	_name_input.max_length = 14
	_name_input.placeholder_text = "ชื่อที่จะอยู่ในการผจญภัยของคุณ"
	_name_input.custom_minimum_size = Vector2(0, 58)
	_name_input.text = "ฮีโร่"
	right.add_child(_name_input)
	# The hero then stands on its circle of the character select; play starts from there.
	var go := UIUtil.button("สร้างฮีโร่!", &"PrimaryButton", Vector2(220, 62))
	go.name = "Confirm"
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
	_class_grid.columns = 2 if _options.size.x < 560.0 else 5


## The ten classes as buttons, and what the picked one is (name, role, main stat, first skills).
func _build_class_picker(parent: Control) -> void:
	parent.add_child(UIUtil.label("อาชีพ", &"BoldLabel"))
	_class_grid = GridContainer.new()
	_class_grid.columns = 2
	_class_grid.add_theme_constant_override("h_separation", 8)
	_class_grid.add_theme_constant_override("v_separation", 8)
	_class_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(_class_grid)
	for id in ClassData.IDS:
		var button := UIUtil.button(String(ClassData.get_class_data(id).name), &"ChoiceButton", Vector2(0, 50))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		button.name = "Class_%s" % id
		button.pressed.connect(func(): set_class(id))
		_class_grid.add_child(button)
		_class_buttons[id] = button
	var info := UIUtil.vbox(4)
	parent.add_child(info)
	_class_title = UIUtil.label("", &"BoldLabel")
	_class_desc = UIUtil.label("", &"SmallLabel")
	_class_role = UIUtil.label("", &"SmallLabel")
	_class_main = UIUtil.label("", &"SmallLabel")
	_class_skills = UIUtil.label("", &"SmallLabel")
	for label in [_class_title, _class_desc, _class_role, _class_main, _class_skills]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.custom_minimum_size = Vector2(120, 0)
		info.add_child(label)


func set_class(id: StringName) -> void:
	if not ClassData.IDS.has(id):
		return
	picked = id
	_refresh()


## What the class plays like, in a few lines (the create screen and the old-save pick).
static func class_lines(id: StringName) -> Dictionary:
	var data := ClassData.get_class_data(id)
	var skills: PackedStringArray = []
	for skill in ClassData.kit(id, 1, 1):
		if skills.size() >= 3 or skill.has("star"):
			break
		skills.append("%s (Lv.%d)" % [skill.name, int(skill.level)])
	var role := ClassRoles.line(id)
	return {
		"title": "%s — %s" % [data.name, data.title],
		"desc": String(data.desc),
		"role": "บทบาทในปาร์ตี้: " + (role if role != "" else "-"),
		"main": "ค่าหลัก: %s" % MAIN_NAMES.get(String(data.main), String(data.main).to_upper()),
		"skills": "สกิลแรก: " + ", ".join(skills),
	}


func _set_gender(g: int) -> void:
	if int(look.gender) == g:
		return
	look["gender"] = g
	_refresh()


## Picks character [param i] of the gender (ChibiBodies).
func set_body(i: int) -> void:
	look["body"] = i
	_refresh()


func _refresh() -> void:
	look = FaceKit.hero_look(look)
	for id in _class_buttons:
		(_class_buttons[id] as Button).disabled = id == picked
	var lines := class_lines(picked)
	_class_title.text = lines.title
	_class_desc.text = lines.desc
	_class_role.text = lines.role
	_class_main.text = lines.main
	_class_skills.text = lines.skills
	_stage_title.text = String(ClassData.get_class_data(picked).name)
	for g in _gender_buttons.size():
		_gender_buttons[g].disabled = int(look.gender) == g
	for i in _body_cards.size():
		var on := int(look.body) == i
		_body_cards[i].set_pressed_no_signal(on)
		_body_cards[i].disabled = on
		# The picked card: a gold frame (a disabled button alone reads as unavailable).
		if on:
			_body_cards[i].add_theme_stylebox_override("disabled", _picked_card_box())
		else:
			_body_cards[i].remove_theme_stylebox_override("disabled")
		_body_names[i].add_theme_color_override("font_color", Color("ffd257") if on else UIPalette.TEXT)
		_body_names[i].text = ChibiBodies.body_name(int(look.gender), i)
		_body_pics[i].texture = ChibiBodies.card(int(look.gender), i)
	_stage.show_hero(picked, {}, "", look)
	_preview = _stage.visual


static func _picked_card_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("2f4392")
	box.border_color = Color("ffd257")
	box.set_border_width_all(3)
	box.set_corner_radius_all(14)
	return box


## Drag the preview with a finger (or mouse) to turn the hero.
func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		_pivot.rotation.y += event.relative.x * 0.012
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		_spin_dragging = event.pressed
	elif event is InputEventMouseMotion and _spin_dragging and event.device != InputEvent.DEVICE_ID_EMULATION:
		_pivot.rotation.y += event.relative.x * 0.012


func _on_confirm() -> void:
	if pick_only:
		confirmed.emit(picked, hero_name_fixed, look)
		return
	var hero_name := _name_input.text.strip_edges()
	if hero_name == "":
		hero_name = "ฮีโร่"
	confirmed.emit(picked, hero_name, FaceKit.hero_look(look))
