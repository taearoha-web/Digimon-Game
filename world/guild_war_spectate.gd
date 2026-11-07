class_name GuildWarSpectate
extends Node
## Watching a live guild war (ชมสงครามกิลด์): a player who did not register for a league
## war, or came too late, opens the castle siege with both guilds played by the AI. The
## hero is out of the war (Hero.spectating: hidden, no body, never a target, never hurt)
## and the hero's HUD is hidden (no skill bar); this node is the watcher's own camera and
## board, a child of the war's zone (GuildWarMatch._build_spectate makes it).
##
## spectate(tree, match_info) travels there: match_info is GuildWarData.roll_guild_match's
## shape ({ally, enemy, ally_name, enemy_name, ally_power, enemy_power, guilds}) plus
## "elapsed" (seconds the war has run, 0..DURATION: the clock starts at what is left),
## "league_match" ([guild_a, guild_b], league ids or names) and "slot_start" (unix seconds);
## optional "ally_color" / "enemy_color". leave() goes back where the hero was, the same
## trip as leaving a war (Main.go). The end of a watched war pays nothing: its result goes
## to report() (GuildLeague.spectated_result when the league has it) and the board.
##
## The camera follows the action by itself (the altar while someone takes it, else the
## thickest fight) or one focus (the castle, side A, side B: the focus button cycles);
## drag / swipe pans it, pinch / the wheel / a trackpad zooms it, on a phone and a desktop.

signal focus_changed(index: int)

## The focus button's modes, in order.
const FOCUS_AUTO := 0
const FOCUS_CASTLE := 1
const FOCUS_A := 2
const FOCUS_B := 3
const FOCUS_COUNT := 4
const MIN_DISTANCE := 14.0
const MAX_DISTANCE := 85.0
const START_DISTANCE := 30.0
## Looking down at the field from the south (the castle is north, the camps east and west).
const PITCH_DEGREES := 56.0
const FOV := 50.0
## How often the followed point is looked for again (seconds).
const AUTO_EVERY := 0.5
## Fighters of both sides within this many metres of each other are one fight.
const FIGHT_RADIUS := 10.0
## After a drag the automatic camera stays where it was put this long, then drifts back.
const MANUAL_HOLD := 6.0
const ALLY_FALLBACK := Color("4a8cff")
const ENEMY_FALLBACK := Color("ff5a4a")
## Zones the hero is never sent back to (an instance that ended when it left).
const NO_RETURN: Array[StringName] = [&"guildwar", &"pvp", &"tower", &"raid", &"arena"]
const FEED_LINES := 4

## The war to open next (spectate -> Zone -> GuildWarMatch takes it once).
static var _pending: Dictionary = {}
## Where leave() takes the hero: the zone and the spot it watched from.
static var return_zone: StringName = &""
static var return_pos := Vector3.ZERO
static var _has_return_pos := false
## Tests: an object with spectated_result(match_info, result) to call instead of the league.
static var league_hook: Object = null
## The last watched war's result (tests, the board).
static var last_result: Dictionary = {}

var match_node: GuildWarMatch
var camera: Camera3D
var focus := FOCUS_AUTO
## The point on the ground the camera looks at (smoothed), the one it heads for, the
## player's drag on top of it and how far the camera stands back.
var center := Vector3.ZERO
var goal := Vector3.ZERO
var pan := Vector3.ZERO
var distance := START_DISTANCE
var _distance_goal := START_DISTANCE
var _manual_left := 0.0
var _auto_left := 0.0
var _touches := {}
var _pinch_from := 0.0
var _leaving := false

var _layer: CanvasLayer
var _names: Array[Label] = []
var _kills: Array[Label] = []
var _swatches: Array[ColorRect] = []
var _clock: Label
var _owner: Label
var _status: Label
var _banner: Label
var _hint: Label
var _feed: Label
var _feed_lines: Array[String] = []
var focus_button: Button
var leave_button: Button
var _result_box: Control
var _refresh := 0.0
var _banner_tween: Tween


# ---------------------------------------------------------------------------
# Going to a watched war and back
# ---------------------------------------------------------------------------

## Opens the war of `match_info` to watch (see the class notes). Returns once the arena is
## up (or at once when the game cannot travel now).
static func spectate(tree: SceneTree, match_info: Dictionary) -> void:
	if tree == null or match_info.is_empty():
		return
	var main := tree.get_first_node_in_group(&"game_main")
	if main == null or bool(main.get("_traveling")):
		return
	var here := Game.current_zone
	return_zone = &"town" if here == &"" or here in NO_RETURN else here
	_has_return_pos = false
	var z: Variant = main.get("zone")
	if return_zone == here and z is Zone and is_instance_valid((z as Zone).hero):
		return_pos = (z as Zone).hero.global_position
		_has_return_pos = true
	_pending = match_info.duplicate(true)
	await main.go(&"guildwar", false, true)
	_pending = {}


## The war to watch, once (Zone hands it to its GuildWarMatch); {} for a war to fight.
static func take_pending() -> Dictionary:
	var out := _pending
	_pending = {}
	return out


static func is_pending() -> bool:
	return not _pending.is_empty()


## Stops watching: back to the zone (and the spot) the hero watched from, the same trip
## as leaving a war (Main.go).
static func leave(tree: SceneTree) -> void:
	var main := tree.get_first_node_in_group(&"game_main") if tree != null else null
	if main == null or bool(main.get("_traveling")):
		return
	var to := return_zone if return_zone != &"" else &"town"
	var pos := return_pos
	var has_pos := _has_return_pos
	return_zone = &""
	_has_return_pos = false
	await main.go(to, false, true)
	var z: Variant = main.get("zone")
	if has_pos and z is Zone and (z as Zone).zone_id == to and is_instance_valid((z as Zone).hero):
		var hero := (z as Zone).hero
		hero.global_position = pos
		hero.velocity = Vector3.ZERO
		if (z as Zone).camera_rig != null:
			(z as Zone).camera_rig.snap_to_target()


## The watched war ended: kept in last_result and handed to the league's hook
## (GuildLeague.spectated_result(match_info, result)) only when it has one.
static func report(match_info: Dictionary, result: Dictionary) -> void:
	last_result = result
	if league_hook != null:
		if league_hook.has_method("spectated_result"):
			league_hook.call("spectated_result", match_info, result)
		return
	if script_has(GuildLeague, "spectated_result"):
		var league: Script = GuildLeague
		league.call("spectated_result", match_info, result)


## True when `script` (a class_name's script) declares `method` (static or not): the
## league's hooks are called only when the league has them.
static func script_has(script: Script, method: String) -> bool:
	if script == null:
		return false
	for m in script.get_script_method_list():
		if String(m.get("name", "")) == method:
			return true
	return false


## A league call when the league has that method (null otherwise).
static func _league(method: String, args: Array = []) -> Variant:
	if not script_has(GuildLeague, method):
		return null
	var league: Script = GuildLeague
	return league.callv(method, args)


## A side's colour: the match_info's own ("ally_color" / "enemy_color"), else the league
## guild's (league_match ids or names, else the side's name), else blue / red.
static func side_color(info: Dictionary, team: int) -> Color:
	var key := "ally_color" if team == GuildFighter.TEAM_ALLY else "enemy_color"
	if info.get(key) is Color:
		return info[key]
	var wanted: Array = []
	var pair: Variant = info.get("league_match", [])
	if pair is Array and (pair as Array).size() == 2:
		wanted.append(pair[team])
	wanted.append(String(info.get("ally_name" if team == GuildFighter.TEAM_ALLY else "enemy_name", "")))
	var ids: Variant = _league("ids")
	for g in wanted:
		if typeof(g) == TYPE_INT or typeof(g) == TYPE_FLOAT:
			var c: Variant = _league("color_of", [int(g)])
			if c is Color and c != Color.WHITE:
				return c
		elif String(g) != "" and ids is Array:
			for id in ids:
				if String(_league("name_of", [int(id)])) == String(g):
					var c: Variant = _league("color_of", [int(id)])
					if c is Color:
						return c
	return ALLY_FALLBACK if team == GuildFighter.TEAM_ALLY else ENEMY_FALLBACK


## Two hired guilds of `per_side` fighters each, in roll_guild_match's shape (tests, tools
## and a preview when no league war is on): random classes, grades from the 100-star set up.
static func demo_match(rng: RandomNumberGenerator, per_side := 20, names: Array = ["Alpha", "Neverdie"]) -> Dictionary:
	var classes: Array = StarGearData.CLASSES.duplicate()
	var sides: Array = [[], []]
	var power := [0.0, 0.0]
	var used := {}
	for team in 2:
		for i in per_side:
			var cls := StringName(classes[(i + team * 3) % classes.size()])
			var grade: int = GuildWarData.GRADES[1 + rng.randi() % (GuildWarData.GRADES.size() - 1)]
			var name: String = PvpData.NAMES[rng.randi() % PvpData.NAMES.size()]
			while used.has(name):
				name = "%s%d" % [PvpData.NAMES[rng.randi() % PvpData.NAMES.size()], used.size()]
			used[name] = true
			var f := GuildWarData.make_fighter(cls, grade, name, rng)
			sides[team].append(f)
			power[team] += float(f.power)
	return {"ally": sides[0], "enemy": sides[1], "ally_name": String(names[0]), "enemy_name": String(names[1]),
		"ally_power": power[0], "enemy_power": power[1], "guilds": true}


# ---------------------------------------------------------------------------
# The watcher's camera
# ---------------------------------------------------------------------------

func setup(m: GuildWarMatch) -> void:
	match_node = m


func _ready() -> void:
	var zone := match_node.zone as Zone
	# The hero's camera rests; this one is the eye (the war's distance LOD reads it).
	if zone != null and zone.camera_rig != null:
		zone.camera_rig.process_mode = Node.PROCESS_MODE_DISABLED
		if zone.camera_rig.camera != null:
			zone.camera_rig.camera.current = false
	camera = Camera3D.new()
	camera.name = "SpectatorCamera"
	camera.fov = FOV
	camera.near = 0.3
	camera.far = 260.0
	add_child(camera)
	camera.current = true
	goal = _point_for(focus)
	center = goal
	_place_camera()
	_build_board()
	match_node.feed.connect(_on_feed)
	match_node.finished.connect(_show_result)
	if zone != null:
		zone.banner_requested.connect(show_banner)


func _process(delta: float) -> void:
	if match_node == null or not is_instance_valid(match_node):
		return
	_auto_left -= delta
	_manual_left = maxf(0.0, _manual_left - delta)
	if _auto_left <= 0.0:
		_auto_left = AUTO_EVERY
		# The automatic camera holds still while the player has just moved it.
		if focus != FOCUS_AUTO or _manual_left <= 0.0:
			goal = _point_for(focus)
	if focus == FOCUS_AUTO and _manual_left <= 0.0:
		pan = pan.lerp(Vector3.ZERO, 1.0 - exp(-delta * 1.2))
	var want := _clamp_field(goal + pan)
	center = center.lerp(want, 1.0 - exp(-delta * 2.6))
	distance = lerpf(distance, _distance_goal, 1.0 - exp(-delta * 8.0))
	_place_camera()
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.2
		_update_board()


func _place_camera() -> void:
	if camera == null:
		return
	var pitch := deg_to_rad(PITCH_DEGREES)
	camera.global_position = center + Vector3(0, sin(pitch), cos(pitch)) * distance
	camera.look_at(center, Vector3.UP)


static func _clamp_field(p: Vector3) -> Vector3:
	var flat := Vector2(p.x, p.z)
	var limit := SiegeArena.RADIUS - 8.0
	if flat.length() > limit:
		flat = flat.normalized() * limit
	return Vector3(flat.x, 0.0, flat.y)


## The ground point at the middle of the view (the war's draw LOD measures from it).
func view_center() -> Vector3:
	return center


## How far from view_center() a fighter may still be on screen.
func view_radius() -> float:
	var size := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(16, 9)
	var aspect := size.x / maxf(1.0, size.y)
	return distance * tan(deg_to_rad(FOV) * 0.5) * maxf(1.0, aspect) * 1.25 + 6.0


## Where a focus looks: the action (auto), the castle (the front gate, then the altar),
## or one side (its leader, else the middle of its living fighters).
func _point_for(mode: int) -> Vector3:
	var m := match_node
	match mode:
		FOCUS_CASTLE:
			return _castle_point()
		FOCUS_A, FOCUS_B:
			var team := GuildFighter.TEAM_ALLY if mode == FOCUS_A else GuildFighter.TEAM_ENEMY
			var lead := m.ai_leader(team)
			if lead != null and not lead.is_dead():
				return _flat(lead.global_position)
			return _middle(m.allies if team == GuildFighter.TEAM_ALLY else m.enemies, _castle_point())
	return action_point()


func _castle_point() -> Vector3:
	var gate := match_node.front_gate()
	if gate != null and match_node.capture.is_empty():
		return _flat(gate.global_position) + Vector3(0, 0, 7.0)
	return SiegeArena.ALTAR + Vector3(0, 0, 4.0)


## The automatic camera's point: whoever is taking the altar, else the thickest fight
## (the fighter with the most of the other side close by, and the middle of everyone
## round it), else the front gate / the altar.
func action_point() -> Vector3:
	var m := match_node
	var who := m.capturer()
	if who != null and is_instance_valid(who):
		return _flat(who.global_position)
	var alive: Array[GuildFighter] = []
	for f in m.all_fighters():
		if is_instance_valid(f) and not f.is_dead():
			alive.append(f)
	var r2 := FIGHT_RADIUS * FIGHT_RADIUS
	var best: GuildFighter = null
	var best_score := 0.0
	for f in alive:
		var foes := 0
		var friends := 0
		for g in alive:
			if g == f or f.global_position.distance_squared_to(g.global_position) > r2:
				continue
			if g.team == f.team:
				friends += 1
			else:
				foes += 1
		var score := float(foes) + 0.35 * float(friends) if foes > 0 else 0.0
		if score > best_score:
			best_score = score
			best = f
	if best == null:
		return _middle(alive, _castle_point()) if not alive.is_empty() else _castle_point()
	var near: Array[GuildFighter] = []
	for g in alive:
		if best.global_position.distance_squared_to(g.global_position) <= r2:
			near.append(g)
	return _middle(near, _flat(best.global_position))


static func _middle(list: Array, fallback: Vector3) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for f in list:
		if is_instance_valid(f) and not f.is_dead():
			sum += f.global_position
			n += 1
	return _flat(sum / float(n)) if n > 0 else fallback


static func _flat(p: Vector3) -> Vector3:
	return Vector3(p.x, 0.0, p.z)


## The focus button: auto -> castle -> side A -> side B -> auto. The drag is dropped.
func cycle_focus() -> int:
	focus = (focus + 1) % FOCUS_COUNT
	pan = Vector3.ZERO
	_manual_left = 0.0
	_auto_left = AUTO_EVERY
	goal = _point_for(focus)
	_update_focus_button()
	focus_changed.emit(focus)
	return focus


func focus_name(mode := -1) -> String:
	var which := focus if mode < 0 else mode
	match which:
		FOCUS_CASTLE:
			return "ปราสาท"
		FOCUS_A:
			return "กิลด์ %s" % match_node.ally_name
		FOCUS_B:
			return "กิลด์ %s" % match_node.enemy_name
	return "ติดตามการรบ"


## Moves the view by a drag of `pixels` on the screen (the field follows the finger).
func pan_by(pixels: Vector2) -> void:
	if camera == null:
		return
	var height := maxf(1.0, get_viewport().get_visible_rect().size.y)
	var per_pixel := 2.0 * distance * tan(deg_to_rad(FOV) * 0.5) / height
	var right := camera.global_basis.x
	right.y = 0.0
	var ahead := -camera.global_basis.z
	ahead.y = 0.0
	right = right.normalized()
	ahead = ahead.normalized()
	pan += (-right * pixels.x + ahead * pixels.y / sin(deg_to_rad(PITCH_DEGREES))) * per_pixel
	# Never farther from the followed point than the field allows.
	pan = _clamp_field(goal + pan) - goal
	_manual_left = MANUAL_HOLD
	if _hint != null:
		_hint.visible = false


## Zooms by `factor` (above 1 closer, below 1 farther).
func zoom_by(factor: float) -> void:
	if factor <= 0.0:
		return
	_distance_goal = clampf(_distance_goal / factor, MIN_DISTANCE, MAX_DISTANCE)


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or camera == null:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_touches[touch.index] = touch.position
		else:
			_touches.erase(touch.index)
		_pinch_from = _pinch_span()
		return
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_touches[drag.index] = drag.position
		if _touches.size() >= 2:
			var span := _pinch_span()
			if _pinch_from > 1.0 and span > 1.0:
				zoom_by(span / _pinch_from)
			_pinch_from = span
		else:
			pan_by(drag.relative)
		get_viewport().set_input_as_handled()
		return
	# A phone's touches also arrive as emulated mouse events: those are the touches above.
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if motion.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE):
			pan_by(motion.relative)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_by(1.12)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by(1.0 / 1.12)
	elif event is InputEventMagnifyGesture:
		zoom_by((event as InputEventMagnifyGesture).factor)
	elif event is InputEventPanGesture:
		pan_by(-(event as InputEventPanGesture).delta * 12.0)


func _pinch_span() -> float:
	if _touches.size() < 2:
		return 0.0
	var points: Array = _touches.values()
	return (points[0] as Vector2).distance_to(points[1] as Vector2)


# ---------------------------------------------------------------------------
# The watcher's board
# ---------------------------------------------------------------------------

func _build_board() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "SpectateBoard"
	_layer.layer = 12
	add_child(_layer)
	var safe := SafeAreaContainer.new()
	_layer.add_child(safe)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(root)
	# The top centre: both guilds (colour, name, falls), the clock, the castle.
	var top := UIUtil.vbox(4)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.anchor_left = 0.5
	top.anchor_right = 0.5
	top.offset_left = -330
	top.offset_right = 330
	top.offset_top = 4
	root.add_child(top)
	var board := UIUtil.panel(&"HudPanel")
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(board)
	var lines := UIUtil.vbox(2)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(lines)
	var row := UIUtil.hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(row)
	for team in 2:
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(14, 30)
		swatch.color = match_node.team_color(team)
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_swatches.append(swatch)
		var name_label := _outlined(UIUtil.label(match_node.team_name(team), &"HeaderLabel", HORIZONTAL_ALIGNMENT_RIGHT if team == 0 else HORIZONTAL_ALIGNMENT_LEFT))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		name_label.add_theme_color_override("font_color", match_node.team_color(team).lerp(Color.WHITE, 0.25))
		_names.append(name_label)
		var kills := _outlined(UIUtil.label("0", &"TitleLabel", HORIZONTAL_ALIGNMENT_CENTER))
		kills.custom_minimum_size = Vector2(54, 0)
		kills.add_theme_font_size_override("font_size", 34)
		_kills.append(kills)
	_clock = _outlined(UIUtil.label("", &"HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER))
	_clock.custom_minimum_size = Vector2(96, 0)
	for node in [_swatches[0], _names[0], _kills[0], _clock, _kills[1], _names[1], _swatches[1]]:
		row.add_child(node)
	_owner = _outlined(UIUtil.label("", &"BoldLabel", HORIZONTAL_ALIGNMENT_CENTER))
	lines.add_child(_owner)
	_status = _outlined(UIUtil.label("", &"SmallLabel", HORIZONTAL_ALIGNMENT_CENTER))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lines.add_child(_status)
	# Top left: the "live" badge.
	var live := UIUtil.chip("● ถ่ายทอดสด · กำลังชม", Color("ff5a5a"), 18)
	live.mouse_filter = Control.MOUSE_FILTER_IGNORE
	live.position = Vector2(4, 8)
	root.add_child(live)
	# The middle: banners; under it, how to move the camera (until the first drag).
	_banner = _outlined(UIUtil.label("", &"TitleLabel", HORIZONTAL_ALIGNMENT_CENTER))
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.offset_top = -120
	_banner.add_theme_font_size_override("font_size", 40)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.modulate.a = 0.0
	root.add_child(_banner)
	_hint = _outlined(UIUtil.label("ลากเพื่อเลื่อนกล้อง · บีบนิ้วหรือหมุนล้อเมาส์เพื่อซูม", &"SmallLabel", HORIZONTAL_ALIGNMENT_CENTER))
	_hint.anchor_left = 0.5
	_hint.anchor_right = 0.5
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = -300
	_hint.offset_right = 300
	_hint.offset_top = -120
	_hint.offset_bottom = -92
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hint)
	# The war's news, small, bottom centre.
	_feed = _outlined(UIUtil.label("", &"SmallLabel", HORIZONTAL_ALIGNMENT_CENTER))
	_feed.anchor_left = 0.5
	_feed.anchor_right = 0.5
	_feed.anchor_top = 1.0
	_feed.anchor_bottom = 1.0
	_feed.offset_left = -290
	_feed.offset_right = 290
	_feed.offset_top = -88
	_feed.offset_bottom = -4
	_feed.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_feed.clip_text = true
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_feed)
	# Bottom left: leave; bottom right: the camera's focus.
	leave_button = UIUtil.button("ออกจากการชม", &"", Vector2(220, 64))
	leave_button.name = "LeaveButton"
	leave_button.anchor_top = 1.0
	leave_button.anchor_bottom = 1.0
	leave_button.offset_left = 4
	leave_button.offset_top = -68
	leave_button.offset_bottom = -4
	leave_button.offset_right = 224
	leave_button.pressed.connect(press_leave)
	root.add_child(leave_button)
	focus_button = UIUtil.button("", &"PrimaryButton", Vector2(260, 64))
	focus_button.name = "FocusButton"
	focus_button.anchor_left = 1.0
	focus_button.anchor_right = 1.0
	focus_button.anchor_top = 1.0
	focus_button.anchor_bottom = 1.0
	focus_button.offset_left = -264
	focus_button.offset_right = -4
	focus_button.offset_top = -68
	focus_button.offset_bottom = -4
	focus_button.pressed.connect(cycle_focus)
	root.add_child(focus_button)
	_update_focus_button()
	_update_board()


static func _outlined(label: Label) -> Label:
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	return label


func _update_focus_button() -> void:
	if focus_button != null:
		focus_button.text = "กล้อง: %s" % focus_name()


func _update_board() -> void:
	var m := match_node
	if _clock == null or m == null:
		return
	for team in 2:
		_kills[team].text = str(m.score[team])
	_clock.text = clock_text()
	_owner.text = m.owner_line()
	_owner.add_theme_color_override("font_color", m.owner_color().lerp(Color.WHITE, 0.2) if m.castle_owner >= 0 else Color("fff1b8"))
	var capture := m.capture_line()
	_status.text = capture if capture != "" and not m.capture.is_empty() else m.siege_status()


## The clock as the board shows it: what is left of the war (m:ss), ต่อเวลา in sudden death.
func clock_text() -> String:
	var m := match_node
	if m.overtime:
		return "ต่อเวลา"
	if m.state == "intro":
		return "เริ่มใน %d" % maxi(1, ceili(m._timer))
	var left := maxi(0, ceili(m.time_left))
	return "%d:%02d" % [left / 60, left % 60]


func show_banner(text: String) -> void:
	if _banner == null:
		return
	_banner.text = text
	_banner.modulate.a = 1.0
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_interval(2.0)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.6)


func _on_feed(text: String, _team: int) -> void:
	_feed_lines.append(text)
	while _feed_lines.size() > FEED_LINES:
		_feed_lines.pop_front()
	if _feed != null:
		_feed.text = "\n".join(_feed_lines)


func press_leave() -> void:
	if _leaving:
		return
	_leaving = true
	if leave_button != null:
		leave_button.disabled = true
	GuildWarSpectate.leave(get_tree())


## The bell: who won and the score, with the leave button (watching pays nothing).
func _show_result(result: Dictionary) -> void:
	if _layer == null or _result_box != null:
		return
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.06, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(dim)
	_result_box = dim
	var panel := UIUtil.panel(&"GlassPanel")
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(620, 0)
	dim.add_child(panel)
	var column := UIUtil.vbox(12)
	panel.add_child(column)
	var winner := int(result.get("winner", -1))
	var heading := _outlined(UIUtil.label(("กิลด์ %s ชนะ!" % String(result.get("winner_name", ""))) if winner >= 0 else "เสมอ", &"TitleLabel", HORIZONTAL_ALIGNMENT_CENTER))
	heading.add_theme_font_size_override("font_size", 52)
	heading.add_theme_color_override("font_color", match_node.team_color(winner).lerp(Color.WHITE, 0.2) if winner >= 0 else Color("fff1b8"))
	column.add_child(heading)
	var score: Array = result.get("score", [0, 0])
	column.add_child(UIUtil.label("%s  %d  :  %d  %s%s" % [match_node.ally_name, int(score[0]), int(score[1]), match_node.enemy_name, "  (ต่อเวลา)" if bool(result.get("overtime", false)) else ""], &"HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER))
	var castle := String(result.get("castle", ""))
	column.add_child(UIUtil.label("ปราสาทเป็นของกิลด์ %s" % castle if castle != "" else "ไม่มีกิลด์ไหนยึดปราสาทได้ — ตัดสินจากจำนวนที่ล้มได้", &"SubHeaderLabel", HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(UIUtil.label("การชมสงครามไม่มีรางวัล", &"SmallLabel", HORIZONTAL_ALIGNMENT_CENTER))
	var buttons := UIUtil.hbox(16)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)
	var stay := UIUtil.button("ดูสนามต่อ", &"", Vector2(220, 68))
	stay.pressed.connect(func():
		dim.visible = false)
	buttons.add_child(stay)
	var out := UIUtil.button("ออกจากการชม", &"PrimaryButton", Vector2(260, 68))
	out.name = "ResultLeaveButton"
	out.pressed.connect(press_leave)
	buttons.add_child(out)


func result_shown() -> bool:
	return _result_box != null
