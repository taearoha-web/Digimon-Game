extends Node3D
## "ตาม" (Online.set_follow): the hero walks after a real party member in the village,
## stops at a short gap, stops following when moved by hand or the party breaks, and
## the HUD card's button toggles it.
var checks := 0
var failures := 0
var zone: Zone
var hero: Hero

class FakeTransport:
	extends RefCounted
	var sent: Array[String] = []
	func send_text(text: String) -> void:
		sent.append(text)
	func poll() -> Array:
		return []
	func is_open() -> bool:
		return true
	func is_closed() -> bool:
		return false


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _player(id: String, name: String, zone_id: String, pos: Vector3) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var equip := {"weapon": ItemData.generate(30, &"warrior", rng, 2, "weapon")}
	var look := {"class": "warrior", "adv": 1, "face": FaceKit.default_look(), "equip": PlayerLook.wire_equip(equip), "wing_mode": 0, "level": 30, "stars": 0}
	return {"id": id, "user": "u_" + id, "name": name, "cls": "warrior", "level": 30, "stars": 0, "look": look, "zone": zone_id,
		"pos": [pos.x, pos.y, pos.z], "yaw": 0.0, "hp": 900, "max_hp": 1000, "mount": "", "party": null}


func _ready() -> void:
	InputSetup.ensure_defaults()
	Game.set_process(false)
	GameSettings.load_settings()
	GameSettings.online_play = true
	WorldPresence.enabled = false
	WorldPlayers.persist = false
	Online.set_process(false)
	Game.new_profile(&"mage", "ผู้ตาม", FaceKit.default_look())
	Game.playing = true
	zone = Zone.new()
	zone.zone_id = &"town"
	zone.layout_seed = 4242
	add_child(zone)
	if not zone.is_built:
		await zone.built
	hero = zone.hero
	var fake := FakeTransport.new()
	Online.use_transport(fake)
	var start := hero.global_position
	Online._dispatch({"t": "welcome", "you": {"id": "me", "user": "me"}, "party": null,
		"players": [_player("p2", "Leader", "town", start + Vector3(12, 0, 0))]})
	Online._dispatch({"t": "party", "party": {"id": "pt", "leader": "p2", "members": ["p2", "me"]}})
	Online._tick(0.016)
	check(Online.remote_node("p2") != null, "the party member stands in the village")
	Online.set_follow("p2")
	check(Online.follow_id == "p2", "following the member")
	for i in 30:
		Online._tick(0.016)
		await get_tree().physics_frame
	check(hero.follow == Online.remote_node("p2"), "the hero is told whom to follow")
	for i in 240:
		Online._tick(0.016)
		await get_tree().physics_frame
	var gap := Vector2(hero.global_position.x - Online.remote_node("p2").global_position.x, hero.global_position.z - Online.remote_node("p2").global_position.z).length()
	check(gap < Hero.FOLLOW_GAP + 1.5 and hero.global_position.distance_to(start) > 5.0, "the hero walked up to the member and stopped near them (gap %.1f m)" % gap)
	# The HUD card's button.
	var hud := HUD.new()
	add_child(hud)
	hud.bind(zone)
	hud._update_online_party()
	var card: Dictionary = hud._online_cards[0]
	check((card.card as Control).visible and (card.follow as Button).text == "หยุด", "the card shows หยุด while following")
	(card.follow as Button).pressed.emit()
	check(Online.follow_id == "" and hero.follow == null, "หยุด stops following")
	(card.follow as Button).pressed.emit()
	check(Online.follow_id == "p2" and (card.follow as Button).text == "หยุด", "ตาม starts it again")
	hud.queue_free()
	# Leaving the party stops it.
	Online._dispatch({"t": "party", "party": null})
	Online._tick(0.016)
	check(Online.follow_id == "" and hero.follow == null, "out of the party: no more following")
	# Moving by hand stops it.
	Online._dispatch({"t": "party", "party": {"id": "pt", "leader": "p2", "members": ["p2", "me"]}})
	Online.set_follow("p2")
	hero.move_input = Vector2(1, 0)
	for i in 5:
		await get_tree().physics_frame
	hero.move_input = Vector2.ZERO
	check(Online.follow_id == "", "walking by hand stops following")
	Online.use_transport(null)
	print("ONLINE FOLLOW: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
