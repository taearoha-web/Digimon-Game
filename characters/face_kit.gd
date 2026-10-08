class_name FaceKit
extends RefCounted
## The hero's customisable head: a skin-coloured head with ears, eyes, brows,
## nose, mouth and a hair style, all built from primitives (the KayKit heads
## have their faces baked into a texture and cannot be changed). A "look" is
##   { gender, skin, hair, hair_color, eyes, eye_color, nose, mouth }
## (all ints). Everything is placed in head-bone space like GearKit hats:
## the head is centred at y = CY, the front of the face is +Z.

const CY := 0.58
const RX := 0.55
const RY := 0.52
const RZ := 0.52

const SKINS: Array[Color] = [Color("fbe4d8"), Color("f8ccab"), Color("eab98f"), Color("d29a6c"), Color("b9794e"), Color("94583a"), Color("6e3f28"), Color("f1d6c4")]
const SKIN_NAMES: Array[String] = ["ขาวใส", "ขาวอมชมพู", "ผิวสองสี", "แทนอ่อน", "แทน", "น้ำตาล", "เข้ม", "ซีด"]
const HAIR_COLORS: Array[Color] = [Color("2a2220"), Color("5b3a29"), Color("8a5a32"), Color("d8b25a"), Color("c4452e"), Color("e8e0d0"), Color("5a7ad8"), Color("e87ab0"), Color("8a5ad8"), Color("4aa86a"), Color("b8c0d0"), Color("e8843a")]
const HAIR_COLOR_NAMES: Array[String] = ["ดำ", "น้ำตาลเข้ม", "น้ำตาล", "บลอนด์", "แดง", "ขาว", "ฟ้า", "ชมพู", "ม่วง", "เขียว", "เงิน", "ส้ม"]
## Starter outfits for the Vagabond (0 = the stock one): [name, outfit model, tint, cape part or ""].
const OUTFITS := [
	["ชุดนักเดินทาง", "", Color.WHITE, ""],
	["ชุดนักล่าป่า", "Ranger", Color.WHITE, "Ranger_Cape"],
	["ชุดอัศวินฝึกหัด", "Knight", Color.WHITE, ""],
	["ชุดจอมเวทม่วง", "Mage", Color.WHITE, "Mage_Cape"],
	["ชุดเงาราตรี", "Rogue", Color(0.75, 0.75, 1.05), "Rogue_Cape"],
	["ชุดนักรบป่าเถื่อน", "Barbarian", Color.WHITE, ""],
	["ชุดฟ้าสดใส", "Knight", Color(0.6, 0.95, 1.7), ""],
	["ชุดแดงเพลิง", "Barbarian", Color(1.7, 0.75, 0.6), ""],
	["ชุดทองหรู", "Mage", Color(1.7, 1.45, 0.7), "Mage_Cape"],
]
const EYE_COLORS: Array[Color] = [Color("3a2a22"), Color("5a8ad8"), Color("4aa86a"), Color("8a6a3a"), Color("a05ad8"), Color("d8604a")]
const EYE_COLOR_NAMES: Array[String] = ["น้ำตาลเข้ม", "ฟ้า", "เขียว", "น้ำตาลอำพัน", "ม่วง", "แดง"]
const EYE_NAMES: Array[String] = ["กลมโต", "รีสูง", "ง่วงๆ", "ยิ้มหยี", "เฉียบคม"]
const NOSE_NAMES: Array[String] = ["จุดเล็ก", "กลมน่ารัก", "โด่ง", "กว้าง"]
const MOUTH_NAMES: Array[String] = ["ยิ้ม", "เฉยๆ", "อ้าปากยิ้ม", "ทำปาก", "ยิ้มกว้างเห็นฟัน"]
const HAIR_NAMES := [
	["ทรงสั้น", "ทรงตั้ง", "ปัดข้าง", "โมฮอว์ค", "ทรงเกรียน", "ผมยาวประบ่า", "ทรงฟูกลม", "ทรงเกาหลีปัดหน้า"],
	["ผมยาว", "หางม้า", "ผมคู่", "ทรงบ๊อบ", "จุกมวย", "ผมเปียคู่", "ผมยาวสลวย", "มัดสูงสองข้าง"],
]
const GENDER_NAMES: Array[String] = ["ชาย", "หญิง"]

const SKIN_SHADER := """
shader_type spatial;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec3 skin : source_color = vec3(0.95, 0.6, 0.45);
uniform vec3 skin_ref : source_color = vec3(0.97, 0.8, 0.67);
uniform float rough = 0.9;
void fragment() {
	vec4 c = texture(albedo_tex, UV);
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float sat = (mx - mn) / max(mx, 0.001);
	vec3 rgb = c.rgb;
	if (c.r >= c.g && c.g >= c.b && sat > 0.3 && sat < 0.9 && mx > 0.7) {
		rgb = min(c.rgb / max(skin_ref, vec3(0.01)) * skin, vec3(1.0));
	}
	ALBEDO = rgb * tint.rgb;
	ROUGHNESS = rough;
	SPECULAR = 0.16;
	RIM = 0.18;
	RIM_TINT = 0.75;
}
"""

static var _skin_shader: Shader


static func default_look() -> Dictionary:
	return {"gender": 0, "skin": 1, "hair": 0, "hair_color": 1, "eyes": 0, "eye_color": 0, "nose": 0, "mouth": 0, "outfit": 0}


static func option_count(key: String, gender: int) -> int:
	match key:
		"gender": return 2
		"skin": return SKINS.size()
		"hair": return (HAIR_NAMES[clampi(gender, 0, 1)] as Array).size()
		"hair_color": return HAIR_COLORS.size()
		"eyes": return EYE_NAMES.size()
		"eye_color": return EYE_COLORS.size()
		"nose": return NOSE_NAMES.size()
		"mouth": return MOUTH_NAMES.size()
		"outfit": return OUTFITS.size()
	return 1


static func random_look(rng: RandomNumberGenerator) -> Dictionary:
	var look := default_look()
	look["gender"] = rng.randi() % 2
	for key in ["skin", "hair", "hair_color", "eyes", "eye_color", "nose", "mouth", "outfit"]:
		look[key] = rng.randi() % option_count(key, int(look["gender"]))
	return look


## Ints in range, with defaults for missing keys (saves load floats from JSON).
static func repair(look: Dictionary) -> Dictionary:
	var out := default_look()
	for key in out:
		if look.has(key):
			out[key] = int(look[key])
	out["gender"] = clampi(int(out["gender"]), 0, 1)
	for key in ["skin", "hair", "hair_color", "eyes", "eye_color", "nose", "mouth", "outfit"]:
		out[key] = clampi(int(out[key]), 0, option_count(key, int(out["gender"])) - 1)
	return out


static func skin_color(look: Dictionary) -> Color:
	return SKINS[clampi(int(look.get("skin", 1)), 0, SKINS.size() - 1)]


## Body parts (arms, legs...) re-skinned: pixels of the skin colour in the
## KayKit atlas are swapped for the chosen tone, everything else is untouched.
static func skin_material(source: StandardMaterial3D, tint: Color, look: Dictionary) -> Material:
	if source == null or source.albedo_texture == null:
		return source
	if _skin_shader == null:
		_skin_shader = Shader.new()
		_skin_shader.code = SKIN_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _skin_shader
	mat.set_shader_parameter("albedo_tex", source.albedo_texture)
	mat.set_shader_parameter("tint", source.albedo_color * StorybookFinish.balanced_tint(tint))
	mat.set_shader_parameter("skin", skin_color(look))
	mat.set_shader_parameter("skin_ref", Color("f5b993"))
	return mat


# --- head ------------------------------------------------------------------

static func _m(color: Color, unshaded := false) -> StandardMaterial3D:
	var source := MeshKit.toon(color, {"unshaded": true} if unshaded else {})
	return source if unshaded else StorybookFinish.material(source)


static func _p(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, size: Vector3, rot := Vector3.ZERO, unshaded := false) -> MeshInstance3D:
	var mi := MeshKit.part(parent, mesh, _m(color, unshaded), pos, size, rot)
	mi.set_meta("face_detail", parent.name != "Hair")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Point on the front of the face at (x, y) in head space.
static func _face(x: float, y: float, lift := 0.0) -> Vector3:
	var nx := x / RX
	var ny := (y - CY) / RY
	var rest := maxf(0.0, 1.0 - nx * nx - ny * ny)
	return Vector3(x, y, RZ * sqrt(rest) + lift)


## The whole head (without the neck/body). [param with_hair] false under helmets.
static func build_head(look: Dictionary, with_hair := true) -> Node3D:
	look = repair(look)
	var root := FaceExpression.new()
	root.name = "CustomHead"
	root.interval = 3.6 + float(int(look.hair) % 4) * 0.35
	root.phase = 0.8 + float(int(look.hair_color) % 5) * 0.41
	var skin := skin_color(look)
	var female := int(look.gender) == 1
	_p(root, MeshKit.sphere(), skin, Vector3(0, CY, 0), Vector3(RX * 2.0, RY * 2.0, RZ * 2.0)).set_meta("face_detail", false)
	for side in [-1.0, 1.0]:
		_p(root, MeshKit.sphere(), skin.darkened(0.04), Vector3(side * (RX - 0.02), CY - 0.02, -0.02), Vector3(0.13, 0.2, 0.15))
		_p(root, MeshKit.sphere(), skin.lerp(Color("d88687"), 0.28), Vector3(side * (RX + 0.014), CY - 0.015, 0.047), Vector3(0.055, 0.11, 0.045))
	_eyes(root, look, skin, female)
	_nose(root, int(look.nose), skin)
	_mouth(root, int(look.mouth), skin, female)
	# Opaque warm cheeks stay readable on all skin tones without alpha sorting.
	for side in [-1.0, 1.0]:
		var cheek := _face(side * 0.33, CY - 0.145, 0.006)
		_p(root, MeshKit.sphere(), skin.lerp(Color("e78089"), 0.27 if female else 0.16), cheek, Vector3(0.16, 0.065, 0.028), Vector3(0, side * 24.0, 0))
	if with_hair:
		_hair(root, look)
	return root


static func _eyes(root: FaceExpression, look: Dictionary, skin: Color, female: bool) -> void:
	var hair_color: Color = HAIR_COLORS[int(look.hair_color)]
	var iris: Color = EYE_COLORS[int(look.eye_color)]
	var kind := int(look.eyes)
	var ey := CY - 0.0
	for side in [-1.0, 1.0]:
		var ex: float = side * 0.2
		var at := _face(ex, ey, -0.013)
		var eye := Node3D.new()
		eye.name = "EyeLeft" if side < 0.0 else "EyeRight"
		eye.position = at
		root.add_child(eye)
		if kind != 3:
			root.eyes.append(eye)
		match kind:
			0:
				_eye(eye, Vector3.ZERO, Vector2(0.19, 0.235), Vector2(0.145, 0.195), iris, 0.0)
			1:
				_eye(eye, Vector3.ZERO, Vector2(0.155, 0.25), Vector2(0.12, 0.21), iris, 0.0)
			2:
				_eye(eye, Vector3.ZERO, Vector2(0.19, 0.155), Vector2(0.13, 0.13), iris, 0.0)
			3:
				var happy_eye := PackedVector2Array()
				for i in 21:
					var t := float(i) / 20.0
					happy_eye.append(Vector2(ex + (t - 0.5) * 0.18, ey + sin(t * PI) * 0.06))
				_face_stroke(root, happy_eye, Color("352c43"), 0.025)
			_:
				_eye(eye, Vector3.ZERO, Vector2(0.2, 0.14), Vector2(0.12, 0.125), iris, side * -12.0)
		# Brow (and lashes for girls).
		var brow := _face(ex, ey + 0.2, 0.0)
		var brow_w := 0.17 if female else 0.2
		var brow_h := 0.03 if female else 0.045
		_p(root, MeshKit.sphere(), hair_color.darkened(0.12), brow + Vector3(0, 0, 0.01), Vector3(brow_w, brow_h, 0.035), Vector3(0, 0, side * -8.0), true)
		if female and kind != 3:
			_p(root, MeshKit.box(), Color("2a1c18"), at + Vector3(side * 0.1, 0.1, 0.05), Vector3(0.06, 0.025, 0.03), Vector3(0, 0, side * 28.0), true)


static func _eye(root: Node3D, at: Vector3, white: Vector2, iris_size: Vector2, iris: Color, tilt: float) -> void:
	var rot := Vector3(0, 0, tilt)
	_p(root, MeshKit.sphere(), Color("352c43"), at + Vector3(0, 0.006, -0.008), Vector3(white.x + 0.024, white.y + 0.024, 0.078), rot, true)
	_p(root, MeshKit.sphere(), Color("fff9ee"), at, Vector3(white.x, white.y, 0.084), rot, true)
	_p(root, MeshKit.sphere(), iris.darkened(0.14), at + Vector3(0, -0.007, 0.03), Vector3(iris_size.x, iris_size.y, 0.076), rot, true)
	_p(root, MeshKit.sphere(), iris.lightened(0.28), at + Vector3(0, -iris_size.y * 0.23, 0.064), Vector3(iris_size.x * 0.73, iris_size.y * 0.43, 0.024), rot, true)
	_p(root, MeshKit.sphere(), Color("232032"), at + Vector3(0, 0.005, 0.064), Vector3(iris_size.x * 0.5, iris_size.y * 0.61, 0.04), rot, true)
	_p(root, MeshKit.sphere(), Color.WHITE, at + Vector3(-0.028, 0.051, 0.084), Vector3(0.05, 0.059, 0.02), Vector3.ZERO, true)
	_p(root, MeshKit.sphere(), Color("fff0cf"), at + Vector3(0.03, -0.036, 0.083), Vector3(0.023, 0.026, 0.014), Vector3.ZERO, true)


static func _nose(root: Node3D, kind: int, skin: Color) -> void:
	var at := _face(0, CY - 0.17, -0.01)
	match kind:
		0:
			_p(root, MeshKit.sphere(), skin.lerp(Color("d88a78"), 0.18), at + Vector3(0, 0, 0.013), Vector3(0.038, 0.028, 0.036))
		1:
			_p(root, MeshKit.sphere(), skin.lightened(0.05), at + Vector3(0, 0.01, 0.0), Vector3(0.1, 0.09, 0.09))
		2:
			_p(root, MeshKit.cone(), skin.lightened(0.04), at + Vector3(0, 0.03, 0.01), Vector3(0.09, 0.16, 0.09), Vector3(90, 0, 0))
		_:
			_p(root, MeshKit.sphere(), skin.lightened(0.03), at + Vector3(0, 0.0, 0.0), Vector3(0.17, 0.08, 0.08))
			_p(root, MeshKit.sphere(), skin.darkened(0.2), at + Vector3(-0.045, -0.03, 0.035), Vector3(0.03, 0.025, 0.02), Vector3.ZERO, true)
			_p(root, MeshKit.sphere(), skin.darkened(0.2), at + Vector3(0.045, -0.03, 0.035), Vector3(0.03, 0.025, 0.02), Vector3.ZERO, true)


static func _mouth(root: Node3D, kind: int, skin: Color, female: bool) -> void:
	var lip := Color("b56575") if female else skin.lerp(Color("a36360"), 0.65)
	var dark := Color("4a1c1c")
	var at := _face(0, CY - 0.33, -0.02)
	match kind:
		0, 4:
			var width := 0.25 if kind == 0 else 0.34
			if kind == 4:
				_p(root, MeshKit.box(), Color("fbfbf5"), at + Vector3(0, -0.01, 0.06), Vector3(width * 0.8, 0.05, 0.03), Vector3.ZERO, true)
			var smile := PackedVector2Array()
			for i in 25:
				var t := float(i) / 24.0
				smile.append(Vector2((t - 0.5) * width, CY - 0.30 - sin(t * PI) * 0.046))
			_face_stroke(root, smile, lip if kind == 0 else dark, 0.016)
		1:
			_p(root, MeshKit.box(), lip, at + Vector3(0, 0, 0.05), Vector3(0.2, 0.035, 0.03), Vector3.ZERO, true)
		2:
			_p(root, MeshKit.sphere(), dark, at + Vector3(0, 0, 0.04), Vector3(0.2, 0.13, 0.06), Vector3.ZERO, true)
			_p(root, MeshKit.sphere(), Color("e8707a"), at + Vector3(0, -0.035, 0.065), Vector3(0.11, 0.05, 0.04), Vector3.ZERO, true)
		_:
			_p(root, MeshKit.sphere(), lip, at + Vector3(0, 0, 0.045), Vector3(0.09, 0.07, 0.05), Vector3.ZERO, true)


# --- hair ------------------------------------------------------------------

## A continuous thin ribbon follows the face surface. This stays a clean drawn
## smile at portrait distance instead of separated beads that resemble stubble.
static func _face_stroke(root: Node3D, points: PackedVector2Array, color: Color, width: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in points.size():
		var previous := points[maxi(i - 1, 0)]
		var next := points[mini(i + 1, points.size() - 1)]
		var tangent := (next - previous).normalized()
		var normal := Vector2(-tangent.y, tangent.x) * width * 0.5
		for side in [-1.0, 1.0]:
			var p: Vector2 = points[i] + normal * side
			st.set_normal(Vector3.BACK)
			st.add_vertex(_face(p.x, p.y, 0.014))
	for i in points.size() - 1:
		var a := i * 2
		for index in [a, a + 1, a + 2, a + 1, a + 3, a + 2]:
			st.add_index(index)
	_p(root, st.commit(), color, Vector3.ZERO, Vector3.ONE, Vector3.ZERO, true)

static func _hair(root: Node3D, look: Dictionary) -> void:
	var color: Color = HAIR_COLORS[int(look.hair_color)]
	var dark := color.darkened(0.18)
	var light := color.lightened(0.16)
	var style := int(look.hair)
	var female := int(look.gender) == 1
	var hair := Node3D.new()
	hair.name = "Hair"
	root.add_child(hair)
	# Top of the head: a high cap whose rim leaves the forehead free, plus the
	# back of the head, then a fringe laid on the forehead.
	var cap_scale := Vector3(RX * 2.16, RY * 2.3, RZ * 2.12)
	if not female and style == 4:
		cap_scale = Vector3(RX * 2.07, RY * 2.2, RZ * 2.05)
	if not female and style == 3:
		cap_scale = Vector3(0.34, RY * 2.5, RZ * 2.1)
	_p(hair, MeshKit.hemisphere(), color, Vector3(0, CY + 0.2, -0.03), cap_scale, Vector3(-10, 0, 0))
	if not (not female and style == 3):
		var back := 1.0 if not (not female and style == 4) else 0.55
		_p(hair, MeshKit.sphere(), dark, Vector3(0, CY + 0.02, -0.22), Vector3(RX * 2.12, RY * 1.7 * back + 0.2, RZ * 1.45))
	if not female:
		match style:
			0:
				_fringe(hair, color, light, 0.9, 0.22, 5)
			1:
				_fringe(hair, color, light, 0.95, 0.12, 3)
				for i in 7:
					var a := TAU * float(i) / 7.0
					var tilt := Vector3(sin(a) * 28.0, 0, -cos(a) * 28.0)
					_p(hair, MeshKit.cone(), color if i % 2 == 0 else light, Vector3(cos(a) * 0.32, 1.12, sin(a) * 0.3), Vector3(0.22, 0.46, 0.22), tilt)
				_p(hair, MeshKit.cone(), light, Vector3(0, 1.22, 0), Vector3(0.26, 0.5, 0.26))
			2:
				var a := _face(-0.08, 0.93, 0.02)
				_p(hair, MeshKit.sphere(), light, a, Vector3(0.66, 0.22, 0.2), Vector3(0, 0, -14))
				var b := _face(0.3, 0.9, 0.0)
				_p(hair, MeshKit.sphere(), color, b, Vector3(0.3, 0.18, 0.18), Vector3(0, 0, 12))
			3:
				_p(hair, MeshKit.sphere(), light, Vector3(0, 1.14, 0.1), Vector3(0.28, 0.4, 0.8), Vector3(-10, 0, 0))
			5:
				_fringe(hair, color, light, 0.9, 0.22, 5)
				_p(hair, MeshKit.sphere(), color, Vector3(0, 0.12, -0.4), Vector3(1.2, 1.5, 0.7))
				for side in [-1.0, 1.0]:
					_p(hair, MeshKit.capsule(), dark, Vector3(side * 0.6, 0.18, 0.0), Vector3(0.22, 0.5, 0.3))
			6:
				_p(hair, MeshKit.sphere(), color, Vector3(0, 0.98, -0.05), Vector3(1.26, 0.7, 1.18))
				_p(hair, MeshKit.sphere(), light, Vector3(0, 1.1, 0.0), Vector3(0.9, 0.5, 0.86))
			7:
				var a2 := _face(-0.12, 0.94, 0.04)
				_p(hair, MeshKit.sphere(), light, a2, Vector3(0.85, 0.3, 0.2), Vector3(0, 0, -10))
				var b2 := _face(0.34, 0.8, 0.02)
				_p(hair, MeshKit.sphere(), color, b2, Vector3(0.28, 0.5, 0.18), Vector3(0, 0, 8))
				for side in [-1.0, 1.0]:
					_p(hair, MeshKit.sphere(), dark, Vector3(side * 0.56, 0.5, 0.05), Vector3(0.2, 0.46, 0.34))
			_:
				pass
	else:
		_fringe(hair, color, light, 0.9, 0.24, 5)
		match style:
			0:
				_p(hair, MeshKit.sphere(), color, Vector3(0, 0.22, -0.36), Vector3(1.22, 1.3, 0.7))
				for side in [-1.0, 1.0]:
					_p(hair, MeshKit.capsule(), dark, Vector3(side * 0.58, 0.3, 0.0), Vector3(0.2, 0.36, 0.3))
			1:
				_p(hair, MeshKit.sphere(), dark, Vector3(0, 0.82, -0.62), Vector3(0.3, 0.3, 0.3))
				_p(hair, MeshKit.capsule(), color, Vector3(0, 0.3, -0.7), Vector3(0.28, 0.32, 0.28), Vector3(14, 0, 0))
			2:
				for side in [-1.0, 1.0]:
					_p(hair, MeshKit.sphere(), dark, Vector3(side * 0.62, 0.7, -0.1), Vector3(0.24, 0.24, 0.24))
					_p(hair, MeshKit.capsule(), color, Vector3(side * 0.68, 0.2, -0.1), Vector3(0.22, 0.28, 0.22), Vector3(0, 0, side * -8.0))
			3:
				_p(hair, MeshKit.sphere(), color, Vector3(0, 0.34, -0.28), Vector3(1.28, 0.78, 0.9))
				for side in [-1.0, 1.0]:
					_p(hair, MeshKit.sphere(), dark, Vector3(side * 0.56, 0.32, 0.1), Vector3(0.2, 0.52, 0.38))
			5:
				for side in [-1.0, 1.0]:
					for k in 3:
						_p(hair, MeshKit.sphere(), color if k % 2 == 0 else light, Vector3(side * (0.62 - k * 0.02), 0.5 - k * 0.3, -0.05), Vector3(0.26, 0.3, 0.26))
					_p(hair, MeshKit.torus(), Color("ff6a8a"), Vector3(side * 0.6, -0.32, -0.05), Vector3(0.24, 0.16, 0.24))
			6:
				_p(hair, MeshKit.sphere(), color, Vector3(0, -0.1, -0.4), Vector3(1.3, 1.9, 0.7))
				for side in [-1.0, 1.0]:
					_p(hair, MeshKit.capsule(), light, Vector3(side * 0.6, 0.0, 0.05), Vector3(0.2, 0.7, 0.28))
			7:
				for side in [-1.0, 1.0]:
					_p(hair, MeshKit.sphere(), dark, Vector3(side * 0.5, 0.95, -0.1), Vector3(0.2, 0.2, 0.2))
					_p(hair, MeshKit.capsule(), color, Vector3(side * 0.62, 0.55, -0.12), Vector3(0.24, 0.62, 0.24), Vector3(0, 0, side * -14.0))
					_p(hair, MeshKit.sphere(), light, Vector3(side * 0.7, 0.16, -0.12), Vector3(0.2, 0.2, 0.2))
			_:
				_p(hair, MeshKit.sphere(), color, Vector3(0, 1.22, -0.1), Vector3(0.46, 0.42, 0.46))
				_p(hair, MeshKit.torus(), Color("ff6a8a"), Vector3(0, 1.02, -0.1), Vector3(0.5, 0.3, 0.5))

	_bake_hair(hair)


## Bangs lying on the forehead along an arc.
static func _fringe(hair: Node3D, color: Color, light: Color, y: float, size: float, count: int) -> void:
	for i in count:
		var t := (float(i) / float(maxi(count - 1, 1))) - 0.5
		var x := t * 0.8
		var at := _face(x, y - absf(t) * 0.16, 0.0)
		_p(hair, _hair_lock(), light if i % 3 == 0 else color, at + Vector3(0, 0.085, 0.008), Vector3(size * 1.17, size * 1.23, size * 0.46), Vector3(-8.0, 0, -t * 28.0))


static var _lock_mesh: ArrayMesh


## Rounded roots and a curved tapered tip make the fringe read as sculpted hair.
static func _hair_lock() -> ArrayMesh:
	if _lock_mesh != null:
		return _lock_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const RINGS := 7
	const SIDES := 12
	for ring in RINGS:
		var t := float(ring) / float(RINGS - 1)
		var radius := 0.46 * pow(maxf(1.0 - t, 0.001), 0.6)
		for side in SIDES:
			var angle := TAU * float(side) / float(SIDES)
			st.set_uv(Vector2(float(side) / SIDES, t))
			st.add_vertex(Vector3(cos(angle) * radius + t * t * 0.16, -t, sin(angle) * radius + sin(t * PI) * 0.24))
	for ring in RINGS - 1:
		for side in SIDES:
			var a := ring * SIDES + side
			var b := ring * SIDES + (side + 1) % SIDES
			var c := a + SIDES
			var d := b + SIDES
			for index in [a, c, b, b, c, d]:
				st.add_index(index)
	st.generate_normals()
	_lock_mesh = st.commit()
	return _lock_mesh


## A hairstyle has only a few colours: merge the static clumps by material to
## keep the smoother geometry from multiplying mobile draw calls.
static func _bake_hair(hair: Node3D) -> void:
	var batches: Dictionary = {}
	for child in hair.get_children():
		if not child is MeshInstance3D:
			continue
		var mi := child as MeshInstance3D
		var mat := mi.material_override
		var key := mat.get_instance_id()
		if not batches.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			batches[key] = {"builder": st, "material": mat}
		(batches[key].builder as SurfaceTool).append_from(mi.mesh, 0, mi.transform)
		mi.free()
	for key in batches:
		var mi := MeshInstance3D.new()
		mi.name = "SculptedHair"
		mi.mesh = (batches[key].builder as SurfaceTool).commit()
		mi.material_override = batches[key].material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hair.add_child(mi)
