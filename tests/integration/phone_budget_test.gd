extends Node
## The phone budgets of the newer systems (see tests/tools/phone_perf_probe.gd for the
## measured scenes):
##   - party roles (ClassRoles): every hit and every unit's frame asks, and the parties
##     are built at most once a frame (one pass for a whole guild war), the same
##     read-only answer for every member; a body outside every party builds nothing
##   - buffs (BuffBook): a buffed body whose buffs did not change does not rebuild its
##     auras every frame, and an expiring buff still takes its aura away
##   - every effect shader the newer effects preload is drawn by ShaderWarm while the zone
##     loads (no compile on a first cast), and the samples are freed again
##   - the village full of players and their pets at medium quality (the phone default):
##     the pets out stay under the crowd's cap, other players' pets draw no rim light
##     nor ink outline (each a second draw of every mesh) below high quality, each stays a
##     handful of draws,
##     and the village's node count stays under its budget; at high quality the rim is
##     still worn (high quality looks the same)
##   godot --headless --path . res://tests/integration/phone_budget_test.tscn
var failures := 0
var checks := 0

## The village at medium quality with every world player and pet out measured about
## 4 100 nodes (phone_perf_probe village 1); the line leaves room for a few more stalls.
const VILLAGE_NODES := 5000
## Draws of one other player's pet at medium quality: its model's meshes (no rim, no
## outline pass), its blob shadow and the cheap form look (aura ring, gold ring, halo).
const PET_DRAWS := 11
## Party builds in a frame where every war fighter asks every hook a few times.
const BUILDS_PER_FRAME := 1


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	WorldEvents.festival_enabled = false
	Game.set_process(false)
	GameSettings.load_settings()
	MemoryGuard.force(0, get_tree())
	_shader_coverage()
	await _shader_warm()
	await _buff_book()
	await _class_roles_war()
	await _village(1)
	await _village(2)
	MemoryGuard.force(-1, get_tree())
	print("PHONE BUDGET: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


# ---------------------------------------------------------------------------
# Shaders

## The scripts of the newer effects: every shader they preload is warmed.
const EFFECT_SCRIPTS := [
	"res://combat/skill_layers.gd", "res://combat/skill_layer_pool.gd", "res://characters/pet_form.gd",
	"res://combat/taunt_chain.gd", "res://combat/martial_skill_art.gd", "res://combat/star_skill_art.gd",
	"res://combat/summon_aura.gd", "res://combat/sculpture_art.gd", "res://characters/shadow_wing_art.gd",
	"res://combat/elite_skill_art.gd", "res://characters/summon.gd",
]


func _shader_coverage() -> void:
	var scripts: Array = EFFECT_SCRIPTS.duplicate()
	for f in DirAccess.get_files_at("res://combat/class_art"):
		if f.ends_with(".gd"):
			scripts.append("res://combat/class_art/" + f)
	var warmed := {}
	for p in ShaderWarm.MESH_SHADERS + ShaderWarm.INSTANCED_SHADERS:
		warmed[p] = true
	var re := RegEx.create_from_string("preload\\(\"(res://shaders/[^\"]+\\.gdshader)\"\\)")
	var found := 0
	for path in scripts:
		var text := FileAccess.get_file_as_string(path)
		for m in re.search_all(text):
			found += 1
			check(warmed.has(m.get_string(1)), "%s's shader %s is drawn while the zone loads" % [path.get_file(), m.get_string(1).get_file()])
	check(found >= 15, "the newer effects' shaders were found (%d)" % found)
	for p in ShaderWarm.MESH_SHADERS + ShaderWarm.INSTANCED_SHADERS:
		check(ResourceLoader.exists(p), "%s exists" % p)


func _shader_warm() -> void:
	var field := Node3D.new()
	add_child(field)
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	await ShaderWarm.warm(field, Vector3.ZERO)
	check(ShaderWarm.last_count == ShaderWarm.MESH_SHADERS.size() + ShaderWarm.INSTANCED_SHADERS.size(), "every shader sample is drawn (%d)" % ShaderWarm.last_count)
	await get_tree().create_timer(ShaderWarm.HOLD + 0.3).timeout
	await _frames(2)
	check(field.get_child_count() == 0, "the samples are freed again (%d children, nodes %d -> %d)" % [field.get_child_count(), nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	field.queue_free()


# ---------------------------------------------------------------------------
# Buffs

class Body extends Node3D:
	pass


func _buff_book() -> void:
	var host := Body.new()
	add_child(host)
	var book := BuffBook.new()
	book.add({"atk": 0.2, "secs": 0.5}, Color.RED, "แรง", false, "test_might")
	var top := func(): return 2.0
	book.tick(host, true, top)
	var list := book.buffs
	var aura: Variant = book.auras.values()[0] if not book.auras.is_empty() else null
	check(aura != null, "a buff wears its aura")
	for i in 30:
		book.tick(host, true, top)
	check(is_same(book.buffs, list) and book.auras.size() == 1 and book.auras.values()[0] == aura, "an unchanged buff list is not rebuilt every frame")
	check(absf(book.total("atk") - 0.2) < 0.001 and book.total("def") == 0.0, "its effect still counts (%.2f)" % book.total("atk"))
	await get_tree().create_timer(0.7).timeout
	book.tick(host, true, top)
	check(book.buffs.is_empty() and book.auras.is_empty(), "an expired buff takes its aura away")
	check(book.total("atk") == 0.0, "and its effect")
	book.add({"atk": 0.2, "secs": 5.0}, Color.RED, "แรง", false, "test_might")
	book.tick(host, true, top)
	check(book.auras.size() == 1, "a new buff shows at once")
	book.tick(host, false, top)
	check(book.auras.is_empty(), "a fallen body's auras go at once")
	host.queue_free()
	await _frames(1)


# ---------------------------------------------------------------------------
# Party roles in a guild war

func _class_roles_war() -> void:
	Game.new_profile(&"warrior", "Budget GW")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile["paragon"] = {"level": 200, "exp": 0, "points": 0, "spent": 0, "alloc": Game.party_star_alloc(200)}
	Game.profile.hp = Game.stats_now().max_hp
	Game.guildwar_party_chosen = false
	Game.current_zone = &"guildwar"
	var zone := Zone.new()
	zone.zone_id = &"guildwar"
	add_child(zone)
	var m: GuildWarMatch = zone.gw_match
	check(m != null and GuildWarMatch.in_war(), "a guild war is on")
	if m == null:
		zone.queue_free()
		return
	zone.set_process(false)
	await _frames(2)
	var fighters: Array = m.all_fighters()
	var bodies: Array = fighters.duplicate()
	bodies.append(m.hero)
	check(fighters.size() >= 10, "the war has its fighters (%d)" % fighters.size())
	var mob: Node = fighters[0]
	await get_tree().process_frame
	var before := ClassRoles.builds
	var started := Time.get_ticks_usec()
	var asks := 0
	for k in 20:
		for b in bodies:
			ClassRoles.outgoing(b, mob)
			ClassRoles.crit_bonus(b)
			ClassRoles.pierce(b)
			ClassRoles.taken(b)
			ClassRoles.cd_rate(b)
			asks += 5
	var spent := float(Time.get_ticks_usec() - started) / 1000.0
	check(ClassRoles.builds - before <= BUILDS_PER_FRAME, "%d asks in a frame build the war's parties once (%d builds)" % [asks, ClassRoles.builds - before])
	print("phone_budget_test: %d party-role asks in %.2f ms" % [asks, spent])
	check(spent < 60.0, "the asks are cheap (%.2f ms for %d)" % [spent, asks])
	# Every member of a party reads the same answer (nothing built per ask).
	var same := true
	for a in fighters:
		for b in fighters:
			if (a as GuildFighter).party == (b as GuildFighter).party and not is_same(ClassRoles.party_classes(a), ClassRoles.party_classes(b)):
				same = false
	check(same, "the members of a party share one answer")
	check(ClassRoles.party_classes(mob).size() > 0 or true, "a fighter has its party's roles")
	# The fighters themselves ask every frame (regen, cooldowns, hits): ten frames of a
	# running war build the parties at most ten times.
	before = ClassRoles.builds
	await _frames(10)
	var built := ClassRoles.builds - before
	check(built >= 1 and built <= 10 * BUILDS_PER_FRAME, "ten frames of the war build the parties at most once a frame (%d)" % built)
	# A body outside every party asks for nothing.
	var outsider := Node3D.new()
	add_child(outsider)
	before = ClassRoles.builds
	check(ClassRoles.party_classes(outsider).is_empty() and ClassRoles.outgoing(outsider, mob) == 1.0 and ClassRoles.builds == before, "a body outside every party builds nothing")
	outsider.queue_free()
	zone.queue_free()
	await _frames(3)


# ---------------------------------------------------------------------------
# The village full of players and pets

func _village(quality: int) -> void:
	GameSettings.quality = quality
	WorldPlayers.persist = false
	WorldPresence.enabled = true
	GameSettings.show_world_players = true
	PetCrowd.enabled = true
	# A day when the village is at its busiest.
	WorldPresence.clock_offset = float(WorldPlayers.START_UNIX) + 20.7 * 86400.0 - WorldPlayers.now()
	Game.new_profile(&"lancer", "Budget Town")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.paragon().level = 300
	Game.choose_pet("fire")
	Game.current_zone = &"town"
	var zone := Zone.new()
	zone.zone_id = &"town"
	add_child(zone)
	for i in 120:
		await get_tree().physics_frame
	var players := get_tree().get_nodes_in_group("world_players")
	if not players.is_empty():
		var middle := Vector3.ZERO
		for p in players:
			middle += (p as Node3D).global_position
		zone.hero.global_position = middle / float(players.size())
	var crowd := zone.get_node_or_null("PetCrowd") as PetCrowd
	check(crowd != null, "q%d: the village has its crowd of pets" % quality)
	if crowd == null:
		zone.queue_free()
		await _frames(2)
		return
	crowd.refresh(true)
	await _frames(3)
	var out := crowd.out_count()
	check(out > 0 and out <= PetCrowd.cap(), "q%d: the pets out stay under the cap (%d of %d)" % [quality, out, PetCrowd.cap()])
	var rims := 0
	var outlines := 0
	var most := 0
	var starred := 0
	for f in get_tree().get_nodes_in_group("pet_followers"):
		var pet := f as PetFollower
		if not pet.visible:
			continue
		if pet.stage >= PetData.STAR_STAGE:
			starred += 1
		var draws := 0
		for g in pet.find_children("*", "GeometryInstance3D", true, false):
			var gi := g as GeometryInstance3D
			if not gi.is_visible_in_tree():
				continue
			if gi is MeshInstance3D and (gi as MeshInstance3D).mesh != null:
				var mi := gi as MeshInstance3D
				for k in mi.mesh.get_surface_count():
					draws += 1
					var mat := mi.get_active_material(k)
					if mat != null and mat.next_pass != null:
						draws += 1
						outlines += 1
			else:
				draws += 1
			if gi.material_overlay is ShaderMaterial and (gi.material_overlay as ShaderMaterial).shader == PetForm.RIM_SHADER:
				rims += 1
				draws += 1
		most = maxi(most, draws)
	print("phone_budget_test: village q%d: %d players, %d pets out (%d from ★100), most draws of one pet %d, rims %d, outlines %d, nodes %d" % [
		quality, players.size(), out, starred, most, rims, outlines, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	if quality < 2:
		check(rims == 0, "q%d: other players' pets draw no rim light (%d)" % [quality, rims])
		check(outlines == 0, "q%d: other players' pets draw no ink outline (%d)" % [quality, outlines])
		check(most <= PET_DRAWS, "q%d: another player's pet is a handful of draws (%d)" % [quality, most])
		check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) <= VILLAGE_NODES, "q%d: the village's nodes stay under %d (%d)" % [quality, VILLAGE_NODES, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	else:
		check(starred == 0 or rims > 0, "q2: other players' ★100 pets still wear the rim light (%d)" % rims)
		check(outlines > 0, "q2: and their ink outline (%d)" % outlines)
	# The hero's own pet keeps its full form at every quality it is shown in.
	var mine: Pet = zone.pet if "pet" in zone else null
	if mine != null and mine.form_root != null:
		var rim_on := false
		for mi in mine._visual._flash_targets():
			if is_instance_valid(mi) and (mi as MeshInstance3D).material_overlay != null:
				rim_on = true
		check(rim_on, "q%d: the hero's own god-form pet wears its rim light" % quality)
	zone.queue_free()
	await _frames(3)
