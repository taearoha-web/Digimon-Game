class_name DialogueLine
extends Resource
## One line of dialogue. [member speaker] and [member text] support variables
## such as {player_name}, {partner_name} and {npc_name} (see [TextVars]).

@export var speaker: String = "{npc_name}"
@export_multiline var text: String = ""
## Optional expression hint for portraits/animations (e.g. &"happy").
@export var emotion: StringName = &""
