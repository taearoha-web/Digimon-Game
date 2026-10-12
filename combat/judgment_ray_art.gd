class_name JudgmentRayArt
extends Node3D
## Art only. One sequence owns the clock and the single damage callback.
const SEAL := preload("res://shaders/judgment_seal.gdshader")
const COLUMN := preload("res://shaders/judgment_column.gdshader")
const GLYPHS := preload("res://shaders/judgment_glyphs.gdshader")
const HEIGHT := 9.2
const TAIL := 1.35
static var _column: CylinderMesh
static var _glyphs: ArrayMesh
var _ground: MeshInstance3D
var _sky: MeshInstance3D
var _beam: MeshInstance3D
var _shell: MeshInstance3D
var _shock: MeshInstance3D
var _debris: MeshInstance3D
var _crowns: Array[MeshInstance3D] = []
var _filigree: EliteSkillArt

static func column_mesh() -> CylinderMesh:
	if not _column:
		_column = CylinderMesh.new()
		_column.top_radius = 1.0
		_column.bottom_radius = 1.0
		_column.height = 1.0
		_column.radial_segments = 32
		_column.cap_top = false
		_column.cap_bottom = false
	return _column

static func glyph_mesh() -> ArrayMesh:
	if _glyphs:
		return _glyphs
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 20:
		var a := TAU * float(i) / 20.0
		var centre := Vector3(cos(a)*2.0, 0.3+float(i%4)*0.35, sin(a)*2.0)
		var side := Vector3(-sin(a),0,cos(a))
		# Three bars form a small forked verdict rune, batched into one mesh.
		for bar in [Vector4(0,-0.18,0,0.22),Vector4(-0.14,0.04,0,0.20),Vector4(0,0.20,0.14,0.04)]:
			var from := Vector2(bar.x,bar.y)
			var to := Vector2(bar.z,bar.w)
			var normal := Vector2(-(to-from).y,(to-from).x).normalized()*0.025
			var corners := [from-normal,to-normal,from+normal,from+normal,to-normal,to+normal]
			for point in corners:
				st.set_uv2(Vector2(float(i)/20.0,float(i%4)/3.0))
				st.add_vertex(centre+side*point.x+Vector3.UP*point.y)
	st.generate_normals()
	_glyphs=st.commit()
	return _glyphs

func _node(label: String, mesh: Mesh, shader: Shader, optional := false) -> MeshInstance3D:
	if optional and not VfxBudget.can_decorate():
		return null
	var node := MeshInstance3D.new()
	node.name=label
	node.mesh=mesh
	var mat := ShaderMaterial.new()
	mat.shader=shader
	node.material_override=mat
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	if optional:
		VfxBudget.track_decoration(node)
	return node

func _plate(label: String, y: float, radius: float, optional := false) -> MeshInstance3D:
	var node := _node(label, SkillInk.quad(), SEAL, optional)
	if node:
		node.position.y=y
		node.rotation.x=-PI*0.5
		node.scale=Vector3.ONE*radius
	return node

func _ready() -> void:
	_ground=_plate("JudgmentTargetSeal",0.06,2.9)
	_sky=_plate("JudgmentHeavenSeal",HEIGHT,4.1)
	_beam=_node("JudgmentEssentialColumn",column_mesh(),COLUMN)
	_shell=_node("JudgmentColumnCorona",column_mesh(),COLUMN,true)
	if _shell:
		_param(_shell,"shell",1.0)
	for i in VfxBudget.count(3,1):
		var crown := _plate("JudgmentOrbitalCrown",HEIGHT-0.6-float(i)*0.7,3.3-float(i)*0.48,true)
		if crown:
			# Tilted outer orbits and a horizontal inner iris form a celestial lens.
			crown.rotation.z=0.17 if i==0 else (-0.17 if i==1 else 0.0)
			_param(crown,"mode",3.0)
			_crowns.append(crown)
	_shock=_plate("JudgmentImpactWave",0.085,5.4,true)
	if _shock:
		_param(_shock,"mode",2.0)
	_debris=_node("JudgmentDissolvingRunes",glyph_mesh(),GLYPHS,true)
	_filigree = EliteSkillArt._root(self, global_position, 100.0, "JudgmentSkyFiligree")
	_filigree.set_process(false)
	var look := EliteSkillArt.palette(ClassData.find_skill(&"mage", "judgment_ray"))
	_filigree.layer("wings", look, Vector3(0, HEIGHT, 0), Vector3.ONE * 2.4, Vector3.ZERO, 0.0, 2.4)
	_filigree.layer("cathedral", look, Vector3(0, HEIGHT - 1.0, 0), Vector3(2.7, 1.8, 2.7), Vector3.ZERO, 0.0, 2.4)
	draw_stage(0.0,-1.0)

func _param(node: MeshInstance3D, key: String, value: float) -> void:
	if node:
		(node.material_override as ShaderMaterial).set_shader_parameter(key,value)

func draw_stage(charge: float, after: float) -> void:
	if is_instance_valid(_filigree):
		_filigree.age = charge * 0.8 if after < 0.0 else 0.8 + after
		_filigree._draw()
	var landed := after >= 0.0
	var age := charge if not landed else 1.0+after
	var fade := 1.0-smoothstep(0.48,TAIL,maxf(after,0.0))
	var power := (1.0-smoothstep(0.10,0.70,after)) if landed else charge*0.12
	for plate in [_ground,_sky]+_crowns:
		_param(plate,"age",age)
		_param(plate,"reveal",1.0 if landed else smoothstep(0.0,0.72,charge))
		_param(plate,"fade",fade)
		_param(plate,"power",power)
	_param(_ground,"mode",1.0)
	# Descent reaches the floor exactly when the sequence applies damage.
	var descent := 1.0 if landed else smoothstep(0.78,1.0,charge)
	var beam_fade := (1.0-smoothstep(0.22,0.78,after)) if landed else descent
	for shaft in [_beam,_shell]:
		if not shaft:
			continue
		shaft.visible=descent>0.001
		var width := 1.1 if shaft==_beam else 1.75
		width *= lerpf(0.85,1.0,power)
		shaft.scale=Vector3(width,maxf(0.001,HEIGHT*descent),width)
		shaft.position.y=HEIGHT-HEIGHT*descent*0.5
		_param(shaft,"age",age)
		_param(shaft,"fade",beam_fade)
	if _shock:
		_shock.visible=landed
		_param(_shock,"age",age)
		_param(_shock,"reveal",clampf(after/0.7,0.0,1.0))
		_param(_shock,"power",power)
		_param(_shock,"fade",(1.0-smoothstep(0.28,0.85,after)) if landed else 0.0)
	if _debris:
		_debris.visible=landed
		_param(_debris,"age",maxf(after,0.0))
		_param(_debris,"fade",fade if landed else 0.0)

static func warm_up(parent: Node3D, at: Vector3) -> void:
	var art := JudgmentRayArt.new()
	art.position=at
	art.scale=Vector3.ONE*0.001
	parent.add_child(art)
	art.draw_stage(1.0,0.1)
	art.create_tween().tween_interval(0.4).finished.connect(art.queue_free,CONNECT_ONE_SHOT)
