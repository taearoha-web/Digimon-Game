class_name BurstGuard
extends RefCounted
## (Off in the guild war since 27 Nov 2026: real damage there; still on in the other
## modes that call it.) Keeps a fight from being decided by one hit: no single hit takes more than
## HIT_CAP of a fighter's max HP and everything landing inside BURST_WINDOW seconds of game
## time (GameClock) is capped at BURST_CAP, however many enemies pile on. Shared by the
## hero and every AI.

const HIT_CAP := 0.2
const BURST_CAP := 0.36
const BURST_WINDOW := 2.0

static var _windows: Dictionary = {}
## Tests of the old capped war switch it back on.
static var war_capped := false


## Returns how much of `amount` may land on `victim_id` right now and records it.
static func take(victim_id: int, amount: int, max_hp: int, now := -1.0) -> int:
	# The guild war measures real attack against real defence (the owner's rule): no
	# per-hit or burst cap there, so a blow never shrinks to 1.
	if not war_capped and Game.current_zone == &"guildwar":
		return amount
	if now < 0.0:
		now = GameClock.now()
	var allowed := mini(amount, maxi(1, int(float(max_hp) * HIT_CAP)))
	var keep: Array = []
	var inside := 0
	for entry in _windows.get(victim_id, []):
		if now - float(entry[0]) <= BURST_WINDOW:
			keep.append(entry)
			inside += int(entry[1])
	var room := int(float(max_hp) * BURST_CAP) - inside
	allowed = clampi(allowed, 1, maxi(room, 1))
	keep.append([now, allowed])
	_windows[victim_id] = keep
	return allowed


static func forget(victim_id: int) -> void:
	_windows.erase(victim_id)


static func clear() -> void:
	_windows.clear()
