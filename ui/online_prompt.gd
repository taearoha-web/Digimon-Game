class_name OnlinePrompt
extends CanvasLayer
## A real player's party invitation (Online "party_invite"): a small card at the top of
## the screen, "<name> ชวนคุณเข้าปาร์ตี้", with เข้าร่วม / ไม่ล่ะ (Online.answer_invite).
## It never stops the game (a fight goes on under it), answers "no" by itself after
## TIMEOUT seconds and goes away when the connection does. A newer invitation replaces
## the one shown.

const TIMEOUT := 30.0
const WIDTH := 520.0

var _card: PanelContainer
var _text: Label
var _left := 0.0


func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var safe := SafeAreaContainer.new()
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(safe)
	var frame := Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(frame)
	_card = UIUtil.panel(&"HudPanel")
	_card.name = "InviteCard"
	_card.anchor_left = 0.5
	_card.anchor_right = 0.5
	_card.offset_left = -WIDTH * 0.5
	_card.offset_right = WIDTH * 0.5
	_card.offset_top = 96
	_card.visible = false
	frame.add_child(_card)
	var column := UIUtil.vbox(8)
	_card.add_child(column)
	_text = UIUtil.label("", &"HudLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_text)
	var buttons := UIUtil.hbox(14)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)
	var no := UIUtil.button("ไม่ล่ะ", &"", Vector2(160, 56))
	no.name = "No"
	no.pressed.connect(answer.bind(false))
	buttons.add_child(no)
	var yes := UIUtil.button("เข้าร่วม", &"PrimaryButton", Vector2(180, 56))
	yes.name = "Yes"
	yes.pressed.connect(answer.bind(true))
	buttons.add_child(yes)
	Online.message.connect(_on_message)
	Online.disconnected.connect(func(): _card.visible = false)


func _on_message(type: String, _data: Dictionary) -> void:
	if type != "party_invite" or Online.pending_invite().is_empty():
		return
	_text.text = "%s ชวนคุณเข้าปาร์ตี้\n(ผู้เล่นจริง · เล่นด้วยกัน ตีมอนตัวเดียวกัน)" % String(Online.pending_invite().name)
	_left = TIMEOUT
	_card.visible = true
	UIUtil.pop_in(_card)
	AudioManager.play_ui(&"ui_open")


func is_showing() -> bool:
	return _card.visible


func answer(ok: bool) -> void:
	if not _card.visible:
		return
	_card.visible = false
	Online.answer_invite(ok)
	AudioManager.play_ui(&"ui_click" if ok else &"ui_cancel")


func _process(delta: float) -> void:
	if not _card.visible:
		return
	_left -= delta
	if _left <= 0.0:
		answer(false)
