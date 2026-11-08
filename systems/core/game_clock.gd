class_name GameClock
extends Node
## The game's own clock: game time, which runs with Engine.time_scale (a hit-stop or an
## ultimate's slow motion slows it; a test's fast-forward speeds it up) and stops while
## the tree is paused. The monsters' and AI players' combat timing (cast, swing and
## animation locks, spawn guards, buffs and marks, area warnings, threat fading) reads it
## (GameClock.msec() / GameClock.now()), so a fight plays the same at any time scale and
## on any machine: on the wall clock (Time.get_ticks_msec) a sim run at 4x on a slow
## runner was a fight in slow motion with the locks taking four times their share.
## The autoload (GameClockTicker) advances it by the scaled physics step at the start of
## every physics frame (it is the first in the tree). The hero, its companions and the
## buff icons (BuffBook) stay on the wall clock.

static var _ms := 0.0


## Game milliseconds since the start.
static func msec() -> int:
	return int(_ms)


## Game seconds since the start.
static func now() -> float:
	return _ms * 0.001


func _ready() -> void:
	process_priority = -1000
	process_physics_priority = -1000


func _physics_process(delta: float) -> void:
	_ms += delta * 1000.0
