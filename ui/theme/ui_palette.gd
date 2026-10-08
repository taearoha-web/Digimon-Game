class_name UIPalette
extends RefCounted
## Colour tokens shared by the generated theme and runtime-drawn UI.

const BG_DEEP := Color("121d32")
const BG_MID := Color("21334a")
const PANEL := Color(0.07, 0.12, 0.19, 0.96)
const PANEL_GLASS := Color(0.07, 0.12, 0.19, 0.94)
const CARD := Color("293e57")
const CARD_HOVER := Color("365470")
const CARD_BORDER := Color("54657b")

const CYAN := Color("8cddd4")
const ORANGE := Color("eebf74")
const GOLD := Color("f5d692")
const PINK := Color("f2adc0")
const PURPLE := Color("aa9de8")
const SUCCESS := Color("5ad17a")
const DANGER := Color("ff5a6e")
const WARNING := Color("ffd166")

const TEXT := Color("fff4de")
const TEXT_DIM := Color("c6cbd2")
const TEXT_MUTED := Color("8595a8")
const TEXT_DARK := Color("223047")

const HP_HIGH := Color("5ad17a")
const HP_MID := Color("ffd166")
const HP_LOW := Color("ff5a6e")
const SP := Color("8a8cff")
const EXP := Color("8cddd4")

const ATTRIBUTE_COLORS := {
	0: Color("4fc3ff"), # Vaccine
	1: Color("5ad17a"), # Data
	2: Color("c46bff"), # Virus
	3: Color("c9ccd6"), # Free
}

const STAGE_COLORS := [
	Color("c9ccd6"), Color("9ad7ff"), Color("5ad17a"), Color("f5d692"), Color("eebf74"), Color("ff5a9e"),
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
