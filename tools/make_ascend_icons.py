#!/usr/bin/env python3
"""Author the Ascension skill medallions (AscendSkillData, the ★500 job change).

Built with tools/make_skill_icons.py's own pieces (objects, palettes, the god frame of
document(god=True)); each Ascension icon adds a second, white crown ring and a sunburst
behind its picture. Standard-library only; no remote art. Writes assets/icons/skills/<id>.svg.
"""
from pathlib import Path
import re
import make_skill_icons as m
from make_skill_icons import o, rays, ring, rain, star, group

# The Ascension's palettes (AscendSkillData.COLORS): dark, mid, main, light.
m.PALETTES.update({
    "asc_sword": ("2a0e1a", "a0402a", "ffb43a", "fff4c0"),
    "asc_star": ("0a2a34", "1f8a78", "6af0c8", "eafff8"),
    "asc_lance": ("0a1a48", "1f6ab8", "4ad0ff", "f0fbff"),
    "asc_cosmos": ("140a3a", "5a36c0", "9a6aff", "f6eeff"),
    "asc_dawn": ("3a2a3a", "c0904a", "ffd84a", "ffffff"),
    "asc_beast": ("0a2e2a", "1fa078", "3af0a0", "e8fff4"),
    "asc_aegis": ("0e1a48", "2a5ac8", "5a9aff", "f0f6ff"),
    "asc_night": ("1a0420", "8a1240", "ff3a7a", "ffe6f0"),
    "asc_dual": ("1a0630", "6a2ab0", "c06aff", "ffe8a0"),
    "asc_hymn": ("2a0a3a", "a02a9a", "ff6ae0", "fff0fb"),
    "asc_fist": ("3a1208", "b8501a", "ffa030", "fff4d0"),
})

CROWN = o("crown", 0, -72, .32)
RECIPES = {
    # Ultimates: the class's weapon under the gate of the heavens.
    "emperor_heavensword": ("asc_sword", ring(1.08) + o("cloud", 0, -58, .7) + o("sword", 0, 6, 1.24, 180) + CROWN + star(-52, 40, 14) + star(52, 40, 14)),
    "starfall_emperor_arrow": ("asc_star", rays(16) + o("meteor", 0, -40, .52, 20) + rain("arrow", 3, .48) + o("bow", 0, 30, .5) + CROWN),
    "dragon_emperor_lance": ("asc_lance", o("dragon", 0, -18, .62) + o("spear", 0, 8, 1.2, 180) + o("bolt", -52, 0, .38, -10) + o("bolt", 52, 0, .38, 10) + CROWN),
    "cosmos_genesis": ("asc_cosmos", group(ring(1.1), rotate=-30) + group(ring(.85), rotate=40) + group(ring(.6), rotate=80) + o("orb", 0, 0, .46) + star(0, 0, 30) + CROWN),
    "eternal_dawn_judgment": ("asc_dawn", rays(20) + o("wings", 0, -6, 1.2) + o("ray", 0, 0, .7) + o("cross", 0, 14, .44) + CROWN),
    "primordial_beast_court": ("asc_beast", o("vortex", s=1.0, opacity=.5) + o("dragon", -6, -6, .8) + o("wolf", -46, 42, .4) + o("phoenix", 46, 40, .42) + CROWN),
    "eternal_bastion_fall": ("asc_aegis", o("cloud", 0, -60, .7) + o("wings", 0, -4, 1.1, 0, .6) + o("shield", 0, 10, .9) + o("crack", 0, 62, .6) + CROWN),
    "timeless_night_execution": ("asc_night", rays(12) + o("moon", 0, -34, .7) + o("hourglass", 0, 10, .4) + o("twin", 0, 40, .72) + CROWN),
    "heaven_hell_sovereign": ("asc_dual", o("flame", -40, 40, .55) + o("wings", 0, -10, 1.0, 0, .55) + o("crown", 0, -30, .7) + o("scepter", 40, 20, .56, 16) + o("bolt", -40, -20, .4)),
    "universe_hymn": ("asc_hymn", rays(18) + group(ring(.95), rotate=20) + o("lyre", 0, 4, .74) + o("notes", -50, -40, .4) + o("treble", 52, -36, .36) + CROWN),
    "heavenly_master_fist": ("asc_fist", rays(16) + o("prajiad", 0, -40, .6) + o("fist", 0, 14, .9) + o("flame", -52, 44, .36) + o("flame", 52, 44, .36) + CROWN),
    # Buffs: the class's emblem crowned, inside the white ring.
    "sovereign_awakening": ("asc_sword", o("wings", 0, -6, .95, 0, .5) + o("sword", 0, 8, .9, 180) + o("crown", 0, -40, .52)),
    "zenith_hawkeye": ("asc_star", rays(12) + o("hawk", 0, 0, .8) + o("eye", 0, -54, .36) + o("crown", 0, -80, .24)),
    "celestial_phalanx": ("asc_lance", o("shield", -36, 20, .56) + o("shield", 36, 20, .56) + o("spear", 0, 0, .96, 180) + o("crown", 0, -62, .34)),
    "arcane_singularity": ("asc_cosmos", o("vortex", s=1.0, opacity=.7) + o("orb", 0, 0, .4) + o("sigil", 0, 0, .9) + o("crown", 0, -64, .32)),
    "halo_of_eternity": ("asc_dawn", ring(1.0, -40) + o("wings", 0, 6, 1.0) + o("prayer", 0, 20, .5) + o("hand", 0, 44, .3)),
    "covenant_of_beasts": ("asc_beast", o("tree", 0, 10, .8) + o("wolf", -44, 40, .38) + o("hawk", 44, -30, .36) + o("crown", 0, -64, .32)),
    "aegis_of_eternity": ("asc_aegis", rays(14) + o("buckler", 0, 6, .9) + o("helmet", 0, -6, .4) + o("crown", 0, -70, .3)),
    "veil_of_eternity": ("asc_night", o("smoke", 0, 30, 1.0) + o("mask", 0, -2, .6) + o("hourglass", 46, -40, .3) + o("moon", -40, -44, .4)),
    "crown_of_dual_realms": ("asc_dual", o("crown", 0, -8, 1.0) + o("flame", -48, 40, .36) + o("orb", 48, 40, .3) + rays(10)),
    "aria_of_eternity": ("asc_hymn", o("wings", 0, -6, .95, 0, .5) + o("treble", 0, 0, .7) + o("note", -46, 30, .34) + o("note", 46, 30, .34) + o("crown", 0, -66, .3)),
    "sacred_ring_vow": ("asc_fist", o("prajiad", 0, -10, .9) + o("prayer", 0, 20, .52) + o("wings", 0, -6, .95, 0, .45) + o("crown", 0, -70, .3)),
}


def document(palette, picture):
    svg = m.document(palette, picture, god=True)
    dark, mid, main, light = m.PALETTES[palette]
    # The Ascension frame: a white crown ring inside the gold one and a sunburst behind.
    halo = group(rays(32), 128, 124, 1.25, 0, .3) + f'<circle cx="128" cy="124" r="100" fill="none" stroke="#ffffff" stroke-width="3" opacity=".6"/>'
    svg = svg.replace('<g clip-path="url(#disc)">', '<g clip-path="url(#disc)">' + halo, 1)
    svg = svg.replace('</svg>', f'<circle cx="128" cy="128" r="106" fill="none" stroke="#{light}" stroke-width="2" stroke-dasharray="6 5" opacity=".85"/></svg>')
    return svg


def main(out=m.OUT):
    ids = re.findall(r'"([a-z_]+)"', (m.ROOT / 'data/ascend_skill_data.gd').read_text().split('const IDS := {')[1].split('}')[0])
    ids = [i for i in ids if i not in ("warrior", "archer", "lancer", "mage", "priest", "summoner", "defender", "assassin", "darklord", "bard", "muaythai")]
    missing = set(ids) - set(RECIPES)
    assert not missing, missing
    for skill, (palette, picture) in RECIPES.items():
        (out / f'{skill}.svg').write_text(document(palette, picture))
    print(f'Authored {len(RECIPES)} Ascension medallions.')


if __name__ == '__main__':
    main()
