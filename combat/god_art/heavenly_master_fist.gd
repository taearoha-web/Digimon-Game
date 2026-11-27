extends RefCounted
## Muay Thai Ascension ultimate (★500): หมัดบรมครูเทวะ, the grand finisher. One blow, heavy and
## slow (AscendSkillData.FINISHERS: a single beat after a long wind-up, the hero dashing in
## first), nothing like the ★300 สิบเศียรสิบกรสะท้านสามภพ it grew from (three_realms_fist):
##   ไหว้ครู   เทวาลัย, a temple ring of gold, rises out of the ground round the aimed point
##            (a floor of กนก flames, eight lotus pillars under flame finials, red ประเจียด
##            cloth swagged between them) under a turning mandala of flame. Behind the
##            fighter the บรมครูเทวะ condenses out of a gold-edged cloud inside a
##            ซุ้มเรือนแก้ว arch of flame tongues: a serene warm-white deity boxer under gold
##            sak yant, a มงคล on his brow, ประเจียด flying from his arms, hands pressed in
##            ไหว้ครู with the fighter (a lotus, a มงคล settling on its head, ประเจียด rings),
##            swaying in his รำไหว้ครู while the field warms to a heavenly amber.
##   the dash the fighter and the master dash for the point together: a golden streak along
##            the run, the master's afterimages left behind, his body sweeping after the
##            fighter, while his colossal fist gathers over the point inside a sun of flame
##            petals and a ring of กนก flame.
##   the blow the fist slams down with the fighter's punch: the biggest blast in the game, a
##            white-gold flash, shockwaves rolling out past the ring, a กนก flame burst
##            blooming over the ground and a crown of flame tongues thrown out, pillars of
##            heaven's light out of the temple, the struck dazed (2 s) and burning (6 s).
## Drawn with RamakienArt's engine (RamakienSculpt figures lit by RamakienSpirit, its light
## and veil, MuayPaint pieces); cosmetic only (StarSkillSequence owns the contact and the
## dash). Roots follow the god contract: StarGodGround (always), StarGodSky (the master,
## no memory pressure), StarGodAvatar on the blow (no pressure), StarGodTemple (high
## quality only); each is tied to its cast, capped (MuayThaiArt.layer_cap), tiered and
## counted (NaturalArt.depth / count) and its pooled materials go back when it ends.
const ID := "heavenly_master_fist"
## AscendSkillData.COLORS["heavenly_master_fist"]: orange-gold, warm white, deep brown.
const ORANGE := Color("ffa030")
const WARM := Color("fff4d0")
const DEEP := Color("5a1a08")
const SACRED := [Color("ffa030"), Color("fff4d0"), Color("5a1a08")]
const FLAME := [Color("ff6a14"), Color("ffd86a"), Color("5a1a08")]
const EMBER := [Color("ff7a1e"), Color("ffe08a"), Color("5a1a08")]
const WHITE_HOT := [Color("fff4d0"), Color.WHITE, Color("5a1a08")]
## The master: warm white-gold skin shading to orange, gold, red cloth, dark hair.
const DEVA_LOOK := {"skin": Color("ffe8c4"), "skin_dark": Color("b8642a"), "rim": Color("ffc860"), "gold": Color("ffb43c"), "gold_dark": Color("6a2606"), "red": Color("d42a1c"), "ink": Color("3a1606"), "lines": Color("ffcf70")}
## His fist: brighter, hotter, glowing at the rim.
const FIST_LOOK := {"skin": Color("fff4dc"), "skin_dark": Color("f08a30"), "rim": Color("ffd27a"), "gold": Color("ffb43c"), "gold_dark": Color("6a2606"), "red": Color("d42a1c"), "ink": Color("3a1606"), "lines": Color("ffd88a")}
## The temple ring: gold.
const TEMPLE_LOOK := {"skin": Color("ffe0a0"), "skin_dark": Color("a8561a"), "rim": Color("fff0c0"), "gold": Color("ffb43c"), "gold_dark": Color("5a1a08"), "red": Color("d42a1c"), "ink": Color("3a1606"), "lines": Color("ffe9a8")}
const COLOSSAL := 5.2
## The set of the cast running now (where the master stands, the run, the frame).
static var _sets := {}


static func _radius(skill: Dictionary) -> float:
	return clampf(float(skill.get("radius", 10.0)), 5.0, 10.0)


static func _grow(seconds: float, rise: float) -> float:
	return maxf(seconds / maxf(rise, 0.05), 1.0)


## Where the colossal fist lands from the aimed point: a little beyond it as the camera
## sees it, so the fighter dashing in stands before the fist, not under it.
static func slam_spot(center: Vector3, away: Vector3) -> Vector3:
	return Vector3(center.x, 0, center.z) + away * 1.2


## The planned run of the cast (StarSkillSequence.dash_to), or the fighter's own spot.
static func _run_end(origin: Vector3) -> Vector3:
	var ref: WeakRef = GodSkillArt._casts.get(ID)
	var cast := ref.get_ref() as StarSkillSequence if ref else null
	if cast == null or cast.dash_to == Vector3.INF:
		return origin
	return cast.dash_to * Vector3(1, 0, 1)


# ---------------------------------------------------------------------------
# Wind-up: the temple ring, the master's ไหว้ครู, the dash, the fist gathering
# ---------------------------------------------------------------------------

static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var parent := art.get_parent() as Node3D if art else null
	if not SculptureArt._alive(parent) or not is_instance_valid(caster):
		return false
	var origin := caster.global_position * Vector3(1, 0, 1)
	var center := Vector3(point.x, 0, point.z)
	var run := _run_end(origin)
	var radius := _radius(skill)
	var dash_at := maxf(0.2, time - AscendSkillData.DASH_LEAD - AscendSkillData.DASH_TIME)
	var stay := time + 1.5
	var view := RamakienArt._view(parent, origin, RamakienArt._frame(art, ID, origin, center)[0])
	var away: Vector3 = view[0]
	_sets[ID] = {"away": away, "radius": radius, "origin": origin, "center": center, "run": run, "dash_at": dash_at, "time": time}
	# The ground (always): เทวาลัย rises out of the earth round the aimed point.
	var ground := RamakienArt._open(parent, center, "StarGodGround_" + ID, ID)
	ground._sculpt("devalai", TEMPLE_LOOK, Vector3.DOWN * 2.4, Vector3.ONE * radius, Vector3(0, atan2(away.x, away.z), 0), 0.0, stay, {"initial": 1.0, "travel": Vector3.UP * 2.42, "snap": 0.7, "pop": 0.0, "fade_in": 0.05, "decay": 0.92, "opacity": 0.97}, {"rim_power": 0.8, "lai_scale": 30.0})
	ground.layer("sun", true, SACRED, Vector3.UP * 0.07, Vector3.ONE * radius * 0.42, Vector3(-PI * 0.5, 0, 0), 0.1, time + 0.1, {"initial": 0.2, "grow": _grow(time + 0.1, 0.8), "spin": 0.45, "fade_in": 0.25, "decay": 0.86, "opacity": 0.34})
	ground._light("disc", 0, ORANGE, WARM, Vector3.UP * 0.05, Vector3.ONE * radius * 0.95, 0.0, time + 0.2, {"initial": 0.4, "grow": _grow(time, 0.8), "fade_in": 0.1, "decay": 0.9, "opacity": 0.42, "priority": -1, "tier": NaturalArt.TIER_MID})
	# The fighter's ไหว้ครู (always): a lotus underfoot, the มงคล settling on its head,
	# ประเจียด rings turning round it; all gone as it dashes.
	var wai := RamakienArt._open(parent, origin, "StarGodWai_" + ID, ID)
	wai.layer("lotus", false, MuayThaiArt.LOTUS, Vector3.UP * 0.05, Vector3.ONE * 1.6, Vector3.ZERO, 0.0, dash_at + 0.1, {"initial": 0.2, "grow": _grow(dash_at, 0.45), "overshoot": true, "spin": 0.4, "fade_in": 0.15, "decay": 0.85, "opacity": 0.95})
	wai.layer("headband", false, MuayThaiArt.CLOTH, Vector3.UP * 3.8, Vector3.ONE * 0.55, Vector3.ZERO, 0.1, dash_at * 0.7, {"initial": 0.3, "grow": 4.0, "overshoot": true, "travel": Vector3.DOWN * 1.7, "spin": 2.0, "fade_in": 0.15, "decay": 0.82})
	wai._orbit_rings(MuayThaiArt.CLOTH, Vector3.ZERO, NaturalArt.count(3), 1.15, 1.05, 0.1, dash_at, 0.3, 3.0)
	# The dash and the fist gathering (always: they are the read of the blow).
	_dash(RamakienArt._open(parent, origin, "StarGodDash_" + ID, ID), origin, run, dash_at)
	_colossal(RamakienArt._open(parent, center, "StarGodFist_" + ID, ID), center, away, dash_at, time)
	# The sky (no memory pressure): the master himself.
	if GodSkillArt.extra_roots(1) >= 1:
		var stage := RamakienArt._stage(parent, origin, away, 12.0, -1.0, 0.0, 0.05)
		var base: Vector3 = stage.base
		_sets[ID].merge({"base": base, "stage": stage}, true)
		var giant := RamakienArt._open(parent, base, "StarGodSky_" + ID, ID)
		_manifest(giant, stage, origin + Vector3.UP, run + Vector3.UP, run - origin, dash_at, time)
	return true


## The master on [param giant] (at the model origin of [param stage]): the amber veil, the
## body in its arch condensing out of the cloud, swaying in the ไหว้ครู until the dash;
## then his body and arch sweep after the fighter along [param shift] (afterimages left
## where he stood) and dissolve as the blow lands.
static func _manifest(giant: RamakienArt, stage: Dictionary, front: Vector3, front_run: Vector3, shift: Vector3, dash_at: float, time: float) -> void:
	var basis: Basis = stage.basis
	var h := float(stage.h)
	var euler := basis.get_euler()
	var near := {"front_world": front, "front_push": 1.1}
	var far := {"front_world": front, "front_push": 1.8}
	var sink := -basis.y * h * 0.035
	var arch_at := sink + RamakienArt.model(stage, Vector3(0, -0.02, -0.17))
	var arch_size := Vector3(h * 1.08, h * 1.02, h)
	var calm := dash_at + 0.06
	# The รำไหว้ครู: a slow sway and a breath (body and arch keep the same clock).
	var dance := {"sway": h * 0.006, "sway_rate": 0.45, "bob": h * 0.003}
	var body_params := {"mist_lo": 0.15, "mist_hi": 0.31, "rim_power": 1.1, "lai_scale": 40.0}
	var arch_params := {"mist_lo": 0.05, "mist_hi": 0.24, "rim_power": 1.3}
	var dash_time := AscendSkillData.DASH_TIME
	giant.layer("veil", false, RamakienArt.LEAF, Vector3.ZERO, Vector3.ONE, Vector3.ZERO, 0.0, time + 0.9, {"shader": RamakienArt.VEIL, "params": {"tint": Color(0.17, 0.085, 0.02), "strength": 0.5}, "fade_in": 0.12, "decay": 0.8, "priority": RamakienArt.PRI_VEIL})
	giant._sculpt("master_deva", DEVA_LOOK, sink, Vector3.ONE * h, euler, 0.0, calm, {"initial": 1.0, "travel": basis.y * h * 0.05, "fade_in": 0.02, "decay": 0.97, "opacity": 0.97, "priority": RamakienArt.PRI_BODY}.merged(dance), body_params.merged({"manifest": 0.85, "front_world": front, "front_push": 1.4}))
	giant._sculpt("ruean_kaew", DEVA_LOOK, arch_at, arch_size, euler, 0.0, calm, {"initial": 0.5, "grow": _grow(calm, 0.9), "overshoot": true, "travel": basis.y * h * 0.05, "fade_in": 0.2, "decay": 0.97, "opacity": 0.95, "priority": RamakienArt.PRI_HALO}.merged(dance), arch_params.merged({"front_world": front, "front_push": 1.9}))
	# The dash: he sweeps after the fighter (a touch smaller, leaning in), then dissolves
	# into the blow.
	var lean := Basis(basis.x, 0.12) * basis
	var after := time - dash_at + 0.4
	var sweep := {"initial": 0.94, "travel": shift + basis.y * h * 0.03, "snap": dash_time, "pop": 0.0, "fade_in": 0.02, "decay": 0.72, "opacity": 0.95}
	giant._sculpt("master_deva", DEVA_LOOK, sink + basis.y * h * 0.05, Vector3.ONE * h, lean.get_euler(), dash_at, after, sweep.merged({"priority": RamakienArt.PRI_BODY}), body_params.merged({"front_world": front_run, "front_push": 1.4}))
	giant._sculpt("ruean_kaew", DEVA_LOOK, arch_at + basis.y * h * 0.05, arch_size, lean.get_euler(), dash_at, after, sweep.merged({"priority": RamakienArt.PRI_HALO, "opacity": 0.85}), arch_params.merged({"front_world": front_run, "front_push": 1.9}))
	giant._light("bank", 9, ORANGE, Color("fff3dc"), RamakienArt.model(stage, Vector3(0, 0.2, 0.12)), Vector3(h * 0.62, h * 0.21, 1.0), 0.0, calm + 0.1, {"initial": 0.7, "grow": 2.0, "billboard": true, "fade_in": 0.08, "decay": 0.85, "opacity": 0.95, "priority": 1}, near)
	giant._light("quad", 1, ORANGE, WARM, RamakienArt.model(stage, Vector3(0, 0.52, -0.12)), Vector3.ONE * h * 0.6, 0.25, calm - 0.25, {"initial": 0.4, "grow": 1.6, "billboard": true, "fade_in": 0.14, "decay": 0.88, "opacity": 1.0, "priority": RamakienArt.PRI_HALO - 1, "tier": NaturalArt.TIER_MID}, far)
	# The blessing in his hands: a glint between the palms as the ไหว้ครู ends.
	giant._light("quad", 3, ORANGE, WARM, RamakienArt.model(stage, Vector3(0, 0.43, 0.24)), Vector3.ONE * h * 0.16, dash_at * 0.55, dash_at * 0.45, {"initial": 0.2, "grow": 5.0, "billboard": true, "fade_in": 0.2, "decay": 0.6, "opacity": 1.0, "priority": 3}, near)
	# His afterimages, left where he stood as he goes.
	for k in NaturalArt.count(2):
		giant._sculpt("master_deva", DEVA_LOOK, sink + shift * (0.3 + 0.3 * float(k)), Vector3.ONE * h * 0.97, lean.get_euler(), dash_at + dash_time * (0.25 + 0.3 * float(k)), 0.4, {"initial": 1.0, "fade_in": 0.02, "decay": 0.1, "opacity": 0.4, "priority": RamakienArt.PRI_BODY - 1, "tier": NaturalArt.TIER_MID}, body_params.merged({"front_world": front_run, "front_push": 1.6, "skin_alpha": 0.6, "rim_power": 2.2}))
	giant._light("embers", 5, ORANGE, WARM, RamakienArt.model(stage, Vector3(0, 0.1, 0.1)), Vector3(h * 0.6, h * 0.85, h * 0.3), 0.2, calm, {"initial": 1.0, "fade_in": 0.1, "decay": 0.85, "priority": 2, "tier": NaturalArt.TIER_DEBRIS}, near)
	for k in 2:
		var x := -0.36 if k == 0 else 0.38
		giant._light("shaft", 4, ORANGE, WARM, RamakienArt.model(stage, Vector3(x, 0.05, -0.18)), Vector3(h * 0.18, h * 1.25, 1.0), 0.15 + 0.12 * float(k), calm - 0.2, {"initial": 0.7, "grow": 2.0, "face_camera": true, "fade_in": 0.2, "decay": 0.8, "opacity": 0.6, "priority": RamakienArt.PRI_HALO - 2, "tier": NaturalArt.TIER_DEBRIS}, far)


## The run on [param root] (standing at [param origin]): a golden streak laid along it as the
## fighter goes, a white-hot core over it and a flash where it sets off.
static func _dash(root: RamakienArt, origin: Vector3, run: Vector3, dash_at: float) -> void:
	var path := run - origin
	var length := path.length()
	if length < 0.6:
		return
	var dir := path / length
	var dash_time := AscendSkillData.DASH_TIME
	var lay := {"initial": 1.0, "point": dir, "fade_in": 0.18, "decay": 0.5, "opacity": 1.0}
	# The streak: comets laid head to tail along the run, each lit as the fighter passes.
	var pieces := 4 if NaturalArt.depth() > NaturalArt.TIER_CORE else 2
	var piece := length / float(pieces)
	for k in pieces:
		var t := float(k + 1) / float(pieces)
		# The fighter's run eases out (StarSkillSequence: 1 - (1 - u)^3): when it passes t.
		var passes := dash_time * (1.0 - pow(1.0 - t, 1.0 / 3.0))
		root._light("trail", 7, ORANGE, WARM, path * t + Vector3.UP * 1.0, Vector3(piece * 1.7, 2.6, 1.0), dash_at + maxf(0.0, passes - 0.05), 0.55, lay.merged({"priority": 6}))
	root._light("trail", 7, WARM, Color.WHITE, path + Vector3.UP * 1.0, Vector3(minf(length, 4.0) * 1.3, 1.2, 1.0), dash_at + dash_time * 0.5, dash_time * 0.5 + 0.35, lay.merged({"priority": 7, "tier": NaturalArt.TIER_MID}))
	root._light("quad", 10, ORANGE, WARM, Vector3.UP * 0.9, Vector3.ONE * 3.0, dash_at, 0.3, {"initial": 0.3, "grow": 8.0, "billboard": true, "decay": 0.4, "priority": 4})
	root.layer("shock", true, SACRED, Vector3.UP * 0.05, Vector3.ONE * 2.6, Vector3.ZERO, dash_at, 0.4, {"initial": 0.2, "grow": 5.0, "decay": 0.45, "opacity": 0.5, "tier": NaturalArt.TIER_MID})
	for k in NaturalArt.count(3):
		var t := (float(k) + 0.5) / 3.0
		root.layer("kanok", false, FLAME, path * t, Vector3.ONE * 0.9, Vector3.ZERO, dash_at + dash_time * t, 0.45, {"initial": 0.2, "grow": 4.0, "overshoot": true, "travel": Vector3(0, 0.3, 0), "face_camera": true, "decay": 0.5, "tier": NaturalArt.TIER_DEBRIS})


## The colossal fist on [param root] (at the aimed point): it condenses high over the slam
## spot inside a sun of flame petals and a ring of กนก flame, winds up a little as the
## fighter dashes, and hammers down at [param land] (the blow).
static func _colossal(root: RamakienArt, center: Vector3, away: Vector3, dash_at: float, land: float) -> void:
	var slam := slam_spot(center, away) - center
	var size := COLOSSAL
	var aim := (Vector3.DOWN - away * 0.28).normalized()
	var knuckles := slam + Vector3.UP * (0.5 * size + 0.15)
	var room := RamakienArt.fit_height(root, center + slam, 12.0, 0.3, 0.04)
	var lift := clampf(room - 1.4 * size, 1.6, 5.0)
	var apex := knuckles - aim * lift
	var appear := maxf(0.1, dash_at - 0.3)
	var hang := land - 0.13
	var rise := -aim * 0.6
	root._sculpt("deva_fist", FIST_LOOK, apex, Vector3.ONE * size, Vector3.ZERO, appear, hang - appear + 0.02, {"initial": 0.2, "grow": 4.0, "overshoot": true, "travel": rise, "point": aim, "fade_in": 0.06, "decay": 0.99, "opacity": 0.96, "priority": 2}, {"rim_power": 2.2, "skin_alpha": 0.92})
	var top := apex + rise
	var slam_style := {"initial": 1.0, "travel": knuckles - top, "snap": 0.13, "snap_in": true, "accelerate": true, "point": aim}
	root._sculpt("deva_fist", FIST_LOOK, top, Vector3.ONE * size, Vector3.ZERO, hang, 0.13 + 0.7, slam_style.merged({"decay": 0.72, "opacity": 0.96, "priority": 2}, true), {"rim_power": 2.4, "skin_alpha": 0.92})
	root.layer("sun", true, SACRED, apex - aim * 0.3 + away * 0.9, Vector3.ONE * size * 0.85, Vector3.ZERO, appear, hang - appear + 0.06, {"initial": 0.2, "grow": 5.0, "overshoot": true, "travel": rise, "roll": 0.9, "billboard": true, "fade_in": 0.08, "decay": 0.85, "opacity": 0.85, "priority": 0})
	root._light("quad", 10, ORANGE, WARM, apex, Vector3.ONE * 6.0, appear - 0.02, 0.24, {"initial": 0.2, "grow": 10.0, "billboard": true, "decay": 0.4, "priority": 3})
	root._light("trail", 7, ORANGE, WARM, top, Vector3(size * 3.4, size * 1.4, 1.0), hang, 0.26, slam_style.merged({"pop": 0.0, "decay": 0.4, "opacity": 1.0, "tier": NaturalArt.TIER_MID}, true))
	root._light("quad", 0, ORANGE, WARM, apex, Vector3.ONE * size * 2.8, appear, hang - appear, {"initial": 0.3, "grow": 4.0, "travel": rise, "billboard": true, "fade_in": 0.1, "decay": 0.9, "opacity": 0.55, "priority": 0, "tier": NaturalArt.TIER_MID})
	# Heaven's shaft of light marks the slam; flames circle the fist as it gathers.
	root._light("shaft", 4, ORANGE, WARM, slam, Vector3(3.0, minf(room + 2.0, 13.0), 1.0), appear, hang - appear + 0.1, {"initial": 0.6, "grow": 3.0, "face_camera": true, "fade_in": 0.15, "decay": 0.8, "opacity": 0.7, "priority": -1, "tier": NaturalArt.TIER_MID})
	for k in NaturalArt.count(4):
		var a := TAU * float(k) / 4.0
		root.layer("kanok", false, FLAME, apex, Vector3.ONE * 1.2, Vector3.ZERO, appear + 0.02 * float(k), hang - appear, {"initial": 0.3, "grow": 4.0, "overshoot": true, "orbit": size * 0.75, "orbit_speed": 5.0, "phase": a, "travel": rise, "face_camera": true, "fade_in": 0.1, "decay": 0.8, "tier": NaturalArt.TIER_MID if k < 2 else NaturalArt.TIER_DEBRIS})


# ---------------------------------------------------------------------------
# The blow: the biggest blast in the game
# ---------------------------------------------------------------------------

## A finisher has no waves (AscendSkillData.god_beats): nothing to draw between.
static func wave(_art: StarSkillArt, _parent: Node3D, _skill: Dictionary, _index: int, _point: Vector3, _source: Vector3) -> bool:
	return true


static func finale(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, source: Vector3) -> bool:
	if not SculptureArt._alive(parent):
		return false
	var set: Dictionary = _sets.get(ID, {})
	var center := Vector3(point.x, 0, point.z)
	var away: Vector3 = set.get("away", RamakienArt._frame(art, ID, source, point)[0])
	var radius := _radius(skill)
	var fx: Dictionary = skill.get("fx", {})
	var slam := slam_spot(center, away)
	# The contact root: a great glow over the ground and the first shockwave.
	RamakienArt._paint_light(art, "disc", 0, ORANGE, WARM, art.to_local(slam + Vector3.UP * 0.06), Vector3.ONE * radius * 1.15, 1.3, {"initial": 0.5, "grow_time": 0.25, "decay": 0.5, "fade_in": 0.01, "opacity": 0.9}, -1)
	RamakienArt._paint(art, "shock", SACRED, art.to_local(slam + Vector3.UP * 0.07), Vector3.ONE * radius * 0.9, 0.6, {"initial": 0.12, "grow_time": 0.4, "decay": 0.5, "opacity": 0.55}, true, 1)
	# The blast: a white-gold flash, the กนก flame burst blooming over the ground, a crown
	# of flame tongues thrown out, shockwaves rolling past the ring, cracks, the dazed.
	var hit := RamakienArt._open(parent, slam, "MasterBlast_" + ID, ID)
	hit._light("quad", 10, ORANGE, WARM, Vector3(0, 1.2, 0), Vector3.ONE * 11.0, 0.0, 0.45, {"initial": 0.3, "grow": 9.0, "billboard": true, "decay": 0.45, "priority": 4})
	hit._light("quad", 0, WARM, Color.WHITE, Vector3(0, 1.5, 0), Vector3.ONE * 14.0, 0.0, 0.3, {"initial": 0.5, "grow": 12.0, "billboard": true, "decay": 0.3, "priority": 5})
	hit.layer("sun", true, SACRED, Vector3.UP * 0.09, Vector3.ONE * radius * 0.85, Vector3(-PI * 0.5, 0, 0), 0.0, 1.2, {"initial": 0.1, "grow": 4.5, "overshoot": true, "spin": 0.9, "decay": 0.5, "opacity": 0.8})
	for k in NaturalArt.count(12):
		var a := TAU * float(k) / 12.0 + 0.2
		var dir := Vector3(sin(a), 0, cos(a))
		hit.layer("kanok", false, FLAME, dir * 1.4, Vector3.ONE * (2.4 + 0.5 * float(k % 2)), Vector3.ZERO, 0.02 + 0.012 * float(k), 0.95, {"initial": 0.2, "grow": 4.0, "overshoot": true, "travel": dir * 3.4 + Vector3.UP * 0.5, "sway": 0.06, "sway_rate": 2.2, "phase": a, "face_camera": true, "decay": 0.55, "tier": NaturalArt.TIER_CORE if k < 3 else (NaturalArt.TIER_MID if k < 7 else NaturalArt.TIER_DEBRIS)})
	hit.layer("shock", true, WHITE_HOT, Vector3.UP * 0.08, Vector3.ONE * radius * 1.35, Vector3.ZERO, 0.04, 0.7, {"initial": 0.08, "grow": 4.0, "decay": 0.5, "opacity": 0.5})
	hit.layer("crack", true, EMBER, Vector3.UP * 0.05, Vector3.ONE * radius * 0.6, Vector3(0, randf() * TAU, 0), 0.0, 1.6, {"initial": 0.3, "grow": 9.0, "decay": 0.65, "opacity": 0.95, "tier": NaturalArt.TIER_MID})
	hit._stun_stars(Vector3.UP * 0.3, 0.05, float(fx.get("stun", 2.0)), 3)
	hit._radial_cones(SACRED, Vector3.ZERO, 10, 5.0, 0.02, 0.5)
	hit._sparks(SACRED, Vector3(0, 1.0, 0), 12, 0.02, 2.4)
	for k in NaturalArt.count(5):
		var a := float(k) * 1.26 + 0.4
		hit.layer("smoke", true, MuayThaiArt.DUST, Vector3(sin(a), 0.1, cos(a)) * 2.4, Vector3.ONE * 2.6, Vector3.ZERO, 0.04 + 0.03 * float(k), 1.2, {"initial": 0.3, "grow": 3.0, "travel": Vector3(sin(a) * 2.0, 1.4, cos(a) * 2.0), "face_camera": true, "decay": 0.55, "opacity": 0.4, "tier": NaturalArt.TIER_DEBRIS})
	# The struck burn (fx burn): flame wisps on each foe in reach.
	if fx.has("burn"):
		RamakienArt._burn_wisps(parent, center, radius, ID)
	# The avatar (no memory pressure): heaven's pillars rise out of the temple ring, a
	# column of light over the blow, the three heavens' rings roll out.
	if GodSkillArt.extra_roots(1) >= 1:
		var avatar := RamakienArt._open(parent, center, "StarGodAvatar_" + ID, ID)
		var yaw := atan2(away.x, away.z)
		avatar._light("shaft", 4, WARM, Color.WHITE, slam - center, Vector3(6.0, 16.0, 1.0), 0.0, 0.9, {"initial": 0.5, "grow": 8.0, "face_camera": true, "fade_in": 0.03, "decay": 0.5, "opacity": 1.0, "priority": 3})
		for k in NaturalArt.count(8):
			var a := yaw + TAU * float(k) / 8.0 + TAU / 16.0
			avatar._light("shaft", 4, ORANGE, WARM, Vector3(sin(a), 0, cos(a)) * radius * 0.968, Vector3(1.8, 10.0, 1.0), 0.04 + 0.03 * float(k), 1.4, {"initial": 0.4, "grow": 5.0, "face_camera": true, "fade_in": 0.08, "decay": 0.6, "opacity": 0.85, "tier": NaturalArt.TIER_CORE if k < 4 else NaturalArt.TIER_MID})
		var rings := [[SACRED, 0.09, 0.75], [EMBER, 0.1, 1.05], [WHITE_HOT, 0.11, 1.5]]
		for k in 3:
			avatar.layer("shock", true, rings[k][0], slam - center + Vector3.UP * float(rings[k][1]), Vector3.ONE * radius * float(rings[k][2]), Vector3.ZERO, 0.05 + 0.09 * float(k), 0.75, {"initial": 0.15, "grow": 4.5, "decay": 0.45, "opacity": 0.3, "tier": NaturalArt.TIER_CORE if k < 2 else NaturalArt.TIER_MID})
	# The temple (high quality only): the floor's flames kindle round the ring and embers
	# drift up over the whole field.
	if GodSkillArt.extra_roots(2) >= 2:
		var temple := RamakienArt._open(parent, center, "StarGodTemple_" + ID, ID)
		for k in NaturalArt.count(12):
			var a := TAU * float(k) / 12.0 + 0.13
			temple.layer("kanok", false, FLAME, Vector3(sin(a), 0.02, cos(a)) * radius * 0.74, Vector3.ONE * (1.4 + 0.3 * float(k % 3)), Vector3.ZERO, 0.08 + 0.025 * float(k), 1.3, {"initial": 0.15, "grow": 3.5, "overshoot": true, "travel": Vector3(0, 0.3, 0), "sway": 0.05, "sway_rate": 2.4, "phase": a, "face_camera": true, "decay": 0.6, "tier": NaturalArt.TIER_MID if k < 6 else NaturalArt.TIER_DEBRIS})
		temple._light("embers", 5, ORANGE, WARM, Vector3.ZERO, Vector3(radius * 1.0, 4.5, radius * 1.0), 0.05, 1.6, {"initial": 1.0, "fade_in": 0.1, "decay": 0.7, "priority": 2, "tier": NaturalArt.TIER_MID})
	return true
