class_name L10n
extends RefCounted
## Text helper. The game is Thai-first: strings are written in Thai in code,
## so this is a pass-through kept for shared UI components.

static func t(text: String) -> String:
	return text
