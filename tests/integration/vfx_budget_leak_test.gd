extends Node3D
## When the VFX particle budget is spent, bursts that are never shown must be freed, not left
## in the scene disabled: a long ten-fighter war used to leak ~8 emitters a second (nodes
## 4,000 -> 15,000 in 25 minutes, FPS 26 -> 15 on an iPhone).
## godot --headless --path . res://tests/integration/vfx_budget_leak_test.tscn
var failures: Array[String] = []
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)


func _emitters(root: Node) -> int:
	return root.find_children("*", "CPUParticles3D", true, false).size()


func _ready() -> void:
	GameSettings.load_settings()
	GameSettings.quality = 2
	# Spend the whole budget, as a big fight does.
	VfxBudget._particles = VfxBudget.particle_limit()
	var holder := Node3D.new()
	add_child(holder)
	for i in 80:
		VfxKit.sparks(holder, Vector3(i, 0, 0), Color.WHITE, 22)
		VfxArt.motes(holder, Vector3(i, 0, 0), Color.WHITE, "ember", 12)
	check(_emitters(holder) > 0, "the bursts were created")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	check(_emitters(holder) == 0, "bursts refused by the spent budget are freed (%d left)" % _emitters(holder))
	# With budget available they are shown and freed after their lifetime.
	VfxBudget._particles = 0
	for i in 20:
		VfxKit.sparks(holder, Vector3(i, 0, 0), Color.WHITE, 6, 3.0, 0.2)
	await get_tree().process_frame
	check(_emitters(holder) == 20, "bursts inside the budget are kept while they play")
	await get_tree().create_timer(1.0).timeout
	check(_emitters(holder) == 0, "and freed when they end (%d left)" % _emitters(holder))
	VfxBudget._particles = 0
	print("VFX BUDGET LEAK: %d checks, %d failures" % [checks, failures.size()])
	if failures.is_empty():
		print("PASS")
	get_tree().quit(1 if failures.size() > 0 else 0)
