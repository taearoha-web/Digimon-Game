class_name Summon
extends Node3D
## A creature or floating blade an ally calls with a summoner skill: the hero's,
## a party companion's or (in a guild war) a fighter of our guild. It follows its
## summoner, picks the summoner's target (or the nearest monster) and attacks; the two
## legends (Wind Monkey King, Poseidon) also cast their two skills (LegendMoves)
## and the Fairy Spirit heals instead of fighting. It has its own health bar,
## monsters can attack it, and it lasts 2 minutes or until it is killed. Its size
## is 100% at 1 star, 110% at 2 stars and 150% at 5 stars (even steps between).

## Seconds a summon stays (2 minutes, every summon skill).
const LIFETIME := 120.0

## Heights are chosen so that a 5-star summon (150%) stands a little taller than the
## hero (~2.8 m with hair, ~2.0 m body): the biggest kinds top out around 3.0-3.2 m.
## The archer's spirit wolf is the one deliberate giant ("giant": true), three times the size it was first shown at.
const KINDS := {
	"falcon": {"model": "flying/Pigeon", "height": 0.8, "hover": 1.2, "tint": Color(1.6, 1.3, 0.5), "ranged": true, "speed": 7.0, "range": 7.0, "color": Color("ffd84a")},
	"wolf": {"model": "blob/Dog", "height": 1.4, "hover": 0.0, "tint": Color(0.85, 0.95, 1.3), "ranged": false, "speed": 6.5, "range": 1.8, "color": Color("bfe0ff")},
	"beast": {"model": "big/Dino", "height": 1.95, "hover": 0.0, "tint": Color(0.7, 1.4, 0.7), "ranged": false, "speed": 5.2, "range": 2.2, "color": Color("7aff8a")},
	"elemental": {"model": "flying/Ghost", "height": 1.2, "hover": 0.7, "tint": Color(0.7, 1.2, 1.7), "ranged": true, "speed": 5.0, "range": 8.0, "color": Color("7fe3ff"), "eye_fire": Color("4aa8ff")},
	# Chibi Demon (assets/models/monsters/summon): floats on its swimming idle, throws fire with a punch.
	"fire_elemental": {"model": "summon/ChibiDemon", "height": 2.15, "hover": 0.5, "tint": Color.WHITE, "ranged": true, "speed": 5.0, "range": 8.5, "color": Color("ff7a2a")},
	"muspell": {"model": "cute/Penguin", "height": 1.9, "hover": 0.0, "tint": Color.WHITE, "ranged": false, "speed": 4.8, "range": 2.6, "color": Color("aaf0ff")},
	# The archer's wolves: the realistic wolf, three times the size of the wolf the summoner keeps.
	"spirit_wolf": {"giant": true, "model": "star/Wolf", "height": 4.5, "hover": 0.0, "tint": Color.WHITE, "ranged": false, "speed": 6.5, "range": 3.6, "color": Color("bfe0ff")},
	# Legend summons of the summoner's star skills: hand-made models (decimated, re-baked and rigged
	# by tools/rig). "legend" lets them stand taller than the hero and gives them more health.
	# The king fights with his staff up close; Poseidon throws water from afar. Both have two skills (LegendMoves).
	"wind_king": {"legend": true, "model": "summon/WindKing", "height": 3.4, "hover": 0.0, "tint": Color.WHITE, "ranged": false, "speed": 6.4, "range": 3.4, "color": Color("7affb8"), "name": "ราชาวานรวายุ"},
	"poseidon": {"legend": true, "model": "summon/Poseidon", "height": 3.6, "hover": 0.0, "tint": Color.WHITE, "ranged": true, "speed": 5.6, "range": 9.0, "color": Color("5cc8ff"), "projectile": "orb", "name": "โพไซดอน"},
	# The Fairy Spirit: the chibi girl with the summoner's spirit-butterfly wings (FairyVisual).
	# She never fights: she keeps close to her summoner and heals (see _tick_fairy).
	"fairy": {"legend": true, "fairy": true, "model": "", "height": 1.5, "hover": 1.1, "tint": Color.WHITE, "ranged": false, "speed": 6.5, "range": 0.0, "color": Color("ffb6e6"), "name": "ภูตินางฟ้า"},
	"cactus": {"model": "cute/Cactus", "height": 1.95, "hover": 0.0, "tint": Color.WHITE, "ranged": false, "speed": 5.2, "range": 2.2, "color": Color("7aff8a")},
	"cat": {"model": "blob/Cat", "height": 1.4, "hover": 0.0, "tint": Color(1.5, 1.2, 0.8), "ranged": false, "speed": 7.0, "range": 1.7, "color": Color("ffd8a0")},
	"frog": {"model": "big/Frog", "height": 1.5, "hover": 0.0, "tint": Color(0.7, 1.4, 0.7), "ranged": true, "speed": 4.6, "range": 7.0, "color": Color("7fe07a")},
	"guardian": {"model": "big/Monkroose", "height": 2.0, "hover": 0.0, "tint": Color(1.3, 1.1, 0.8), "ranged": false, "speed": 5.0, "range": 2.4, "color": Color("c8a070")},
	"treant": {"model": "big/MushroomKing", "height": 2.1, "hover": 0.0, "tint": Color(0.8, 1.4, 0.6), "ranged": false, "speed": 4.4, "range": 2.6, "color": Color("b0e070")},
	"drake": {"model": "flying/Dragon", "height": 1.5, "hover": 0.9, "tint": Color(0.7, 1.5, 1.2), "ranged": true, "speed": 6.0, "range": 8.5, "color": Color("7affd0")},
	"elder_dragon": {"model": "flying/Dragon_Evolved", "height": 1.95, "hover": 0.8, "tint": Color(1.7, 1.4, 0.5), "ranged": true, "speed": 6.0, "range": 9.5, "color": Color("ffd84a")},
	"sword": {"proc": true, "real_sword": true, "hover": 1.7, "ranged": false, "speed": 9.0, "range": 1.6, "color": Color("e6f4ff")},
}
## Health as a share of the summoner's: legends stand longer, but no summon outlasts a swarm.
const HP_SHARE := 0.8
const LEGEND_HP_SHARE := 1.2
## A summon hits every second for minutes: each hit is this share of its skill's multiplier.
const HIT_SHARE := 0.14
## How often the Fairy Spirit heals, and how much: the summoner, then allies close to her.
const FAIRY_EVERY := 10.0
const FAIRY_HEAL := 0.2
const FAIRY_ALLY_HEAL := 0.1
const FAIRY_ALLY_RADIUS := 6.0

## Who called it: the hero, a companion or an allied guild fighter (Rival). [member hero]
## is set only for the hero's own summons (star-set bonus, HUD).
var summoner: Node3D
var hero: Hero
var skill_id := ""
var spec: Dictionary = {}
var damage_mult := 1.0
var life := LIFETIME
var rank := 1
var size_mult := 1.0
var max_hp := 1
var hp := 1

var _kind: Dictionary = {}
var _kind_id := "wolf"
var _visual: MonsterVisual
var _blade: Node3D
var _slot := 0
var _slots := 1
var _target: Mob
var _attack_timer := 0.5
var _age := 0.0
var _star_departed := false
var _fading := false
var _dead := false
var _bar: FieldHpBar
var _book := BuffBook.new()
var _sigil: MeshInstance3D
var _move_cds: Dictionary = {}
var _cast_until := 0.0
var _heal_timer := 3.0

const SPIRIT_SHADER := preload("res://shaders/vfx_spirit.gdshader")
## The three sword models a Dancing Sword cycles through, and how long they stand on screen.
const SWORD_MODELS: Array[String] = ["res://assets/models/weapons/sword_5.glb", "res://assets/models/weapons/sword_7.glb", "res://assets/models/weapons/sword_9.glb"]
const SWORD_LENGTH := 2.4
## Where a spirit flame sits on the face, as a fraction of body height (x is the half spacing).
const EYE_FIRE := Vector3(0.125, 0.62, 0.17)


## [param p_summoner]: the hero, a companion or an allied guild fighter.
func setup(p_summoner: Node3D, p_skill_id: String, p_spec: Dictionary, p_damage_mult: float, slot: int, slots: int, p_rank := 1) -> void:
	summoner = p_summoner
	hero = p_summoner as Hero
	skill_id = p_skill_id
	spec = p_spec
	damage_mult = p_damage_mult
	rank = clampi(p_rank, 1, 10)
	size_mult = size_for_rank(rank)
	life = float(spec.get("secs", LIFETIME))
	_kind_id = String(spec.get("kind", "wolf"))
	_kind = KINDS.get(_kind_id, KINDS["wolf"])
	var share := LEGEND_HP_SHARE if bool(_kind.get("legend", false)) else HP_SHARE
	max_hp = maxi(300, int(round(float(_summoner_stats().max_hp) * share * (1.0 + 0.6 * float(rank - 1)))))
	hp = max_hp
	_slot = slot
	_slots = maxi(slots, 1)
	for move in LegendMoves.moves(_kind_id):
		_move_cds[move.id] = randf_range(1.5, 3.0)


func is_fairy() -> bool:
	return bool(_kind.get("fairy", false))


func _ready() -> void:
	add_to_group("summons")
	var around := _formation()
	global_position = summoner.global_position + around
	if bool(_kind.get("proc", false)):
		_blade = _build_blade()
		add_child(_blade)
	elif is_fairy():
		var fairy := FairyVisual.new()
		add_child(fairy)
		fairy.setup_fairy()
		fairy.position.y = float(_kind.hover)
		_visual = fairy
	else:
		_visual = MonsterVisual.new()
		add_child(_visual)
		_visual.setup(String(_kind.model), float(_kind.height), float(_kind.hover), _kind.tint)
	_spiritify()
	if _kind.has("eye_fire"):
		_add_eye_fire()
	if skill_id in ["elder_dragon", "primal_legion"]:
		var crest := MeshInstance3D.new()
		crest.name = "AncientSummonCrest"
		crest.mesh = EliteSkillArt.geometry("crown" if skill_id == "elder_dragon" else "seal")
		var entry := ClassData.find_skill(&"summoner", skill_id)
		crest.material_override = EliteSkillArt.material(EliteSkillArt.palette(entry))
		crest.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		crest.position.y = float(_kind.height) + float(_kind.hover) + 0.10 if skill_id == "elder_dragon" else 0.04
		crest.scale = Vector3.ONE * (0.38 if skill_id == "elder_dragon" else 0.70)
		add_child(crest)
	scale = Vector3.ONE * 0.05
	create_tween().tween_property(self, "scale", Vector3.ONE * size_mult, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# A small gate at the actual creature, instead of a seven-metre light pillar.
	for family in SkillShow.FAMILY_COLORS:
		var entry := ClassData.find_skill(StringName(family), skill_id)
		if not entry.is_empty():
			var look := SkillShow.profile_for(entry)
			var arrival := SpellSpectacle._root(get_parent(), global_position, "CreatureArrival")
			var mat := SpellSpectacle._material(look, 0.7)
			SkillCraft.portal(arrival, look, mat, 0.8 * size_mult, 0.65)
			SpellSpectacle._finish(arrival, mat, 0.7)
			break
	# Health bar above the head (the node is scaled, so the bar is placed in local units).
	var top: float = (float(_kind.height) if _kind.has("height") else 1.8) + float(_kind.hover) + 0.5
	_bar = FieldHpBar.new()
	_bar.position = Vector3(0, top, 0)
	_bar.scale = Vector3.ONE * 1.3 / sqrt(size_mult)
	add_child(_bar)


## Summoned allies read as spirits, never as wild monsters: a pulsing glow along
## their outline in the summon's colour, a rune circle turning under their feet
## and a halo with sparkles around the body (see SummonAura).
func _spiritify() -> void:
	var color: Color = _kind.color
	var glow := ShaderMaterial.new()
	glow.shader = SPIRIT_SHADER
	glow.set_shader_parameter("color", color.lightened(0.15))
	for node in find_children("*", "MeshInstance3D", true, false):
		if _blade and _blade.is_ancestor_of(node) and bool(_kind.get("real_sword", false)):
			continue
		(node as MeshInstance3D).material_overlay = glow
	var mat := VfxKit._glow(color.lerp(Color.WHITE, 0.15), 0.85, false)
	mat.albedo_texture = VfxArt.texture("rune")
	_sigil = MeshInstance3D.new()
	_sigil.mesh = VfxKit.ground_quad()
	_sigil.material_override = mat
	_sigil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sigil.position = Vector3(0, 0.06, 0)
	_sigil.scale = Vector3.ONE * (0.9 if float(_kind.get("hover", 0.0)) > 0.5 else 1.15)
	add_child(_sigil)
	var spin := _sigil.create_tween().set_loops()
	spin.tween_property(_sigil, "rotation:y", TAU, 6.0).as_relative()
	SummonAura.attach(self, _kind_id, _kind, rank)


func _build_blade() -> Node3D:
	var root := Node3D.new()
	root.position.y = float(_kind.hover)
	if bool(_kind.get("real_sword", false)):
		var scene := load(SWORD_MODELS[_slot % SWORD_MODELS.size()]) as PackedScene
		if scene:
			var sword := scene.instantiate() as Node3D
			root.add_child(sword)
			# Point down and centre the sword on the spinning root, 2.4 m long.
			var box := MonsterVisual._bounds(sword)
			var fit := SWORD_LENGTH / maxf(maxf(box.size.x, maxf(box.size.y, box.size.z)), 0.001)
			sword.scale = Vector3.ONE * fit
			sword.rotation_degrees.z = 180.0
			var c := box.get_center() * fit
			sword.position = Vector3(c.x, c.y, -c.z)
			return root
	var blade := MeshInstance3D.new()
	blade.mesh = MeshKit.prism()
	blade.material_override = MeshKit.toon(Color("e6f4ff"), {"emission": 1.4})
	blade.scale = Vector3(0.22, 1.5, 0.08)
	blade.rotation_degrees = Vector3(180, 0, 0)
	root.add_child(blade)
	var guard := MeshInstance3D.new()
	guard.mesh = MeshKit.box()
	guard.material_override = MeshKit.toon(Color("ffd84a"), {"emission": 0.8})
	guard.scale = Vector3(0.5, 0.08, 0.1)
	guard.position.y = 0.78
	root.add_child(guard)
	return root


## A spirit flame burning in each eye (blue for the Spirit Elemental): a bright
## core and a flickering billboard flame. Positions are fractions of the body height.
func _add_eye_fire() -> void:
	var color: Color = _kind.eye_fire
	var h := float(_kind.height)
	var flame_mat := VfxKit._glow(Color(color.r * 1.8, color.g * 1.6, color.b * 2.2), 1.0, true)
	flame_mat.albedo_texture = VfxArt.texture("flame")
	flame_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var halo_mat := VfxKit._glow(Color(color.r * 1.2, color.g * 1.4, color.b * 1.8), 0.9, true)
	halo_mat.albedo_texture = VfxArt.texture("flare")
	halo_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var core_mat := VfxKit._glow(color.lerp(Color.WHITE, 0.35), 1.0, true)
	for side in [-1.0, 1.0]:
		var eye := Node3D.new()
		eye.name = "EyeFireL" if side < 0.0 else "EyeFireR"
		eye.position = Vector3(float(side) * EYE_FIRE.x * h, float(_kind.hover) + EYE_FIRE.y * h, EYE_FIRE.z * h)
		_visual.add_child(eye)
		var core := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.05 * h
		ball.height = 0.10 * h
		ball.radial_segments = 8
		ball.rings = 4
		core.mesh = ball
		core.material_override = core_mat
		core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		eye.add_child(core)
		var halo := MeshInstance3D.new()
		var halo_quad := QuadMesh.new()
		halo_quad.size = Vector2(0.4, 0.4) * h
		halo.mesh = halo_quad
		halo.material_override = halo_mat
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		eye.add_child(halo)
		var flame := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.45, 0.62) * h
		quad.center_offset = Vector3(0, 0.22 * h, 0)
		flame.mesh = quad
		flame.material_override = flame_mat
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		eye.add_child(flame)
		var flicker := flame.create_tween().set_loops()
		flicker.tween_interval(randf() * 0.12)
		flicker.tween_property(flame, "scale", Vector3(0.85, 1.25, 1.0), 0.16)
		flicker.tween_property(flame, "scale", Vector3(1.1, 0.85, 1.0), 0.13)


func _formation() -> Vector3:
	var angle := TAU * float(_slot) / float(_slots) + PI * 0.5
	var spread := 1.7 if is_fairy() else 2.6 + 1.2 * (size_mult - 1.0)
	return Vector3(cos(angle), 0.0, sin(angle)) * spread


# ---------------------------------------------------------------------------
# The summoner (hero, companion or allied fighter)
# ---------------------------------------------------------------------------

## atk / def / crit / max_hp of whoever called the summon.
func _summoner_stats() -> Dictionary:
	if summoner is Rival:
		return (summoner as Rival).rstats
	if "stats" in summoner:
		return summoner.stats
	return {"atk": 10.0, "def": 1.0, "crit": 0.0, "max_hp": 400}


func _summoner_alive() -> bool:
	if summoner == null or not is_instance_valid(summoner) or summoner.is_dead():
		return false
	return not (summoner is Rival and (summoner as Rival).duel_over)


## The summoner's own target, when it is a monster the summon can fight.
func _summoner_target() -> Mob:
	var t: Variant = null
	if summoner is Rival:
		t = (summoner as Rival)._victim
	elif "target" in summoner:
		t = summoner.target
	return t as Mob if t is Mob and _valid(t) else null


func _summoner_heal(fraction: float) -> void:
	if not _summoner_alive():
		return
	if hero:
		hero.receive_heal(fraction)
	elif summoner.has_method("heal_fraction"):
		summoner.heal_fraction(fraction)
	elif summoner.has_method("_heal"):
		summoner._heal(fraction)


## One basic hit before mitigation: the summoner's attack, the skill, the hit share
## and the hero's summoner star set.
func _basic_raw() -> float:
	var raw := float(_summoner_stats().atk) * damage_mult * HIT_SHARE
	if hero and StarProgression.has_full_set(Game.profile, "summoner"):
		raw *= 1.15
	return raw


func _process(delta: float) -> void:
	if not _summoner_alive():
		queue_free()
		return
	_age += delta
	life -= delta
	_book.tick(self, not _dead and not _fading, func(): return (float(_kind.height) if _kind.has("height") else 1.6) + float(_kind.hover))
	if skill_id == "eclipse_sovereign" and life <= 0.7 and not _star_departed and not _dead:
		_star_departed = true
		_star_wave(3.0, 7.5, 2)
	if life <= 0.0 and not _fading:
		_vanish()
	if _fading:
		return
	for id in _move_cds:
		_move_cds[id] = maxf(0.0, float(_move_cds[id]) - delta)
	if is_fairy():
		_tick_fairy(delta)
		return
	_attack_timer -= delta
	if not _valid(_target):
		_target = _pick_target()
	var goal := summoner.global_position + _formation()
	var want_range := 0.0
	if _valid(_target):
		goal = _target.global_position
		want_range = _reach() * 0.85
	var to := goal - global_position
	to.y = 0.0
	var speed := float(_kind.speed) * (1.0 + _book.total("speed"))
	var casting := _age < _cast_until
	if to.length() > want_range + 0.3 and not casting:
		var step := minf(to.length() - want_range, speed * delta * (1.0 if _valid(_target) else 1.6))
		global_position += to.normalized() * maxf(step, 0.0)
		_face(to, delta)
		if _visual:
			_visual.play("run" if speed > 4.0 else "walk")
	elif _visual:
		if _valid(_target):
			_face(_target.global_position - global_position, delta)
		_visual.play("idle")
	global_position.y = summoner.global_position.y
	if _blade:
		_blade.rotation.y += delta * 7.0
		_blade.position.y = float(_kind.hover) + sin(_age * 4.0 + float(_slot)) * 0.12
	if casting or not _valid(_target):
		return
	var dist := Vector2(_target.global_position.x - global_position.x, _target.global_position.z - global_position.z).length() - _target.body_radius()
	if _try_move(dist):
		return
	if _attack_timer <= 0.0 and dist <= _reach() + 0.4:
		_attack()


## The Fairy Spirit keeps close to her summoner and heals on her clock.
func _tick_fairy(delta: float) -> void:
	var goal := summoner.global_position + _formation()
	var to := goal - global_position
	to.y = 0.0
	if to.length() > 0.6:
		var step := minf(to.length() - 0.4, float(_kind.speed) * delta * 1.4)
		global_position += to.normalized() * maxf(step, 0.0)
		_face(to, delta)
		if _visual:
			_visual.play("run")
	else:
		var face := summoner.global_position - global_position
		if "target" in summoner and _valid(summoner.target):
			face = summoner.target.global_position - global_position
		_face(face, delta)
		if _visual:
			_visual.play("idle")
	global_position.y = summoner.global_position.y
	if _visual:
		_visual.position.y = float(_kind.hover) + sin(_age * 2.2) * 0.12
	_heal_timer -= delta
	if _heal_timer <= 0.0:
		_heal_timer = FAIRY_EVERY
		_fairy_heal()


## The heal: a soft pulse from the fairy, light rising around the summoner (+20%),
## then allies standing close to her (+10%).
func _fairy_heal() -> void:
	if _visual:
		_visual.action("attack", 700)
	var field := get_parent()
	var color: Color = _kind.color
	VfxKit.impact_ring(field, global_position + Vector3(0, float(_kind.hover) * 0.6, 0), color, FAIRY_ALLY_RADIUS * 0.55, 0.8)
	VfxArt.motes(field, global_position + Vector3(0, float(_kind.hover), 0), color.lightened(0.3), "heart", 10, 0.4, 1.4, 1.0)
	BattleVfx.floating_text(field, global_position + Vector3(0, float(_kind.hover) + 1.6, 0), "ฮีล +%d%%" % int(FAIRY_HEAL * 100.0), color, 0.9)
	_summoner_heal(FAIRY_HEAL)
	for node in get_tree().get_nodes_in_group("companions") + get_tree().get_nodes_in_group("summons"):
		if node == self or node == summoner or not is_instance_valid(node) or not node.has_method("heal_fraction"):
			continue
		if node.has_method("is_dead") and node.is_dead():
			continue
		if (node as Node3D).global_position.distance_to(global_position) <= FAIRY_ALLY_RADIUS:
			node.heal_fraction(FAIRY_ALLY_HEAL)


## Summons heal too (the fairy's allies, a priest's touch).
func heal_fraction(fraction: float) -> void:
	if _dead or _fading:
		return
	var before := hp
	hp = mini(max_hp, hp + int(float(max_hp) * fraction))
	_bar.set_ratio(float(hp) / float(max_hp))
	if hp > before:
		BattleVfx.floating_text(get_parent(), global_position + Vector3(0, (float(_kind.hover) + 1.8) * size_mult, 0), "+%d" % (hp - before), Color("6dff9a"), 0.8)


## Body size by skill stars: 1 = normal, 2 = +10%, 5 = +50%, evenly in between.
static func size_for_rank(stars: int) -> float:
	if stars <= 1:
		return 1.0
	return 1.10 + 0.40 * float(mini(stars, 5) - 2) / 3.0


func is_dead() -> bool:
	return _dead


## Buff skills of the summoner reach summons too: the aura shows, defence and speed
## apply (attack and crit already come through the summoner's own stats).
func receive_party_buff(buff: Dictionary, color: Color, label := "", p_skill_id := "") -> void:
	var prepared := buff.duplicate()
	if prepared.has("shield"):
		prepared["shield_left"] = int(max_hp * float(prepared.shield))
	_book.add(prepared, color, label, true, p_skill_id)


## Monsters and enemy fighters hit summons like any other ally. Legends keep 80% of
## the summoner's defence (others 60%). In a war or a ranked duel (the attacker fights
## with a war scale), BurstGuard caps one hit and one pile-on exactly as it does for the
## hero: the summon stands a while under fire and still falls to a swarm. Monsters in
## the field hit it in full, as they always did.
func take_damage(raw: float, attacker: Node = null) -> void:
	if _dead or _fading or not _summoner_alive():
		return
	var def_share := 0.8 if bool(_kind.get("legend", false)) else 0.6
	var amount := maxi(1, int(round(HeroStats.mitigate(raw, float(_summoner_stats().def) * def_share * (1.0 + _book.total("def"))))))
	amount = BuffBook.absorb(_book.buffs, amount)
	if attacker is Rival and (attacker as Rival).war_scale > 1.0:
		amount = BurstGuard.take(get_instance_id(), amount, max_hp)
	hp = maxi(0, hp - amount)
	_bar.set_ratio(float(hp) / float(max_hp))
	BattleVfx.floating_text(get_parent(), global_position + Vector3(0, (float(_kind.hover) + 1.8) * size_mult, 0), str(amount), Color("ff7a8a"), 1.0)
	if _visual:
		_visual.flash()
	if hp <= 0:
		_dead = true
		remove_from_group("summons")
		BurstGuard.forget(get_instance_id())
		BattleVfx.floating_text(get_parent(), global_position + Vector3(0, (float(_kind.hover) + 2.2) * size_mult, 0), "ซัมมอนถูกสังหาร", Color("ffb0b0"), 1.1)
		VfxKit.sparks(get_parent(), global_position + Vector3(0, 1.0, 0), _kind.color, 24, 4.0, 0.7)
		_vanish()


func _vanish() -> void:
	if _fading:
		return
	_fading = true
	remove_from_group("summons")
	BurstGuard.forget(get_instance_id())
	VfxArt.motes(get_parent(), global_position + Vector3(0, 0.8, 0), _kind.color.lightened(0.3), "star", 10, 0.8, 1.6, 0.9)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 0.05, 0.35)
	tween.tween_callback(queue_free)


func _face(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 0.001:
		return
	var yaw := atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-14.0 * delta))


## Bigger summons reach further.
func _reach() -> float:
	return float(_kind.range) * (1.0 + 0.5 * (size_mult - 1.0))


func _valid(mob: Variant) -> bool:
	return mob != null and is_instance_valid(mob) and not (mob as Mob).is_dead()


func _pick_target() -> Mob:
	var own := _summoner_target()
	if own:
		return own
	var best: Mob = null
	var best_d := 16.0
	for node in get_tree().get_nodes_in_group("mobs"):
		var mob := node as Mob
		if mob and not mob.is_dead():
			var d := Vector2(mob.global_position.x - summoner.global_position.x, mob.global_position.z - summoner.global_position.z).length()
			if d < best_d:
				best_d = d
				best = mob
	return best


## One hit on [param mob] (before mitigation: [param raw]), with the summoner credited.
func _hit(mob: Mob, raw: float) -> void:
	if not _valid(mob) or not _summoner_alive():
		return
	raw *= randf_range(0.92, 1.08)
	var crit := randf() < float(_summoner_stats().get("crit", 0.0))
	if crit:
		raw *= HeroStats.CRIT_DAMAGE
	var amount := maxi(1, int(round(HeroStats.mitigate(raw, float(mob.stats.def)))))
	VfxKit.impact(get_parent(), mob.hit_point(), _kind.color, 0.9)
	mob.take_hit(amount, crit, _kind.color, summoner)


func _attack() -> void:
	_attack_timer = float(spec.get("interval", 1.0))
	var mob := _target
	var color: Color = _kind.color
	if _visual:
		_visual.action("attack", 380 if not bool(_kind.get("legend", false)) else 700)
	var strike := func():
		if _dead or _fading or not _valid(mob) or not _summoner_alive():
			return
		_hit(mob, _basic_raw())
		if spec.has("heal") and not is_fairy():
			_summoner_heal(float(spec.heal))
	if bool(_kind.ranged):
		var from := global_position + Vector3(0, float(_kind.hover) + 0.8 * size_mult, 0)
		var to := mob.hit_point()
		var flight := clampf(from.distance_to(to) / 22.0, 0.1, 0.5)
		VfxKit.projectile(get_parent(), color, from, to, flight, 0.4 + 0.2 * (size_mult - 1.0), String(_kind.get("projectile", "spark")))
		get_tree().create_timer(flight).timeout.connect(strike, CONNECT_ONE_SHOT)
	else:
		get_tree().create_timer(0.18 if not bool(_kind.get("legend", false)) else 0.42).timeout.connect(strike, CONNECT_ONE_SHOT)


# ---------------------------------------------------------------------------
# Legend skills (LegendMoves): the king's whirlwind and staff slam, Poseidon's
# maelstrom and ice crystals
# ---------------------------------------------------------------------------

## Casts the first ready move whose area reaches the target. Returns true when one started.
func _try_move(dist: float) -> bool:
	for move in LegendMoves.moves(_kind_id):
		if float(_move_cds.get(move.id, 0.0)) > 0.0:
			continue
		var reach := float(move.radius) * 0.9 if String(move.shape) == "self" else _reach() + 1.0
		if dist > reach:
			continue
		_cast_move(move)
		return true
	return false


func _cast_move(move: Dictionary) -> void:
	_move_cds[move.id] = float(move.cd)
	_cast_until = _age + float(move.lock)
	_attack_timer = maxf(_attack_timer, float(move.lock) + 0.2)
	var center := global_position if String(move.shape) == "self" else _target.global_position
	center.y = summoner.global_position.y
	var radius := float(move.radius) * (1.0 + 0.3 * (size_mult - 1.0))
	var color: Color = LegendMoves.STYLE_COLORS.get(String(move.style), _kind.color)
	if _visual:
		_visual.action(String(move.clip), int(float(move.lock) * 1000.0))
	var field := get_parent()
	VfxKit.ground_circle(field, center, color, radius, float(move.impact) + 0.1)
	BattleVfx.floating_text(field, global_position + Vector3(0, (float(_kind.height) + 0.8) * size_mult, 0), String(move.name), color, 1.0)
	get_tree().create_timer(float(move.impact)).timeout.connect(func(): _land_move(move, center, radius), CONNECT_ONE_SHOT)


func _land_move(move: Dictionary, center: Vector3, radius: float) -> void:
	if _dead or _fading or not _summoner_alive():
		return
	var field := get_parent()
	LegendMoves.impact_vfx(field, String(move.style), center, radius)
	var raw := _basic_raw() * float(move.power)
	for node in get_tree().get_nodes_in_group("mobs"):
		var mob := node as Mob
		if mob and not mob.is_dead() and Vector2(mob.global_position.x - center.x, mob.global_position.z - center.z).length() <= radius + mob.body_radius():
			_hit(mob, raw)
			LegendMoves.afflict(move, mob)


## Poseidon's farewell: a great wave before he leaves.
func _star_wave(power: float, radius: float, index: int) -> void:
	if not _summoner_alive():
		return
	var entry := ClassData.find_skill(&"summoner", "eclipse_sovereign")
	StarSkillArt.strike(get_parent(), entry, global_position, index, summoner.global_position)
	for node in get_tree().get_nodes_in_group("mobs"):
		var mob := node as Mob
		if mob and not mob.is_dead() and mob.global_position.distance_to(global_position) <= radius + mob.body_radius():
			var raw := _basic_raw() * power
			mob.take_hit(maxi(1, int(HeroStats.mitigate(raw, float(mob.stats.def)))), false, _kind.color, summoner)
