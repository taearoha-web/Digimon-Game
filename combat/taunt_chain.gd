class_name TauntChain
extends MeshInstance3D
## The Defender's provoke made visible: one light chain (a single tube draw) from
## the taunted monster to the great shield, re-aimed every frame for the taunt
## seconds and freed with either end. Cosmetic: the taunt itself lives in Mob.
const LIMIT := 6
static var _active := 0
static var _mesh: ArrayMesh
var mob_ref: WeakRef
var hero_ref: WeakRef
var left := 0.0
var age := 0.0
var mat: ShaderMaterial

static func link(mob: Node3D, hero: Node3D, seconds: float) -> TauntChain:
	if _active >= LIMIT or not VfxBudget.can_decorate() or not is_instance_valid(mob) or not is_instance_valid(hero):
		return null
	var parent := mob.get_parent() as Node3D
	if parent == null:
		return null
	var chain := TauntChain.new()
	chain.name = "TauntChain"
	chain.mesh = chain_mesh()
	chain.mat = EliteSkillArt.material({"primary": Color("ff6a3a"), "accent": Color("ffe0a8"), "shade": Color("7a1a22")})
	chain.mat.set_shader_parameter("opacity", 0.8)
	chain.material_override = chain.mat
	chain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chain.mob_ref = weakref(mob)
	chain.hero_ref = weakref(hero)
	chain.left = seconds
	parent.add_child(chain)
	VfxBudget.track_decoration(chain)
	_active += 1
	chain.tree_exited.connect(func(): _active = maxi(0, _active - 1), CONNECT_ONE_SHOT)
	chain._update()
	return chain

func _process(delta: float) -> void:
	left -= delta
	age += delta
	if left <= 0.0:
		queue_free()
		return
	_update()

func _update() -> void:
	var mob := mob_ref.get_ref() as Node3D
	var hero := hero_ref.get_ref() as Node3D
	if not is_instance_valid(mob) or not mob.is_inside_tree() or not is_instance_valid(hero) or not hero.is_inside_tree() or (mob.has_method("is_dead") and bool(mob.call("is_dead"))) or (hero.has_method("is_dead") and bool(hero.call("is_dead"))):
		queue_free()
		return
	var from: Vector3 = mob.call("hit_point") if mob.has_method("hit_point") else mob.global_position + Vector3.UP
	var visual := hero.get("visual") as HeroVisual
	var to: Vector3 = visual.skill_emission_position() if is_instance_valid(visual) else hero.global_position + Vector3.UP * 1.2
	var dir := to - from
	visible = dir.length() > 0.3
	if not visible:
		return
	global_position = from
	look_at(to, Vector3.RIGHT if absf(dir.normalized().dot(Vector3.UP)) > 0.98 else Vector3.UP)
	scale = Vector3(1, 1, dir.length())
	mat.set_shader_parameter("age", age)
	mat.set_shader_parameter("fade", clampf(left / 0.4, 0.0, 1.0) * smoothstep(0.0, 0.15, age))

## A unit chain along -Z: a sagging spine with alternating links, built once.
static func chain_mesh() -> ArrayMesh:
	if _mesh:
		return _mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spine := PackedVector3Array()
	for i in 13:
		var t := float(i) / 12.0
		spine.append(Vector3(0, -sin(t * PI) * 0.06, -t))
	EliteSkillArt._line(st, spine, 0.022, 0.7)
	for k in 12:
		var t := (float(k) + 0.5) / 12.0
		var c := Vector3(0, -sin(t * PI) * 0.06, -t)
		var across := Vector3.UP if k % 2 == 0 else Vector3.RIGHT
		var pts := PackedVector3Array()
		for j in 11:
			var a := TAU * float(j) / 10.0
			pts.append(c + Vector3.FORWARD * cos(a) * 0.035 + across * sin(a) * 0.05)
		EliteSkillArt._line(st, pts, 0.01, 1.0 if k % 2 == 0 else 0.35)
	st.generate_normals()
	_mesh = st.commit()
	return _mesh
