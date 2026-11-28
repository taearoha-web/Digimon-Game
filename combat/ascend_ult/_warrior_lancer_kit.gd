extends Node3D
## Shared base of two ★500 ultimates with mechanics of their own (AscendUlt): the Warrior's
## ดาบเหินฟ้า (emperor_heavensword.gd) and the Lancer's หอกพายุบูมเมอแรง
## (dragon_emperor_lance.gd). A kit, never a skill's own script (its name starts with "_").
##
## What it holds for them: who cast (the hero or an AI player), the whole multiplier the
## cast spreads over its blows (skill.mult x the hero's rank power, or the AI's SKILL_POWER
## x its rank power: as StarSkillSequence and Rival._resolve compute it), the caster check
## that stops a cast at once (freed, fallen, off its field, in the safe zone, its duel
## over), the foes round a point, one blow of a share of that multiplier (Hero._deal /
## Rival._hit) with its ledger (dealt: share per struck foe), the caster's visual and its
## clips, the hero's room of VfxBudget, and the wind funnel both draw
## (shaders/ascend_wind_funnel.gdshader).

const FUNNEL := preload("res://shaders/ascend_wind_funnel.gdshader")

var caster: Node3D
var skill: Dictionary = {}
var by_hero := false
## The whole multiplier on one foe, spread over the cast's blows.
var total_mult := 0.0
## Whether the cast's own set pieces show (always for the hero; an AI's above low quality).
var shown := true
var color := Color.WHITE
var light := Color.WHITE
var shade := Color.BLACK
var clock := 0.0
var done := false
## instance id -> the share of total_mult it has taken; and the blows dealt in all.
var dealt := {}
var blows := 0
var _field: Node3D
var _zone: StringName
## The hero's strikes: the skill without its effects (each blow), and with them (the last).
var _plain := {}


func _setup(who: Node3D, p_skill: Dictionary, hero_side: bool, mult: float) -> void:
	caster = who
	skill = p_skill
	by_hero = hero_side
	total_mult = mult
	_field = get_parent() as Node3D
	_zone = Game.current_zone
	shown = hero_side or VfxBudget.quality() > 0
	var palette: Array = AscendSkillData.COLORS.get(String(skill.get("id", "")), [])
	color = Color(palette[0]) if palette.size() > 0 else Color(skill.get("color", Color.WHITE))
	light = Color(palette[1]) if palette.size() > 1 else color.lerp(Color.WHITE, 0.7)
	shade = Color(palette[2]) if palette.size() > 2 else color.darkened(0.6)
	_plain = skill.duplicate()
	_plain["fx"] = {}


func _setup_hero(hero: Hero, p_skill: Dictionary) -> void:
	_setup(hero, p_skill, true, float(p_skill.get("mult", 0.0)) * hero.rank_mult(p_skill))


func _setup_rival(rival: Node3D, p_skill: Dictionary) -> void:
	var rank := int(rival.call("skill_rank", p_skill)) if rival.has_method("skill_rank") else 1
	_setup(rival, p_skill, false, float(p_skill.get("mult", 0.0)) * HeroStats.SKILL_POWER * SkillRank.power(rank))


func _exit_tree() -> void:
	done = true


## The caster can still fight this cast: alive, on this field, out of the safe zone, its duel on.
func _caller_ok() -> bool:
	if caster == null or not is_instance_valid(caster) or caster.is_queued_for_deletion() or not caster.is_inside_tree():
		return false
	if caster.has_method("is_dead") and caster.is_dead():
		return false
	if not is_instance_valid(_field) or _field.is_queued_for_deletion():
		return false
	if Game.current_zone != _zone:
		return false
	if caster is Hero:
		var hero := caster as Hero
		return hero.field == _field and not hero.safe_zone
	if caster is Rival:
		return not (caster as Rival).duel_over and caster.get_parent() == _field
	return caster.get_parent() == _field


## Every foe whose body reaches within [param radius] of [param at] (flat).
func _foes(at: Vector3, radius: float) -> Array:
	var out: Array = []
	if by_hero:
		var hero := caster as Hero
		for node in get_tree().get_nodes_in_group("mobs"):
			var mob := node as Mob
			if mob == null or not is_instance_valid(mob) or mob.is_dead() or mob.is_queued_for_deletion():
				continue
			if mob is CastleGate and not (mob as CastleGate).open_to(hero):
				continue
			if _flat(mob.global_position - at).length() <= radius + mob.body_radius():
				out.append(mob)
	elif caster is Rival:
		var rival := caster as Rival
		for node: Node3D in rival._targets():
			if rival._alive(node) and _flat(node.global_position - at).length() <= radius + _body(node):
				out.append(node)
	return out


func _valid(node: Variant) -> bool:
	if node == null or not is_instance_valid(node) or (node as Node).is_queued_for_deletion():
		return false
	if not by_hero and caster is Rival and is_instance_valid(caster):
		return (caster as Rival)._alive(node)
	return node.has_method("is_dead") and not node.is_dead()


## One blow: [param share] of the whole multiplier on [param foe]; [param final] carries the
## skill's effects (stun, armour break). Returns whether it was dealt.
func _strike(foe: Node3D, share: float, final: bool) -> bool:
	if done or not _valid(foe) or not _caller_ok():
		return false
	var mult := total_mult * share
	if by_hero:
		var hero := caster as Hero
		VfxBudget.hero_begin()
		hero._deal(foe as Mob, mult, color, &"light", false, skill if final else _plain)
		VfxBudget.hero_end()
	else:
		(caster as Rival)._hit(foe, mult, color, skill.get("fx", {}) if final else {})
	var key := foe.get_instance_id()
	dealt[key] = float(dealt.get(key, 0.0)) + share
	blows += 1
	return true


## The hero's beat of the cast (SkillFeel: punch, shake, hit-stop) round its hits.
func _beat(at: Vector3, radius: float, index: int, count: int) -> void:
	if by_hero and is_instance_valid(caster):
		SkillFeel.impact(caster, skill, at, radius, index, count)
		SkillFeel.area_from(at)


func _beat_done() -> void:
	if by_hero:
		SkillFeel.area_done()
		SkillFeel.beat_done()


## A real boss (never thrown); rivals and guild fighters are thrown like anyone (MuayThai.kick).
static func heavy(foe: Node3D) -> bool:
	if foe is CastleGate:
		return true
	return foe is Mob and (foe as Mob).is_boss and not (foe is Rival)


## Runs [param fn] (effects) in the hero's room of the visual budget for the hero's own.
func _with_room(fn: Callable) -> void:
	if by_hero:
		VfxBudget.hero_begin()
	fn.call()
	if by_hero:
		VfxBudget.hero_end()


func _sound(id: StringName, db: float) -> void:
	if id == &"" or not AudioManager.has_sound(id):
		return
	if by_hero:
		AudioManager.play_sfx(id, db)
	elif is_instance_valid(caster):
		AudioManager.play_sfx_at(caster.global_position, id, db - 4.0)


## The caster's body (the hero's HeroVisual, an AI's RivalVisual): what leaps and turns.
func _body_visual() -> Node3D:
	if not is_instance_valid(caster):
		return null
	var v: Variant = caster.get("visual")
	return v as Node3D if v is Node3D and is_instance_valid(v) else null


## The caster's HeroVisual (clips, the weapon grip).
func _hero_visual() -> HeroVisual:
	if not is_instance_valid(caster):
		return null
	if caster is Hero:
		return (caster as Hero).visual
	var rv: Variant = caster.get("_rv")
	if rv is RivalVisual and is_instance_valid(rv):
		return (rv as RivalVisual).hero_visual
	return null


## Plays the first of [param clips] the caster's rig has.
func _act(clips: Array, speed := 1.0) -> void:
	var hv := _hero_visual()
	if hv == null:
		return
	for clip in clips:
		if hv.has_clip(String(clip)):
			hv.action(String(clip), speed)
			return


func _caster_yaw() -> float:
	if caster is Hero:
		return float((caster as Hero)._facing)
	if caster is Rival:
		return float((caster as Rival)._yaw)
	return caster.rotation.y if is_instance_valid(caster) else 0.0


func _hit_point(foe: Node3D) -> Vector3:
	if foe.has_method("hit_point"):
		return foe.hit_point()
	return foe.global_position + Vector3.UP * 1.1


static func _body(foe: Node3D) -> float:
	return (foe as Mob).body_radius() if foe is Mob else 0.5


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


static func _forward(yaw: float) -> Vector3:
	return Vector3(sin(yaw), 0.0, cos(yaw))


## An open funnel of wind (bottom radius r0, top r1, height h) standing on its origin,
## drawn with the wind shader; null when the budget has no room. Counted as a decoration.
func _funnel(parent: Node3D, r0: float, r1: float, h: float, params := {}) -> MeshInstance3D:
	if not VfxBudget.can_decorate():
		return null
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = r0
	mesh.top_radius = r1
	mesh.height = h
	mesh.radial_segments = 28 if VfxBudget.quality() > 0 else 16
	mesh.rings = 4
	mesh.cap_top = false
	mesh.cap_bottom = false
	var mat := ShaderMaterial.new()
	mat.shader = FUNNEL
	mat.set_shader_parameter("color", color)
	mat.set_shader_parameter("core", light)
	for key in params:
		mat.set_shader_parameter(key, params[key])
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.position = Vector3.UP * h * 0.5
	VfxBudget.track_decoration(mi)
	return mi
