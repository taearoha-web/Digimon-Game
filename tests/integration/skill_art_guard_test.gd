extends Node3D
## The Defender and Assassin Lv.60-100 signature art (combat/skill_art, team "guard"): every
## skill casts for real through the hero's path and a companion's without script errors,
## its own signature owns the show (SkillSignature / GodSkillArt.owns: the shared class
## overlays stay out, links, flights and hits included), its wind-up and release draw layers,
## a companion's cast stays light (no more than the lite cap per root), every root it opens
## is gone after the cast, VfxBudget returns to its baseline, quality 0 still draws within
## its cap, and a caster dying mid-cast takes the set piece down with it.
const G := preload("res://combat/skill_art/_guard.gd")
const IDS := {
	&"defender": ["titan_quake", "bastion_crush", "rebound_storm", "grand_provoke", "unbreakable", "holy_rampart", "judgment_shield", "aegis_of_ages", "meteor_shield", "sanctuary_wall", "world_bastion"],
	&"assassin": ["thousand_cuts", "throat_slit", "shadow_dance", "death_mark", "night_lord", "eclipse_fang", "abyss_vortex", "phantom_legion", "midnight_execution", "shadow_sovereign", "oblivion_requiem"],
}
## Roots of the shared class systems that a signature's skill must never open.
const FOREIGN := ["ClassFlourish_", "ShadowArt_", "Signature_", "LordArt_", "CasterArt_", "EliteInvocation_", "SkillWindup_", "SkillContact_", "SkillLink_", "SkillFlight_", "Relief_", "FlourishLotus", "SpellContact", "StarWindup_"]
var failures := 0
var checks := 0


func check(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", why)


func _profile(cls: StringName) -> void:
	Game.new_profile(cls, "Guard Art QA")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile.look = {"gender": 0}
	Game.profile.party = []
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
			var skill := _skill(cls, id)
			check(not skill.is_empty(), "skill exists " + id)
			check(SkillSignature.script_for(id) != null, "signature script for " + id)
			check(SkillSignature.owns(skill) and GodSkillArt.owns(skill), "signature owns " + id)
	check(SkillSignature.script_for("_guard") == null, "the kit is never a skill's art")
	check(not SkillSignature.owns(_skill(&"defender", "shield_wave")), "a lower skill keeps the shared art")
	for quality in [2, 0]:
		GameSettings.quality = quality
		for cls in IDS:
			for id in IDS[cls]:
				await _cast(cls, id, quality, false)
	GameSettings.quality = 2
	for cls in IDS:
		for id in IDS[cls]:
			await _cast(cls, id, 2, true)
	await _death_after_release()
	await _death_in_windup()
	Engine.time_scale = 1.0
	Game.has_profile = false
	print("SKILL ART GUARD checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _skill(cls: StringName, id: String) -> Dictionary:
	for skill in ClassData.pool(cls):
		if String(skill.id) == id and not skill.has("star"):
			return skill
	return {}


func _field(cls: StringName) -> Array:
	_profile(cls)
	var field := Node3D.new()
	add_child(field)
	var hero := Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	var mobs: Array = []
	for spot in [Vector3(0, 0, 2.6), Vector3(-2.0, 0, 4.2), Vector3(2.2, 0, 4.0), Vector3(0.6, 0, 6.0)]:
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


func _foreign(field: Node) -> String:
	for node in field.find_children("*", "", true, false):
		for prefix in FOREIGN:
			if String(node.name).begins_with(prefix) and node is Node3D and (node as Node3D).is_visible_in_tree():
				return String(node.name)
	return ""


func _ours(field: Node, id: String) -> Array:
	var out: Array = []
	for node in field.get_children():
		if node is StarSkillArt and String(node.name).begins_with("Skill_" + id + "_") and not node.is_queued_for_deletion():
			out.append(node)
	return out


func _cast(cls: StringName, id: String, quality: int, companion: bool) -> void:
	var made := _field(cls)
	var field: Node3D = made[0]
	var hero: Hero = made[1]
	var mobs: Array = made[2]
	var skill := _skill(cls, id)
	var tag := "%s q%d%s" % [id, quality, " companion" if companion else ""]
	await get_tree().process_frame
	var base := VfxBudget.counters()
	var caster: Node3D = hero
	if companion:
		var buddy := Companion.new()
		buddy.setup({"class": String(cls), "name": "Ally", "level": 100, "exp": 0, "gender": 0}, 0, hero, field)
		field.add_child(buddy)
		buddy.set_physics_process(false)
		buddy.target = mobs[0]
		buddy.mp = 100000
		await get_tree().process_frame
		base = VfxBudget.counters()
		buddy._cast(skill)
		caster = buddy
	else:
		Game.profile.mp = 100000
		hero.cooldowns.clear()
		hero._cast(skill)
	# The wind-up root opens in the cast's own frame (checked at once: a slow first frame
	# can carry the short wind-up past its end before the next one).
	var windup := false
	for root in _ours(field, id):
		if String(root.name).ends_with("_windup") and not (root as StarSkillArt).layers.is_empty():
			windup = true
	var release := false
	var layers := 0
	var foreign := ""
	var cap: int = [2, 4, 6][quality] if not companion else mini(G.LITE_CAP, [2, 4, 6][quality])
	var end := Time.get_ticks_msec() + int((float(skill.hit_delay) + 0.5) / Engine.time_scale * 1000.0)
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame
		for root in _ours(field, id):
			var art := root as StarSkillArt
			layers = maxi(layers, art.layers.size())
			if String(art.name).ends_with("_windup") and not art.layers.is_empty():
				windup = true
			elif not art.layers.is_empty():
				release = true
			check(art.layers.size() <= cap, "layer cap per root %s (%d > %d)" % [tag, art.layers.size(), cap])
		if foreign == "":
			foreign = _foreign(field)
	check(windup, "signature wind-up draws " + tag)
	check(release, "signature release draws " + tag)
	check(layers > 0, "signature layers " + tag)
	check(foreign == "", "no shared class overlay under the signature %s (%s)" % [tag, foreign])
	# Every root of the set piece has finished shortly after the cast.
	await get_tree().create_timer(2.8).timeout
	check(_ours(field, id).is_empty(), "signature roots freed after the cast %s (%d left)" % [tag, _ours(field, id).size()])
	check(is_instance_valid(caster), "caster survives " + tag)
	field.queue_free()
	await field.tree_exited
	await get_tree().process_frame
	check(VfxBudget.counters() == base, "VfxBudget back to baseline %s %s vs %s" % [tag, str(VfxBudget.counters()), str(base)])


## The defender dies just after World Bastion lands: the fortress, its waves and its sky go.
func _death_after_release() -> void:
	var made := _field(&"defender")
	var field: Node3D = made[0]
	var hero: Hero = made[1]
	var skill := _skill(&"defender", "world_bastion")
	Game.profile.mp = 100000
	hero._cast(skill)
	await get_tree().create_timer(float(skill.hit_delay) + 0.15).timeout
	check(_ours(field, "world_bastion").size() >= 2, "world bastion under way")
	hero._dead = true
	await get_tree().create_timer(0.5).timeout
	check(_ours(field, "world_bastion").is_empty(), "the set piece closes with its caster (%d roots left)" % _ours(field, "world_bastion").size())
	field.queue_free()
	await field.tree_exited
	await get_tree().process_frame
	check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "budget released after a death mid-cast " + str(VfxBudget.counters()))


## The assassin dies in the wind-up of Midnight Execution: the moon and the dive go at once
## and nothing lands.
func _death_in_windup() -> void:
	var made := _field(&"assassin")
	var field: Node3D = made[0]
	var hero: Hero = made[1]
	var skill := _skill(&"assassin", "midnight_execution")
	Game.profile.mp = 100000
	hero._cast(skill)
	await get_tree().process_frame
	await get_tree().process_frame
	check(not _ours(field, "midnight_execution").is_empty(), "midnight execution wind-up under way")
	hero._die()
	await get_tree().create_timer(0.3).timeout
	check(_ours(field, "midnight_execution").is_empty(), "the wind-up closes with its caster (%d roots left)" % _ours(field, "midnight_execution").size())
	await get_tree().create_timer(float(skill.hit_delay) + 0.3).timeout
	check(_ours(field, "midnight_execution").is_empty(), "nothing lands after the caster died")
	field.queue_free()
	await field.tree_exited
	await get_tree().process_frame
	check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "budget released after a death in the wind-up " + str(VfxBudget.counters()))
