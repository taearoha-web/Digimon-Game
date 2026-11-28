extends Node3D
## ประตูมิติร้อยบาน (the mage's ★500 Ascension ultimate, AscendSkillData "cosmos_genesis",
## played by AscendUlt from its release): PORTALS dimensional portals open in a ring round
## the aimed area and, for about three seconds, rapid-fire elemental bolts into the enemies
## inside it: VOLLEYS volleys GAP seconds apart, the element turning fire, ice, lightning,
## fire... Every enemy in the area (RADIUS round the aimed point) takes one bolt a volley, of
## 1/VOLLEYS of the whole multiplier, from the portal of that volley's element nearest it,
## so a foe in the area throughout takes exactly the skill's multiplier (x its rank's power).
## Each element adds a little: fire a short burn (BURN), ice a short slow (CHILL s), and the
## last volley (lightning) a short stun (STUN s). Bolts fly FLIGHT s (lightning strikes at
## once); a bolt lands on its foe only while the caster still commands the cast.
##
## The hero's bolts go through Hero._deal; an AI player's (Rival, begin_rival) through
## Rival._hit on its own targets (the slow and the stun on what can take them; no burn, which
## only the hero's blows carry). The cast stops at once (no bolt lands after) when its
## caster falls, leaves the field or the zone, enters a safe zone or ends its duel; the
## field freed frees it. Light: the hero's always; an AI's at medium quality and up, while
## fewer than MAX_AI_SHOWN others show (its bolts land unseen otherwise), with fewer bolts.

const Kit := preload("res://combat/ascend_ult/_ult_kit.gd")
const ID := "cosmos_genesis"
const PORTALS := 6
const OPEN := 0.3
const GAP := 0.25
const VOLLEYS := 12
const FLIGHT := 0.2
const STRIKE_DELAY := 0.05
const CLOSE := 0.35
## The area the bolts seek, round the aimed point; the portals' ring round it.
const RADIUS := 8.0
const RING := 6.5
const PORTAL_HEIGHT := 3.4
const PORTAL_SIZE := 3.1
## Fire: a burn of BURN[0] x ATK a second for BURN[1] s; ice: a slow; the last volley: a stun.
const BURN := [0.2, 2.0]
const CHILL := 1.5
const STUN := 1.0
const MAX_AI_SHOWN := 2
## Bolts drawn a volley (every foe is struck; past these the bolts fly unseen).
const SHOWN_BOLTS := 6
const AI_SHOWN_BOLTS := 3
const ELEMENTS := ["fire", "ice", "lightning"]
## Per element: bolt colour, hot core, deep shade.
const LOOK := {
	"fire": [Color("ff7a2a"), Color("ffe6a0"), Color("8a1a06")],
	"ice": [Color("7fd8ff"), Color("f0ffff"), Color("1a4a8a")],
	"lightning": [Color("fff07a"), Color("ffffff"), Color("6a4ad0")],
}
const RIM := Color("8a5aff")

var caster: Node3D
var skill: Dictionary = {}
var by_hero := false
var shown := true
var total_mult := 0.0
var center := Vector3.ZERO
var clock := 0.0
var volleys := 0
## Tests: what each foe (instance id) took, in shares of total_mult, and how many bolts of
## each element landed in all.
var dealt := {}
var landed := {"fire": 0, "ice": 0, "lightning": 0}
var gone := false

var _field: Node
var _zone: StringName
var _ending := -1.0
## Bolts in flight: {at, foe (WeakRef), element, final, shown}.
var _flying: Array[Dictionary] = []
var _portals: Array[MeshInstance3D] = []
var _seal: MeshInstance3D
var _spots: Array[Vector3] = []


func begin_hero(hero: Hero, data: Dictionary, aim: Vector3, _target: Mob) -> void:
	_begin(hero, data, aim, true, Kit.hero_total(hero, data))


func begin_rival(rival: Rival, data: Dictionary, aim: Vector3, target: Node3D) -> void:
	var at := aim
	if Kit.valid(rival, false, target):
		at = target.global_position
	_begin(rival, data, at, false, Kit.rival_total(rival, data))


func _begin(who: Node3D, data: Dictionary, aim: Vector3, hero_side: bool, mult: float) -> void:
	caster = who
	skill = data
	by_hero = hero_side
	total_mult = mult
	center = Kit.flat(aim)
	_field = get_parent()
	_zone = Game.current_zone
	shown = by_hero or (VfxBudget.quality() > 0 and get_tree().get_nodes_in_group("rift_gates_ai_shown").size() < MAX_AI_SHOWN)
	if shown and not by_hero:
		add_to_group("rift_gates_ai_shown")
	var face := Kit.flat(center - who.global_position)
	var base := atan2(face.x, face.z) + PI if face.length() > 0.5 else 0.0
	for i in PORTALS:
		var a := base + TAU * float(i) / float(PORTALS)
		_spots.append(center + Vector3(sin(a), 0.0, cos(a)) * RING + Vector3.UP * PORTAL_HEIGHT)
	if shown:
		Kit.with_room(by_hero, _build)
	Kit.sound(by_hero, center, SkillSound.star_beat(0), -3.0)
	if by_hero:
		BattleVfx.floating_text(_field, center + Vector3.UP * 4.6, String(data.get("name", "")), RIM, 1.0)


## The element of volley [param index] and the portals that fire it (portal i is ELEMENTS[i % 3]).
static func element_of(index: int) -> String:
	return ELEMENTS[index % ELEMENTS.size()]


func _process(delta: float) -> void:
	if gone:
		return
	clock += delta
	if _ending >= 0.0:
		_fade_out()
		return
	if not Kit.caster_ok(caster, _field, _zone):
		_end()
		return
	while volleys < VOLLEYS and clock >= OPEN + GAP * float(volleys):
		_volley(volleys)
		volleys += 1
	_land()
	if shown:
		_draw()
	if volleys >= VOLLEYS and _flying.is_empty():
		_end()


func _exit_tree() -> void:
	gone = true


## In the area: within RADIUS (plus its body) of the aimed point.
func in_area(foe: Node3D) -> bool:
	return Kit.flat(foe.global_position - center).length() <= RADIUS + Kit.body(foe)


func _volley(index: int) -> void:
	var element := element_of(index)
	var final := index == VOLLEYS - 1
	var cap := SHOWN_BOLTS if by_hero else AI_SHOWN_BOLTS
	var drawn := 0
	var targets: Array = []
	for foe: Node3D in Kit.foes(caster, by_hero):
		if in_area(foe):
			targets.append(foe)
	targets.sort_custom(func(a: Node3D, b: Node3D): return a.global_position.distance_squared_to(center) < b.global_position.distance_squared_to(center))
	for foe: Node3D in targets:
		var from := _portal_for(element, foe)
		var show := shown and drawn < cap
		if show:
			drawn += 1
			_shoot(element, from, foe)
		var delay := STRIKE_DELAY if element == "lightning" else FLIGHT
		_flying.append({"at": clock + delay, "foe": weakref(foe), "element": element, "final": final, "shown": show})
	if shown:
		for i in _portals.size():
			if ELEMENTS[i % ELEMENTS.size()] == element and is_instance_valid(_portals[i]):
				var c: Array = LOOK[element]
				var p := _spots[i]
				Kit.with_room(by_hero, func(): VfxKit.flash(_field, p, c[0], 1.8, 0.16))
	if index % 2 == 0:
		Kit.sound(by_hero, center, SkillSound.star_beat(1), -9.0)


## The portal of [param element] nearest [param foe].
func _portal_for(element: String, foe: Node3D) -> Vector3:
	var best := _spots[0]
	var best_d := INF
	for i in _spots.size():
		if ELEMENTS[i % ELEMENTS.size()] != element:
			continue
		var d := _spots[i].distance_squared_to(foe.global_position)
		if d < best_d:
			best_d = d
			best = _spots[i]
	return best


func _shoot(element: String, from: Vector3, foe: Node3D) -> void:
	var c: Array = LOOK[element]
	var to := Kit.hit_point(foe)
	Kit.with_room(by_hero, func():
		match element:
			"fire":
				VfxKit.projectile(_field, c[0], from, to, FLIGHT, 0.5, "flame")
			"ice":
				VfxKit.projectile(_field, c[0], from, to, FLIGHT, 0.45, "shard")
			_:
				VfxKit.lightning(_field, from, to, c[0])
	)


func _land() -> void:
	var i := 0
	while i < _flying.size():
		var bolt: Dictionary = _flying[i]
		if clock < float(bolt.at):
			i += 1
			continue
		_flying.remove_at(i)
		var foe := (bolt.foe as WeakRef).get_ref() as Node3D
		if not Kit.valid(caster, by_hero, foe):
			continue
		var element := String(bolt.element)
		var fx := {}
		match element:
			"fire":
				fx = {"burn": BURN}
			"ice":
				fx = {"slow": CHILL}
			_:
				if bool(bolt.final):
					fx = {"stun": STUN}
		var share := 1.0 / float(VOLLEYS)
		var key := foe.get_instance_id()
		dealt[key] = float(dealt.get(key, 0.0)) + share
		landed[element] = int(landed[element]) + 1
		var at := Kit.hit_point(foe)
		var c: Array = LOOK[element]
		Kit.deal(caster, by_hero, foe, total_mult * share, c[0], Kit.strike(skill, fx))
		if bool(bolt.shown) and is_instance_valid(_field):
			var style := "fire" if element == "fire" else ("ice" if element == "ice" else "thunder")
			Kit.with_room(by_hero, func(): VfxKit.element_impact(_field, at, c[0], style, 0.7))


func _end() -> void:
	if _ending >= 0.0:
		return
	_ending = clock
	_flying.clear()
	remove_from_group("rift_gates_ai_shown")
	if not shown or (_portals.is_empty() and _seal == null):
		gone = true
		queue_free()


func _fade_out() -> void:
	var f := clampf(1.0 - (clock - _ending) / CLOSE, 0.0, 1.0)
	for i in _portals.size():
		var p := _portals[i]
		if is_instance_valid(p):
			Kit.set_fade(p, f)
			p.scale = Vector3.ONE * PORTAL_SIZE * maxf(0.05, f)
	if is_instance_valid(_seal):
		Kit.set_fade(_seal, f * 0.7)
	if f <= 0.0:
		gone = true
		queue_free()


# ---------------------------------------------------------------------------
# Light: the ring of portals over the area and the seal of the area on the ground
# ---------------------------------------------------------------------------

## The seal of the area on the ground: a faint violet ring of runes.
static func seal_material(strength: float) -> ShaderMaterial:
	return Kit.material(Kit.PORTAL, Color("6a3ae0"), Color("9a7aff"), Color("1a0850"), {"flow": 0.6, "strength": strength})


static func portal_material(element: String) -> ShaderMaterial:
	var c: Array = LOOK[element]
	return Kit.material(Kit.PORTAL, RIM, c[0], c[2], {"flow": 2.6 if element != "lightning" else 4.5, "strength": 1.0})


func _build() -> void:
	for i in PORTALS:
		var element: String = ELEMENTS[i % ELEMENTS.size()]
		var p := Kit.light(self, "quad", portal_material(element), "Portal_%s_%d" % [element, i])
		if p == null:
			break
		_portals.append(p)
	_seal = Kit.light(self, "quad", seal_material(0.24), "AreaSeal")
	_draw()


func _draw() -> void:
	var open := smoothstep(0.0, OPEN, clock)
	for i in _portals.size():
		var p := _portals[i]
		if not is_instance_valid(p):
			continue
		# Each portal rises out of its ground sigil and turns to face the area's heart.
		var spot := _spots[i]
		var at := Vector3(spot.x, lerpf(0.3, spot.y, open), spot.z)
		var look := Vector3(center.x, 0.8, center.z) - at
		var basis := Basis.looking_at(look.normalized(), Vector3.UP).rotated(look.normalized(), clock * 1.6 + float(i))
		var breathe := 1.0 + 0.05 * sin(clock * 9.0 + float(i) * 1.7)
		p.global_transform = Transform3D(basis.scaled(Vector3.ONE * PORTAL_SIZE * maxf(0.05, open) * breathe), at)
	if is_instance_valid(_seal):
		_seal.global_transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0).rotated(Vector3.UP, clock * 0.5).scaled(Vector3.ONE * RADIUS * 2.0 * open), center + Vector3.UP * 0.07)


# ---------------------------------------------------------------------------
# The wind-up (combat/god_art/cosmos_genesis.gd): the seal of the area is drawn on the
# ground, a sigil glows where each portal will open, and a small portal turns before the
# mage's raised hands.
# ---------------------------------------------------------------------------

static func telegraph(art: StarSkillArt, caster: Node3D, _skill: Dictionary, point: Vector3, time: float) -> bool:
	if not is_instance_valid(art) or not is_instance_valid(caster):
		return true
	var mid := Kit.flat(point)
	var face := Kit.flat(mid - caster.global_position)
	var base := atan2(face.x, face.z) + PI if face.length() > 0.5 else 0.0
	var nodes: Array = []
	var seal := Kit.light(art, "quad", seal_material(0.24), "WindupSeal")
	if seal:
		Kit.set_fade(seal, 0.0)
		seal.global_transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0).scaled(Vector3.ONE * RADIUS * 2.0), mid + Vector3.UP * 0.07)
		nodes.append([seal, 0.0, 0.7])
	for i in PORTALS:
		var a := base + TAU * float(i) / float(PORTALS)
		var sigil := Kit.light(art, "quad", portal_material(ELEMENTS[i % ELEMENTS.size()]), "WindupSigil_%d" % i)
		if sigil == null:
			break
		Kit.set_fade(sigil, 0.0)
		sigil.global_transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0).scaled(Vector3.ONE * 1.4), mid + Vector3(sin(a), 0.0, cos(a)) * RING + Vector3.UP * 0.3)
		nodes.append([sigil, time * (0.15 + 0.08 * float(i)), 1.0])
	var hands := Kit.light(art, "quad", portal_material("lightning"), "WindupHands")
	if hands:
		Kit.set_fade(hands, 0.0)
		var ahead := Kit.flat(face).normalized() if face.length() > 0.5 else Vector3.FORWARD
		hands.global_transform = Transform3D(Basis.looking_at(ahead, Vector3.UP).scaled(Vector3.ONE * 1.1), Kit.flat(caster.global_position) + ahead * 0.9 + Vector3.UP * 1.9)
		nodes.append([hands, 0.0, 1.0])
		var spin := hands.create_tween().set_loops(4)
		spin.tween_method(func(v: float): hands.rotation.z = v, 0.0, TAU, maxf(time / 3.0, 0.1))
	for entry in nodes:
		var node: GeometryInstance3D = entry[0]
		var t := node.create_tween()
		t.tween_interval(float(entry[1]))
		t.tween_method(func(v: float): Kit.set_fade(node, v), 0.0, float(entry[2]), maxf(time * 0.35, 0.05))
	return true
