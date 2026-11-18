class_name BossCast
extends Node3D
## A boss's special move made readable: the wind-up that fills the move's telegraph, then
## the release when the first blow lands. The rigs carry no cast clips, so it is all
## procedural (MonsterVisual.cast_windup / cast_release, overridden by the eastern dragons
## and the kirin on their shaders):
##   gather (the first ~72% of the telegraph)  the body rears back, rises or crouches, the
##       move's clip creeping into its anticipation frame; a rune opens on the ground, the
##       body kindles in the move's colour (BossAttack.STYLE_COLORS) and motes gather in the
##       move's own way: fire is inhaled into the mouth, lightning crackles upward, crystal
##       spikes rise round the boss, lotus petals spiral up, the void draws in...
##   hold (the rest)  a short held breath at the top of the wind-up, quivering, glow peaking;
##   release  the clip fast-plays its strike, the body snaps forward and squashes back,
##       a flash and a shockwave at the boss, the camera shakes (GameSettings.screen_shake).
## The move's Thai name (BossAttack.title, or the boss's own titles) rides over the boss as
## a banner for the whole wind-up. Nothing here touches the move's timings or damage: the
## cast is a child of the move's own node (BossAttack, StarAttack, DivineAttack) where
## there is one, so a stun, a death or a leash reset that ends the move ends the cast too
## (the body snaps back to rest); tick-driven bosses (world, story, raid, tomb) release it
## from their own _fire. Mirrors (MirrorMob) replay it from the cast event (EntitySync
## "bc" + "w"). Phones: no lights, no GPU particles, one MultiMesh of motes on shared
## meshes and materials, counts by VfxBudget (quality and MemoryGuard), the extras dropped
## when the decoration budget is full.

const HOLD_SHARE := 0.28
const MIN_WINDUP := 0.35
const RELEASE := 0.42
## Seconds the cast stays after its release (the aura burns away).
const LINGER := 0.55
const META := "boss_cast"

## pose: "rear" (draws back), "crouch" (gathers low, then slams), "raise" (rises tall);
## motes: "inhale" (into the mouth), "converge" (into the chest), "rise" (up from the
## ground), "spikes" (crystals rising round the boss), "spiral" (up round the body),
## "swirl" (a closing whirl), "orbit" (shards circling), "crackle" (sparks shooting up and
## lightning off the body). Keys are BossAttack moves, the star kings' and the lotus
## queen's first specials, and the scripted bosses' moves ("<boss>_<kind>").
const LOOKS := {
	"spore_bloom": ["raise", "rise"], "cap_stomp": ["crouch", "rise"],
	"flame_breath": ["rear", "inhale"], "flame_fan": ["rear", "inhale"],
	"quicksand": ["raise", "swirl"], "sand_cross": ["crouch", "swirl"],
	"freeze_ring": ["crouch", "spikes"], "avalanche": ["rear", "spikes"],
	"lava_lines": ["rear", "inhale"], "magma_geysers": ["crouch", "rise"],
	"bone_spikes": ["crouch", "spikes"], "bone_rain": ["raise", "orbit"],
	"tongue_lash": ["rear", "inhale"], "poison_pools": ["rear", "rise"],
	"chain_lightning": ["raise", "crackle"], "thunder_cage": ["raise", "crackle"],
	"solar_wedge": ["raise", "rise"], "sun_pillars": ["raise", "rise"],
	"inferno_spiral": ["rear", "inhale"], "inferno_twin": ["rear", "inhale"],
	"rift_trail": ["rear", "converge"], "event_horizon": ["raise", "converge"],
	"maelstrom": ["raise", "swirl"], "glacial_bloom": ["raise", "spikes"],
	"dragon_breath": ["rear", "inhale"], "heavens_fall": ["raise", "crackle"],
	"stone_thorns": ["crouch", "spikes"], "frost_crown": ["raise", "spikes"],
	"radiant_wings": ["raise", "rise"], "eclipse_cleave": ["rear", "converge"],
	"lotus_rain": ["raise", "spiral"],
	"slam": ["crouch", "converge"],
	"root_ring": ["crouch", "spiral"], "crystal_fault": ["crouch", "spikes"],
	"sun_lances": ["raise", "rise"], "eclipse_crown": ["raise", "converge"],
	"lotus_judgment": ["raise", "spiral"], "star_special": ["raise", "converge"],
	"raid_buster": ["rear", "converge"], "raid_rain": ["raise", "rise"], "raid_nova": ["crouch", "converge"],
	"tomb_cone": ["rear", "inhale"], "tomb_spread": ["raise", "orbit"],
	"world_stomp": ["crouch", "swirl"], "world_beam": ["rear", "converge"], "world_summon": ["raise", "spiral"],
	"story_nova": ["crouch", "converge"], "story_lance": ["rear", "converge"],
	"story_rain": ["raise", "rise"], "story_veil": ["raise", "spiral"],
}
## The casts that are not BossAttack moves: their style (colour) and Thai name (the
## scripted bosses pass their own titles).
const EXTRA := {
	"slam": {"style": "", "th": ""},
	"root_ring": {"style": "verdant", "th": "วงรากราชันพฤกษา"},
	"crystal_fault": {"style": "ice", "th": "รอยแยกผลึกคราม"},
	"sun_lances": {"style": "light", "th": "หอกสุริยันพิพากษา"},
	"eclipse_crown": {"style": "eclipse", "th": "มงกุฎสุริยคราส"},
	"lotus_judgment": {"style": "lotus", "th": "บัวดาราพิพากษา"},
	"star_special": {"style": "light", "th": ""},
	"raid_buster": {"style": "blood"}, "raid_rain": {"style": "blood"}, "raid_nova": {"style": "blood"},
	"tomb_cone": {"style": "claw"}, "tomb_spread": {"style": "eyes"},
	"world_stomp": {"style": ""}, "world_beam": {"style": ""}, "world_summon": {"style": "light"},
	"story_nova": {"style": "shadow"}, "story_lance": {"style": "shadow"},
	"story_rain": {"style": "shadow"}, "story_veil": {"style": "shadow"},
}
const EXTRA_COLORS := {"blood": Color("ff3a4a"), "claw": Color("ff5a3a"), "eyes": Color("ff8a2a"), "shadow": Color("9a5cff")}
## Motes shaped by the move: crystals for ice, petals and leaves, bone and sand shards.
const SPIKE_STYLES := ["ice", "glacier", "bone", "verdant"]
const PETAL_STYLES := ["lotus", "verdant", "spore"]
const SHARD_STYLES := ["sand", "bone", "eclipse"]

static var _meshes := {}
static var _mats := {}

var mob: Mob
var key := ""
var style := ""
var color := Color.WHITE
var title := ""
var clip := "attack"
var pose := "rear"
var motes := "converge"
var windup := 1.0
var age := 0.0
var released := false
var released_at := -1.0
## Seconds into the cast when the gather ends and the hold begins.
var hold_at := 0.7
var lite := false
var _radius := 3.0
var _height := 3.0
var _seeds: Array[Vector3] = []
var _multi: MultiMeshInstance3D
var _rune: Array[MeshInstance3D] = []
var _rising: MeshInstance3D
var _orb: MeshInstance3D
var _banner: Label3D
var _crackle := 0.0
var _shake_seed := 0.0
var _banner_done := false


## Starts [param p_key]'s cast on [param p_mob], the first blow [param p_windup] seconds
## away. [param host] owns it (the move's node, so the cast ends with the move); opts:
## "title", "clip", "color". A cast already running on the boss gives way.
static func begin(p_mob: Mob, host: Node, p_key: String, p_windup: float, opts := {}) -> BossCast:
	if p_mob == null or not is_instance_valid(p_mob) or p_mob.is_dead() or not p_mob.is_inside_tree():
		return null
	if p_mob.visual == null or not p_mob.visual.has_method("cast_windup"):
		return null
	var old := of(p_mob)
	if old != null:
		old.cancel()
	var cast := BossCast.new()
	cast.mob = p_mob
	cast.key = p_key
	cast.windup = maxf(p_windup, MIN_WINDUP)
	var spec := look(p_key)
	cast.style = String(spec.style)
	cast.pose = String(spec.pose)
	cast.motes = String(spec.motes)
	cast.clip = String(opts.get("clip", spec.clip))
	cast.title = String(opts.get("title", spec.title))
	cast.color = opts.get("color", spec.color) if opts.has("color") or cast.style != "" else p_mob.template.get("color", Color("ff6a4a"))
	cast.name = "BossCast"
	p_mob.set_meta(META, weakref(cast))
	(host if host != null and is_instance_valid(host) else p_mob).add_child(cast)
	return cast


## The cast running on [param p_mob] now, or null.
static func of(p_mob: Node) -> BossCast:
	if p_mob == null or not is_instance_valid(p_mob) or not p_mob.has_meta(META):
		return null
	var ref: Variant = p_mob.get_meta(META)
	var cast := (ref as WeakRef).get_ref() as BossCast if ref is WeakRef else null
	return cast if cast != null and is_instance_valid(cast) and not cast.is_queued_for_deletion() else null


## The blow lands now (tick-driven bosses call it from their _fire).
static func release_on(p_mob: Node) -> void:
	var cast := of(p_mob)
	if cast != null and not cast.released:
		cast.release()


static func cancel_on(p_mob: Node) -> void:
	var cast := of(p_mob)
	if cast != null:
		cast.cancel()


## {style, color, title, pose, motes, clip} of a cast key.
static func look(p_key: String) -> Dictionary:
	var out := {"style": "", "color": Color("ff6a4a"), "title": "", "pose": "rear", "motes": "converge", "clip": "attack"}
	if BossAttack.MOVES.has(p_key):
		var move: Dictionary = BossAttack.MOVES[p_key]
		out.style = String(move.style)
		out.title = String(move.th)
		out.clip = String(move.get("clip", "attack"))
	elif EXTRA.has(p_key):
		out.style = String(EXTRA[p_key].get("style", ""))
		out.title = String(EXTRA[p_key].get("th", ""))
	if BossAttack.STYLE_COLORS.has(out.style):
		out.color = BossAttack.STYLE_COLORS[out.style]
	elif EXTRA_COLORS.has(out.style):
		out.color = EXTRA_COLORS[out.style]
	var l: Array = LOOKS.get(p_key, ["rear", "converge"])
	out.pose = String(l[0])
	out.motes = String(l[1])
	return out


func _ready() -> void:
	top_level = true
	hold_at = windup * (1.0 - HOLD_SHARE)
	_height = maxf(mob.visual.height, 1.0)
	_radius = clampf(mob.body_radius() * 3.2 + _height * 0.25, 2.2, 6.5)
	_shake_seed = randf() * 100.0
	global_position = _feet()
	lite = not VfxBudget.can_decorate(4)
	if not lite:
		VfxBudget.track_decoration(self)
	mob.visual.cast_windup(hold_at, windup - hold_at, clip, pose)
	_build_rune()
	if not lite:
		_build_motes()
	# The banner comes on the first frame (a label made and freed in one frame trips the renderer).
	var cam := _camera()
	if cam != null:
		cam.feel_windup(2.0, windup)


func _feet() -> Vector3:
	return mob.global_position if is_instance_valid(mob) else global_position


func _camera() -> ThirdPersonCamera:
	if mob == null or not is_instance_valid(mob.hero) or not mob.hero.is_inside_tree():
		return null
	if mob.hero.global_position.distance_to(mob.global_position) > 26.0:
		return null
	return SkillFeel._camera(mob.hero)


func _process(delta: float) -> void:
	if not is_instance_valid(mob) or mob.is_dead() or not mob.is_inside_tree():
		cancel()
		return
	if _banner == null and not released and title != "" and age > 0.1 and not _banner_done:
		_banner_done = true
		_build_banner()
	age += delta
	global_position = _feet()
	if not released and age >= windup:
		release()
	if released:
		_fade(delta)
		if age >= released_at + LINGER:
			queue_free()
		return
	var charge := clampf(age / maxf(hold_at, 0.05), 0.0, 1.0)
	var held := age >= hold_at
	var pulse := 0.5 + 0.5 * sin(age * (22.0 if held else 9.0))
	mob.visual.cast_glow(color, lerpf(0.1, 0.75, charge) + (0.25 * pulse if held else 0.0))
	# The held breath quivers (the node's x/z only; its y, tilt and scale are the pose's).
	if held:
		var q := 0.035 * minf(_height, 6.0) * 0.25
		mob.visual.position.x = sin(age * 61.0 + _shake_seed) * q
		mob.visual.position.z = cos(age * 53.0 + _shake_seed) * q
	_tick_rune(charge, held)
	if _multi != null:
		_tick_motes(charge, held)
	if motes == "crackle" and not lite and held:
		_crackle -= delta
		if _crackle <= 0.0:
			_crackle = 0.18
			var top := mob.top_point()
			var a := randf() * TAU
			VfxKit.lightning(mob.get_parent(), top, top + Vector3(cos(a) * 1.4, 2.2 + randf() * 1.6, sin(a) * 1.4), color)
	if _banner != null:
		_banner.global_position = mob.top_point() + Vector3(0, 0.85, 0)
		_banner.scale = Vector3.ONE * (1.0 + (0.06 * pulse if held else 0.0))


## The blow: the body lets go, a flash where it gathered, a shockwave at its feet.
func release() -> void:
	if released or not is_instance_valid(mob):
		return
	released = true
	released_at = age
	mob.visual.position.x = 0.0
	mob.visual.position.z = 0.0
	mob.visual.cast_release(RELEASE)
	var parent := mob.get_parent() as Node3D
	if parent != null:
		var at := _gather_point()
		VfxKit.flash(parent, at, color, clampf(_height * 0.6, 1.8, 4.0), 0.3)
		VfxKit.shockwave(parent, _feet() * Vector3(1, 0, 1) + Vector3(0, mob.global_position.y + 0.08, 0), color, _radius * 1.1)
		if motes == "crackle":
			VfxKit.lightning(parent, mob.top_point() + Vector3(0.3, 9.0, 0.2), mob.top_point(), color)
	mob.visual.flash(color.lerp(Color.WHITE, 0.5), 0.25)
	var cam := _camera()
	if cam != null:
		var dir := (mob.hero.global_position - mob.global_position) * Vector3(1, 0, 1)
		cam.feel_shake(dir, 0.09 if VfxBudget.quality() > 0 else 0.06, 0.32, 0.05)
		if VfxBudget.quality() >= 1:
			cam.feel_punch(2.5)
	if _banner != null:
		var b := _banner
		_banner = null
		# The name lingers a moment over the blow on its own (the move's node may go first).
		b.reparent(parent if parent != null else self)
		var t := b.create_tween()
		t.tween_property(b, "scale", Vector3.ONE * 1.3, 0.12).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(b, "modulate:a", 0.0, 0.45).set_delay(0.1)
		t.tween_callback(b.queue_free)


## Ends at once (the move was cut short): the body back at rest, nothing left behind.
func cancel() -> void:
	if not released and is_instance_valid(mob) and mob.visual != null:
		mob.visual.cast_cancel()
	released = true
	if _banner != null:
		_banner.queue_free()
		_banner = null
	if not is_queued_for_deletion():
		queue_free()


func _exit_tree() -> void:
	if not released and is_instance_valid(mob) and mob.visual != null:
		released = true
		mob.visual.cast_cancel()
	if is_instance_valid(_banner):
		_banner.queue_free()
	if is_instance_valid(mob) and mob.has_meta(META):
		var ref: Variant = mob.get_meta(META)
		if ref is WeakRef and (ref as WeakRef).get_ref() == self:
			mob.remove_meta(META)


## Where the motes gather, in world space.
func _gather_point() -> Vector3:
	var part := "mouth" if motes == "inhale" else "chest"
	return mob.visual.global_transform * mob.visual.cast_point(part)


# ---------------------------------------------------------------------------
# The aura: a rune on the ground (two counter-turning rings, a ring climbing the body,
# a kindling orb where the charge gathers) and the motes.
# ---------------------------------------------------------------------------

func _build_rune() -> void:
	var ring := VfxKit.torus_mesh(0.93, 1.0, 40, 4)
	var outer := _part(ring, _mat(color, 0.85, false))
	outer.position.y = 0.07
	_rune.append(outer)
	var inner := _part(ring, _mat(color.lightened(0.25), 0.85, false))
	inner.position.y = 0.08
	_rune.append(inner)
	if lite:
		return
	var fill := _part(VfxKit._disc_mesh(), _mat(color, 0.18))
	fill.position.y = 0.05
	_rune.append(fill)
	_rising = _part(VfxKit.torus_mesh(0.9, 1.0, 32, 4), _mat(color.lightened(0.15), 0.8, false))
	if motes in ["inhale", "converge"]:
		_orb = _part(_mesh("orb"), _mat(color.lightened(0.3), 0.92, false))
		_orb.scale = Vector3.ONE * 0.01
	for r in _rune:
		r.scale = Vector3(0.01, 1.0, 0.01)


func _part(mesh: Mesh, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _tick_rune(charge: float, held: bool) -> void:
	var grow := ease(charge, 0.4)
	var spin := age * (1.2 + 2.5 * charge)
	for i in _rune.size():
		var r := _rune[i]
		var s := _radius * grow * (1.0 if i != 1 else 0.68)
		r.scale = Vector3(s, 1.0 if i != 2 else 1.0, s)
		r.rotation.y = spin * (1.0 if i % 2 == 0 else -1.4)
	if _rising != null:
		var u := fmod(age * (1.1 if not held else 2.4), 1.0)
		var w := lerpf(_radius * 0.55, mob.body_radius() * 1.3, u)
		_rising.position.y = lerpf(0.1, _height * 0.95, u)
		_rising.scale = Vector3(w, 1.0, w) * (1.0 - 0.6 * u * u)
	if _orb != null:
		var size := clampf(_height * 0.11, 0.22, 0.75) * ease(charge, 0.6) * (1.0 + (0.12 * sin(age * 30.0) if held else 0.0))
		_orb.global_position = _gather_point()
		_orb.scale = Vector3.ONE * maxf(size, 0.01)


func _fade(delta: float) -> void:
	var k := clampf((age - released_at) / LINGER, 0.0, 1.0)
	for r in _rune:
		r.scale = Vector3(r.scale.x + delta * _radius * 2.5, 1.0, r.scale.z + delta * _radius * 2.5) * (1.0 - k * 0.15)
		r.visible = k < 0.7
	if _rising != null:
		_rising.visible = false
	if _orb != null:
		_orb.scale = _orb.scale * maxf(0.0, 1.0 - delta * 9.0)
	if _multi != null:
		_multi.visible = false
	if k > 0.05 and is_instance_valid(mob):
		mob.visual.cast_glow(color, 0.0)


func _build_motes() -> void:
	var n := VfxBudget.count(16, 5)
	if motes == "spikes":
		n = VfxBudget.count(10, 5)
	var shape := "orb"
	if motes == "spikes" or (motes == "rise" and style in SPIKE_STYLES):
		shape = "spike"
	elif style in PETAL_STYLES:
		shape = "petal"
	elif style in SHARD_STYLES or motes == "orbit":
		shape = "shard"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _mesh(shape)
	mm.instance_count = n
	_multi = MultiMeshInstance3D.new()
	_multi.multimesh = mm
	_multi.material_override = _mat(color.lightened(0.1), 0.95, false)
	_multi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_multi.top_level = true
	# Big bounds so the motes are never culled as they swing round the boss.
	_multi.custom_aabb = AABB(Vector3(-12, -2, -12), Vector3(24, 18, 24))
	add_child(_multi)
	for i in n:
		_seeds.append(Vector3(TAU * float(i) / float(n) + randf_range(-0.3, 0.3), randf(), randf_range(0.7, 1.3)))
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.001), Vector3.ZERO))


func _tick_motes(charge: float, held: bool) -> void:
	var mm := _multi.multimesh
	var feet := _feet()
	_multi.global_position = feet
	var gather := _gather_point() - feet
	var body := mob.body_radius()
	var speed := (0.9 + 1.6 * charge) * (1.6 if held else 1.0)
	var base_size := clampf(_height * 0.05, 0.1, 0.32)
	for i in mm.instance_count:
		var sd := _seeds[i]
		var u := fmod(sd.y + age * speed * 0.6 * sd.z, 1.0)
		var a := sd.x
		var pos := Vector3.ZERO
		var size := base_size * sd.z
		var b := Basis()
		match motes:
			"inhale", "converge":
				# Drawn in from a wide shell, quicker as they near the mouth / heart.
				var from := Vector3(cos(a) * _radius * 1.1, _height * (0.2 + 0.9 * sd.z * 0.6), sin(a) * _radius * 1.1)
				var k := u * u
				pos = from.lerp(gather, k)
				size *= 1.0 - 0.7 * k
				b = Basis().scaled(Vector3(1.0, 1.0, 1.0 + 2.5 * k))
				b = Basis.looking_at((gather - pos).normalized() if (gather - pos).length() > 0.05 else Vector3.FORWARD) * b
			"rise", "crackle":
				var r := lerpf(_radius * 0.95, body * 1.1, u * 0.6)
				pos = Vector3(cos(a + u * 0.8) * r, u * _height * (1.3 if motes == "crackle" else 1.05), sin(a + u * 0.8) * r)
				size *= 1.0 - 0.6 * u
				if motes == "crackle":
					b = Basis().scaled(Vector3(0.5, 3.0, 0.5))
			"spikes":
				# Crystals breaking out of the rune, growing taller and closing in.
				var r := lerpf(_radius * 0.95, body * 1.5, charge * 0.6)
				pos = Vector3(cos(a + age * 0.3) * r, 0.0, sin(a + age * 0.3) * r)
				var tall := (0.4 + 1.6 * ease(charge, 0.5)) * sd.z * clampf(_height * 0.35, 0.6, 2.0)
				b = Basis(Vector3(-sin(a), 0, cos(a)), (0.25 - 0.2 * charge) * (1.0 if i % 2 == 0 else -1.0)).scaled(Vector3(size * 2.0, tall, size * 2.0))
				size = 1.0
			"spiral":
				var turn := a + u * TAU * 1.4
				var r := lerpf(_radius, body * 1.15, u)
				pos = Vector3(cos(turn) * r, lerpf(0.2, _height * 1.05, u), sin(turn) * r)
				b = Basis(Vector3.UP, -turn) * Basis(Vector3.RIGHT, 0.6 + u)
				size *= 1.3
			"swirl":
				var turn := a + age * (2.0 + 5.0 * charge)
				var r := lerpf(_radius * 1.05, body * 1.2, fmod(sd.y + charge * 0.7, 1.0))
				pos = Vector3(cos(turn) * r, _height * (0.15 + 0.5 * sd.y), sin(turn) * r)
				b = Basis(Vector3.UP, -turn)
			_:
				var turn := a + age * (1.5 + 4.0 * charge)
				var r := body * 1.7 + 0.4 * sin(age * 3.0 + a)
				pos = Vector3(cos(turn) * r, _height * (0.45 + 0.25 * sin(a * 3.0 + age * 2.0)), sin(turn) * r)
				b = Basis(Vector3.UP, -turn) * Basis(Vector3.FORWARD, a)
		var appear := clampf(age * 4.0 - sd.y, 0.0, 1.0)
		mm.set_instance_transform(i, Transform3D(b.scaled(Vector3.ONE * maxf(size * appear, 0.001)), pos))


# ---------------------------------------------------------------------------
# The banner: the move's Thai name over the boss for the whole wind-up.
# ---------------------------------------------------------------------------

func _build_banner() -> void:
	if title == "":
		return
	var label := Label3D.new()
	label.text = L10n.t(title)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font = load("res://ui/theme/fonts/heading_font.tres")
	label.font_size = BattleVfx.FLOATING_FONT_SIZE
	label.outline_size = int(22 * BattleVfx.FLOATING_FONT_SIZE / 96.0)
	label.pixel_size = 0.0042 * BattleVfx.text_scale * 1.45 * 96.0 / BattleVfx.FLOATING_FONT_SIZE
	label.modulate = color.lerp(Color.WHITE, 0.35)
	label.outline_modulate = Color(0.05, 0.03, 0.1)
	label.render_priority = 3
	label.top_level = true
	add_child(label)
	label.global_position = mob.top_point() + Vector3(0, 0.85, 0)
	label.scale = Vector3.ONE * 0.3
	var t := label.create_tween()
	t.tween_property(label, "scale", Vector3.ONE * 1.12, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(label, "scale", Vector3.ONE, 0.1)
	_banner = label


# ---------------------------------------------------------------------------
# Shared meshes and materials (made once, kept for the session).
# ---------------------------------------------------------------------------

static func _mesh(shape: String) -> Mesh:
	if _meshes.has(shape):
		return _meshes[shape]
	var m: Mesh
	match shape:
		"spike":
			# A five-sided crystal standing on its base (y 0..1).
			var verts := PackedVector3Array()
			var sides := 5
			for i in sides:
				var a0 := TAU * float(i) / float(sides)
				var a1 := TAU * float(i + 1) / float(sides)
				var p0 := Vector3(cos(a0) * 0.5, 0.0, sin(a0) * 0.5)
				var p1 := Vector3(cos(a1) * 0.5, 0.0, sin(a1) * 0.5)
				verts.append_array([p0, Vector3(0, 1, 0), p1, p1, Vector3.ZERO, p0])
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = verts
			var am := ArrayMesh.new()
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			m = am
		"petal":
			var petal := SphereMesh.new()
			petal.radius = 0.5
			petal.height = 0.35
			petal.radial_segments = 8
			petal.rings = 3
			m = petal
		"shard":
			var prism := PrismMesh.new()
			prism.size = Vector3(0.6, 1.0, 0.35)
			m = prism
		_:
			var orb := SphereMesh.new()
			orb.radius = 0.5
			orb.height = 1.0
			orb.radial_segments = 8
			orb.rings = 4
			m = orb
	_meshes[shape] = m
	return m


static func _mat(c: Color, alpha: float, additive := true) -> StandardMaterial3D:
	var k := "%s|%.2f|%s" % [c.to_html(false), alpha, additive]
	if _mats.has(k):
		return _mats[k]
	if _mats.size() > 64:
		_mats.clear()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.disable_fog = true
	MaterialKeeper.keep(m)
	_mats[k] = m
	return m
