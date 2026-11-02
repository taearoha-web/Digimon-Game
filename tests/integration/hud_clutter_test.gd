extends Node3D
## A party fight must stay readable on a phone: damage numbers on one target fan out
## instead of piling into one blob, the party's numbers are smaller and dimmer than the
## hero's own and capped, party name labels fade while they fight, the hero has its gold
## ring, and the world chat never says the same line twice within the repeat window.
## godot --headless --path . res://tests/integration/hud_clutter_test.tscn
var failures: Array[String] = []
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)


func _ready() -> void:
	await get_tree().process_frame
	InputSetup.ensure_defaults()
	Game.set_process(false)
	GameSettings.load_settings()
	BattleVfx.text_scale = 1.8
	_numbers()
	await _party()
	_chat()
	BattleVfx.clock_override = -1.0
	WorldPresence.chat_clock_override = -1.0
	print("HUD CLUTTER: %d checks, %d failures" % [checks, failures.size()])
	if failures.is_empty():
		print("PASS")
	get_tree().quit(1 if failures.size() > 0 else 0)


func _numbers() -> void:
	var holder := Node3D.new()
	add_child(holder)
	var cam := Camera3D.new()
	holder.add_child(cam)
	cam.position = Vector3(0, 8, 12)
	cam.look_at(Vector3.ZERO)
	cam.current = true
	BattleVfx.clock_override = 100.0
	var spot := Vector3(0, 2, 0)
	var labels: Array[Label3D] = []
	for i in 5:
		labels.append(BattleVfx.damage_number(holder, spot, str(390 + i), false))
		BattleVfx.clock_override += 0.05
	var closest := INF
	for a in labels.size():
		for b in range(a + 1, labels.size()):
			closest = minf(closest, labels[a].global_position.distance_to(labels[b].global_position))
	check(closest > 0.4, "five numbers on one target fan out (closest pair %.2f m apart)" % closest)
	# Later, after the window, a number starts at the target again.
	BattleVfx.clock_override += 5.0
	var alone := BattleVfx.damage_number(holder, spot, "12", false)
	check(alone.global_position.distance_to(spot) < 0.2, "a lone number later starts on the target (%.2f m)" % alone.global_position.distance_to(spot))
	# Others' numbers: smaller and dimmer; the hero's crits bigger and gold.
	BattleVfx.clock_override += 5.0
	var own := BattleVfx.damage_number(holder, Vector3(20, 2, 0), "400", false)
	var other := BattleVfx.damage_number(holder, Vector3(30, 2, 0), "400", false, 1.0, true)
	var crit := BattleVfx.damage_number(holder, Vector3(40, 2, 0), "400!", false, 1.35)
	check(other.pixel_size < own.pixel_size * 0.8, "a party member's number is smaller than the hero's (%.4f < %.4f)" % [other.pixel_size, own.pixel_size])
	check(other.modulate.a < own.modulate.a, "and dimmer (%.2f < %.2f)" % [other.modulate.a, own.modulate.a])
	check(crit.pixel_size > own.pixel_size * 1.3 and crit.modulate.is_equal_approx(BattleVfx.CRIT_COLOR), "the hero's crit is bigger and gold")
	check(own.render_priority > other.render_priority, "the hero's numbers draw over others'")
	BattleVfx.dealing_other = true
	var flagged := BattleVfx.damage_number(holder, Vector3(50, 2, 0), "77", false)
	BattleVfx.dealing_other = false
	check(flagged.has_meta(&"other"), "a hit while dealing_other is drawn as someone else's")
	# The cap: never more than OTHERS_CAP of others' numbers at once.
	for i in 25:
		BattleVfx.damage_number(holder, Vector3(i * 0.3, 2, 5), str(i), false, 1.0, true)
	var alive := 0
	for l in holder.get_children():
		if l is Label3D and l.has_meta(&"other") and not l.is_queued_for_deletion():
			alive += 1
	check(alive <= BattleVfx.OTHERS_CAP, "others' numbers are capped (%d alive)" % alive)
	# The hero's own are always shown, however many texts are up.
	BattleVfx._floating_active = 60
	var shown := 0
	for i in 12:
		if BattleVfx.damage_number(holder, Vector3(i, 2, -5), str(i), false) != null:
			shown += 1
	check(shown == 12, "the hero's own numbers are never dropped (%d/12)" % shown)
	BattleVfx._floating_active = 0
	holder.queue_free()


func _party() -> void:
	Game.new_profile(&"mage", "Clutter QA", {"gender": 0})
	Game.profile.level = 30
	var field := Node3D.new()
	add_child(field)
	var hero := Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	await get_tree().process_frame
	var ring := hero.get_node_or_null("SelfRing") as MeshInstance3D
	check(ring != null and ring.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "the hero has its gold ring, without a shadow")
	var mob := Mob.new()
	mob.setup(&"pink_slime", 1, Vector3(3, 0, 0), hero)
	field.add_child(mob)
	mob.position = Vector3(3, 0, 0)
	mob.hp = 1000000
	mob.max_hp = 1000000
	mob.set_physics_process(false)
	var c := Companion.new()
	c.setup({"class": "mage", "name": "QA mage", "level": 30, "exp": 0, "gender": 0}, 0, hero, field)
	field.add_child(c)
	c.position = Vector3(-2, 0, 1)
	c.set_physics_process(false)
	await get_tree().process_frame
	# Its hit is drawn as someone else's; the hero's own hit is not.
	c._deal(mob, 1.0, Color.WHITE, &"", false, null)
	check(not BattleVfx.dealing_other, "dealing_other is reset after a party member's hit")
	var tagged := field.get_children().filter(func(n): return n is Label3D and n.has_meta(&"other"))
	check(tagged.size() >= 1, "a party member's hit shows as someone else's number")
	var before := tagged.size()
	mob.take_hit(50, false)
	tagged = field.get_children().filter(func(n): return n is Label3D and n.has_meta(&"other"))
	check(tagged.size() == before, "the hero's own hit is drawn as the hero's")
	# The label fades in a fight and comes back when calm.
	c.target = mob
	for i in 10:
		c.fade_label(0.1)
	check(c._label.modulate.a < 0.4, "a fighting party member's label fades (%.2f)" % c._label.modulate.a)
	c.target = null
	c._since_hurt = 0.5
	c.fade_label(0.1)
	check(c._label.modulate.a < 0.5, "it stays faded right after being hit (%.2f)" % c._label.modulate.a)
	c._since_hurt = 99.0
	for i in 10:
		c.fade_label(0.1)
	check(is_equal_approx(c._label.modulate.a, 1.0), "and is full again when calm (%.2f)" % c._label.modulate.a)
	field.queue_free()
	await get_tree().process_frame


func _chat() -> void:
	WorldPresence._said.clear()
	WorldPresence.chat_clock_override = 5000.0
	var presence := WorldPresence.new()
	presence._online = [{"name": "ผู้เล่นA", "index": 1, "guild": 0, "level": 6, "place": &"meadow"},
		{"name": "ผู้เล่นB", "index": 2, "guild": 0, "level": 8, "place": &"meadow"}]
	var said: Array[String] = []
	var record := func(_speaker: String, text: String, _color: Color): said.append(text)
	Game.world_chat.connect(record)
	for i in 30:
		presence.chat_once()
		WorldPresence.chat_clock_override += 7.0
	var unique := {}
	for t in said:
		unique[t] = true
	check(said.size() >= 8, "the chat keeps talking (%d lines in 30 turns)" % said.size())
	check(unique.size() == said.size(), "no line is said twice within %d s (%d lines, %d different)" % [int(WorldPresence.REPEAT_WINDOW), said.size(), unique.size()])
	# After the window a line may come back.
	WorldPresence.chat_clock_override += WorldPresence.REPEAT_WINDOW + 1.0
	said.clear()
	for i in 10:
		presence.chat_once()
		WorldPresence.chat_clock_override += 7.0
	check(said.size() >= 5, "after the window the lines come back (%d)" % said.size())
	Game.world_chat.disconnect(record)
	presence.free()
	# A field speaker never says a village-only line.
	var village := 0
	for seed_value in 400:
		var line := WorldChat.line_for({"level": 6, "place": &"meadow"}, seed_value)
		if line.contains("หมู่บ้าน"):
			village += 1
	check(village == 0, "a low-level player in a field never talks about the village (%d)" % village)
