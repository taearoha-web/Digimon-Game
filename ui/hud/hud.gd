class_name HUD
extends CanvasLayer
## Always-on screen UI (landscape, touch first):
##   left            joystick
##   bottom right    big Attack button, the four class skills on an arc around
##                   it, potion / target / talk buttons
##   top left        hero panel (HP, MP, EXP) and the locked-on monster
##   top right       gold, zone name, menu
## All state is read from [Game] and the hero every frame.

signal menu_requested(tab: StringName)
signal interact_pressed()

const ARC_RADIUS := 158.0
const ARC_ANGLES := [172.0, 142.0, 112.0, 82.0]
const ATTACK_RADIUS := 62.0

var hero: Hero
var zone: Zone
var joystick: VirtualJoystick
var camera_area: TouchCameraArea
var attack_button: TouchButton
var skill_slots: Array[SkillSlot] = []
var hp_potion: TouchButton
var mp_potion: TouchButton
var target_button: TouchButton
var interact_button: TouchButton

var _root: Control
var _frame: Control
var _controls: Array[Control] = []
var _name_label: Label
var _level_label: Label
var _hp_bar: ProgressBar
var _hp_label: Label
var _mp_bar: ProgressBar
var _mp_label: Label
var _exp_bar: ProgressBar
var _badge: Label
var _badge_panel: PanelContainer
var _target_panel: PanelContainer
var _target_name: Label
var _target_bar: ProgressBar
var _target_hp: Label
var _gold_label: Label
var _zone_label: Label
var _banner: Label
var _death_panel: ColorRect
var _combat_controls: Array[Control] = []
var _badge_class: StringName = &""
var _party_cards: Array[Dictionary] = []


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	camera_area = TouchCameraArea.new()
	camera_area.anchor_left = 0.32
	camera_area.anchor_right = 1.0
	camera_area.anchor_bottom = 1.0
	_root.add_child(camera_area)
	joystick = VirtualJoystick.new()
	joystick.anchor_top = 0.3
	joystick.anchor_right = 0.32
	joystick.anchor_bottom = 1.0
	_root.add_child(joystick)
	var safe := SafeAreaContainer.new()
	_root.add_child(safe)
	_frame = Control.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(_frame)
	_build_status(_frame)
	_build_top_right(_frame)
	_build_action_buttons(_frame)
	_build_banner(_frame)
	_build_death_overlay()
	_controls = [joystick, camera_area, attack_button, hp_potion, mp_potion, target_button, interact_button]
	_controls.append_array(skill_slots)
	_combat_controls = [attack_button, hp_potion, mp_potion, target_button]
	_combat_controls.append_array(skill_slots)
	Game.gold_changed.connect(func(_g): _refresh_gold())
	Game.toast.connect(func(text: String, _k: StringName): pass)
	_refresh_gold()


func bind(p_zone: Zone) -> void:
	zone = p_zone
	hero = zone.hero
	joystick.input_changed.connect(func(v: Vector2): hero.move_input = v)
	camera_area.drag.connect(zone.camera_rig.rotate_by_pixels)
	camera_area.pinch.connect(zone.camera_rig.zoom)
	hero.message.connect(func(text: String): Game.say(text, &"warning"))
	zone.interact_changed.connect(_on_interact_changed)
	hero.target_changed.connect(func(_t): _refresh_target())
	var town := zone.is_town
	for control in _combat_controls:
		control.visible = not town
	for slot in skill_slots:
		slot.visible = not town
	_zone_label.text = String(zone.data.name)
	show_banner(String(zone.data.name))
	_target_panel.visible = false
	_death_panel.visible = false
	_on_interact_changed("")


func set_controls_visible(value: bool) -> void:
	for c in _controls:
		if c == interact_button:
			continue
		var in_town := zone != null and zone.is_town
		c.visible = value and not (in_town and c in _combat_controls)
	if not value:
		joystick.output = Vector2.ZERO
		if hero:
			hero.move_input = Vector2.ZERO


func show_banner(text: String) -> void:
	_banner.text = text
	_banner.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_banner, "modulate:a", 1.0, 0.4)
	tween.tween_interval(1.6)
	tween.tween_property(_banner, "modulate:a", 0.0, 0.6)


func show_death(visible_flag: bool) -> void:
	_death_panel.visible = visible_flag
	if visible_flag:
		_death_panel.modulate.a = 0.0
		create_tween().tween_property(_death_panel, "modulate:a", 1.0, 0.6)


func _process(_delta: float) -> void:
	if hero == null or not is_instance_valid(hero) or Game.profile.is_empty():
		return
	var p := Game.profile
	var stats := hero.stats
	var class_id := StringName("%s|%s" % [Game.class_id(), Game.job_id()])
	if class_id != _badge_class:
		_badge_class = class_id
		var data := Game.class_data()
		var style := StyleBoxFlat.new()
		style.bg_color = data.color
		style.set_corner_radius_all(30)
		style.set_border_width_all(3)
		style.border_color = Color.WHITE
		_badge_panel.add_theme_stylebox_override("panel", style)
		_badge.text = String(data.badge)
	_name_label.text = String(p.name)
	_update_party()
	_level_label.text = "Lv.%d" % int(p.level)
	UIUtil.set_bar(_hp_bar, p.hp, stats.max_hp)
	UIUtil.tint_hp_bar(_hp_bar, float(p.hp) / float(maxi(1, stats.max_hp)))
	_hp_label.text = "%d/%d" % [p.hp, stats.max_hp]
	UIUtil.set_bar(_mp_bar, p.mp, stats.max_mp)
	_mp_label.text = "%d/%d" % [p.mp, stats.max_mp]
	_exp_bar.max_value = 1000.0
	_exp_bar.value = Game.exp_ratio() * 1000.0
	if not zone.is_town:
		_update_skills()
		_update_potions()
		attack_button.set_toggled(hero.engaged)
	_update_target_frame()


func _update_skills() -> void:
	var skills: Array = Game.class_data().skills
	for i in skill_slots.size():
		var skill: Dictionary = skills[i]
		var slot := skill_slots[i]
		slot.cost = hero.mp_cost(skill)
		slot.apply(skill, hero.cooldown_ratio(skill), float(hero.cooldowns.get(skill.id, 0.0)), int(Game.profile.mp) >= hero.mp_cost(skill),
				Game.skill_unlocked(skill), Game.effective_rank(skill), false)


func _update_potions() -> void:
	hp_potion.set_label("×%d" % Game.total_potions("hp"))
	mp_potion.set_label("×%d" % Game.total_potions("mp"))


func _refresh_target() -> void:
	var mob := hero.target if hero else null
	_target_panel.visible = mob != null and is_instance_valid(mob) and not mob.is_dead()
	if _target_panel.visible:
		_target_name.text = "Lv.%d %s" % [mob.level, mob.template.name]
		_target_name.add_theme_color_override("font_color", Color("ffd84a") if mob.is_boss else Color.WHITE)


func _update_target_frame() -> void:
	var mob := hero.target
	if mob == null or not is_instance_valid(mob) or mob.is_dead():
		_target_panel.visible = false
		return
	if not _target_panel.visible:
		_refresh_target()
	UIUtil.set_bar(_target_bar, mob.hp, mob.max_hp)
	UIUtil.tint_hp_bar(_target_bar, float(mob.hp) / float(mob.max_hp))
	_target_hp.text = "%d/%d" % [mob.hp, mob.max_hp]


func _refresh_gold() -> void:
	if _gold_label and not Game.profile.is_empty():
		_gold_label.text = "%d" % int(Game.profile.gold)


func _on_interact_changed(label: String) -> void:
	interact_button.visible = label != ""
	if label != "":
		interact_button.set_label(label)


# ---------------------------------------------------------------------------
# Building
# ---------------------------------------------------------------------------

func _build_status(frame: Control) -> void:
	var column := UIUtil.vbox(8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(column)
	var panel := UIUtil.panel(&"HudPanel")
	panel.custom_minimum_size = Vector2(350, 0)
	panel.gui_input.connect(_tap(func(): menu_requested.emit(&"character")))
	column.add_child(panel)
	var row := UIUtil.hbox(12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	_badge_panel = PanelContainer.new()
	_badge_panel.custom_minimum_size = Vector2(60, 60)
	_badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_badge_panel)
	_badge = UIUtil.label("", &"HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge.add_theme_font_size_override("font_size", 28)
	_badge_panel.add_child(_badge)
	var info := UIUtil.vbox(3)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var name_row := UIUtil.hbox(8)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(name_row)
	_name_label = UIUtil.label("", &"HudLabel")
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_name_label)
	_level_label = UIUtil.label("", &"ValueLabel")
	_level_label.add_theme_color_override("font_color", UIPalette.GOLD)
	name_row.add_child(_level_label)
	var hp_row := UIUtil.hbox(6)
	hp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(hp_row)
	_hp_bar = _bar(&"HPBar", 16)
	hp_row.add_child(_hp_bar)
	_hp_label = UIUtil.label("", &"SmallLabel")
	_hp_label.custom_minimum_size = Vector2(86, 0)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_row.add_child(_hp_label)
	var mp_row := UIUtil.hbox(6)
	mp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(mp_row)
	_mp_bar = _bar(&"SPBar", 12)
	mp_row.add_child(_mp_bar)
	_mp_label = UIUtil.label("", &"SmallLabel")
	_mp_label.custom_minimum_size = Vector2(86, 0)
	_mp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mp_row.add_child(_mp_label)
	_exp_bar = _bar(&"EXPBar", 8)
	info.add_child(_exp_bar)

	_target_panel = UIUtil.panel(&"HudPanel")
	_target_panel.custom_minimum_size = Vector2(350, 0)
	_target_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target_panel.visible = false
	column.add_child(_target_panel)
	var tcol := UIUtil.vbox(3)
	tcol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target_panel.add_child(tcol)
	_target_name = UIUtil.label("", &"HudLabel", HORIZONTAL_ALIGNMENT_CENTER)
	tcol.add_child(_target_name)
	var trow := UIUtil.hbox(6)
	trow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tcol.add_child(trow)
	_target_bar = _bar(&"HPBar", 14)
	trow.add_child(_target_bar)
	_target_hp = UIUtil.label("", &"SmallLabel")
	_target_hp.custom_minimum_size = Vector2(110, 0)
	_target_hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	trow.add_child(_target_hp)
	_build_party(column)

## Small cards for the two AI companions: badge, name, level, EXP.
func _build_party(column: Control) -> void:
	for i in 2:
		var card := UIUtil.panel(&"HudPanel")
		card.custom_minimum_size = Vector2(230, 0)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(card)
		var row := UIUtil.hbox(8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(row)
		var badge := PanelContainer.new()
		badge.custom_minimum_size = Vector2(34, 34)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(badge)
		var letter := UIUtil.label("", &"HudLabel", HORIZONTAL_ALIGNMENT_CENTER)
		letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_child(letter)
		var info := UIUtil.vbox(2)
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var title := UIUtil.label("", &"SmallLabel")
		info.add_child(title)
		var bar := _bar(&"HPBar", 8)
		info.add_child(bar)
		_party_cards.append({"card": card, "badge": badge, "letter": letter, "title": title, "bar": bar, "key": ""})


func _update_party() -> void:
	var party := Game.party()
	for i in _party_cards.size():
		var entry: Dictionary = _party_cards[i]
		var card: Control = entry.card
		card.visible = i < party.size() and (zone != null)
		if not card.visible:
			continue
		var member: Dictionary = party[i]
		var data := ClassData.get_class_data(StringName(member["class"]))
		var key := "%s|%d" % [member.name, int(member.level)]
		if key != entry.key:
			entry["key"] = key
			var style := StyleBoxFlat.new()
			style.bg_color = data.color
			style.set_corner_radius_all(17)
			style.set_border_width_all(2)
			style.border_color = Color.WHITE
			(entry.badge as PanelContainer).add_theme_stylebox_override("panel", style)
			(entry.letter as Label).text = String(data.badge)
			(entry.title as Label).text = "%s  Lv.%d" % [member.name, int(member.level)]
		var bar := entry.bar as ProgressBar
		bar.max_value = float(HeroStats.exp_to_next(int(member.level)))
		bar.value = float(member.exp)


func _build_top_right(frame: Control) -> void:
	var row := UIUtil.hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.anchor_left = 1.0
	row.anchor_right = 1.0
	row.offset_left = -330
	row.offset_right = 0
	row.alignment = BoxContainer.ALIGNMENT_END
	frame.add_child(row)
	var money := UIUtil.panel(&"HudPanel")
	money.mouse_filter = Control.MOUSE_FILTER_IGNORE
	money.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var money_row := UIUtil.hbox(6)
	money_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	money.add_child(money_row)
	money_row.add_child(UIUtil.texture_rect(load("res://assets/icons/ui/coin.svg"), Vector2(26, 26)))
	_gold_label = UIUtil.label("0", &"HudLabel")
	money_row.add_child(_gold_label)
	row.add_child(money)
	var menu := UIUtil.icon_button("res://assets/icons/ui/menu.svg", Vector2(76, 76))
	menu.pressed.connect(func(): menu_requested.emit(&"inventory"))
	row.add_child(menu)
	_zone_label = UIUtil.label("", &"SmallLabel", HORIZONTAL_ALIGNMENT_RIGHT)
	_zone_label.anchor_left = 1.0
	_zone_label.anchor_right = 1.0
	_zone_label.offset_left = -330
	_zone_label.offset_top = 84
	_zone_label.offset_right = -4
	frame.add_child(_zone_label)


func _build_action_buttons(frame: Control) -> void:
	# Everything is positioned from the bottom-right corner.
	attack_button = TouchButton.new()
	attack_button.radius = ATTACK_RADIUS
	attack_button.icon = load("res://assets/icons/ui/fight.svg")
	attack_button.accent = UIPalette.ORANGE
	attack_button.toggle_mode = false
	_place_corner(attack_button, Vector2(-30, -30), ATTACK_RADIUS)
	attack_button.pressed.connect(func(): if hero: hero.tap_attack())
	frame.add_child(attack_button)

	var center := Vector2(-30 - ATTACK_RADIUS, -30 - ATTACK_RADIUS)
	for i in 4:
		var slot := SkillSlot.new()
		var angle := deg_to_rad(float(ARC_ANGLES[i]))
		var offset := Vector2(cos(angle), -sin(angle)) * ARC_RADIUS
		_place_corner(slot, center + offset + Vector2(slot.radius, slot.radius), slot.radius)
		slot.pressed.connect(func(): if hero: hero.use_skill(i))
		frame.add_child(slot)
		skill_slots.append(slot)

	hp_potion = _small_button("res://assets/icons/ui/heart_potion.svg", Color("ff5a6e"), center + Vector2(-108, 46))
	hp_potion.pressed.connect(func(): if hero: hero.use_potion("hp"))
	frame.add_child(hp_potion)
	mp_potion = _small_button("res://assets/icons/ui/mana_potion.svg", Color("5a9bff"), center + Vector2(-176, 40))
	mp_potion.pressed.connect(func(): if hero: hero.use_potion("mp"))
	frame.add_child(mp_potion)
	target_button = _small_button("res://assets/icons/ui/target.svg", UIPalette.DANGER, center + Vector2(-244, 26))
	target_button.pressed.connect(func(): if hero: hero.cycle_target())
	frame.add_child(target_button)

	interact_button = TouchButton.new()
	interact_button.radius = 52.0
	interact_button.icon = load("res://assets/icons/ui/interact.svg")
	interact_button.accent = UIPalette.ORANGE
	interact_button.text = "คุย"
	_place_corner(interact_button, Vector2(-30, -30), 52.0)
	interact_button.pressed.connect(func(): interact_pressed.emit())
	frame.add_child(interact_button)


func _place_corner(control: Control, offset_from_corner: Vector2, r: float) -> void:
	control.anchor_left = 1.0
	control.anchor_right = 1.0
	control.anchor_top = 1.0
	control.anchor_bottom = 1.0
	control.offset_left = offset_from_corner.x - r * 2.0
	control.offset_right = offset_from_corner.x
	control.offset_top = offset_from_corner.y - r * 2.0
	control.offset_bottom = offset_from_corner.y


## Small round button centred [param center_rel] from the bottom-right corner.
func _small_button(icon_path: String, accent: Color, center_rel: Vector2) -> TouchButton:
	var b := TouchButton.new()
	b.radius = 28.0
	if ResourceLoader.exists(icon_path):
		b.icon = load(icon_path)
	b.accent = accent
	_place_corner(b, center_rel + Vector2(28, 28), 28.0)
	return b


func _build_banner(frame: Control) -> void:
	_banner = UIUtil.label("", &"TitleLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_banner.add_theme_font_size_override("font_size", 46)
	_banner.anchor_left = 0.2
	_banner.anchor_right = 0.8
	_banner.anchor_top = 0.2
	_banner.anchor_bottom = 0.2
	_banner.offset_bottom = 70
	_banner.modulate.a = 0.0
	frame.add_child(_banner)


func _build_death_overlay() -> void:
	_death_panel = ColorRect.new()
	_death_panel.color = Color(0.25, 0.0, 0.02, 0.62)
	_death_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_death_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death_panel.visible = false
	_root.add_child(_death_panel)
	var label := UIUtil.label("คุณพ่ายแพ้…", &"TitleLabel", HORIZONTAL_ALIGNMENT_CENTER)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.offset_left = -300
	label.offset_right = 300
	label.offset_top = -50
	_death_panel.add_child(label)
	var sub := UIUtil.label("กำลังกลับหมู่บ้านเพื่อพักฟื้น", &"HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER)
	sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	sub.offset_left = -300
	sub.offset_right = 300
	sub.offset_top = 30
	_death_panel.add_child(sub)


func _bar(variation: StringName, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.theme_type_variation = variation
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, height)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


func _tap(callback: Callable) -> Callable:
	return func(event: InputEvent):
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
				or (event is InputEventScreenTouch and event.pressed):
			AudioManager.play_ui(&"ui_click")
			callback.call()


func _unhandled_input(event: InputEvent) -> void:
	if hero == null or not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_SPACE, KEY_F:
			if interact_button.visible:
				interact_pressed.emit()
			else:
				hero.tap_attack()
		KEY_1, KEY_2, KEY_3, KEY_4:
			hero.use_skill(event.physical_keycode - KEY_1)
		KEY_H:
			hero.use_potion("hp")
		KEY_M:
			hero.use_potion("mp")
		KEY_TAB, KEY_R:
			hero.cycle_target()
		KEY_I:
			menu_requested.emit(&"inventory")
		KEY_K:
			menu_requested.emit(&"skills")
		KEY_C:
			menu_requested.emit(&"character")
		KEY_J:
			menu_requested.emit(&"quests")
