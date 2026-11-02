class_name GodSkillArt
extends RefCounted
## God-tier (300-star) presentation. Cosmetic ONLY: StarSkillSequence owns every
## contact, this only dresses the wind-up and the five beats it already plays.
## Built from the star art blocks (StarSkillArt roots with their one clock, shader
## and 2/4/6 layer cap; StarGeometry, MartialGeometry and EliteSkillArt meshes):
## a god_halo sigil and a pantheon of pillars on the ground, the class's emblem in
## the sky and an aureole behind the caster. A cast is a few finite roots: extra
## roots are dropped at low quality and while MemoryGuard reports pressure, and
## every layer is a VfxBudget decoration, so a phone never pays for the spectacle.
const SKY := 9.5
const GOLDEN := 2.39996


static func handles(skill: Dictionary) -> bool:
	return StarSkillData.is_god(skill) and StarSkillArt.handles(skill)


## How many roots beyond the main one this beat may open.
static func extra_roots(want: int) -> int:
	if MemoryGuard.pressure > 0 or not VfxBudget.can_decorate(4): return 0
	return mini(want, [1, 1, 2][VfxBudget.quality()])


static func _extra(parent: Node3D, point: Vector3, seconds: float, label: String, source: Vector3, owner: StarSkillArt) -> StarSkillArt:
	var art := StarSkillArt._root(parent, point, seconds, label)
	if not art: return null
	StarSkillArt._face(art, source, point)
	if owner and owner.generation_ref:
		art.generation_ref = owner.generation_ref
		art.generation = owner.generation
	return art


## Adds a StarGeometry / "martial/" kind, or an EliteSkillArt mesh with "elite/".
static func _put(art: StarSkillArt, kind: String, c: Dictionary, at: Vector3, size: Vector3, angles := Vector3.ZERO, seconds := 1.0, style := {}) -> void:
	if not art: return
	if kind.begins_with("elite/"):
		var name := kind.trim_prefix("elite/")
		art.add_mesh(EliteSkillArt.geometry(name), "Elite_" + name, c, at, size, angles, seconds, style)
	else:
		art.add(kind, c, at, size, angles, seconds, style)


## A blade-like mesh (+Y along its length) hung point-down so its tip sits at
## tip_y; returns [position, scale].
static func _point_down(mesh: Mesh, length: float, tip_y: float) -> Array:
	var bounds := mesh.get_aabb()
	var size := length / maxf(0.1, bounds.size.y)
	return [Vector3(0, tip_y + bounds.end.y * size, 0), Vector3.ONE * size]


## A falling blade: the mesh drops point-first from height onto spot in [param flight] s.
static func _drop(art: StarSkillArt, mesh: Mesh, label: String, c: Dictionary, spot: Vector3, length: float, height: float, flight: float, yaw := 0.0, delay := 0.0) -> void:
	var pose := _point_down(mesh, length, 0.0)
	art.add_mesh(mesh, label, c, spot + pose[0] + Vector3.UP * height, pose[1], Vector3(PI, yaw, 0), flight, {"initial": 1.0, "travel": Vector3.DOWN * height, "accelerate": true, "grow_time": 0.01, "fade_in": 0.015, "decay": 0.96, "front": true, "delay": delay})


## The same blade planted in the ground after its fall, sunk by [param sink].
static func _planted(art: StarSkillArt, mesh: Mesh, label: String, c: Dictionary, spot: Vector3, length: float, seconds: float, delay: float, sink := 0.6) -> void:
	var pose := _point_down(mesh, length, -sink)
	art.add_mesh(mesh, label, c, spot + pose[0], pose[1], Vector3(PI, 0, 0), seconds, {"initial": 1.0, "grow_time": 0.01, "fade_in": 0.01, "decay": 0.7, "front": true, "delay": delay})


static func _spot(index: int, radius: float) -> Vector3:
	var a := float(index) * GOLDEN + 0.5
	return Vector3(sin(a), 0, cos(a)) * radius * (0.32 + 0.1 * float(index % 3))


# ---------------------------------------------------------------------------
# Wind-up: the main root (on the caster, facing the target) receives the
# aureole; the ground root raises the sigil and the pantheon, the sky root
# forms the class emblem over the target.
# ---------------------------------------------------------------------------
static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> void:
	var id := String(skill.id)
	var c := StarSkillArt.look(skill)
	var r := clampf(float(skill.get("radius", 9.0)), 4.0, 10.0)
	var spectral := 1.0 if id == "astral_apocalypse" else 0.0
	var grow := {"initial": 0.06, "grow_time": 0.9, "fade_in": 0.12, "decay": 0.97, "opacity": 0.8, "spectral": spectral}
	if id == "pantheon_bastion": StarSkillArt._recent_shield = StarSkillArt.equipped_sword(caster)
	if id == "death_gods_eclipse": StarSkillArt._recent_dagger = StarSkillArt.equipped_sword(caster)
	# The caster: a divine aureole behind the shoulders and a seal at the feet.
	_put(art, "aureole", c, Vector3(0, 2.3, -0.55), Vector3.ONE * 1.25, Vector3.ZERO, time, {"initial": 0.2, "grow_time": 0.5, "fade_in": 0.1, "decay": 0.98, "face_camera": true, "spin": 0.0, "pulse": true, "spectral": spectral})
	_put(art, "celestial", c, Vector3.UP * 0.07, Vector3.ONE * 2.4, Vector3.ZERO, time, {"initial": 0.3, "grow_time": 0.6, "spin": 0.5, "decay": 0.97, "spectral": spectral})
	match id:
		"divine_edict": _put(art, "lion", c, Vector3(0, 3.4, -0.2), Vector3.ONE * 1.0, Vector3.ZERO, time, grow)
		"sunfall_volley": _put(art, "martial/bow", c, Vector3(0, 1.7, 0.5), Vector3.ONE * 1.3, Vector3.ZERO, time, grow)
		"heavenrend_spear": _put(art, "elite/spears", c, Vector3.UP * 0.05, Vector3(2.2, 2.6, 2.2), Vector3.ZERO, time, grow)
		"astral_apocalypse": _put(art, "planets", c, Vector3(0, 3.3, 0), Vector3.ONE * 1.1, Vector3.ZERO, time, grow.merged({"spin": 1.2}, true))
		"seraphic_judgment": _put(art, "feathers", c, Vector3.UP * 0.2, Vector3(1.8, 3.0, 1.8), Vector3.ZERO, time, {"travel": Vector3.UP * 1.5, "decay": 0.9, "initial": 0.7})
		"celestial_dragon_emperor": _put(art, "sylph", c, Vector3(0, 2.6, 0), Vector3.ONE * 1.3, Vector3.ZERO, time, grow.merged({"spin": 1.0}, true))
		"pantheon_bastion": _put(art, "shield_ring", c, Vector3.UP * 0.1, Vector3.ONE * 2.0, Vector3.ZERO, time, grow.merged({"spin": 0.3}, true))
		"death_gods_eclipse": _put(art, "moon", c, Vector3(0, 3.0, -0.3), Vector3.ONE * 1.1, Vector3(PI / 2, 0, 0), time, grow)
		"abyssal_throne": _put(art, "elite/banners", c, Vector3.UP * 0.05, Vector3(2.2, 2.4, 2.2), Vector3.ZERO, time, grow)
		"divine_symphony": _put(art, "lyre", c, Vector3.UP * 0.1, Vector3.ONE * 1.6, Vector3.ZERO, time, grow.merged({"spin": 0.4}, true))
	var origin := caster.global_position
	var parent := art.get_parent() as Node3D
	var ground := _extra(parent, Vector3(point.x, 0, point.z), time, "StarGodGround_" + id, origin, art)
	if ground:
		_put(ground, "god_halo", c, Vector3.UP * 0.06, Vector3.ONE * r, Vector3.ZERO, time, grow.merged({"spin": 0.28}, true))
		match id:
			"divine_edict": _put(ground, "martial/sword_fan", c, Vector3.ZERO, Vector3.ONE * r * 0.35, Vector3.ZERO, time, grow.merged({"spin": 0.6}, true))
			"sunfall_volley": _put(ground, "reticle", c, Vector3.UP * 0.1, Vector3.ONE * r * 0.6, Vector3.ZERO, time, grow.merged({"spin": -0.7}, true))
			"heavenrend_spear": _put(ground, "martial/fault", c, Vector3.UP * 0.03, Vector3.ONE * r, Vector3.ZERO, time, grow)
			"astral_apocalypse": _put(ground, "elite/astrolabe", c, Vector3.UP * 0.1, Vector3.ONE * r * 0.8, Vector3.ZERO, time, grow.merged({"spin": -0.5}, true))
			"seraphic_judgment": _put(ground, "elite/cathedral", c, Vector3.ZERO, Vector3(r * 0.7, 3.2, r * 0.7), Vector3.ZERO, time, grow)
			"celestial_dragon_emperor": _put(ground, "court", c, Vector3.UP * 0.1, Vector3.ONE * r * 0.6, Vector3.ZERO, time, grow.merged({"spin": 0.5}, true))
			"pantheon_bastion": _put(ground, "elite/rampart", c, Vector3.ZERO, Vector3(r * 0.8, 2.6, r * 0.8), Vector3.ZERO, time, grow)
			"death_gods_eclipse": _put(ground, "fang", c, Vector3.UP * 0.1, Vector3(r * 0.7, 1.4, r * 0.7), Vector3.ZERO, time, grow.merged({"spin": 0.9}, true))
			"abyssal_throne": _put(ground, "worldroot", c, Vector3.ZERO, Vector3(r * 0.8, 2.4, r * 0.8), Vector3.ZERO, time, grow)
			"divine_symphony": _put(ground, "elite/stave", c, Vector3.UP * 0.2, Vector3(r * 0.85, 3.0, r * 0.85), Vector3.ZERO, time, grow.merged({"spin": 0.5}, true))
		ground._draw()
	if extra_roots(1) < 1: return
	var sky := _extra(parent, Vector3(point.x, 0, point.z), time, "StarGodSky_" + id, origin, art)
	if not sky: return
	var high := {"initial": 0.2, "grow_time": 0.85, "fade_in": 0.12, "decay": 0.98, "spectral": spectral}
	_put(sky, "god_halo", c, Vector3.UP * (SKY + 0.6), Vector3.ONE * r * 0.55, Vector3.ZERO, time, high.merged({"spin": -0.35, "opacity": 0.75}, true))
	match id:
		"divine_edict":
			var sword := MartialGeometry.mesh("blade")
			var pose := _point_down(sword, 7.0, SKY - 2.0)
			sky.add_mesh(sword, "GodSword", c, pose[0], pose[1], Vector3(PI, 0, 0), time, high.merged({"spin": 0.5, "front": true}, true))
		"sunfall_volley":
			_put(sky, "sunrise", c, Vector3.UP * SKY, Vector3.ONE * r * 0.7, Vector3.ZERO, time, high.merged({"spin": 0.5}, true))
			_put(sky, "aureole", c, Vector3.UP * (SKY - 1.0), Vector3.ONE * 2.6, Vector3.ZERO, time, high.merged({"face_camera": true}, true))
		"heavenrend_spear":
			var lance := MartialGeometry.mesh("lance")
			var pose := _point_down(lance, 8.0, SKY - 3.5)
			sky.add_mesh(lance, "GodLance", c, pose[0], pose[1] * Vector3(1.6, 1, 1.6), Vector3(PI, 0, 0), time, high.merged({"spin": 2.0, "front": true}, true))
			_put(sky, "martial/bolt", c, Vector3.ZERO, Vector3(2.4, 2.4, SKY * 0.5), Vector3(-PI / 2, 0, 0), time, high.merged({"spin": 3.0, "opacity": 0.7}, true))
		"astral_apocalypse":
			_put(sky, "elite/astrolabe", c, Vector3.UP * SKY, Vector3.ONE * r * 0.7, Vector3(0.35, 0, 0.2), time, high.merged({"spin": 0.6}, true))
			_put(sky, "genesis", c, Vector3.UP * SKY, Vector3.ONE * 2.2, Vector3.ZERO, time, high.merged({"spin": 1.3}, true))
		"seraphic_judgment":
			_put(sky, "seraph", c, Vector3.UP * (SKY - 1.5), Vector3.ONE * 3.4, Vector3.ZERO, time, high.merged({"flap": 0.06, "flap_rate": 3.0}, true))
			_put(sky, "sunrise", c, Vector3.UP * SKY, Vector3.ONE * r * 0.6, Vector3.ZERO, time, high.merged({"spin": 0.3}, true))
		"celestial_dragon_emperor":
			_put(sky, "martial/dragon", c, Vector3.UP * (SKY - 2.0), Vector3.ONE * 3.0, Vector3(0, PI / 2, 0), time, high.merged({"orbit": r * 0.45, "orbit_speed": 1.7, "spin": 1.7}, true))
			_put(sky, "court", c, Vector3.UP * SKY, Vector3.ONE * r * 0.45, Vector3.ZERO, time, high.merged({"spin": 0.6}, true))
		"pantheon_bastion":
			_put(sky, "titan_shield", c, Vector3.UP * (SKY - 1.0), Vector3.ONE * 4.0, Vector3(PI / 2, 0, 0), time, high.merged({"spin": 0.4, "front": true}, true))
			_put(sky, "elite/aegis", c, Vector3.ZERO, Vector3.ONE * r * 0.95, Vector3.ZERO, time, high.merged({"opacity": 0.4, "spin": 0.15}, true))
		"death_gods_eclipse":
			_put(sky, "moon", c, Vector3.UP * (SKY - 2.0), Vector3.ONE * r * 0.55, Vector3(PI / 2, 0, 0), time, high.merged({"spin": 0.0}, true))
			_put(sky, "constellation", c, Vector3.UP * SKY, Vector3.ONE * r * 0.7, Vector3.ZERO, time, high.merged({"spin": -0.3}, true))
		"abyssal_throne":
			_put(sky, "crown", c, Vector3.UP * (SKY - 1.0), Vector3.ONE * r * 0.5, Vector3.ZERO, time, high.merged({"spin": 0.35}, true))
			_put(sky, "martial/bolt", c, Vector3.ZERO, Vector3(3.0, 3.0, SKY * 0.45), Vector3(-PI / 2, 0, 0), time, high.merged({"spin": -2.5, "opacity": 0.75}, true))
		"divine_symphony":
			_put(sky, "lyre", c, Vector3.UP * SKY, Vector3.ONE * r * 0.55, Vector3.ZERO, time, high.merged({"spin": 0.45}, true))
			_put(sky, "planets", c, Vector3.UP * (SKY - 1.5), Vector3.ONE * 2.4, Vector3.ZERO, time, high.merged({"spin": 0.9, "spectral": 1.0}, true))
	sky._draw()


# ---------------------------------------------------------------------------
# Contacts: four waves strike round the field, the fifth beat is the finale.
# ---------------------------------------------------------------------------
static func strike(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> void:
	var id := String(skill.id)
	var c := StarSkillArt.look(skill)
	var r := clampf(float(skill.get("radius", 9.0)), 4.0, 10.0)
	var last := StarSkillData.GOD_BEATS.size() - 1
	if index >= last:
		_finale(art, parent, id, c, r, point, source)
	else:
		_wave(art, parent, id, c, r, index, point, source)


static func _wave(art: StarSkillArt, parent: Node3D, id: String, c: Dictionary, r: float, index: int, point: Vector3, source: Vector3) -> void:
	var spot := _spot(index, r)
	var a := float(index) * GOLDEN
	var spectral := 1.0 if id == "astral_apocalypse" else 0.0
	var hit := {"initial": 0.1, "grow_time": 0.22, "spectral": spectral}
	match id:
		"divine_edict":
			var sword := MartialGeometry.mesh("blade")
			for k in 3:
				var off := Vector3(sin(a + k * 2.1), 0, cos(a + k * 2.1)) * 1.4 * float(k)
				_drop(art, sword, "GodWaveSword", c, spot + off, 3.4, 7.0, 0.3, a + k, 0.06 * k)
				if k == 0: _put(art, "martial/crater", c, spot + Vector3.UP * 0.05, Vector3.ONE * r * 0.45, Vector3.ZERO, 1.0, hit.merged({"delay": 0.28}, true))
			_put(art, "martial/sweep", c, spot + Vector3.UP * 1.1, Vector3.ONE * r * 0.5, Vector3(PI / 2, a, 0.4), 0.55, {"initial": 0.4, "spin": 3.0, "delay": 0.25})
		"sunfall_volley":
			_put(art, "martial/rain", c, spot + Vector3.UP * 6.0, Vector3(r * 0.42, 2.5, r * 0.42), Vector3.ZERO, 0.4, {"initial": 1.0, "travel": Vector3.DOWN * 6.0, "accelerate": true, "decay": 0.9})
			_put(art, "reticle", c, spot + Vector3.UP * 0.08, Vector3.ONE * r * 0.35, Vector3.ZERO, 0.9, {"initial": 1.4, "grow_time": 0.25, "spin": 1.2})
			_put(art, "martial/crater", c, spot + Vector3.UP * 0.05, Vector3.ONE * r * 0.4, Vector3.ZERO, 0.9, hit.merged({"delay": 0.35}, true))
			_put(art, "shards", c, spot, Vector3(2.0, 2.4, 2.0), Vector3.ZERO, 1.0, {"travel": Vector3.UP * 0.6, "delay": 0.35})
		"heavenrend_spear":
			var lance := MartialGeometry.mesh("lance")
			art.add_mesh(lance, "GodWaveLance", c, spot + Vector3.DOWN * 3.0, Vector3(1.5, 5.0, 1.5), Vector3.ZERO, 0.7, {"initial": 1.0, "grow_time": 0.01, "travel": Vector3.UP * 3.4, "decay": 0.7, "front": true})
			_put(art, "martial/fault", c, spot + Vector3.UP * 0.03, Vector3.ONE * r * 0.45, Vector3.ZERO, 1.0, hit)
			_put(art, "martial/bolt", c, spot, Vector3(2.2, 2.2, 4.5), Vector3(-PI / 2, a, 0), 0.4, {"initial": 1.0, "spin": 6.0, "decay": 0.6})
			_put(art, "impact", c, spot + Vector3.UP * 0.06, Vector3.ONE * r * 0.35, Vector3.ZERO, 0.7, {"initial": 0.05})
		"astral_apocalypse":
			_put(art, "martial/meteor", c, spot + Vector3(0, 9.0, -3.0), Vector3.ONE * 1.3, Vector3(-0.3, 0, 0), 0.32, {"initial": 1.0, "travel": Vector3(0, -8.6, 3.0), "accelerate": true, "decay": 0.92, "spectral": 1.0})
			_put(art, "prism", c, spot + Vector3.UP * 1.3, Vector3.ONE * 1.6, Vector3(0.3, 0, 0.2), 0.8, {"initial": 0.2, "spin": 2.0, "spectral": 1.0, "pulse": true, "delay": 0.3})
			_put(art, "constellation", c, spot + Vector3.UP * 0.08, Vector3.ONE * r * 0.4, Vector3.ZERO, 1.0, hit.merged({"spin": 0.6, "delay": 0.3}, true))
			_put(art, "shards", c, spot, Vector3(2.0, 2.6, 2.0), Vector3.ZERO, 1.0, {"travel": Vector3.UP * 0.7, "spectral": 1.0, "delay": 0.3})
		"seraphic_judgment":
			var lance := MartialGeometry.mesh("lance")
			_drop(art, lance, "GodHolyLance", c, spot, 5.5, 8.0, 0.3, a)
			_put(art, "sunrise", c, spot + Vector3.UP * 0.07, Vector3.ONE * r * 0.38, Vector3.ZERO, 1.0, hit.merged({"delay": 0.28, "spin": 0.4}, true))
			_put(art, "feathers", c, spot, Vector3(2.2, 3.0, 2.2), Vector3.ZERO, 1.1, {"travel": Vector3.UP * 1.2, "delay": 0.28})
			_put(art, "impact", c, spot + Vector3.UP * 0.06, Vector3.ONE * r * 0.3, Vector3.ZERO, 0.7, {"initial": 0.05, "delay": 0.28})
		"celestial_dragon_emperor":
			var across := Vector3(cos(a), 0, -sin(a))
			_put(art, "martial/dragon", c, spot + Vector3.UP * 5.0 - across * 5.0, Vector3.ONE * 2.2, Vector3(0.55, atan2(across.x, across.z), 0), 0.55, {"initial": 1.0, "travel": across * 10.0 + Vector3.DOWN * 4.0, "decay": 0.85})
			_put(art, "fang", c, spot + Vector3.UP * 0.1, Vector3(r * 0.45, 1.6, r * 0.45), Vector3.ZERO, 0.9, {"initial": 0.3, "turn": Vector3(0, 0.8, 0), "delay": 0.2})
			_put(art, "martial/wind", c, spot, Vector3(r * 0.35, 2.0, r * 0.35), Vector3.ZERO, 0.9, {"initial": 0.3, "spin": 3.0, "opacity": 0.7, "delay": 0.2})
			_put(art, "shards", c, spot, Vector3(2.0, 2.4, 2.0), Vector3.ZERO, 1.0, {"travel": Vector3.UP * 0.6, "delay": 0.25})
		"pantheon_bastion":
			var shield: Mesh = StarSkillArt._recent_shield if StarSkillArt._recent_shield else StarGeometry.mesh("titan_shield")
			art.add_mesh(shield, "GodWaveShield", c, spot + Vector3.UP * 7.0, Vector3.ONE * 2.6, Vector3(PI / 2, a, 0), 0.32, {"initial": 1.0, "grow_time": 0.01, "travel": Vector3.DOWN * 6.4, "accelerate": true, "decay": 0.97, "front": true})
			_put(art, "martial/crater", c, spot + Vector3.UP * 0.05, Vector3.ONE * r * 0.42, Vector3.ZERO, 1.0, hit.merged({"delay": 0.3}, true))
			_put(art, "shield_ring", c, spot + Vector3.UP * 0.1, Vector3.ONE * r * 0.22, Vector3.ZERO, 1.0, hit.merged({"delay": 0.3, "spin": 0.6}, true))
			_put(art, "titan_shield", c, spot + Vector3.UP * 0.6, Vector3.ONE * 2.6, Vector3(PI / 2, a, 0), 0.8, {"initial": 1.2, "grow_time": 0.1, "decay": 0.6, "front": true, "delay": 0.3})
		"death_gods_eclipse":
			_put(art, "martial/cross", c, spot + Vector3.UP * 0.1, Vector3.ONE * r * 0.42, Vector3(0, a, 0), 0.8, {"initial": 0.2, "grow_time": 0.15, "turn": Vector3(0, 0.5, 0)})
			var dagger: Mesh = StarSkillArt._recent_dagger if StarSkillArt._recent_dagger else MartialGeometry.mesh("blade")
			for k in 2:
				var off := Vector3(sin(a + k * PI), 0, cos(a + k * PI)) * 1.3
				_drop(art, dagger, "GodShadowDagger", c, spot + off, 2.4, 6.0, 0.32, a + k, 0.05 * k)
			for side in [-1.0, 1.0]:
				_put(art, "martial/sweep", c, spot + Vector3.UP * 1.2, Vector3.ONE * r * 0.42, Vector3(PI / 2, a, side * 0.6), 0.5, {"initial": 0.35, "spin": side * 3.0})
		"abyssal_throne":
			_put(art, "martial/bolt", c, spot, Vector3(2.6, 2.6, 5.0), Vector3(-PI / 2, a, 0), 0.35, {"initial": 1.0, "spin": 8.0, "decay": 0.55})
			_put(art, "worldroot", c, spot, Vector3(r * 0.38, 2.4, r * 0.38), Vector3.ZERO, 1.0, {"initial": 0.2, "grow_time": 0.2, "decay": 0.6})
			_put(art, "martial/crater", c, spot + Vector3.UP * 0.05, Vector3.ONE * r * 0.4, Vector3.ZERO, 1.0, hit)
			_put(art, "shards", c, spot, Vector3(2.2, 2.6, 2.2), Vector3.ZERO, 1.0, {"travel": Vector3.UP * 0.8, "pulse": true})
		"divine_symphony":
			_put(art, "elite/stave", c, spot + Vector3.UP * 0.2, Vector3(r * 0.36, 2.0, r * 0.36), Vector3.ZERO, 0.9, {"initial": 0.3, "grow_time": 0.2, "spin": 2.0})
			_put(art, "planets", c, spot + Vector3.UP * 2.2, Vector3.ONE * 1.6, Vector3.ZERO, 0.9, {"initial": 0.4, "spin": 1.6, "spectral": 1.0})
			_put(art, "constellation", c, spot + Vector3.UP * 0.08, Vector3.ONE * r * 0.42, Vector3.ZERO, 1.0, hit.merged({"spin": 0.5}, true))
			_put(art, "shards", c, spot, Vector3(2.0, 2.4, 2.0), Vector3.ZERO, 1.0, {"travel": Vector3.UP * 0.7, "pulse": true})
	# The temple answers each wave: a column of the pantheon flares over the spot.
	if extra_roots(1) < 1: return
	var flare := _extra(parent, point, 1.0, "StarGodWave_" + id, source, null)
	if not flare: return
	_put(flare, "shards", c, spot, Vector3(1.8, 5.0, 1.8), Vector3.ZERO, 0.9, {"initial": 0.6, "travel": Vector3.UP * 1.6, "spin": 1.2, "delay": 0.2, "spectral": spectral})
	_put(flare, "god_halo", c, spot + Vector3.UP * 0.12, Vector3.ONE * r * 0.3, Vector3.ZERO, 0.8, {"initial": 0.5, "spin": -1.0, "delay": 0.2, "spectral": spectral})
	flare._draw()


static func _finale(art: StarSkillArt, parent: Node3D, id: String, c: Dictionary, r: float, point: Vector3, source: Vector3) -> void:
	var spectral := 1.0 if id == "astral_apocalypse" else 0.0
	var at := Vector3.UP * 0.08
	var seal := {"initial": 0.15, "grow_time": 0.3, "spin": 0.3, "decay": 0.8, "spectral": spectral}
	match id:
		"divine_edict":
			var sword := MartialGeometry.mesh("blade")
			_drop(art, sword, "GodEdictFalling", c, Vector3.ZERO, 10.0, 12.0, 0.3)
			_planted(art, sword, "GodEdictPlanted", c, Vector3.ZERO, 10.0, 1.7, 0.29, 1.2)
			_put(art, "martial/fault", c, at, Vector3.ONE * r * 1.1, Vector3.ZERO, 1.9, seal.merged({"delay": 0.28, "spin": 0.0}, true))
			_put(art, "god_halo", c, at, Vector3.ONE * r, Vector3.ZERO, 1.9, seal.merged({"delay": 0.28}, true))
			_put(art, "lion", c, Vector3(0, 6.5, 0), Vector3.ONE * 3.0, Vector3.ZERO, 1.6, {"initial": 0.4, "travel": Vector3.UP * 0.8, "delay": 0.3})
			_put(art, "shards", c, at, Vector3(r * 0.7, 4.0, r * 0.7), Vector3.ZERO, 1.6, {"travel": Vector3.UP * 0.9, "delay": 0.3})
		"sunfall_volley":
			_put(art, "martial/dragon_arrow", c, Vector3.UP * 13.0, Vector3.ONE * 3.2, Vector3(PI / 2, 0, 0), 0.34, {"initial": 1.0, "travel": Vector3.DOWN * 12.0, "accelerate": true, "decay": 0.94, "front": true})
			_put(art, "sunrise", c, at, Vector3.ONE * r, Vector3.ZERO, 1.9, seal.merged({"delay": 0.3}, true))
			_put(art, "god_halo", c, at + Vector3.UP * 0.02, Vector3.ONE * r * 0.75, Vector3.ZERO, 1.9, seal.merged({"delay": 0.3, "spin": -0.4}, true))
			_put(art, "aureole", c, Vector3.UP * 4.0, Vector3.ONE * 3.4, Vector3.ZERO, 1.6, {"initial": 0.3, "face_camera": true, "delay": 0.32})
			_put(art, "martial/crater", c, at, Vector3.ONE * r * 0.8, Vector3.ZERO, 1.4, seal.merged({"delay": 0.32, "spin": 0.0}, true))
			_put(art, "shards", c, at, Vector3(r * 0.7, 4.0, r * 0.7), Vector3.ZERO, 1.6, {"travel": Vector3.UP * 0.9, "delay": 0.3})
		"heavenrend_spear":
			var lance := MartialGeometry.mesh("lance")
			_drop(art, lance, "GodLanceFalling", c, Vector3.ZERO, 11.0, 12.0, 0.28)
			_planted(art, lance, "GodLancePlanted", c, Vector3.ZERO, 11.0, 1.6, 0.27, 1.0)
			_put(art, "elite/spears", c, Vector3.ZERO, Vector3(r * 0.95, 5.0, r * 0.95), Vector3.ZERO, 1.5, {"initial": 0.3, "grow_time": 0.12, "decay": 0.7, "delay": 0.28, "front": true})
			_put(art, "god_halo", c, at, Vector3.ONE * r, Vector3.ZERO, 1.9, seal.merged({"delay": 0.28}, true))
			_put(art, "worldroot", c, at, Vector3(r, 3.2, r), Vector3.ZERO, 1.5, {"initial": 0.15, "grow_time": 0.2, "decay": 0.62, "delay": 0.28})
			_put(art, "martial/fault", c, at, Vector3.ONE * r * 1.1, Vector3.ZERO, 1.8, seal.merged({"delay": 0.28, "spin": 0.0}, true))
		"astral_apocalypse":
			for k in 3:
				var tilt: Vector3 = [Vector3(0.45, 0, 0.1), Vector3(-0.3, 0, 0.6), Vector3(0.1, 0, -0.75)][k]
				_put(art, "elite/astrolabe", c, Vector3.UP * 3.4, Vector3.ONE * r * (0.5 + 0.17 * k), tilt, 1.9, {"initial": 0.2, "grow_time": 0.3, "spin": [0.9, -0.7, 0.5][k], "spectral": 1.0, "decay": 0.8})
			_put(art, "genesis", c, Vector3.UP * 3.4, Vector3.ONE * 3.6, Vector3.ZERO, 1.8, {"initial": 0.3, "spin": 1.2, "spectral": 1.0, "decay": 0.5, "pulse": true})
			_put(art, "god_halo", c, at, Vector3.ONE * r, Vector3.ZERO, 1.9, seal)
			_put(art, "sunrise", c, at + Vector3.UP * 0.02, Vector3.ONE * r * 1.05, Vector3.ZERO, 1.5, {"initial": 0.02, "delay": 0.12, "spectral": 1.0})
		"seraphic_judgment":
			_put(art, "seraph", c, Vector3.UP * 7.0, Vector3.ONE * 5.5, Vector3.ZERO, 1.9, {"initial": 0.7, "travel": Vector3.DOWN * 2.2, "flap": 0.08, "flap_rate": 4.0, "decay": 0.85})
			_put(art, "elite/cathedral", c, Vector3.ZERO, Vector3(r, 4.0, r), Vector3.ZERO, 1.9, {"initial": 0.2, "grow_time": 0.25, "decay": 0.85})
			_put(art, "sunrise", c, at, Vector3.ONE * r, Vector3.ZERO, 1.9, seal)
			_put(art, "god_halo", c, at + Vector3.UP * 0.02, Vector3.ONE * r * 0.7, Vector3.ZERO, 1.9, seal.merged({"spin": -0.4}, true))
			_put(art, "feathers", c, at, Vector3(r * 0.7, 5.0, r * 0.7), Vector3.ZERO, 1.9, {"travel": Vector3.UP * 1.4})
		"celestial_dragon_emperor":
			_put(art, "martial/dragon", c, Vector3.UP * 14.0, Vector3.ONE * 4.6, Vector3(PI / 2, 0, 0), 0.4, {"initial": 1.0, "travel": Vector3.DOWN * 13.0, "accelerate": true, "decay": 0.9, "front": true})
			_put(art, "martial/storm", c, Vector3.UP * 0.2, Vector3(r * 0.8, 3.2, r * 0.8), Vector3.ZERO, 1.6, {"initial": 0.3, "spin": 2.6, "opacity": 0.75, "delay": 0.36})
			_put(art, "court", c, at, Vector3.ONE * r * 0.85, Vector3.ZERO, 1.9, seal.merged({"delay": 0.36}, true))
			_put(art, "god_halo", c, at + Vector3.UP * 0.02, Vector3.ONE * r, Vector3.ZERO, 1.9, seal.merged({"delay": 0.36, "spin": -0.3}, true))
			_put(art, "martial/dragon", c, Vector3.UP * 4.0, Vector3.ONE * 3.0, Vector3(0, PI / 2, 0), 1.5, {"initial": 0.6, "orbit": r * 0.5, "orbit_speed": 2.2, "spin": 2.2, "delay": 0.4})
			_put(art, "shards", c, at, Vector3(r * 0.7, 4.0, r * 0.7), Vector3.ZERO, 1.6, {"travel": Vector3.UP * 0.9, "delay": 0.36})
		"pantheon_bastion":
			var shield: Mesh = StarSkillArt._recent_shield if StarSkillArt._recent_shield else StarGeometry.mesh("titan_shield")
			art.add_mesh(StarGeometry.mesh("titan_shield"), "GodTitanShield", c, Vector3.UP * 11.0, Vector3.ONE * 6.5, Vector3(PI / 2, 0, 0), 0.3, {"initial": 1.0, "grow_time": 0.01, "travel": Vector3.DOWN * 10.2, "accelerate": true, "decay": 0.97, "front": true})
			_put(art, "elite/rampart", c, Vector3.ZERO, Vector3(r, 3.4, r), Vector3.ZERO, 1.9, {"initial": 0.3, "grow_time": 0.2, "decay": 0.85, "delay": 0.28})
			_put(art, "elite/aegis", c, Vector3.ZERO, Vector3.ONE * r * 0.95, Vector3.ZERO, 1.8, {"initial": 0.5, "grow_time": 0.25, "opacity": 0.55, "spin": 0.2, "delay": 0.28})
			_put(art, "god_halo", c, at, Vector3.ONE * r, Vector3.ZERO, 1.9, seal.merged({"delay": 0.28}, true))
			art.add_mesh(shield, "GodPlantedShield", c, Vector3.UP * 0.9, Vector3.ONE * 3.0, Vector3(-PI / 2, 0, 0), 1.6, {"initial": 1.3, "grow_time": 0.1, "decay": 0.7, "front": true, "delay": 0.28, "spin": 1.5})
			_put(art, "martial/crater", c, at, Vector3.ONE * r * 0.85, Vector3.ZERO, 1.4, seal.merged({"delay": 0.28, "spin": 0.0}, true))
		"death_gods_eclipse":
			_put(art, "moon", c, Vector3.UP * 4.2, Vector3.ONE * r * 0.75, Vector3(PI / 2, 0, 0), 1.6, {"initial": 0.5, "grow_time": 0.12, "turn": Vector3(0, 0, -1.2), "decay": 0.7})
			_put(art, "martial/cross", c, at + Vector3.UP * 0.05, Vector3.ONE * r, Vector3.ZERO, 1.6, {"initial": 0.2, "grow_time": 0.15, "turn": Vector3(0, 0.6, 0)})
			_put(art, "god_halo", c, at, Vector3.ONE * r, Vector3.ZERO, 1.9, seal)
			_put(art, "fang", c, at + Vector3.UP * 0.1, Vector3(r, 2.0, r), Vector3.ZERO, 1.2, {"initial": 0.4, "turn": Vector3(0, -0.9, 0)})
			_put(art, "constellation", c, Vector3.UP * 7.0, Vector3.ONE * r * 0.7, Vector3.ZERO, 1.6, {"initial": 0.8, "spin": -0.4})
			_put(art, "shards", c, at, Vector3(r * 0.7, 4.0, r * 0.7), Vector3.ZERO, 1.6, {"travel": Vector3.UP * 0.9})
		"abyssal_throne":
			_put(art, "crown", c, Vector3.UP * 9.0, Vector3.ONE * r * 0.55, Vector3.ZERO, 1.9, {"initial": 0.9, "travel": Vector3.DOWN * 6.5, "spin": 0.5, "decay": 0.85})
			_put(art, "worldroot", c, at, Vector3(r, 3.6, r), Vector3.ZERO, 1.6, {"initial": 0.15, "grow_time": 0.2, "decay": 0.62, "delay": 0.15})
			_put(art, "god_halo", c, at, Vector3.ONE * r, Vector3.ZERO, 1.9, seal)
			_put(art, "martial/fault", c, at, Vector3.ONE * r * 1.1, Vector3.ZERO, 1.8, seal.merged({"spin": 0.0}, true))
			for k in 2:
				var b := Vector3(sin(k * PI + 0.7), 0, cos(k * PI + 0.7)) * r * 0.45
				_put(art, "martial/bolt", c, b, Vector3(3.0, 3.0, 6.0), Vector3(-PI / 2, k, 0), 0.5, {"initial": 1.0, "spin": 7.0, "decay": 0.6, "delay": 0.1 * k})
		"divine_symphony":
			_put(art, "lyre", c, at, Vector3.ONE * r * 0.85, Vector3.ZERO, 1.9, {"initial": 0.3, "grow_time": 0.25, "spin": 0.5, "decay": 0.85})
			_put(art, "elite/stave", c, Vector3.UP * 0.3, Vector3(r, 4.0, r), Vector3.ZERO, 1.8, {"initial": 0.3, "grow_time": 0.2, "spin": 1.6, "decay": 0.8})
			_put(art, "planets", c, Vector3.UP * 4.2, Vector3.ONE * r * 0.45, Vector3.ZERO, 1.8, {"initial": 0.4, "spin": 0.7, "spectral": 1.0, "decay": 0.8})
			_put(art, "god_halo", c, at, Vector3.ONE * r, Vector3.ZERO, 1.9, seal)
			_put(art, "constellation", c, Vector3.UP * 7.5, Vector3.ONE * r * 0.8, Vector3.ZERO, 1.6, {"initial": 0.7, "spin": -0.3})
			_put(art, "shards", c, at, Vector3(r * 0.7, 4.0, r * 0.7), Vector3.ZERO, 1.6, {"travel": Vector3.UP * 0.9, "pulse": true})
	var extras := extra_roots(2)
	if extras < 1: return
	# The god manifests over the field: the class's avatar, high and huge, in an aureole.
	var avatar := _extra(parent, point, 2.2, "StarGodAvatar_" + id, source, null)
	if avatar:
		_avatar(avatar, id, c, r, spectral)
		avatar._draw()
	if extras < 2: return
	# The pantheon rises in full round the finale.
	var temple := _extra(parent, point, 2.0, "StarGodTemple_" + id, source, null)
	if temple:
		_put(temple, "pantheon", c, Vector3.ZERO, Vector3(r * 1.02, 5.5, r * 1.02), Vector3.ZERO, 1.9, {"initial": 0.15, "grow_time": 0.25, "spin": 0.35, "decay": 0.75, "delay": 0.15, "opacity": 0.6, "spectral": spectral})
		_put(temple, "shards", c, Vector3.UP * 0.2, Vector3(r * 0.9, 5.0, r * 0.9), Vector3.ZERO, 1.8, {"initial": 0.6, "travel": Vector3.UP * 1.4, "delay": 0.15, "spectral": spectral})
		_put(temple, "impact", c, Vector3.UP * 0.1, Vector3.ONE * r * 1.15, Vector3.ZERO, 1.0, {"initial": 0.05, "delay": 0.2, "spectral": spectral})
		_put(temple, "sunrise", c, Vector3.UP * 0.12, Vector3.ONE * r * 1.2, Vector3.ZERO, 1.2, {"initial": 0.1, "grow_time": 0.3, "spin": -0.5, "delay": 0.2, "opacity": 0.7, "spectral": spectral})
		temple._draw()


## The finale's god avatar: the class emblem made colossal over the field.
static func _avatar(art: StarSkillArt, id: String, c: Dictionary, r: float, spectral: float) -> void:
	var high := Vector3.UP * 6.8
	var rise := {"initial": 0.35, "grow_time": 0.22, "fade_in": 0.08, "decay": 0.82, "spectral": spectral}
	var aureole := rise.merged({"face_camera": true, "pulse": true}, true)
	match id:
		"divine_edict":
			_put(art, "lion", c, high, Vector3.ONE * 4.6, Vector3.ZERO, 2.0, rise)
			_put(art, "aureole", c, high, Vector3.ONE * r * 0.42, Vector3.ZERO, 2.0, aureole)
			_put(art, "martial/sword_fan", c, Vector3.UP * 0.5, Vector3.ONE * r * 0.5, Vector3.ZERO, 1.6, rise.merged({"spin": 1.2}, true))
		"sunfall_volley":
			_put(art, "sunrise", c, high, Vector3.ONE * r * 0.5, Vector3(PI / 2, 0, 0), 2.0, aureole.merged({"spin": 0.0}, true))
			_put(art, "aureole", c, high, Vector3.ONE * r * 0.45, Vector3.ZERO, 2.0, aureole)
			_put(art, "martial/bow", c, high + Vector3.DOWN * 0.5, Vector3.ONE * 3.2, Vector3.ZERO, 2.0, rise.merged({"face_camera": true}, true))
		"heavenrend_spear":
			_put(art, "aureole", c, high, Vector3.ONE * r * 0.45, Vector3.ZERO, 2.0, aureole)
			_put(art, "drill", c, high + Vector3.UP * 1.5, Vector3.ONE * 3.4, Vector3(PI / 2, 0, 0), 2.0, rise.merged({"spin": 2.0}, true))
			_put(art, "elite/spears", c, Vector3.ZERO, Vector3(r * 0.6, 4.5, r * 0.6), Vector3.ZERO, 1.6, rise.merged({"spin": -0.8}, true))
		"astral_apocalypse":
			_put(art, "genesis", c, high, Vector3.ONE * 4.2, Vector3.ZERO, 2.0, rise.merged({"spin": 1.4, "spectral": 1.0}, true))
			_put(art, "elite/astrolabe", c, high, Vector3.ONE * r * 0.55, Vector3(PI / 2, 0, 0), 2.0, aureole.merged({"spectral": 1.0}, true))
			_put(art, "planets", c, high, Vector3.ONE * r * 0.5, Vector3(0.4, 0, 0.2), 2.0, rise.merged({"spin": -0.9, "spectral": 1.0}, true))
		"seraphic_judgment":
			_put(art, "aureole", c, high + Vector3.UP * 0.8, Vector3.ONE * r * 0.5, Vector3.ZERO, 2.0, aureole)
			_put(art, "sunrise", c, high + Vector3.UP * 0.8, Vector3.ONE * r * 0.42, Vector3(PI / 2, 0, 0), 2.0, aureole.merged({"pulse": false}, true))
			_put(art, "feathers", c, Vector3.UP * 0.5, Vector3(r * 0.8, 7.0, r * 0.8), Vector3.ZERO, 2.0, {"travel": Vector3.UP * 1.6, "initial": 0.7})
		"celestial_dragon_emperor":
			_put(art, "martial/dragon", c, high + Vector3.DOWN * 1.2, Vector3.ONE * 5.0, Vector3(0, PI / 2, 0), 2.0, rise.merged({"orbit": r * 0.32, "orbit_speed": 2.0, "spin": 2.0}, true))
			_put(art, "aureole", c, high, Vector3.ONE * r * 0.45, Vector3.ZERO, 2.0, aureole)
			_put(art, "court", c, high + Vector3.UP * 1.6, Vector3.ONE * r * 0.5, Vector3.ZERO, 2.0, rise.merged({"spin": 0.8}, true))
		"pantheon_bastion":
			_put(art, "titan_shield", c, high + Vector3.DOWN * 1.0, Vector3.ONE * 5.0, Vector3.ZERO, 2.0, rise.merged({"face_camera": true, "front": true}, true))
			_put(art, "aureole", c, high, Vector3.ONE * r * 0.45, Vector3.ZERO, 2.0, aureole)
			_put(art, "elite/aegis", c, Vector3.ZERO, Vector3.ONE * r * 1.05, Vector3.ZERO, 2.0, rise.merged({"opacity": 0.45, "spin": 0.25}, true))
		"death_gods_eclipse":
			_put(art, "moon", c, high, Vector3.ONE * r * 0.5, Vector3(PI / 2, 0, 0), 2.0, rise.merged({"turn": Vector3(0, 0, 1.4)}, true))
			_put(art, "aureole", c, high, Vector3.ONE * r * 0.45, Vector3.ZERO, 2.0, aureole)
			_put(art, "martial/cross", c, high, Vector3.ONE * r * 0.5, Vector3(PI / 2, 0, PI / 4), 1.6, rise.merged({"face_camera": true}, true))
		"abyssal_throne":
			_put(art, "crown", c, high, Vector3.ONE * r * 0.45, Vector3.ZERO, 2.0, rise.merged({"spin": 0.6}, true))
			_put(art, "aureole", c, high + Vector3.UP * 0.6, Vector3.ONE * r * 0.45, Vector3.ZERO, 2.0, aureole)
			_put(art, "martial/bolt", c, Vector3.ZERO, Vector3(4.0, 4.0, 4.0), Vector3(-PI / 2, 0, 0), 1.2, rise.merged({"spin": 6.0}, true))
		"divine_symphony":
			_put(art, "lyre", c, high, Vector3.ONE * r * 0.5, Vector3(PI / 2, 0, 0), 2.0, aureole.merged({"pulse": false}, true))
			_put(art, "aureole", c, high, Vector3.ONE * r * 0.45, Vector3.ZERO, 2.0, aureole)
			_put(art, "planets", c, high + Vector3.UP * 1.0, Vector3.ONE * 3.2, Vector3.ZERO, 2.0, rise.merged({"spin": 1.2, "spectral": 1.0}, true))
