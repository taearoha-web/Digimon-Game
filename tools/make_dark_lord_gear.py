#!/usr/bin/env python3
"""Author the Dark Lord's scepters procedurally (original geometry, no external art).

usage: python3 tools/make_dark_lord_gear.py [OUT_ROOT]   (OUT_ROOT defaults to assets/models)

What it writes (same layout and conventions as the other classes):
  weapons/scepter_<0-9>.glb          Lv.10..100 scepters, static, grip at the origin, head up +Y
  divine_gear/darklord_scepter.glb  the 200-star emperor's raven scepter, static

A scepter is a short royal mace-staff: a wrapped grip with a pommel, a shaft with
collars, and a head that grows grander with each tier (iron flanges, a ring and
gem, mithril crescents, a royal crown, a dragon's claw round a fire orb, ice
shards, raven-wing blades round a void orb, a holy halo, lightning prongs, and
the god-tier crown with floating rings). The cape and the raven are built at
runtime (CapeArt, DarkRaven). Shares the mesh helpers and GLB writer of
tools/make_assassin_gear.py. Requires numpy.
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_assassin_gear as kit  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
OUT = ARGS[0] if ARGS else os.path.join(ROOT, "assets", "models")

Mesh, material, tube, cylinder, torus, sphere, gem, ridge = kit.Mesh, kit.material, kit.tube, kit.cylinder, kit.torus, kit.sphere, kit.gem, kit.ridge

# Per tier: shaft length, metal, accent, gem colour (sRGB hex).
TIERS = [
    (0.50, "8a8f98", "5a4a3a", "c0c8d0"),  # iron
    (0.52, "c4ccd8", "6b4a2f", "5ab8ff"),  # steel
    (0.54, "b8d8f4", "2c4a7a", "8fe8ff"),  # mithril
    (0.55, "f2c45a", "8a1a2a", "ff3a4a"),  # royal
    (0.57, "d8543a", "3a1410", "ffb03a"),  # fire dragon
    (0.58, "d8f0ff", "5a8ab8", "aef4ff"),  # ice
    (0.59, "2a2236", "8a4dff", "b06bff"),  # shadow
    (0.60, "fff4dc", "e8b64a", "fff0a0"),  # holy
    (0.61, "4a5468", "8fd8ff", "c8f0ff"),  # thunder
    (0.64, "f2c45a", "6a3ab8", "e0a0ff"),  # god
]


def grip(m, wrap, core, pommel, gem_key, rings=5):
    cylinder(m, core, -0.2, 0.05, 0.02, 0.019)
    for i in range(rings):
        y = -0.17 + i * 0.045
        torus(m, wrap, (0, y, 0), (0, 1, 0), 0.0205, 0.005, seg=14, sides=4)
    sphere(m, pommel, (0, -0.22, 0), 0.032)
    gem(m, gem_key, (0, -0.265, 0), (0.018, 0.028, 0.018))


def shaft(m, metal, accent, length):
    cylinder(m, metal, 0.05, length, 0.017, 0.019, sides=10)
    for y in (0.06, length * 0.5, length - 0.01):
        torus(m, accent, (0, y, 0), (0, 1, 0), 0.022, 0.006, seg=16, sides=5)


def flanges(m, key, y, count, height, reach, thick=0.006):
    """Mace flanges round the head: thin blades fanning out from the shaft."""
    for k in range(count):
        a = 2 * math.pi * k / count
        d = np.array([math.cos(a), 0.0, math.sin(a)])
        pts = [(0, y - height * 0.5, 0), tuple(d * reach * 0.9 + np.array([0, y - height * 0.2, 0])),
               tuple(d * reach + np.array([0, y + height * 0.25, 0])), (0, y + height * 0.5, 0)]
        outline = [(np.dot(np.array(p), d), p[1]) for p in pts]
        # Build in the plane spanned by d and up.
        normal = np.cross(d, [0, 1, 0])
        for face in (1, -1):
            for i in range(1, len(pts) - 1):
                a3 = np.array(pts[0]) + normal * thick * face
                b3 = np.array(pts[i]) + normal * thick * face
                c3 = np.array(pts[i + 1]) + normal * thick * face
                if face > 0:
                    m.tri(key, a3, b3, c3)
                else:
                    m.tri(key, a3, c3, b3)
        del outline


def crown(m, key, y, radius, points=5, height=0.06):
    torus(m, key, (0, y, 0), (0, 1, 0), radius, 0.008, seg=20, sides=5)
    for k in range(points):
        a = 2 * math.pi * k / points
        base = np.array([math.cos(a) * radius, y, math.sin(a) * radius])
        tube(m, key, [tuple(base), tuple(base * np.array([0.92, 1, 0.92]) + np.array([0, height, 0]))], [0.012, 0.002], sides=5)
        sphere(m, key, tuple(base * np.array([0.92, 1, 0.92]) + np.array([0, height + 0.006, 0])), 0.008, rings=4, seg=6)


def wing_blades(m, key, y, span, rise, count=2, thick=0.012):
    """Raven-wing blades sweeping out and up from both sides of the head."""
    for side in (-1, 1):
        for k in range(count):
            off = k * 0.03
            outline = [(0.0, -0.02 - off), (span * 0.45, 0.01 - off), (span, rise - off * 1.5), (span * 0.7, rise * 0.55 - off), (span * 0.35, 0.03 - off)]
            outline = [(side * x, yy) for (x, yy) in outline]
            ridge(m, key, outline, (0, y, 0), thick)


def scepter(tier):
    length, metal_hex, accent_hex, gem_hex = TIERS[tier]
    m = Mesh()
    mats = {
        "metal": material(metal_hex, 0.75 if tier != 6 else 0.4, 0.3),
        "accent": material(accent_hex, 0.4, 0.4),
        "grip": material("2a1a14" if tier < 6 else "140c18", 0.0, 0.8),
        "gem": material(gem_hex, 0.1, 0.15, glow=gem_hex, glow_amount=0.6 + tier * 0.12),
        "gold": material("f2c45a", 0.8, 0.25),
    }
    grip(m, "accent", "grip", "metal", "gem")
    shaft(m, "metal", "accent" if tier < 3 else "gold", length)
    top = length
    if tier == 0:
        sphere(m, "metal", (0, top + 0.04, 0), 0.04)
        flanges(m, "metal", top + 0.05, 6, 0.1, 0.06)
    elif tier == 1:
        sphere(m, "metal", (0, top + 0.03, 0), 0.035)
        torus(m, "metal", (0, top + 0.1, 0), (0, 0, 1), 0.05, 0.008, seg=20)
        gem(m, "gem", (0, top + 0.1, 0), (0.022, 0.032, 0.016))
        flanges(m, "metal", top + 0.03, 4, 0.06, 0.05)
    elif tier == 2:
        sphere(m, "metal", (0, top + 0.03, 0), 0.035)
        for side in (-1, 1):
            ridge(m, "metal", [(side * x, yy) for x, yy in [(0.0, 0.0), (0.06, 0.03), (0.09, 0.12), (0.05, 0.07), (0.02, 0.05)]], (0, top, 0), 0.01)
        gem(m, "gem", (0, top + 0.11, 0), (0.025, 0.045, 0.02))
    elif tier == 3:
        torus(m, "gold", (0, top + 0.02, 0), (0, 1, 0), 0.04, 0.01, seg=20)
        sphere(m, "accent", (0, top + 0.07, 0), 0.045)
        crown(m, "gold", top + 0.08, 0.05, points=5, height=0.07)
        gem(m, "gem", (0, top + 0.16, 0), (0.02, 0.03, 0.02))
    elif tier == 4:
        # A dragon's claw closed round a fire orb.
        sphere(m, "gem", (0, top + 0.09, 0), 0.05)
        for k in range(4):
            a = 2 * math.pi * k / 4 + 0.4
            d = np.array([math.cos(a), 0, math.sin(a)])
            pts = [(0, top, 0), tuple(d * 0.05 + np.array([0, top + 0.03, 0])), tuple(d * 0.065 + np.array([0, top + 0.1, 0])), tuple(d * 0.03 + np.array([0, top + 0.16, 0]))]
            tube(m, "metal", pts, [0.012, 0.011, 0.008, 0.002], sides=6)
        flanges(m, "accent", top - 0.02, 5, 0.05, 0.04)
    elif tier == 5:
        sphere(m, "gem", (0, top + 0.09, 0), 0.045)
        for k in range(6):
            a = 2 * math.pi * k / 6
            d = np.array([math.cos(a), 0, math.sin(a)])
            gem(m, "metal", tuple(d * 0.06 + np.array([0, top + 0.08 + (k % 2) * 0.03, 0])), (0.012, 0.06, 0.012))
        gem(m, "metal", (0, top + 0.2, 0), (0.016, 0.06, 0.016))
    elif tier == 6:
        # Raven-wing blades round a void orb.
        sphere(m, "gem", (0, top + 0.08, 0), 0.045)
        torus(m, "accent", (0, top + 0.08, 0), (0, 0, 1), 0.065, 0.006, seg=24)
        wing_blades(m, "metal", top + 0.06, 0.16, 0.14, count=2)
        tube(m, "metal", [(0, top + 0.12, 0), (0, top + 0.22, 0)], [0.012, 0.001], sides=6)
    elif tier == 7:
        sphere(m, "gem", (0, top + 0.08, 0), 0.04)
        torus(m, "accent", (0, top + 0.08, 0), (0, 0, 1), 0.08, 0.008, seg=28)
        for side in (-1, 1):
            ridge(m, "metal", [(side * x, yy) for x, yy in [(0.0, 0.0), (0.05, 0.02), (0.13, 0.1), (0.07, 0.07), (0.03, 0.06)]], (0, top + 0.03, 0), 0.01)
        tube(m, "accent", [(0, top + 0.12, 0), (0, top + 0.24, 0)], [0.01, 0.01], sides=6)
        tube(m, "accent", [(-0.04, top + 0.2, 0), (0.04, top + 0.2, 0)], [0.009, 0.009], sides=6)
    elif tier == 8:
        sphere(m, "gem", (0, top + 0.09, 0), 0.048)
        for k in range(3):
            a = 2 * math.pi * k / 3
            d = np.array([math.cos(a), 0, math.sin(a)])
            zig = [(0, top, 0)]
            for j in range(1, 5):
                zz = d * (0.03 + 0.012 * (j % 2)) * (1 + j * 0.25)
                zig.append(tuple(zz + np.array([0, top + j * 0.045, 0])))
            tube(m, "accent", zig, [0.008, 0.007, 0.006, 0.004, 0.001], sides=5)
        flanges(m, "metal", top - 0.02, 6, 0.05, 0.045)
    else:
        # The god-tier: a crowned violet orb in two crossing gold rings, raven wings and a gem spire.
        sphere(m, "gem", (0, top + 0.1, 0), 0.055)
        torus(m, "gold", (0, top + 0.1, 0), (0, 0, 1), 0.08, 0.007, seg=28)
        torus(m, "gold", (0, top + 0.1, 0), (1, 0, 0), 0.08, 0.007, seg=28)
        crown(m, "gold", top + 0.16, 0.035, points=5, height=0.05)
        wing_blades(m, "accent", top + 0.05, 0.18, 0.16, count=3)
        gem(m, "gem", (0, top + 0.25, 0), (0.015, 0.04, 0.015))
        flanges(m, "gold", top - 0.01, 6, 0.04, 0.045)
    return m, mats


def divine_scepter():
    """The 200-star emperor's raven scepter: black and gold, a crimson void orb held
    by a raven with spread wings, a floating crown and three orbiting gold rings."""
    m = Mesh()
    mats = {"metal": material("16101e", 0.6, 0.3), "gold": material("f2c45a", 0.85, 0.2),
            "gem": material("ff2a4a", 0.1, 0.15, glow="ff2a4a", glow_amount=2.0),
            "violet": material("b06bff", 0.2, 0.2, glow="b06bff", glow_amount=1.6),
            "grip": material("0c0810", 0.0, 0.8)}
    grip(m, "gold", "grip", "gold", "gem")
    shaft(m, "metal", "gold", 0.66)
    top = 0.66
    sphere(m, "gem", (0, top + 0.11, 0), 0.06)
    for axis in ((0, 0, 1), (1, 0, 0), (0.7, 0.7, 0)):
        torus(m, "gold", (0, top + 0.11, 0), axis, 0.09, 0.006, seg=28)
    wing_blades(m, "metal", top + 0.06, 0.22, 0.2, count=3)
    wing_blades(m, "violet", top + 0.07, 0.2, 0.17, count=1, thick=0.004)
    crown(m, "gold", top + 0.2, 0.04, points=7, height=0.06)
    gem(m, "violet", (0, top + 0.3, 0), (0.018, 0.045, 0.018))
    flanges(m, "gold", top - 0.01, 8, 0.05, 0.05)
    return m, mats


def main():
    report = []
    for tier in range(10):
        m, mats = scepter(tier)
        size, tris = kit.write_static(os.path.join(OUT, "weapons", "scepter_%d.glb" % tier), m, mats, "scepter_%d" % tier)
        report.append(("weapons/scepter_%d.glb" % tier, tris, size))
    m, mats = divine_scepter()
    size, tris = kit.write_static(os.path.join(OUT, "divine_gear", "darklord_scepter.glb"), m, mats, "darklord_scepter")
    report.append(("divine_gear/darklord_scepter.glb", tris, size))
    for name, tris, size in report:
        print("%-36s %6d tris %5d KB" % (name, tris, size // 1024))


if __name__ == "__main__":
    main()
