class_name MartialGeometry
extends RefCounted
## Original, finite sculptures. Each recipe is one surface / one draw; no
## runtime textures, unbounded per-target geometry keys, or external assets.
const KINDS := "blade lance arrow dragon_arrow dragon phoenix wing_left wing_right bow champion sweep cross shock fault sparks wind storm rain fire_rain rune gates shield crest triumph wind_aura valkyrie meteor crater sword_fan bolt"
static var cache: Dictionary = {}

static func warm() -> void:
	for kind in KINDS.split(" "):
		mesh(kind)

static func part(st: SurfaceTool, kind: String, at: Vector3, size: Vector3, angles := Vector3.ZERO, tint := 0.2) -> void:
	var arrays := mesh(kind).surface_get_arrays(0)
	var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray=arrays[Mesh.ARRAY_COLOR]
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
	var transform := Transform3D(Basis.from_euler(angles)*Basis.from_scale(size),at)
	for i in (indices.size() if not indices.is_empty() else points.size()):
		var idx := indices[i] if not indices.is_empty() else i
		st.set_color(Color(lerpf(colors[idx].r,tint,0.15),1,0))
		st.set_uv(Vector2(points[idx].x,points[idx].y))
		st.add_vertex(transform*points[idx])

static func line(st: SurfaceTool, points: Array, width: float, tint := 0.8) -> void:
	EliteSkillArt._line(st,PackedVector3Array(points),width,tint)

static func gem(st: SurfaceTool, at: Vector3, size: Vector3, angles := Vector3.ZERO, tint := 0.2) -> void:
	EliteSkillArt._append(st,SpellSpectacle._crystal_mesh(),at,size,angles,tint)

static func orb(st: SurfaceTool, at: Vector3, size: Vector3, tint := 0.2) -> void:
	EliteSkillArt._append(st,SpellSpectacle._sphere_mesh(),at,size,Vector3.ZERO,tint)

static func ribbon(st: SurfaceTool, radius: float, height: float, start: float, arc: float, width: float, pitch := 0.0) -> void:
	# Broad tapered stroke, bright leading edge, open centre.
	var pts: Array = []
	for i in 41:
		var t := float(i)/40
		var a := start+arc*t
		pts.append(Vector3(sin(a)*radius,height+pitch*t,cos(a)*radius))
		if i==40: break
		var u := float(i+1)/40
		var b := start+arc*u
		var p: Vector3=pts[-1]
		var q := Vector3(sin(b)*radius,height+pitch*u,cos(b)*radius)
		var inner := Vector3(sin(a),0,cos(a))*width*sin(t*PI)
		var next := Vector3(sin(b),0,cos(b))*width*sin(u*PI)
		st.set_color(Color(0.12,1,0))
		SpellSpectacle._tri(st,p,q,q-next)
		SpellSpectacle._tri(st,p,q-next,p-inner)
	line(st,pts,0.014,1.0)

static func feather(st: SurfaceTool, root: Vector3, tip: Vector3, width: float, tint: float) -> void:
	var axis := tip-root
	var side := Vector3(axis.y,-axis.x,0).normalized()*width
	var middle := root+axis*0.55+Vector3(0,0,0.055)
	st.set_color(Color(tint,1,0))
	SpellSpectacle._tri(st,root,middle+side,tip)
	SpellSpectacle._tri(st,root,tip,middle-side)
	line(st,[root,root+axis*0.60+Vector3(0,0,0.06),tip],0.012,0.9)

static func mesh(kind: String) -> ArrayMesh:
	if cache.has(kind): return cache[kind]
	assert(kind in KINDS.split(" "), "Unknown martial geometry")
	if kind=="champion":
		cache[kind]=load("res://assets/vfx/martial/champion.res")
		return cache[kind]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	match kind:
		"blade", "lance", "arrow":
			# Longitudinal axis +Y; recessed dark body, bevels and bright fuller.
			var broad := 0.19 if kind=="blade" else 0.12
			var start := 0.29 if kind=="blade" else 0.63
			var edge: Array[Vector3] = [Vector3(-broad,start,0),Vector3(-broad*0.75,0.84,0),Vector3(0,1.2,0),Vector3(broad*0.75,0.84,0),Vector3(broad,start,0)]
			var ridge := Vector3(0,0.75,0.085)
			for i in 4:
				st.set_color(Color(0.18 if i%2==0 else 0.65,1,0))
				SpellSpectacle._tri(st,edge[i],edge[i+1],ridge)
				SpellSpectacle._tri(st,edge[i+1],edge[i],Vector3(0,0.75,-0.07))
			line(st,[Vector3.ZERO,Vector3(0,start+0.12,0)],0.028,0.35)
			line(st,[Vector3(0,start,0.075),Vector3(0,1.16,0.015)],0.012,1)
			if kind=="blade":
				line(st,[Vector3(-0.35,0.34,0),Vector3(-0.20,0.23,0),Vector3(0,0.28,0),Vector3(0.20,0.23,0),Vector3(0.35,0.34,0)],0.036,0.95)
				gem(st,Vector3(0,0.28,0.10),Vector3(0.07,0.12,0.06),Vector3.ZERO,1)
			elif kind=="lance":
				for s in [-1.0,1.0]:
					feather(st,Vector3(s*0.05,0.63,0),Vector3(s*0.30,0.87,0),0.065,0.7)
			else:
				for s in [-1.0,1.0]:
					feather(st,Vector3(0,0.06,0),Vector3(s*0.15,0.25,0),0.065,0.6)
		"bolt":
			for branch in 4:
				var points: Array=[]
				for i in 13:
					var t := float(i)/12
					points.append(Vector3(sin(i*3.7+branch)*0.15,cos(i*2.9+branch)*0.15,t*2.0))
				line(st,points,0.032 if branch==0 else 0.013,1.0 if branch==0 else 0.05)

		"sword_fan":
			for i in 8:
				var a := (i-3.5)*0.19
				part(st,"blade",Vector3(sin(a)*2.5,0.7+cos(a)*0.4,cos(a)*0.8),Vector3(0.42,1.6,0.42),Vector3(PI/2,0,-a),0.6)

		"wing_left", "wing_right":
			var s := -1.0 if kind=="wing_left" else 1.0
			line(st,[Vector3.ZERO,Vector3(s*0.48,0.34,0),Vector3(s*1.08,0.52,0),Vector3(s*1.75,0.22,0)],0.045,0.9)
			for i in 12:
				var t := float(i)/11
				var root := Vector3(s*(0.18+t*1.2),0.15+sin(t*PI)*0.38,0)
				var tip := root+Vector3(s*(0.24+t*0.20),-0.35-t*0.55,0.02)
				feather(st,root,tip,0.13,0.16+float(i%3)*0.24)
			for i in 7:
				var t := float(i)/6
				feather(st,Vector3(s*(0.15+t),0.25+sin(t*PI)*0.32,0.04),Vector3(s*(0.46+t),-0.12+sin(t*PI)*0.13,0.09),0.09,0.7)
		"phoenix":
			orb(st,Vector3.ZERO,Vector3(0.19,0.37,0.17),0.5)
			line(st,[Vector3(0,0.12,0),Vector3(0,0.42,0),Vector3(0,0.57,0.08)],0.11,0.6)
			gem(st,Vector3(0,0.59,0.2),Vector3(0.1,0.21,0.07),Vector3(PI/2,0,0),1)
			for s in [-1.0,1.0]:
				orb(st,Vector3(s*0.10,0.61,0.12),Vector3.ONE*0.024,1)
				feather(st,Vector3(s*0.04,0.63,0),Vector3(s*0.17,0.98,-0.02),0.05,1)
			for i in 7:
				var f := float(i-3)
				var points: Array=[]
				for j in 17:
					var t := float(j)/16
					points.append(Vector3(f*0.12*t+sin(t*PI)*f*0.06,-0.18-t*(1.45-absf(f)*0.15),sin(t*PI)*0.20))
				line(st,points,0.032,0.2+float(i%3)*0.3)
				feather(st,points[10],points[-1],0.1,0.75)
		"dragon", "dragon_arrow":
			# Serpentine flame dragon. Tapered continuous body, jaw, horns and fins.
			var points: Array=[]
			for i in 25:
				var t := float(i)/24
				points.append(Vector3(sin(t*TAU)*0.18,t*0.14,-1.5+t*2.5))
			for i in 24:
				line(st,[points[i],points[i+1]],0.025+float(i)/24*0.17,0.16)
			orb(st,Vector3(0,0.20,1.12),Vector3(0.23,0.22,0.34),0.15)
			orb(st,Vector3(0,0.09,1.39),Vector3(0.19,0.09,0.23),0.45)
			for s in [-1.0,1.0]:
				gem(st,Vector3(s*0.19,0.41,0.95),Vector3(0.06,0.33,0.055),Vector3(-0.5,0,-s*0.3),0.95)
				orb(st,Vector3(s*0.20,0.24,1.31),Vector3(0.03,0.04,0.07),1)
				line(st,[Vector3(s*0.15,0.13,1.47),Vector3(s*0.38,0.19,1.46),Vector3(s*0.50,0.32,1.16)],0.015,1)
				for i in 5:
					feather(st,Vector3(s*0.12,0.20,0.65-i*0.28),Vector3(s*(0.52-float(i)*0.05),0.53,0.20-i*0.3),0.12,0.65)
			for i in 8:
				gem(st,Vector3(sin(i*0.7)*0.15,0.29,0.8-i*0.23),Vector3(0.06,0.15,0.10),Vector3(-0.4,0,0),0.9)
			if kind=="dragon_arrow": part(st,"arrow",Vector3(0,0,0.8),Vector3(0.9,1,0.9),Vector3(PI/2,0,0),0.9)
		"bow":
			for s in [-1.0,1.0]:
				line(st,[Vector3(0,0,0),Vector3(s*0.20,s*0.48,0),Vector3(s*0.14,s*1.04,0),Vector3(0,s*1.35,0)],0.065,0.85)
				feather(st,Vector3(s*0.18,s*0.45,0),Vector3(s*0.60,s*0.92,0),0.13,0.5)
			line(st,[Vector3(0,-1.35,0),Vector3(0,0,-0.65),Vector3(0,1.35,0)],0.014,1)
			gem(st,Vector3.ZERO,Vector3(0.09,0.18,0.08),Vector3.ZERO,1)
		"champion":
			# Armoured apparition with a readable helm, shoulders, bent arms, sword.
			gem(st,Vector3(0,1.3,0),Vector3(0.46,0.62,0.24),Vector3.ZERO,0.15)
			orb(st,Vector3(0,2,0),Vector3(0.23,0.28,0.21),0.15)
			line(st,[Vector3(-0.17,2.03,0.21),Vector3(0.17,2.03,0.21)],0.024,1)
			feather(st,Vector3(0,2.18,0),Vector3(0,2.64,-0.20),0.15,0.65)
			for s in [-1.0,1.0]:
				gem(st,Vector3(s*0.50,1.62,0),Vector3(0.27,0.24,0.29),Vector3(0,0,s*0.3),0.6)
				line(st,[Vector3(s*0.48,1.45,0),Vector3(s*0.58,1.15,0.24),Vector3(s*0.1,1.10,0.48)],0.12,0.25)
				feather(st,Vector3(s*0.25,1.1,-0.1),Vector3(s*0.55,0.05,-0.35),0.26,0.15)
				line(st,[Vector3(s*0.17,0.9,0),Vector3(s*0.24,0.48,0.06),Vector3(s*0.3,0.04,0.17)],0.11,0.35)
			part(st,"blade",Vector3(0,1.05,0.55),Vector3(1.6,1.9,1.3),Vector3(0.75,0,0),0.55)
		"sweep", "cross", "shock", "wind", "storm":
			if kind=="cross":
				for a in [0.0, PI/2]:
					var f := Vector3(sin(a),0,cos(a))
					line(st,[-f,Vector3.ZERO,f],0.045,1)
					for s in [-1.0,1.0]:
						gem(st,f*s*0.78,Vector3(0.08,0.23,0.035),Vector3(PI/2,a,0),0.9)
			for i in (4 if kind=="storm" else 3 if kind=="wind" else 2):
				ribbon(st,1-float(i)*0.08,float(i)*0.22 if kind in ["wind","storm"] else 0.0,float(i)*2.3,4.7 if kind!="sweep" else 2.7,0.16 if kind!="shock" else 0.05,0.36 if kind in ["wind","storm"] else 0.0)
		"fault", "crater":
			for i in 12:
				var a := TAU*i/12+sin(i*7.3)*0.16
				var r := Vector3(sin(a),0,cos(a))
				var s := Vector3(cos(a),0,-sin(a))
				line(st,[r*0.12,r*0.30+s*0.10,r*0.47-s*0.06,r*0.63+s*0.09,r*(0.75+float(i%4)*0.065)],0.007,0.8)
				line(st,[r*0.47-s*0.06,r*0.56-s*0.18,r*0.69-s*0.24],0.004,0.8)
				if i%2==0: gem(st,r*0.60+Vector3.UP*0.04,Vector3(0.08,0.13,0.07),Vector3(0,a,0.4),0.15)
			if kind=="crater": ribbon(st,0.67,0.01,0,TAU,0.14)
		"sparks":
			for i in 32:
				var a := i*2.39996
				var r := 0.25+float(i%7)*0.105
				gem(st,Vector3(sin(a)*r,float(i%9)/8,cos(a)*r),Vector3(0.012,0.10+float(i%3)*0.03,0.012),Vector3(cos(a)*0.6,0,sin(a)*0.6),0.9)
		"rain", "fire_rain":
			for i in 28:
				var a := i*2.39996
				var r := sqrt((i+0.5)/28.0)*0.97
				var at := Vector3(sin(a)*r,0.12+float(i%4)*0.16,cos(a)*r)
				part(st,"arrow",at,Vector3(0.055,0.18,0.055),Vector3(PI,0,-0.17),0.6)
				line(st,[at,at+Vector3(-0.02,0.22,0)],0.005,0.85)
		"rune", "gates":
			for k in (3 if kind=="gates" else 1):
				var z := float(k)*0.45
				for r in [0.74,0.94,1.0]:
					var pts: Array=[]
					for j in 65:
						var a := TAU*j/64
						pts.append(Vector3(sin(a)*r,cos(a)*r,z))
					line(st,pts,0.009 if r!=1.0 else 0.018,0.8)
				for j in 12:
					var a := TAU*j/12
					var r := Vector3(sin(a),cos(a),0)
					var s := Vector3(cos(a),-sin(a),0)
					var p := r*0.83+Vector3(0,0,z)
					line(st,[p-s*0.04,p+r*0.055,p+s*0.04,p-r*0.055],0.012,1)
		"shield":
			EliteSkillArt._append(st,SkillTableau.shield_mesh(),Vector3.ZERO,Vector3(0.9,1.2,0.25),Vector3.ZERO,0.15)
			# Lion's engraved mane, eyes and muzzle above raised border.
			for i in 12:
				var a := TAU*i/12
				gem(st,Vector3(sin(a)*0.26,0.12+cos(a)*0.28,0.19),Vector3(0.07,0.14,0.045),Vector3(0,0,-a),0.75)
			orb(st,Vector3(0,0.13,0.22),Vector3(0.19,0.22,0.055),0.6)
			for s in [-1.0,1.0]:
				line(st,[Vector3(s*0.035,0.19,0.28),Vector3(s*0.12,0.22,0.28)],0.018,1)
			gem(st,Vector3(0,0.02,0.28),Vector3(0.08,0.12,0.025),Vector3.ZERO,1)
		"crest":
			for s in [-1.0,1.0]:
				for i in 7:
					var a := 0.25+i*0.18
					feather(st,Vector3(s*sin(a)*0.6,cos(a)*0.6,0),Vector3(s*(sin(a)*0.9),cos(a)*0.9,0),0.1,0.85)
			for i in 5:
				gem(st,Vector3((i-2)*0.15,0.66,0),Vector3(0.065,0.23 if i==2 else 0.15,0.035),Vector3.ZERO,0.9)
		"triumph":
			for s in [-1.0,1.0]:
				line(st,[Vector3(s*0.95,0,0),Vector3(s*0.95,2.3,0),Vector3(s*0.65,2.65,0),Vector3(0,2.8,0)],0.06,0.8)
				line(st,[Vector3(s*1.5,0,0.10),Vector3(s*1.5,2.1,0.1)],0.035,0.9)
				for i in 8:
					var x: float = s*(1.5+float(i)/8*0.6)
					var xx: float = s*(1.5+float(i+1)/8*0.6)
					var y := 2.0-sin(float(i)/8*PI)*0.06
					st.set_color(Color(0.1,1,0))
					SpellSpectacle._tri(st,Vector3(x,y,0.1),Vector3(xx,y,0.1),Vector3(xx,y-0.7,0.1))
					SpellSpectacle._tri(st,Vector3(x,y,0.1),Vector3(xx,y-0.7,0.1),Vector3(x,y-0.7,0.1))
			part(st,"crest",Vector3(0,1.9,0),Vector3.ONE*0.7)
		"wind_aura":
			for s in [-1.0,1.0]:
				part(st,"wing_left" if s<0 else "wing_right",Vector3(s*0.35,1.05,0),Vector3.ONE*0.38,Vector3(0,0,-s*0.3),0.6)
				feather(st,Vector3(s*0.2,0.12,0),Vector3(s*0.45,0.48,-0.22),0.08,0.8)
			ribbon(st,0.95,0.15,0,4.6,0.05,0.45)
		"valkyrie":
			for s in [-1.0,1.0]:
				part(st,"wing_left" if s<0 else "wing_right",Vector3(s*0.12,1.4,-0.25),Vector3.ONE*0.7,Vector3(0,s*0.25,s*0.2),0.4)
			part(st,"crest",Vector3(0,2.15,-0.25),Vector3.ONE*0.25)
		"meteor":
			part(st,"arrow",Vector3.ZERO,Vector3(1.3,2.2,1.3),Vector3(PI,0,0),0.75)
			for i in 7:
				var a := TAU*i/7
				feather(st,Vector3(sin(a)*0.20,0.15,cos(a)*0.20),Vector3(sin(a)*0.45,2.7+float(i%3)*0.30,cos(a)*0.45),0.18,0.2+float(i%3)*0.25)
	st.generate_normals()
	var result := st.commit()
	cache[kind]=result
	return result
