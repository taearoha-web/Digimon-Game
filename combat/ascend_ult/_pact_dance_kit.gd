extends RefCounted
## Shared bits of the Dark Lord's and the Bard's ★500 ultimates (heaven_hell_sovereign.gd:
## สัญญาโลหิต, universe_hymn.gd: ระบำสะกดใจ): who may still cast, who may be struck, how a
## blow is dealt by the hero (Hero._deal) or by an AI player (Rival._hit), and the light
## they are drawn with (shaders/ascend_pact_dance*.gdshader on a few plain meshes). Scripts
## whose name starts with "_" are kits, never an ultimate of their own.

const MIX := preload("res://shaders/ascend_pact_dance.gdshader")
const ADD := preload("res://shaders/ascend_pact_dance_add.gdshader")
## Shader modes (shaders/ascend_pact_dance.gdshaderinc).
const TIDE := 0
const FLOOR := 1
const BEAM := 2
const MOON := 3
const SEAL := 4
const BALL := 5

static var _meshes := {}


# ---------------------------------------------------------------------------
# The caster and its foes
# ---------------------------------------------------------------------------

## The whole multiplier of the cast on one target: the hero's (skill mult x its rank's
## power; Hero._deal adds SKILL_POWER), an AI's (mult x SKILL_POWER x its rank's power, as
## Rival._resolve).
static func total(caster: Node3D, by_hero: bool, skill: Dictionary) -> float:
	if by_hero:
		return float(skill.get("mult", 0.0)) * (caster as Hero).rank_mult(skill)
	return float(skill.get("mult", 0.0)) * HeroStats.SKILL_POWER * SkillRank.power((caster as Rival).skill_rank(skill))


## The caster still commands its cast: alive, on this field, out of the safe zone, its duel on.
static func caster_ok(caster: Variant, field: Variant, zone: StringName) -> bool:
	if caster == null or not is_instance_valid(caster) or (caster as Node).is_queued_for_deletion():
		return false
	if not is_instance_valid(field) or field.is_queued_for_deletion() or not caster.is_inside_tree():
		return false
	if caster.has_method("is_dead") and caster.is_dead():
		return false
	if Game.current_zone != zone:
		return false
	if caster is Hero:
		return (caster as Hero).field == field and not (caster as Hero).safe_zone
	if caster is Rival:
		return not (caster as Rival).duel_over and caster.get_parent() == field
	return true


## Whether [param node] may still be struck by the caster's side.
static func valid(caster: Variant, by_hero: bool, node: Variant) -> bool:
	if node == null or not is_instance_valid(node) or (node as Node).is_queued_for_deletion():
		return false
	if not is_instance_valid(caster):
		return false
	if not by_hero:
		return (caster as Rival)._alive(node)
	if not (node is Mob) or (node as Mob).is_dead():
		return false
	if node is CastleGate and not (node as CastleGate).open_to(caster as Hero):
		return false
	return true


## Every foe of the caster within [param radius] (flat metres, plus its body) of [param at],
## nearest first: the hero's the "mobs" group (no dead, no closed gate), an AI's its own
## targets (Rival._targets: its war's other side, the hero, their summons).
static func foes(caster: Node3D, by_hero: bool, at: Vector3, radius: float) -> Array:
	var out: Array = []
	var pool: Array = caster.get_tree().get_nodes_in_group("mobs") if by_hero else (caster as Rival)._targets()
	for node in pool:
		if not valid(caster, by_hero, node):
			continue
		if flat((node as Node3D).global_position - at).length() <= radius + body(node as Node3D):
			out.append(node)
	out.sort_custom(func(x, y): return flat(x.global_position - at).length() < flat(y.global_position - at).length())
	return out


static func body(node: Node3D) -> float:
	return (node as Mob).body_radius() if node is Mob else 0.4


static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


static func hit_point(node: Node3D) -> Vector3:
	if node is Mob:
		return (node as Mob).hit_point()
	return node.global_position + Vector3.UP * 1.1


## The skill as its blows carry it: the skill itself (SKILL_POWER, its name and colour on
## the numbers, kill credit, the combo) with only [param fx] as its effects.
static func strike(skill: Dictionary, fx: Dictionary) -> Dictionary:
	var out := skill.duplicate()
	out["fx"] = fx
	return out


## One blow of [param mult] on [param foe]: the hero's through Hero._deal (its room of the
## visual budget, kill credit, drops, the PvP proxies, the hit-heal), an AI's through
## Rival._hit (its war scale, BurstGuard, the hero's defence; no effects of the skill's).
static func deal(caster: Variant, by_hero: bool, foe: Variant, mult: float, color: Color, blow: Dictionary) -> void:
	if not is_instance_valid(caster) or not valid(caster, by_hero, foe):
		return
	if by_hero:
		var hero := caster as Hero
		VfxBudget.hero_begin()
		hero._deal(foe as Mob, mult, color, StringName(String(blow.get("vfx", "dark"))), false, blow)
		VfxBudget.hero_end()
	else:
		(caster as Rival)._hit(foe, mult, color, {})


## [param fn] (art) inside the hero's room of the visual budget when the hero casts.
static func with_room(by_hero: bool, fn: Callable) -> void:
	if by_hero:
		VfxBudget.hero_begin()
	fn.call()
	if by_hero:
		VfxBudget.hero_end()


static func sound(by_hero: bool, at: Vector3, id: StringName, db: float) -> void:
	if id == &"":
		return
	if by_hero:
		AudioManager.play_sfx(id, db)
	else:
		AudioManager.play_sfx_at(at, id, db - 4.0)


## HP now / most of [param unit] (the hero's lives in the profile).
static func hp_of(unit: Node3D) -> int:
	if unit is Hero:
		return int(Game.profile.get("hp", 0))
	return int(unit.get("hp")) if "hp" in unit else 0


static func max_hp_of(unit: Node3D) -> int:
	if unit is Hero:
		return int((unit as Hero).stats.get("max_hp", 1))
	return int(unit.get("max_hp")) if "max_hp" in unit else 1


static func set_hp(unit: Node3D, hp: int) -> void:
	if unit is Hero:
		Game.profile.hp = hp
	elif unit is Mob:
		var m := unit as Mob
		m.hp = hp
		if m._bar:
			m._bar.set_ratio(float(m.hp) / float(maxi(m.max_hp, 1)))


# ---------------------------------------------------------------------------
# Light
# ---------------------------------------------------------------------------

static func material(mode: int, c: Color, core: Color, shade: Color, additive := false, extra := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = ADD if additive else MIX
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("core", core)
	m.set_shader_parameter("shade", shade)
	m.set_shader_parameter("seed", randf() * 40.0)
	for key in extra:
		m.set_shader_parameter(key, extra[key])
	return m


## Shared plain meshes: "disc" (a 2 x 2 ground quad, UV 0..1), "cone" (a beam 1 m long,
## its tip at the top, its foot 1 m wide), "orb" (a sphere of radius 1), "ball" (a coarse
## sphere for the mirror ball).
static func mesh(kind: String) -> Mesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var m: Mesh
	match kind:
		"disc":
			var plane := PlaneMesh.new()
			plane.size = Vector2(2, 2)
			m = plane
		"cone":
			var cone := CylinderMesh.new()
			cone.top_radius = 0.04
			cone.bottom_radius = 0.5
			cone.height = 1.0
			cone.radial_segments = 14
			cone.rings = 1
			cone.cap_top = false
			cone.cap_bottom = false
			m = cone
		"ball":
			var ball := SphereMesh.new()
			ball.radius = 1.0
			ball.height = 2.0
			ball.radial_segments = 18
			ball.rings = 9
			m = ball
		_:
			var orb := SphereMesh.new()
			orb.radius = 1.0
			orb.height = 2.0
			orb.radial_segments = 24
			orb.rings = 12
			m = orb
	_meshes[kind] = m
	return m


## A decoration under [param parent] when the budget has room (null when not): counted in
## VfxBudget until it leaves the tree.
static func piece(parent: Node, kind: String, mat: Material, label: String) -> MeshInstance3D:
	if not is_instance_valid(parent) or not VfxBudget.can_decorate():
		return null
	var mi := MeshInstance3D.new()
	mi.name = label
	mi.mesh = mesh(kind)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	VfxBudget.track_decoration(mi)
	return mi


## A dancer's ring of notes: one decoration (VfxBudget) holding three billboard cards
## named "DanceNote0..2" (a note, a heart, a note in [param colors]); null without room.
static func notes(parent: Node, colors: Array, label: String) -> Node3D:
	if not is_instance_valid(parent) or not VfxBudget.can_decorate():
		return null
	var ring := Node3D.new()
	ring.name = label
	parent.add_child(ring)
	VfxBudget.track_decoration(ring)
	for k in 3:
		_card(ring, "heart" if k == 1 else "note", colors[k % colors.size()], 0.75 if k == 1 else 0.68, "DanceNote%d" % k)
	return ring


## A billboard card of a VfxArt texture ("note", "heart") under the budget.
static func card(parent: Node, kind: String, c: Color, size: float, label: String) -> MeshInstance3D:
	if not is_instance_valid(parent) or not VfxBudget.can_decorate():
		return null
	var mi := _card(parent, kind, c, size, label)
	VfxBudget.track_decoration(mi)
	return mi


static func _card(parent: Node, kind: String, c: Color, size: float, label: String) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = VfxArt.texture(kind)
	mat.albedo_color = c
	mat.disable_fog = true
	mat.no_depth_test = false
	var mi := MeshInstance3D.new()
	mi.name = label
	mi.mesh = VfxKit.quad(Vector2(size, size))
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func set_fade(node: GeometryInstance3D, value: float) -> void:
	if not is_instance_valid(node):
		return
	var mat := node.material_override
	if mat is ShaderMaterial:
		(mat as ShaderMaterial).set_shader_parameter("fade", clampf(value, 0.0, 1.0))
	elif mat is StandardMaterial3D:
		var c := (mat as StandardMaterial3D).albedo_color
		c.a = clampf(value, 0.0, 1.0)
		(mat as StandardMaterial3D).albedo_color = c


## Points [param node] (a "cone", tip up at its origin) from [param top] down to [param foot].
static func beam(node: Node3D, top: Vector3, foot: Vector3, width: float) -> void:
	if not is_instance_valid(node):
		return
	var span := foot - top
	var length := span.length()
	if length < 0.01:
		return
	var down := span / length
	var side := down.cross(Vector3.FORWARD if absf(down.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT).normalized()
	var other := side.cross(down).normalized()
	# The cone's +Y runs from its foot to its tip: point it up the beam.
	node.global_transform = Transform3D(Basis(side * width, -down * length, -other * width), top + down * length * 0.5)
