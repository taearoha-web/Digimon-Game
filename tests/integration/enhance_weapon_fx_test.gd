extends Node
## The held weapon's own + (EnhanceWeaponFx.apply): nothing to +6, a glow in the
## weapon's own colour at +7 (clearer at +9), shader arcs along it growing +10 .. +14,
## a ring of arcs around the hand only at +15. Quality 0 keeps the glow only, the
## crowd look (light) one cheap arc mesh; never particles or lights; meshes and
## materials are shared.
##   godot --headless --path . res://tests/integration/enhance_weapon_fx_test.tscn

var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _item(look: String) -> Node3D:
	var n := WeaponKit.build(look)
	add_child(n)
	return n


func _arcs(item: Node3D) -> Array:
	return item.find_children(EnhanceWeaponFx.ARC_NAME, "MeshInstance3D", true, false)


func _overlay(item: Node3D) -> Material:
	for m in MeshKit.collect_meshes(item):
		if m.name != EnhanceWeaponFx.ARC_NAME:
			return m.material_overlay
	return null


func _heavy(item: Node3D) -> int:
	return item.find_children("*", "CPUParticles3D", true, false).size() + item.find_children("*", "GPUParticles3D", true, false).size() \
		+ item.find_children("*", "Light3D", true, false).size()


## The look built for +plus: the nodes it added, the overlay, the arc mesh (or null).
func _dress(look: String, plus: int, light := false) -> Dictionary:
	var item := _item(look)
	var before := item.find_children("*", "", true, false).size()
	EnhanceWeaponFx.apply(item, plus, light)
	var arcs := _arcs(item)
	return {"item": item, "added": item.find_children("*", "", true, false).size() - before, "overlay": _overlay(item),
		"arcs": arcs[0] if arcs.size() > 0 else null, "heavy": _heavy(item)}


func _ready() -> void:
	Game.set_process(false)
	var keep_quality := GameSettings.quality
	GameSettings.quality = 2

	# +0 .. +6: nothing at all.
	for plus in range(0, 7):
		var d := _dress("sword_3", plus)
		check(d.added == 0 and d.overlay == null, "+%d: nothing on the weapon" % plus)
		(d.item as Node).queue_free()

	# +7, +8, +9: the glow only, a shader overlay; +9 clearer.
	var g7 := _dress("sword_3", 7)
	var g8 := _dress("sword_3", 8)
	var g9 := _dress("sword_3", 9)
	check(g7.overlay is ShaderMaterial and (g7.overlay as ShaderMaterial).shader == EnhanceWeaponFx.GLOW_SHADER, "+7: a glow shader overlay")
	check(g7.added == 0 and g9.added == 0 and g7.arcs == null and g9.arcs == null, "+7 / +9: no extra nodes, no arcs")
	check(g8.overlay == g7.overlay, "+8 looks like +7 (one shared material)")
	if g7.overlay is ShaderMaterial and g9.overlay is ShaderMaterial:
		var rim7 := float((g7.overlay as ShaderMaterial).get_shader_parameter("rim"))
		var rim9 := float((g9.overlay as ShaderMaterial).get_shader_parameter("rim"))
		check(g9.overlay != g7.overlay and rim9 > rim7 * 1.3, "+9 glows clearer than +7 (rim %.2f > %.2f)" % [rim9, rim7])
	for d in [g7, g8, g9]:
		(d.item as Node).queue_free()

	# The weapon's own colour: a red sword and a violet staff glow differently.
	var red := _dress("sword_3", 9)
	var violet := _dress("staff_6", 9)
	if red.overlay is ShaderMaterial and violet.overlay is ShaderMaterial:
		var tint_red: Color = (red.overlay as ShaderMaterial).get_shader_parameter("tint")
		var tint_violet: Color = (violet.overlay as ShaderMaterial).get_shader_parameter("tint")
		check(tint_red != tint_violet, "two weapons, two glow colours (%s vs %s)" % [tint_red.to_html(false), tint_violet.to_html(false)])
		check(tint_red.v > 0.8 and tint_violet.v > 0.8, "the glow colour is bright (non-dark)")
	else:
		check(false, "the colour probes glow")
	(red.item as Node).queue_free()
	(violet.item as Node).queue_free()

	# +10 .. +14: one arc mesh, more strands every step, no hand ring.
	var last := 0
	var last_intensity := 0.0
	for plus in range(10, 15):
		var d := _dress("sword_3", plus)
		var arcs: MeshInstance3D = d.arcs
		check(arcs != null and d.added == 1, "+%d: one arc mesh (added %d)" % [plus, d.added])
		if arcs != null:
			var strands := int(arcs.get_meta("strands"))
			var mat := arcs.material_override as ShaderMaterial
			var intensity := float(mat.get_shader_parameter("intensity"))
			check(strands > last and intensity > last_intensity, "+%d: more arcs than the step before (%d strands, intensity %.2f)" % [plus, strands, intensity])
			check(int(arcs.get_meta("rings")) == 0, "+%d: no hand ring" % plus)
			check(arcs.mesh.surface_get_array_len(0) == strands * 4, "+%d: the mesh holds %d strand quads" % [plus, strands])
			check(mat.shader == EnhanceWeaponFx.ARC_SHADER and arcs.get_script() == null, "+%d: the arcs move in the shader (no script)" % plus)
			last = strands
			last_intensity = intensity
		check(d.heavy == 0, "+%d: no particles, no lights" % plus)
		(d.item as Node).queue_free()
	check(last == 6, "+14: six strands")

	# +15: +14 and the ring of arcs around the hand (the grip, the item's origin).
	var top := _dress("sword_3", 15)
	var top_arcs: MeshInstance3D = top.arcs
	check(top_arcs != null and int(top_arcs.get_meta("rings")) == EnhanceWeaponFx.RING_PLANES and int(top_arcs.get_meta("strands")) == 6, "+15: six strands and the hand ring")
	if top_arcs != null:
		check(top_arcs.mesh.surface_get_array_len(0) == (6 + EnhanceWeaponFx.RING_PLANES) * 4, "+15: strands and rings in ONE mesh")
		check(top_arcs.mesh.get_aabb().has_point(Vector3.ZERO), "+15: the ring sits around the grip")
	check(top.heavy == 0 and top.added == 1, "+15: still one node, no particles or lights")
	# Shared: a second +15 sword uses the same mesh and materials.
	var twin := _dress("sword_3", 15)
	var twin_arcs: MeshInstance3D = twin.arcs
	check(twin_arcs != null and top_arcs != null and twin_arcs.mesh == top_arcs.mesh and twin_arcs.material_override == top_arcs.material_override and twin.overlay == top.overlay,
		"two +15 swords share the arc mesh, arc material and glow")
	(top.item as Node).queue_free()
	(twin.item as Node).queue_free()

	# Wraps: the ring circles the fist itself.
	var fist := _dress("wraps_7", 15)
	check(fist.arcs != null and int((fist.arcs as MeshInstance3D).get_meta("rings")) > 0, "wraps +15: a ring around the fist")
	(fist.item as Node).queue_free()

	# The crowd look (light): the glow and one slow arc mesh, at most two strands, one ring.
	for plus in [7, 12, 15]:
		var d := _dress("staff_6", plus, true)
		check(d.overlay is ShaderMaterial and d.heavy == 0 and d.added <= 1, "light +%d: glow and at most one node (added %d)" % [plus, d.added])
		if plus >= 10:
			var arcs: MeshInstance3D = d.arcs
			check(arcs != null and int(arcs.get_meta("strands")) <= 2, "light +%d: at most two strands" % plus)
			if arcs != null:
				var mat := arcs.material_override as ShaderMaterial
				check(float(mat.get_shader_parameter("rate")) <= 3.0 and float(mat.get_shader_parameter("layers")) == 1.0, "light +%d: the slow, single-bolt arcs" % plus)
				check(int(arcs.get_meta("rings")) == (1 if plus >= 15 else 0), "light +%d: one ring plane only at +15" % plus)
		(d.item as Node).queue_free()

	# Quality 0: the glow only, even at +15. Quality 1: fewer strands.
	GameSettings.quality = 0
	var low := _dress("sword_3", 15)
	check(low.overlay is ShaderMaterial and low.added == 0 and low.heavy == 0, "quality 0 +15: the glow only")
	(low.item as Node).queue_free()
	GameSettings.quality = 1
	var mid := _dress("sword_3", 14)
	var mid_strands := int((mid.arcs as MeshInstance3D).get_meta("strands")) if mid.arcs != null else 0
	check(mid_strands >= 2 and mid_strands < 6, "quality 1 +14: fewer strands (%d)" % mid_strands)
	(mid.item as Node).queue_free()
	GameSettings.quality = 2

	# plan() says what apply() builds.
	check(EnhanceWeaponFx.plan(6).glow == 0 and EnhanceWeaponFx.plan(7).glow == 1 and EnhanceWeaponFx.plan(9).glow == 2, "plan: glow steps")
	check(EnhanceWeaponFx.plan(10).strands == 2 and EnhanceWeaponFx.plan(14).strands == 6 and EnhanceWeaponFx.plan(14).rings == 0 and EnhanceWeaponFx.plan(15).rings == EnhanceWeaponFx.RING_PLANES, "plan: strands and ring")
	check(EnhanceWeaponFx.plan(15, false, 0).strands == 0 and EnhanceWeaponFx.plan(15, true).strands <= 2, "plan: quality 0 and light")

	# Caches stay small: many weapons, few materials.
	check(EnhanceWeaponFx._glow_cache.size() <= 12 and EnhanceWeaponFx._arc_cache.size() <= 16, "materials cached per colour bucket (%d glow, %d arc)" % [EnhanceWeaponFx._glow_cache.size(), EnhanceWeaponFx._arc_cache.size()])

	GameSettings.quality = keep_quality
	await get_tree().process_frame
	print("ENHANCE WEAPON FX: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED", checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
