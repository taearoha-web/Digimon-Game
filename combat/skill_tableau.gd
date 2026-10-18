class_name SkillTableau
extends RefCounted
## Storybook spell staging: silhouette first, a contrasting core, then a small
## number of moving ink accents. All decoration shares the combat VFX budget.
## Gameplay owns every impact; this module owns no damage callbacks or timers.
static var _creatures: Dictionary = {}
static var _lightning: ArrayMesh
static var _shield_shape: ArrayMesh
static var _sculpt_parts: Dictionary = {}

static func link(parent: Node3D, skill: Dictionary, from: Vector3, to: Vector3) -> void:
	var look := SkillShow.profile_for(skill)
	if String(look.signature) == "lightning":
		VfxKit.lightning(parent, from, to, look.primary)
		return
	var direction := to - from
	if direction.length_squared() < 0.001:
		return
	var root := SpellSpectacle._root(parent, (from + to) * 0.5, "SkillLink_" + String(skill.id))
	root.look_at(to, Vector3.RIGHT if absf(direction.normalized().dot(Vector3.UP)) > 0.98 else Vector3.UP, true)
	SkillInk.ribbon(root, look, Vector3.ZERO, direction.length() * 0.5, 2, Vector3.ZERO, 0.25)
	SkillInk.ribbon(root, look, Vector3.ZERO, direction.length() * 0.5, 2, Vector3(0, 0, PI * 0.5), 0.25)
	root.create_tween().tween_interval(0.3).finished.connect(root.queue_free, CONNECT_ONE_SHOT)

static func flight(parent: Node3D, skill: Dictionary, from: Vector3, to: Vector3, seconds: float, size := 1.0) -> Node3D:
	if MartialSkillArt.handles(skill):
		var martial := MartialSkillArt.flight(parent,skill,from,to,seconds,size)
		ClassFlourish.flight_glow(martial, skill, size)
		return martial
	var look := SkillShow.profile_for(skill)
	var root := SpellSpectacle._root(parent, from, "SkillFlight_" + String(skill.id))
	ClassFlourish.flight_glow(root, skill, size)
	var direction := to - from
	if direction.length_squared() > 0.001:
		root.look_at(to, Vector3.RIGHT if absf(direction.normalized().dot(Vector3.UP)) > 0.98 else Vector3.UP, true)
	var arrow := String(look.family) == "archer" or String(look.signature) in ["arrow", "lance", "blade", "thorn", "beam"]
	# This body is essential feedback, like the old VfxKit carrier, and remains
	# visible when the optional cosmetic budget is completely occupied.
	var body := MeshInstance3D.new()
	body.name = "EssentialSkillProjectile"
	body.mesh = SpellSpectacle._blade_mesh(true) if arrow else (SpellSpectacle._crystal_mesh() if String(look.style) in ["ice", "arcane", "thunder"] else SpellSpectacle._sphere_mesh())
	body.material_override = SpellSpectacle._material(look)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(body)
	var grand := 1.7 if bool(look.ultimate) else 1.0
	var style := String(look.style)
	if arrow:
		body.scale = Vector3(0.23, 1.45 + float(look.tier) * 0.08, 0.23) * size * grand
		body.rotation.x = PI * 0.5
	else:
		# A spell body big enough to read in flight, with coiling ribbons behind it.
		body.scale = Vector3(0.45, 0.45, 0.7) * size * grand
		var trail := Node3D.new()
		root.add_child(trail)
		trail.rotation.y = PI
		VfxKit.flight_ribbons(trail, look.primary, 0.45 * size * grand, 2.7, style == "fire")
	for i in (2 if VfxBudget.quality() > 0 else 1):
		SkillInk.ribbon(root, look, Vector3(0, 0, -0.85 * grand), 1.15 * size * grand, 2, Vector3(0, 0, PI * i * 0.5), seconds)
	if style in ["holy", "heal", "arcane"]:
		var halo := SpellSpectacle._mesh(root, SpellSpectacle._halo_mesh(), body.material_override)
		if halo:
			halo.scale = Vector3.ONE * (0.38 if arrow else 0.6) * size
			halo.rotation.x = PI * 0.5
	elif style == "fire":
		var tail := SpellSpectacle._mesh(root, SpellSpectacle._crystal_mesh(), body.material_override, Vector3(0, 0, -0.45))
		if tail:
			tail.rotation.x = -PI * 0.5
			tail.scale = Vector3(0.18, 0.8, 0.18) * size
	elif style == "ice" and not arrow and VfxBudget.can_decorate():
		# A real ice lance spins ahead of the crystal (the element made physical).
		ElementFx.ice_lance(root, 0.4 * size * grand)
		var lance := root.get_child(root.get_child_count() - 1) as MeshInstance3D
		lance.rotation_degrees.x = 90.0
		VfxBudget.track_decoration(lance)
	if String(look.signature) in ["phoenix", "comet"]:
		var wings := SpellSpectacle._mesh(root, SpellSpectacle._wing_mesh(), SpellSpectacle._material(look))
		if wings:
			wings.scale = Vector3(0.7, 0.5, 0.35) * grand
	if not arrow and VfxBudget.can_light():
		var light := OmniLight3D.new()
		light.light_color = look.primary
		light.light_energy = 0.6
		light.omni_range = 3.5
		root.add_child(light)
		VfxBudget.track_light(light)
	var family := String(look.family)
	var tw := root.create_tween()
	tw.tween_property(root, "global_position", to, seconds)
	if style == "fire" and not arrow:
		# Flames shed along the path, like the old fireball carrier.
		var puffs := {"next": 0.15}
		tw.parallel().tween_method(func(t: float):
			if t >= float(puffs.next) and is_instance_valid(root) and root.is_inside_tree():
				puffs["next"] = t + 0.22
				ElementFx.flame_puff(parent, root.global_position, 0.45 * size), 0.0, 1.0, seconds)
	tw.tween_callback(func():
		# The archer's arrival bursts into a fan of light; the carrier owns the rest.
		if family == "archer" and is_instance_valid(parent) and parent.is_inside_tree():
			VfxKit.impact_fan(parent, to, look.accent, 0.75 * size, "spark")
		root.queue_free())
	return root

## [param crit] only adds a fan of light; damage was already decided.
static func contact(parent: Node3D, skill: Dictionary, at: Vector3, crit := false) -> void:
	ClassFlourish.contact(parent, skill, at, crit)
	if MartialSkillArt.handles(skill):
		MartialSkillArt.contact(parent,skill,at)
		return
	if String(skill.id) != "judgment_ray":
		SkillCraft.contact(parent, skill, at, crit)

static func anticipate(parent: Node3D, skill: Dictionary, look: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual = null) -> void:
	if not VfxBudget.can_decorate():
		return
	if visual:
		SkillCharge.launch(parent, visual, look, duration)
	var root := SpellSpectacle._root(parent, origin, "SkillWindup_" + String(skill.id))
	var dir := aim - origin
	if Vector2(dir.x, dir.z).length_squared() > 0.001:
		root.rotation.y = atan2(dir.x, dir.z)
	var family := String(look.family)
	var time := maxf(duration, 0.08)
	if visual:
		# Socket light owns the wind-up; only a low, open grounding mark remains.
		if family in ["mage", "priest", "summoner"]:
			SkillInk.mark(root, look, Vector3(0, 0.035, 0), 0.9 + float(look.tier) * 0.08, time)
	elif family in ["warrior", "vagabond", "lancer", "defender"]:
		SkillInk.ribbon(root, look, Vector3(0, 1.1, 0.4), 0.8, 0, Vector3(0, 0, -0.7), time)
	elif family == "archer":
		var reticle := SkillInk.mark(root, look, Vector3(0, 1.35, 0.75), 0.6, time, 2)
		if reticle:
			reticle.rotation = Vector3.ZERO
	else:
		SkillInk.mark(root, look, Vector3(0, 0.035, 0), 1.05 + float(look.tier) * 0.08, time)
		var orb := SpellSpectacle._mesh(root, SpellSpectacle._sphere_mesh(), SpellSpectacle._material(look), Vector3(0.35, 1.7, 0.35))
		if orb:
			orb.scale = Vector3.ONE * 0.035
			orb.create_tween().tween_property(orb, "scale", Vector3.ONE * (0.16 + float(look.tier) * 0.015), time)
	root.create_tween().tween_interval(time + 0.04).finished.connect(root.queue_free, CONNECT_ONE_SHOT)

static func render(parent: Node3D, skill: Dictionary, look: Dictionary, center: Vector3, origin: Vector3, tier: int, crowd: int) -> void:
	if String(skill.id) == "forest_blessing":
		_forest_bloom(parent, origin, look)
		return
	if String(skill.id) == "armageddon" or not VfxBudget.can_decorate():
		return
	var shape := String(skill.shape)
	var travelling := bool(skill.get("projectile", false)) or shape in ["fan", "chain"]
	var self_cast := shape in ["self", "summon", "burst"]
	var directed := String(look.signature) in ["cleave", "cross", "lance", "world_spear", "blade"] and shape == "single"
	var root := SpellSpectacle._root(parent, origin if travelling or self_cast or directed else center, "SpellSpectacle_" + String(skill.id))
	var dir := center - origin
	if Vector2(dir.x, dir.z).length_squared() > 0.001:
		root.rotation.y = atan2(dir.x, dir.z)
	tier = mini(tier, [1, 3, 5][VfxBudget.quality()])
	var mat := SpellSpectacle._material(look)
	var core_look := look.duplicate()
	core_look.primary = (look.primary as Color).lerp(look.accent, 0.62)
	core_look.shade = look.primary
	var core := SpellSpectacle._material(core_look)
	var shade_look := look.duplicate()
	shade_look.primary = look.shade
	shade_look.accent = look.primary
	var shade := SpellSpectacle._material(shade_look)
	var radius := minf(float(skill.get("radius", 2.8)) * 0.66, 4.8)
	var duration := (0.48 + float(look.tempo) * 0.34 + tier * 0.045) * clampf(float(look.linger), 0.7, 1.5)
	if bool(look.ultimate):
		duration = 1.35
	# The recipe's layer count (2 at Lv.1, 6 at Lv.100) adds a second pass
	# above the silhouette from Lv.50: a helix, a crown or a phoenix.
	var layers := clampi(int(look.layers), 2, 6)
	var signature := String(look.signature)
	if shape == "summon":
		root.translate_object_local(Vector3(0, 0, 1.4))
	if shape == "summon" or signature in ["beast", "dragon", "elder_dragon"]:
		SkillCraft.portal(root, look, core, 1.15 + tier * 0.12, duration)
	match signature:
		"cleave", "cross", "cyclone":
			var count := clampi(int(look.strokes), 2, 4) if signature == "cross" else 1
			if signature == "cyclone":
				count = 2 if tier >= 2 else 1
			for i in count:
				var tilt := Vector3(0.0, float(i) * 0.85, float(look.curvature) if i % 2 == 0 else -float(look.curvature))
				if signature == "cyclone":
					tilt = Vector3(0.12 * i, float(i) * PI, 0.0)
				SkillInk.ribbon(root, look, Vector3(0, 0.8 + i * 0.22, 0), radius if signature == "cyclone" else 1.5 + tier * 0.19, 1 if signature == "cyclone" else 0, tilt, 0.48 + tier * 0.025, i * 0.045)
			# A narrow solid blade edge remains visible even before the ink reveals.
			SpellSpectacle._slashes(root, core, "cut", mini(tier, 2), float(look.curvature), 1)
		"blade", "lance", "world_spear":
			var length := 2.7 + tier * 0.5
			if signature == "world_spear":
				length = 9.3
			if directed:
				length = maxf(length, minf(dir.length() * 0.8, 12.0))
			SpellSpectacle._weapon(root, mat, "arrow" if signature != "blade" else "sword", length, 1)
			SkillInk.ribbon(root, core_look, Vector3(0, 1.1, length * 0.15), length * 0.65, 2, Vector3(0, 0, 0.4), 0.48)
			if tier >= 2:
				SkillInk.ribbon(root, look, Vector3(0, 1.1, 0.5), 1.6, 0, Vector3(PI * 0.5, 0, 0), 0.5)
			if signature == "world_spear":
				SpellSpectacle._ground_shards(root, shade, 3.5, 4)
				_crown(root, core, 4.0, 4, false)
		"arrow", "comet", "thorn":
			SpellSpectacle._weapon(root, core, "arrow", 1.9 + tier * 0.25, 1)
			var fan := 3 if shape == "fan" else 1
			for i in fan:
				SkillInk.ribbon(root, look, Vector3((i - (fan - 1) * 0.5) * 0.25, 1.2, 0.6), 1.15 + tier * 0.08, 0, Vector3(PI * 0.5, 0, (i - 1) * 0.3), 0.42)
			if signature == "comet":
				SpellSpectacle._phoenix(root, mat, 2.7, true)
		"shield":
			_shield(root, mat, core, tier)
		"focus", "rune":
			SpellSpectacle._orbit(root, mat, mini(tier, 2))
			_crown(root, core, 1.3, 3 + tier / 2, false)
			_astrolabe(root, look, 1.5 + tier * 0.2, duration)
		"roar":
			for i in 2:
				SkillInk.ribbon(root, look, Vector3(0, 0.65 + i * 0.8, 0), radius, 1, Vector3.ZERO, 0.62, i * 0.06)
			_crown(root, core, 1.0, 4, false)
		"fault":
			SpellSpectacle._ground_shards(root, shade, radius * 0.68, 3 + tier)
			SkillInk.mark(root, look, Vector3(0, 0.05, 0), radius, 0.65, 1)
			_crown(root, core, radius * 0.7, 3, false)
		"fire", "meteor":
			_fire(root, mat, core, tier, radius, travelling)
		"tide", "wind", "vortex":
			var height := 3.6 if signature == "tide" else 2.8
			SpellSpectacle._helix(root, mat, minf(radius, 2.8), height, 2)
			SkillInk.ribbon(root, core_look, Vector3(0, 0.6, 0), radius, 1, Vector3(0.2, 0, 0.05), 0.8)
			if signature == "vortex":
				SpellSpectacle._orbit(root, shade, 2)
			elif tier >= 3:
				SpellSpectacle._helix(root, core, 1.25, 3.8, 1)
		"beam", "lightning":
			if travelling:
				SpellSpectacle._weapon(root, core, "arrow", 2.4 + tier * 0.25, 1)
				SkillInk.mark(root, look, Vector3(0, 1.3, 0.4), 0.9, 0.45, 1, true)
			else:
				_bolts(root, mat, core, tier, radius)
		"rain":
			SpellSpectacle._sky_lances(root, mat, tier, false)
			_crown(root, core, radius * 0.55, 3 + tier / 2, true)
		"frost":
			SkillCraft.frost(root, look, mat, core, tier, radius)
			duration = maxf(duration, 1.05)
		"lotus", "spores":
			_lotus(root, mat, core, shade, tier, signature == "spores")
		"sun":
			# A real sun: the orb and halo, a second halo turning around it and a
			# hot core of light striking down through it, instead of a flat sigil.
			SpellSpectacle._solar(root, core, 3.4, mini(tier, 2))
			_sun_halo(root, mat, 3.4 * 0.66, tier, duration)
			VfxKit.pillar(root, root.global_position, look.accent, 6.0 + tier, 0.3 + tier * 0.05, duration * 0.8, Color.WHITE)
		"wings", "phoenix":
			SpellSpectacle._phoenix(root, mat, 2.0 + tier * 0.35, signature == "phoenix")
			SpellSpectacle._phoenix(root, core, 1.25 + tier * 0.20, false)
			SkillInk.mark(root, look, Vector3(0, 1.8, -0.08), 1.0, 0.8, 2, true)
		"roots", "tree":
			_tree(root, mat, core, tier, signature == "tree")
		"beast":
			_beast(root, mat, core, shade, String(skill.get("summon", {}).get("kind", "cat")), tier)
		"dragon", "elder_dragon":
			SpellSpectacle._dragon(root, mat, mini(tier, 3))
			SpellSpectacle._phoenix(root, core, 2.6, false)
			SkillInk.mark(root, look, Vector3(0, 0.055, 0), 3.0, 1.1)
		"sword_court":
			SpellSpectacle._sword_court(root, core, 3)
			_crown(root, core, 2.4, 4, false)
			SkillInk.ribbon(root, core_look, Vector3(0, 1.0, 0), 3.4, 0, Vector3(0, 0, -0.8), 0.6)
		"cathedral":
			SpellSpectacle._judgement(root, mat, 3)
			SpellSpectacle._phoenix(root, core, 2.4, false)
			SkillInk.mark(root, look, Vector3(0, 5.6, 0), 2.6, 1.0, 1, true)
	if layers >= 4 and tier >= 2 and crowd < 2:
		match signature:
			"cleave", "cross", "cyclone", "blade", "lance", "world_spear", "arrow", "comet", "thorn", "beam", "lightning", "sword_court":
				_crown(root, core, 1.1 + layers * 0.15, layers, false)
			"wings", "phoenix", "sun", "cathedral", "lotus", "spores", "rain":
				SpellSpectacle._phoenix(root, shade, 1.0 + layers * 0.3, false)
			_:
				SpellSpectacle._helix(root, core, 0.85 + layers * 0.12, 2.3 + layers * 0.25, 1)
	if not travelling and signature not in ["cleave", "cross", "lance", "blade", "fault", "frost", "dragon", "elder_dragon"]:
		SkillInk.mark(root, look, Vector3(0, 0.045, 0), radius if shape in ["burst", "blast"] else 1.45 + tier * 0.12, minf(duration, 1.0))
	# One small accent emitter, never the old six universal particle layers.
	if tier >= 2 and crowd < 3:
		SpellSpectacle._particles(root, look, Vector3(0, 0.8, 0), "spark", 6 + tier * 2, minf(radius, 2.3), 0.55, true)
	SpellSpectacle._finish(root, mat, duration)

static func _crown(root: Node3D, mat: Material, radius: float, count: int, falling: bool) -> void:
	count = VfxBudget.count(count, 2)
	for i in count:
		var a := float(i) * TAU / count
		var shard := SpellSpectacle._mesh(root, SpellSpectacle._crystal_mesh(), mat, Vector3(cos(a) * radius, 4.0 if falling else 0.25, sin(a) * radius))
		if shard:
			shard.scale = Vector3(0.09, 1.25 if falling else 0.45, 0.09)
			var tw := shard.create_tween()
			tw.tween_property(shard, "position:y", 0.3 if falling else 1.8, 0.24 if falling else 0.58).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN if falling else Tween.EASE_OUT)

## A second, tilted astrolabe ring (the elite mesh) spinning over the caster,
## drawn spectral like the star prisms.
static func _astrolabe(root: Node3D, look: Dictionary, radius: float, duration: float) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = StarSkillArt.SHADER
	for key in ["primary", "accent", "shade"]:
		mat.set_shader_parameter(key, look[key])
	mat.set_shader_parameter("spectral", 1.0)
	mat.set_shader_parameter("opacity", 0.9)
	var ring := SpellSpectacle._mesh(root, EliteSkillArt.geometry("astrolabe"), mat, Vector3(0, 1.6, 0))
	if ring == null:
		return
	ring.rotation = Vector3(0.55, 0.0, 0.25)
	ring.scale = Vector3.ONE * radius * 0.3
	var tw := ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3.ONE * radius, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "rotation:y", TAU * 0.6, duration)
	tw.tween_method(func(v: float): mat.set_shader_parameter("age", v), 0.0, duration, duration)
	tw.tween_method(func(v: float): mat.set_shader_parameter("fade", v), 1.0, 0.0, duration * 0.4).set_delay(duration * 0.6)


## A second halo turning around the sun, tilted so it reads as a ring.
static func _sun_halo(root: Node3D, mat: Material, height: float, tier: int, duration: float) -> void:
	var halo := SpellSpectacle._mesh(root, SpellSpectacle._halo_mesh(), mat, Vector3(0, height, 0))
	if halo:
		halo.scale = Vector3.ONE * (1.4 + tier * 0.25)
		halo.rotation = Vector3(1.15, 0.0, 0.35)
		halo.create_tween().tween_property(halo, "rotation:y", TAU * 0.75, duration)


static func _shield(root: Node3D, mat: Material, core: Material, tier: int) -> void:
	var plate := SpellSpectacle._mesh(root, shield_mesh(), core, Vector3(0, 1.35, 0.8))
	if plate:
		plate.scale = Vector3(0.06, 1.25 + tier * 0.06, 1.0)
		plate.create_tween().tween_property(plate, "scale:x", 1.18 + tier * 0.05, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var inlay := SpellSpectacle._mesh(root, shield_mesh(), mat, Vector3(0, 1.35, 0.88))
	if inlay:
		inlay.scale = Vector3(0.05, 1.05 + tier * 0.06, 1.0)
		inlay.create_tween().tween_property(inlay, "scale:x", 0.98 + tier * 0.05, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var gem := SpellSpectacle._mesh(root, SpellSpectacle._crystal_mesh(), core, Vector3(0, 1.40, 1.11))
	if gem:
		gem.scale = Vector3(0.18, 0.40, 0.10)
	for i in 2:
		var wing := SpellSpectacle._mesh(root, SpellSpectacle._wing_mesh(), core, Vector3(0, 1.0 + i * 0.36, 0.87))
		if wing:
			wing.scale = Vector3(0.8, 0.6, 0.25)

static func _fire(root: Node3D, mat: Material, core: Material, tier: int, radius: float, travelling: bool) -> void:
	var orb := SpellSpectacle._mesh(root, SpellSpectacle._sphere_mesh(), core, Vector3(0, 1.15, 0))
	if orb:
		orb.scale = Vector3.ONE * (0.40 if travelling else 0.7 + tier * 0.07)
	if travelling:
		var flame := SpellSpectacle._mesh(root, SpellSpectacle._crystal_mesh(), mat, Vector3(0, 1.15, 0.55))
		if flame:
			flame.scale = Vector3(0.22, 0.75, 0.22)
			flame.rotation.x = PI * 0.5
		return
	var count := VfxBudget.count(4 + tier, 3)
	for i in count:
		var a := TAU * i / count
		var flame := SpellSpectacle._mesh(root, SpellSpectacle._crystal_mesh(), mat, Vector3(sin(a), 0.25, cos(a)) * minf(radius * 0.55, 1.7))
		if flame:
			flame.scale = Vector3(0.40, 0.15, 0.3)
			flame.rotation = Vector3(0.28, a, 0.18)
			flame.create_tween().tween_property(flame, "scale:y", 1.7 + (i % 3) * 0.4, 0.16 + (i % 3) * 0.035).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

static func _bolts(root: Node3D, mat: Material, core: Material, tier: int, radius: float) -> void:
	var count := VfxBudget.count(2 + tier / 2, 1)
	for i in count:
		var a := TAU * float(i) / count
		var at := Vector3.ZERO if i == 0 else Vector3(cos(a), 0, sin(a)) * radius * 0.55
		var bolt := SpellSpectacle._mesh(root, lightning_mesh(), mat, at)
		if bolt:
			bolt.scale = Vector3(1.0, 1.0, 1.0)
		var inner := SpellSpectacle._mesh(root, lightning_mesh(), core, at + Vector3(0, 0.01, 0.015))
		if inner:
			inner.scale = Vector3(0.97, 1.0, 0.97)

static func _lotus(root: Node3D, mat: Material, core: Material, shade: Material, tier: int, spores: bool) -> void:
	var count := VfxBudget.count(6 + tier, 4)
	for i in count:
		var a := TAU * i / count
		var petal := SpellSpectacle._mesh(root, SpellSpectacle._sphere_mesh() if spores else SkillCraft.petal_mesh(), shade if i % 2 == 0 else mat, Vector3(sin(a) * 0.9, 0.3, cos(a) * 0.9))
		if petal:
			petal.scale = Vector3(0.42, 1.1 + tier * 0.12, 0.23)
			petal.rotation = Vector3(0.1, a, 0)
			petal.create_tween().tween_property(petal, "rotation:x", 1.1, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var seed := SpellSpectacle._mesh(root, SpellSpectacle._sphere_mesh(), core, Vector3(0, 0.8, 0))
	if seed:
		seed.scale = Vector3.ONE * 0.28
		seed.create_tween().tween_property(seed, "position:y", 2.5, 0.7)

static func _tree(root: Node3D, mat: Material, core: Material, tier: int, tree: bool) -> void:
	if tree:
		var trunk := SpellSpectacle._mesh(root, creature_mesh("treant"), mat)
		if trunk:
			trunk.scale = Vector3(1.4 + tier * 0.1, 0.12, 1.4 + tier * 0.1)
			trunk.create_tween().tween_property(trunk, "scale:y", 1.4 + tier * 0.1, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_crown(root, core, 1.5, 4, false)
	else:
		SpellSpectacle._helix(root, mat, 1.45 + tier * 0.14, 2.7, 2)
		var count := VfxBudget.count(4 + tier, 3)
		for i in count:
			var a := TAU * i / count
			var leaf := SpellSpectacle._mesh(root, SpellSpectacle._crystal_mesh(), core, Vector3(sin(a) * 1.8, 0.65, cos(a) * 1.8))
			if leaf:
				leaf.scale = Vector3(0.2, 0.65, 0.09)
				leaf.rotation = Vector3(0.6, a, 0.4)

static func _beast(root: Node3D, mat: Material, core: Material, shade: Material, kind: String, tier: int) -> void:
	if "dragon" in kind or "drake" in kind:
		SpellSpectacle._dragon(root, mat, 1)
		return
	var idol := Node3D.new()
	root.add_child(idol)
	idol.position = Vector3(0, 0.18, -0.65)
	var size := 0.9 + tier * 0.1
	idol.scale = Vector3.ONE * size * 0.18
	var emerge := idol.create_tween().set_parallel(true)
	emerge.tween_property(idol, "position", Vector3(0, 0.35, 0.7), 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	emerge.tween_property(idol, "scale", Vector3.ONE * size, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	SpellSpectacle._mesh(idol, creature_mesh(kind), mat)
	# Contrasting eyes make the species readable on a bright battlefield.
	var eyes := Vector3(0, 1.8, 0.91)
	if "guardian" in kind or "treant" in kind:
		eyes = Vector3(0, 1.25, 0.34)
	elif "fire" in kind or "muspell" in kind:
		eyes = Vector3(0, 1.65, 0.53)
	SpellSpectacle._spirit_eyes(idol, shade, eyes, 0.22)
	var gem := SpellSpectacle._mesh(idol, SpellSpectacle._crystal_mesh(), core, Vector3(0, 2.45, 0.45))
	if gem:
		gem.scale = Vector3(0.14, 0.26, 0.14)

static func lightning_mesh() -> ArrayMesh:
	if _lightning == null:
		var points := PackedVector3Array([Vector3(0, 6.5, 0), Vector3(-0.4, 5.1, 0), Vector3(0.35, 4.5, 0.1), Vector3(-0.30, 3.0, 0), Vector3(0.24, 2.8, 0), Vector3(0, 0.1, 0)])
		_lightning = SpellSpectacle._tube_mesh(points, 0.095)
	return _lightning

static func shield_mesh() -> ArrayMesh:
	if _shield_shape == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rim := PackedVector3Array([Vector3(0, 1, 0), Vector3(-0.82, 0.57, 0), Vector3(-0.66, -0.37, 0), Vector3(0, -1, 0), Vector3(0.66, -0.37, 0), Vector3(0.82, 0.57, 0)])
		for i in rim.size():
			SpellSpectacle._tri(st, rim[i], rim[(i + 1) % rim.size()], Vector3(0, 0.05, 0.20))
			SpellSpectacle._tri(st, rim[(i + 1) % rim.size()], rim[i], Vector3(0, 0.05, -0.07))
		st.generate_normals()
		_shield_shape = st.commit()
	return _shield_shape

static func creature_mesh(kind: String) -> ArrayMesh:
	# Normalize to a finite set of sculpted totems rather than a cat for every pet.
	var species := "wolf" if "wolf" in kind or "beast" in kind or "wolverine" in kind else "frog" if "frog" in kind else "treant" if "treant" in kind or "guardian" in kind else "flame" if "fire" in kind or "muspell" in kind else "cat"
	if _creatures.has(species):
		return _creatures[species]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sphere := SpellSpectacle._sphere_mesh()
	var crystal := SpellSpectacle._crystal_mesh()
	if species == "treant":
		_append(st, SpellSpectacle._column_mesh(), Vector3(0, 0.9, 0), Vector3(0.34, 1.8, 0.34))
		for i in 7:
			var a := TAU * i / 7.0
			_append(st, crystal, Vector3(sin(a), 1.55 + float(i % 2) * 0.4, cos(a)) * Vector3(0.75, 1, 0.75), Vector3(0.65, 1.0, 0.65))
	elif species == "flame":
		_append(st, sphere, Vector3(0, 1.3, 0), Vector3(0.65, 0.75, 0.55))
		for i in 5:
			var a := TAU * i / 5.0
			_append(st, crystal, Vector3(cos(a) * 0.45, 1.7, sin(a) * 0.45), Vector3(0.3, 0.95, 0.3))
	else:
		var frog := species == "frog"
		_append(st, sphere, Vector3(0, 1.0, 0), Vector3(0.8 if frog else 0.52, 0.52, 0.65))
		_append(st, sphere, Vector3(0, 1.65, 0.46), Vector3(0.7 if frog else 0.48, 0.4, 0.45))
		if species == "wolf":
			_append(st, sphere, Vector3(0, 1.55, 0.88), Vector3(0.28, 0.2, 0.35))
		for side in [-1.0, 1.0]:
			_append(st, sphere if frog else crystal, Vector3(side * 0.36, 2.0, 0.4), Vector3(0.20, 0.2 if frog else 0.43, 0.17))
			for z in [-0.40, 0.45]:
				_append(st, sphere, Vector3(side * (0.65 if frog else 0.38), 0.45, z), Vector3(0.26, 0.25 if frog else 0.42, 0.32))
		if not frog:
			_append(st, crystal, Vector3(0.15, 1.0, -0.78), Vector3(0.22, 0.63, 0.24))
	_creatures[species] = st.commit()
	return _creatures[species]

static func _append(st: SurfaceTool, mesh: Mesh, at: Vector3, size: Vector3) -> void:
	# All pieces must use the same indexing convention. Mixing an indexed
	# sphere/cylinder with unindexed crystals drops the ears/leaves at draw time.
	var key := mesh.get_instance_id()
	if not _sculpt_parts.has(key):
		var part := SurfaceTool.new()
		part.create_from(mesh, 0)
		part.deindex()
		_sculpt_parts[key] = part.commit()
	st.append_from(_sculpt_parts[key], 0, Transform3D(Basis.from_scale(size), at))


static func _forest_bloom(parent: Node3D, origin: Vector3, look: Dictionary) -> void:
	var root := SpellSpectacle._root(parent, origin, "SpellSpectacle_forest_blessing")
	# A large botanical seal opens, then settles into the persistent living arches.
	SkillInk.mark(root, look, Vector3(0, 0.07, 0), 2.5, 1.25, 2)
	var mat := SpellSpectacle._material(look)
	var gold_look := look.duplicate()
	gold_look.primary = look.accent
	var gold := SpellSpectacle._material(gold_look)
	for i in VfxBudget.count(8, 4):
		var angle := TAU * float(i) / VfxBudget.count(8, 4)
		var at := Vector3(sin(angle) * 1.9, 0.08, cos(angle) * 1.9)
		var petal := SpellSpectacle._mesh(root, BuffArt._grove_leaf_mesh(), mat, at)
		if petal:
			petal.rotation = Vector3(0.55, angle, 0.0)
			petal.scale = Vector3(0.03, 0.03, 0.03)
			var tw := petal.create_tween()
			tw.tween_interval(i * 0.025)
			tw.tween_property(petal, "scale", Vector3(1.35, 1.45, 0.75), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(petal, "position:y", 0.6, 0.65)
		var seed := SpellSpectacle._mesh(root, SpellSpectacle._crystal_mesh(), gold, at * Vector3(0.7, 1, 0.7))
		if seed:
			seed.scale = Vector3(0.04, 0.12, 0.04)
			seed.create_tween().tween_property(seed, "position:y", 2.7 + (i % 2) * 0.4, 1.0)
	SpellSpectacle._finish(root, mat, 1.25)
	root.create_tween().tween_method(func(value: float): gold.set_shader_parameter("fade", value), 1.0, 0.0, 1.2)
