class_name BootTrace
## Start-up milestones: the first time each one is reached, "[boot] <name> <ms>" is
## printed (milliseconds since the engine started) and, on the web, kept in
## window.toonBoot (as the page's performance.now()) so the page and the web tests can read how long opening took.

static var _seen := {}
## The first zone of a web session prints how long each of its build phases took (Zone._phase).
static var zone_phases := OS.has_feature("web")


static func mark(milestone: String) -> void:
	if _seen.has(milestone):
		return
	var ms := Time.get_ticks_msec()
	_seen[milestone] = ms
	print("[boot] %s %d" % [milestone, ms])
	if milestone == "enter_world_done":
		zone_phases = false
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(window.toonBoot=window.toonBoot||{})[%s]=performance.now()" % JSON.stringify(milestone), true)
