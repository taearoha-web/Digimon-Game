class_name HUD
extends CanvasLayer
## Always-on screen UI (landscape, touch first):
##   left            joystick
##   bottom          eight skills in one row, big Attack button at the right
##   far right       HP potion, MP potion, auto and target in a vertical column
##   top left        hero panel, self / ally buffs, companions
##   top centre      target or boss health
##   top right       gold, zone name, menu
## All state is read from [Game] and the hero every frame.

signal menu_requested(tab: StringName)
## The online count was tapped: open the game registry.
signal registry_requested()
## The chat chip: type a line to the world chat (AiChat).
signal chat_requested()
## A tap on the 3D world that did not turn the camera (Zone.player_at picks who is there).
signal world_tapped(position: Vector2)
signal interact_pressed()

## One bottom row leaves the joystick's touch circle clear on the left.
const SKILL_SPACING := 82.0
const SKILL_ROW_Y := -68.0
const ATTACK_RADIUS := 62.0
## Room the world chat leaves before the first skill slot's centre.
const SKILL_SLOT_CLEAR := 44.0
## The skill slots' radius (smaller medallions leave the world chat room).
const SKILL_RADIUS := 32.0
## The last skill slot's centre from the frame's right edge (clear of the attack button).
const SKILL_ROW_RIGHT := -194.0
## What the raven mode button announces for each mode (DarkRaven.Mode).
const RAVEN_MODE_TIPS := ["โจมตีเดี่ยว จิกเป้าหมายของเราแรงขึ้น", "โจมตีหมู่ จิกทีละกลุ่มรอบเป้าหมาย", "ออโต้ เลือกเหยื่อเองและจิกเป็นกลุ่มเมื่อศัตรูรวมตัว"]

var hero: Hero
var zone: Zone
var joystick: VirtualJoystick
var camera_area: TouchCameraArea
var attack_button: TouchButton
var skill_slots: Array[SkillSlot] = []
var hp_potion: TouchButton
var mp_potion: TouchButton
var target_button: TouchButton
var auto_button: TouchButton
## The Dark Lord's raven: attack on its own / come back to the arm.
var raven_button: TouchButton
## How the raven hunts: single (เดี่ยว), group (หมู่) or auto (ออโต้); tap to cycle.
var raven_mode_button: TouchButton
var interact_button: TouchButton

var _root: Control
var _frame: Control
var _controls: Array[Control] = []
var _name_label: Label
var _level_label: Label
var _star_row: HBoxContainer
var _hp_bar: ProgressBar
var _hp_label: Label
var _mp_bar: ProgressBar
var _mp_label: Label
var _exp_bar: ProgressBar
var _portrait: HeroPortrait
var _badge_panel: PanelContainer
var _target_panel: PanelContainer
var _boss_panel: PanelContainer
var _timers: TimerBars
var _tracker: Label
var _tracker_timer := 0.0
var _boss_name: Label
var _boss_bar: ProgressBar
var _target_name: Label
var _target_bar: ProgressBar
var _target_hp: Label
var _gold_label: Label
var _online_label: Label
var world_chat: WorldChat
var _online_in := 0.0
var _zone_label: Label
var _banner: Label
var _death_panel: ColorRect
var _death_title: Label
var _death_sub: Label
var _combat_controls: Array[Control] = []
var _badge_class: StringName = &""
var _gw_hud: GuildWarHud
var _party_cards: Array[Dictionary] = []
## "ปาร์ตี้ของคุณ" above the cards in a guild war (the cards then show the war party).
var _party_head: Label
## Wing pose chips (fly / stand / fold) under the companion card, shown while wings are worn.
var _wing_row: HBoxContainer
var _wing_chips: Array[PanelContainer] = []
var _wing_shown := -1
var minimap: Minimap


var _save_label: Label


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	camera_area = TouchCameraArea.new()
	camera_area.anchor_left = 0.0
	camera_area.anchor_right = 1.0
	camera_area.anchor_bottom = 1.0
	camera_area.tapped.connect(func(at: Vector2): world_tapped.emit(at))
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
	_build_world_chat(_frame)
	_frame.resized.connect(_layout_actions)
	_layout_actions()
	_build_death_overlay()
	_controls = [joystick, camera_area, attack_button, hp_potion, mp_potion, target_button, auto_button, interact_button]
	_controls.append_array(skill_slots)
	_combat_controls = [attack_button, hp_potion, mp_potion, target_button, auto_button]
	_combat_controls.append_array(skill_slots)
	Game.gold_changed.connect(func(_g): _refresh_gold())
	# Equipment can change while the menu pauses gameplay. The portrait's
	# one-shot capture also runs safely during that pause.
	Game.inventory_changed.connect(_refresh_portrait)
	_save_label = UIUtil.label("บันทึกอัตโนมัติ", &"SmallLabel")
	_save_label.modulate.a = 0.0
	_save_label.anchor_left = 1.0
	_save_label.anchor_right = 1.0
	_save_label.offset_left = -270.0
	_save_label.offset_right = -140.0
	_save_label.offset_top = 70.0
	_save_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_save_label)
	Game.autosaved.connect(_flash_saved)
	Game.toast.connect(func(text: String, _k: StringName): pass)
	_refresh_gold()


func _flash_saved() -> void:
	var tw := create_tween()
	tw.tween_property(_save_label, "modulate:a", 0.85, 0.2)
	tw.tween_interval(1.2)
	tw.tween_property(_save_label, "modulate:a", 0.0, 0.6)


func bind(p_zone: Zone) -> void:
	zone = p_zone
	hero = zone.hero
	# Show the new zone's status on the next frame, without carrying the old
	# hero's timer phase or a partially elapsed HUD refresh across travel.
	_refresh_in = 0.0
	_timer_elapsed = 0.0
	minimap.zone = zone
	minimap.visible = true
	# One link to the current hero (bind runs for every zone), and a thumb that is
	# still on the stick keeps steering the new hero straight away.
	if _stick_link.is_valid() and joystick.input_changed.is_connected(_stick_link):
		joystick.input_changed.disconnect(_stick_link)
	_stick_link = func(v: Vector2):
		if hero and is_instance_valid(hero):
			hero.move_input = v
	joystick.input_changed.connect(_stick_link)
	hero.move_input = joystick.output
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
	_death_title.text = "คุณพ่ายแพ้…"
	_death_sub.text = "กำลังกลับหมู่บ้านเพื่อพักฟื้น"
	_on_interact_changed("")
	if _gw_hud != null:
		_gw_hud.queue_free()
		_gw_hud = null
	if zone.gw_match != null:
		_gw_hud = GuildWarHud.new()
		_frame.add_child(_gw_hud)
		_gw_hud.bind(zone.gw_match)
		zone.gw_match.hero_down.connect(func(_s: float): show_death(true, "คุณล้มลง!", "รอเกิดใหม่ที่ฐาน"))
		zone.gw_match.hero_back.connect(func(): show_death(false))


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


func show_death(visible_flag: bool, title := "คุณพ่ายแพ้…", sub := "กำลังกลับหมู่บ้านเพื่อพักฟื้น") -> void:
	_death_title.text = title
	_death_sub.text = sub
	_death_panel.visible = visible_flag
	if visible_flag:
		_death_panel.modulate.a = 0.0
		create_tween().tween_property(_death_panel, "modulate:a", 1.0, 0.6)


var _refresh_in := 0.0
var _timer_elapsed := 0.0
var _stick_link := Callable()


func _process(delta: float) -> void:
	if hero == null or not is_instance_valid(hero) or Game.profile.is_empty():
		return
	# Status snapshots and timer chips share the 20 Hz HUD refresh. Building the
	# buff/summon dictionaries and redrawing their text every rendered frame is
	# unnecessary during combat. Accumulate real elapsed time so warning pulses
	# keep their speed when the render rate changes.
	_timer_elapsed += delta
	_online_in -= delta
	if _online_in <= 0.0:
		_online_in = 5.0
		update_online()
	_refresh_in -= delta
	if _refresh_in <= 0.000001:
		# Preserve the remainder, avoiding refresh-rate drift at 60/120 Hz. After
		# a long frame, one snapshot is enough; skip missed work rather than loop.
		_refresh_in = maxf(_refresh_in + 0.05, 0.0)
		_refresh()
		_update_timers(_timer_elapsed)
		_timer_elapsed = 0.0
	_update_tracker(delta)


func _refresh() -> void:
	var p := Game.profile
	var stats := hero.stats
	var class_id := StringName("%s|%d" % [Game.class_id(), Game.adv()])
	if class_id != _badge_class:
		_badge_class = class_id
		var data := Game.class_data()
		var style := StyleBoxFlat.new()
		style.bg_color = (data.color as Color).darkened(0.65)
		style.set_corner_radius_all(36)
		style.set_border_width_all(2)
		style.border_color = (data.color as Color).lerp(Color.WHITE, 0.65)
		style.content_margin_left = 4
		style.content_margin_top = 4
		style.content_margin_right = 4
		style.content_margin_bottom = 4
		_badge_panel.add_theme_stylebox_override("panel", style)
	# The portrait captures the actual head gear when its appearance changes,
	# then displays the cached image without an ongoing 3D render.
	_refresh_portrait()
	_name_label.text = String(p.name)
	_update_party()
	_update_wing_row()
	_level_label.text = "Lv.%d" % int(p.level)
	var stars := int(Game.paragon().level)
	_star_row.visible = stars > 0
	(_star_row.get_node("StarValue") as Label).text = str(stars)
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
		auto_button.set_toggled(hero.auto)
	raven_button.visible = hero.raven != null and not zone.is_town and auto_button.visible
	raven_mode_button.visible = raven_button.visible
	if raven_button.visible:
		raven_button.set_toggled(hero.raven.attack)
		raven_mode_button.text = DarkRaven.MODE_NAMES[hero.raven.mode]
	_update_target_frame()
	_update_boss_bar()


func _update_skills() -> void:
	var skills: Array = Game.class_data().skills
	for i in skill_slots.size():
		var skill: Dictionary = skills[i]
		var slot := skill_slots[i]
		if skill.is_empty():
			slot.apply({}, 0.0, 0.0, false, false, 0, false)
			continue
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


## Buff / summon countdown rows below the hero status card.
func _update_timers(delta: float) -> void:
	if hero == null or not is_instance_valid(hero) or zone == null or zone.is_town:
		_timers.update_entries([], delta)
		return
	_timers.update_entries(hero.timer_status(), delta)


## Wide bar at the top while a boss that noticed the hero is alive nearby.
func _update_boss_bar() -> void:
	var boss: Mob = null
	if hero and not zone.is_town and zone.gw_match == null:
		for node in get_tree().get_nodes_in_group("mobs"):
			var mob := node as Mob
			if mob and mob.is_boss and mob.hostile and not mob.is_dead() \
					and (zone.is_pvp or mob.global_position.distance_to(hero.global_position) < 40.0):
				boss = mob
				break
	_boss_panel.visible = boss != null
	if boss != null and hero.target == boss:
		_target_panel.hide()
	elif boss != null:
		_target_panel.offset_top = 92.0
	else:
		_target_panel.offset_top = 8.0
	if boss == null:
		return
	var phase_text: String = ["", "  (เรียกพวก)", "  (คลั่ง!)"][clampi(boss.phase, 0, 2)]
	_boss_name.text = "Lv.%d %s%s" % [boss.level, boss.template.name, phase_text]
	if zone.is_pvp and zone.pvp_match != null:
		var left := int(ceil(maxf(zone.pvp_match.time_left, 0.0)))
		_boss_name.text = "%s   เวลา %d:%02d" % [_boss_name.text, left / 60, left % 60]
	UIUtil.set_bar(_boss_bar, boss.hp, boss.max_hp)
	UIUtil.tint_hp_bar(_boss_bar, float(boss.hp) / float(boss.max_hp))


## Two lines under the minimap: the story quest and the daily board.
func _update_tracker(delta: float) -> void:
	_tracker_timer -= delta
	if _tracker_timer > 0.0:
		return
	_tracker_timer = 0.5
	if Game.profile.is_empty() or zone.is_town:
		_tracker.visible = false
		return
	_tracker.visible = true
	var lines: PackedStringArray = []
	var quest_id := QuestData.current_quest()
	if quest_id != "" and Game.quest_status(quest_id) in ["active", "ready"]:
		var quest := QuestData.get_quest(quest_id)
		var have := int(Game.quest_state(quest_id).get("progress", 0))
		lines.append("เควสต์: %s %d/%d" % [quest.name, have, int(quest.count)] if have < int(quest.count) else "เควสต์: %s เสร็จแล้ว กลับไปรายงาน" % quest.name)
	var done := 0
	for entry in Game.daily().quests:
		if int(entry.progress) >= Game.daily_target(entry):
			done += 1
	lines.append("รายวัน: เสร็จ %d/3" % done)
	_tracker.text = "\n".join(lines)


func _build_tracker(frame: Control) -> void:
	_tracker = UIUtil.label("", &"SmallLabel", HORIZONTAL_ALIGNMENT_RIGHT)
	_tracker.anchor_left = 1.0
	_tracker.anchor_right = 1.0
	_tracker.offset_left = -480
	_tracker.offset_right = -130
	_tracker.offset_top = 252
	_tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tracker.add_theme_constant_override("outline_size", 6)
	_tracker.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	frame.add_child(_tracker)


func _build_boss_bar(frame: Control) -> void:
	_build_tracker(frame)
	_boss_panel = UIUtil.panel(&"HudPanel")
	_boss_panel.anchor_left = 0.33
	_boss_panel.anchor_right = 0.7
	_boss_panel.offset_top = 8
	_boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_panel.visible = false
	frame.add_child(_boss_panel)
	var col := UIUtil.vbox(3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_panel.add_child(col)
	_boss_name = UIUtil.label("", &"HudLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_boss_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_boss_name.clip_text = true
	_boss_name.add_theme_color_override("font_color", Color("ffd84a"))
	col.add_child(_boss_name)
	_boss_bar = _bar(&"HPBar", 16)
	col.add_child(_boss_bar)


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


func _refresh_portrait() -> void:
	if _portrait != null and not Game.profile.is_empty():
		_portrait.refresh_profile(Game.profile)


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
	_badge_panel.custom_minimum_size = Vector2(84, 84)
	_badge_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_badge_panel)
	_portrait = HeroPortrait.new()
	_portrait.name = "HeroPortrait"
	_portrait.custom_minimum_size = Vector2(76, 76)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_panel.add_child(_portrait)
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
	# "Lv.100 [star] 5" is one unit on one line: level, star icon and star count.
	var level_row := UIUtil.hbox(6)
	level_row.alignment = BoxContainer.ALIGNMENT_END
	level_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(level_row)
	_level_label = UIUtil.label("", &"ValueLabel")
	_level_label.add_theme_color_override("font_color", UIPalette.GOLD)
	_level_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_level_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	level_row.add_child(_level_label)
	_star_row = UIUtil.star_count(0, 22, &"ValueLabel")
	_star_row.visible = false
	level_row.add_child(_star_row)
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
	_target_panel.anchor_left = 0.33
	_target_panel.anchor_right = 0.70
	_target_panel.offset_top = 8
	frame.add_child(_target_panel)
	var tcol := UIUtil.vbox(3)
	tcol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target_panel.add_child(tcol)
	_target_name = UIUtil.label("", &"HudLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_target_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_target_name.clip_text = true
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
	_timers = TimerBars.new()
	column.add_child(_timers)
	_build_party(column)
	_build_wing_row(column)
	minimap = Minimap.new()
	minimap.anchor_left = 1.0
	minimap.anchor_right = 1.0
	minimap.offset_left = -150
	minimap.offset_right = -10
	minimap.offset_top = 102
	minimap.offset_bottom = 242
	frame.add_child(minimap)

## The world chat (WorldChat): along the bottom edge just right of the joystick's resting
## place, clear of the skill row; it never takes a tap.
func _build_world_chat(frame: Control) -> void:
	world_chat = WorldChat.new()
	world_chat.anchor_top = 1.0
	world_chat.anchor_bottom = 1.0
	world_chat.offset_left = 250.0
	world_chat.offset_right = 650.0
	world_chat.offset_top = -12.0
	world_chat.offset_bottom = -12.0
	world_chat.grow_vertical = Control.GROW_DIRECTION_BEGIN
	frame.add_child(world_chat)


## "ออนไลน์ N": the world players online now plus the hero.
func update_online() -> void:
	if _online_label:
		_online_label.text = "ออนไลน์ %d" % (WorldPresence.online_count() + 1)


## Small cards for the party (world players who joined): badge, name, level, progress.
## A tap switches that member between follow, aggressive and guard; the cross lets it go.
func _build_party(column: Control) -> void:
	_party_head = UIUtil.label("", &"SmallLabel")
	_party_head.name = "WarPartyHead"
	_party_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_party_head.add_theme_font_size_override("font_size", 15)
	_party_head.add_theme_color_override("font_color", GuildWarMatch.PARTY_COLOR)
	_party_head.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_party_head.add_theme_constant_override("outline_size", 5)
	_party_head.visible = false
	column.add_child(_party_head)
	for i in Game.PARTY_MAX:
		var card := UIUtil.panel(&"HudPanel")
		# Compact: four of these stand above the joystick on a phone.
		card.custom_minimum_size = Vector2(250, 0)
		card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var compact := card.get_theme_stylebox("panel")
		if compact != null:
			compact = compact.duplicate()
			compact.content_margin_left = 6
			compact.content_margin_right = 6
			compact.content_margin_top = 3
			compact.content_margin_bottom = 3
			card.add_theme_stylebox_override("panel", compact)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(_tap(func():
			if _war() != null:
				return
			var stance := Game.cycle_stance(i)
			if stance != "":
				Game.say("%s: %s" % [Game.party()[i].name, Game.STANCE_NAMES[stance]], &"info")))
		column.add_child(card)
		var row := UIUtil.hbox(6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(row)
		var badge := PanelContainer.new()
		badge.custom_minimum_size = Vector2(24, 24)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(badge)
		var letter := UIUtil.label("", &"HudLabel", HORIZONTAL_ALIGNMENT_CENTER)
		letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		letter.add_theme_font_size_override("font_size", 14)
		badge.add_child(letter)
		var info := UIUtil.vbox(1)
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var title := UIUtil.label("", &"SmallLabel")
		title.clip_text = true
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(title)
		title.add_theme_font_size_override("font_size", 14)
		var bar := _bar(&"HPBar", 7)
		info.add_child(bar)
		var exp_bar := _bar(&"EXPBar", 3)
		info.add_child(exp_bar)
		# The cross lets this member go (the card itself changes its stance).
		var kick := UIUtil.button("✕", &"", Vector2(32, 32))
		kick.name = "Kick"
		kick.focus_mode = Control.FOCUS_NONE
		kick.add_theme_font_size_override("font_size", 15)
		kick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		kick.pressed.connect(func(): kick_party_member(i))
		row.add_child(kick)
		_party_cards.append({"card": card, "badge": badge, "letter": letter, "title": title, "bar": bar, "exp": exp_bar, "kick": kick, "key": ""})


## Lets the i-th party member go (the cross on its card); it says goodbye.
func kick_party_member(i: int) -> void:
	if i < 0 or i >= Game.world_party.size():
		return
	var who: Dictionary = Game.party()[i]
	Game.party_kick(Game.world_party[i], "%s ออกจากปาร์ตี้แล้ว" % who.name)
	AudioManager.play_ui(&"ui_cancel")


const WING_LABELS := ["ยืน", "บิน", "หุบปีก"]
## The Dark Lord's cape: walk, float, gather it up.
const CAPE_LABELS := ["เดิน", "ลอย", "เก็บผ้าคลุม"]
## Chip order on screen: fly, stand, fold.
const WING_ORDER := [HeroVisual.WING_FLY, HeroVisual.WING_STAND, HeroVisual.WING_FOLD]


var _cape_shown := false


func _build_wing_row(column: Control) -> void:
	_wing_row = UIUtil.hbox(8)
	_wing_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wing_row.visible = false
	column.add_child(_wing_row)
	for mode in WING_ORDER:
		var chip := PanelContainer.new()
		chip.custom_minimum_size = Vector2(108, 46)
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		chip.gui_input.connect(_tap(func():
			if hero != null:
				hero.set_wing_mode(mode)
				_update_wing_row()))
		var label := UIUtil.label(WING_LABELS[mode], &"HudLabel", HORIZONTAL_ALIGNMENT_CENTER)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(label)
		_wing_row.add_child(chip)
		_wing_chips.append(chip)


func _update_wing_row() -> void:
	var worn := hero != null and is_instance_valid(hero.visual) and hero.visual.has_wings()
	_wing_row.visible = worn
	var cape := worn and hero.visual.class_id == &"darklord"
	if not worn or (hero.visual.wing_mode == _wing_shown and cape == _cape_shown):
		return
	_wing_shown = hero.visual.wing_mode
	_cape_shown = cape
	for i in _wing_chips.size():
		(_wing_chips[i].get_child(0) as Label).text = (CAPE_LABELS if cape else WING_LABELS)[WING_ORDER[i]]
	for i in _wing_chips.size():
		var active: bool = WING_ORDER[i] == _wing_shown
		var style := StyleBoxFlat.new()
		style.bg_color = Color(UIPalette.GOLD, 0.9) if active else Color(0.1, 0.12, 0.2, 0.72)
		style.set_corner_radius_all(14)
		style.set_border_width_all(2)
		style.border_color = Color.WHITE if active else Color(1, 1, 1, 0.35)
		_wing_chips[i].add_theme_stylebox_override("panel", style)
		(_wing_chips[i].get_child(0) as Label).add_theme_color_override("font_color", Color("2a1a08") if active else Color.WHITE)


## The guild war being fought in this zone, or null.
func _war() -> GuildWarMatch:
	if zone == null or not is_instance_valid(zone) or zone.gw_match == null or not is_instance_valid(zone.gw_match):
		return null
	return zone.gw_match


func _update_party() -> void:
	var war := _war()
	_party_head.visible = war != null
	if war != null:
		_update_war_party(war)
		return
	var party := Game.party()
	for i in _party_cards.size():
		var entry: Dictionary = _party_cards[i]
		var card: Control = entry.card
		card.visible = i < party.size() and (zone != null)
		if not card.visible:
			continue
		card.modulate = Color.WHITE
		(entry.kick as Control).visible = true
		(entry.exp as Control).visible = true
		var member: Dictionary = party[i]
		var data := ClassData.get_class_data(StringName(member["class"]))
		var key := "%s|%d|%d" % [member.name, int(member.level), Game.party_stars(member)]
		var level_text := "Lv.%d%s" % [int(member.level), " ★%d" % Game.party_stars(member) if Game.party_stars(member) > 0 else ""]
		if key != entry.key:
			entry["key"] = key
			var style := StyleBoxFlat.new()
			style.bg_color = data.color
			style.set_corner_radius_all(17)
			style.set_border_width_all(2)
			style.border_color = Color.WHITE
			(entry.badge as PanelContainer).add_theme_stylebox_override("panel", style)
			(entry.letter as Label).text = String(data.badge)
			(entry.title as Label).text = "%s  %s" % [member.name, level_text]
		entry["name_text"] = "%s  %s" % [member.name, level_text]
		(entry.title as Label).text = "%s  [%s]" % [entry.name_text, Game.STANCE_NAMES[String(member.get("stance", "follow"))]]
		var bar := entry.bar as ProgressBar
		var buddy: Companion = zone.companions[i] if zone != null and i < zone.companions.size() and is_instance_valid(zone.companions[i]) else null
		if buddy:
			UIUtil.set_bar(bar, buddy.hp, buddy.max_hp)
			UIUtil.tint_hp_bar(bar, float(buddy.hp) / float(maxi(1, buddy.max_hp)))
		else:
			UIUtil.set_bar(bar, 1, 1)
		# Their own progress to the next level or star (they level on their own schedule).
		var exp_bar := entry.exp as ProgressBar
		exp_bar.max_value = 1000.0
		exp_bar.value = float(member.get("frac", 0.0)) * 1000.0


## In a guild war the party cards show the hero's war party: class badge, name and
## level, HP (a fallen member greyed with its respawn), no stance and no cross.
func _update_war_party(war: GuildWarMatch) -> void:
	var members := war.hero_party_members()
	_party_head.text = "◆ ปาร์ตี้ของคุณ %d/%d · บัฟถึงเฉพาะในปาร์ตี้" % [members.size() + 1, GuildWarMatch.PARTY_SIZE]
	for i in _party_cards.size():
		var entry: Dictionary = _party_cards[i]
		var card: Control = entry.card
		card.visible = i < members.size()
		(entry.kick as Control).visible = false
		(entry.exp as Control).visible = false
		if not card.visible:
			continue
		var f := members[i]
		var data := ClassData.get_class_data(f.fighter_class())
		var level_text := String(f.tag) if String(f.tag) != "" else "Lv.%d" % int(f.member.get("level", 100))
		var key := "gw|%s|%s" % [f.member.name, level_text]
		if key != entry.key:
			entry["key"] = key
			var style := StyleBoxFlat.new()
			style.bg_color = data.color
			style.set_corner_radius_all(17)
			style.set_border_width_all(2)
			style.border_color = GuildWarMatch.PARTY_COLOR
			(entry.badge as PanelContainer).add_theme_stylebox_override("panel", style)
			(entry.letter as Label).text = String(data.badge)
		var dead := f.is_dead()
		(entry.title as Label).text = "%s  %s" % [f.member.name, ("ล้ม · เกิดใน %d" % int(ceil(f.respawn_left))) if dead else level_text]
		card.modulate = Color(1, 1, 1, 0.5) if dead else Color.WHITE
		var bar := entry.bar as ProgressBar
		UIUtil.set_bar(bar, 0 if dead else f.hp, maxi(1, f.max_hp))
		UIUtil.tint_hp_bar(bar, 0.0 if dead else f.hp_ratio())


func _build_top_right(frame: Control) -> void:
	var row := UIUtil.hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.anchor_left = 1.0
	row.anchor_right = 1.0
	row.offset_left = -560
	row.offset_right = 0
	row.alignment = BoxContainer.ALIGNMENT_END
	frame.add_child(row)
	# Talk to the world players: a tap opens the typing bar for the world chat.
	var chat := UIUtil.panel(&"HudPanel")
	chat.name = "ChatChip"
	chat.mouse_filter = Control.MOUSE_FILTER_STOP
	chat.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chat.gui_input.connect(_tap(func(): chat_requested.emit()))
	var chat_label := UIUtil.label("แชท", &"HudLabel")
	chat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat.add_child(chat_label)
	row.add_child(chat)
	# Who else is playing: the world players online plus the hero; a tap opens the registry.
	var online := UIUtil.panel(&"HudPanel")
	online.name = "OnlineChip"
	online.mouse_filter = Control.MOUSE_FILTER_STOP
	online.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	online.gui_input.connect(_tap(func(): registry_requested.emit()))
	var online_row := UIUtil.hbox(6)
	online_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	online.add_child(online_row)
	var dot := UIUtil.label("●", &"HudLabel")
	dot.add_theme_color_override("font_color", Color("6dff9a"))
	online_row.add_child(dot)
	_online_label = UIUtil.label("", &"HudLabel")
	online_row.add_child(_online_label)
	row.add_child(online)
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
	_zone_label.offset_left = -480
	_zone_label.offset_top = 90
	_zone_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_zone_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_zone_label.add_theme_constant_override("outline_size", 6)
	_zone_label.offset_right = -160
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

	for i in ClassData.SLOTS:
		var slot := SkillSlot.new()
		slot.slot_number = i + 1
		slot.pressed.connect(func(): if hero: hero.use_skill(i))
		frame.add_child(slot)
		skill_slots.append(slot)

	hp_potion = _small_button("res://assets/icons/ui/heart_potion.svg", UIPalette.DANGER, Vector2.ZERO)
	hp_potion.pressed.connect(func(): if hero: hero.use_potion("hp"))
	frame.add_child(hp_potion)
	mp_potion = _small_button("res://assets/icons/ui/mana_potion.svg", UIPalette.SP, Vector2.ZERO)
	mp_potion.pressed.connect(func(): if hero: hero.use_potion("mp"))
	frame.add_child(mp_potion)
	auto_button = _small_button("", UIPalette.SUCCESS, Vector2.ZERO)
	auto_button.toggle_mode = true
	auto_button.text = "ออโต้"
	auto_button.font_size_override = 17
	auto_button.pressed.connect(func(): if hero: hero.toggle_auto())
	frame.add_child(auto_button)
	target_button = _small_button("res://assets/icons/ui/target.svg", UIPalette.GOLD, Vector2.ZERO)
	target_button.pressed.connect(func(): if hero: hero.cycle_target())
	frame.add_child(target_button)
	raven_button = _small_button("", Color("8a4dff"), Vector2.ZERO)
	raven_button.toggle_mode = true
	raven_button.text = "อีกา"
	raven_button.font_size_override = 17
	raven_button.visible = false
	raven_button.pressed.connect(func():
		if hero and hero.raven:
			hero.set_raven_attack(not hero.raven.attack)
			Game.say("อีกา: %s" % ("บุกโจมตีเอง" if hero.raven.attack else "กลับมาเกาะแขน"), &"info"))
	frame.add_child(raven_button)
	# Violet like the raven button, with a raven over the mode name, so it never
	# reads as the auto-hunt button beside it.
	raven_mode_button = _small_button("res://assets/icons/ui/raven.svg", Color("8a4dff"), Vector2.ZERO)
	raven_mode_button.text = DarkRaven.MODE_NAMES[DarkRaven.Mode.AUTO]
	raven_mode_button.font_size_override = 13
	raven_mode_button.visible = false
	raven_mode_button.pressed.connect(func():
		if hero and hero.raven:
			hero.set_raven_mode((hero.raven.mode + 1) % 3)
			raven_mode_button.text = DarkRaven.MODE_NAMES[hero.raven.mode]
			Game.say("อีกา: %s" % RAVEN_MODE_TIPS[hero.raven.mode], &"info"))
	frame.add_child(raven_mode_button)

	interact_button = TouchButton.new()
	interact_button.radius = 52.0
	interact_button.icon = load("res://assets/icons/ui/interact.svg")
	interact_button.accent = UIPalette.ORANGE
	interact_button.text = "คุย"
	_place_corner(interact_button, Vector2(-30, -30), 52.0)
	interact_button.pressed.connect(func(): interact_pressed.emit())
	frame.add_child(interact_button)


## Positions are calculated together so every skill retains its own touch area.
## The virtual canvas expands beyond 1280 x 720 on wide phones/tablets.
static func action_layout(canvas_size: Vector2) -> Dictionary:
	var spacing := clampf((canvas_size.x - 550.0) / float(ClassData.SLOTS - 1), 80.0, SKILL_SPACING)
	var centers: Array[Vector2] = []
	for i in ClassData.SLOTS:
		centers.append(Vector2(SKILL_ROW_RIGHT - (ClassData.SLOTS - 1 - i) * spacing, SKILL_ROW_Y))
	var utility: Array[Vector2] = []
	# Keep the top potion below the minimap, including a phone's safe insets.
	var utility_spacing := clampf((canvas_size.y - 466.0) / 3.0, 62.0, 72.0)
	for i in 4:
		utility.append(Vector2(-40.0, -184.0 - (3 - i) * utility_spacing))
	return {"skills": centers, "skill_spacing": spacing, "utility": utility, "attack": Vector2(-84, -84)}


func _layout_actions() -> void:
	if attack_button == null or skill_slots.size() != ClassData.SLOTS:
		return
	var positions := action_layout(_frame.size)
	for i in skill_slots.size():
		var slot := skill_slots[i]
		slot.radius = SKILL_RADIUS
		slot.name_width = minf(86.0, positions.skill_spacing - 6.0)
		slot.queue_redraw()
		_place_corner(slot, positions.skills[i] + Vector2.ONE * slot.radius, slot.radius)
	var utilities := [hp_potion, mp_potion, auto_button, target_button]
	for i in utilities.size():
		var button: TouchButton = utilities[i]
		_place_corner(button, positions.utility[i] + Vector2.ONE * button.radius, button.radius)
	# The raven button sits just left of the auto button.
	_place_corner(raven_button, positions.utility[2] + Vector2(-72, 0) + Vector2.ONE * raven_button.radius, raven_button.radius)
	# Its mode button sits right above it.
	_place_corner(raven_mode_button, positions.utility[2] + Vector2(-72, -72) + Vector2.ONE * raven_mode_button.radius, raven_mode_button.radius)
	_place_corner(attack_button, positions.attack + Vector2.ONE * ATTACK_RADIUS, ATTACK_RADIUS)
	_place_corner(interact_button, positions.attack + Vector2.ONE * interact_button.radius, interact_button.radius)
	# The world chat sits between the joystick's resting ring and the first skill slot,
	# whatever the screen's width (a narrow screen gets a narrower chat).
	if world_chat != null:
		var first: Vector2 = positions.skills[0]
		# Just past the joystick's ring, which is placed on the screen while the chat
		# lives in the safe-area frame.
		var after_stick := 250.0
		if joystick != null:
			after_stick = joystick.global_position.x + joystick.rest_offset.x + joystick.base_radius + 24.0 - _frame.global_position.x
		world_chat.offset_left = after_stick
		world_chat.offset_right = maxf(_frame.size.x + first.x - SKILL_SLOT_CLEAR, after_stick + 160.0)
		world_chat.custom_minimum_size = Vector2(0.0, WorldChat.HEIGHT)
		world_chat.size = Vector2(world_chat.offset_right - world_chat.offset_left, WorldChat.HEIGHT)


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
	_build_boss_bar(frame)
	_banner = UIUtil.label("", &"TitleLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_banner.add_theme_font_size_override("font_size", 28)
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.anchor_left = 0.33
	_banner.anchor_right = 0.70
	_banner.anchor_top = 0.0
	_banner.anchor_bottom = 0.0
	_banner.offset_top = 174
	_banner.offset_bottom = 244
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
	_death_title = label
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.offset_left = -300
	label.offset_right = 300
	label.offset_top = -50
	_death_panel.add_child(label)
	var sub := UIUtil.label("กำลังกลับหมู่บ้านเพื่อพักฟื้น", &"HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_death_sub = sub
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
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8:
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
