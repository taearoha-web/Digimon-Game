class_name WeaponGrip
extends RefCounted
## Model geometry is normalized at its actual handle. This is the separate
## conversion from that model convention into KayKit's hand-slot axes.


static func mount(kind: String) -> Basis:
	match kind:
		"shield", "book", "tome":
			# Face away from the left arm; top points towards the elbow.
			return Basis(Vector3.FORWARD, PI * 0.5)
		"bow":
			# The left arm holds the bow; the right hand draws its string.
			return Basis(Vector3.RIGHT, PI * 0.5)
	return Basis(Vector3.UP, PI)


static func hand_for(kind: String) -> String:
	return "handslot.l" if kind in ["bow", "shield", "book", "tome"] else "handslot.r"
