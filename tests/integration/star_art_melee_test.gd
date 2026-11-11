extends Node3D
## The melee star signatures (combat/star_art: Warrior, Lancer, Defender, Assassin at 50 / 100 /
## 150 / 200 stars): every skill casts for real in a field without script errors, its own
## signature owns the show (StarSignature / GodSkillArt.owns: the generic class overlays stay
## out), its wind-up and contacts draw layers, every root it opens is gone after the cast,
## VfxBudget returns to its baseline, quality 0 still draws, and a hero dying mid-cast takes
## the set piece down with it.
const CLASSES := [&"warrior", &"lancer", &"defender", &"assassin"]
## Roots of the shared class systems that a signature's skill must never open.
const FOREIGN := ["ClassFlourish_", "ShadowArt_", "Signature_", "StarWindupCanopy", "CelestialEquippedSword", "CelestialSwordCanopy"]
var failures := 0
var checks := 0


func check(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", why)


func _profile(cls: StringName) -> void:
	Game.new_profile(cls, "Star Art QA")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile.paragon = {"level": 300, "points": 300, "spent": 0, "exp": 0, "alloc": {}}
	Game.profile.look = {"gender": 0}
	Game.profile.equip = {}
	Game.profile.party = []
	for slot in ItemData.EQUIP_SLOTS:
		Game.profile.equip[slot] = StarWingData.item(String(cls), Game.rng) if slot == "wings" else StarProgression.item(cls, 200, slot, Game.rng)
	Game.profile.hp = 100000
	Game.profile.mp = 100000


func _ready() -> void:
	Game.set_process(false)
	InputSetup.ensure_defaults()
	GameSettings.load_settings()
	GameSettings.ult_cutin = false
	MemoryGuard.pressure = 0
	Engine.time_scale = 4.0
	for cls in CLASSES:
		var ids: Array = StarSkillData.IDS[cls]
		for i in 4:
			var skill: Dictionary = StarSkillData.pool(cls)[i]
			check(StarSignature.script_for(ids[i]) != null, "signature script for " + String(ids[i]))
			check(StarSignature.owns(skill) and GodSkillArt.owns(skill), "signature owns " + String(ids[i]))
			# A star monster's attack borrows these ids for their colours: never the signature.
			check(not StarSignature.owns({"id": ids[i], "star": 50, "radius": 3.0, "shape": "blast"}), "lookalike not owned " + String(ids[i]))
		check(not StarSignature.owns(StarSkillData.pool(cls)[4]), "the god skill keeps its god art " + String(cls))
	for quality in [2, 0]:
		GameSettings.quality = quality
		for cls in CLASSES:
			for i in 4:
				await _cast(cls, i, quality)
	GameSettings.quality = 2
	await _death_mid_cast()
	Engine.time_scale = 1.0
	Game.has_profile = false
	print("STAR ART MELEE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _field(cls: StringName) -> Array:
	_profile(cls)
	var field := Node3D.new()
	add_child(field)
	var hero := Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	var mobs: Array = []
	for spot in [Vector3(0, 0, 2.6), Vector3(-2.0, 0, 4.2), Vector3(2.2, 0, 4.0)]:
		var mob := Mob.new()
		mob.setup(&"forest_orc", 60, spot, hero)
		mob.position = spot
		field.add_child(mob)
		mob.set_physics_process(false)
		mob.hp = 100000000
		mob.max_hp = mob.hp
		mobs.append(mob)
	hero.target = mobs[0]
	return [field, hero]


func _foreign(field: Node) -> String:
	for node in field.find_children("*", "", true, false):
		for prefix in FOREIGN:
			if String(node.name).begins_with(prefix) and (node as Node3D) != null and (node as Node3D).is_visible_in_tree():
				return String(node.name)
	return ""


func _ours(field: Node, id: String) -> Array:
	var out: Array = []
	for node in field.get_children():
		if node is StarSkillArt and String(node.name).contains(id) and not node.is_queued_for_deletion():
			out.append(node)
	return out


func _cast(cls: StringName, i: int, quality: int) -> void:
	var made := _field(cls)
	var field: Node3D = made[0]
	var hero: Hero = made[1]
	var skill: Dictionary = StarSkillData.pool(cls)[i]
	var id := String(skill.id)
	var tag := "%s q%d" % [id, quality]
	await get_tree().process_frame
	var base := VfxBudget.counters()
	hero._cast(skill)
	var seq := hero.get_node_or_null("StarCast_" + id)
	check(seq != null, "cast runs " + tag)
	var windup := false
	var contact := false
	var layers := 0
	var foreign := ""
	var frames := 0
	while is_instance_valid(seq) and frames < 4000:
		await get_tree().process_frame
		frames += 1
		for root in _ours(field, id):
			var art := root as StarSkillArt
			layers = maxi(layers, art.layers.size())
			if String(art.name).begins_with("StarWindup_") and not art.layers.is_empty():
				windup = true
			if String(art.name).begins_with("StarContact_") and not art.layers.is_empty():
				contact = true
			check(art.layers.size() <= [2, 4, 6][quality], "layer cap per root " + tag)
		if foreign == "":
			foreign = _foreign(field)
	check(not is_instance_valid(seq), "cast ends " + tag)
	check(windup, "signature wind-up draws " + tag)
	check(contact, "signature contacts draw " + tag)
	check(layers > 0, "signature layers " + tag)
	check(foreign == "", "no shared class overlay under the signature %s (%s)" % [tag, foreign])
	# Every root of the set piece has finished shortly after the cast.
	await get_tree().create_timer(2.6).timeout
	check(_ours(field, id).is_empty(), "signature roots freed after the cast " + tag)
	field.queue_free()
	await field.tree_exited
	await get_tree().process_frame
	check(VfxBudget.counters() == base, "VfxBudget back to baseline %s %s" % [tag, str(VfxBudget.counters())])


## The hero dies in the middle of the Swordfall: its sky, seal and swords close at once.
func _death_mid_cast() -> void:
	var made := _field(&"warrior")
	var field: Node3D = made[0]
	var hero: Hero = made[1]
	var skill: Dictionary = StarSkillData.pool(&"warrior")[3]
	var id := String(skill.id)
	hero._cast(skill)
	var seq := hero.get_node_or_null("StarCast_" + id)
	await get_tree().create_timer(2.2).timeout
	check(is_instance_valid(seq) and not _ours(field, id).is_empty(), "swordfall under way")
	hero._dead = true
	await get_tree().create_timer(0.6).timeout
	check(not is_instance_valid(seq), "the cast stops with its hero")
	check(_ours(field, id).is_empty(), "the set piece closes with its hero (%d roots left)" % _ours(field, id).size())
	field.queue_free()
	await field.tree_exited
	await get_tree().process_frame
	check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "budget released after a death mid-cast")
