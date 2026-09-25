class_name TextVars
extends RefCounted
## Replaces {variables} in dialogue/UI text.
##
## Values are escaped for RichTextLabel BBCode, so a player named "[b]x" can
## never inject markup.


## Builds the default variable set from the current game state.
static func default_context() -> Dictionary:
	var ctx := {
		"player_name": L10n.t("Tamer"),
		"partner_name": L10n.t("Partner"),
	}
	var game_state = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() else null
	if game_state:
		if game_state.profile and game_state.profile.player_name != "":
			ctx["player_name"] = game_state.profile.player_name
		var lead = game_state.roster.get_lead() if game_state.roster else null
		if lead:
			ctx["partner_name"] = lead.get_display_name()
	return ctx


static func format(text: String, context: Dictionary = {}, escape_bbcode := true) -> String:
	var ctx := default_context()
	ctx.merge(context, true)
	var result := text
	for key in ctx.keys():
		var value := str(ctx[key])
		if escape_bbcode:
			value = escape(value)
		result = result.replace("{%s}" % key, value)
	return result


static func escape(value: String) -> String:
	# "[lb]" renders a literal "[" in RichTextLabel; escape before any other tag.
	return value.replace("[", "[lb]")
