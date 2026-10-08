class_name FaceExpression
extends Node3D
## Tiny deterministic facial animation; it never changes the skeleton or creates
## tweens/particles. Each chosen appearance gets its own blink phase.

var eyes: Array[Node3D] = []
var phase := 0.0
var interval := 4.2
var asleep := false


func _process(delta: float) -> void:
	if has_meta("freeze_expression"):
		return
	phase = fmod(phase + delta, interval)
	var open := 1.0
	if asleep:
		open = 0.08
	elif phase < 0.16:
		# Close quickly and reopen softly, instead of a long doll-like wink.
		open = 1.0 - sin(phase / 0.16 * PI) * 0.92
	for eye in eyes:
		eye.scale.y = open
