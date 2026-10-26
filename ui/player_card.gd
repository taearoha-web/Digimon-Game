class_name PlayerCard
extends CanvasLayer
## The card of a world player the hero tapped (walk up to someone, tap them): name, guild,
## class, level and play style, and the party buttons. A stranger asks to join the hero's
## party here (Game.party_invite) and answers above its head; a member can change its
## stance or be let go. The game keeps running while the card is up; it closes when the
## player is gone, out of reach or a screen opens.

signal closed()

## How near the hero must be to talk to someone (metres).
const RANGE := 12.0
const YES := ["ได้เลย ไปด้วยกัน!", "โอเค ลุยกัน!", "ยินดีเลย ไปกัน!", "จัดไป!"]
const BYE := ["ไว้เจอกันใหม่นะ!", "ขอบคุณที่ชวนนะ!", "ไปล่าต่อแล้วนะ!"]

var is_open := false
var player: FieldPlayer
var hero: Hero
var _root: Control
var _body: VBoxContainer


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)
	var panel := UIUtil.panel(&"GlassPanel")
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -300
	panel.offset_right = 300
	panel.offset_top = 104
	_root.add_child(panel)
	_body = UIUtil.vbox(8)
	panel.add_child(_body)
	Game.party_roster_changed.connect(func():
		if is_open:
			_build())


## Whether `p` stands close enough to the hero to be talked to.
static func in_reach(p: FieldPlayer, h: Hero) -> bool:
	if p == null or h == null or not is_instance_valid(p) or not is_instance_valid(h):
		return false
	var d := p.global_position - h.global_position
	d.y = 0.0
	return d.length() <= RANGE


func open_card(p: FieldPlayer, h: Hero) -> void:
	player = p
	hero = h
	is_open = true
	_root.visible = true
	AudioManager.play_ui(&"ui_open")
	_build()
	UIUtil.pop_in(_root.get_child(0) as Control)


func close_card() -> void:
	if not is_open:
		return
	is_open = false
	_root.visible = false
	player = null
	UIUtil.clear(_body)
	closed.emit()


func _process(_delta: float) -> void:
	if not is_open:
		return
	if get_tree().paused or not is_instance_valid(player) or player.is_queued_for_deletion() or not player.visible \
			or not is_instance_valid(hero) or player.global_position.distance_to(hero.global_position) > RANGE * 1.6:
		close_card()


func _build() -> void:
	if not is_instance_valid(player):
		close_card()
		return
	UIUtil.clear(_body)
	var i := player.world_index
	var s := WorldPlayers.state(i, WorldPresence.clock())
	var g := int(s.guild)
	var head := UIUtil.hbox(10)
	_body.add_child(head)
	var title := UIUtil.label(("[%s] %s" % [WorldPlayers.guild_name(g), s.name]) if g > 0 else String(s.name), &"HeaderLabel")
	title.add_theme_color_override("font_color", WorldPlayers.GUILD_COLORS.get(g, Color.WHITE))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var shut := UIUtil.button("ปิด", &"", Vector2(110, 54))
	shut.name = "Close"
	shut.pressed.connect(close_card)
	head.add_child(shut)
	var style := String(WorldPlayers.STYLES[String(s.style)].label)
	var line := UIUtil.label("%s · %s · %s" % [ClassData.get_class_data(StringName(s["class"])).name, WorldPlayers.level_text(s), style], &"BoldLabel")
	_body.add_child(line)
	var member := Game.in_party(i)
	var note := ""
	if member:
		note = "อยู่ในปาร์ตี้ของคุณ · แบ่ง EXP กันทุกตัวที่ล้มได้"
	elif Game.party().size() >= Game.PARTY_MAX:
		note = "ปาร์ตี้ของคุณเต็มแล้ว (ปาร์ตี้ละ %d คนรวมคุณ)" % Game.PARTY_SIZE
	else:
		var mate := Game.guild() > 0 and g == Game.guild()
		note = "เพื่อนร่วมกิลด์ ชวนได้เสมอ" if mate else "ชวนได้ถ้าเลเวลห่างจากคุณไม่เกิน %d" % Game.PARTY_LEVEL_GAP
	var hint := UIUtil.label(note, &"SmallLabel")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(hint)
	var row := UIUtil.hbox(10)
	_body.add_child(row)
	if member:
		var k := Game.world_party.find(i)
		var stance := String(Game.party()[k].get("stance", "follow"))
		var stance_button := UIUtil.button("ท่าที: %s" % Game.STANCE_NAMES.get(stance, stance), &"", Vector2(220, 60))
		stance_button.name = "Stance"
		stance_button.pressed.connect(func():
			Game.cycle_stance(Game.world_party.find(i))
			_build())
		row.add_child(stance_button)
		var leave := UIUtil.button("ออกจากปาร์ตี้", &"", Vector2(220, 60))
		leave.name = "Leave"
		leave.pressed.connect(func():
			var who := player
			Game.party_kick(i, "%s ออกจากปาร์ตี้แล้ว" % s.name)
			if is_instance_valid(who):
				who.say(BYE[randi() % BYE.size()]))
		row.add_child(leave)
	else:
		var invite := UIUtil.button("ชวนเข้าปาร์ตี้", &"PrimaryButton", Vector2(300, 60))
		invite.name = "Invite"
		invite.disabled = Game.party().size() >= Game.PARTY_MAX
		invite.pressed.connect(invite_party)
		row.add_child(invite)


## Asks the player on the card to join; it answers above its head.
func invite_party() -> String:
	if not is_instance_valid(player):
		return "ไม่พบผู้เล่น"
	var who := player
	var why := Game.party_invite(who.world_index)
	if why == "":
		who.say(YES[randi() % YES.size()], Color("8ff0ff"))
	else:
		if why.contains("เลเวล"):
			who.say("เลเวลห่างกันไปหน่อยนะ ไว้คราวหน้า!", Color("ffb0b0"))
		Game.say(why, &"warning")
	if is_open:
		_build()
	return why
