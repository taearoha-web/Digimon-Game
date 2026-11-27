class_name ThotsakanForm
extends Node
## ★300 สิบเศียรสิบกรสะท้านสามภพ (three_realms_fist): the Muay Thai fighter TURNS INTO
## ทศกัณฐ์ for SECS seconds instead of calling a giant from the sky. On the release of its
## wind-up (StarSkillSequence for the hero, Rival._resolve for an AI player) the fighter
## grows to SCALE, an emerald sheen on its body, while the spirit of the ten-headed demon
## king stands up behind it (its ten heads crowning the fighter, eighteen more arms fanned
## round its shoulders). While the form lasts, every normal attack of the fighter (its
## basic punch: Hero._basic_attack, Rival._basic_attack call punch_from) ALSO strikes every
## foe within [member radius] round it and sets them alight; the spirit's arms swing and
## its fists fly at each of them. When the time is up the spirit's fists fuse into one god
## fist that slams down before the fighter (the finisher): every foe within the skill's
## radius is struck and stunned, burns, and the finisher spends the combo the punches
## built (MuayThai.finisher, combo_power) like the old god skill's last beat.
##
## Damage (per target in reach, the same TOTAL as the old five-beat god skill): the skill's
## multiplier M (56.7, x star rank) is split into PUNCH_SHARE for the punches, divided over
## the punches the fighter can throw in SECS at its attack speed when the form begins
## ([member planned]), and FINISH_SHARE for the finisher (which grows by the spent combo,
## x1.4 at the full 20 stacks the punches always reach). Punches the fighter never threw
## (no foe in reach, walking away) are not lost: their share joins the finisher. Each punch
## burns for PUNCH_BURN seconds at the skill's own burn, so the burn runs through the form
## and the finisher's 6 s after it; the shares are set so the hits plus that longer burn
## come to the old skill's hits plus its 6 s burn (thotsakan_form_test measures it):
##   old  0.4 M x ~1.08 (its combo_power at ~10 stacks) x 1.1 (combo +1%/stack) + 0.45 ATK x 6 s
##   new  0.4 M x (0.42 + 0.3 x 1.4) x 1.2 (the form holds the combo at 20) + 0.45 ATK x (8 + 6) s
## so one foe takes about what it took before (x1.0-1.1), and a pack in reach takes it
## each, as the old area did; the fighter's own normal hit on its target lands as always.
##
## The form is a child node of its caster and polices itself: the caster dying, being
## freed (a zone change), its field changing, a duel ending or a new form replacing it end
## the form at once, without the finisher, and give back the body's size, the camera and
## the name plate. A cosmetic form (cosmetic = true: another player's body, RemotePlayer)
## grows and shows the spirit, swings with its attacks and shows the finisher, and hurts
## nobody. Art: ThotsakanFormArt (cosmetic only, VfxBudget-capped like every Ramakien root).

const ID := "three_realms_fist"
const NODE := &"ThotsakanForm"
## How long the form lasts (s), and how much the fighter grows.
const SECS := 8.0
const SCALE := 1.7
## Grow-in and shrink-out times (s).
const GROW := 0.35
const SHRINK := 0.4
## The demon king holds its size this long after the god fist lands.
const LINGER := 0.35
## Reach of the punches (m) at the skill's authored radius (BASE_RADIUS); a higher star
## rank's wider radius widens it in proportion.
const PUNCH_RADIUS := 5.0
const BASE_RADIUS := 9.0
## Shares of the skill's multiplier (see the header).
const PUNCH_SHARE := 0.42
const FINISH_SHARE := 0.3
## A punch sets its foes alight for this long (refreshed by the next punch).
const PUNCH_BURN := 1.0
## The finisher: from the end of the form to the god fist landing (s), and the fighter's
## lock while it slams.
const FINISH_WINDUP := 0.55
const FINISH_LOCK := 0.75
## The follow camera while the hero is big: lifted and drawn back (m).
const CAMERA_LIFT := 1.0
const CAMERA_BACK := 2.4
## The hero's name plate rises over the bigger body.
const PLATE_LIFT := 1.5

## Stats of the last forms (tests, probes).
static var last := {"punches": 0, "planned": 0, "finished": false, "victims": 0}

var caster_ref: WeakRef
var skill: Dictionary = {}
var cosmetic := false
## Seconds since the release (negative while a cosmetic form waits for its wind-up).
var clock := 0.0
## The skill's multiplier at its star rank (before SKILL_POWER), per target.
var power := 0.0
var planned := 1
var punches := 0
var radius := PUNCH_RADIUS
var finish_radius := BASE_RADIUS
var finished := false
var ended := false
var _field_ref: WeakRef
var _visual_ref: WeakRef
var _base_scale := Vector3.ONE
var _grown := 0.0
var _cam_ref: WeakRef
var _cam_lift := 0.0
var _cam_back := 0.0
var _plate_ref: WeakRef
var _plate_lift := 0.0
var _slammed := false
var _swing := 0
## The art: the mantle on the body (ThotsakanFormArt).
var art: ThotsakanFormArt


# ---------------------------------------------------------------------------
# Entry points
# ---------------------------------------------------------------------------

static func handles(p_skill: Dictionary) -> bool:
	return String(p_skill.get("id", "")) == ID


## The running form of [param caster], or null.
static func of(caster: Variant) -> ThotsakanForm:
	if caster == null or not is_instance_valid(caster) or not (caster is Node):
		return null
	var node := (caster as Node).get_node_or_null(NodePath(String(NODE))) as ThotsakanForm
	return node if node != null and not node.ended and not node.is_queued_for_deletion() else null


static func active(caster: Variant) -> bool:
	var form := of(caster)
	return form != null and form.clock >= 0.0 and form.clock < SECS


## [param caster] (a Hero, a Rival or any of its kinds, a RemotePlayer) turns into ทศกัณฐ์
## with [param p_skill] (as cast: its star rank applied). A form already running ends first
## (without its finisher). A cosmetic form starts after [param delay] seconds.
static func begin(caster: Node3D, p_skill: Dictionary, p_cosmetic := false, delay := 0.0) -> ThotsakanForm:
	if caster == null or not is_instance_valid(caster) or not caster.is_inside_tree():
		return null
	var old := caster.get_node_or_null(NodePath(String(NODE))) as ThotsakanForm
	if old != null:
		old.stop()
		caster.remove_child(old)
		old.queue_free()
	var form := ThotsakanForm.new()
	form.name = String(NODE)
	form.caster_ref = weakref(caster)
	form.skill = p_skill
	form.cosmetic = p_cosmetic
	form.clock = -maxf(delay, 0.0)
	form._field_ref = weakref(caster.get_parent())
	var scale := float(p_skill.get("radius", BASE_RADIUS)) / BASE_RADIUS
	form.radius = PUNCH_RADIUS * clampf(scale, 0.8, 1.6)
	form.finish_radius = float(p_skill.get("radius", BASE_RADIUS))
	form.power = float(p_skill.get("mult", 0.0)) * _rank_power(caster, p_skill)
	form.planned = clampi(roundi(SECS / maxf(_interval(caster), 0.2)), 1, 40)
	caster.add_child(form)
	last = {"punches": 0, "planned": form.planned, "finished": false, "victims": 0}
	return form


## The caster's normal attack landed: a punch of the form, if one is running.
static func punch_from(caster: Variant) -> void:
	var form := of(caster)
	if form != null:
		form.punch()


## Another player's body attacked (RemotePlayer): the spirit swings, nobody is hurt.
static func swing_on(caster: Variant) -> void:
	var form := of(caster)
	if form != null and form.cosmetic:
		form.punch()


## Ends the form of [param caster] at once, without its finisher (death, a duel's end).
static func end_on(caster: Variant) -> void:
	var form := of(caster)
	if form != null:
		form.stop()


# ---------------------------------------------------------------------------
# Who casts it
# ---------------------------------------------------------------------------

static func _rank_power(caster: Variant, p_skill: Dictionary) -> float:
	if caster is Hero:
		return (caster as Hero).rank_mult(p_skill)
	if caster is Rival:
		return SkillRank.power((caster as Rival).skill_rank(p_skill))
	return 1.0


## Seconds between the caster's normal attacks now.
static func _interval(caster: Variant) -> float:
	if caster is Hero:
		var hero := caster as Hero
		return float(Game.class_data().attack.interval) * (1.0 - hero._haste())
	if caster is Rival:
		var rival := caster as Rival
		var attack: Dictionary = rival.class_data.get("attack", {})
		var base := float(attack.get("interval", 0.62))
		return base * ((1.0 - rival.haste()) if rival.faithful else lerpf(1.6, 1.0, rival.difficulty))
	return 0.62


static func visual_of(caster: Variant) -> HeroVisual:
	if caster is RemotePlayer:
		return (caster as RemotePlayer).visual as HeroVisual
	return MuayThai.visual_of(caster)


func caster() -> Node3D:
	return caster_ref.get_ref() as Node3D if caster_ref != null else null


## The caster can no longer hold the form: gone, fallen, off its field, its duel over.
func _lost(body: Node3D) -> bool:
	if body == null or not is_instance_valid(body) or not body.is_inside_tree() or body.is_queued_for_deletion():
		return true
	if body.get_parent() != (_field_ref.get_ref() if _field_ref else null):
		return true
	if body is Hero:
		var hero := body as Hero
		return hero._dead or hero.field == null or not is_instance_valid(hero.field) or hero.field.is_queued_for_deletion()
	if body is Rival:
		var rival := body as Rival
		return rival.is_dead() or rival.duel_over
	if body is RemotePlayer:
		return (body as RemotePlayer).anim == "dead"
	if body.has_method("is_dead"):
		return bool(body.call("is_dead"))
	return false


# ---------------------------------------------------------------------------
# The clock
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if ended:
		return
	var body := caster()
	if _lost(body):
		stop()
		queue_free()
		return
	var was := clock
	clock += delta
	if clock < 0.0:
		return
	# The hero's own form draws in the hero's room of the effects budget (VfxBudget).
	var own := body is Hero
	if own:
		VfxBudget.hero_begin()
	_step(body, was)
	if own:
		VfxBudget.hero_end()


func _step(body: Node3D, was: float) -> void:
	if was < 0.0 or _visual_ref == null:
		_start(body)
	# The god fist: the slam begins when the time is up and lands FINISH_WINDUP later.
	if clock >= SECS and not finished:
		finished = true
		_finisher_windup(body)
	if finished and not _slammed and clock >= SECS + FINISH_WINDUP:
		_slammed = true
		_slam(body)
	# Grow in, hold, shrink out after the slam.
	var grow := smoothstep(0.0, GROW, clock)
	var shrink := smoothstep(SECS + FINISH_WINDUP + LINGER, SECS + FINISH_WINDUP + LINGER + SHRINK, clock)
	_set_grown(body, grow * (1.0 - shrink))
	if is_instance_valid(art):
		art.tick(body, self, get_process_delta_time())
	if clock >= SECS + FINISH_WINDUP + LINGER + SHRINK:
		stop()
		queue_free()


func _start(body: Node3D) -> void:
	var visual := visual_of(body)
	_visual_ref = weakref(visual) if visual != null else null
	if visual != null:
		_base_scale = visual.scale
	# A demon king does not ride: off the mount for the form.
	if body.has_method("dismount") and body.has_method("is_riding") and bool(body.call("is_riding")):
		body.call("dismount")
	if body is Hero:
		var hero := body as Hero
		# The form is fought in: an attacker keeps punching its target.
		if hero._valid_target(hero.target):
			hero.engaged = true
		if is_instance_valid(hero.camera_rig):
			_cam_ref = weakref(hero.camera_rig)
		if is_instance_valid(hero._name_plate):
			_plate_ref = weakref(hero._name_plate)
	art = ThotsakanFormArt.mantle(body, self)


## How grown the body is (0 its own size .. 1 the demon king's): the body's scale, the
## camera and the name plate follow.
func _set_grown(body: Node3D, k: float) -> void:
	_grown = k
	var visual := _visual_ref.get_ref() as HeroVisual if _visual_ref else null
	if visual != null and is_instance_valid(visual):
		visual.scale = _base_scale * lerpf(1.0, SCALE, k)
	var cam := _cam_ref.get_ref() as ThirdPersonCamera if _cam_ref else null
	if cam != null and is_instance_valid(cam):
		var lift := CAMERA_LIFT * k
		cam.height_offset += lift - _cam_lift
		_cam_lift = lift
		var back := CAMERA_BACK * k
		var before := float(cam._target_distance)
		cam.zoom(-(back - _cam_back))
		# The zoom is clamped: only what it really moved is given back.
		_cam_back += float(cam._target_distance) - before
	var plate := _plate_ref.get_ref() as Label3D if _plate_ref else null
	if plate != null and is_instance_valid(plate):
		var up := PLATE_LIFT * k
		plate.position.y += up - _plate_lift
		_plate_lift = up


## Ends the form now (no finisher): the body, the camera and the plate are given back,
## the art fades out.
func stop() -> void:
	if ended:
		return
	ended = true
	last["punches"] = punches
	last["finished"] = _slammed
	var visual := _visual_ref.get_ref() as HeroVisual if _visual_ref else null
	if visual != null and is_instance_valid(visual):
		visual.scale = _base_scale
	var cam := _cam_ref.get_ref() as ThirdPersonCamera if _cam_ref else null
	if cam != null and is_instance_valid(cam):
		cam.height_offset -= _cam_lift
		cam.zoom(_cam_back)
	_cam_lift = 0.0
	_cam_back = 0.0
	var plate := _plate_ref.get_ref() as Label3D if _plate_ref else null
	if plate != null and is_instance_valid(plate):
		plate.position.y -= _plate_lift
	_plate_lift = 0.0
	_grown = 0.0
	if is_instance_valid(art):
		art.close()
	art = null
	set_process(false)


func _exit_tree() -> void:
	stop()


# ---------------------------------------------------------------------------
# Punches and the finisher
# ---------------------------------------------------------------------------

## Damage of one punch on each foe in reach (a multiplier on ATK).
func punch_mult() -> float:
	return power * HeroStats.SKILL_POWER * PUNCH_SHARE / float(maxi(planned, 1))


## The finisher's share: its own and every punch not thrown.
func finish_share() -> float:
	var left := float(maxi(planned - punches, 0)) / float(maxi(planned, 1))
	return FINISH_SHARE + PUNCH_SHARE * left


## Foes within [param reach] of the caster (the hero's mobs, an AI player's targets).
func foes(body: Node3D, reach: float) -> Array:
	var out: Array = []
	if body is Hero:
		for mob in (body as Hero).mobs_in_range(reach + 0.6):
			out.append(mob)
	elif body is Rival:
		var rival := body as Rival
		for victim in rival._victims():
			if is_instance_valid(victim) and rival._alive(victim) and rival._flat_distance(victim.global_position) <= reach + 0.6 + 0.4:
				out.append(victim)
	return out


## One punch of the form (the caster's normal attack landed, or a cosmetic swing).
func punch() -> void:
	var body := caster()
	if ended or clock < 0.0 or clock >= SECS or _lost(body):
		return
	_swing += 1
	var victims: Array = [] if cosmetic else foes(body, radius)
	if not cosmetic:
		punches += 1
		last["punches"] = punches
		last["victims"] = victims.size()
	if is_instance_valid(art):
		if body is Hero:
			VfxBudget.hero_begin()
		art.punch(body, self, victims, _swing)
		if body is Hero:
			VfxBudget.hero_end()
	if cosmetic:
		return
	var mult := punch_mult()
	var burn: Array = skill.get("fx", {}).get("burn", [0.45, 6.0])
	if body is Hero:
		var hero := body as Hero
		VfxBudget.hero_begin()
		for mob in victims:
			var victim := mob as Mob
			if not hero._valid_target(victim):
				continue
			# A normal punch (no skill power, no generic skill art), then the fire.
			hero._deal(victim, mult, skill.get("color", Color("ffa040")), &"impact", false)
			if hero._valid_target(victim):
				victim.apply_burn(HeroStats.burn_dps(float(hero.stats.atk) * hero.rank_mult(skill), float(burn[0]), float(victim.stats.def)), PUNCH_BURN)
				victim.burn_source = hero
		VfxBudget.hero_end()
		var cam := SkillFeel._camera(hero)
		if cam and ThirdPersonCamera.feel_allowed() and not victims.is_empty():
			cam.feel_shake(Vector3(sin(hero._facing), 0, cos(hero._facing)), 0.05, 0.14)
	elif body is Rival:
		var rival := body as Rival
		for victim in victims:
			rival._hit(victim, mult, skill.get("color", Color("ffa040")), {"burn": burn})
	AudioManager.play_sfx_at(body.global_position, SkillSound.star_beat(1), -12.0)


## The time is up: the fighter rears up for the slam and the god fist rises.
func _finisher_windup(body: Node3D) -> void:
	var visual := visual_of(body)
	if visual != null and is_instance_valid(visual):
		visual.skill_action(skill, FINISH_WINDUP)
	if body is Hero:
		var hero := body as Hero
		hero._cast_until = maxi(hero._cast_until, Time.get_ticks_msec() + int(FINISH_LOCK * 1000.0))
	elif body is Rival:
		var rival := body as Rival
		rival._cast_until = maxi(rival._cast_until, GameClock.msec() + int(FINISH_LOCK * 1000.0))
		rival._attack_timer = maxf(rival._attack_timer, FINISH_LOCK)
	if is_instance_valid(art):
		art.finisher(body, self, FINISH_WINDUP)


## Where the god fist lands: before the fighter.
func slam_point(body: Node3D) -> Vector3:
	var facing := 0.0
	if body is Hero:
		facing = (body as Hero)._facing
	elif body is Rival:
		facing = (body as Rival)._yaw
	else:
		var visual := visual_of(body)
		facing = visual.rotation.y if visual != null else 0.0
	return body.global_position * Vector3(1, 0, 1) + Vector3(sin(facing), 0, cos(facing)) * 1.8


## The god fist lands: every foe within the skill's radius is struck (the combo spent),
## stunned and set alight.
func _slam(body: Node3D) -> void:
	var at := slam_point(body)
	AudioManager.play_sfx_at(at, SkillSound.star_beat(0), -3.0)
	var landing := SkillSound.landing(skill)
	if landing != &"":
		AudioManager.play_sfx_at(at, landing, -5.0)
	if cosmetic:
		return
	var share := finish_share()
	var color: Color = skill.get("color", Color("ffa040"))
	if body is Hero:
		var hero := body as Hero
		VfxBudget.hero_begin()
		SkillFeel.impact(hero, skill, at, finish_radius, StarSkillData.GOD_BEATS.size() - 1, StarSkillData.GOD_BEATS.size())
		SkillFeel.area_from(at)
		for mob in foes(hero, finish_radius):
			# The skill's own hit: SKILL_POWER, the spent combo, stun and burn (Hero._deal).
			hero._deal(mob, power * share, color, skill.get("vfx", &"light"), false, skill)
		SkillFeel.area_done()
		SkillFeel.beat_done()
		VfxBudget.hero_end()
	elif body is Rival:
		var rival := body as Rival
		var fx: Dictionary = skill.get("fx", {})
		for victim in foes(rival, finish_radius):
			rival._hit(victim, power * HeroStats.SKILL_POWER * share, color, fx)
