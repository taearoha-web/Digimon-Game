class_name BootTrace
## Start-up milestones: the first time each one is reached, "[boot] <name> <ms>" is
## printed (milliseconds since the engine started) and, on the web, kept in
## window.toonBoot (as the page's performance.now()) so the page and the web tests can read how long opening took.

static var _seen := {}


static func mark(milestone: String) -> void:
	if _seen.has(milestone):
		return
	var ms := Time.get_ticks_msec()
	_seen[milestone] = ms
	print("[boot] %s %d" % [milestone, ms])
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(window.toonBoot=window.toonBoot||{})[%s]=performance.now()" % JSON.stringify(milestone), true)
