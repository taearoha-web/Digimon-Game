extends Node3D
## The Warrior and Lancer Lv.60-100 class skills' signature art (combat/skill_art, team
## "blade" kit _blade.gd): every skill casts for real through the hero's path and a
## companion's without script errors, its own signature owns the show (SkillSignature /
## GodSkillArt.owns: the shared class overlays, SkillTableau's links, flights and contacts
## stay out), its wind-up and release draw layers within the root cap, a companion's cast
## draws no more than the hero's, every root it opens is gone after the cast, VfxBudget
## returns to its baseline, quality 0 still draws, and a hero dying mid-cast takes the set
## piece down with it.
const IDS := {
	&"warrior": ["cyclone_strike", "brandish", "double_crash", "piercing", "drastic_spirit", "grand_cross", "sword_of_justice", "godly_shield", "divine_piercing", "triumph_of_valhalla", "gladiator"],
	&"lancer": ["typhoon_spear", "lancer_rush", "vanguard_strike", "sky_pierce", "dragon_stance", "dragon_lance", "gale_cyclone", "valkyrie_blessing", "gungnir", "heaven_rend", "ragnarok_lance"],
}
## Nodes of the shared class systems that an owned skill must never open.
const FOREIGN := ["ClassFlourish_", "ShadowArt_", "Signature_", "SkillLink_", "SkillFlight_", "SkillContact_", "SpellSpectacle_", "EliteSkill_", "StarContact_", "StarWindup_", "InkBlade", "InkImpact", "InkSeal", "FlourishFlightGlow", "EssentialSkillProjectile"]
var failures := 0
var checks := 0
## The most layers one cast of each skill drew at quality 2 (hero), to compare a companion's.
var hero_layers := {}


func check(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", why)


func _profile(cls: StringName) -> void:
	Game.new_profile(cls, "Blade Art QA")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile.look = {"gender": 0}
	Game.profile.equip = {}
	Game.profile.party = []
	for slot in ItemData.EQUIP_SLOTS:
		Game.profile.equip[slot] = StarProgression.item(cls, 50, slot, Game.rng) if slot != "wings" else ItemData.wings(Game.rng, String(cls))
	Game.profile.hp = 100000
	Game.profile.mp = 100000


func _ready() -> void:
	Game.set_process(false)
	InputSetup.ensure_defaults()
	GameSettings.load_settings()
	GameSettings.ult_cutin = false
	MemoryGuard.pressure = 0
	Engine.time_scale = 4.0
	for cls in IDS:
		for id in IDS[cls]:
			var skill := ClassData.find_skill(cls, id)
			check(not skill.is_empty(), "skill exists " + String(id))
			check(SkillSignature.script_for(id) != null, "signature script for " + String(id))
			check(SkillSignature.owns(skill) and GodSkillArt.owns(skill), "signature owns " + String(id))
	check(SkillSignature.script_for("_blade") == null, "the kit is never a skill's art")
	for quality in [2, 0]:
		GameSettings.quality = quality
		for cls in IDS:
			for id in IDS[cls]:
				await _cast(cls, id, quality, false)
	GameSettings.quality = 2
	for cls in IDS:
		for id in IDS[cls]:
			await _cast(cls, id, 2, true)
	await _death(&"warrior", "gladiator", 0.5)
	await _death(&"lancer", "ragnarok_lance", 1.6)
	Engine.time_scale = 1.0
	Game.has_profile = false
	print("SKILL ART BLADE checks=%d failures=%d" % [checks, failures])
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
	for spot in [Vector3(0, 0, 2.6), Vector3(-2.0, 0, 4.2), Vector3(2.2, 0, 4.0), Vector3(0.3, 0, 6.5), Vector3(-3.0, 0, -1.5)]:
		var mob := Mob.new()
		mob.setup(&"forest_orc", 60, spot, hero)
		mob.position = spot
		field.add_child(mob)
		mob.set_physics_process(false)
		mob.hp = 100000000
		mob.max_hp = mob.hp
		mobs.append(mob)
	hero.target = mobs[0]
	return [field, hero, mobs]


func _ours(field: Node, id: String) -> Array:
	var out: Array = []
	for node in field.get_children():
		if node is StarSkillArt and String(node.name).begins_with("SkillArt_" + id) and not node.is_queued_for_deletion():
			out.append(node)
	return out


func _leftovers(field: Node, id: String) -> int:
	var n := 0
	for node in field.get_children():
		if String(node.name).begins_with("SkillArt") and String(node.name).contains(id) and not node.is_queued_for_deletion():
			n += 1
	return n


func _foreign(field: Node) -> String:
	for node in field.find_children("*", "", true, false):
		for prefix in FOREIGN:
			if String(node.name).begins_with(prefix) and node is Node3D and (node as Node3D).is_visible_in_tree():
				return String(node.name)
	var vp := get_viewport()
	if vp.has_meta(MeleeArt.HOLDER):
		for rig in (vp.get_meta(MeleeArt.HOLDER) as Node).get_children():
			if rig is MeleeArt and rig.busy:
				return "MeleeArt"
	return ""


func _cast(cls: StringName, id: String, quality: int, companion: bool) -> void:
	var base := VfxBudget.counters()
	var made := _field(cls)
	var field: Node3D = made[0]
	var hero: Hero = made[1]
	var skill := ClassData.find_skill(cls, id)
	var tag := "%s q%d%s" % [id, quality, " companion" if companion else ""]
	await get_tree().process_frame
	var release := float(skill.hit_delay)
	if companion:
		var buddy := Companion.new()
		buddy.setup({"class": String(cls), "name": "Ally", "level": 100, "exp": 0, "gender": 0}, 0, hero, field)
		field.add_child(buddy)
		buddy.set_physics_process(false)
		buddy.global_position = Vector3(0.5, 0, -0.5)
		buddy.target = made[2][0]
		buddy.mp = 100000
		buddy._cast(skill)
	else:
		hero._cast(skill)
		release *= 1.0 - hero._haste()
	# Every layer of a root is built when the root opens: the wind-up's right now (a first
	# cast builds its meshes, and that frame can outlast the whole short wind-up).
	var windup := false
	var released := false
	var seen := {}
	var foreign := ""
	var clock := 0.0
	while clock < release + 2.6:
		for root in _ours(field, id):
			var art := root as StarSkillArt
			seen[art.get_instance_id()] = art.layers.size()
			check(art.layers.size() <= [2, 4, 6][quality], "layer cap per root " + tag)
			if art.layers.is_empty():
				continue
			if String(art.name).ends_with("_Windup"):
				windup = true
			else:
				released = true
		if foreign == "":
			foreign = _foreign(field)
		await get_tree().process_frame
		clock += get_process_delta_time()
	var most := 0
	for n in seen.values():
		most += int(n)
	check(windup, "signature wind-up draws " + tag)
	check(released, "signature release draws " + tag)
	check(foreign == "", "no shared class overlay under the signature %s (%s)" % [tag, foreign])
	if quality == 2 and not companion:
		hero_layers[id] = most
	if companion:
		check(most <= int(hero_layers.get(id, 999)), "a companion's cast is no heavier than the hero's %s (%d > %d)" % [tag, most, int(hero_layers.get(id, 999))])
	await get_tree().create_timer(1.2).timeout
	check(_leftovers(field, id) == 0, "signature roots freed after the cast %s (%d left)" % [tag, _leftovers(field, id)])
	field.queue_free()
	await field.tree_exited
	await get_tree().process_frame
	check(VfxBudget.counters() == base, "VfxBudget back to baseline %s %s" % [tag, str(VfxBudget.counters())])


## The hero dies [param after] seconds into the cast: every root of the set piece closes.
func _death(cls: StringName, id: String, after: float) -> void:
	var base := VfxBudget.counters()
	var made := _field(cls)
	var field: Node3D = made[0]
	var hero: Hero = made[1]
	var skill := ClassData.find_skill(cls, id)
	await get_tree().process_frame
	hero._cast(skill)
	await get_tree().create_timer(after).timeout
	check(not _ours(field, id).is_empty(), "%s under way at %.2f s" % [id, after])
	hero._die()
	await get_tree().create_timer(0.6).timeout
	check(_ours(field, id).is_empty(), "the set piece closes with its hero %s (%d roots left)" % [id, _ours(field, id).size()])
	field.queue_free()
	await field.tree_exited
	await get_tree().process_frame
	check(VfxBudget.counters() == base, "budget released after a death mid-cast %s %s" % [id, str(VfxBudget.counters())])
