class_name SpectacleAssets
extends RefCounted
## Original CC0 textures, retained unchanged with their licenses and SHA-256
## source receipts in assets/vfx. Reused across classes and loaded once.

const TEXTURES := {
	"flame": preload("res://assets/vfx/kenney-particles/flame_01.png"),
	"fire": preload("res://assets/vfx/kenney-particles/fire_01.png"),
	"smoke": preload("res://assets/vfx/kenney-particles/smoke_04.png"),
	"smoke_soft": preload("res://assets/vfx/kenney-particles/smoke_07.png"),
	"spark": preload("res://assets/vfx/kenney-particles/spark_01.png"),
	"flare": preload("res://assets/vfx/rpicster/spotlight_5.png"),
	"magic": preload("res://assets/vfx/kenney-particles/magic_01.png"),
	"circle": preload("res://assets/vfx/kenney-particles/circle_02.png"),
	"swirl": preload("res://assets/vfx/rpicster/effect_4.png"),
	"rays": preload("res://assets/vfx/rpicster/effect_2.png"),
	"star": preload("res://assets/vfx/rpicster/spotlight_8.png"),
	"glow": preload("res://assets/vfx/rpicster/spotlight_1.png"),
	"scorch": preload("res://assets/vfx/kenney-particles/scorch_01.png"),
	"dirt": preload("res://assets/vfx/kenney-particles/dirt_01.png"),
}


static func tex(kind: String) -> Texture2D:
	return TEXTURES.get(kind, TEXTURES["glow"])
