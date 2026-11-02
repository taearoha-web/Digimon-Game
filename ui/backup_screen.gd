class_name BackupScreen
extends CanvasLayer
## The save backups kept on this device (SaveBackup), newest first; each opens to its
## heroes, one "กู้คืนช่องนี้" per hero, "กู้คืนทั้งหมด" for the whole backup. A restore
## is confirmed by tapping the same button again ("แตะอีกครั้งเพื่อยืนยัน"), not by a
## dialog. [signal restored] fires after a successful restore so the character select
## can put the heroes back on their circles.

signal restored()
signal closed()

const MONTHS := ["ม.ค.", "ก.พ.", "มี.ค.", "เม.ย.", "พ.ค.", "มิ.ย.", "ก.ค.", "ส.ค.", "ก.ย.", "ต.ค.", "พ.ย.", "ธ.ค."]
const REASONS := {"daily": "รายวัน", "manual": "ด้วยมือ", "before-restore": "ก่อนกู้คืน", "before-storage": "ก่อนรวมคลัง"}
## A tapped restore button waits this long for its confirming tap.
const CONFIRM_SECONDS := 4.0

var is_open := false
var _root: Control
var _box: VBoxContainer
var _status: Label
var _open_dir := ""
## The restore button awaiting its second tap, and its text before the first.
var _pending: Button
var _pending_text := ""


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.1, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var safe := SafeAreaContainer.new()
	_root.add_child(safe)
	var frame := Control.new()
	safe.add_child(frame)
	var panel := UIUtil.panel(&"GlassPanel")
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 16
	panel.offset_top = 12
	panel.offset_right = -16
	panel.offset_bottom = -12
	frame.add_child(panel)
	var column := UIUtil.vbox(10)
	panel.add_child(column)
	var head := UIUtil.hbox(14)
	column.add_child(head)
	var titles := UIUtil.vbox(0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	titles.add_child(UIUtil.label("สำรอง / กู้คืนเซฟ", &"HeaderLabel"))
	var hint := UIUtil.label("เก็บในเครื่องนี้: รายวัน %d ชุด, ด้วยมือ %d ชุด" % [SaveBackup.KEEP_DAILY, SaveBackup.KEEP_MANUAL], &"SmallLabel")
	hint.clip_text = true
	hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	titles.add_child(hint)
	var now := UIUtil.button("สำรองตอนนี้", &"GhostButton", Vector2(180, 60))
	now.pressed.connect(_on_backup_now)
	head.add_child(now)
	var close := UIUtil.button("ปิด", &"PrimaryButton", Vector2(140, 60))
	close.pressed.connect(close_screen)
	head.add_child(close)
	_status = UIUtil.label("", &"BoldLabel")
	_status.clip_text = true
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_status)
	var scroll := TouchScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_box = UIUtil.vbox(8)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_box)


func open_screen() -> void:
	is_open = true
	_root.visible = true
	_status.text = ""
	AudioManager.play_ui(&"ui_open")
	_rebuild()


func close_screen() -> void:
	is_open = false
	_root.visible = false
	_pending = null
	UIUtil.clear(_box)
	closed.emit()


## "29 ต.ค. 21:40"
static func format_time(unix_time: int) -> String:
	if unix_time <= 0:
		return "-"
	var d := Time.get_datetime_dict_from_unix_time(unix_time + int(Time.get_time_zone_from_system().get("bias", 0)) * 60)
	return "%d %s %02d:%02d" % [d.day, MONTHS[clampi(int(d.month) - 1, 0, 11)], d.hour, d.minute]


static func reason_text(reason: String) -> String:
	return String(REASONS.get(reason, reason))


func _rebuild() -> void:
	_pending = null
	UIUtil.clear(_box)
	var backups := SaveBackup.list()
	if backups.is_empty():
		_box.add_child(UIUtil.label("ยังไม่มีชุดสำรอง — เกมจะสำรองให้วันละครั้ง หรือแตะ \"สำรองตอนนี้\"", &"DimLabel"))
		return
	for entry in backups:
		_box.add_child(_backup_row(entry))


func _backup_row(entry: Dictionary) -> Control:
	var dir: String = entry.dir
	var slots: Dictionary = entry.slots
	var card := UIUtil.panel(&"CardPanel")
	var column := UIUtil.vbox(6)
	card.add_child(column)
	var line := UIUtil.hbox(10)
	column.add_child(line)
	var title := UIUtil.label("%s · %s · %d ตัวละคร" % [format_time(int(entry.time)), reason_text(String(entry.reason)), slots.size()], &"BoldLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.add_child(title)
	var is_open_dir := dir == _open_dir
	var toggle := UIUtil.button("ซ่อน" if is_open_dir else "ดูตัวละคร", &"GhostButton", Vector2(140, 52))
	toggle.pressed.connect(func():
		_open_dir = "" if dir == _open_dir else dir
		_rebuild())
	line.add_child(toggle)
	var all := UIUtil.button("กู้คืนทั้งหมด", &"DangerButton", Vector2(170, 52))
	all.pressed.connect(func(): _confirm(all, func(): return SaveBackup.restore_all(dir), "กู้คืนทั้งหมดจาก %s แล้ว" % format_time(int(entry.time))))
	line.add_child(all)
	if not is_open_dir:
		return card
	# The shared storage comes back with "กู้คืนทั้งหมด" only; one hero leaves it as it is.
	var stored := int(entry.get("storage", -1))
	if stored >= 0:
		column.add_child(UIUtil.label("คลังรวมทุกตัวละคร %d ชิ้น — กลับมาเมื่อกด \"กู้คืนทั้งหมด\" (กู้ทีละช่องคลังไม่เปลี่ยน)" % stored, &"SmallLabel"))
	var keys := slots.keys()
	keys.sort_custom(func(a, b): return int(a) < int(b))
	for key in keys:
		var slot := int(key)
		var info: Dictionary = slots[key] if slots[key] is Dictionary else {}
		var row := UIUtil.hbox(10)
		column.add_child(row)
		var cls := JobData.resolve(StringName(String(info.get("class", "warrior"))), int(info.get("adv", 0)))
		var who := UIUtil.label("จุด %d · %s · %s Lv.%d" % [slot, String(info.get("name", "?")), cls.name, int(info.get("level", 1))], &"SmallLabel")
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		who.clip_text = true
		who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		who.add_theme_color_override("font_color", cls.color.lightened(0.35))
		row.add_child(who)
		var one := UIUtil.button("กู้คืนช่องนี้", &"GhostButton", Vector2(170, 48))
		one.pressed.connect(func(): _confirm(one, func(): return SaveBackup.restore(dir, slot), "กู้คืนจุด %d แล้ว" % slot))
		row.add_child(one)
	return card


## First tap arms the button, the second within CONFIRM_SECONDS runs the restore.
func _confirm(button: Button, action: Callable, done_text: String) -> void:
	if _pending == button:
		_pending = null
		button.text = _pending_text
		button.disabled = true
		if bool(action.call()):
			_status.text = done_text
			_status.add_theme_color_override("font_color", UIPalette.SUCCESS)
			restored.emit()
		else:
			_status.text = "กู้คืนไม่สำเร็จ — ไฟล์สำรองเสียหายหรือหายไป"
			_status.add_theme_color_override("font_color", UIPalette.DANGER)
		if is_open:
			_rebuild()
		return
	if _pending != null and is_instance_valid(_pending):
		_pending.text = _pending_text
	_pending = button
	_pending_text = button.text
	button.text = "แตะอีกครั้งเพื่อยืนยัน"
	get_tree().create_timer(CONFIRM_SECONDS).timeout.connect(func():
		if _pending == button and is_instance_valid(button):
			button.text = _pending_text
			_pending = null)


func _on_backup_now() -> void:
	var dir := SaveBackup.backup_now("manual")
	if dir == "":
		_status.text = "ไม่มีเซฟให้สำรอง" if not Game.any_save() else "สำรองไม่สำเร็จ"
		_status.add_theme_color_override("font_color", UIPalette.WARNING)
	else:
		_status.text = "สำรองแล้ว"
		_status.add_theme_color_override("font_color", UIPalette.SUCCESS)
	_rebuild()
