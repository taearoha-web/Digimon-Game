# Toon Tale

A cute, solo 3D action RPG for landscape phone browsers, built with **Godot 4.3** and the GL Compatibility renderer. Version **0.3.1** refines the storybook visuals, mobile controls, skill effects, progression and save recovery.

## Play

- Left joystick / WASD: move. Drag the right side / right mouse: turn the camera. Pinch / mouse wheel: zoom.
- Sword button / Space: lock a nearby monster and auto-attack. Eight skills sit in one row along the bottom; keyboard shortcuts are 1–8.
- Far-right vertical controls, top to bottom: HP potion, MP potion, auto hunting, target switch. Walk manually to stop auto hunting.
- Menu / I: character, equipment, skills, quests, achievements and settings. H/M use potions; Tab switches targets.

Every hero begins as a **Vagabond**. Customize face, hair, skin and outfit, then choose Warrior, Archer, Mage or Priest at **Lv.10**. Advance at **Lv.20 / 40 / 60 / 80**. Arrange eight skills from each class's active skill pool and upgrade passive skills.

## Adventure

Travel from Mistwood village through ten hunting fields to Lv.100, with the Void field available for endgame adventures. Equip weapons and outfits that appear on the hero, enhance equipment to +10, socket gems, collect set bonuses and earn wings. Travel with one AI companion with follow, aggressive or guard behavior. The village provides shops, storage, healing, skill training, quests and travel crystals.

After Lv.100, earn **Paragon** levels, collect star equipment in the Void, and climb the **Void Tower**. Ranked arena opponents are **AI**, not online players; stronger ranks can heal and dodge. Daily quests and achievements provide additional goals.

## Version 0.3.1

- Eight skills now sit in a single bottom row. HP potion, MP potion, auto and target form a vertical column at the far right. Layout checks cover three aspect ratios and phone safe-area insets.

## Version 0.3.0

- Softer landscape colors, regional landmarks, cottage details and natural camp clearings.
- Sculpted hair, layered eyes and catchlights, blinking, softer character/monster outlines and material finish.
- Class-specific crests, ribbons and elemental accents across all **102 active skills**. Decorative effect limits follow graphics quality and crowding.
- Navy, cream and gold interface, equipped hero preview on the save screen, responsive creator and single-row bottom skill bank.
- Quest rewards track the actual EXP curve; EXP overflowing Lv.100 continues into Paragon.
- Save imports show a preview and destination, validate nested data and preserve the current save if writing fails. Restoring a character rebuilds the active scene.
- The web loader decompresses files as streams to avoid accumulating another complete compressed buffer.

## Saves

Four save slots are stored in the current browser/device. Use **Settings → สำรอง / นำเข้าเซฟ** to copy a backup code before changing devices or clearing browser data. Review the character and destination slot before restoring. Arena/tower backups resume safely in town. Saves are local; there is no account or cloud synchronization.

## Run and validate

Open `project.godot` with Godot 4.3, or:

```bash
godot --headless --editor --import --path .
godot --path .
godot --headless --path . -s res://tools/check_scripts.gd
godot --headless --path . -s res://tests/integration/character_finish_test.gd
godot --headless --path . res://tests/integration/save_progression_test.tscn
godot --headless --path . res://tests/integration/skill_presentation_test.tscn
godot --headless --path . res://tests/tools/ui_polish_review.tscn
godot --headless --path . res://tests/integration/flow_test.tscn
node tools/test_web_loader.mjs
```

Tests create and delete game saves: run them with a separate `XDG_DATA_HOME` on Linux. The GitHub Actions workflow pins Godot 4.3 and isolates save, UI and integration fixtures. Character checks cover blinking, hair geometry and material reuse; the headless UI check verifies touch-control spacing and all eight populated skill slots. The balance simulator is a rough combat estimate, not a complete playthrough: `godot --headless --path . -s res://tools/balance.gd`.

## Build the browser game

Install the matching Godot 4.3 Web export templates. The project uses the single-threaded web export.

```bash
mkdir -p build/web
godot --headless --path . --export-release "Web" build/web/index.html
python3 tools/package_web.py --pages docs/play
```

`build/web_artifact` is suitable for static hosting. `docs/play` adds the web app manifest and iPhone home-screen metadata. Publishing source changes alone does not rebuild the existing browser bundle; export and package it before publishing a release.

## Visual review

Actual captures from the updated game: [heroes](docs/screenshots/v0.3.0/heroes.png), [representative skill effects](docs/screenshots/v0.3.0/skills.png), [eight-slot HUD](docs/screenshots/v0.3.1/hud.png), and [inventory](docs/screenshots/v0.3.0/inventory.png).

```bash
godot --rendering-driver opengl3 --path . res://tests/tools/tour.tscn -- /tmp/toon-shots warrior field
godot --rendering-driver opengl3 --path . res://tests/tools/look_preview.tscn -- /tmp/heroes.png classes
godot --rendering-driver opengl3 --path . res://tests/tools/monster_preview.tscn -- /tmp/monsters.png zone:meadow
godot --rendering-driver opengl3 --path . res://tests/tools/ui_polish_review.tscn -- /tmp/toon-ui-shots
```

Inspect menus, touch targets, boss telegraphs and crowded skill effects on representative phones. Desktop software-renderer timings do not establish mobile performance.

## Credits

See [ASSET_CREDITS.md](ASSET_CREDITS.md). KayKit Adventurers and Quaternius models are CC0. Fonts are SIL OFL. Audio credits and source licenses are retained with the project.
