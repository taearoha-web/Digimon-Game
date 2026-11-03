extends Node
## Dev tool: online play without a server. Starts the real game in the village, hands
## Online a loopback transport (what the game sends is printed) and plays a second, fake
## player: a world player's look (PlayerLook.of_member, so it wears real gear, wings and
## a mount) arriving with a welcome, walking circles around the hero, riding now and
## then, chatting on the world, party and whisper channels and inviting the hero into a
## party. Watch the RemotePlayer, the chat's "ผู้เล่นจริง" lines, the invite card and the
## real party card on the HUD.
##   godot --path . res://tests/tools/online_loopback.tscn
##   godot --path . res://tests/tools/online_loopback.tscn -- shot=/tmp/online.png
## With shot=<png> the fake player stands beside the hero, one picture is saved and the
## tool quits.

const FAKE_ID := "loop2"
const RADIUS := 4.0
const STEP := 0.15
const LINES := [["world", "สวัสดีทุกคน ผู้เล่นจริงมาแล้ว"], ["whisper", "ไปล่ามอนด้วยกันไหม"], ["party", "ตามมาทางนี้เลย"],
	["world", "ใครไปทุ่งหญ้าบ้าง"], ["party", "ยาเลือดใกล้หมดแล้ว"]]

@export var shot_path := ""

var main: Node
var loop := Loopback.new()
var hero: Hero
var _t := 0.0
var _send_in := 0.0
var _talk_in := 3.0
var _line := 0
var _ready_to_play := false
var _invited := false
## The fake player's own mount (WorldPlayers.mount_of), ridden a third of the time.
var _mount_id := ""


class Loopback:
	extends RefCounted
	var quiet := false

	func send_text(text: String) -> void:
		if not quiet and not text.contains("\"t\":\"state\""):
			print("[online →] ", text.left(160))

	func poll() -> Array:
		return []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("shot="):
			shot_path = arg.substr(5)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(0.5).timeout
	Game.new_profile(&"mage", "ลูน่า", FaceKit.default_look())
	Game.profile["level"] = 41
	Game.profile["adv"] = JobData.adv_for_level(41)
	Game.fill_loadout()
	main.title_screen.queue_free()
	main.title_screen = null
	main.hud.visible = true
	Game.playing = true
	await main.go(&"town", true)
	await get_tree().create_timer(1.0).timeout
	hero = main.zone.hero
	loop.quiet = shot_path != ""
	Online.use_transport(loop)
	Online._dispatch({"t": "welcome", "you": {"id": "me", "user": "luna"}, "party": null, "players": [_fake_player()]})
	_ready_to_play = true
	if shot_path != "":
		await _shot()


## A world player well into the game (gear, wings, a mount), as a real player's hello.
func _fake_player() -> Dictionary:
	var when := WorldPlayers.START_UNIX + 200.0 * 86400.0
	var pick := 0
	for i in WorldPlayers.size():
		var m := WorldPlayers.member(i, when)
		if int(m.level) >= 100 and not WorldPlayers.mount_of(m).is_empty():
			pick = i
			break
	var member := WorldPlayers.member(pick, when)
	var look := PlayerLook.of_member(member, pick)
	var at := hero.global_position + Vector3(RADIUS, 0, 0)
	_mount_id = String(WorldPlayers.mount_of(member).get("id", ""))
	return {"id": FAKE_ID, "user": "tester", "name": String(member.name), "cls": String(member["class"]), "level": int(member.level),
		"stars": int(look.stars), "look": look, "zone": String(main.zone.zone_id), "pos": [at.x, at.y, at.z], "yaw": 0.0,
		"hp": 5000, "max_hp": 5000, "mount": "", "party": null}


func _process(delta: float) -> void:
	if not _ready_to_play or shot_path != "" or hero == null or not is_instance_valid(hero):
		return
	_t += delta
	_send_in -= delta
	if _send_in <= 0.0:
		_send_in = STEP
		var a := _t * 0.5
		var at := hero.global_position + Vector3(cos(a), 0, sin(a)) * RADIUS
		var riding := fmod(_t, 30.0) > 20.0
		var mount := _mount_id
		Online._dispatch({"t": "state", "id": FAKE_ID, "pos": [at.x, at.y, at.z], "yaw": a + PI, "anim": "run", "hp": 5000, "max_hp": 5000,
			"zone": String(main.zone.zone_id), "mount": mount if riding else ""})
	_talk_in -= delta
	if _talk_in <= 0.0:
		_talk_in = 6.0
		var entry: Array = LINES[_line % LINES.size()]
		_line += 1
		Online._dispatch({"t": "chat", "ch": entry[0], "from": FAKE_ID, "user": "tester", "name": Online.display_name(Online.player(FAKE_ID)),
			"text": entry[1], "to": "me"})
		if not _invited and _line == 2:
			_invited = true
			Online._dispatch({"t": "party_invite", "from": FAKE_ID, "name": Online.display_name(Online.player(FAKE_ID))})
	# Accepting the invite on the card: the fake server makes the party.
	if _invited and not Online.in_party() and Online.pending_invite().is_empty() and main.online_prompt != null and not main.online_prompt.is_showing():
		Online._dispatch({"t": "party", "party": {"id": "loop_party", "leader": FAKE_ID, "members": [FAKE_ID, "me"]}})
		Online._dispatch({"t": "host", "zone": String(main.zone.zone_id), "id": FAKE_ID})


## The fake player beside the hero, one picture, then quit.
func _shot() -> void:
	var cam := main.zone.camera_rig as ThirdPersonCamera
	var side := Vector3(cos(hero.facing()), 0, -sin(hero.facing()))
	var at := hero.global_position + side * 1.9
	Online._dispatch({"t": "state", "id": FAKE_ID, "pos": [at.x, at.y, at.z], "yaw": hero.facing(), "anim": "idle", "hp": 4200, "max_hp": 5000,
		"zone": String(main.zone.zone_id), "mount": ""})
	Online._dispatch({"t": "chat", "ch": "world", "from": FAKE_ID, "user": "tester", "name": Online.display_name(Online.player(FAKE_ID)), "text": "สวัสดีทุกคน ผู้เล่นจริงมาแล้ว"})
	Online._dispatch({"t": "party", "party": {"id": "loop_party", "leader": "me", "members": ["me", FAKE_ID]}})
	if cam != null:
		cam.distance = 6.5
		cam.snap_to_target()
	await get_tree().create_timer(5.0).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(shot_path.get_base_dir())
	img.save_png(shot_path)
	print("saved ", shot_path)
	get_tree().quit()
