extends RefCounted
## Shared bits of the archer's and the mage's ★500 ultimates (starfall_emperor_arrow.gd,
## cosmos_genesis.gd): who may still cast, who may be struck, how a blow is dealt by the
## hero (Hero._deal) or by an AI player (Rival._hit), and the light they are drawn with
## (shaders/ascend_ult_light.gdshader on a few shared meshes). Scripts whose name starts
## with "_" are kits, never an ultimate of their own.

const SHADER := preload("res://shaders/ascend_ult_light.gdshader")
const BEAM := 0
const LENS := 1
const STRIP := 2
const PORTAL := 3
const GLOW := 4

static var _meshes := {}


# ---------------------------------------------------------------------------
# The caster and its foes
# ---------------------------------------------------------------------------

## The whole multiplier of the cast, spread over every blow one target can take: the hero's
## (skill mult x its rank's power; Hero._deal adds SKILL_POWER), an AI's (mult x SKILL_POWER
## x its rank's power, as Rival._resolve).
static func hero_total(hero: Hero, skill: Dictionary) -> float:
	return float(skill.get("mult", 0.0)) * hero.rank_mult(skill)


static func rival_total(rival: Rival, skill: Dictionary) -> float:
	return float(skill.get("mult", 0.0)) * HeroStats.SKILL_POWER * SkillRank.power(rival.skill_rank(skill))


## The caster still commands its cast: alive, on this field, out of the safe zone, its duel on.
## Untyped: a freed caster must reach the check, not fail the call.
static func caster_ok(who: Variant, field: Variant, zone: StringName) -> bool:
	if who == null or not is_instance_valid(who) or not (who is Node3D) or (who as Node).is_queued_for_deletion():
		return false
	var caster := who as Node3D
	if field == null or not is_instance_valid(field) or (field as Node).is_queued_for_deletion() or not caster.is_inside_tree():
		return false
	if caster.has_method("is_dead") and caster.is_dead():
		return false
	if Game.current_zone != zone:
		return false
	if caster is Hero:
		var hero := caster as Hero
		return hero.field == field and not hero.safe_zone
	if caster is Rival:
		return not (caster as Rival).duel_over and caster.get_parent() == field
	return true


static func valid(caster: Node3D, by_hero: bool, node: Variant) -> bool:
	if node == null or not is_instance_valid(node) or (node as Node).is_queued_for_deletion():
		return false
	if not by_hero and caster is Rival and is_instance_valid(caster):
		return (caster as Rival)._alive(node)
	if node is Mob and (node as Mob).is_dead():
		return false
	return not (node.has_method("is_dead") and node.is_dead())


## Everyone the caster may strike: the hero's live mobs (an unopened castle gate never), an
## AI's own targets (Rival._targets: the hero, its summons, the other side's fighters).
static func foes(caster: Node3D, by_hero: bool) -> Array:
	var out: Array = []
	if not is_instance_valid(caster) or not caster.is_inside_tree():
		return out
	if by_hero:
		var hero := caster as Hero
		for node in caster.get_tree().get_nodes_in_group("mobs"):
			var mob := node as Mob
			if mob == null or not is_instance_valid(mob) or mob.is_dead() or mob.is_queued_for_deletion():
				continue
			if mob is CastleGate and not (mob as CastleGate).open_to(hero):
				continue
			out.append(mob)
	else:
		var rival := caster as Rival
		for node: Node3D in rival._targets():
			if rival._alive(node):
				out.append(node)
	return out


static func body(node: Node3D) -> float:
	return (node as Mob).body_radius() if node is Mob else 0.4


static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


static func hit_point(node: Node3D) -> Vector3:
	return (node as Mob).hit_point() if node is Mob else node.global_position + Vector3.UP * 1.1


## The blow's skill for Hero._deal: the ultimate's id (its rank, its "รวม N ฮิต" count) and
## class, but a light single hit ("star" 0: no per-hit tableau, no ★500 launch on each tick)
## carrying only [param fx].
static func strike(skill: Dictionary, fx: Dictionary) -> Dictionary:
	return {"id": String(skill.get("id", "")), "name": String(skill.get("name", "")), "class": skill.get("class", &""),
		"star": 0, "shape": "single", "level": 40, "mult": 1.0, "color": skill.get("color", Color.WHITE), "vfx": &"light", "fx": fx}


## One blow of [param mult] (a share of the whole) on [param foe]. The hero's goes through
## Hero._deal (kill credit, drops, the coliseum's and online duels' PvpProxy, burn / slow /
## stun / marks); an AI's through Rival._hit (war scale, BurstGuard, marks), the slow and
## the stun on what can take them.
static func deal(caster: Node3D, by_hero: bool, foe: Node3D, mult: float, color: Color, blow: Dictionary) -> void:
	var fx: Dictionary = blow.get("fx", {})
	if by_hero:
		(caster as Hero)._deal(foe as Mob, mult, color, &"light", false, blow)
		return
	var rival := caster as Rival
	var marks := {}
	for key in Mob.MARKS:
		if fx.get(key) is Array:
			marks[key] = fx[key]
	rival._hit(foe, mult, color, marks)
	if not rival._alive(foe):
		return
	if fx.has("slow") and foe.has_method("apply_slow"):
		foe.call("apply_slow", float(fx.slow))
	if fx.has("stun") and foe.has_method("apply_stun"):
		foe.call("apply_stun", float(fx.stun))


static func with_room(by_hero: bool, fn: Callable) -> void:
	if by_hero:
		VfxBudget.hero_begin()
	fn.call()
	if by_hero:
		VfxBudget.hero_end()


static func sound(by_hero: bool, at: Vector3, id: StringName, db: float) -> void:
	if id == &"" or not AudioManager.has_sound(id):
		return
	if by_hero:
		AudioManager.play_sfx(id, db)
	else:
		AudioManager.play_sfx_at(at, id, db - 4.0)


# ---------------------------------------------------------------------------
# Light
# ---------------------------------------------------------------------------

static func material(mode: int, c: Color, core: Color, shade: Color, extra := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("core", core)
	m.set_shader_parameter("shade", shade)
	m.set_shader_parameter("seed", randf() * 40.0)
	for key in extra:
		m.set_shader_parameter(key, extra[key])
	return m


## The shared meshes: "beam" an open cylinder (radius 0.5, height 1 on Y), "lens" a sphere
## of radius 0.5 (flattened by its node), "quad" 1x1 facing +Z, "plane" 1x1 on the ground.
static func mesh(kind: String) -> Mesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var m: Mesh
	match kind:
		"beam":
			var c := CylinderMesh.new()
			c.top_radius = 0.5
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = 14
			c.rings = 1
			c.cap_top = false
			c.cap_bottom = false
			m = c
		"lens":
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			s.radial_segments = 28
			s.rings = 12
			m = s
		"quad":
			var q := QuadMesh.new()
			q.size = Vector2.ONE
			m = q
		"plane":
			var p := PlaneMesh.new()
			p.size = Vector2.ONE
			m = p
		"ring":
			var t := TorusMesh.new()
			t.inner_radius = 0.44
			t.outer_radius = 0.5
			t.rings = 32
			t.ring_segments = 6
			m = t
	_meshes[kind] = m
	return m


## A light node under [param parent] (a VfxBudget decoration), or null when there is no room.
static func light(parent: Node, kind: String, mat: Material, label: String) -> MeshInstance3D:
	if not is_instance_valid(parent) or not VfxBudget.can_decorate():
		return null
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh(kind)
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	VfxBudget.track_decoration(node)
	return node


## Lays a "beam" (its Y axis) from [param from] to [param to], [param radius] thick.
static func span(node: Node3D, from: Vector3, to: Vector3, radius: float) -> void:
	var axis := to - from
	var length := axis.length()
	if length < 0.01:
		node.visible = false
		return
	node.visible = true
	var y := axis / length
	var side := y.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = y.cross(Vector3.RIGHT)
	var x := side.normalized()
	var z := x.cross(y).normalized()
	node.global_transform = Transform3D(Basis(x * radius * 2.0, y * length, z * radius * 2.0), (from + to) * 0.5)


## Lays a "plane" flat on the ground from [param from] to [param to], [param width] wide.
static func strip(node: Node3D, from: Vector3, to: Vector3, width: float, lift := 0.06) -> void:
	var axis := flat(to - from)
	var length := axis.length()
	if length < 0.01:
		node.visible = false
		return
	node.visible = true
	var z := axis / length
	var x := Vector3.UP.cross(z).normalized()
	var mid := flat(from + to) * 0.5 + Vector3.UP * lift
	node.global_transform = Transform3D(Basis(x * width, Vector3.UP, z * length), mid)


static func set_fade(node: GeometryInstance3D, value: float) -> void:
	if not is_instance_valid(node):
		return
	if node.material_override is ShaderMaterial:
		(node.material_override as ShaderMaterial).set_shader_parameter("fade", clampf(value, 0.0, 1.0))
	elif node.material_override is StandardMaterial3D:
		(node.material_override as StandardMaterial3D).albedo_color.a = clampf(value, 0.0, 1.0) * 0.95


## A solid (not additive) unshaded body that reads on any ground: the lens's gold frame.
static func solid(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(c.r, c.g, c.b, 0.95)
	m.disable_fog = true
	return m
