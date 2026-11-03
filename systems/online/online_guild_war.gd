class_name OnlineGuildWar
extends Node
## The guild war together (docs/ONLINE_PROTOCOL.md: gw_invite / gw_answer / gw_start).
##
## The party leader who goes to war online asks its party in (`gw_invite`) and holds the
## countdown (GuildWarMatch.hold) until every member answered and the ones who said yes
## stand in the war, at most WAIT seconds; then `gw_start {seed, plan}` starts the same
## countdown everywhere. A member gets a Thai prompt; saying yes takes it to the war,
## where its match is a mirror of the leader's (GuildWarMatch.mirror): the leader hosts
## the fighters and the gates through EntitySync, the member fights on the leader's side,
## and the leader's bell (`gw_end`) shows the result screen for everyone.
## One of these lives under the root (ensure) so an invite reaches the village too.

const WAIT := 25.0
## A prompt nobody answers says no by itself.
const ANSWER_TIME := 20.0
const WAR_ZONE := &"guildwar"

static var instance: OnlineGuildWar
## A member said yes: the next guild war it builds is a mirror of the leader's.
static var _joining := false
## When it said yes (msec): a yes older than JOIN_TIME (the trip never happened) is void.
static var _joined_at := 0
const JOIN_TIME := 60000
## The leader's gw_start plan, kept when it came before the member's war was built.
static var _start: Dictionary = {}

## Leader: the war waiting for its party, and each invited member's answer.
var war: GuildWarMatch
var invited: Dictionary = {}
var _wait := 0.0
## Member: the open prompt.
var prompt: CanvasLayer
var _prompt_left := 0.0
var _invite_from := ""


static func ensure(tree: SceneTree) -> OnlineGuildWar:
	if instance != null and is_instance_valid(instance):
		return instance
	instance = OnlineGuildWar.new()
	instance.name = "OnlineGuildWar"
	tree.root.add_child.call_deferred(instance)
	return instance


static func take_joining() -> bool:
	var was := _joining and Time.get_ticks_msec() - _joined_at < JOIN_TIME
	_joining = false
	return was


static func take_start() -> Dictionary:
	var plan := _start
	_start = {}
	return plan


## The party leader's own war is built: invite the party and hold the countdown.
static func on_war_built(p_zone: Node) -> void:
	var w: Variant = p_zone.get("gw_match")
	if w == null or not is_instance_valid(w) or (w as GuildWarMatch).mirror:
		return
	if not Online.is_online() or not Online.in_party() or String(Online.party().get("leader", "")) != Online.my_id():
		return
	var others: Array = []
	for id in Online.party().get("members", []):
		if String(id) != Online.my_id() and Online.players().has(String(id)):
			others.append(String(id))
	if others.is_empty():
		return
	ensure(p_zone.get_tree()).lead(w as GuildWarMatch, others)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Online.message.connect(_on_message)


func _exit_tree() -> void:
	if instance == self:
		instance = null
	if Online.message.is_connected(_on_message):
		Online.message.disconnect(_on_message)


func lead(p_war: GuildWarMatch, members: Array) -> void:
	war = p_war
	war.hold = true
	invited.clear()
	for id in members:
		invited[String(id)] = "wait"
	_wait = WAIT
	Online.send("gw_invite")
	war.zone.banner_requested.emit("รอสมาชิกปาร์ตี้ตอบรับสงครามกิลด์...")
	Game.say("ชวนปาร์ตี้ลงสงครามกิลด์ด้วยกันแล้ว รอตอบรับสูงสุด %d วินาที" % int(WAIT), &"quest")


func _process(delta: float) -> void:
	if war != null:
		if not is_instance_valid(war) or not Online.is_online():
			war = null
		else:
			_wait -= delta
			if _wait <= 0.0 or _everyone_here():
				start_war()
	if prompt != null:
		_prompt_left -= delta
		if _prompt_left <= 0.0:
			answer(false)


func accepted() -> Array:
	var out: Array = []
	for id in invited:
		if String(invited[id]) == "yes":
			out.append(String(id))
	return out


## Every member answered, and the ones who said yes stand in the war.
func _everyone_here() -> bool:
	for id in invited:
		var said := String(invited[id])
		if said == "wait":
			return false
		if said == "yes":
			var p: Variant = Online.players().get(id, {})
			if not (p is Dictionary) or StringName(String((p as Dictionary).get("zone", ""))) != WAR_ZONE:
				return false
	return true


## The leader: everybody's countdown starts now.
func start_war() -> void:
	if war == null or not is_instance_valid(war):
		war = null
		return
	var members := accepted()
	Online.send("gw_start", {"seed": war.roll_seed, "plan": {"ally": war.ally_name, "enemy": war.enemy_name, "time": war.time_left, "members": members}})
	war.hold = false
	war.zone.banner_requested.emit("สงครามกิลด์เริ่ม! สมาชิกปาร์ตี้ %d คนร่วมรบ" % members.size() if not members.is_empty() else "สงครามกิลด์เริ่ม!")
	war = null


func _leader() -> String:
	return String(Online.party().get("leader", ""))


func _on_message(type: String, data: Dictionary) -> void:
	var from := String(data.get("from", ""))
	match type:
		"gw_answer":
			if war != null and invited.has(from):
				invited[from] = "yes" if bool(data.get("ok", false)) else "no"
				var who: Variant = Online.players().get(from, {})
				var who_name := String((who as Dictionary).get("name", "")) if who is Dictionary else ""
				Game.say("%s %s" % [who_name, "ตอบรับ ไปสงครามด้วยกัน" if invited[from] == "yes" else "ไม่ไปสงคราม"], &"info")
		"gw_invite":
			if from != "" and from == _leader() and from != Online.my_id():
				_invited_by(from)
		"gw_start":
			if from == "" or from != _leader():
				return
			var plan: Dictionary = data.get("plan") if data.get("plan") is Dictionary else {}
			var mine: Array = plan.get("members", []) if plan.get("members") is Array else []
			if not mine.has(Online.my_id()):
				return
			var w := _my_war()
			if w != null and w.mirror:
				w.mirror_start(plan)
			else:
				_start = plan


func _my_war() -> GuildWarMatch:
	var w := GuildWarMatch.current
	return w if w != null and is_instance_valid(w) else null


## A member is asked into its leader's war: a prompt, unless it cannot go.
func _invited_by(from: String) -> void:
	var reason := ZoneData.access_reason(WAR_ZONE, int(Game.profile.get("level", 1)), int(Game.paragon().level)) if Game.has_profile else "ยังไม่มีตัวละคร"
	if reason == "" and Game.current_zone in [WAR_ZONE, &"pvp", &"tower"]:
		reason = "ติดภารกิจอื่นอยู่"
	if reason != "":
		Online.send("gw_answer", {"ok": false})
		Game.say("หัวหน้าปาร์ตี้ชวนไปสงครามกิลด์ แต่ไปไม่ได้: %s" % reason, &"warning")
		return
	_invite_from = from
	_show_prompt(from)


func _show_prompt(from: String) -> void:
	_close_prompt()
	var p: Variant = Online.players().get(from, {})
	var leader_name := String((p as Dictionary).get("name", (p as Dictionary).get("user", "หัวหน้าปาร์ตี้"))) if p is Dictionary else "หัวหน้าปาร์ตี้"
	prompt = CanvasLayer.new()
	prompt.name = "GuildWarInvite"
	prompt.layer = 95
	prompt.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(prompt)
	var box := UIUtil.panel(&"GlassPanel")
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box.offset_top = 90
	box.offset_left = -330
	box.offset_right = 330
	prompt.add_child(box)
	var column := UIUtil.vbox(12)
	box.add_child(column)
	var text := UIUtil.label("%s ชวนลงสงครามกิลด์ด้วยกัน\nสู้ฝั่งเดียวกับหัวหน้าปาร์ตี้ ไปด้วยไหม?" % leader_name, &"SubHeaderLabel", HORIZONTAL_ALIGNMENT_CENTER)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(text)
	var row := UIUtil.hbox(14)
	column.add_child(row)
	var yes := UIUtil.button("ไปด้วย!", &"PrimaryButton", Vector2(0, 64))
	yes.name = "Yes"
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.pressed.connect(answer.bind(true))
	row.add_child(yes)
	var no := UIUtil.button("ไม่ไป", &"", Vector2(0, 64))
	no.name = "No"
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.pressed.connect(answer.bind(false))
	row.add_child(no)
	_prompt_left = ANSWER_TIME
	AudioManager.play_ui(&"ui_open")


func _close_prompt() -> void:
	if prompt != null and is_instance_valid(prompt):
		prompt.queue_free()
	prompt = null


## The member's answer: yes goes to the war (its match mirrors the leader's).
func answer(ok: bool) -> void:
	if prompt == null and _invite_from == "":
		return
	_close_prompt()
	_invite_from = ""
	Online.send("gw_answer", {"ok": ok})
	if not ok:
		return
	_joining = true
	_joined_at = Time.get_ticks_msec()
	_start = {}
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("go"):
		if get_tree().paused:
			get_tree().paused = false
		scene.call("go", WAR_ZONE, false, true)
