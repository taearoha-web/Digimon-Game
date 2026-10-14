class_name FrameSlicer
extends RefCounted
## Time-budgeted frame yielding for long build jobs (a zone change). `pace()` gives the
## page a frame back only when the work since the last frame has used up its budget,
## so cheap steps cost nothing and expensive ones never stall for more than ~BUDGET_MS.

const BUDGET_MS := 40.0
static var _mark := 0


## Start measuring from now (call when a job starts).
static func begin() -> void:
	_mark = Time.get_ticks_usec()


## Await a frame if the budget is spent. `tree` null = run straight through (tests, tools).
static func pace(tree: SceneTree) -> void:
	if tree == null:
		return
	if float(Time.get_ticks_usec() - _mark) / 1000.0 >= BUDGET_MS:
		await tree.process_frame
		_mark = Time.get_ticks_usec()
