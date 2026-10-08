extends SceneTree
## Generates the project-wide UI theme (res://ui/theme/game_theme.tres) and
## the shared font variations. Colours come from UIPalette.
##
## Usage: godot --headless --path . -s res://tools/generate_theme.gd
## Re-running overwrites the theme; tweak values here, not in the .tres.

const OUT_THEME := "res://ui/theme/game_theme.tres"
const FONT_DIR := "res://ui/theme/fonts"
const P = preload("res://ui/theme/ui_palette.gd")

var body_font: FontVariation
var bold_font: FontVariation
var heading_font: FontVariation


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(FONT_DIR)
	_make_fonts()
	var theme := Theme.new()
	theme.default_font = body_font
	theme.default_font_size = 18
	_button_styles(theme)
	_label_styles(theme)
	_panel_styles(theme)
	_input_styles(theme)
	_bar_styles(theme)
	_range_styles(theme)
	_scroll_styles(theme)
	_misc_styles(theme)
	var err := ResourceSaver.save(theme, OUT_THEME)
	print("generate_theme: ", error_string(err))
	quit()


func _make_fonts() -> void:
	var nunito: FontFile = load("res://assets/fonts/Nunito-Variable.ttf")
	var fredoka: FontFile = load("res://assets/fonts/Fredoka-Variable.ttf")
	var system_fallback := SystemFont.new()
	system_fallback.font_names = PackedStringArray(["sans-serif", "Noto Sans", "Roboto", "Arial"])
	# Thai glyphs (Fredoka/Nunito are Latin-only): Noto Sans Thai for text,
	# Mitr for headings. Both SIL OFL.
	var noto_thai: FontFile = load("res://assets/fonts/NotoSansThai-Variable.ttf")
	var mitr: FontFile = load("res://assets/fonts/Mitr-Medium.ttf")
	var thai_body := FontVariation.new()
	thai_body.base_font = noto_thai
	thai_body.variation_opentype = {"wght": 600}
	var thai_bold := FontVariation.new()
	thai_bold.base_font = noto_thai
	thai_bold.variation_opentype = {"wght": 750}
	var fallbacks: Array[Font] = [thai_body, system_fallback]

	body_font = FontVariation.new()
	body_font.base_font = nunito
	body_font.variation_opentype = {"wght": 650}
	body_font.fallbacks = fallbacks
	ResourceSaver.save(body_font, FONT_DIR + "/body_font.tres")

	bold_font = FontVariation.new()
	bold_font.base_font = nunito
	bold_font.variation_opentype = {"wght": 850}
	var bold_fallbacks: Array[Font] = [thai_bold, system_fallback]
	bold_font.fallbacks = bold_fallbacks
	ResourceSaver.save(bold_font, FONT_DIR + "/bold_font.tres")

	heading_font = FontVariation.new()
	heading_font.base_font = fredoka
	heading_font.variation_opentype = {"wght": 600}
	var heading_fallbacks: Array[Font] = [mitr, system_fallback]
	heading_font.fallbacks = heading_fallbacks
	ResourceSaver.save(heading_font, FONT_DIR + "/heading_font.tres")

	# Reload so the theme references the font files instead of embedding copies.
	body_font = ResourceLoader.load(FONT_DIR + "/body_font.tres", "", ResourceLoader.CACHE_MODE_REPLACE)
	bold_font = ResourceLoader.load(FONT_DIR + "/bold_font.tres", "", ResourceLoader.CACHE_MODE_REPLACE)
	heading_font = ResourceLoader.load(FONT_DIR + "/heading_font.tres", "", ResourceLoader.CACHE_MODE_REPLACE)


func _box(bg: Color, border := Color.TRANSPARENT, border_width := 0, radius := 16, margin := Vector4(18, 10, 18, 10)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = margin.x
	sb.content_margin_top = margin.y
	sb.content_margin_right = margin.z
	sb.content_margin_bottom = margin.w
	sb.anti_aliasing = true
	sb.corner_detail = 8
	return sb


func _with_shadow(sb: StyleBoxFlat, size := 10, alpha := 0.35, offset := Vector2(0, 4)) -> StyleBoxFlat:
	sb.shadow_color = Color(0, 0, 0, alpha)
	sb.shadow_size = size
	sb.shadow_offset = offset
	return sb


func _button_set(theme: Theme, type: String, bg: Color, border: Color, font_color: Color, radius := 18,
		hover_bg := Color(), pressed_bg := Color()) -> void:
	if hover_bg == Color():
		hover_bg = bg.lightened(0.12)
	if pressed_bg == Color():
		pressed_bg = bg.darkened(0.15)
	theme.set_stylebox("normal", type, _with_shadow(_box(bg, border, 2, radius), 6, 0.3, Vector2(0, 3)))
	theme.set_stylebox("hover", type, _with_shadow(_box(hover_bg, border.lightened(0.3), 2, radius), 8, 0.35, Vector2(0, 3)))
	theme.set_stylebox("pressed", type, _box(pressed_bg, border, 2, radius, Vector4(18, 12, 18, 8)))
	theme.set_stylebox("hover_pressed", type, _box(pressed_bg, border, 2, radius, Vector4(18, 12, 18, 8)))
	var disabled := _box(Color(bg.r, bg.g, bg.b, 0.35), Color(border.r, border.g, border.b, 0.2), 2, radius)
	theme.set_stylebox("disabled", type, disabled)
	var focus := _box(Color.TRANSPARENT, P.CYAN, 3, radius + 2)
	focus.draw_center = false
	focus.set_expand_margin_all(3)
	theme.set_stylebox("focus", type, focus)
	theme.set_color("font_color", type, font_color)
	theme.set_color("font_hover_color", type, font_color.lightened(0.1))
	theme.set_color("font_pressed_color", type, font_color)
	theme.set_color("font_hover_pressed_color", type, font_color)
	theme.set_color("font_focus_color", type, font_color)
	theme.set_color("font_disabled_color", type, Color(font_color.r, font_color.g, font_color.b, 0.4))
	theme.set_color("icon_normal_color", type, Color.WHITE)
	theme.set_font("font", type, heading_font)
	theme.set_font_size("font_size", type, 19)
	theme.set_constant("h_separation", type, 10)


func _button_styles(theme: Theme) -> void:
	_button_set(theme, "Button", P.CARD, Color(P.GOLD.r, P.GOLD.g, P.GOLD.b, 0.32), P.TEXT, 16, P.CARD_HOVER, P.BG_DEEP)

	theme.add_type("PrimaryButton")
	theme.set_type_variation("PrimaryButton", "Button")
	_button_set(theme, "PrimaryButton", P.GOLD, Color("fff0c5"), P.TEXT_DARK, 18, Color("ffe6ad"), Color("dba957"))
	theme.set_color("font_outline_color", "PrimaryButton", Color("8a3510"))
	theme.set_constant("outline_size", "PrimaryButton", 0)
	theme.set_font_size("font_size", "PrimaryButton", 21)

	theme.add_type("AccentButton")
	theme.set_type_variation("AccentButton", "Button")
	_button_set(theme, "AccentButton", Color("1f8fb8"), Color("aef3ff"), Color.WHITE, 20, Color("27a7d4"), Color("17708f"))
	theme.set_color("font_outline_color", "AccentButton", Color("0b3f55"))
	theme.set_constant("outline_size", "AccentButton", 4)

	theme.add_type("DangerButton")
	theme.set_type_variation("DangerButton", "Button")
	_button_set(theme, "DangerButton", Color("c83c4f"), Color("ffc2ca"), Color.WHITE, 18)

	theme.add_type("GhostButton")
	theme.set_type_variation("GhostButton", "Button")
	_button_set(theme, "GhostButton", Color(0.1, 0.14, 0.32, 0.55), Color(1, 1, 1, 0.25), P.TEXT, 18, Color(0.16, 0.22, 0.46, 0.7), Color(0.06, 0.09, 0.22, 0.8))

	theme.add_type("TabButton")
	theme.set_type_variation("TabButton", "Button")
	_button_set(theme, "TabButton", Color(0.1, 0.14, 0.32, 0.6), Color(1, 1, 1, 0.1), P.TEXT_DIM, 16, Color(0.16, 0.22, 0.46, 0.8), Color(0.2, 0.55, 0.75, 1.0))
	theme.set_stylebox("pressed", "TabButton", _box(Color("1f8fb8"), P.CYAN, 2, 16))
	theme.set_stylebox("hover_pressed", "TabButton", _box(Color("27a7d4"), P.CYAN, 2, 16))
	theme.set_color("font_pressed_color", "TabButton", Color.WHITE)
	theme.set_color("font_hover_pressed_color", "TabButton", Color.WHITE)
	theme.set_font_size("font_size", "TabButton", 17)

	theme.add_type("ChoiceButton")
	theme.set_type_variation("ChoiceButton", "Button")
	_button_set(theme, "ChoiceButton", Color(0.13, 0.19, 0.42, 0.9), Color(1, 1, 1, 0.12), P.TEXT, 14, Color(0.18, 0.26, 0.55, 1.0), Color(0.2, 0.55, 0.75, 1.0))
	theme.set_stylebox("pressed", "ChoiceButton", _box(Color("1f6f9a"), P.CYAN, 3, 14))
	theme.set_stylebox("hover_pressed", "ChoiceButton", _box(Color("2583b4"), P.CYAN, 3, 14))
	theme.set_font_size("font_size", "ChoiceButton", 16)

	theme.add_type("IconButton")
	theme.set_type_variation("IconButton", "Button")
	_button_set(theme, "IconButton", Color(0.1, 0.14, 0.32, 0.75), Color(1, 1, 1, 0.25), P.TEXT, 40, Color(0.16, 0.22, 0.46, 0.9), Color(0.06, 0.09, 0.22, 0.9))
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var sb: StyleBoxFlat = theme.get_stylebox(state, "IconButton")
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10

	# CheckButton as a large mobile-friendly toggle.
	var toggle_on: Texture2D = load("res://assets/icons/ui/toggle_on.svg")
	var toggle_off: Texture2D = load("res://assets/icons/ui/toggle_off.svg")
	theme.set_icon("checked", "CheckButton", toggle_on)
	theme.set_icon("unchecked", "CheckButton", toggle_off)
	theme.set_icon("checked_disabled", "CheckButton", toggle_on)
	theme.set_icon("unchecked_disabled", "CheckButton", toggle_off)
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		theme.set_stylebox(state, "CheckButton", empty)
	theme.set_font("font", "CheckButton", body_font)
	theme.set_font_size("font_size", "CheckButton", 18)
	theme.set_color("font_color", "CheckButton", P.TEXT)
	theme.set_color("font_hover_color", "CheckButton", Color.WHITE)
	theme.set_color("font_pressed_color", "CheckButton", Color.WHITE)
	theme.set_color("font_hover_pressed_color", "CheckButton", Color.WHITE)


func _label_styles(theme: Theme) -> void:
	theme.set_color("font_color", "Label", P.TEXT)
	theme.set_color("font_outline_color", "Label", Color(0.03, 0.05, 0.14))
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))

	var variations := {
		"TitleLabel": [heading_font, 48, P.TEXT, 3],
		"HeaderLabel": [heading_font, 27, P.TEXT, 1],
		"SubHeaderLabel": [heading_font, 19, P.CYAN, 0],
		"ValueLabel": [heading_font, 18, Color.WHITE, 0],
		"BoldLabel": [bold_font, 18, P.TEXT, 0],
		"DimLabel": [body_font, 15, P.TEXT_DIM, 0],
		"SmallLabel": [body_font, 14, P.TEXT_DIM, 0],
		"HudLabel": [bold_font, 16, Color.WHITE, 5],
		"NameTagLabel": [heading_font, 19, Color.WHITE, 6],
	}
	for type_name in variations.keys():
		var v: Array = variations[type_name]
		theme.add_type(type_name)
		theme.set_type_variation(type_name, "Label")
		theme.set_font("font", type_name, v[0])
		theme.set_font_size("font_size", type_name, v[1])
		theme.set_color("font_color", type_name, v[2])
		theme.set_constant("outline_size", type_name, v[3])
		theme.set_color("font_outline_color", type_name, Color(0.03, 0.05, 0.14, 0.9))
	theme.set_color("font_shadow_color", "TitleLabel", Color(0.03, 0.06, 0.10, 0.4))
	theme.set_constant("shadow_offset_x", "TitleLabel", 0)
	theme.set_constant("shadow_offset_y", "TitleLabel", 6)

	theme.set_font("normal_font", "RichTextLabel", body_font)
	theme.set_font("bold_font", "RichTextLabel", bold_font)
	theme.set_font_size("normal_font_size", "RichTextLabel", 18)
	theme.set_font_size("bold_font_size", "RichTextLabel", 18)
	theme.set_color("default_color", "RichTextLabel", P.TEXT)


func _panel_styles(theme: Theme) -> void:
	var main := _with_shadow(_box(P.PANEL, Color(P.GOLD.r, P.GOLD.g, P.GOLD.b, 0.35), 2, 24, Vector4(22, 18, 22, 18)), 14, 0.4)
	theme.set_stylebox("panel", "PanelContainer", main)
	theme.set_stylebox("panel", "Panel", main)

	var styles := {
		"GlassPanel": _box(P.PANEL_GLASS, Color(1, 1, 1, 0.12), 2, 20, Vector4(16, 12, 16, 12)),
		"CardPanel": _with_shadow(_box(P.CARD, P.CARD_BORDER, 2, 18, Vector4(16, 14, 16, 14)), 6, 0.3),
		"CardPanelSelected": _with_shadow(_box(P.CARD_HOVER, P.GOLD, 4, 18, Vector4(16, 14, 16, 14)), 14, 0.45),
		"ChipPanel": _box(Color(1, 1, 1, 0.1), Color(1, 1, 1, 0.18), 1, 12, Vector4(10, 3, 10, 3)),
		"DialoguePanel": _with_shadow(_box(Color(0.05, 0.08, 0.2, 0.95), Color(P.CYAN.r, P.CYAN.g, P.CYAN.b, 0.6), 3, 24, Vector4(26, 20, 26, 18)), 16, 0.45),
		"NameTagPanel": _box(P.ORANGE, Color("ffd9c2"), 2, 14, Vector4(16, 4, 16, 4)),
		"HudPanel": _box(Color(0.05, 0.08, 0.2, 0.72), Color(1, 1, 1, 0.14), 2, 18, Vector4(14, 10, 14, 10)),
		"DarkPanel": _box(Color(0.03, 0.05, 0.13, 0.85), Color(1, 1, 1, 0.08), 1, 14, Vector4(12, 8, 12, 8)),
		"ToastPanel": _with_shadow(_box(Color(0.07, 0.11, 0.27, 0.95), P.CYAN, 2, 16, Vector4(18, 10, 18, 10)), 10, 0.4),
	}
	for type_name in styles.keys():
		theme.add_type(type_name)
		theme.set_type_variation(type_name, "PanelContainer")
		theme.set_stylebox("panel", type_name, styles[type_name])


func _input_styles(theme: Theme) -> void:
	var normal := _box(Color(0.04, 0.07, 0.18, 0.95), Color(P.CYAN.r, P.CYAN.g, P.CYAN.b, 0.5), 2, 16, Vector4(18, 10, 18, 10))
	var focus := _box(Color(0.05, 0.09, 0.22, 1.0), P.CYAN, 3, 16, Vector4(18, 10, 18, 10))
	theme.set_stylebox("normal", "LineEdit", normal)
	theme.set_stylebox("focus", "LineEdit", focus)
	theme.set_stylebox("read_only", "LineEdit", normal)
	theme.set_font("font", "LineEdit", heading_font)
	theme.set_font_size("font_size", "LineEdit", 26)
	theme.set_color("font_color", "LineEdit", Color.WHITE)
	theme.set_color("font_placeholder_color", "LineEdit", P.TEXT_MUTED)
	theme.set_color("caret_color", "LineEdit", P.CYAN)
	theme.set_color("selection_color", "LineEdit", Color(P.GOLD.r, P.GOLD.g, P.GOLD.b, 0.35))
	theme.set_constant("caret_width", "LineEdit", 3)


func _bar_styles(theme: Theme) -> void:
	var bg := _box(Color(0.02, 0.04, 0.12, 0.9), Color(1, 1, 1, 0.14), 1, 8, Vector4(0, 0, 0, 0))
	var fill := _box(P.CYAN, Color.TRANSPARENT, 0, 8, Vector4(0, 0, 0, 0))
	theme.set_stylebox("background", "ProgressBar", bg)
	theme.set_stylebox("fill", "ProgressBar", fill)
	theme.set_font("font", "ProgressBar", bold_font)
	theme.set_font_size("font_size", "ProgressBar", 11)
	theme.set_color("font_color", "ProgressBar", Color.WHITE)
	for pair in [["HPBar", P.HP_HIGH], ["SPBar", P.SP], ["EXPBar", P.EXP], ["StatBar", P.ORANGE]]:
		var type_name: String = pair[0]
		theme.add_type(type_name)
		theme.set_type_variation(type_name, "ProgressBar")
		theme.set_stylebox("background", type_name, bg)
		theme.set_stylebox("fill", type_name, _box(pair[1], Color.TRANSPARENT, 0, 8, Vector4(0, 0, 0, 0)))


func _range_styles(theme: Theme) -> void:
	var track := _box(Color(0.04, 0.07, 0.18, 1.0), Color(1, 1, 1, 0.15), 1, 8, Vector4(0, 7, 0, 7))
	var filled := _box(P.CYAN, Color.TRANSPARENT, 0, 8, Vector4(0, 7, 0, 7))
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", filled)
	theme.set_stylebox("grabber_area_highlight", "HSlider", filled)
	theme.set_icon("grabber", "HSlider", load("res://assets/icons/ui/slider_grabber.svg"))
	theme.set_icon("grabber_highlight", "HSlider", load("res://assets/icons/ui/slider_grabber_hl.svg"))
	theme.set_icon("grabber_disabled", "HSlider", load("res://assets/icons/ui/slider_grabber.svg"))


func _scroll_styles(theme: Theme) -> void:
	var track := _box(Color(1, 1, 1, 0.04), Color.TRANSPARENT, 0, 6, Vector4(4, 4, 4, 4))
	var grab := _box(Color(P.CYAN.r, P.CYAN.g, P.CYAN.b, 0.45), Color.TRANSPARENT, 0, 6, Vector4(4, 4, 4, 4))
	var grab_hl := _box(Color(P.CYAN.r, P.CYAN.g, P.CYAN.b, 0.75), Color.TRANSPARENT, 0, 6, Vector4(4, 4, 4, 4))
	for type_name in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", type_name, track)
		theme.set_stylebox("scroll_focus", type_name, track)
		theme.set_stylebox("grabber", type_name, grab)
		theme.set_stylebox("grabber_highlight", type_name, grab_hl)
		theme.set_stylebox("grabber_pressed", type_name, grab_hl)
	theme.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())


func _misc_styles(theme: Theme) -> void:
	theme.set_stylebox("panel", "TooltipPanel", _box(P.BG_MID, P.CYAN, 1, 10, Vector4(10, 6, 10, 6)))
	theme.set_color("font_color", "TooltipLabel", P.TEXT)
	theme.set_stylebox("separator", "HSeparator", _box(Color(1, 1, 1, 0.12), Color.TRANSPARENT, 0, 1, Vector4(0, 1, 0, 1)))
	theme.set_constant("separation", "HSeparator", 12)
	theme.set_constant("separation", "VBoxContainer", 10)
	theme.set_constant("separation", "HBoxContainer", 10)
	theme.set_constant("h_separation", "GridContainer", 12)
	theme.set_constant("v_separation", "GridContainer", 12)
