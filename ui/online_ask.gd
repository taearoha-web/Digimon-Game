class_name OnlineAsk
extends CanvasLayer
## A real player's request (แลกเปลี่ยน, ท้าประลอง): a small card near the top of the
## screen with a yes and a no and a countdown, answered no when the time runs out. It does
## not block the game (a request can come in the middle of a fight). Cards stack; one
## layer serves the whole session (find_or_make).

const GROUP := &"online_ask"
const CARD_WIDTH := 560.0

var _stack: VBoxContainer
static var _shared: OnlineAsk


## The session's layer (made under the scene root on first use).
static func find_or_make(from: Node) -> OnlineAsk:
	if is_instance_valid(_shared) and not _shared.is_queued_for_deletion():
		return _shared
	var layer := OnlineAsk.new()
	layer._build()
	from.get_tree().root.add_child.call_deferred(layer)
	_shared = layer
	return layer


func _build() -> void:
	if _stack != null:
		return
	layer = 75
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(GROUP)
	var safe := SafeAreaContainer.new()
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(safe)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(root)
	_stack = VBoxContainer.new()
	_stack.anchor_left = 0.5
	_stack.anchor_right = 0.5
	_stack.offset_left = -CARD_WIDTH * 0.5
	_stack.offset_right = CARD_WIDTH * 0.5
	# Under the HUD's top bar and the toasts' first line.
	_stack.offset_top = 96
	_stack.add_theme_constant_override("separation", 8)
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_stack)


func _ready() -> void:
	_build()


## Takes a card away at once (no answer is given).
static func withdraw(card: Control) -> void:
	if card == null or not is_instance_valid(card):
		return
	if card.get_parent() != null:
		card.get_parent().remove_child(card)
	card.queue_free()


## Shows [param text] with two buttons; [param answer] gets true / false once (false when
## [param seconds] pass). Returns the card (withdraw it to take the question back silently).
func ask(text: String, yes_text: String, no_text: String, seconds: float, answer: Callable) -> Control:
	_build()
	var card := PanelContainer.new()
	card.theme_type_variation = &"GlassPanel"
	card.name = "AskCard"
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := UIUtil.vbox(8)
	card.add_child(box)
	var label := UIUtil.label(text, &"BoldLabel", HORIZONTAL_ALIGNMENT_CENTER)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(CARD_WIDTH - 40.0, 0)
	box.add_child(label)
	var clock := UIUtil.label("", &"SmallLabel", HORIZONTAL_ALIGNMENT_CENTER)
	clock.name = "Clock"
	box.add_child(clock)
	var row := UIUtil.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var no := UIUtil.button(no_text, &"GhostButton", Vector2(200, 60))
	no.name = "No"
	row.add_child(no)
	var yes := UIUtil.button(yes_text, &"PrimaryButton", Vector2(200, 60))
	yes.name = "Yes"
	row.add_child(yes)
	_stack.add_child(card)
	var state := {"done": false, "left": seconds}
	var finish := func(ok: bool):
		if state.done:
			return
		state.done = true
		withdraw(card)
		answer.call(ok)
	yes.pressed.connect(finish.bind(true))
	no.pressed.connect(finish.bind(false))
	clock.text = "ตอบภายใน %d วินาที" % int(ceil(seconds))
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	card.add_child(timer)
	timer.timeout.connect(func():
		state.left = float(state.left) - 1.0
		clock.text = "ตอบภายใน %d วินาที" % maxi(0, int(ceil(float(state.left))))
		if float(state.left) <= 0.0:
			finish.call(false))
	AudioManager.play_ui(&"ui_open")
	return card
