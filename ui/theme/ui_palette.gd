class_name UIPalette
extends RefCounted
## Colour tokens shared by the generated theme and runtime-drawn UI.

const BG_DEEP := Color("0c1230")
const BG_MID := Color("16204a")
const PANEL := Color(0.071, 0.102, 0.251, 0.93)
const PANEL_GLASS := Color(0.059, 0.09, 0.231, 0.8)
const CARD := Color("1c2858")
const CARD_HOVER := Color("24336e")
const CARD_BORDER := Color("2e3f86")

const CYAN := Color("34e0ff")
const ORANGE := Color("ff7a3d")
const GOLD := Color("ffc93c")
const PINK := Color("ff8fb1")
const PURPLE := Color("8a6bff")
const SUCCESS := Color("5ad17a")
const DANGER := Color("ff5a6e")
const WARNING := Color("ffd166")

const TEXT := Color("f4f7ff")
const TEXT_DIM := Color("a9b4d8")
const TEXT_MUTED := Color("6b759a")
const TEXT_DARK := Color("1b2143")

const HP_HIGH := Color("5ad17a")
const HP_MID := Color("ffd166")
const HP_LOW := Color("ff5a6e")
const SP := Color("8a8cff")
const EXP := Color("34e0ff")

const ATTRIBUTE_COLORS := {
	0: Color("4fc3ff"), # Vaccine
	1: Color("5ad17a"), # Data
	2: Color("c46bff"), # Virus
	3: Color("c9ccd6"), # Free
}

const STAGE_COLORS := [
	Color("c9ccd6"), Color("9ad7ff"), Color("5ad17a"), Color("ffc93c"), Color("ff7a3d"), Color("ff5a9e"),
]


static func hp_color(ratio: float) -> Color:
	if ratio > 0.5:
		return HP_HIGH
	if ratio > 0.2:
		return HP_MID
	return HP_LOW


static func attribute_color(attribute: int) -> Color:
	return ATTRIBUTE_COLORS.get(attribute, TEXT_DIM)


static func stage_color(stage: int) -> Color:
	return STAGE_COLORS[clampi(stage, 0, STAGE_COLORS.size() - 1)]
