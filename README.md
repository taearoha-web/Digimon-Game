# Toon Tale

เกม RPG ล่ามอนสเตอร์สไตล์การ์ตูน เล่นคนเดียวบนมือถือ (เบราว์เซอร์) แรงบันดาลใจจากเกม MMORPG รุ่นคลาสสิก
สร้างด้วย **Godot 4.3** (GL Compatibility) ส่งออกเป็น Web ได้

A solo cartoon action-RPG for the phone browser: four classes, hunting fields,
loot, quests and bosses.

## Play

* **Joystick (left)** move · **drag the right side** to turn the camera · pinch to zoom
* **Big sword button** locks the nearest monster and auto-attacks (the hero chases it)
* **Four skills on the arc** around the sword button (unlock at Lv 1 / 4 / 8 / 12; first two change with your job)
* Potion buttons, target switch, menu (top right: stats, bag & equipment, skills, quests)
* Keyboard: WASD move · Space attack · 1-4 skills · H/M potions · Tab target · I/K/C/J menus

## Classes

| Class | Style | Skills |
|---|---|---|
| นักรบ Warrior | melee, tankiest | Power Slash · Shield Bash (stun) · Whirlwind (area) · Battle Roar (buff) |
| นักธนู Archer | ranged, crits | Power Shot · Triple Shot · Arrow Rain (area) · Swift Step (buff) |
| จอมเวท Mage | ranged, area damage | Fireball (burn) · Frost Nova (slow) · Chain Lightning · Meteor |
| พรีสต์ Priest | ranged + self sustain | Holy Bolt · Heal · Holy Nova (area + heal) · Blessing (buff) |

## Gear that shows

Every weapon, helm and armor has a look. Wear it and the hero changes: 48 procedural weapon
designs (sword / bow / staff / wand), 12 hats, five outfit styles (tinted per tier) mixed from the
KayKit characters, boot cuffs and a necklace. Items have rendered icons in the bag, shop and on the ground.

## More to do

* **Forge** (blacksmith in the village): enhance gear up to +10 (failure only costs gold), socket gems dropped by
  monsters, set bonuses for 2/3/4 pieces of the same set. Legendary gear and +7 weapons sparkle.
* **Third advancement** at Lv.30 (new skills 3 and 4) and **passive skills** (Lv.10 / 25, up to 5 stars).
* **Daily quests**, 18 **achievements**, a three-wave **arena** with a boss, an ending after the last boss.
* **Minimap**, graphics quality (low / medium / high), camera speed, save backup code (Settings).
* Companion stance (tap its card: follow / aggressive / guard) and a brave or careful personality.
* `godot --headless -s res://tools/balance.gd` prints how long each class takes to level.

## AI party

One AI companion at a time, picked from the Party Broker in the village (any of the four classes,
swap or send home whenever). They follow you, fight the monster you fight, use skills (a priest heals and
buffs you), share every kill's EXP and wear gear that grows with their level. Monsters attack them like the
hero; when they fall they get back up after a few seconds.

## Jobs

At Lv 15 the Job Master in the village splits each class into two branches (1,500 gold):
Paladin / Berserker · Sniper / Storm Hunter · Pyromancer / Cryomancer · Saint / Inquisitor.
A job adds stat bonuses, a ring under the feet and two new skills in place of the first two.

## World

Village (shop, quests, free healer, Job Master) → Mistwood Meadow (Lv 1-6) → Purple Forest (Lv 7-14)
→ Scorching Desert (Lv 15-22) → Eternal Ice Mountain (Lv 23-30) → Raging Volcano (Lv 31-40).
Each field has marked monster camps, one species per camp, and a boss.

## Run & test

```bash
godot --path .                                   # play
godot --headless --path . res://tests/integration/flow_test.tscn   # end-to-end test
godot --headless --path . -s res://tools/check_scripts.gd          # load every script
godot --headless --path . --export-release "Web" build/web/index.html
python3 tools/package_web.py                      # -> build/web_artifact (static hosting)
```

Screenshots: `godot --rendering-driver opengl3 --path . res://tests/tools/tour.tscn -- out_dir warrior field`
(tours: field, town, menus, skills, zones).

## Credits

See [ASSET_CREDITS.md](ASSET_CREDITS.md). Characters: KayKit Adventurers (CC0). Monsters and
nature: Quaternius (CC0). Fonts: SIL OFL. Sound and music: synthesized for this project.
