extends Node
## Effect materials keep their generated shaders alive: the ring holds the most
## recent materials, and the first material of every distinct feature set is
## pinned for good (see MaterialKeeper).
##   godot --headless --path . res://tests/integration/material_keeper_test.tscn
var failures := 0
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _glow(additive: bool, textured: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	MaterialKeeper.keep(m)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if textured:
		m.albedo_texture = VfxKit.soft_dot()
	return m


func _ready() -> void:
	await get_tree().process_frame
	var base := MaterialKeeper.pinned()
	# Four feature sets, many materials each.
	var made: Array[WeakRef] = []
	for i in 40:
		made.append(weakref(_glow(i % 2 == 0, i % 4 < 2)))
	await get_tree().process_frame
	check(MaterialKeeper.pinned() == base + 4, "one pinned material per distinct feature set (%d new)" % (MaterialKeeper.pinned() - base))
	check(MaterialKeeper.held() <= MaterialKeeper.RING_SIZE, "the ring is bounded")
	# Colour, alpha and render priority do not select a shader: no new pin.
	var tinted := _glow(true, true)
	tinted.albedo_color = Color(0.2, 0.4, 0.9, 0.3)
	tinted.render_priority = 3
	await get_tree().process_frame
	check(MaterialKeeper.pinned() == base + 4, "colour and priority share a feature set")
	# A new feature (billboard) is a new set.
	var board := _glow(true, true)
	board.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	await get_tree().process_frame
	check(MaterialKeeper.pinned() == base + 5, "billboarding is its own feature set")
	# Far more materials than the ring holds: every pinned set stays alive.
	for i in MaterialKeeper.RING_SIZE * 3:
		_glow(false, false)
	await get_tree().process_frame
	check(MaterialKeeper.held() == MaterialKeeper.RING_SIZE, "ring stays full")
	var alive := 0
	for key in MaterialKeeper._pinned:
		if is_instance_valid(MaterialKeeper._pinned[key]):
			alive += 1
	check(alive == MaterialKeeper.pinned(), "every pinned material is still alive (%d/%d)" % [alive, MaterialKeeper.pinned()])
	check(MaterialKeeper.keep(null) == null, "keep passes through a null material")
	print("MATERIAL KEEPER: %s | %d checks, %d failures, pinned %d" % ["PASS" if failures == 0 else "FAIL", checks, failures, MaterialKeeper.pinned()])
	get_tree().quit(failures)
