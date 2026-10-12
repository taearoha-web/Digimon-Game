# Weapon grip and motion review — 0.7.1

This release fixes actual equipment placement and the transitions between carrying, running and fighting. It uses the same game, character models and saved equipment.

## Corrections

- Normalize swords, staffs, wands, lanterns, bows and spears around their modelled handles. Locate each shield's back handle from its geometry, including the differently shaped shields at higher tiers.
- Give shields, books, grimoires and bows their own mounting axes. The bow belongs in the left hand; its upright aim follows the character's facing direction while the torso turns to draw.
- Author carry poses for standing, walking, running and flying. Long staffs and lanterns lean slightly forward; the crook and lantern remain in front. Both hands share a reachable point along the spear, with a stable bend at the elbows.
- Blend into a skill from the current pose, restore omitted constant bone tracks, and resume the most recent movement request. Changes to running speed update animation cadence without restarting its loop.
- Bake arm tracks offline into 21 compressed animation libraries. Existing source clips retain their length, body and leg tracks, and release timing. Runtime loading merges the arm tracks once per rig/class and uses normal AnimationPlayer interpolation.

## Validation

Run with Godot **4.3**, an isolated user-data directory, and the Compatibility renderer. The authoring tool is `tools/bake_weapon_poses.gd`.

- `weapon_motion_test`: all seven class states (including Vagabond), three rigs and ten equipment tiers; grip geometry, shield facing, whole carry loops, bow/spear attacks, elbow continuity, skill transitions and running cadence. **101,333 checks passed**. Maximum grip-centre deviation was 0.002 game units; spear support-hand deviation stayed below 0.016. Long-pole carry poses remained within 15° of vertical.
- `skill_choreography_test`: **1,368 cases / 11,568 checks passed** across all 152 skills, three rigs and three haste values; release/contact synchronization, interruption and restoration.
- `armageddon_test`: **193 checks passed**, with 77 observed sequence hits; the eleven-hit sequence remains spaced at 0.5 seconds.
- Web loader: **54 checks passed**. Resolution tests passed for Retina budgets, quality changes, rotation and restoration.
- Native front/side/rear captures checked weapon placement. A 30-second movie rendered actual idle/run/attack/skill transitions for male and female characters across all six professions. Bone attachments matched their current hand poses throughout the recording.

The browser smoke test and deployment record are retained in the release artifacts. These checks use desktop software rendering; they are not an FPS measurement on a physical iPhone.
