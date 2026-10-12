# Toon Tale skill medallions

152 original vector illustrations authored for Toon Tale. No third-party images,
fonts, downloads, external API calls or runtime generation are used.

Source: `tools/make_skill_icons.py`. Each skill has an explicit composition based
on its gameplay description, using shared drawing vocabulary and palettes.
`tools/skill_icon_catalogue.json` records IDs, families and foreground hashes.

Godot imports each SVG at 192 × 192. `SkillIcons` caches textures on demand; the
HUD, skill menu, trainer and timed buffs all resolve the same skill illustration.

Regenerate with `python3 tools/make_skill_icons.py`, import using Godot 4.3 and run
`tests/integration/skill_icons_test.tscn`. Use its raster previews to review the
smallest hotbar size after changing any art, especially arrow shafts and trails.
