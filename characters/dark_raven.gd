class_name DarkRaven
extends Node3D
## The Dark Lord's raven. It perches upright on the Lord's raised left forearm,
## wings folded, turning its head to watch the field, and on command (the raven
## button on the HUD for the hero; always for an AI Lord in a fight) flies off and
## hunts on its own: it circles on spread wings, banking, folds them into a stoop,
## throws its talons forward and strikes (LordSkillArt.raven_peck), then climbs
## away to circle again. With nothing to fight, or called back, it flies home and
## flares its wings to land on the arm.
##
## Three ways to hunt (the mode button on the HUD, remembered with the character):
##   SINGLE (เดี่ยว)  the Lord's own target, one hard strike at a time
##   GROUP (หมู่)     the Lord's own target, every strike tearing into all the
##                    monsters around it
##   AUTO (ออโต้)     picks its own prey (the nearest monster) and strikes the
##                    pack when three or more stand together, else one alone
##
## The owner (Hero, Companion / FieldPlayer, or a Rival / GuildFighter, whose raven
## only perches) provides:
##   visual: HeroVisual or RivalVisual (perch_point(), equip, dressed)
##   raven_target() -> Mob             the monster to go for (by mode), or null
##   raven_strike(mob, group)          one strike (damage, credit)
## Built from simple shapes in code, one material per colour: blue-black plumage
## with a violet sheen, glowing red eyes under dark brows, a heavy black beak,
## shaggy throat feathers, a wedge-shaped tail, dark feet with black talons and a
## gold band and crimson jess on one leg.
##
## The bird grows grander with the Lord's scepter (Look, from the worn weapon, and
## rebuilt whenever the owner re-dresses):
##   Lv.10-40 scepters      the blue-black raven above
##   Lv.50-90 scepters      plumage in the scepter's theme: ember-red edges and
##                          flickering flame tips (fire dragon), frost-blue tips and
##                          ice crystals (ice), violet sheen in drifting smoke
##                          (shadow), pale gold edges and plumes (holy), electric
##                          glints crackling on the wings (thunder)
##   Lv.100 scepter         bigger and glossy, with a small gold crown
##   star scepters          glowing tips in the star set's colours and stardust
##                          trailing from the tail, more of both per star tier
##   divine scepter         the emperor raven: black-and-gold wings, violet fire in
##                          the eyes, a gold ring floating over the head
## The glow, the moving extras and the stardust follow the graphics quality (none
## on the lowest, or while memory is tight; the stardust is one draw surface that
## counts as a VfxBudget decoration); the colours and shapes stay at every quality.

enum State { PERCH, FLY, RETURN }
enum Mode { SINGLE, GROUP, AUTO }

const MODE_NAMES := ["เดี่ยว", "หมู่", "ออโต้"]
const SIZE := 0.56
const SPEED := 13.0
const STRIKE_EVERY := 0.85
const LEASH := 22.0
## A group strike reaches every monster this close to the one it dives on.
const GROUP_RADIUS := 3.2
const VIOLET := Color("8a4dff")
## The bird's look, from the owner's weapon (look_for).
enum Look { PLAIN, FIRE, ICE, SHADOW, HOLY, THUNDER, CROWN, STAR_50, STAR_100, STAR_150, STAR_200, DIVINE }
const LOOK_NAMES := ["อีกาทมิฬ", "อีกามังกรเพลิง", "อีกาน้ำแข็ง", "อีกาเงามืด", "อีกาศักดิ์สิทธิ์", "อีกาสายฟ้า",
	"ราชาอีกา", "อีกาดารา ★50", "อีกาดารา ★100", "อีกาดารา ★150", "อีกาดารา ★200", "จักรพรรดิอีกาทมิฬ"]
## Stardust: seconds each mote lives, and how far it sinks.
const DUST_LIFE := 0.7
const DUST_SINK := 0.55
## The moving extras of a look (_animate_look).
enum Fx { FLAME, GLINT, SMOKE, RING, TWINKLE }
static var _palettes: Dictionary = {}
static var _dust_material: StandardMaterial3D

var owner_ref: WeakRef
var attack := false
var mode := Mode.AUTO
var state := State.PERCH
var _target_ref: WeakRef
var _strike_timer := 0.0
var _retarget := 0.0
var _dive := 0.0
var _orbit := 0.0
var _flap := 0.0
var _clock := 0.0
## Smoothed pose: pitch (nose-down degrees), wings 0 folded..1 spread, legs -1 tucked..1 talons out.
var _pitch := -52.0
var _spread := 0.0
var _legs := 0.0
var _bank := 0.0
var _look := 0.0
var _body: Node3D
var _head: Node3D
var _tail: Node3D
var _wings: Array[Node3D] = []
var _hands: Array[Node3D] = []
var _feet: Array[Node3D] = []
var _tail_feathers: Array[Node3D] = []
var _eyes: StandardMaterial3D
## The look now worn and whether its glow and moving extras are on (quality).
var look := Look.PLAIN
var fancy := false
var _dressed := -1
var _root: Node3D
## The look's moving extras (Fx), side by side: node, kind, phase, rest scale and place.
var _fx: Array[Node3D] = []
var _fx_kind: PackedInt32Array = PackedInt32Array()
var _fx_phase: PackedFloat32Array = PackedFloat32Array()
var _fx_scale: PackedVector3Array = PackedVector3Array()
var _fx_at: PackedVector3Array = PackedVector3Array()
var _glow: StandardMaterial3D
var _glow_energy := 0.0
## Stardust: one MultiMesh in world space, a ring of motes dropped from the tail.
var _dust: MultiMeshInstance3D
var _dust_at: PackedVector3Array = PackedVector3Array()
var _dust_born: PackedFloat32Array = PackedFloat32Array()
var _dust_colors: PackedColorArray = PackedColorArray()
var _dust_head := 0
var _dust_timer := 0.0
var _dust_size := 0.1
var _dust_retry := 0.0
var _scale := 1.0
var _wants_dust := false


## Gives `owner_node` a raven (once) and returns it.
static func ensure(owner_node: Node3D) -> DarkRaven:
	for child in owner_node.get_children():
		if child is DarkRaven:
			return child
	var raven := DarkRaven.new()
	raven.owner_ref = weakref(owner_node)
	raven.name = "DarkRaven"
	owner_node.add_child(raven)
	return raven


## Takes the raven away (another class).
static func remove(owner_node: Node3D) -> void:
	for child in owner_node.get_children():
		if child is DarkRaven:
			child.queue_free()


## Live monsters within [param radius] of [param at] (the pack a group strike reaches).
static func pack(tree: SceneTree, at: Vector3, radius: float) -> Array[Mob]:
	var out: Array[Mob] = []
	for node in tree.get_nodes_in_group("mobs"):
		var mob := node as Mob
		if mob and is_instance_valid(mob) and not mob.is_dead() and mob.hostile:
			var d := mob.global_position - at
			if Vector2(d.x, d.z).length() <= radius:
				out.append(mob)
	return out


func _ready() -> void:
	top_level = true
	add_to_group("dark_ravens")
	var lord := _lord()
	var visual := _visual(lord) if lord != null else null
	if visual != null:
		_dressed = visual.dressed
		look = DarkRaven.look_for(visual.equip.get("weapon"))
	fancy = DarkRaven.rich()
	_build()
	_animate(1.0, "perch")
	if lord != null:
		global_position = _perch(lord)


## Which look a weapon gives the raven: the scepter's tier (Lv.50-90 themes, the
## Lv.100 crown), a star scepter's tier, or the divine scepter.
static func look_for(weapon: Variant) -> int:
	if not (weapon is Dictionary) or (weapon as Dictionary).is_empty():
		return Look.PLAIN
	if DivineGearData.is_item(weapon):
		return Look.DIVINE
	if StarGearData.is_star(weapon):
		return Look.STAR_50 + StarGearData.index(int(weapon.star_tier))
	var tier := ItemLook.tier_of(weapon)
	if tier >= 9:
		return Look.CROWN
	return Look.FIRE + tier - 4 if tier >= 4 else Look.PLAIN


## The glow, the moving extras and the stardust are drawn (medium and high
## quality, memory not tight).
static func rich() -> bool:
	return GameSettings.quality > 0 and MemoryGuard.pressure < 2


## The colours and extras of a look (built once per look).
static func palette(p_look: int) -> Dictionary:
	if _palettes.has(p_look):
		return _palettes[p_look]
	var p := {
		"black": Color("16111c"), "sheen": Color("2c2244"), "edge": Color("5a43a0"), "tip": Color("3d2d6e"),
		"dark": Color("0b080e"), "beak": Color("1f1d24"), "feet": Color("2a2630"), "eye": Color("ff3a3a"),
		"covert": Color("2c2244"), "second": Color("2c2244"), "glow": 0.0, "size": 1.0, "rim": false,
		"fx": "", "dust": 0, "dust_a": Color.WHITE, "dust_b": Color.WHITE, "accent": Color("f0c058"),
	}
	match p_look:
		Look.FIRE:
			p.merge({"black": Color("1c1010"), "sheen": Color("5a2218"), "edge": Color("e8482a"), "tip": Color("ff6a26"),
				"dark": Color("100808"), "eye": Color("ffb03a"), "covert": Color("7a2618"), "second": Color("8a2a16"),
				"glow": 1.5, "fx": "fire", "accent": Color("ffb03a")}, true)
		Look.ICE:
			p.merge({"black": Color("151c2a"), "sheen": Color("4a82b0"), "edge": Color("a8e4ff"), "tip": Color("d8f4ff"),
				"dark": Color("0c121c"), "eye": Color("8fe8ff"), "covert": Color("6aaad8"), "second": Color("4a86b8"),
				"glow": 0.8, "fx": "ice", "accent": Color("bff0ff")}, true)
		Look.SHADOW:
			p.merge({"black": Color("130b1c"), "sheen": Color("50288a"), "edge": Color("a466ff"), "tip": Color("b06bff"),
				"dark": Color("0a0612"), "eye": Color("d070ff"), "covert": Color("5e30a0"), "second": Color("47227c"),
				"glow": 1.4, "fx": "shadow", "accent": Color("8a4dff")}, true)
		Look.HOLY:
			p.merge({"black": Color("1e1824"), "sheen": Color("5a5064"), "edge": Color("f2d070"), "tip": Color("fff2c8"),
				"dark": Color("120e16"), "eye": Color("ffe27a"), "covert": Color("9a8c94"), "second": Color("6e6270"),
				"glow": 1.0, "fx": "holy", "accent": Color("f6d37a")}, true)
		Look.THUNDER:
			p.merge({"black": Color("12141e"), "sheen": Color("3a4458"), "edge": Color("5ad0ff"), "tip": Color("e8fbff"),
				"dark": Color("0a0c14"), "eye": Color("e8fbff"), "covert": Color("525e76"), "second": Color("2a303e"),
				"glow": 1.5, "fx": "thunder", "accent": Color("e8fbff")}, true)
		Look.CROWN:
			p.merge({"black": Color("140c20"), "sheen": Color("4a36a0"), "edge": Color("9a66f0"), "tip": Color("f2c45a"),
				"dark": Color("0c0716"), "eye": Color("ff3050"), "covert": Color("5a40b8"), "second": Color("46329a"),
				"glow": 0.6, "size": 1.15, "rim": true, "fx": "crown", "accent": Color("f2c45a")}, true)
		Look.STAR_50, Look.STAR_100, Look.STAR_150, Look.STAR_200:
			var i := p_look - Look.STAR_50
			var star := StarGearData.palette(50 * (i + 1), "darklord")
			var dark: Color = star.dark
			var cloth: Color = star.cloth
			p.merge({"black": Color("16111c").lerp(dark, 0.3), "sheen": cloth, "edge": star.metal,
				"tip": star.gem, "dark": Color("0b080e").lerp(dark, 0.25), "eye": star.gem,
				"covert": cloth.lerp(star.gem, 0.22), "second": dark.lerp(cloth, 0.6), "glow": 1.0 + 0.3 * i,
				"size": 1.0 + 0.04 * i, "rim": i >= 2, "fx": "star", "dust": [8, 12, 16, 24][i],
				"dust_a": star.gem, "dust_b": star.edge, "accent": star.metal, "star": i}, true)
		Look.DIVINE:
			p.merge({"black": Color("0e0a10"), "sheen": Color("2a1420"), "edge": Color("f2c45a"), "tip": Color("ffd870"),
				"dark": Color("08060a"), "beak": Color("1a1418"), "eye": Color("b06bff"), "covert": Color("e8b64a"),
				"second": Color("1c1418"), "glow": 1.2, "size": 1.24, "rim": true, "fx": "divine", "dust": 18,
				"dust_a": Color("ffd870"), "dust_b": Color("b06bff"), "accent": Color("e8b64a")}, true)
	_palettes[p_look] = p
	return p


## The owner's HeroVisual (a Rival's sits inside its RivalVisual), or null.
static func _visual(lord: Node3D) -> HeroVisual:
	var visual: Variant = lord.get("visual")
	if not is_instance_valid(visual):
		return null
	if visual is RivalVisual:
		visual = (visual as RivalVisual).hero_visual
	return visual as HeroVisual if is_instance_valid(visual) and visual is HeroVisual else null


## Rebuilds the bird when the owner's weapon or the graphics quality has changed.
func _sync_look(lord: Node3D) -> void:
	var visual := _visual(lord)
	var now_rich := DarkRaven.rich()
	if visual != null and visual.dressed != _dressed:
		_dressed = visual.dressed
		var next := DarkRaven.look_for(visual.equip.get("weapon"))
		if next != look or now_rich != fancy:
			look = next
			fancy = now_rich
			_rebuild()
		return
	if now_rich != fancy:
		fancy = now_rich
		_rebuild()


## Frees the bird and builds it again in the current look, keeping its pose.
func _rebuild() -> void:
	if _root != null and is_instance_valid(_root):
		_root.free()
	if _dust != null and is_instance_valid(_dust):
		_dust.free()
	_root = null
	_dust = null
	_wings.clear()
	_hands.clear()
	_feet.clear()
	_tail_feathers.clear()
	_fx.clear()
	_fx_kind.clear()
	_fx_phase.clear()
	_fx_scale.clear()
	_fx_at.clear()
	_glow = null
	_build()
	_animate(0.0, "perch" if state == State.PERCH else "glide")


func _lord() -> Node3D:
	var lord := owner_ref.get_ref() as Node3D if owner_ref != null else null
	return lord if is_instance_valid(lord) and lord.is_inside_tree() else null


func _perch(lord: Node3D) -> Vector3:
	var visual := _visual(lord)
	if visual != null:
		return visual.perch_point()
	return lord.global_position + Vector3(-0.35, 1.2, 0.25)


## True when this strike should tear into the pack rather than one monster.
func strikes_pack(target: Mob) -> bool:
	match mode:
		Mode.GROUP:
			return true
		Mode.AUTO:
			return is_inside_tree() and DarkRaven.pack(get_tree(), target.global_position, GROUP_RADIUS).size() >= 3
	return false


func _process(delta: float) -> void:
	_clock += delta
	var lord := _lord()
	if lord == null:
		return
	if not global_position.is_finite():
		state = State.PERCH
		global_position = _perch(lord) if _perch(lord).is_finite() else Vector3.ZERO
	var dead: bool = lord.call("is_dead") if lord.has_method("is_dead") else false
	visible = not dead
	_sync_look(lord)
	var target := _target_ref.get_ref() as Mob if _target_ref != null else null
	if target != null and (not is_instance_valid(target) or target.is_dead()):
		target = null
	match state:
		State.PERCH:
			global_position = _perch(lord)
			var body := _visual(lord)
			var facing: Vector3 = body.global_basis.z if body != null else lord.global_basis.z
			look_at(global_position + Vector3(facing.x, 0, facing.z), Vector3.UP, true)
			_animate(delta, "perch")
			if attack and not dead:
				var next := lord.call("raven_target") as Mob
				if next != null:
					_target_ref = weakref(next)
					state = State.FLY
					_dive = 0.0
		State.FLY:
			# Follow the Lord's choice: a new target (single, group) or new prey (auto).
			_retarget -= delta
			if attack and (target == null or _retarget <= 0.0) and _strike_timer > 0.0:
				_retarget = 0.3
				var next := lord.call("raven_target") as Mob
				if next != null:
					_target_ref = weakref(next)
					target = next
			if target == null and attack:
				var next := lord.call("raven_target") as Mob
				if next != null:
					_target_ref = weakref(next)
					target = next
			if target == null or not attack or dead or target.global_position.distance_to(lord.global_position) > LEASH:
				state = State.RETURN
				_animate(delta, "flap")
			else:
				_fight(lord, target, delta)
		State.RETURN:
			var home := _perch(lord)
			_fly_to(home, delta, SPEED * 1.2)
			var near := global_position.distance_to(home)
			_animate(delta, "land" if near < 1.2 else "flap")
			if near < 0.25:
				state = State.PERCH


## Circles over the target on spread wings and stoops on it every STRIKE_EVERY seconds.
func _fight(lord: Node3D, target: Mob, delta: float) -> void:
	_strike_timer -= delta
	_orbit += delta * 2.4
	var center := target.global_position + Vector3(0, 1.0, 0)
	var goal := center + Vector3(cos(_orbit) * 1.6, 1.6, sin(_orbit) * 1.6)
	var pose := "glide"
	if _strike_timer <= 0.0:
		# The stoop: wings folded, straight at the target's body, talons out on contact.
		_dive += delta * 4.0
		goal = target.hit_point() if target.has_method("hit_point") else center
		pose = "strike" if global_position.distance_to(goal) < 1.0 else "stoop"
		if global_position.distance_to(goal) < 0.45 or _dive > 1.0:
			var group := strikes_pack(target)
			var from := global_position
			lord.call("raven_strike", target, group)
			_strike_timer = STRIKE_EVERY
			_dive = 0.0
			_retarget = 0.0
			LordSkillArt.raven_peck(target.get_parent() as Node3D, goal, from, group, GROUP_RADIUS)
	_fly_to(goal, delta, SPEED * (1.5 if _strike_timer <= 0.0 else 0.8))
	_bank = lerpf(_bank, 28.0 if _strike_timer > 0.0 else 0.0, minf(1.0, delta * 4.0))
	_animate(delta, pose)


func _fly_to(goal: Vector3, delta: float, speed: float) -> void:
	var step := goal - global_position
	var move := step.limit_length(speed * delta)
	global_position += move
	if move.length_squared() > 0.000001:
		var flat := Vector3(move.x, move.y * 0.4, move.z)
		if flat.length_squared() > 0.000001 and absf(flat.normalized().dot(Vector3.UP)) < 0.98:
			look_at(global_position + flat, Vector3.UP, true)


## Poses the raven for a moment of its flight: "perch", "glide", "flap", "stoop",
## "strike" or "land". Every part eases towards its pose, so changes blend.
func _animate(delta: float, pose: String) -> void:
	var blend := minf(1.0, delta * 8.0)
	var pitch := 0.0
	var spread := 1.0
	var legs := -1.0
	var flap_speed := 0.0
	var flap_amp := 0.0
	match pose:
		"perch":
			pitch = -52.0; spread = 0.0; legs = 0.0
		"glide":
			pitch = 4.0; spread = 1.0; legs = -1.0; flap_speed = 3.0; flap_amp = 0.12
		"flap":
			pitch = -6.0; spread = 1.0; legs = -1.0; flap_speed = 13.0; flap_amp = 0.85
		"stoop":
			pitch = 32.0; spread = 0.25; legs = -1.0
		"strike":
			pitch = -24.0; spread = 0.8; legs = 1.0; flap_speed = 16.0; flap_amp = 0.5
		"land":
			pitch = -40.0; spread = 1.0; legs = 1.0; flap_speed = 10.0; flap_amp = 0.6
	if pose != "glide":
		_bank = lerpf(_bank, 0.0, blend)
	_pitch = lerpf(_pitch, pitch, blend)
	_spread = lerpf(_spread, spread, blend)
	_legs = lerpf(_legs, legs, blend)
	_flap += delta * flap_speed
	var flap := sin(_flap) * flap_amp * _spread
	# _pitch is nose-down degrees: perched it sits upright, stooping it points down.
	_body.rotation_degrees = Vector3(_pitch, 0, _bank)
	# The head stays level and, perched, looks about now and then.
	var watch := 0.0
	if pose == "perch":
		watch = clampf(sin(_clock * 0.7) * 1.6 + sin(_clock * 1.9) * 0.6, -1.0, 1.0) * 55.0
	_look = lerpf(_look, watch, minf(1.0, delta * 5.0))
	_head.rotation_degrees = Vector3(-_pitch * 0.9, _look, -_bank * 0.5)
	for i in _wings.size():
		var side := -1.0 if i == 0 else 1.0
		var fold := 1.0 - _spread
		var breathe := sin(_clock * 1.6) * 0.03 * fold
		# Folding rolls the wing upright onto the flank (leading edge up), then swings
		# it back along the body: the flight feathers end at the tail.
		_wings[i].rotation = Vector3(-1.45 * fold, side * 1.38 * fold, side * (flap + 0.18 * _spread + breathe))
		_hands[i].rotation = Vector3(0, side * 0.12 * fold, side * (sin(_flap - 0.7) * flap_amp * 0.6 * _spread))
	for i in _tail_feathers.size():
		_tail_feathers[i].rotation.y = (float(i) - 2.0) * deg_to_rad(4.0 + 8.0 * _spread)
	_tail.rotation_degrees.x = 10.0 * (1.0 - _spread) - 6.0 * _spread
	# Legs hang straight down whatever the body's pitch; tucked back in flight,
	# thrown forward for a strike.
	for foot in _feet:
		foot.rotation_degrees.x = -_pitch + 70.0 * maxf(0.0, -_legs) - 75.0 * maxf(0.0, _legs)
	var fierce := pose == "stoop" or pose == "strike"
	if _eyes:
		_eyes.emission_energy_multiplier = (2.6 if fierce else 1.3) * (1.4 if look == Look.DIVINE else 1.0)
	_animate_look(delta, fierce)


## The look's moving extras, the glow's slow pulse and the stardust (no allocation).
func _animate_look(delta: float, fierce: bool) -> void:
	if _glow != null:
		_glow.emission_energy_multiplier = _glow_energy * (1.0 + 0.22 * sin(_clock * 3.1)) * (1.35 if fierce else 1.0)
	for i in _fx.size():
		var node := _fx[i]
		var phase := _fx_phase[i]
		var base := _fx_scale[i]
		match _fx_kind[i]:
			Fx.FLAME:
				var f := 1.0 + 0.28 * sin(_clock * 17.0 + phase) + 0.14 * sin(_clock * 29.0 + phase * 2.3)
				node.scale = Vector3(base.x * (1.15 - 0.15 * f), base.y * f, base.z * (1.15 - 0.15 * f))
			Fx.GLINT:
				var t := fposmod(_clock * 1.25 + phase, 1.0)
				node.visible = t < 0.22 or (t > 0.3 and t < 0.4)
				node.scale = base * (0.8 + 0.4 * fposmod(phase * 7.3 + floorf(_clock * 1.25 + phase) * 0.37, 1.0))
			Fx.SMOKE:
				var t := fposmod(_clock * 0.55 + phase, 1.0)
				node.position = _fx_at[i] + Vector3(0, t * 0.05, -t * 0.16)
				node.scale = base * (0.25 + sin(t * PI) * 0.95)
			Fx.RING:
				node.position.y = _fx_at[i].y + sin(_clock * 2.0) * 0.018
				node.rotation.y = _clock * 0.9
			Fx.TWINKLE:
				node.scale = base * (0.6 + 0.5 * maxf(0.0, sin(_clock * 4.0 + phase)))
	if _dust != null:
		_update_dust(delta)
	elif _wants_dust:
		# The decoration budget was spent when the bird was built: try again now and then.
		_dust_retry -= delta
		if _dust_retry <= 0.0:
			_dust_retry = 2.0
			_make_dust(DarkRaven.palette(look))


## Drops a mote from the tail now and then; each one sinks, drifts and fades.
func _update_dust(delta: float) -> void:
	var n := _dust_at.size()
	var multi := _dust.multimesh
	_dust_timer -= delta
	if _dust_timer <= 0.0 and _tail != null:
		_dust_timer = DUST_LIFE / float(n) * (1.6 if state == State.PERCH else 1.0)
		_dust_at[_dust_head] = _tail.global_transform * Vector3(0, 0, -0.3)
		_dust_born[_dust_head] = _clock
		_dust_head = (_dust_head + 1) % n
	for i in n:
		var t := (_clock - _dust_born[i]) / DUST_LIFE
		if t < 0.0 or t >= 1.0:
			multi.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), _dust_at[i]))
			continue
		var k := float(i)
		var pos := _dust_at[i] + Vector3(sin(k * 2.1 + _clock * 3.0) * 0.06 * t, -DUST_SINK * t * t, cos(k * 1.3 + _clock * 2.0) * 0.06 * t)
		var s := _dust_size * (1.0 - t * 0.8) * (0.75 + 0.35 * sin(_clock * 11.0 + k * 1.7))
		multi.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(s, s, s)), pos))
		var c := _dust_colors[i % 2]
		c.a = 1.0 - t * t
		multi.set_instance_color(i, c)


## The stardust: one billboard MultiMesh in world space, one budget decoration.
func _make_dust(p: Dictionary) -> void:
	if not VfxBudget.can_decorate():
		return
	var n := clampi(VfxBudget.count(int(p.dust), 4), 4, 32)
	if _dust_material == null:
		_dust_material = StandardMaterial3D.new()
		_dust_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_dust_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_dust_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_dust_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_dust_material.billboard_keep_scale = true
		_dust_material.vertex_color_use_as_albedo = true
		_dust_material.albedo_texture = VfxArt.texture("flare")
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = MeshKit.quad()
	multi.instance_count = n
	_dust = MultiMeshInstance3D.new()
	_dust.name = "Stardust"
	_dust.multimesh = multi
	_dust.material_override = _dust_material
	_dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dust.custom_aabb = AABB(Vector3(-4000, -400, -4000), Vector3(8000, 800, 8000))
	_dust.top_level = true
	add_child(_dust)
	_dust.global_transform = Transform3D.IDENTITY
	VfxBudget.track_decoration(_dust)
	_dust_at.resize(n)
	_dust_born.resize(n)
	_dust_born.fill(-100.0)
	var star := int(p.get("star", 2))
	_dust_size = (0.26 + 0.05 * star) * _scale
	_dust_colors = PackedColorArray([p.dust_a, p.dust_b])
	_dust_head = 0
	_dust_timer = 0.0
	for i in n:
		multi.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), global_position))
		multi.set_instance_color(i, _dust_colors[i % 2])


## A look material: glossy (rim) for the grander looks, glowing only when rich.
func _mat(color: Color, rim := false, glow := 0.0) -> StandardMaterial3D:
	var opts := {}
	if rim:
		opts["rim"] = true
	if glow > 0.0 and fancy:
		opts["emission"] = glow
	return MeshKit.toon(color, opts)


## A raven of simple shapes, facing +Z, its feet at the origin: body, head with a
## heavy beak, brows and throat hackles, two wings (a shoulder pivot and a hand
## pivot carrying the five fingered flight feathers), a wedge tail and two legs,
## then the extras of its look (look_for).
func _build() -> void:
	var p := DarkRaven.palette(look)
	var fx: String = p.fx
	var rim: bool = p.rim
	var glow: float = p.glow
	_scale = float(p.size)
	_root = Node3D.new()
	_root.name = "Raven"
	_root.scale = Vector3.ONE * SIZE * _scale
	add_child(_root)
	var black := _mat(p.black, rim)
	var sheen := _mat(p.sheen, rim)
	var covert := _mat(p.covert, rim)
	var second := _mat(p.second, rim)
	var edge := _mat(p.edge, rim, glow * 0.3)
	var dark := _mat(p.dark, rim)
	var beak := _mat(p.beak, rim)
	var feet := MeshKit.toon(p.feet)
	var gold := MeshKit.toon(p.accent, {"emission": 0.15})
	var jess := MeshKit.toon(Color("a01e30"))
	var tip := _mat(p.tip, rim)
	if glow > 0.0 and fancy:
		_glow = (MeshKit.toon(p.tip, {"emission": glow}) as StandardMaterial3D).duplicate()
		_glow_energy = glow
		tip = _glow
	_eyes = (MeshKit.toon(p.eye, {"emission": 1.3}) as StandardMaterial3D).duplicate()
	_body = Node3D.new()
	_body.name = "Body"
	_body.position = Vector3(0, 0.2, 0)
	_root.add_child(_body)
	# Body, a sheen on the back and a deep breast.
	_piece(_body, MeshKit.sphere_low(), black, Vector3(0, 0.02, 0), Vector3(0.3, 0.27, 0.56))
	_piece(_body, MeshKit.sphere_low(), sheen, Vector3(0, 0.08, -0.04), Vector3(0.24, 0.16, 0.44))
	_piece(_body, MeshKit.sphere_low(), black, Vector3(0, -0.04, 0.09), Vector3(0.25, 0.24, 0.4))
	if look != Look.PLAIN:
		# A chevron of the look's colour down the breast (seen when it perches).
		for side in [-1.0, 1.0]:
			_piece(_body, MeshKit.sphere_low(), edge, Vector3(side * 0.035, -0.1, 0.27), Vector3(0.022, 0.12, 0.018), Vector3(0, 0, side * -30.0))
			_piece(_body, MeshKit.sphere_low(), tip, Vector3(side * 0.03, -0.15, 0.25), Vector3(0.02, 0.09, 0.016), Vector3(18, 0, side * -34.0))
	# Head on a level-keeping pivot.
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, 0.1, 0.27)
	_body.add_child(_head)
	_piece(_head, MeshKit.sphere_low(), black, Vector3(0, 0.03, 0), Vector3(0.22, 0.21, 0.25))
	_piece(_head, MeshKit.sphere_low(), sheen, Vector3(0, 0.08, -0.02), Vector3(0.15, 0.08, 0.18))
	# Shaggy throat hackles under the beak.
	for k in 3:
		_piece(_head, MeshKit.cone(), black, Vector3((float(k) - 1.0) * 0.04, -0.07, 0.07), Vector3(0.05, 0.08, 0.04), Vector3(160, 0, (float(k) - 1.0) * 12.0))
	# Brows over glowing eyes (gold brows on the emperor).
	var brow := gold if fx == "divine" else dark
	for side in [-1.0, 1.0]:
		_piece(_head, MeshKit.box(), brow, Vector3(side * 0.07, 0.075, 0.075), Vector3(0.07, 0.022, 0.06), Vector3(0, 0, side * -18.0))
		_piece(_head, MeshKit.sphere_low(), _eyes, Vector3(side * 0.078, 0.04, 0.08), Vector3(0.045, 0.045, 0.04) * (1.25 if fx == "divine" else 1.0))
	# The heavy beak: a thick base, a long ridge curving down to the tip, a lower mandible.
	_piece(_head, MeshKit.sphere_low(), beak, Vector3(0, 0.01, 0.12), Vector3(0.085, 0.075, 0.08))
	_piece(_head, MeshKit.cone(), beak, Vector3(0, 0.012, 0.19), Vector3(0.07, 0.15, 0.06), Vector3(96, 0, 0))
	_piece(_head, MeshKit.cone(), beak, Vector3(0, -0.018, 0.17), Vector3(0.05, 0.1, 0.04), Vector3(84, 0, 0))
	_piece(_head, MeshKit.cone(), gold if fx in ["holy", "divine"] else beak, Vector3(0, -0.006, 0.262), Vector3(0.025, 0.035, 0.02), Vector3(150, 0, 0))
	# Wings.
	for side in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.name = "Wing"
		wing.position = Vector3(side * 0.12, 0.08, 0.08)
		_body.add_child(wing)
		# Coverts over the arm, a sheened leading edge, secondaries trailing behind.
		_piece(wing, MeshKit.sphere_low(), covert, Vector3(side * 0.2, 0.0, -0.02), Vector3(0.42, 0.05, 0.2))
		_piece(wing, MeshKit.sphere_low(), edge, Vector3(side * 0.2, 0.012, 0.06), Vector3(0.38, 0.03, 0.05))
		for k in 6:
			_piece(wing, MeshKit.sphere_low(), black if k % 2 == 0 else second, Vector3(side * (0.04 + k * 0.066), -0.008 - k * 0.001, -0.13),
				Vector3(0.12, 0.018, 0.27), Vector3(0, side * -6.0, 0))
		var hand := Node3D.new()
		hand.name = "Hand"
		hand.position = Vector3(side * 0.4, 0, 0)
		wing.add_child(hand)
		_piece(hand, MeshKit.sphere_low(), covert, Vector3(side * 0.04, 0.0, -0.03), Vector3(0.16, 0.026, 0.19))
		if look != Look.PLAIN:
			_piece(hand, MeshKit.sphere_low(), edge, Vector3(side * 0.05, 0.008, 0.055), Vector3(0.14, 0.022, 0.04))
		# The five fingered flight feathers, the look's colour towards the tips.
		for k in 5:
			var ang: float = side * (4.0 - k * 15.0)
			var feather := Node3D.new()
			feather.position = Vector3(side * 0.05, -0.004 * k, -0.01 - k * 0.035)
			feather.rotation_degrees = Vector3(0, ang, 0)
			hand.add_child(feather)
			var length := 0.42 - k * 0.04
			_piece(feather, MeshKit.sphere_low(), dark if k % 2 == 0 else black, Vector3(side * length * 0.5, 0, 0), Vector3(length, 0.016, 0.105))
			_piece(feather, MeshKit.sphere_low(), tip, Vector3(side * (length - 0.07), 0.003, 0), Vector3(0.12, 0.017, 0.08))
			_feather_extra(feather, fx, side, length, k)
		_wing_extra(wing, hand, fx, side)
		_wings.append(wing)
		_hands.append(hand)
	# The wedge tail: the middle feathers longest.
	_tail = Node3D.new()
	_tail.name = "Tail"
	_tail.position = Vector3(0, 0.0, -0.24)
	_body.add_child(_tail)
	for k in 5:
		var feather := Node3D.new()
		_tail.add_child(feather)
		var length := 0.36 - absf(float(k) - 2.0) * 0.05
		_piece(feather, MeshKit.sphere_low(), black if k != 2 else sheen, Vector3(0, -0.002 * absf(k - 2.0), -length * 0.5), Vector3(0.08, 0.016, length))
		_piece(feather, MeshKit.sphere_low(), tip, Vector3(0, 0.001, -length + 0.06), Vector3(0.07, 0.017, 0.1))
		_tail_extra(feather, fx, length, k)
		_tail_feathers.append(feather)
	# Legs: feathered thighs, dark shanks, three toes forward and one back, black talons.
	for side in [-1.0, 1.0]:
		var foot := Node3D.new()
		foot.name = "Leg"
		foot.position = Vector3(side * 0.07, -0.08, 0.06)
		_body.add_child(foot)
		_piece(foot, MeshKit.sphere_low(), black, Vector3(0, -0.02, 0), Vector3(0.1, 0.12, 0.1))
		_piece(foot, MeshKit.cylinder(), feet, Vector3(0, -0.1, 0.0), Vector3(0.032, 0.1, 0.032))
		for k in 3:
			var toe := (float(k) - 1.0) * 25.0
			_piece(foot, MeshKit.box(), feet, Vector3(sin(deg_to_rad(toe)) * 0.04, -0.15, cos(deg_to_rad(toe)) * 0.04),
				Vector3(0.02, 0.02, 0.08), Vector3(0, toe, 0))
			_piece(foot, MeshKit.cone(), dark, Vector3(sin(deg_to_rad(toe)) * 0.085, -0.16, cos(deg_to_rad(toe)) * 0.085),
				Vector3(0.018, 0.04, 0.018), Vector3(120, toe, 0))
		_piece(foot, MeshKit.box(), feet, Vector3(0, -0.15, -0.035), Vector3(0.02, 0.02, 0.06))
		if side > 0.0:
			# A band (gold, or the look's metal) and a crimson jess: the Lord's own bird.
			_piece(foot, MeshKit.cylinder(), gold, Vector3(0, -0.075, 0.0), Vector3(0.05, 0.022, 0.05))
			_piece(foot, MeshKit.box(), jess, Vector3(0.0, -0.12, -0.03), Vector3(0.018, 0.09, 0.008), Vector3(14, 0, 0))
		_feet.append(foot)
	_head_extra(fx, p)
	_wants_dust = fancy and int(p.dust) > 0
	if _wants_dust:
		_make_dust(p)


## An extra on one flight feather: a flame tongue (fire), smoke (shadow), a glint (thunder).
func _feather_extra(feather: Node3D, fx: String, side: float, length: float, k: int) -> void:
	if fx == "ice" and k % 2 == 0:
		# Ice crystals are part of the plumage, kept at every quality.
		_piece(feather, MeshKit.prism(), _ice(), Vector3(side * (length - 0.02), 0.01, 0.02), Vector3(0.035, 0.09, 0.02), Vector3(0, 0, -side * 70.0))
	if not fancy:
		return
	match fx:
		"fire":
			_add_fx(Fx.FLAME, _piece(feather, MeshKit.cone(), _flame(Color("ff7a2a")), Vector3(side * (length + 0.04), 0.004, 0), Vector3(0.05, 0.13, 0.03), Vector3(0, 0, -side * 90.0)), k * 1.7)
		"shadow":
			if k % 2 == 0:
				_add_fx(Fx.SMOKE, _piece(feather, MeshKit.sphere_low(), _smoke(), Vector3(side * (length - 0.02), 0.0, -0.02), Vector3(0.12, 0.08, 0.12)), k * 0.33)
		"thunder":
			if k == 1 or k == 3:
				_add_fx(Fx.GLINT, _bolt(feather, Vector3(side * length * 0.55, 0.014, 0), side, 0.22), k * 0.29 + (0.5 if side > 0.0 else 0.0))
		"star":
			if k == 0 or k == 3:
				_add_fx(Fx.TWINKLE, _piece(feather, MeshKit.sphere_low(), _flame(DarkRaven.palette(look).dust_b), Vector3(side * (length - 0.03), 0.012, 0), Vector3(0.03, 0.03, 0.03)), k * 1.3 + side)
		"divine":
			if k == 0:
				_add_fx(Fx.TWINKLE, _piece(feather, MeshKit.sphere_low(), _flame(Color("fff0b0")), Vector3(side * (length - 0.03), 0.012, 0), Vector3(0.032, 0.032, 0.032)), side * 2.0)


## Extras on the arm of a wing: ice crystals on the coverts, a bolt, plumes of smoke.
func _wing_extra(wing: Node3D, hand: Node3D, fx: String, side: float) -> void:
	match fx:
		"ice":
			for k in 3:
				_piece(wing, MeshKit.prism(), _ice(), Vector3(side * (0.1 + k * 0.1), 0.04, -0.03 + k * 0.01),
					Vector3(0.04, 0.1 - k * 0.015, 0.03), Vector3(-30, 0, -side * (15.0 + k * 12.0)))
			_piece(hand, MeshKit.prism(), _ice(), Vector3(side * 0.02, 0.03, 0.04), Vector3(0.045, 0.12, 0.03), Vector3(-20, 0, -side * 35.0))
		"thunder":
			if fancy:
				_add_fx(Fx.GLINT, _bolt(wing, Vector3(side * 0.24, 0.035, -0.04), side, 0.26), 0.62 + (0.4 if side > 0.0 else 0.0))
		"shadow":
			if fancy:
				_add_fx(Fx.SMOKE, _piece(wing, MeshKit.sphere_low(), _smoke(), Vector3(side * 0.3, 0.0, -0.2), Vector3(0.16, 0.1, 0.16)), 0.5 + side * 0.2)
		"holy", "crown":
			# A rim of the look's metal along the leading edge.
			_piece(wing, MeshKit.sphere_low(), _mat(DarkRaven.palette(look).accent, true, 0.25), Vector3(side * 0.2, 0.02, 0.085), Vector3(0.36, 0.022, 0.025))
		"divine":
			_piece(wing, MeshKit.sphere_low(), _mat(Color("fff0b0"), true, 0.4), Vector3(side * 0.2, 0.02, 0.085), Vector3(0.38, 0.024, 0.028))
			_piece(hand, MeshKit.sphere_low(), _mat(Color("e8b64a"), true, 0.2), Vector3(side * 0.03, 0.012, -0.02), Vector3(0.12, 0.02, 0.1))


## Extras on a tail feather.
func _tail_extra(feather: Node3D, fx: String, length: float, k: int) -> void:
	match fx:
		"fire":
			if fancy:
				_add_fx(Fx.FLAME, _piece(feather, MeshKit.cone(), _flame(Color("ff7a2a")), Vector3(0, 0.003, -length - 0.04), Vector3(0.05, 0.12, 0.03), Vector3(-90, 0, 0)), k * 2.1)
		"ice":
			if k % 2 == 1:
				_piece(feather, MeshKit.prism(), _ice(), Vector3(0, 0.02, -length * 0.55), Vector3(0.035, 0.08, 0.02), Vector3(-60, 0, 0))
		"shadow":
			if fancy and k % 2 == 0:
				_add_fx(Fx.SMOKE, _piece(feather, MeshKit.sphere_low(), _smoke(), Vector3(0, 0, -length), Vector3(0.12, 0.08, 0.12)), k * 0.21 + 0.1)
		"thunder":
			if fancy and k == 2:
				_add_fx(Fx.GLINT, _bolt(feather, Vector3(0, 0.012, -length * 0.6), 1.0, 0.16, true), 0.81)
		"holy", "star", "divine":
			# The middle pair grows long streamers.
			if (k == 1 or k == 3) and (fx != "star" or int(DarkRaven.palette(look).get("star", 0)) >= 2):
				var streamer := _mat(DarkRaven.palette(look).tip, true, 0.6)
				_piece(feather, MeshKit.sphere_low(), streamer, Vector3((float(k) - 2.0) * 0.02, -0.004, -length - 0.08), Vector3(0.05, 0.014, 0.3), Vector3(0, (float(k) - 2.0) * -6.0, 0))
				_piece(feather, MeshKit.sphere_low(), streamer, Vector3((float(k) - 2.0) * 0.045, -0.004, -length - 0.24), Vector3(0.1, 0.015, 0.11))


## Extras on the head: the crown (Lv.100), plumes (holy), a crest (ice, star ★150+),
## violet fire over the eyes and a floating ring (divine).
func _head_extra(fx: String, p: Dictionary) -> void:
	match fx:
		"crown":
			var gold := _mat(Color("f2c45a"), true, 0.35)
			_piece(_head, MeshKit.cylinder(), gold, Vector3(0, 0.13, -0.01), Vector3(0.12, 0.025, 0.12))
			for k in 5:
				var a := TAU * float(k) / 5.0
				_piece(_head, MeshKit.cone(), gold, Vector3(sin(a) * 0.055, 0.165, -0.01 + cos(a) * 0.055), Vector3(0.028, 0.06, 0.028))
				_piece(_head, MeshKit.sphere_low(), gold, Vector3(sin(a) * 0.055, 0.2, -0.01 + cos(a) * 0.055), Vector3(0.016, 0.016, 0.016))
			_piece(_head, MeshKit.sphere_low(), _mat(Color("b06bff"), false, 0.9), Vector3(0, 0.135, 0.052), Vector3(0.03, 0.03, 0.02))
			# Two crest feathers sweeping back from under the crown.
			for side in [-1.0, 1.0]:
				_piece(_head, MeshKit.sphere_low(), _mat(p.edge, true), Vector3(side * 0.03, 0.12, -0.1), Vector3(0.03, 0.02, 0.16), Vector3(-28, side * 12.0, 0))
		"holy":
			for k in 3:
				var off := float(k) - 1.0
				_piece(_head, MeshKit.sphere_low(), _mat(p.tip, true, 0.5), Vector3(off * 0.03, 0.13 - absf(off) * 0.015, -0.08), Vector3(0.025, 0.018, 0.2 - absf(off) * 0.04), Vector3(-38, off * 14.0, 0))
		"ice":
			for k in 3:
				var off := float(k) - 1.0
				_piece(_head, MeshKit.prism(), _ice(), Vector3(off * 0.04, 0.12 - absf(off) * 0.02, -0.05), Vector3(0.03, 0.09 - absf(off) * 0.025, 0.02), Vector3(-35, 0, off * -25.0))
		"star":
			var i := int(p.get("star", 0))
			if i >= 2:
				_piece(_head, MeshKit.sphere_low(), _mat(p.dust_a, false, 1.2), Vector3(0, 0.1, 0.07), Vector3(0.03, 0.03, 0.018))
			if i >= 3:
				for k in 3:
					var off := float(k) - 1.0
					_piece(_head, MeshKit.sphere_low(), _mat(p.tip, true, 1.0), Vector3(off * 0.03, 0.13 - absf(off) * 0.015, -0.08), Vector3(0.022, 0.016, 0.18 - absf(off) * 0.04), Vector3(-34, off * 16.0, 0))
		"divine":
			if fancy:
				for side in [-1.0, 1.0]:
					_add_fx(Fx.FLAME, _piece(_head, MeshKit.cone(), _flame(Color("c080ff")), Vector3(side * 0.09, 0.085, 0.065), Vector3(0.045, 0.12, 0.03), Vector3(-35, 0, side * -30.0)), side * 1.9)
			var halo := Node3D.new()
			halo.name = "Halo"
			halo.position = Vector3(0, 0.21, -0.02)
			_head.add_child(halo)
			_piece(halo, MeshKit.torus(), _mat(Color("f2c45a"), true, 1.1), Vector3.ZERO, Vector3(0.3, 0.16, 0.3))
			for k in 4:
				var a := TAU * float(k) / 4.0 + PI * 0.25
				_piece(halo, MeshKit.sphere_low(), _mat(Color("b06bff"), false, 1.3), Vector3(sin(a) * 0.132, 0, cos(a) * 0.132), Vector3(0.026, 0.026, 0.026))
			if fancy:
				_add_fx(Fx.RING, halo, 0.0)


## A zigzag lightning glint of three thin bars.
func _bolt(parent: Node3D, at: Vector3, side: float, size: float, along := false) -> Node3D:
	var bolt := Node3D.new()
	bolt.position = at
	if along:
		bolt.rotation_degrees = Vector3(0, 90, 0)
	parent.add_child(bolt)
	var mat := _flame(Color("e8fbff"))
	var zig := [Vector3(-0.32, 0, 0.1), Vector3(0, 0, -0.06), Vector3(0.32, 0, 0.08)]
	var ang := [side * 35.0, side * -40.0, side * 35.0]
	for k in 3:
		_piece(bolt, MeshKit.box(), mat, zig[k] * size, Vector3(size * 0.46, 0.012, 0.032), Vector3(0, ang[k], 0))
	return bolt


func _add_fx(kind: int, node: Node3D, phase: float) -> void:
	_fx.append(node)
	_fx_kind.append(kind)
	_fx_phase.append(phase)
	_fx_scale.append(node.scale)
	_fx_at.append(node.position)


## Bright unshaded fire / spark material.
func _flame(color: Color) -> StandardMaterial3D:
	return MeshKit.toon(color, {"unshaded": true, "emission": 2.2})


func _ice() -> StandardMaterial3D:
	return MeshKit.toon(Color("c8f0ff"), {"alpha": 0.82, "emission": 0.45} if fancy else {"alpha": 0.82})


func _smoke() -> StandardMaterial3D:
	return MeshKit.toon(Color(0.66, 0.4, 1.0), {"unshaded": true, "alpha": 0.42})


func _piece(parent: Node3D, mesh: Mesh, mat: Material, at: Vector3, size: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshKit.part(parent, mesh, mat, at, size, rot)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
