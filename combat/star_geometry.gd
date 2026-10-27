class_name StarGeometry
extends RefCounted
## Fixed vocabulary for the twenty-four astral skills. Every recipe is merged
## into one indexed surface; casts share these meshes and never bake particles.
const KINDS := "lion fang crown banners celestial moon reticle sylph constellation drill heart phalanx worldroot prism prison planets genesis rosary seraph chapel sunrise wolf leviathan court sovereign impact streak shards feathers titan_shield shield_ring lyre"
static var cache: Dictionary = {}

static func warm() -> void:
	for kind in KINDS.split(" "):
		mesh(kind)

static func _line(st: SurfaceTool, points: Array, width := 0.02, tint := 0.8) -> void:
	EliteSkillArt._line(st, PackedVector3Array(points), width, tint)

static func _ring(st: SurfaceTool, radius: float, height := 0.0, width := 0.016, tint := 0.9, sides := 48) -> void:
	EliteSkillArt._ring(st, radius, height, width, tint, sides)

static func _gem(st: SurfaceTool, at: Vector3, size: Vector3, rot := Vector3.ZERO, tint := 0.35) -> void:
	EliteSkillArt._append(st, SpellSpectacle._crystal_mesh(), at, size, rot, tint)

static func _orb(st: SurfaceTool, at: Vector3, size: Vector3, tint := 0.3) -> void:
	EliteSkillArt._append(st, SpellSpectacle._sphere_mesh(), at, size, Vector3.ZERO, tint)

static func _part(st: SurfaceTool, kind: String, at: Vector3, size: Vector3, rot := Vector3.ZERO, tint := 0.5) -> void:
	EliteSkillArt._append(st, MartialGeometry.mesh(kind), at, size, rot, tint)

static func _arc(st: SurfaceTool, radius: float, start: float, arc: float, height := 0.0, width := 0.024, tint := 0.9) -> void:
	var points: Array = []
	for i in 33:
		var angle := start + arc * float(i) / 32.0
		points.append(Vector3(sin(angle)*radius,height,cos(angle)*radius))
	_line(st,points,width,tint)

static func _seal(st: SurfaceTool, rays: int, radius := 1.0) -> void:
	_ring(st,radius,0,0.015,0.85)
	_ring(st,radius*0.90,0,0.006,0.5)
	_ring(st,radius*0.64,0,0.012,1.0)
	for i in rays:
		var a := TAU * float(i)/rays
		var radial := Vector3(sin(a),0,cos(a))
		var side := Vector3(cos(a),0,-sin(a))
		var p := radial*radius*0.77
		_line(st,[p-side*0.035,p+radial*0.06,p+side*0.035,p-radial*0.06,p-side*0.035],0.009,0.95)
		_line(st,[radial*radius*0.65,radial*radius*0.52,radial*radius*0.44+side*0.06],0.01,0.75)

static func _fairy(st: SurfaceTool, at: Vector3, size := 1.0) -> void:
	_gem(st,at,Vector3(0.06,0.14,0.06)*size,Vector3.ZERO,1.0)
	for side in [-1.0,1.0]:
		MartialGeometry.feather(st,at,at+Vector3(side*0.26,0.12,0)*size,0.11*size,0.65)
		MartialGeometry.feather(st,at,at+Vector3(side*0.20,-0.13,0)*size,0.06*size,0.95)

static func _wolf(st: SurfaceTool, royal := false) -> void:
	# Original quadruped silhouette: shoulder, haunches, muzzle, pricked ears,
	# bent legs and flowing tail. Royal uses its own crown and shoulder spines.
	_orb(st,Vector3(0,0.70,0),Vector3(0.29,0.31,0.60),0.23)
	_orb(st,Vector3(0,0.83,0.48),Vector3(0.32,0.38,0.35),0.4)
	_orb(st,Vector3(0,1.09,0.75),Vector3(0.24,0.25,0.30),0.35)
	_gem(st,Vector3(0,1.02,1.07),Vector3(0.15,0.28,0.15),Vector3(PI/2,0,0),0.8)
	for s in [-1.0,1.0]:
		_gem(st,Vector3(s*0.16,1.36,0.68),Vector3(0.10,0.27,0.12),Vector3(0,0,-s*0.17),0.7)
		_orb(st,Vector3(s*0.18,1.15,0.93),Vector3.ONE*0.041,1.0)
		for z in [-0.4,0.4]:
			_line(st,[Vector3(s*0.22,0.72,z),Vector3(s*0.26,0.35,z+0.10),Vector3(s*0.24,0.07,z+0.18)],0.095,0.4)
			_orb(st,Vector3(s*0.24,0.06,z+0.23),Vector3(0.12,0.08,0.17),0.7)
		for i in 3:
			_gem(st,Vector3(s*(0.25+i*0.055),0.9-i*0.08,0.4-i*0.15),Vector3(0.075,0.28,0.06),Vector3(0.5,0,s*0.5),0.5)
	_line(st,[Vector3(0,0.75,-0.45),Vector3(0.12,0.88,-0.80),Vector3(0.24,1.16,-1.11),Vector3(0.15,1.33,-1.31)],0.14,0.25)
	_line(st,[Vector3(0,0.87,-0.42),Vector3(0.13,1.00,-0.8),Vector3(0.22,1.2,-1.13)],0.025,1.0)
	if royal:
		for i in 5:
			var a := TAU*i/5.0
			_gem(st,Vector3(sin(a)*0.27,1.60,0.76+cos(a)*0.21),Vector3(0.06,0.27 if i%2==0 else 0.18,0.06),Vector3.ZERO,1)

static func mesh(kind: String) -> ArrayMesh:
	if cache.has(kind): return cache[kind]
	assert(kind in KINDS.split(" "),"Unknown star geometry: "+kind)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	match kind:
		"lion":
			# Raised lion mask, its mane is a corona of bevelled flame facets.
			_orb(st,Vector3(0,0.08,0),Vector3(0.46,0.44,0.28),0.2)
			for i in 16:
				var a := TAU*i/16.0
				_gem(st,Vector3(sin(a)*0.55,cos(a)*0.55,0),Vector3(0.17,0.36,0.11),Vector3(0,0,-a),0.35+float(i%3)*0.2)
			for s in [-1.0,1.0]:
				_gem(st,Vector3(s*0.25,0.16,0.23),Vector3(0.19,0.07,0.055),Vector3(0,0,-s*0.2),1)
				_orb(st,Vector3(s*0.14,-0.20,0.26),Vector3(0.19,0.14,0.12),0.65)
				_gem(st,Vector3(s*0.22,-0.35,0.28),Vector3(0.055,0.18,0.065),Vector3(0,0,s*0.2),1)
			_gem(st,Vector3(0,-0.05,0.37),Vector3(0.14,0.12,0.08),Vector3.ZERO,0.8)
		"fang":
			for i in 3:
				MartialGeometry.ribbon(st,0.65+0.17*i,0.12*i,-1.15,2.3,0.15,0.08)
			for side in [-1.0,1.0]:
				_gem(st,Vector3(side*0.70,0.10,0.3),Vector3(0.08,0.4,0.09),Vector3(PI/2,0,side*0.7),1)
		"crown":
			_arc(st,0.56,0,PI*0.92,0,0.038)
			_arc(st,0.56,PI+0.16,PI*0.89,0,0.038)
			for i in 7:
				var a := TAU*i/7.0
				var p := Vector3(sin(a)*0.56,0,cos(a)*0.56)
				_gem(st,p+Vector3.UP*(0.20 if i%2==0 else 0.10),Vector3(0.10,0.43 if i%2==0 else 0.25,0.10),Vector3(0,0,-0.2*sin(a)),0.9)
			_line(st,[Vector3(-0.12,0.55,0.52),Vector3(0.05,0.34,0.57),Vector3(-0.02,0.10,0.61),Vector3(0.18,-0.14,0.55)],0.035,1)
		"banners":
			for side in [-1.0,1.0]:
				_line(st,[Vector3(side*0.75,0,0),Vector3(side*0.75,2.0,0)],0.042,1)
				_gem(st,Vector3(side*0.75,2.12,0),Vector3(0.12,0.28,0.1),Vector3.ZERO,1)
				MartialGeometry.feather(st,Vector3(side*0.75,1.83,0),Vector3(side*1.32,0.73,0.10),0.30,0.30)
				_line(st,[Vector3(side*0.79,1.70,0.02),Vector3(side*1.12,1.49,0.08),Vector3(side*1.14,1.05,0.10)],0.017,1)
			_part(st,"shield",Vector3(0,0.90,0.18),Vector3.ONE*0.9)
		"lyre":
			# A celestial bandstand: three lyres of light standing round a staff ring, a ten-ray seal inside.
			for i in 3:
				var a := TAU*float(i)/3.0
				var at := Vector3(sin(a),0,cos(a))*0.75
				var side := Vector3(cos(a),0,-sin(a))
				for s in [-1.0,1.0]:
					_line(st,[at+side*s*0.07,at+side*s*0.16+Vector3.UP*0.22,at+side*s*0.15+Vector3.UP*0.44,at+side*s*0.10+Vector3.UP*0.56,at+side*s*0.15+Vector3.UP*0.62],0.018,0.9)
				_line(st,[at-side*0.13+Vector3.UP*0.52,at+side*0.13+Vector3.UP*0.52],0.014,1.0)
				for k in 5:
					var x := (float(k)-2.0)*0.035
					_line(st,[at+side*x+Vector3.UP*0.04,at+side*x+Vector3.UP*0.52],0.004,0.6)
				_orb(st,at+Vector3.UP*0.03,Vector3(0.22,0.06,0.08),0.8)
			for j in 5:
				_ring(st,0.9+0.025*float(j),0.0,0.005,0.5+0.1*float(j))
			_seal(st,10,0.55)
		"celestial":
			_seal(st,20)
			_ring(st,1.16,0,0.022,1)
			for i in 10:
				var a := TAU*i/10.0
				var p := Vector3(sin(a),0,cos(a))
				_line(st,[p*0.30,p*0.48,p.rotated(Vector3.UP,0.10)*0.41,p*0.48,p.rotated(Vector3.UP,-0.10)*0.41],0.013,1)
				_gem(st,p*1.14,Vector3(0.035,0.12,0.035),Vector3(0,a,PI/2),1)
		"moon":
			_arc(st,0.80,0.30,TAU-0.6,0,0.07,0.5)
			_arc(st,0.67,0.43,TAU-0.86,0,0.025,1)
			for i in 5:
				var a := 0.9+i*1.0
				_gem(st,Vector3(sin(a)*0.92,0,cos(a)*0.92),Vector3.ONE*(0.05 if i%2==0 else 0.035),Vector3.ZERO,1)
		"reticle":
			for i in 4:
				var a := PI/2*i
				_arc(st,0.68,a+0.13,0.70,0,0.025)
				var p := Vector3(sin(a),0,cos(a))
				_line(st,[p*0.82,p*0.5,p*0.57+p.cross(Vector3.UP)*0.09],0.022,1)
			_gem(st,Vector3.ZERO,Vector3(0.07,0.04,0.07),Vector3.ZERO,1)
		"sylph", "court":
			var count := 3 if kind=="court" else 2
			for i in count:
				var a := TAU*i/count
				_fairy(st,Vector3(sin(a)*0.75,0.30+0.12*i,cos(a)*0.75),1.0 if kind=="court" else 0.85)
				MartialGeometry.ribbon(st,0.73,0.25,-0.7+a,1.3,0.065,0.2)
			if kind=="court": _seal(st,9,0.70)
		"constellation":
			var points: Array=[Vector3(-0.72,0,0.25),Vector3(-0.35,0,-0.48),Vector3(0.12,0,-0.85),Vector3(0.55,0,-0.28),Vector3(0.76,0,0.48),Vector3(0.18,0,0.17),Vector3(-0.20,0,0.80)]
			_line(st,points,0.014,0.6)
			_line(st,[points[1],points[5],points[3]],0.014,0.6)
			for p in points:
				_gem(st,p,Vector3(0.07,0.12,0.07),Vector3.ZERO,1)
			_arc(st,1.0,0.05,TAU-0.25,0,0.01,0.45)
		"drill":
			for arm in 3:
				var points: Array=[]
				for i in 41:
					var t := float(i)/40
					var a := t*TAU*2+arm*TAU/3
					points.append(Vector3(sin(a)*0.35*(1-t),cos(a)*0.35*(1-t),t*2.4))
				_line(st,points,0.026,0.45+0.23*arm)
			_part(st,"lance",Vector3.ZERO,Vector3(0.60,2.0,0.60),Vector3(PI/2,0,0),0.95)
		"heart":
			for i in 5:
				var a := TAU*i/5.0
				var p := Vector3(sin(a),0,cos(a))
				_line(st,[p*0.84,p*0.54,p*0.60+p.cross(Vector3.UP)*0.09],0.032,0.75)
			_seal(st,5,0.40)
			_gem(st,Vector3.ZERO,Vector3(0.10,0.10,0.10),Vector3.ZERO,1)
		"phalanx":
			for i in 5:
				var a := (i-2)*0.46
				var p := Vector3(sin(a)*1.2,0.5,cos(a)*0.9)
				var hex: Array=[]
				for j in 7:
					var b := TAU*j/6.0
					hex.append(p+Vector3(sin(b)*0.36,cos(b)*0.48,0))
				_line(st,hex,0.030,0.85)
				_gem(st,p,Vector3(0.08,0.13,0.06),Vector3.ZERO,1)
				_part(st,"lance",p+Vector3(-0.2,-0.5,-0.1),Vector3(0.30,1.10,0.30),Vector3(0,0,-0.12),0.35)
		"worldroot":
			for i in 7:
				var a := TAU*i/7.0
				var p := Vector3(sin(a),0,cos(a))
				var s := p.cross(Vector3.UP)
				_line(st,[Vector3.ZERO,p*0.30+s*0.08,p*0.55-s*0.10,p*0.80+s*0.06,p*1.12],0.03,1)
				for j in 2:
					var pos := p*(0.45+j*0.38)
					_part(st,"lance",pos,Vector3(0.60,0.9+j*0.5,0.60),Vector3(p.z*0.18,0,-p.x*0.18),0.3+j*0.35)
		"prism":
			_gem(st,Vector3.ZERO,Vector3(0.55,0.80,0.55),Vector3.ZERO,0.3)
			for i in 3:
				var a := TAU*i/3.0
				var p := Vector3(sin(a)*0.8,0,cos(a)*0.8)
				_gem(st,p,Vector3(0.14,0.35,0.14),Vector3(0,0,a),0.95)
				_line(st,[Vector3(0,0.6,0),p,Vector3(0,-0.6,0)],0.023,0.8)
		"prison":
			_seal(st,6)
			for i in 6:
				var a := TAU*i/6.0
				_gem(st,Vector3(sin(a)*0.85,0.65,cos(a)*0.85),Vector3(0.21,1.6,0.17),Vector3(0.22*cos(a),0,-0.22*sin(a)),0.28+float(i%3)*0.27)
				_line(st,[Vector3(sin(a)*0.84,0.05,cos(a)*0.84),Vector3(sin(a)*0.68,1.40,cos(a)*0.68)],0.024,1)
		"planets", "genesis":
			var ultimate := kind=="genesis"
			_orb(st,Vector3.ZERO,Vector3.ONE*(0.34 if ultimate else 0.22),0.8)
			for i in 4:
				var a := TAU*i/4.0+0.3
				var p := Vector3(sin(a)*0.85,sin(a*2)*0.22,cos(a)*0.85)
				_gem(st,p,Vector3.ONE*(0.22 if ultimate else 0.16),Vector3(0,a,a),float(i)/3)
				var orbit: Array=[]
				for j in 33:
					var b := TAU*j/32.0
					orbit.append(Vector3(sin(b),sin(b+a)*0.48,cos(b))*0.87)
				_line(st,orbit,0.012 if ultimate else 0.009,0.35+0.2*i)
			if ultimate:
				for i in 12:
					var a := TAU*i/12.0
					_gem(st,Vector3(sin(a)*1.08,0,cos(a)*1.08),Vector3(0.04,0.19,0.04),Vector3(0,0,PI/2),0.9)
		"rosary":
			for i in 16:
				var t := float(i)/15
				var p := Vector3(sin(t*PI*3)*0.14,cos(t*PI*2)*0.10,t*2.0)
				_orb(st,p,Vector3.ONE*0.048,0.9)
				if i>0:
					var u := float(i-1)/15
					_line(st,[Vector3(sin(u*PI*3)*0.14,cos(u*PI*2)*0.10,u*2),p],0.012,0.4)
		"seraph":
			for s in [-1.0,1.0]:
				for i in 3:
					_part(st,"wing_left" if s<0 else "wing_right",Vector3(0,0.20-i*0.27,0),Vector3.ONE*(1.0-i*0.16),Vector3(0,0,s*(0.35-i*0.43)),0.4+i*0.25)
			_gem(st,Vector3(0,0.15,0.05),Vector3(0.16,0.35,0.10),Vector3.ZERO,1)
		"chapel":
			_seal(st,12)
			for i in 6:
				var a := TAU*i/6.0
				var p := Vector3(sin(a)*0.84,0,cos(a)*0.84)
				_line(st,[p,p+Vector3.UP*1.1],0.025,0.85)
				var next := Vector3(sin(a+TAU/6)*0.84,0,cos(a+TAU/6)*0.84)
				_line(st,[p+Vector3.UP*0.72,p.lerp(next,0.5)+Vector3.UP*1.35,next+Vector3.UP*0.72],0.023,0.65)
		"sunrise":
			_seal(st,16)
			_ring(st,0.42,0,0.055,1)
			for i in 16:
				var a := TAU*i/16.0
				var p := Vector3(sin(a),0,cos(a))
				_line(st,[p*0.47,p*(0.82 if i%2==0 else 0.66)],0.02 if i%2==0 else 0.012,1)
		"wolf": _wolf(st)
		"leviathan":
			for i in 24:
				var t := float(i)/23
				var p := Vector3(sin(t*TAU)*0.24,sin(t*PI)*0.45,-1.5+t*3.0)
				_orb(st,p,Vector3.ONE*(0.055+t*0.20),0.3)
				if i%3==0:
					_gem(st,p+Vector3.UP*0.18,Vector3(0.035,0.25,0.18),Vector3(0.3,0,0),0.7)
			_orb(st,Vector3(0,0.10,1.43),Vector3(0.3,0.23,0.43),0.45)
			for s in [-1.0,1.0]:
				MartialGeometry.feather(st,Vector3(s*0.15,0.05,1.30),Vector3(s*0.85,0.35,0.65),0.26,0.6)
				_orb(st,Vector3(s*0.22,0.23,1.63),Vector3.ONE*0.045,1)
				_line(st,[Vector3(s*0.18,0.27,1.3),Vector3(s*0.36,0.62,1.00),Vector3(s*0.30,0.8,0.78)],0.045,1)
			for i in 3: MartialGeometry.ribbon(st,0.85+0.22*i,-0.20,0.2,TAU*0.8,0.09,0.16)
		"sovereign":
			_wolf(st,true)
			for side in [-1.0,1.0]:
				_part(st,"wing_left" if side<0 else "wing_right",Vector3(side*0.10,1.1,-0.20),Vector3.ONE*0.9,Vector3(0.3,side*0.55,side*0.35),0.28)
			_line(st,[Vector3(-0.23,0.9,0.57),Vector3(0,1.18,0.61),Vector3(0.23,0.9,0.57)],0.045,1)
		"impact":
			for i in 12:
				var a := TAU*i/12.0
				var p := Vector3(sin(a),0,cos(a))
				_line(st,[p*0.34,p*(0.76 if i%2==0 else 0.60)],0.018,0.9)
			_arc(st,0.80,0.05,PI*0.84,0,0.026,1)
			_arc(st,0.80,PI+0.05,PI*0.84,0,0.026,1)
		"streak":
			for i in 3:
				var x := (i-1)*0.07
				_line(st,[Vector3(x,0,-1.6),Vector3(x*0.4,0,-0.6),Vector3.ZERO],0.02 if i==1 else 0.007,1 if i==1 else 0.35)
		"shards":
			for i in 18:
				var a := float(i)*2.399963
				var r := 0.25+float(i%5)*0.16
				_gem(st,Vector3(sin(a)*r,0.05+float(i%4)*0.21,cos(a)*r),Vector3(0.025,0.09+float(i%3)*0.02,0.025),Vector3(sin(a)*0.6,0,cos(a)*0.6),0.2+float(i%4)*0.25)
		"titan_shield":
			# The colossal heater of the Defender's star skills: the great shield with a spiked rim, flanges and a sun boss.
			EliteSkillArt._append(st,EliteSkillArt.geometry("greatshield"),Vector3.ZERO,Vector3.ONE,Vector3.ZERO,0.25)
			for i in 10:
				var a := -1.1+2.2*float(i)/9.0
				_gem(st,Vector3(sin(a)*0.98,cos(a)*0.98,0.1),Vector3(0.09,0.24,0.06),Vector3(0,0,-a),0.9)
			for s in [-1.0,1.0]:
				MartialGeometry.feather(st,Vector3(s*0.7,0.45,0.05),Vector3(s*1.35,0.9,0.0),0.16,0.6)
				MartialGeometry.feather(st,Vector3(s*0.75,0.2,0.05),Vector3(s*1.2,0.35,0.0),0.11,0.35)
			_orb(st,Vector3(0,0.1,0.27),Vector3(0.26,0.26,0.1),0.95)
			_gem(st,Vector3(0,1.18,0.05),Vector3(0.12,0.32,0.08),Vector3.ZERO,1)
		"shield_ring":
			# Twelve small shields facing out around a seal: the ward of the shield wall.
			_seal(st,16,0.9)
			_ring(st,1.12,0,0.02,1)
			for i in 12:
				var a := TAU*i/12.0
				EliteSkillArt._append(st,EliteSkillArt.geometry("greatshield"),Vector3(sin(a),0.28,cos(a))*Vector3(1.02,1,1.02),Vector3(0.22,0.26,0.2),Vector3(0,a,0),0.35+float(i%2)*0.4)
		"feathers":
			for i in 12:
				var a := float(i)*2.399963
				var p := Vector3(sin(a)*(0.3+float(i%3)*0.25),float(i%4)*0.25,cos(a)*(0.3+float(i%3)*0.25))
				MartialGeometry.feather(st,p,p+Vector3(sin(a)*0.20,0.22,cos(a)*0.05),0.06,0.5+float(i%3)*0.24)
	st.generate_normals()
	st.index()
	cache[kind] = st.commit()
	return cache[kind]
