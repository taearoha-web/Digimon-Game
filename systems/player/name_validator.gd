class_name NameValidator
extends RefCounted
## Validates and sanitises the player name.

const MIN_LENGTH := 1
const MAX_LENGTH := 12
## Characters rejected to keep names safe for BBCode, file names and logs.
const FORBIDDEN := "[]{}<>\\|/`~^=+*#@$%&;:\"\t\n\r"


## Removes control characters / forbidden symbols and collapses whitespace.
static func sanitize(raw: String) -> String:
	var cleaned := ""
	for i in raw.length():
		var c := raw[i]
		var code := c.unicode_at(0)
		if code < 32 or (code >= 127 and code < 160):
			continue
		# Zero-width and bidi control characters.
		if code in [0x200B, 0x200C, 0x200D, 0x200E, 0x200F, 0x202A, 0x202B, 0x202C, 0x202D, 0x202E, 0xFEFF]:
			continue
		if FORBIDDEN.contains(c):
			continue
		cleaned += c
	# Collapse runs of whitespace.
	var parts := cleaned.split(" ", false)
	cleaned = " ".join(parts).strip_edges()
	if cleaned.length() > MAX_LENGTH:
		cleaned = cleaned.substr(0, MAX_LENGTH).strip_edges()
	return cleaned


## Returns an error message, or "" when [param raw] is acceptable.
static func validate(raw: String) -> String:
	var cleaned := sanitize(raw)
	if cleaned.length() < MIN_LENGTH:
		return L10n.t("Please enter a name.")
	if raw.strip_edges().length() > MAX_LENGTH:
		return L10n.t("Names can be at most %d characters.") % MAX_LENGTH
	var has_visible := false
	for i in cleaned.length():
		if cleaned[i] != " " and cleaned[i] != "." and cleaned[i] != "-" and cleaned[i] != "_" and cleaned[i] != "'":
			has_visible = true
			break
	if not has_visible:
		return L10n.t("Names need at least one letter or number.")
	return ""
