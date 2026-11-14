class_name Announcer
extends RefCounted
## Server-wide announcements (a jackpot drop, the rare dragon appearing): a banner on the
## HUD and a line in the world chat for everyone, the real players online included.
## CONTRACT STUB (docs/SKY_ISLE_PLAN.md): the world team writes the banner, the chat line
## and the online relay; broadcast() and its arguments stay.

## Shows [param text] to everyone. [param kind]: "jackpot" or "rare".
static func broadcast(text: String, kind := "jackpot") -> void:
	if kind != "" and text != "":
		Game.say(text, &"quest")
