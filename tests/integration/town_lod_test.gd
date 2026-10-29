extends Node
## The village's players on a phone budget: every other player wears the cheap
## enhancement dressing (at most one particle emitter, no flames, beams or lights), far
## players stop their emitters, cast no shadow and still animate (the manual animation
## steps run), the party keeps the full dressing, and the arrivals of a sync come one
## per frame. The village shows only stall keepers, each at a stall of its own (never
## more than there are stalls), and players in on an errand, at their villager.
var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _ready() -> void:
	Game.set_process(false)
	GameSettings.load_settings()
	GameSettings.quality = 2
	WorldPlayers.persist = false
	# A day on which the village is full of players, with enhanced gear to show.
	WorldPresence.enabled = true
	GameSettings.show_world_players = true
	WorldPresence.clock_offset = float(WorldPlayers.START_UNIX) + 3.4 * 86400.0 - WorldPlayers.now()
	Game.new_profile(&"warrior", "LOD QA", FaceKit.default_look())
	Game.current_zone = &"town"
	var zone := Zone.new()
	zone.zone_id = &"town"
	add_child(zone)
	for i in 90:
		await get_tree().physics_frame
	var players: Array = get_tree().get_nodes_in_group("world_players")
	check(players.size() >= 10, "the village shows players (%d)" % players.size())
	check(players.size() <= WorldPresence.limit_here(true), "no more than the village's limit (%d of %d)" % [players.size(), WorldPresence.limit_here(true)])
	var spots := {}
	var keepers_shown := 0
	for node in players:
		var p := node as FieldPlayer
		var s := WorldPlayers.state(p.world_index, WorldPresence.clock())
		check(p.doing in ["stall", "errand"] and String(s.doing) == p.doing and String(s.place) == "town", "%s in the village keeps a stall or runs an errand (%s, %s)" % [p.member.name, p.doing, s.doing])
		if p.doing == "errand":
			check(p.on_errand() and p.errand == String(s.errand), "%s is on its %s errand" % [p.member.name, s.errand])
			continue
		keepers_shown += 1
		check(p.stall_at.is_finite() and not spots.has(p.stall_at), "%s has a stall of its own" % p.member.name)
		spots[p.stall_at] = true
	check(keepers_shown <= JapanVillage.STALLS.size(), "no more keepers than stalls (%d of %d)" % [keepers_shown, JapanVillage.STALLS.size()])
	# A day when more keepers are online than there are stalls: still one stall each.
	var presence0: WorldPresence = zone.presence if "presence" in zone else null
	if presence0 != null:
		var keepers := 0
		for i in WorldPlayers.size():
			var s := WorldPlayers.state(i, WorldPresence.clock())
			keepers += 1 if bool(s.online) and String(s.doing) == "stall" else 0
		print("town_lod_test: %d stall keepers online, %d shown, %d errand runners, %d stalls" % [keepers, keepers_shown, players.size() - keepers_shown, JapanVillage.STALLS.size()])
		check(presence0._stalls.size() == keepers_shown, "every shown keeper holds a stall (%d shown, %d stalls taken)" % [keepers_shown, presence0._stalls.size()])
	var emitters := 0
	var flames := 0
	var lights := 0
	var enhanced := 0
	for node in players:
		var p := node as FieldPlayer
		check(p.visual.decor_light, "%s wears the cheap dressing" % p.member.name)
		var own := p.visual.find_children("*", "CPUParticles3D", true, false).size()
		emitters += own
		check(own <= 1, "%s carries at most one particle emitter (%d)" % [p.member.name, own])
		for n in p.visual.find_children("*", "OmniLight3D", true, false):
			lights += 1
		if EnhanceFx.best_plus(p.visual.equip) >= 7:
			enhanced += 1
	check(lights == 0, "no player around carries a light (%d)" % lights)
	print("town_lod_test: %d players, %d enhanced to +7 or more, %d emitters" % [players.size(), enhanced, emitters])
	# Far players: emitters off, no shadows, animation still moving.
	var hero: Hero = zone.hero
	var far: Array[FieldPlayer] = []
	var near: Array[FieldPlayer] = []
	for node in players:
		var p := node as FieldPlayer
		var d := Vector2(p.global_position.x - hero.global_position.x, p.global_position.z - hero.global_position.z).length()
		if d > FieldPlayer.LOD_FAR:
			far.append(p)
		elif d < FieldPlayer.LOD_NEAR * 0.8:
			near.append(p)
	for i in 40:
		await get_tree().physics_frame
	check(not far.is_empty(), "some players stand far from the hero (%d)" % far.size())
	for p in far:
		if p.party_mode or p.target != null:
			continue
		check(p.visual.anim_lod >= 2, "%s far away poses less often (step %d)" % [p.member.name, p.visual.anim_lod])
		check(p.visual.is_processing(), "%s far away still takes its manual animation steps" % p.member.name)
		var before := p.visual.anim.current_animation_position if p.visual.anim != null else -1.0
		for i in 12:
			await get_tree().process_frame
		var after := p.visual.anim.current_animation_position if p.visual.anim != null else -1.0
		check(p.visual.anim == null or not is_equal_approx(before, after) or p.visual.anim.current_animation == "", "%s far away keeps animating (%.2f -> %.2f)" % [p.member.name, before, after])
		for e in p.visual.find_children("*", "CPUParticles3D", true, false):
			check(not (e as CPUParticles3D).emitting, "%s far away stops its emitter" % p.member.name)
		var shadowed := 0
		for mi in p.visual.find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				shadowed += 1
		check(shadowed == 0, "%s far away casts no shadow (%d meshes do)" % [p.member.name, shadowed])
	# On a phone a far player also loses its small decoration (hair accessory, rune rings,
	# halo) and the enhancement glow overlays on its meshes; both come back when it is near.
	MemoryGuard.phone_override = 1
	var decorated := 0
	for p in far:
		if p.party_mode or p.target != null:
			continue
		p.visual.set_far(false)
		var decor: Array = p.visual._body_nodes.filter(func(n): return is_instance_valid(n) and bool(n.get_meta("far_decor", false)))
		var overlays := 0
		for mi in p.visual.find_children("*", "MeshInstance3D", true, false):
			overlays += 1 if (mi as MeshInstance3D).material_overlay != null else 0
		p.visual.set_far(true)
		check(p.visual.far_light, "%s far away on a phone wears the cheap far state" % p.member.name)
		for n in decor:
			check(not (n as Node3D).visible, "%s far away on a phone hides its %s" % [p.member.name, n.name])
		var left := 0
		for mi in p.visual.find_children("*", "MeshInstance3D", true, false):
			left += 1 if (mi as MeshInstance3D).material_overlay != null else 0
		check(left == 0, "%s far away on a phone wears no glow overlay (%d of %d left)" % [p.member.name, left, overlays])
		if not decor.is_empty() or overlays > 0:
			decorated += 1
		p.visual.set_far(false)
		check(not p.visual.far_light and decor.all(func(n): return (n as Node3D).visible), "%s near again shows its decoration" % p.member.name)
		var back := 0
		for mi in p.visual.find_children("*", "MeshInstance3D", true, false):
			back += 1 if (mi as MeshInstance3D).material_overlay != null else 0
		check(back == overlays, "%s near again wears its glow overlays (%d of %d)" % [p.member.name, back, overlays])
		p.visual.set_far(true)
	print("town_lod_test: %d of %d far players carried decoration or glow to drop" % [decorated, far.size()])
	MemoryGuard.phone_override = -1
	for p in far:
		if not (p.party_mode or p.target != null):
			p.visual.set_far(false)
			p.visual.set_far(true)
			check(not p.visual.far_light, "%s far away on a desktop keeps its decoration" % p.member.name)
			break
	for p in near:
		if p.visual.anim_lod == 1:
			var shadowed := 0
			for mi in p.visual.find_children("*", "MeshInstance3D", true, false):
				if (mi as MeshInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
					shadowed += 1
			check(shadowed > 0, "%s nearby casts shadows" % p.member.name)
	# Into the party: the full dressing comes back; out again: the cheap one.
	if not players.is_empty():
		var p := players[0] as FieldPlayer
		p.join_party(p.member, 0)
		check(not p.visual.decor_light, "a party member wears the full dressing")
		p.leave_party()
		check(p.visual.decor_light, "and the cheap one again after leaving")
	# The 3D scale a phone's village starts from.
	check(is_equal_approx(MemoryGuard.scale_3d, MemoryGuard.base_scale_3d()), "the zone starts at the device's base 3D scale (%.2f)" % MemoryGuard.scale_3d)
	# A sync's arrivals come one per frame: force every shown player out and let them return.
	var presence: WorldPresence = zone.presence if "presence" in zone else null
	if presence != null:
		var shown_before := presence.shown.size()
		for i in presence.shown.keys():
			var gone: FieldPlayer = presence.shown[i]
			if is_instance_valid(gone):
				gone.queue_free()
		presence.shown.clear()
		await get_tree().process_frame
		presence.sync(false)
		var first := get_tree().get_nodes_in_group("world_players").size()
		for i in 6:
			await get_tree().process_frame
		var later := get_tree().get_nodes_in_group("world_players").size()
		check(first <= 2 and later > first, "arrivals come one per frame (%d after the sync, %d six frames on, %d before)" % [first, later, shown_before])
	print("TOWN LOD: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED", checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
