class_name TauntChain
extends MeshInstance3D
## The Defender's provoke made visible: a heavy chain of interlocking links from
## the taunted monster to the great shield, over a glowing core that sends a
## pulse of light down to the foe every beat. Re-aimed every frame for the taunt
## seconds and freed with either end. Cosmetic: the taunt itself lives in Mob.
## Draws: the links (one mesh, real-size links per half-metre of length) and
## the glow (one crossed quad pair); both share the one tracked decoration.
const LIMIT := 6
const GLOW_SHADER := preload("res://shaders/melee_chain.gdshader")
## Length of one link (metres) and the steps the link meshes are cached at.
const LINK := 0.26
const STEP := 0.5
static var _active := 0
static var _meshes: Dictionary = {}
static var _glow_mesh: ArrayMesh
var mob_ref: WeakRef
var hero_ref: WeakRef
var left := 0.0
var age := 0.0
var mat: ShaderMaterial
var glow: MeshInstance3D
var glow_mat: ShaderMaterial
var _bucket := -1

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
	chain.mat.set_shader_parameter("opacity", 0.92)
	chain.material_override = chain.mat
	chain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chain.glow = MeshInstance3D.new()
	chain.glow.mesh = glow_mesh()
	chain.glow_mat = ShaderMaterial.new()
	chain.glow_mat.shader = GLOW_SHADER
	chain.glow_mat.set_shader_parameter("primary", Color("ff6a3a"))
	chain.glow_mat.set_shader_parameter("accent", Color("ffe0a8"))
	chain.glow.material_override = chain.glow_mat
	chain.glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chain.add_child(chain.glow)
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
	var length := dir.length()
	visible = length > 0.3
	if not visible:
		return
	# Links keep their real size: the mesh follows the length in half-metre steps.
	var bucket := clampi(int(round(length / STEP)), 1, 40)
	if bucket != _bucket:
		_bucket = bucket
		mesh = chain_mesh(bucket)
	global_position = from
	look_at(to, Vector3.RIGHT if absf(dir.normalized().dot(Vector3.UP)) > 0.98 else Vector3.UP)
	scale = Vector3(1, 1, length)
	var fade := clampf(left / 0.4, 0.0, 1.0) * smoothstep(0.0, 0.15, age)
	mat.set_shader_parameter("age", age)
	mat.set_shader_parameter("fade", fade)
	glow_mat.set_shader_parameter("age", age)
	glow_mat.set_shader_parameter("fade", fade)
	glow_mat.set_shader_parameter("span", length)

## A unit chain along -Z for a chain about bucket * STEP metres long: a sagging
## spine threaded through interlocking links that alternate flat and upright,
## each about LINK long once scaled to that length. Cached per bucket.
static func chain_mesh(bucket := 8) -> ArrayMesh:
	bucket = clampi(bucket, 1, 40)
	if _meshes.has(bucket):
		return _meshes[bucket]
	var metres := float(bucket) * STEP
	var count := maxi(3, int(round(metres / (LINK * 0.78))))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sag := 0.06 + 0.012 * metres
	var spine := PackedVector3Array()
	for i in 17:
		var t := float(i) / 16.0
		spine.append(Vector3(0, -sin(t * PI) * sag, -t))
	EliteSkillArt._line(st, spine, 0.016, 0.7)
	for k in count:
		var t := (float(k) + 0.5) / float(count)
		var c := Vector3(0, -sin(t * PI) * sag, -t)
		var across := Vector3.UP if k % 2 == 0 else Vector3.RIGHT
		var pts := PackedVector3Array()
		for j in 13:
			var a := TAU * float(j) / 12.0
			# Along the chain the link is LINK long (in unit length: LINK / metres).
			pts.append(c + Vector3.FORWARD * cos(a) * (LINK * 0.5 / metres) + across * sin(a) * 0.075)
		EliteSkillArt._line(st, pts, 0.026, 1.0 if k % 2 == 0 else 0.4)
	st.generate_normals()
	var built := st.commit()
	_meshes[bucket] = built
	return built

## Two crossed quads along -Z (0..1), 0.34 wide: UV.x across, UV.y 0 at the
## foe -> 1 at the shield, for the glow shader.
static func glow_mesh() -> ArrayMesh:
	if _glow_mesh:
		return _glow_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [Vector3.RIGHT, Vector3.UP]:
		var s: Vector3 = side * 0.17
		var corners := [[-s, Vector2(0, 0)], [-s + Vector3.FORWARD, Vector2(0, 1)], [s + Vector3.FORWARD, Vector2(1, 1)], [s, Vector2(1, 0)]]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_uv(corners[i][1])
			st.add_vertex(corners[i][0])
	_glow_mesh = st.commit()
	return _glow_mesh
