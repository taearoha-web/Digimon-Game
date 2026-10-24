class_name DivineOutfitArt
extends RefCounted
## A colour edition of the original chibi outfit. These decorations stay within
## the tier-three silhouette; the base character supplies the clothes, gloves,
## trousers and shoes. All dimensions use the original chibi skeleton units.

const PALETTES := {
	"warrior": {"body":Color("e5e8ee"), "pants":Color("394857"), "gloves":Color("697b8a"), "boots":Color("465564"), "metal":Color("e4c88e"), "gem":Color("8ecede")},
	"archer": {"body":Color("488875"), "pants":Color("2d514b"), "gloves":Color("786447"), "boots":Color("4a5747"), "metal":Color("c6b37c"), "gem":Color("90d6ab")},
	"assassin": {"body":Color("2e2448"), "pants":Color("1e1a30"), "gloves":Color("3a2c54"), "boots":Color("241d38"), "metal":Color("6e52a8"), "gem":Color("ff5a86")},
	"defender": {"body":Color("3a4f86"), "pants":Color("2a3456"), "gloves":Color("4a5a80"), "boots":Color("2e3550"), "metal":Color("d8c48a"), "gem":Color("9fd6ff")},
	"lancer": {"body":Color("9e4754"), "pants":Color("4c3440"), "gloves":Color("6b4945"), "boots":Color("4e3d43"), "metal":Color("d1a07b"), "gem":Color("eab297")},
	"mage": {"body":Color("414c81"), "pants":Color("34354f"), "gloves":Color("736480"), "boots":Color("42445d"), "metal":Color("b3bdd4"), "gem":Color("bba5e4")},
	"priest": {"body":Color("eee9db"), "pants":Color("709891"), "gloves":Color("b5c4b9"), "boots":Color("72938d"), "metal":Color("d7c491"), "gem":Color("8fd9cf")},
	"summoner": {"body":Color("795576"), "pants":Color("3e4f5b"), "gloves":Color("6a8690"), "boots":Color("425b63"), "metal":Color("d1abaf"), "gem":Color("83c8c9")},
}


static func palette(cls: String) -> Dictionary:
	return PALETTES.get(cls, PALETTES.warrior)


## Uses the same compact, hair-visible pieces as the original Lv1–100 gear.
## No uploaded shells, capes, tall hats, leg coverings, particles or lights.
static func decorate(root: Node3D, kind: String, cls: String, side := 1.0) -> void:
	var colors := palette(cls)
	var tints: Array[Color] = []
	match kind:
		"pauldron":
			ChibiGear.pauldron(root, 3, side)
			tints = [colors.metal, colors.metal.darkened(0.18), colors.gem]
		"chest":
			ChibiGear.chest(root, 3)
			tints = [colors.body.darkened(0.18), colors.metal, colors.gem]
		"belt":
			ChibiGear.belt(root, 3)
			tints = [colors.pants.darkened(0.12), colors.metal]
		"helm":
			ChibiGear.headpiece(root, 3)
			tints = [colors.metal, colors.gem]
		"boots":
			ChibiGear.boot_cuff(root, 3)
			tints = [colors.boots.lightened(0.1), colors.gem]
		_:
			return
	root.set_meta("divine_dye_piece", kind)
	root.set_meta("divine_dye_class", cls)
	var pieces := root.find_children("*", "MeshInstance3D", true, false)
	for i in pieces.size():
		var mesh := pieces[i] as MeshInstance3D
		# MeshKit owns a bounded material cache. Do not mutate the tier-three
		# materials: those are shared with the existing level equipment.
		mesh.material_override = MeshKit.toon(tints[mini(i, tints.size() - 1)])
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.set_meta("no_outline", true)
		mesh.set_meta("polished", true)
		mesh.set_meta("divine_dye", true)
