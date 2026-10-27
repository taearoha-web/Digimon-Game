class_name BuffAura
extends Node3D
## Skill-specific, open-centre protection. One shared mesh, no emitter or light.
const AURA_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
uniform vec4 primary : source_color;
uniform vec4 accent : source_color;
uniform float phase = 0.0;
uniform bool grove = false;
uniform float growth = 1.0;
varying vec3 local_pos;
void vertex() {
	local_pos = VERTEX;
	if (grove) {
		float reveal = smoothstep(0.0, 1.0, growth * 1.5 - VERTEX.y * 0.13);
		VERTEX.y *= reveal;
		if (COLOR.b > 0.5) {
			VERTEX.y += sin(TIME * 1.2 + VERTEX.x * 3.0) * 0.15;
		}
		VERTEX.xz += vec2(sin(TIME * 0.9 + VERTEX.y * 2.0), cos(TIME * 0.8 + VERTEX.x * 2.0)) * 0.018 * VERTEX.y;
	}
}
void fragment() {
	float edge = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	float inlay = pow(0.5 + 0.5 * sin(local_pos.y * 15.0 + local_pos.x * 5.0), 8.0);
	float sweep = pow(0.5 + 0.5 * sin(local_pos.y * 3.0 - TIME * 1.1 + phase), 12.0);
	ALBEDO = mix(primary.rgb, accent.rgb, clamp(edge * 0.5 + inlay * 0.45 + sweep * 0.3, 0.0, 1.0));
	ALPHA = 0.40 + edge * 0.24 + inlay * 0.15;
	if (grove) {
		ALBEDO = mix(primary.rgb * (0.75 + edge * 0.3), accent.rgb, COLOR.r);
		ALBEDO += accent.rgb * sweep * 0.18;
		ALPHA = mix(0.34 + edge * 0.16, 0.78, smoothstep(0.35, 0.65, COLOR.r)) * smoothstep(0.0, 0.22, growth);
	}
}
"""
static var _shader: Shader
var body_top := 2.8
var look: Dictionary
var lane := 0
var _age := 0.0
var _retry := 0.0
var _body: MeshInstance3D

static func warm_up(parent: Node3D, at: Vector3) -> void:
	var sample := BuffAura.new()
	sample.look = BuffArt.profile({"skill_id": "energy_shield"})
	sample.position = at
	sample.scale = Vector3.ONE * 0.001
	parent.add_child(sample)
	sample.create_tween().tween_interval(0.4).finished.connect(sample.queue_free, CONNECT_ONE_SHOT)

static func sync(host: Node3D, auras: Dictionary, buffs: Array, now: int, alive: bool, top: Callable) -> void:
	var wanted := {}
	if alive:
		for buff in buffs:
			if int(buff.until) > now:
				var key := "%s:%s" % [BuffBook.identity(buff), buff.get("ally", false)]
				wanted[key] = buff
	# Drop old art immediately, before the new skill enters.
	for key in auras.keys():
		if not wanted.has(key):
			if is_instance_valid(auras[key]):
				auras[key].hide()
				auras[key].queue_free()
			auras.erase(key)
	var index := 0
	for key in wanted:
		if not auras.has(key) or not is_instance_valid(auras[key]):
			var aura := BuffAura.new()
			aura.look = BuffArt.profile(wanted[key])
			aura.body_top = float(top.call())
			aura.lane = index
			host.add_child(aura)
			auras[key] = aura
		index += 1

## Height from the feet to the highest point of a character's meshes (hair, hat...).
static func measure_top(root: Node, host: Node3D) -> float:
	var top := 2.0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or mi.get_parent() is BuffAura or not mi.is_inside_tree():
			continue
		var box := mi.global_transform * mi.get_aabb()
		top = maxf(top, box.end.y - host.global_position.y)
	return clampf(top, 2.0, 4.5)


func _ready() -> void:
	rotation.y = float(lane) * 0.61
	_build()

func _build() -> void:
	if _body != null or not VfxBudget.can_decorate():
		return
	if _shader == null:
		_shader = Shader.new()
		_shader.code = AURA_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("primary", look.primary)
	mat.set_shader_parameter("accent", look.accent)
	mat.set_shader_parameter("phase", float(lane) * 1.7)
	mat.set_shader_parameter("grove", look.shape == "grove")
	if look.shape == "grove":
		mat.set_shader_parameter("growth", 0.0)
		create_tween().tween_method(func(value: float): mat.set_shader_parameter("growth", value), 0.0, 1.0, 0.85)
	_body = MeshInstance3D.new()
	_body.mesh = BuffArt.mesh_for(look)
	_body.material_override = mat
	_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	VfxBudget.track_decoration(_body)
	add_child(_body)
	var target := Vector3.ONE * clampf(body_top / 2.8, 0.65, 1.4)
	target.x *= 1.0 + lane * 0.065
	target.z *= 1.0 + lane * 0.065
	_body.scale = target * 0.85
	_body.create_tween().tween_property(_body, "scale", target, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if look.shape == "note" and VfxBudget.quality() > 0 and is_inside_tree():
		# A Bard's song reaches this member: a puff of notes rises round them (one GPU draw, gone in 0.9 s).
		ShaderBurst.emit(self, global_position + Vector3.UP * 1.1, look.primary, "note", 8, "rise", 1.4, 0.6, 0.9, 0.3)

func _process(delta: float) -> void:
	_age += delta
	rotation.y += delta * float(look.spin)
	if _body:
		_body.position.y = 0.025 * sin(_age * 1.6 + lane)
	else:
		_retry += delta
		if _retry >= 0.5:
			_retry = 0.0
			_build()
