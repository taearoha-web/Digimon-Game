extends Node3D
## Bard ★500 ระบำสะกดใจ (universe_hymn, AscendUlt): an enchanting dance tune. A stage of
## light opens where the bard aimed (a turning dance floor the size of the skill's radius,
## 10 m, a mirror ball over it, spotlights sweeping it); the opening chord strikes every
## foe on it (OPEN_SHARE) and charms them: each is made to dance for the skill's "stun"
## (3 s; Mob.apply_stun's rules, so a boss, a duel rival or a guild war fighter dances
## 40% of it, 1.2 s), held like a stun (no attack, no move, no skill), and while it dances
## it takes TAKEN (+20%) more damage from every hit, anyone's (Mob.apply_vulnerable, read
## by Mob.take_hit and GuildFighter._receive). The dancers hop, twirl and sway to the beat
## under a ring of music notes and hearts. When the tune ends (FINALE_AT, just after the
## longest dance) the finale bursts over the stage and strikes every foe on it
## (FINALE_SHARE).
##
## Damage: the skill's whole multiplier M (god mult x ULT_POWER, x star rank) on each foe,
## OPEN_SHARE + FINALE_SHARE = 1. The opening lands before the charm and the finale after
## the dance, so neither is raised by the dance's own vulnerability: the +20% is the
## party's (and the bard's other skills') window. Players are no dancers here: the hero
## and its companions have no stun in this game, so an AI's dance strikes them (the
## opening and the finale) without holding them, as every AI stun does.
##
## The node owns its clock (a child of the caster's field) and stops at once when the
## caster falls, is freed, leaves the field or the zone, enters a safe zone or ends its
## duel: the dancers are let go (their bodies set straight, the notes gone; the stun
## already given runs out on its own) and no finale lands. An AI player's cast charms and
## strikes the same (Rival._hit); its stage is lighter (no spotlights; no stage, ball or
## notes at low quality).

const KIT := preload("res://combat/ascend_ult/_pact_dance_kit.gd")
const ID := "universe_hymn"
const OPEN_SHARE := 0.3
const FINALE_SHARE := 0.7
const DANCE := 3.0
const TAKEN := 0.2
## The finale lands this long after the full dance ends.
const FINALE_AFTER := 0.2
const OUTRO := 0.9
const LEAD := 0.5
const BEAT := 0.5
## Dancers that get notes over their heads (the hero's cast / an AI's).
const NOTED_HERO := 12
const NOTED_AI := 5
## Rose pink, warm gold, deep plum (AscendSkillData.COLORS) and the stage's other lights.
const PINK := Color("ff5aa8")
const GOLD := Color("ffe9a0")
const PLUM := Color("3a0a3a")
const VIOLET := Color("b07aff")
const AQUA := Color("6ae8ff")
const NOTE_COLORS := [Color("ff7ac0"), Color("ffe27a"), Color("c69bff")]

var caster: Node3D
var by_hero := false
var skill: Dictionary = {}
var radius := 10.0
var center := Vector3.ZERO
var dance := DANCE
var taken := TAKEN
var total_mult := 0.0
var clock := 0.0
var gone := false
## For tests: blows struck, each foe's share (instance id -> share), who was made to dance.
var blows := 0
var dealt: Dictionary = {}
var charmed: Array = []
var finale_done := false
## Each dancer: {node, until, base_y, yaw, phase, hop, notes: Array}
var _dancers: Array = []
var _field: Node
var _zone: StringName
var _blow: Dictionary = {}
var _floor: MeshInstance3D
var _ball: MeshInstance3D
var _beams: Array = []
var _beat_wait := 0.0


static func lead(_skill: Dictionary) -> float:
	return LEAD


func begin_hero(hero: Hero, p_skill: Dictionary, aim: Vector3, _target: Mob) -> void:
	_begin(hero, true, p_skill, aim)


func begin_rival(rival: Rival, p_skill: Dictionary, aim: Vector3, _target: Node3D) -> void:
	_begin(rival, false, p_skill, aim)


func _begin(who: Node3D, hero_side: bool, p_skill: Dictionary, aim: Vector3) -> void:
	caster = who
	by_hero = hero_side
	skill = p_skill
	radius = float(skill.get("radius", 10.0))
	var fx: Dictionary = skill.get("fx", {})
	dance = float(fx.get("stun", DANCE))
	taken = float(fx.get("dance_taken", TAKEN))
	_field = get_parent()
	_zone = Game.current_zone
	_blow = KIT.strike(skill, {})
	center = KIT.flat(aim) if aim.is_finite() else KIT.flat(who.global_position)
	if not KIT.caster_ok(caster, _field, _zone):
		_finish()
		return
	global_position = center
	total_mult = KIT.total(caster, by_hero, skill)
	var foes := KIT.foes(caster, by_hero, center, radius)
	KIT.sound(by_hero, center, SkillSound.star_beat(0), -3.0)
	KIT.sound(by_hero, center, SkillSound.landing(skill), -7.0)
	_strike(foes, OPEN_SHARE, 0)
	# The charm: every foe still standing on the stage dances (its notes first: the dance
	# is what must show), then the stage.
	for foe in foes:
		if KIT.valid(caster, by_hero, foe):
			_charm(foe as Node3D)
	KIT.with_room(by_hero, _open_art.bind(foes))


func _process(delta: float) -> void:
	if gone:
		return
	if not KIT.caster_ok(caster, _field, _zone):
		_finish()
		return
	clock += delta
	KIT.with_room(by_hero, _tick_art.bind(delta))
	_tick_dancers()
	if not finale_done and clock >= dance + FINALE_AFTER:
		finale_done = true
		_finale()
	if finale_done and clock >= dance + FINALE_AFTER + OUTRO:
		_finish()


func _exit_tree() -> void:
	_release_all()


func _finish() -> void:
	if gone:
		return
	gone = true
	set_process(false)
	_release_all()
	queue_free()


# ---------------------------------------------------------------------------
# The charm and the blows
# ---------------------------------------------------------------------------

## Makes [param foe] dance: held by Mob.apply_stun (its boss / player rule decides how
## long), vulnerable for as long as it dances.
func _charm(foe: Node3D) -> void:
	if not (foe is Mob) or foe is CastleGate:
		return
	var mob := foe as Mob
	if mob.has_method("under_guard") and mob.call("under_guard"):
		return
	mob.apply_stun(dance)
	# How long it is held now (a boss / a player: 40%); a longer stun it had runs on.
	var held := minf(maxf(mob._stun, 0.0), dance)
	if held <= 0.0:
		return
	mob.apply_vulnerable(taken, held)
	charmed.append(mob)
	var visual := mob.get("visual") as Node3D
	var entry := {"node": mob, "until": clock + held, "base_y": visual.position.y if visual else 0.0,
		"yaw": visual.rotation.y if visual else 0.0, "phase": randf() * 2.0, "hop": clampf(mob.body_radius() * 0.45, 0.22, 0.7), "notes": []}
	var cap := NOTED_HERO if by_hero else NOTED_AI
	if _fancy() and _dancers.size() < cap:
		KIT.with_room(by_hero, func():
			var ring := KIT.notes(self, NOTE_COLORS, "DanceNotes")
			if ring:
				(entry.notes as Array).append_array(ring.get_children())
		)
	_dancers.append(entry)
	if by_hero or mob.visual.visible:
		BattleVfx.floating_text(_field, mob.top_point() + Vector3.UP * 0.7, "เต้น!", PINK, 0.85)


func _strike(foes: Array, share: float, index: int) -> void:
	if by_hero:
		SkillFeel.impact(caster, skill, center, radius, index, 2)
		SkillFeel.area_from(center)
	for foe in foes:
		if gone or not is_instance_valid(caster):
			break
		var id := (foe as Node).get_instance_id()
		dealt[id] = float(dealt.get(id, 0.0)) + share
		blows += 1
		KIT.deal(caster, by_hero, foe, total_mult * share, PINK, _blow)
	if by_hero:
		SkillFeel.area_done()
		SkillFeel.beat_done()


func _finale() -> void:
	_release_all()
	var foes := KIT.foes(caster, by_hero, center, radius)
	KIT.with_room(by_hero, _finale_art.bind(foes))
	KIT.sound(by_hero, center, SkillSound.star_beat(0), -2.0)
	KIT.sound(by_hero, center, SkillSound.landing(skill), -5.0)
	_strike(foes, FINALE_SHARE, 1)


# ---------------------------------------------------------------------------
# The dance (cosmetic: the hold is the stun, the vulnerability Mob's)
# ---------------------------------------------------------------------------

func _tick_dancers() -> void:
	var keep: Array = []
	for d in _dancers:
		var mob := d.node as Mob
		if not is_instance_valid(mob) or mob.is_dead() or clock >= float(d.until):
			_release(d)
			continue
		keep.append(d)
		var visual := mob.get("visual") as Node3D
		var t := clock + float(d.phase)
		if visual:
			# Two hops a beat-pair, a twirl, a sway from side to side.
			visual.position.y = float(d.base_y) + absf(sin(t * PI * 2.0)) * float(d.hop)
			visual.rotation.y = float(d.yaw) + t * TAU * 0.55
			visual.rotation.z = sin(t * PI * 2.0) * 0.17
		var notes: Array = d.notes
		var top := mob.top_point() + Vector3.UP * 0.45
		for k in notes.size():
			var card := notes[k] as Node3D
			if not is_instance_valid(card):
				continue
			var a := t * 2.4 + TAU * float(k) / float(maxi(notes.size(), 1))
			var lift := 0.18 * sin(t * 5.0 + float(k) * 2.0)
			card.global_position = top + Vector3(cos(a) * 0.75, lift + 0.2 * float(k % 2), sin(a) * 0.75)
	_dancers = keep


## Lets [param d] go: its body set straight, its notes gone.
func _release(d: Dictionary) -> void:
	var mob := d.node as Mob
	if is_instance_valid(mob):
		var visual := mob.get("visual") as Node3D
		if visual:
			visual.position.y = float(d.base_y)
			visual.rotation.y = float(mob.get("_yaw")) if mob.get("_yaw") != null else float(d.yaw)
			visual.rotation.z = 0.0
	for card in d.notes:
		if is_instance_valid(card):
			var ring := (card as Node).get_parent()
			if is_instance_valid(ring) and ring != self and not ring.is_queued_for_deletion():
				ring.queue_free()
	(d.notes as Array).clear()


func _release_all() -> void:
	for d in _dancers:
		_release(d)
	_dancers.clear()


# ---------------------------------------------------------------------------
# The stage (cosmetic only)
# ---------------------------------------------------------------------------

func _fancy() -> bool:
	return by_hero or VfxBudget.quality() > 0


func _open_art(foes: Array) -> void:
	VfxKit.flash(_field, center + Vector3.UP * 1.2, PINK, 3.2, 0.3)
	VfxKit.shockwave(_field, center + Vector3.UP * 0.12, PINK, radius)
	VfxKit.impact_ring(_field, center + Vector3.UP * 0.1, GOLD, radius * 0.6, 0.45, Color.WHITE, PLUM)
	VfxArt.motes(_field, center, PINK, "heart", 18, radius * 0.5, 0.4, 1.4)
	for foe in foes.slice(0, 10):
		VfxKit.impact(_field, KIT.hit_point(foe), PINK, 1.0)
	if not _fancy():
		return
	_floor = KIT.piece(self, "disc", KIT.material(KIT.FLOOR, PINK, VIOLET, PLUM, true, {"fade": 0.0, "speed": 1.0}), "DanceFloor")
	if _floor:
		_floor.position = Vector3.UP * 0.06
		_floor.scale = Vector3.ONE * radius
	_ball = KIT.piece(self, "ball", KIT.material(KIT.BALL, Color("e8e4ff"), Color.WHITE, Color("4a3a6a"), false, {"speed": 1.0}), "MirrorBall")
	if _ball:
		_ball.position = Vector3.UP * 6.2
		_ball.scale = Vector3.ONE * 0.75
	if by_hero:
		for c in [PINK, GOLD, VIOLET, AQUA]:
			var beam := KIT.piece(self, "cone", KIT.material(KIT.BEAM, c, (c as Color).lerp(Color.WHITE, 0.5), PLUM, true, {"fade": 0.0}), "Spotlight")
			if beam:
				_beams.append(beam)


func _tick_art(delta: float) -> void:
	var fade_in := clampf(clock / 0.3, 0.0, 1.0)
	var end := dance + FINALE_AFTER
	var fade_out := clampf((end + 0.5 - clock) / 0.5, 0.0, 1.0)
	if is_instance_valid(_floor):
		KIT.set_fade(_floor, fade_in * fade_out * 0.95)
		_floor.rotation.y += delta * 0.5
	if is_instance_valid(_ball):
		_ball.rotation.y += delta * 1.6
		KIT.set_fade(_ball, fade_out)
		_ball.position.y = 6.2 + 0.15 * sin(clock * 3.0)
	var top := global_position + Vector3.UP * 6.0
	for k in _beams.size():
		var beam := _beams[k] as MeshInstance3D
		if not is_instance_valid(beam):
			continue
		var a := clock * (0.9 + 0.25 * k) + TAU * float(k) / float(_beams.size())
		var reach := radius * (0.35 + 0.25 * sin(clock * 1.3 + float(k)))
		var foot := global_position + Vector3(cos(a) * reach, 0.05, sin(a) * reach)
		KIT.beam(beam, top, foot, 1.6)
		KIT.set_fade(beam, fade_in * fade_out * 0.8)
	# The beat: a ring under each dancer, hearts over the stage.
	_beat_wait -= delta
	if _beat_wait <= 0.0 and clock < end:
		_beat_wait = BEAT
		var shown := 0
		for d in _dancers:
			if shown >= 8:
				break
			var mob := d.node as Mob
			if is_instance_valid(mob):
				VfxKit.impact_ring(_field, KIT.flat(mob.global_position) + Vector3.UP * 0.08, NOTE_COLORS[shown % 3], 1.0 + mob.body_radius() * 0.5, 0.35)
				shown += 1
		VfxArt.motes(_field, center, NOTE_COLORS[int(clock / BEAT) % 3], "heart", 6, radius * 0.45, 0.6, 1.1)


func _finale_art(foes: Array) -> void:
	var top := center + Vector3.UP * 3.0
	VfxKit.flash(_field, top, Color.WHITE, 7.0, 0.42)
	VfxArt.rays_burst(_field, top, PINK, 6.5, 0.5, 1.4)
	VfxArt.star_flash(_field, center + Vector3.UP * 6.2, GOLD, 3.5, 0.45)
	VfxKit.shockwave(_field, center + Vector3.UP * 0.15, PINK, radius * 1.1)
	VfxKit.impact_ring(_field, center + Vector3.UP * 0.12, GOLD, radius * 0.8, 0.55, Color.WHITE, PLUM)
	VfxArt.motes(_field, center, PINK, "heart", 30, radius * 0.6, 0.5, 1.6)
	VfxKit.sparks(_field, top, GOLD, 36, 8.0, 0.9)
	for foe in foes.slice(0, 10):
		VfxKit.impact(_field, KIT.hit_point(foe), GOLD, 1.3)
		VfxArt.motes(_field, KIT.flat((foe as Node3D).global_position), NOTE_COLORS[randi() % 3], "heart", 6, 0.6, 1.2, 1.0)
	if is_instance_valid(_ball):
		VfxKit.sparks(_field, _ball.global_position, Color.WHITE, 24, 7.0, 0.7)
