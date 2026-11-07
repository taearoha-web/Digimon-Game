class_name Pet
extends Summon
## The hero's pet (PetData): it follows the hero everywhere, fights whatever the hero
## fights (or the nearest monster) and casts its unlocked skills by itself. A Summon
## underneath (group "summons"): monsters and enemy guild fighters attack it, the hero's
## buff skills reach it, the fairy heals it; it never expires, and when it falls it comes
## back to the hero PetData.RESPAWN seconds later. It lives in the zone (a zone change
## frees it with everything else; the next zone spawns a new one), and in the village it
## only walks along. Its stats are shares of the hero's current ones (PetData.stats_for).
##
## An AI player's pet (PetCrowd: a world player hunting in a field, a member of the hero's
## party) is the same pet in "lite" form: its owner is that player (stats and level are
## the owner's), it fights what the owner fights and casts its unlocked skills, but on a
## phone budget: no name tag, the shared ring, no skill effects, words or sounds (only the
## hits and their numbers), and it looks for a monster a few times a second, not every
## frame. It is in "ai_pets" (not "pets", the hero's own) and not in "summons": monsters
## leave it alone (it has no health bar and never falls).

## How far behind / beside the hero it walks, and past which distance it hops back
## to the hero (a warp, a knock-back across the field).
const FOLLOW_BACK := 2.0
const FOLLOW_SIDE := 1.6
const TELEPORT := 26.0
## How far from the hero it goes after a monster of its own choosing.
const LEASH := 14.0

var pet_id := ""
var pet: Dictionary = {}
var pstats: Dictionary = {}
## Seconds until a fallen pet stands up again (0 while it fights).
var respawn_left := 0.0
## Hits it dealt (tests, the HUD tooltip) and skills it cast, by id.
var dealt := 0
var casts: Dictionary = {}
## An AI player's pet (PetCrowd): its owner is not the hero, cheap presentation.
var lite := false

## Seconds between two looks for a monster of a lite pet's own choosing.
const LITE_RETARGET := 0.4
## The element rings under the pets: one mesh, one material per element, for all of them.
static var _ring_mesh: TorusMesh
static var _ring_mats: Dictionary = {}
var _retarget_in := 0.0

var _skill_cds: Dictionary = {}
var _gcd := 1.0
var _stats_timer := 0.0
var _hots: Array[Dictionary] = []
var _name_tag: Label3D
var _shadow: MeshInstance3D
## The form shown (PetData.stage_for of its owner's level and ★): -1 until the first look.
var stage := -1
var _since_hit := 0.0
var _regen_acc := 0.0
## Its owner's ★ (the hero's paragon level, an AI player's stars).
var owner_star := 0
## The form's layers (PetForm.build, PetForm.dress_lite) and what they were built for.
var form_root: Node3D
var _form_key := ""
var _aura: MeshInstance3D


## [param p_owner]: the hero. [param id]: its pet (PetData id).
func setup_pet(p_owner: Node3D, id: String) -> void:
	summoner = p_owner
	hero = p_owner as Hero
	lite = hero == null
	pet_id = id
	pet = PetData.get_pet(id)
	skill_id = "pet_" + id
	spec = {}
	rank = 1
	size_mult = 1.0
	life = INF
	_kind_id = "pet"
	_kind = {"model": String(pet.model), "height": float(pet.height), "hover": 0.0, "tint": pet.tint,
		"ranged": false, "speed": float(pet.speed), "range": float(pet.range), "color": pet.color}
	_refresh_stats(true)
	for skill in pet.skills:
		_skill_cds[String(skill.id)] = randf_range(1.0, 3.0)


func _ready() -> void:
	# Monsters go for the hero's pet (a summon); an AI player's pet is not a target (it
	# never falls) and needs no health bar.
	if not lite:
		add_to_group("summons")
	add_to_group("ai_pets" if lite else "pets")
	name = "AiPet" if lite else "Pet"
	global_position = summoner.global_position + _follow_spot()
	_visual = MonsterVisual.new()
	# An AI player's pet skips the ink outline below high quality (a second draw per mesh).
	_visual.outline = not lite or GameSettings.quality >= 2
	add_child(_visual)
	var skin: Texture2D = load(String(pet.skin)) as Texture2D if String(pet.get("skin", "")) != "" else null
	_visual.setup(String(pet.model), float(pet.height), 0.0, pet.tint, skin)
	_visual.add_to_group("anim_lod")
	_shadow = MeshKit.blob_shadow(self, 0.7)
	# A thin ring in the element's colour under its feet: a pet, not a monster or a hero.
	add_child(ring_for(pet_id))
	if lite:
		_apply_stage(false)
		_shadow.visibility_range_end = PetCrowd.HIDE
		_retarget_in = randf() * LITE_RETARGET
		scale = Vector3.ONE * 0.05
		create_tween().tween_property(self, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		return
	_bar = FieldHpBar.new()
	_bar.position = Vector3(0, float(pet.height) + 0.45, 0)
	_bar.scale = Vector3.ONE * 1.1
	add_child(_bar)
	_name_tag = Label3D.new()
	_name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_tag.pixel_size = 0.0028 * BattleVfx.text_scale
	_name_tag.font_size = 30
	_name_tag.outline_size = 8
	_name_tag.modulate = (pet.glow as Color).lightened(0.3)
	_name_tag.outline_modulate = Color(0.1, 0.12, 0.2, 0.9)
	_name_tag.position = Vector3(0, float(pet.height) + 0.75, 0)
	_name_tag.no_depth_test = true
	_name_tag.render_priority = 1
	add_child(_name_tag)
	# Its form: size, layers, and the bar and name over its head.
	_apply_stage(false)
	scale = Vector3.ONE * 0.05
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The thin element ring under a pet's feet (the hero's and every AI player's fighting
## pet): one shared torus and one material per element.
static func ring_for(id: String) -> MeshInstance3D:
	if _ring_mesh == null:
		_ring_mesh = TorusMesh.new()
		_ring_mesh.inner_radius = 0.55
		_ring_mesh.outer_radius = 0.64
		_ring_mesh.rings = 24
		_ring_mesh.ring_segments = 4
	if not _ring_mats.has(id):
		_ring_mats[id] = MeshKit.toon(PetData.get_pet(id).get("glow", Color.WHITE), {"unshaded": true, "emission": 0.8, "alpha": 0.8})
	var ring := MeshInstance3D.new()
	ring.name = "PetRing"
	ring.mesh = _ring_mesh
	ring.material_override = _ring_mats[id]
	ring.scale = Vector3(1, 0.1, 1)
	ring.position = Vector3(0, 0.05, 0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return ring


## Its owner's ★: the hero's (paragon level), an AI player's own (member sheet).
func owner_stars() -> int:
	if hero:
		return PetData.profile_stars(Game.profile)
	if "member" in summoner and summoner.member is Dictionary:
		return Game.party_stars(summoner.member)
	return 0


## Its owner's level: the hero's (Game.profile), an AI player's own (member sheet).
func owner_level() -> int:
	if hero:
		return int(Game.profile.get("level", 1))
	if "member" in summoner and summoner.member is Dictionary:
		return int((summoner.member as Dictionary).get("level", 1))
	if "level" in summoner:
		return int(summoner.level)
	return 1


## The form's Thai name now ("ร่างเทพ").
func form_name() -> String:
	return PetData.form_name(maxi(stage, 0))


func _update_name() -> void:
	if _name_tag:
		var line := "%s · %s Lv.%d" % [String(pet.name), form_name(), int(pstats.get("level", 1))]
		# The god form wears its title over the name, like a God hero's name plate.
		if stage >= PetData.GOD_STAGE:
			line = "✦ %s ✦\n%s" % [String(PetData.GOD_TITLES.get(pet_id, "เทพ")), line]
		_name_tag.text = line
		_name_tag.modulate = (pet.glow as Color).lightened(0.3) if stage < PetData.STAR_STAGE else (pet.glow as Color).lerp(PetForm.DIVINE, 0.25 * float(stage - 2)).lightened(0.25)


## Sizes the pet to its form (PetData.stage_for of its owner's level and ★) and dresses
## it (_dress); growing into a new form while the hero plays shows a burst of light and a
## message (PetForm.announce), grander for the star forms.
func _apply_stage(announce: bool) -> void:
	var level := int(pstats.get("level", 1))
	var next := PetData.stage_for(level, owner_star)
	if _visual == null:
		return
	if next == stage:
		_dress()
		return
	var grew := stage >= 0 and next > stage
	stage = next
	var k := float(PetData.STAGE_SCALE[stage])
	_visual.scale = Vector3.ONE * k
	if _shadow:
		_shadow.scale = Vector3.ONE * k
	var top := float(pet.height) * k
	# The holy and god forms wear a crown: the bar and the name sit over it.
	var crown := 0.3 if stage >= 4 and not lite else 0.0
	if _bar:
		_bar.position.y = top + 0.45 + crown
	if _name_tag:
		_name_tag.position.y = top + 0.75 + crown
	_update_name()
	_dress()
	if grew and announce and not lite and is_inside_tree():
		PetForm.announce(self, pet_id, stage, top)


## Puts on the layers of its form at the detail allowed now (PetForm.tier: the quality
## setting and memory pressure; checked again with the stats each second): the full set
## on the hero's pet, the cheap set (PetForm.dress_lite) on an AI player's.
func _dress() -> void:
	# A lite pet's dressing changes with the crowd rim (quality, memory pressure) only.
	var detail := (-1 if PetForm.crowd_rim() else -2) if lite else PetForm.tier()
	var key := "%d|%d" % [stage, detail]
	if key == _form_key or _visual == null:
		return
	_form_key = key
	PetForm.clear(form_root)
	form_root = null
	_aura = null
	var h := float(pet.height)
	if lite:
		form_root = PetForm.dress_lite(self, _visual, pet_id, stage, h, PetCrowd.HIDE)
	else:
		form_root = PetForm.build(self, _visual, pet_id, stage, h, detail)
	if form_root:
		form_root.scale = Vector3.ONE * float(PetData.STAGE_SCALE[stage])
		_aura = form_root.get_node_or_null("PetAura") as MeshInstance3D


## Recomputes ATK / HP / DEF / crit from the hero's stats now (keeps the health share).
func _refresh_stats(full := false) -> void:
	var owner_stats: Dictionary = {}
	if summoner is Rival:
		owner_stats = (summoner as Rival).rstats
	elif "stats" in summoner and summoner.stats is Dictionary:
		owner_stats = summoner.stats
	var level := owner_level()
	owner_star = owner_stars()
	var before_level := int(pstats.get("level", 0))
	var ratio := 1.0 if full or max_hp <= 0 else float(hp) / float(max_hp)
	pstats = PetData.stats_for(pet_id, owner_stats, level)
	max_hp = int(pstats.max_hp)
	if not _dead:
		hp = clampi(int(round(float(max_hp) * ratio)), 1, max_hp)
	if before_level != int(pstats.level):
		_update_name()
	_apply_stage(not full)
	if _bar:
		_bar.set_ratio(float(hp) / float(max_hp))


## The pet's own numbers stand in for the summoner's (Summon uses them for defence).
func _summoner_stats() -> Dictionary:
	return {"atk": float(pstats.get("atk", 4.0)), "def": float(pstats.get("def", 0.0)), "crit": float(pstats.get("crit", 0.0)), "max_hp": max_hp}


func _basic_raw() -> float:
	return float(pstats.get("atk", 4.0))


## The hero is home (the village) or gone: the pet only walks along, no fighting.
## An AI player's pet rests while its owner is down or away (PetCrowd brings fighting
## pets into the fields only).
func _peaceful() -> bool:
	if lite:
		return not summoner.visible or (summoner.has_method("is_dead") and summoner.is_dead())
	return hero == null or hero.safe_zone or hero.is_dead()


## Where it walks relative to the hero: behind and a little to the left of the way the
## camera (else the hero) looks, so it does not stand between the camera and the hero.
func _follow_spot() -> Vector3:
	var yaw := 0.0
	if lite:
		# An AI player's pet walks behind its owner (no camera to keep clear).
		return PetFollower.spot_behind(summoner, FOLLOW_SIDE, FOLLOW_BACK)
	if "camera_rig" in summoner and summoner.camera_rig:
		yaw = float(summoner.camera_rig.yaw)
	elif "_facing" in summoner:
		yaw = float(summoner._facing) + PI
	return Vector3(-FOLLOW_SIDE, 0.0, -FOLLOW_BACK).rotated(Vector3.UP, yaw)


func _process(delta: float) -> void:
	if summoner == null or not is_instance_valid(summoner) or summoner.is_queued_for_deletion():
		queue_free()
		return
	_age += delta
	_stats_timer -= delta
	if _stats_timer <= 0.0:
		_stats_timer = 1.0
		_refresh_stats()
	_tick_hots(delta)
	if _dead:
		respawn_left -= delta
		if respawn_left <= 0.0:
			_respawn()
		return
	# Out of the fight for a moment: it catches its breath (PetData.REGEN).
	_since_hit += delta
	if _since_hit >= PetData.REGEN_AFTER and hp < max_hp:
		_regen_acc += float(max_hp) * PetData.REGEN * delta
		if _regen_acc >= 1.0:
			hp = mini(max_hp, hp + int(_regen_acc))
			_regen_acc -= floorf(_regen_acc)
			if _bar:
				_bar.set_ratio(float(hp) / float(max_hp))
	_book.tick(self, true, func(): return float(pet.height))
	for id in _skill_cds:
		_skill_cds[id] = maxf(0.0, float(_skill_cds[id]) - delta)
	_gcd = maxf(0.0, _gcd - delta)
	_attack_timer -= delta
	var peaceful := _peaceful()
	var look := true
	if lite and not _valid(_target):
		# A lite pet looks for a monster of its own a few times a second, not every frame.
		_retarget_in -= delta
		look = _retarget_in <= 0.0
		if look:
			_retarget_in = LITE_RETARGET
	if peaceful:
		_target = null
	elif look and (not _valid(_target) or _flat(_target.global_position - summoner.global_position).length() > LEASH + 4.0):
		_target = _pick_target()
		if _target and _flat(_target.global_position - summoner.global_position).length() > LEASH:
			_target = null
	var goal := summoner.global_position + _follow_spot()
	var want := 0.25
	if _valid(_target):
		goal = _target.global_position
		want = _reach() * 0.85
	var to := _flat(goal - global_position)
	if _flat(summoner.global_position - global_position).length() > TELEPORT:
		global_position = summoner.global_position + _follow_spot()
		to = Vector3.ZERO
	var casting := _age < _cast_until
	var speed := float(pet.speed) * (1.0 + _book.total("speed"))
	if to.length() > want + 0.3 and not casting:
		var hurry := 1.0 if _valid(_target) else clampf(to.length() / 4.0, 1.0, 2.2)
		var step := minf(to.length() - want, speed * delta * hurry)
		global_position += to.normalized() * maxf(step, 0.0)
		_face(to, delta)
		_visual.play("run" if speed * hurry > 6.5 or _valid(_target) else "walk")
	else:
		if _valid(_target):
			_face(_target.global_position - global_position, delta)
		elif not casting:
			_face(summoner.global_position - global_position + Vector3(0, 0, 0.001), delta * 0.3)
		_visual.play("idle")
	global_position.y = summoner.global_position.y
	if peaceful or casting:
		return
	if _gcd <= 0.0 and _try_skill():
		return
	if not _valid(_target):
		return
	var dist := _flat(_target.global_position - global_position).length() - _target.body_radius()
	if _attack_timer <= 0.0 and dist <= _reach() + 0.4:
		_basic_attack()


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _reach() -> float:
	return float(pet.range)


# ---------------------------------------------------------------------------
# Hitting
# ---------------------------------------------------------------------------

## One hit of [param power] x the pet's ATK on [param mob] (mitigated by its DEF), the
## hero credited (threat, kills and loot are the hero's). Returns the damage.
func strike(mob: Mob, power: float, fx := {}) -> int:
	if not _valid(mob) or _dead:
		return 0
	var raw := _basic_raw() * power * randf_range(0.92, 1.08)
	var crit := randf() < float(pstats.get("crit", 0.0))
	if crit:
		raw *= HeroStats.CRIT_DAMAGE
	var amount := maxi(1, int(round(HeroStats.mitigate(raw, float(mob.stats.def)))))
	if not lite:
		VfxKit.impact(get_parent(), mob.hit_point(), pet.color, 0.8)
	var killed := mob.take_hit(amount, crit, pet.color, summoner)
	dealt += amount
	if killed or not _valid(mob):
		return amount
	if fx.has("burn"):
		mob.apply_burn(HeroStats.burn_dps(_basic_raw(), float(fx.burn[0]), float(mob.stats.def)), float(fx.burn[1]))
		if "burn_source" in mob:
			mob.burn_source = summoner
	if fx.has("slow"):
		mob.apply_slow(float(fx.slow))
	if fx.has("stun"):
		mob.apply_stun(float(fx.stun))
	if fx.has("knock"):
		mob.knock_back(global_position, float(fx.knock))
	return amount


func _basic_attack() -> void:
	_attack_timer = PetData.ATTACK_INTERVAL
	var mob_ref: WeakRef = weakref(_target)
	_visual.action("attack", 420)
	get_tree().create_timer(0.22).timeout.connect(func():
		var victim := mob_ref.get_ref() as Mob
		if is_instance_valid(self) and not _dead and _valid(victim):
			strike(victim, 1.0), CONNECT_ONE_SHOT)


## The living monsters within [param radius] of [param center].
func _mobs_in(center: Vector3, radius: float) -> Array[Mob]:
	var out: Array[Mob] = []
	for node in get_tree().get_nodes_in_group("mobs"):
		var mob := node as Mob
		if mob and not mob.is_dead() and _flat(mob.global_position - center).length() <= radius + mob.body_radius():
			out.append(mob)
	return out


# ---------------------------------------------------------------------------
# Skills (PetData kits)
# ---------------------------------------------------------------------------

## Casts the first unlocked skill that is ready and useful now (the ultimate and the
## hero's heals first). Returns true when one started.
func _try_skill() -> bool:
	# Asked every frame the pet is free: the unlocked list (last first) is built once a level.
	var level := int(pstats.get("level", 1))
	if level != _skills_level:
		_skills_level = level
		_skills_last_first = PetData.unlocked(pet_id, level)
		_skills_last_first.reverse()
	var skills := _skills_last_first
	var owner_rate := _owner_hp_rate()
	var fighting := _valid(_target)
	var dist := 999.0
	if fighting:
		dist = _flat(_target.global_position - global_position).length() - _target.body_radius()
	for skill in skills:
		if float(_skill_cds.get(String(skill.id), 0.0)) > 0.0:
			continue
		var ok := false
		match String(skill.kind):
			"owner_heal":
				ok = owner_rate < float(skill.get("below", 0.75))
			"owner_hot":
				ok = owner_rate < 0.9 or (fighting and owner_rate < 1.0)
			"owner_buff", "self_buff":
				ok = fighting and dist < 9.0
			"bolt", "blast", "pull":
				ok = fighting and dist <= float(skill.get("range", 9.0))
			"bite":
				ok = fighting and dist <= _reach() + 0.6
			"cone", "line":
				ok = fighting and dist <= float(skill.get("range", 6.0)) * 0.9
			"nova":
				ok = fighting and dist <= float(skill.get("radius", 4.0)) * 0.9
		if ok:
			cast(skill)
			return true
	return false


var _skills_level := -1
var _skills_last_first: Array = []


func _owner_hp_rate() -> float:
	if lite:
		if not ("hp" in summoner and "max_hp" in summoner) or (summoner.has_method("is_dead") and summoner.is_dead()):
			return 1.0
		return float(summoner.hp) / maxf(float(summoner.max_hp), 1.0)
	if hero == null or hero.is_dead():
		return 1.0
	return float(Game.profile.get("hp", 1)) / maxf(float(hero.stats.get("max_hp", 1)), 1.0)


## Casts [param skill] (a PetData skill) now, whatever its cooldown (tests use it too).
func cast(skill: Dictionary) -> void:
	var id := String(skill.id)
	_skill_cds[id] = float(skill.cd)
	_gcd = PetData.SKILL_GAP
	casts[id] = int(casts.get(id, 0)) + 1
	var lock := 0.55
	_cast_until = _age + lock
	_attack_timer = maxf(_attack_timer, lock + 0.2)
	_visual.action(String(skill.get("clip", "attack")), int(lock * 1000.0) + 150)
	var field := get_parent()
	var color: Color = pet.color
	if not lite:
		BattleVfx.floating_text(field, global_position + Vector3(0, float(pet.height) + 1.1, 0), String(skill.name), (pet.glow as Color), 0.85 if not bool(skill.get("ultimate", false)) else 1.15)
	var kind := String(skill.kind)
	var fx: Dictionary = skill.get("fx", {})
	var power := float(skill.get("power", 1.0))
	match kind:
		"bolt":
			var mob := _target
			var ref: WeakRef = weakref(mob)
			var from := global_position + Vector3(0, float(pet.height) * 0.7, 0)
			var flight := clampf(from.distance_to(mob.hit_point()) / 20.0, 0.1, 0.45)
			if not lite:
				VfxKit.projectile(field, color, from, mob.hit_point(), flight, 0.5, String(skill.get("projectile", {"fire": "flame", "water": "shard"}.get(pet_id, "orb"))))
			_later(flight, func():
				var victim := ref.get_ref() as Mob
				if _valid(victim):
					_element_hit(victim.hit_point())
					strike(victim, power, fx))
		"bite":
			var ref: WeakRef = weakref(_target)
			_later(0.25, func():
				var victim := ref.get_ref() as Mob
				if _valid(victim):
					_element_hit(victim.hit_point())
					strike(victim, power, fx))
		"cone", "line":
			var aim := _flat(_target.global_position - global_position)
			if aim.length_squared() < 0.01:
				aim = Vector3(sin(rotation.y), 0, cos(rotation.y))
			aim = aim.normalized()
			var hits := int(skill.get("hits", 1))
			for k in hits:
				_later(0.25 + 0.45 * k, func(): _sweep(skill, aim, power, fx))
		"blast", "pull":
			var center := _target.global_position
			var radius := float(skill.get("radius", 3.0))
			var delay := float(skill.get("delay", 0.3))
			if not lite:
				VfxKit.ground_circle(field, center, color, radius, delay + 0.15)
			if pet_id == "fire" and delay >= 0.5 and not lite:
				VfxKit.meteor(field, center, color, delay, radius, func(): pass)
			var hits := int(skill.get("hits", 1))
			for k in hits:
				_later(delay + 0.5 * k, func(): _burst(skill, center, radius, power, fx, kind == "pull"))
		"nova":
			_later(0.3, func(): _burst(skill, global_position, float(skill.get("radius", 4.0)), power, fx, false))
		"owner_buff":
			if lite:
				if summoner.has_method("receive_party_buff") and not (summoner.has_method("is_dead") and summoner.is_dead()):
					summoner.receive_party_buff(skill.buff, color, buff_label(skill), "pet_%s_%s" % [pet_id, id])
			elif hero and not hero.is_dead():
				hero.receive_buff(skill.buff, color, buff_label(skill), true, "pet_%s_%s" % [pet_id, id])
				VfxKit.aura(field, hero.global_position, (pet.glow as Color))
		"owner_heal":
			if lite:
				_later(0.3, func(): _summoner_heal(float(skill.heal)))
			elif hero and not hero.is_dead():
				VfxKit.projectile(field, Color("6dff9a"), global_position + Vector3(0, float(pet.height) * 0.7, 0), hero.global_position + Vector3(0, 1.2, 0), 0.3, 0.4, "orb")
				_later(0.3, func():
					if hero and not hero.is_dead():
						hero.receive_heal(float(skill.heal)))
		"owner_hot":
			_hots.append({"skill": id, "heal": float(skill.heal), "every": float(skill.every), "left": int(skill.ticks), "timer": 0.05})
			if hero and not lite:
				VfxKit.column_rain(field, hero.global_position, 3.0, (pet.glow as Color), 8, 0.9, 7.0)
		"self_buff":
			var buff: Dictionary = (skill.buff as Dictionary).duplicate()
			_book.add(buff, color, String(skill.name), false, "pet_" + id)
			if not lite:
				VfxKit.aura(field, global_position, (pet.glow as Color))
			if skill.has("taunt"):
				for mob in _mobs_in(global_position, float(skill.get("radius", 6.0))):
					mob.taunt(self, float(skill.taunt))
			if power > 0.0 and skill.has("radius") and not skill.has("taunt"):
				_later(0.3, func(): _burst(skill, global_position, float(skill.radius), power, fx, false))
	if not lite:
		AudioManager.play_sfx(&"buff" if kind.begins_with("owner") or kind == "self_buff" else &"hit_special", -6.0)


## The Thai name a pet's buff wears in the hero's buff list: "ปลุกพลัง · คาอิจูเร็กซ์".
func buff_label(skill: Dictionary) -> String:
	return "%s · %s" % [String(skill.name), String(pet.name)]


func _later(seconds: float, call: Callable) -> void:
	get_tree().create_timer(seconds).timeout.connect(func():
		if is_instance_valid(self) and is_inside_tree() and not _dead:
			call.call(), CONNECT_ONE_SHOT)


## An element-flavoured hit spark (theme only: no element damage rules anywhere).
func _element_hit(pos: Vector3) -> void:
	if lite:
		return
	var field := get_parent()
	match pet_id:
		"fire":
			ElementFx.flame_hit(field, pos)
		"water":
			ElementFx.ice_hit(field, pos)
		_:
			VfxKit.impact_smoke(field, pos, pet.color, 0.8)


## A circle of damage at [param center]; a pull drags the monsters in toward it.
func _burst(skill: Dictionary, center: Vector3, radius: float, power: float, fx: Dictionary, pull: bool) -> void:
	var field := get_parent()
	match pet_id if not lite else "":
		"":
			pass
		"fire":
			ElementFx.fire_field(field, center, radius, 2 if bool(skill.get("ultimate", false)) else 1)
		"water":
			if pull:
				VfxKit.vortex(field, center, pet.color, 2.6, 0.8)
			ElementFx.ice_field(field, center, radius, 1)
		_:
			VfxKit.slam(field, center, pet.color, radius)
	if not lite:
		VfxKit.impact_ring(field, center + Vector3(0, 0.1, 0), pet.color, radius, 0.45)
	for mob in _mobs_in(center, radius):
		strike(mob, power, fx)
		if pull and not mob.is_boss and _valid(mob):
			var dir := _flat(center - mob.global_position)
			if dir.length() > 0.8:
				mob.velocity += dir.normalized() * minf(dir.length() * 2.2, 7.0)


## A fan (cone) or a strip (line) from the pet along [param aim].
func _sweep(skill: Dictionary, aim: Vector3, power: float, fx: Dictionary) -> void:
	var field := get_parent()
	var reach := float(skill.get("range", 6.0))
	var line := String(skill.kind) == "line"
	var half_width := float(skill.get("width", 2.0)) * 0.5
	var half_angle := deg_to_rad(float(skill.get("angle", 70.0)) * 0.5)
	var origin := global_position
	for k in (0 if lite else 4):
		var spot := origin + aim * reach * (0.3 + 0.22 * k)
		match pet_id:
			"fire":
				ElementFx.flame_puff(field, spot + Vector3(0, 0.6, 0), 0.6 + 0.15 * k)
			"water":
				VfxKit.impact_fan(field, spot + Vector3(0, 0.4, 0), pet.color, 0.8 + 0.2 * k, "spark")
			_:
				VfxKit.spikes(field, spot, 0.9, pet.color, 4, 1.4, 0.1)
	for mob in _mobs_in(origin, reach):
		var rel := _flat(mob.global_position - origin)
		var along := rel.dot(aim)
		if along < -mob.body_radius():
			continue
		var inside := false
		if line:
			inside = absf(rel.cross(aim).y) <= half_width + mob.body_radius() and along <= reach + mob.body_radius()
		else:
			inside = rel.length() < 1.0 or absf(aim.signed_angle_to(rel.normalized(), Vector3.UP)) <= half_angle
		if inside:
			strike(mob, power, fx)


## Heal-over-time ticks on the hero (allies near the hero get their share through
## Hero._heal, as with any heal the hero receives).
func _tick_hots(delta: float) -> void:
	if _hots.is_empty():
		return
	for h in _hots:
		h.timer = float(h.timer) - delta
		if float(h.timer) <= 0.0 and int(h.left) > 0:
			h.timer = float(h.every)
			h.left = int(h.left) - 1
			if lite and not _dead:
				_summoner_heal(float(h.heal))
			elif hero and not hero.is_dead() and not _dead:
				hero.receive_heal(float(h.heal))
	_hots = _hots.filter(func(h): return int(h.left) > 0)


# ---------------------------------------------------------------------------
# Taking damage, falling and coming back
# ---------------------------------------------------------------------------

func take_damage(raw: float, attacker: Node = null) -> void:
	if _dead or not is_inside_tree():
		return
	_since_hit = 0.0
	var amount := maxi(1, int(round(HeroStats.mitigate(raw, float(pstats.get("def", 0.0)) * (1.0 + _book.total("def"))) * PetData.TAKEN)))
	amount = BuffBook.absorb(_book.buffs, amount)
	if attacker is Rival and (attacker as Rival).war_scale > 1.0:
		amount = BurstGuard.take(get_instance_id(), amount, max_hp)
	var back := BuffBook.reflect(_book.buffs)
	if back > 0.0 and attacker is Mob and _valid(attacker) and amount > 0:
		(attacker as Mob).take_hit(maxi(1, int(float(amount) * back)), false, pet.color, summoner)
	hp = maxi(0, hp - amount)
	if _bar:
		_bar.set_ratio(float(hp) / float(max_hp))
	BattleVfx.floating_text(get_parent(), global_position + Vector3(0, float(pet.height) + 0.6, 0), str(amount), Color("ff7a8a"), 0.9)
	_visual.flash()
	if hp <= 0:
		_fall()


func heal_fraction(fraction: float) -> void:
	if _dead:
		return
	var before := hp
	hp = mini(max_hp, hp + int(float(max_hp) * fraction))
	if _bar:
		_bar.set_ratio(float(hp) / float(max_hp))
	if hp > before:
		BattleVfx.floating_text(get_parent(), global_position + Vector3(0, float(pet.height) + 0.6, 0), "+%d" % (hp - before), Color("6dff9a"), 0.8)


func _fall() -> void:
	_dead = true
	respawn_left = PetData.RESPAWN
	_target = null
	_hots.clear()
	remove_from_group("summons")
	BurstGuard.forget(get_instance_id())
	_book.clear(self)
	_visual.hold("die")
	if not lite:
		BattleVfx.floating_text(get_parent(), global_position + Vector3(0, float(pet.height) + 1.0, 0), "%s หมดแรง! กลับมาใน %d วินาที" % [String(pet.name), int(PetData.RESPAWN)], Color("ffb0b0"), 1.0)
	var tween := create_tween()
	tween.tween_interval(1.4)
	tween.tween_property(self, "scale", Vector3.ONE * 0.05, 0.3)
	tween.tween_callback(func(): visible = false)


func _respawn() -> void:
	_dead = false
	respawn_left = 0.0
	_refresh_stats(true)
	hp = max_hp
	if _bar:
		_bar.set_ratio(1.0)
	if not lite:
		add_to_group("summons")
	global_position = summoner.global_position + _follow_spot()
	visible = true
	_visual.busy_until = 0
	_visual.current = ""
	_visual.play("idle")
	scale = Vector3.ONE * 0.05
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not lite:
		VfxArt.motes(get_parent(), global_position + Vector3(0, 0.8, 0), (pet.glow as Color), "star", 10, 0.8, 1.6, 0.9)
		BattleVfx.floating_text(get_parent(), global_position + Vector3(0, float(pet.height) + 1.0, 0), "%s กลับมาแล้ว!" % String(pet.name), (pet.glow as Color), 0.9)


## The pet never fades away like a summon (no lifetime): only its zone frees it.
func _vanish() -> void:
	pass
