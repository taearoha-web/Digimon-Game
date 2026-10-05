# Toon Tale

เกม RPG ล่ามอนสเตอร์สไตล์การ์ตูน เล่นคนเดียวบนมือถือ (เบราว์เซอร์) แรงบันดาลใจจากเกม MMORPG รุ่นคลาสสิก
สร้างด้วย **Godot 4.3** (GL Compatibility) ส่งออกเป็น Web ได้

A solo cartoon action-RPG for the phone browser: four classes, hunting fields,
loot, quests and bosses.

## Play

* **Joystick (left)** move · **drag the right side** to turn the camera · pinch to zoom
* **Big sword button** locks the nearest monster and auto-attacks (the hero chases it)
* **Four skills on the arc** around the sword button (unlock at Lv 1 / 4 / 8 / 12)
* Potion buttons, target switch, menu (top right: stats, bag & equipment, skills, quests)
* Keyboard: WASD move · Space attack · 1-4 skills · H/M potions · Tab target · I/K/C/J menus

## Classes

| Class | Style | Skills |
|---|---|---|
| นักรบ Warrior | melee, tankiest | Power Slash · Shield Bash (stun) · Whirlwind (area) · Battle Roar (buff) |
| นักธนู Archer | ranged, crits | Power Shot · Triple Shot · Arrow Rain (area) · Swift Step (buff) |
| จอมเวท Mage | ranged, area damage | Fireball (burn) · Frost Nova (slow) · Chain Lightning · Meteor |
| พรีสต์ Priest | ranged + self sustain | Holy Bolt · Heal · Holy Nova (area + heal) · Blessing (buff) |

## World

Village (shop, quests, free healer) → Mistwood Meadow (Lv 1-6, boss: Mushroom King)
→ Purple Forest (Lv 7-14, boss: Fire Dragon). Gear drops in four rarities.

## Run & test

```bash
godot --path .                                   # play
godot --headless --path . res://tests/integration/flow_test.tscn   # end-to-end test
godot --headless --path . -s res://tools/check_scripts.gd          # load every script
godot --headless --path . --export-release "Web" build/web/index.html
python3 tools/package_web.py                      # -> build/web_artifact (static hosting)
```

Screenshots: `godot --rendering-driver opengl3 --path . res://tests/tools/tour.tscn -- out_dir warrior field`
(tours: field, town, menus, skills).

## Credits

See [ASSET_CREDITS.md](ASSET_CREDITS.md). Characters: KayKit Adventurers (CC0). Monsters and
nature: Quaternius (CC0). Fonts: SIL OFL. Sound and music: synthesized for this project.
