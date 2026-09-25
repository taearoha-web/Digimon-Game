class_name HUD
extends CanvasLayer
## Exploration HUD (landscape, touch first):
##   left  : virtual joystick
##   right : camera drag area, Interact button, Sprint toggle
##   top   : partner status, quest tracker + compass, menu button, currency
## Kept deliberately uncluttered; panels update on events or slow timers.

signal menu_requested(tab: StringName)
signal interact_pressed()
signal sprint_toggled(on: bool)

var joystick: VirtualJoystick
var camera_area: TouchCameraArea
var interact_button: TouchButton
var sprint_button: TouchButton

var player: PlayerController
var camera_rig: ThirdPersonCamera
var waypoint_resolver: Callable

var _root: Control
var _partner_name: Label
var _partner_level: Label
var _partner_badge: Label
var _partner_badge_panel: PanelContainer
var _hp_bar: ProgressBar
var _hp_label: Label
var _sp_bar: ProgressBar
var _quest_panel: PanelContainer
var _quest_title: Label
var _quest_objective: Label
var _compass: TextureRect
var _compass_distance: Label
var _compass_box: Control
var _banner: Label
var _default_interact_icon: Texture2D
var _currency: Label
var _fps: Label
var _refresh_timer := 0.0
var _controls: Array[Control] = []
var _badge_species: StringName = &""


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
	var frame := Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(frame)

	_build_top_left(frame)
	_build_top_right(frame)
	_build_buttons(frame)
	_build_compass(frame)
	_build_banner(frame)

	_controls = [joystick, camera_area, interact_button, sprint_button]
	EventBus.party_changed.connect(refresh_partner)
	EventBus.area_entered.connect(_on_area_entered)
	QuestManager.tracked_quest_changed.connect(refresh_quest)
	EventBus.quest_updated.connect(func(_id): refresh_quest())
	GameState.profile.currency_changed.connect(func(_c): _refresh_currency())
	Settings.changed.connect(func(): _fps.visible = Settings.show_fps)
	refresh_partner()
	refresh_quest()
	_refresh_currency()
	set_interact_target(null)


func bind(p_player: PlayerController, p_camera: ThirdPersonCamera, p_waypoint_resolver: Callable) -> void:
	player = p_player
	camera_rig = p_camera
	waypoint_resolver = p_waypoint_resolver


## Hides touch controls (e.g. during dialogue) without hiding status panels.
func set_controls_visible(value: bool) -> void:
	for c in _controls:
		c.visible = value
	if not value:
		joystick.output = Vector2.ZERO


func set_interact_target(target: Interactable) -> void:
	if target:
		interact_button.set_label(target.get_prompt())
		interact_button.icon = target.prompt_icon if target.prompt_icon else _default_interact_icon
		interact_button.accent = target.prompt_accent if target.prompt_accent.a > 0.0 else UIPalette.ORANGE
		interact_button.queue_redraw()
		if not interact_button.visible:
			interact_button.visible = true
			interact_button.pivot_offset = interact_button.size * 0.5
			interact_button.scale = Vector2(0.6, 0.6)
			create_tween().tween_property(interact_button, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)
	else:
		interact_button.visible = false


func show_banner(text: String) -> void:
	if text == "":
		return
	_banner.text = text
	_banner.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_banner, "modulate:a", 1.0, 0.4)
	tween.tween_interval(1.8)
	tween.tween_property(_banner, "modulate:a", 0.0, 0.6)


func _process(delta: float) -> void:
	_update_compass()
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.5
		refresh_partner()
		if _fps.visible:
			_fps.text = "%d FPS" % Engine.get_frames_per_second()


func refresh_partner() -> void:
	var lead := GameState.roster.get_lead()
	if lead == null or _partner_name == null:
		return
	var species := lead.get_species()
	_partner_name.text = lead.get_display_name()
	_partner_level.text = L10n.t("Lv %d") % lead.level
	_partner_badge.text = lead.get_display_name().substr(0, 1)
	if lead.species_id != _badge_species:
		_badge_species = lead.species_id
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = species.get_color(0, UIPalette.CYAN) if species else UIPalette.CYAN
		badge_style.set_corner_radius_all(28)
		badge_style.set_border_width_all(3)
		badge_style.border_color = Color.WHITE
		_partner_badge_panel.add_theme_stylebox_override("panel", badge_style)
	UIUtil.set_bar(_hp_bar, lead.current_hp, lead.get_max_hp())
	UIUtil.tint_hp_bar(_hp_bar, lead.get_hp_ratio())
	_hp_label.text = "%d/%d" % [lead.current_hp, lead.get_max_hp()]
	UIUtil.set_bar(_sp_bar, lead.current_sp, lead.get_max_sp())


func refresh_quest() -> void:
	if _quest_title == null:
		return
	var quest := QuestManager.get_tracked_quest()
	_quest_panel.visible = quest != null
	if quest == null:
		return
	var state := QuestManager.get_state(quest.id)
	_quest_title.text = ("★ " if state == QuestLog.State.COMPLETED else "") + quest.title
	_quest_objective.text = QuestManager.get_objective_text(quest.id)


func _refresh_currency() -> void:
	_currency.text = "%d" % GameState.profile.currency


func _update_compass() -> void:
	if camera_rig == null or player == null or not waypoint_resolver.is_valid():
		_compass_box.visible = false
		return
	var quest := QuestManager.get_tracked_quest()
	var waypoint_id := QuestManager.get_objective_waypoint(quest.id) if quest else &""
	var target = waypoint_resolver.call(waypoint_id) if waypoint_id != &"" else null
	if target == null:
		_compass_box.visible = false
		return
	var to_target: Vector3 = (target as Vector3) - player.global_position
	to_target.y = 0.0
	var distance := to_target.length()
	_compass_box.visible = distance > 4.0
	var target_yaw := atan2(-to_target.x, -to_target.z)
	_compass.rotation = -(target_yaw - camera_rig.yaw)
	_compass_distance.text = "%dm" % int(distance)


func _build_top_left(frame: Control) -> void:
	var column := UIUtil.vbox(10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.position = Vector2.ZERO
	frame.add_child(column)

	var partner := UIUtil.panel(&"HudPanel")
	partner.custom_minimum_size = Vector2(340, 0)
	partner.gui_input.connect(_tap_handler(func(): menu_requested.emit(&"party")))
	column.add_child(partner)
	var row := UIUtil.hbox(12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	partner.add_child(row)
	_partner_badge_panel = PanelContainer.new()
	_partner_badge_panel.custom_minimum_size = Vector2(56, 56)
	_partner_badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_partner_badge_panel)
	_partner_badge = UIUtil.label("", &"HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_partner_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_partner_badge.add_theme_font_size_override("font_size", 28)
	_partner_badge_panel.add_child(_partner_badge)
	var info := UIUtil.vbox(3)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var name_row := UIUtil.hbox(8)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(name_row)
	_partner_name = UIUtil.label("", &"HudLabel")
	_partner_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_partner_name)
	_partner_level = UIUtil.label("", &"ValueLabel")
	_partner_level.add_theme_color_override("font_color", UIPalette.GOLD)
	name_row.add_child(_partner_level)
	var hp_row := UIUtil.hbox(6)
	hp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(hp_row)
	_hp_bar = _bar(&"HPBar", 14)
	hp_row.add_child(_hp_bar)
	_hp_label = UIUtil.label("", &"SmallLabel")
	_hp_label.custom_minimum_size = Vector2(70, 0)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_row.add_child(_hp_label)
	_sp_bar = _bar(&"SPBar", 8)
	info.add_child(_sp_bar)

	_quest_panel = UIUtil.panel(&"HudPanel")
	_quest_panel.custom_minimum_size = Vector2(340, 0)
	_quest_panel.gui_input.connect(_tap_handler(func(): menu_requested.emit(&"quests")))
	column.add_child(_quest_panel)
	var quest_box := UIUtil.vbox(2)
	quest_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quest_panel.add_child(quest_box)
	_quest_title = UIUtil.label("", &"SubHeaderLabel")
	_quest_title.add_theme_color_override("font_color", UIPalette.GOLD)
	_quest_title.add_theme_font_size_override("font_size", 21)
	quest_box.add_child(_quest_title)
	_quest_objective = UIUtil.label("", &"SmallLabel")
	_quest_objective.add_theme_color_override("font_color", UIPalette.TEXT)
	_quest_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest_objective.custom_minimum_size = Vector2(310, 0)
	quest_box.add_child(_quest_objective)


func _build_top_right(frame: Control) -> void:
	var row := UIUtil.hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.anchor_left = 1.0
	row.anchor_right = 1.0
	row.offset_left = -300
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
	_currency = UIUtil.label("0", &"HudLabel")
	money_row.add_child(_currency)
	row.add_child(money)
	var menu := UIUtil.icon_button("res://assets/icons/ui/menu.svg", Vector2(76, 76))
	menu.pressed.connect(func(): menu_requested.emit(&""))
	row.add_child(menu)
	_fps = UIUtil.label("", &"SmallLabel")
	_fps.anchor_left = 0.5
	_fps.anchor_right = 0.5
	_fps.offset_left = -60
	_fps.offset_right = 60
	_fps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fps.visible = Settings.show_fps
	frame.add_child(_fps)


func _build_buttons(frame: Control) -> void:
	interact_button = TouchButton.new()
	interact_button.radius = 70.0
	_default_interact_icon = load("res://assets/icons/ui/interact.svg")
	interact_button.icon = _default_interact_icon
	interact_button.text = "Talk"
	interact_button.accent = UIPalette.ORANGE
	interact_button.anchor_left = 1.0
	interact_button.anchor_right = 1.0
	interact_button.anchor_top = 1.0
	interact_button.anchor_bottom = 1.0
	interact_button.offset_left = -160
	interact_button.offset_top = -160
	interact_button.offset_right = -20
	interact_button.offset_bottom = -20
	interact_button.pressed.connect(func(): interact_pressed.emit())
	frame.add_child(interact_button)

	sprint_button = TouchButton.new()
	sprint_button.radius = 46.0
	sprint_button.icon = load("res://assets/icons/ui/sprint.svg")
	sprint_button.toggle_mode = true
	sprint_button.accent = UIPalette.CYAN
	sprint_button.anchor_left = 1.0
	sprint_button.anchor_right = 1.0
	sprint_button.anchor_top = 1.0
	sprint_button.anchor_bottom = 1.0
	sprint_button.offset_left = -270
	sprint_button.offset_top = -120
	sprint_button.offset_right = -178
	sprint_button.offset_bottom = -28
	sprint_button.toggled.connect(func(on: bool): sprint_toggled.emit(on))
	frame.add_child(sprint_button)


func _build_compass(frame: Control) -> void:
	_compass_box = UIUtil.vbox(0)
	_compass_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_compass_box.anchor_left = 0.5
	_compass_box.anchor_right = 0.5
	_compass_box.offset_left = -45
	_compass_box.offset_right = 45
	_compass_box.offset_top = 6
	frame.add_child(_compass_box)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(90, 56)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_compass_box.add_child(holder)
	_compass = TextureRect.new()
	_compass.texture = load("res://assets/icons/ui/compass_arrow.svg")
	_compass.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_compass.size = Vector2(48, 48)
	_compass.position = Vector2(21, 4)
	_compass.pivot_offset = Vector2(24, 24)
	_compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_compass)
	_compass_distance = UIUtil.label("", &"HudLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_compass_distance.add_theme_font_size_override("font_size", 18)
	_compass_box.add_child(_compass_distance)


func _build_banner(frame: Control) -> void:
	_banner = UIUtil.label("", &"TitleLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_banner.add_theme_font_size_override("font_size", 44)
	_banner.anchor_left = 0.2
	_banner.anchor_right = 0.8
	_banner.anchor_top = 0.2
	_banner.anchor_bottom = 0.2
	_banner.offset_bottom = 70
	_banner.modulate.a = 0.0
	frame.add_child(_banner)


func _bar(variation: StringName, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.theme_type_variation = variation
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, height)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


func _tap_handler(callback: Callable) -> Callable:
	return func(event: InputEvent):
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
				or (event is InputEventScreenTouch and event.pressed):
			AudioManager.play_ui(&"ui_click")
			callback.call()


func _on_area_entered(_area_id: StringName, display_name: String) -> void:
	show_banner(display_name)
