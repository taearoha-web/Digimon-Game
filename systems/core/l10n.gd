class_name L10n
extends RefCounted
## Localisation helpers.
##
## Source strings are English and double as translation keys (see
## res://i18n/*.po). Controls translate their own plain `text` automatically;
## use [method t] for formatted strings ("Lv %d") and in static code.
## Data resources are translated in memory by [method localize] when the
## registry loads or the language changes (the .tres files stay English).

const META_KEY := &"l10n_source"


static func t(text: String) -> String:
	return TranslationServer.translate(text) if text != "" else text


## Translates the given String properties of [param obj] in place. The English
## originals are kept in metadata, so switching language back is lossless.
static func localize(obj: Object, props: Array) -> void:
	if obj == null:
		return
	var source: Dictionary = obj.get_meta(META_KEY, {})
	for prop in props:
		if not source.has(prop):
			source[prop] = obj.get(prop)
		var original = source[prop]
		if original is String:
			obj.set(prop, t(original))
		elif original is Dictionary:
			# Dictionary of display strings (e.g. StarterRoster.taglines).
			var translated := {}
			for key in original.keys():
				translated[key] = t(str(original[key])) if original[key] is String else original[key]
			obj.set(prop, translated)
		elif original is Array:
			# Array of option dictionaries with a "name" (CustomizationCatalog).
			var out: Array[Dictionary] = []
			for entry in original:
				var copy: Dictionary = entry.duplicate()
				if copy.has("name"):
					copy["name"] = t(str(copy["name"]))
				out.append(copy)
			obj.set(prop, out)
	obj.set_meta(META_KEY, source)


## Returns the untranslated (English) value of a localised property.
static func source_of(obj: Object, prop: StringName) -> Variant:
	var source: Dictionary = obj.get_meta(META_KEY, {})
	return source.get(prop, obj.get(prop))
