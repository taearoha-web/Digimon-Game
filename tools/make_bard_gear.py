#!/usr/bin/env python3
"""Author the Bard's lutes and wings procedurally (original geometry, no external art).

usage: python3 tools/make_bard_gear.py [--wings] [OUT_ROOT]   (OUT_ROOT defaults to assets/models;
       --wings rewrites only the two wing pairs)

What it writes (same layout and conventions as the other classes):
  weapons/lute_<0-9>.glb        Lv.10..100 lutes, static: the left hand closes on the neck at the
                                origin, the neck runs up +Y, the soundboard and strings face +Z
  divine_gear/bard_lute.glb     the 200-star lute of the heavenly song, static
  wings/wings_bard.glb          Lv.100 wings of heavenly notes on the mage wing rig (skinned + clips)
  star_wings/wings_bard.glb     star symphony wings: the same rig, a lyre halo behind the head and a
                                wheel of notes turning on the rig's WingHalo joint

A lute is a pear-shaped bowl of staves behind a flat soundboard, a short fretted
neck with its pegbox bent back, a rosette over the sound hole and strings from the
nut to the bridge. The hand's bare zone is |y| < 0.045 on the neck. The rosette
sits at (0, -0.20, 0.017) raw, WeaponKit.LUTE_ROSETTE (0, -0.35, 0.035) when held at
WeaponKit's x1.75: every song and note leaves from there (HeroVisual's emission
point). Each tier grows grander: pine and iron; walnut bound in steel; mithril with
crescent fins; red lacquer, a gold crown and gold staves; a dragon-headed fire lute
licked by flames; frosted crystal with icicles; black lacquer under bat wings and a
crescent moon; white gold with a halo and feathered wings; storm blue split by
lightning; and the god-tier rose-gold lute with a floating halo, a crown, a star and
great wings. Big ornaments sit at the body's sides, below its shoulders: held, the
shoulders point at the hero's chin, so nothing large grows there.

The wings reuse the armature, bind poses and Unfold / Fold / Glide / Flap / Idle (and
HaloSpin) clips of the mage's wings, read from the committed assets (never OUT), so
they fold, flap and glide exactly like every other class's pair; only the skinned
mesh is new. Every wing is a fan of rose-gold feathers crossed by the five glowing
lines of a musical staff, with notes on the lines and note heads at the feather
tips. Material keys are stable (they become glTF material names). Shares the mesh
helpers and GLB writer of tools/make_assassin_gear.py. Requires numpy.
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_assassin_gear as kit  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
WINGS_ONLY = "--wings" in sys.argv[1:]
OUT = ARGS[0] if ARGS else os.path.join(ROOT, "assets", "models")
# The wing rig is always read from the committed mage wings, never from OUT.
SRC = os.path.join(ROOT, "assets", "models")

Mesh, material, tube, cylinder, torus, sphere, gem, ridge = kit.Mesh, kit.material, kit.tube, kit.cylinder, kit.torus, kit.sphere, kit.gem, kit.ridge

# ---------------------------------------------------------------------------
# The lute (raw units; WeaponKit holds it at x1.75)
# ---------------------------------------------------------------------------

NUT, BRIDGE = 0.205, -0.31
ROSE = (0.0, -0.20, 0.017)
BODY_TOP, BODY_BOTTOM, BODY_W = -0.07, -0.37, 0.132
BOARD_Z = 0.012
# The pegbox bends back from the nut; its tip carries each tier's crest.
BOX = [(0.0, NUT - 0.005, -0.006), (0.0, NUT + 0.045, -0.03), (0.0, NUT + 0.09, -0.068)]
TIP = np.array(BOX[2])

# Per tier: wood, soundboard, trim, string, gem (sRGB hex), string glow, wood glow (hex or None).
TIERS = [
    ("b07a44", "e2b878", "8a8f98", "e8e2d0", "c0c8d0", 0.0, None),       # 0 pine and iron (trainee)
    ("5e3e26", "c99a62", "c4ccd8", "eef0f4", "5ab8ff", 0.0, None),       # 1 walnut bound in steel
    ("8fa2bc", "dfe9f6", "eef6ff", "f4fbff", "8fe8ff", 0.35, None),      # 2 mithril silver, pale-blue gem
    ("7a1424", "a8283a", "f2c45a", "fff0c0", "ff3a4a", 0.0, None),       # 3 royal red lacquer and gold
    ("8a2a1a", "c8482c", "3a1410", "ffc040", "ff5a1f", 1.3, None),       # 4 fire dragon: ember strings
    ("9cc8e8", "dff4ff", "8ab8d8", "eaffff", "aef4ff", 0.9, "aef4ff"),   # 5 ice: frosted crystal
    ("1e1828", "2e2440", "8a4dff", "c9a7ff", "b06bff", 1.2, None),       # 6 shadow: black lacquer, violet
    ("f4e8cc", "fff8ec", "e8b64a", "fff8e0", "fff0a0", 0.7, None),       # 7 holy: white gold
    ("3a4458", "56637c", "8fd8ff", "e8fbff", "6fd0ff", 1.1, None),       # 8 thunder: storm blue
    ("d88870", "f4c0ac", "f2c45a", "ffe0f0", "ff8fcf", 1.5, None),       # 9 god: rose gold
]


def pear_point(a, width=BODY_W):
    """The soundboard outline at angle a (0 top, pi bottom): a pear, widest low,
    narrowing into the neck."""
    cy, ry = (BODY_TOP + BODY_BOTTOM) * 0.5, (BODY_TOP - BODY_BOTTOM) * 0.5
    squeeze = 1.0 - 0.55 * max(0.0, math.cos(a)) ** 2.2
    return (width * math.sin(a) * squeeze, cy + ry * math.cos(a))


def pear(n=20, width=BODY_W):
    return [pear_point(2 * math.pi * i / n, width) for i in range(n)]


def bowl(m, key, line_key=None, depth=0.088, stations=12, staves=9, z_front=BOARD_Z - 0.001):
    """The vaulted back: half-elliptic ribs across the pear, the staves running from
    the neck to the tail as on a real lute. With line_key, a narrow column of that
    material marks every joint between two staves (flush, no extra geometry on top)."""
    def point(a, th):
        hw, y = pear_point(a)
        d = depth * (hw / BODY_W) ** 0.55
        return np.array([hw * math.cos(th), y, z_front - d * math.sin(th)])

    centre = np.array([0.0, (BODY_TOP + BODY_BOTTOM) * 0.5, z_front - depth * 0.4])

    def normal(a, th):
        e = 1e-3
        n = np.cross(point(min(a + e, math.pi), th) - point(max(a - e, 0.0), th), point(a, min(th + e, math.pi)) - point(a, max(th - e, 0.0)))
        p = point(a, th)
        if np.linalg.norm(n) < 1e-12:
            n = p - centre
        n = n / np.linalg.norm(n)
        return -n if np.dot(n, p - centre) < 0 else n

    step = math.pi / staves
    half = step * 0.07
    thetas, keys = [0.0], []
    for j in range(1, staves):
        if line_key:
            thetas += [j * step - half, j * step + half]
            keys += [key, line_key]
        else:
            thetas.append(j * step)
            keys.append(key)
    thetas.append(math.pi)
    keys.append(key)
    # Sample the ends of the body a little finer: the pear narrows fast there.
    stops = [math.pi * (0.5 - 0.5 * math.cos(math.pi * k / stations)) for k in range(stations + 1)]
    P = [[point(a, th) for th in thetas] for a in stops]
    N = [[normal(max(min(a, math.pi - 1e-3), 1e-3), th) for th in thetas] for a in stops]
    for i in range(stations):
        for j in range(len(thetas) - 1):
            quad = ((i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1))
            for tri in ((quad[0], quad[1], quad[2]), (quad[0], quad[2], quad[3])):
                pts = [P[a][b] for a, b in tri]
                nrm = [N[a][b] for a, b in tri]
                face = np.cross(pts[1] - pts[0], pts[2] - pts[0])
                if np.linalg.norm(face) < 1e-12:
                    continue
                if np.dot(face, nrm[0] + nrm[1] + nrm[2]) < 0:
                    pts, nrm = [pts[0], pts[2], pts[1]], [nrm[0], nrm[2], nrm[1]]
                m.smooth_tri(keys[j], pts, nrm)


def leaf(length, width, angle, n=4, tip=0.0):
    """A feather / leaf / flame outline rooted at the origin, pointing along angle
    (radians from +Y towards -X). tip bends the last third sideways."""
    pts = []
    for i in range(n + 1):
        t = i / n
        w = width * math.sin(math.pi * min(1.0, t * 1.15)) ** 0.8 * (1.0 - 0.25 * t)
        pts.append((w, t * length, t))
    out = [(0.0, 0.0)] + [(x + tip * t ** 2, y) for x, y, t in pts[1:-1]] + [(tip, length)] + [(-x + tip * t ** 2, y) for x, y, t in reversed(pts[1:-1])]
    c, s = math.cos(angle), math.sin(angle)
    return [(x * c - y * s, x * s + y * c) for x, y in out]


def flat(m, key, outline, centre, depth):
    """A bevelled silhouette in the soundboard's plane (XY)."""
    ridge(m, key, outline, centre, depth, plane=("x", "y"))


def star_gem(m, key, centre, outer, inner, points, depth):
    outline = []
    for k in range(points * 2):
        a = math.pi * k / points
        r = outer if k % 2 == 0 else inner
        outline.append((r * math.sin(a), r * math.cos(a)))
    flat(m, key, outline, centre, depth)


def note_glyph(m, key, centre, size):
    """An eighth note in the XY plane: a tilted head, a stem and a flag."""
    c = np.asarray(centre, float)
    sphere(m, key, tuple(c), size, rings=3, seg=6, squash=(1.3, 0.9, 0.6))
    top = c + np.array([size * 1.1, size * 3.4, 0.0])
    tube(m, key, [tuple(c + np.array([size * 1.1, 0.2 * size, 0.0])), tuple(top)], [size * 0.22, size * 0.2], sides=3)
    flat(m, key, [(0.0, 0.0), (size * 1.2, -size * 0.9), (size * 1.0, -size * 1.8), (size * 0.25, -size * 1.0)], tuple(top), size * 0.18)


def neck(m, wood, board, fret_key, nut_key):
    # Neck (bare where the hand closes, |y| < 0.045), fingerboard, nut and frets.
    tube(m, wood, [(0, -0.09, -0.004), (0, NUT, -0.004)], [0.018, 0.0145], sides=6)
    flat(m, board, [(-0.016, -0.09), (0.016, -0.09), (0.0135, NUT), (-0.0135, NUT)], (0, 0, 0.0105), 0.0016)
    tube(m, nut_key, [(-0.016, NUT, 0.011), (0.016, NUT, 0.011)], [0.003, 0.003], sides=4)
    for y in (0.07, 0.11, 0.15, 0.183, -0.07):
        tube(m, fret_key, [(-0.0155, y, 0.0125), (0.0155, y, 0.0125)], [0.0015, 0.0015], sides=4, caps=False)
    # The heel where the neck meets the body.
    sphere(m, wood, (0, -0.082, -0.012), 0.024, rings=3, seg=6, squash=(0.9, 1.0, 0.8))


def pegbox(m, wood, peg, tier):
    tube(m, wood, BOX, [0.0155, 0.014, 0.0115], sides=6)
    for k in range(3):
        t = 0.22 + k * 0.3
        p = np.array(BOX[0]) * (1 - t) + np.array(BOX[2]) * t
        for side in (-1, 1):
            tube(m, peg, [tuple(p + [side * 0.01, 0, 0]), tuple(p + [side * 0.03, 0, 0])], [0.0036, 0.0028], sides=4)
            if tier == 5:
                # Icicle pegs: long crystal drops instead of knobs.
                gem(m, "gem", tuple(p + [side * 0.036, -0.012, 0]), (0.0045, 0.016, 0.0045))
            else:
                sphere(m, peg, tuple(p + [side * 0.034, 0, 0]), 0.0058, rings=2, seg=4, squash=(0.7, 1.2, 1.2))


def body(m, tier):
    outline = pear()
    # Stave joints inlaid in the tier's trim metal (dark wood on the plain tiers and
    # under the dragon's scales).
    bowl(m, "wood", "trim" if tier in (3, 5, 6, 7, 8, 9) else "hole")
    flat(m, "top", outline, (0, 0, BOARD_Z), 0.003)
    # The sound hole and its rosette.
    flat(m, "hole", [(0.03 * math.sin(2 * math.pi * k / 14), ROSE[1] + 0.03 * math.cos(2 * math.pi * k / 14)) for k in range(14)], (0, 0, 0.0153), 0.0004)
    torus(m, "trim", ROSE, (0, 0, 1), 0.034, 0.0036, seg=18, sides=3)
    if tier >= 2:
        # A pierced lace star inside the rosette.
        for k in range(3):
            a = math.pi * k / 3 + math.pi / 6
            d = np.array([math.sin(a), math.cos(a), 0.0]) * 0.03
            tube(m, "trim", [tuple(np.array(ROSE) + d + [0, 0, -0.001]), tuple(np.array(ROSE) - d + [0, 0, -0.001])], [0.0013, 0.0013], sides=3, caps=False)
        torus(m, "trim", ROSE, (0, 0, 1), 0.016, 0.0016, seg=10, sides=3)
    # The bridge, with a tie block for the strings.
    tube(m, "trim" if tier >= 1 else "hole", [(-0.034, BRIDGE, 0.0165), (0.034, BRIDGE, 0.0165)], [0.0048, 0.0048], sides=4)
    flat(m, "hole" if tier not in (3, 7, 9) else "trim", [(-0.04, -0.008), (-0.028, 0.004), (0.028, 0.004), (0.04, -0.008), (0.0, -0.016)], (0, BRIDGE - 0.004, 0.0152), 0.0012)
    # The end button at the tail.
    sphere(m, "trim", (0, BODY_BOTTOM - 0.004, -0.02), 0.009, rings=3, seg=6)
    return outline


def strings(m, count):
    for k in range(count):
        x = (k - (count - 1) / 2) * (0.0046 if count <= 6 else 0.0036)
        tube(m, "string", [(x * 0.75, NUT, 0.0128), (x * 1.6, BRIDGE, 0.0188)], [0.0011, 0.0011], sides=3, caps=False)


def binding(m, key, outline, radius=0.0024, z=BOARD_Z + 0.0012):
    ring = [(x * 1.01, y, z) for x, y in outline] + [(outline[0][0], outline[0][1], z)]
    tube(m, key, ring, [radius] * len(ring), sides=3, caps=False)


def crown(m, key, centre, radius, points=5, height=0.022, thick=0.003):
    c = np.asarray(centre, float)
    torus(m, key, tuple(c), (0, 1, 0), radius, thick, seg=14, sides=4)
    for k in range(points):
        a = 2 * math.pi * k / points
        base = c + [radius * math.cos(a), 0, radius * math.sin(a)]
        tube(m, key, [tuple(base), tuple(base + [0, height, 0])], [thick * 1.2, 0.0006], sides=4)
        gem(m, "gem", tuple(base + [0, height + 0.002, 0]), (0.003, 0.0045, 0.003))


def rotate(outline, angle):
    c, s = math.cos(angle), math.sin(angle)
    return [(x * c - y * s, x * s + y * c) for x, y in outline]


def feather2d(length, width, angle):
    """A rounded-tip feather from its root along +Y, turned by angle (as leaf())."""
    w = width * 0.5
    return rotate([(0.0, 0.0), (-w * 0.6, length * 0.12), (-w, length * 0.55), (-w * 0.6, length * 0.92), (0.0, length),
                   (w * 0.7, length * 0.86), (w, length * 0.5), (w * 0.55, length * 0.1)], angle)


def petal2d(length, width, angle):
    """A lotus petal from its root along +Y: widest at half length, a pointed tip."""
    w = width * 0.5
    return rotate([(0.0, 0.0), (-w * 0.7, length * 0.18), (-w, length * 0.5), (-w * 0.62, length * 0.82), (0.0, length),
                   (w * 0.62, length * 0.82), (w, length * 0.5), (w * 0.7, length * 0.18)], angle)


def angel_wing(m, key, root, side, span, drop, count, length, width, arm_key=None, depth=0.003):
    """A feathered wing folded along the body's side in the soundboard's plane: an arm
    arching out from root and down the rim, its feathers fanning out and down from it,
    longest at the lower end. Held, the lute's sides point up at the hero's chin, so
    the wing must not reach up and out: its feathers stay within 55 degrees of the tail."""
    r = np.asarray(root, float)
    p1, p2 = np.array([side * span * 1.1, -drop * 0.3]), np.array([side * span, -drop])
    arm = lambda t: 2 * t * (1 - t) * p1 + t * t * p2
    for k in range(count):
        t = (k + 0.6) / count
        phi = math.radians(55.0 - 35.0 * t)
        a = arm(t)
        flat(m, key, feather2d(length * (0.55 + 0.7 * t), width * (0.85 + 0.3 * t), math.pi + side * phi), (r[0] + a[0], r[1] + a[1], r[2] - 0.0016 * k), depth)
    pts = [tuple(r + [arm(t)[0], arm(t)[1], 0.002]) for t in np.linspace(0.0, 1.0, 6)]
    tube(m, arm_key or key, pts, [0.0045, 0.0042, 0.0038, 0.0032, 0.0024, 0.0008], sides=3)


def streak(m, key, pts, widths, z, depth=0.003):
    """A flat ribbon through 2D points in the soundboard's plane, one convex quad per
    segment (bolts, vines, flames)."""
    pts = [np.asarray(p, float) for p in pts]
    for i in range(len(pts) - 1):
        d = pts[i + 1] - pts[i]
        n = np.array([-d[1], d[0]]) / max(np.linalg.norm(d), 1e-9)
        a, b = pts[i], pts[i + 1]
        wa, wb = widths[i] * 0.5, widths[i + 1] * 0.5
        quad = [tuple(a - n * wa), tuple(b - n * wb), tuple(b + n * wb), tuple(a + n * wa)] if wb > 1e-5 else [tuple(a - n * wa), tuple(b), tuple(a + n * wa)]
        flat(m, key, quad, (0.0, 0.0, z), depth)


def lightning(m, key, start, side, scale, z, width=0.012):
    """A lightning bolt striking down and out to one side: three jagged strokes."""
    s = np.asarray(start, float)
    pts = [s, s + np.array([side * 0.035, -0.04]) * scale, s + np.array([side * 0.018, -0.052]) * scale,
           s + np.array([side * 0.06, -0.1]) * scale, s + np.array([side * 0.04, -0.11]) * scale, s + np.array([side * 0.085, -0.165]) * scale]
    streak(m, key, pts, [width, width * 0.9, width * 0.85, width * 0.7, width * 0.6, 0.0], z)


def flame(m, outer, inner, root, side, length, z):
    """A fire tongue rising up and out at the body's side: an orange flame with a
    bright core and two smaller licks."""
    r = np.asarray(root, float)
    for key, scale, dz, lean in ((outer, 1.0, 0.0, 0.55), (inner, 0.6, 0.0012, 0.5)):
        flat(m, key, leaf(length * scale, length * 0.32 * scale, -side * lean, n=5, tip=-side * 0.18 * length * scale), (r[0], r[1], z + dz), 0.0035)
    for k, (dx, dy, ln, lean) in enumerate(((0.03, -0.035, 0.6, 1.0), (-0.012, -0.012, 0.42, 0.1))):
        flat(m, outer, leaf(length * ln, length * 0.22 * ln, -side * lean, n=4, tip=-side * 0.15 * length * ln), (r[0] + side * dx, r[1] + dy, z - 0.001 * (k + 1)), 0.003)


def lute(tier):
    wood, top, trim, string_hex, gem_hex, string_glow, wood_glow = TIERS[tier]
    m = Mesh()
    lacquer = tier in (3, 6)
    metallic = tier in (2, 5, 7, 9)
    mats = {
        "wood": material(wood, 0.5 if metallic else (0.15 if lacquer else 0.05), 0.35 if (metallic or lacquer) else 0.6,
                         glow=wood_glow, glow_amount=0.22),
        "top": material(top, 0.45 if metallic else 0.05, 0.4 if (metallic or lacquer) else 0.65, glow=wood_glow, glow_amount=0.3),
        "trim": material(trim, 0.5, 0.32),
        "string": material(string_hex, 0.3, 0.3, glow=string_hex if string_glow else None, glow_amount=string_glow),
        "gem": material(gem_hex, 0.1, 0.15, glow=gem_hex, glow_amount=0.6 + tier * 0.12),
        "hole": material("1a0e14", 0.0, 0.85),
    }
    board = "trim" if tier in (3, 9) else "hole"
    neck(m, "wood", board, "trim", "trim" if tier >= 1 else "string")
    pegbox(m, "wood", "trim" if tier >= 1 else "hole", tier)
    outline = body(m, tier)
    strings(m, 8 if tier == 9 else 6)
    if tier >= 1:
        binding(m, "gem" if tier in (6, 8) else "trim", outline, 0.0026 if tier >= 3 else 0.0022)
    if tier >= 1 and tier not in (4, 5, 7, 8, 9):
        gem(m, "gem", tuple(TIP + [0, 0.016, -0.006]), (0.009, 0.014, 0.009))
    tip = TIP
    z = BOARD_Z + 0.0015
    # --- the ornaments of each tier (all must read from the gameplay camera) ---
    if tier == 1:
        # Steel corner plates at the shoulders and a steel clasp at the tail.
        for side in (-1, 1):
            flat(m, "trim", [(0, 0), (side * 0.032, -0.012), (side * 0.024, -0.034)], (side * 0.034, -0.094, z), 0.002)
        flat(m, "trim", [(-0.03, 0.0), (0.0, 0.012), (0.03, 0.0), (0.0, -0.02)], (0, BODY_BOTTOM + 0.018, z), 0.0025)
    if tier == 2:
        # Mithril crescent fins either side of the pegbox, small crescents at the
        # shoulders and a gem at the bridge.
        for side in (-1, 1):
            flat(m, "trim", [(side * x, y) for x, y in [(0.0, -0.02), (0.035, 0.0), (0.058, 0.045), (0.062, 0.085), (0.04, 0.05), (0.018, 0.022)]], tuple(tip + [0, -0.045, 0.004]), 0.004)
            flat(m, "trim", [(side * x, y) for x, y in [(0.0, 0.0), (0.024, 0.006), (0.04, 0.03), (0.042, 0.05), (0.028, 0.028), (0.012, 0.016)]], (side * 0.052, -0.11, z), 0.003)
        gem(m, "gem", (0, BRIDGE - 0.014, 0.019), (0.008, 0.011, 0.006))
        sphere(m, "gem", (0, BODY_BOTTOM + 0.02, z), 0.006, rings=3, seg=6, squash=(1, 1, 0.6))
    if tier == 3:
        # A gold crown on the pegbox, a gold lace rosette set with ten beads, gold
        # scrolls curling at the shoulders and a ruby at the tail.
        crown(m, "trim", tip + [0, 0.012, 0], 0.017, points=5, height=0.024)
        torus(m, "trim", ROSE, (0, 0, 1), 0.044, 0.0024, seg=20, sides=3)
        for k in range(10):
            a = 2 * math.pi * k / 10
            sphere(m, "gem", (0.05 * math.sin(a), ROSE[1] + 0.05 * math.cos(a), 0.0168), 0.0034, rings=2, seg=4)
        for side in (-1, 1):
            curl = [(side * (0.045 + 0.05 * s - 0.03 * s ** 3), -0.098 - 0.03 * s + 0.024 * s ** 3, z + 0.001) for s in np.linspace(0, 1, 7)]
            tube(m, "trim", curl, [0.004, 0.0038, 0.0035, 0.003, 0.0025, 0.002, 0.001], sides=4)
            flat(m, "trim", leaf(0.03, 0.012, -side * 2.2), (side * 0.06, -0.105, z), 0.002)
        gem(m, "gem", (0, BODY_BOTTOM + 0.022, z + 0.002), (0.01, 0.014, 0.005))
    if tier == 4:
        # A dragon's head crowns the pegbox, flames lick up the body's sides, a
        # scaled ridge runs down the back to a curled tail.
        head = tip + np.array([0, 0.018, 0.006])
        sphere(m, "wood", tuple(head), 0.019, rings=4, seg=8, squash=(0.9, 0.85, 1.2))
        tube(m, "wood", [tuple(head + [0, 0.004, 0.012]), tuple(head + [0, 0.012, 0.036]), tuple(head + [0, 0.008, 0.05])], [0.012, 0.009, 0.004], sides=6)
        tube(m, "trim", [tuple(head + [0, -0.008, 0.012]), tuple(head + [0, -0.004, 0.044])], [0.007, 0.002], sides=5)
        for side in (-1, 1):
            tube(m, "trim", [tuple(head + [side * 0.01, 0.012, -0.006]), tuple(head + [side * 0.024, 0.034, -0.026]), tuple(head + [side * 0.022, 0.05, -0.05])], [0.0045, 0.003, 0.0004], sides=4)
            gem(m, "gem", tuple(head + [side * 0.011, 0.01, 0.018]), (0.0035, 0.003, 0.003))
            flat(m, "trim", [(0, 0), (side * 0.016, 0.012), (side * 0.03, 0.03), (side * 0.012, 0.026)], tuple(head + [side * 0.006, -0.02, -0.01]), 0.0025)
        for k in range(6):
            yy = -0.13 - k * 0.035
            ridge(m, "trim", [(-0.0, 0.016), (0.012, 0.0), (0.0, -0.018), (-0.012, 0.0)], (0, yy, -0.088 + abs(yy + 0.22) * 0.25), 0.006, plane=("y", "z"))
        for side in (-1, 1):
            flame(m, "gem", "string", (side * 0.115, -0.2), side, 0.1, z - 0.004)
            flame(m, "gem", "string", (side * 0.105, -0.29), side, 0.075, z - 0.005)
        tail = [(0.0, BODY_BOTTOM + 0.002, -0.02), (0.02, BODY_BOTTOM - 0.02, -0.01), (0.04, BODY_BOTTOM - 0.012, 0.0), (0.036, BODY_BOTTOM + 0.006, 0.004), (0.026, BODY_BOTTOM - 0.002, 0.006)]
        tube(m, "wood", tail, [0.008, 0.007, 0.005, 0.003, 0.001], sides=5)
        torus(m, "gem", ROSE, (0, 0, 1), 0.052, 0.0024, seg=20, sides=3)
    if tier == 5:
        # Frosted crystal: icicle pegs, shards round the rosette, clusters of ice spikes
        # on the rim, an icicle crown on the pegbox and icicles under the tail.
        for k in range(6):
            a = 2 * math.pi * k / 6 + 0.3
            gem(m, "string", (0.05 * math.sin(a), ROSE[1] + 0.05 * math.cos(a), 0.018), (0.006, 0.014, 0.004))
        cy = (BODY_TOP + BODY_BOTTOM) * 0.5
        for side in (-1, 1):
            for k, (a, ln) in enumerate(((0.6, 0.075), (0.8, 0.055), (0.42, 0.05))):
                x, y = pear_point(math.pi * a)
                d = np.array([x, y - cy])
                d /= np.linalg.norm(d)
                d[0] *= side
                flat(m, "gem", [(-0.009 * d[1], 0.009 * d[0]), (d[0] * ln, d[1] * ln), (0.009 * d[1], -0.009 * d[0]), (-d[0] * 0.012, -d[1] * 0.012)],
                     (side * x * 0.97, y, z - 0.004), 0.004 if k == 0 else 0.003)
            gem(m, "gem", (side * 0.05, -0.1, z), (0.006, 0.02, 0.004))
        for dx, h in ((-0.016, 0.024), (0.0, 0.04), (0.016, 0.024)):
            gem(m, "gem", tuple(tip + [dx, 0.024 + h * 0.5, -0.004]), (0.006, h * 0.5 + 0.004, 0.006))
        for k in range(3):
            gem(m, "gem", ((k - 1) * 0.016, BODY_BOTTOM - 0.008 - (0.012 if k == 1 else 0.004), -0.008), (0.005, 0.016 if k == 1 else 0.01, 0.005))
    if tier == 6:
        # Bat wings spread at the pegbox and at the shoulders, a violet eye in the
        # rosette and a crescent moon hanging under the tail.
        bat = [(0.0, 0.0), (0.03, 0.022), (0.06, 0.036), (0.085, 0.034), (0.074, 0.012), (0.066, -0.004), (0.05, 0.008), (0.042, -0.012), (0.026, 0.004), (0.016, -0.01)]
        for side in (-1, 1):
            flat(m, "trim", [(side * x, y) for x, y in bat], tuple(tip + [0, -0.012, -0.002]), 0.003)
            tube(m, "gem", [tuple(tip + [side * x, y - 0.012, 0.002]) for x, y in bat[:4]], [0.0018] * 4, sides=3, caps=False)
            small = rotate([(side * x * 0.9, y * 0.9) for x, y in bat], -side * 0.45)
            flat(m, "trim", small, (side * 0.058, -0.1, z), 0.0025)
            tube(m, "gem", [(side * 0.058 + px, -0.1 + py, z + 0.002) for px, py in small[:4]], [0.0016] * 4, sides=3, caps=False)
        gem(m, "gem", (0, ROSE[1], 0.019), (0.012, 0.016, 0.006))
        moon = []
        for k in range(9):
            a = math.pi * (0.15 + 0.7 * k / 8)
            moon.append((0.034 * math.cos(a), BODY_BOTTOM + 0.004 - 0.034 * math.sin(a), BOARD_Z - 0.006))
        tube(m, "gem", moon, [0.002, 0.004, 0.006, 0.0072, 0.0078, 0.0072, 0.006, 0.004, 0.002], sides=4)
    if tier == 7:
        # A halo round the rosette, feathered wings rising from the body's sides and a gold
        # star over the pegbox.
        torus(m, "gem", ROSE, (0, 0, 1), 0.058, 0.0035, seg=24, sides=4)
        for side in (-1, 1):
            angel_wing(m, "trim", (side * 0.1, -0.13, z - 0.004), side, 0.05, 0.13, 5, 0.1, 0.026)
        star_gem(m, "gem", tuple(tip + [0, 0.03, 0.0]), 0.018, 0.006, 4, 0.004)
        gem(m, "gem", (0, BODY_BOTTOM + 0.02, z + 0.002), (0.008, 0.012, 0.005))
    if tier == 8:
        # Lightning: bolt inlays down both sides of the neck, three crackling prongs on
        # the pegbox, great bolts striking out from the body's sides and a star of sparks
        # in the rosette.
        for side in (-1, 1):
            zig = [(side * 0.0172, -0.06 + i * 0.034, 0.0 + (0.003 if i % 2 else -0.003)) for i in range(8)]
            tube(m, "gem", zig, [0.0022] * len(zig), sides=3, caps=False)
            lightning(m, "gem", (side * 0.1, -0.15), side, 1.3, z - 0.004, 0.02)
            lightning(m, "string", (side * 0.115, -0.26), side, 0.7, z - 0.005, 0.013)
        for k in range(3):
            a = -0.55 + k * 0.55
            tube(m, "gem", [tuple(tip), tuple(tip + [0.024 * math.sin(a), 0.022, -0.006]), tuple(tip + [0.01 * math.sin(a), 0.04, -0.01]), tuple(tip + [0.036 * math.sin(a), 0.064, -0.014])], [0.0036, 0.003, 0.0022, 0.0004], sides=3)
        star_gem(m, "gem", (0, ROSE[1], 0.0182), 0.024, 0.008, 6, 0.0025)
    if tier == 9:
        # The god-tier: a crown, a floating halo set with stars behind the pegbox, an
        # eight-point star at the bridge, a halo round the rosette and great wings.
        crown(m, "trim", tip + [0, 0.012, 0], 0.017, points=5, height=0.028)
        hc = tip + np.array([0, 0.04, -0.03])
        torus(m, "gem", tuple(hc), (0, 0.45, -0.89), 0.08, 0.0042, seg=24, sides=3)
        torus(m, "trim", tuple(hc), (0, 0.45, -0.89), 0.092, 0.0022, seg=24, sides=3)
        for k in range(4):
            a = 2 * math.pi * k / 4 + math.pi / 4
            star_gem(m, "gem", tuple(hc + [0.092 * math.cos(a), 0.092 * math.sin(a) * 0.9, -0.04 * math.sin(a)]), 0.011, 0.004, 4, 0.003)
        star_gem(m, "gem", (0, BRIDGE - 0.022, 0.019), 0.022, 0.008, 8, 0.004)
        torus(m, "gem", ROSE, (0, 0, 1), 0.056, 0.003, seg=22, sides=3)
        for k in range(8):
            a = 2 * math.pi * k / 8
            gem(m, "trim", (0.046 * math.sin(a), ROSE[1] + 0.046 * math.cos(a), 0.0168), (0.0036, 0.0036, 0.0026))
        for side in (-1, 1):
            angel_wing(m, "trim", (side * 0.1, -0.12, z - 0.004), side, 0.065, 0.16, 6, 0.12, 0.03)
            angel_wing(m, "gem", (side * 0.11, -0.15, z - 0.012), side, 0.07, 0.14, 4, 0.1, 0.022, depth=0.002)
    return m, mats


def divine_lute():
    """The 200-star lute of the heavenly song: white gold and gold, crystal strings, a
    rose-quartz heart in the rosette, a lotus of gold petals fanned behind the rim and
    a halo of six notes behind the pegbox, on the god-tier lute's crown, wings and halos."""
    m, mats = lute(9)
    mats.update({"wood": material("fff4e6", 0.5, 0.3), "top": material("fffaf2", 0.35, 0.35),
                 "trim": material("f2c45a", 0.5, 0.28),
                 "gem": material("ff9ad2", 0.1, 0.15, glow="ff9ad2", glow_amount=2.0),
                 "string": material("dff8ff", 0.2, 0.2, glow="dff8ff", glow_amount=1.6),
                 "hole": material("2a1020", 0.0, 0.9)})
    cy = (BODY_TOP + BODY_BOTTOM) * 0.5

    def rim(a):
        """Point of the pear outline at angle a round the full rim, and its outward direction."""
        x, y = pear_point(a if a <= math.pi else 2 * math.pi - a)
        x = x if a <= math.pi else -x
        d = np.array([x, y - cy])
        return x, y, d / np.linalg.norm(d)

    for k in range(7):
        x, y, d = rim(math.pi * (0.45 + 1.1 * k / 6))
        flat(m, "trim", petal2d(0.11, 0.06, math.atan2(-d[0], d[1])), (x * 0.62, cy + (y - cy) * 0.62, -0.02), 0.004)
        if k < 6:
            x, y, d = rim(math.pi * (0.45 + 1.1 * (k + 0.5) / 6))
            flat(m, "gem", petal2d(0.08, 0.036, math.atan2(-d[0], d[1])), (x * 0.74, cy + (y - cy) * 0.74, -0.028), 0.0025)
    hc = np.array([0, NUT + 0.14, -0.105])
    torus(m, "trim", tuple(hc), (0, 0, 1), 0.11, 0.003, seg=32, sides=4)
    for k in range(6):
        a = 2 * math.pi * k / 6 + math.pi / 2
        note_glyph(m, "gem", hc + [0.11 * math.cos(a) - 0.006, 0.11 * math.sin(a) - 0.01, 0.0], 0.009)
    gem(m, "gem", ROSE, (0.02, 0.026, 0.012))
    return m, mats


# ---------------------------------------------------------------------------
# Wings: rose-gold feathers crossed by a musical staff
# ---------------------------------------------------------------------------

def feather(m, key, root, direction, normal, length, width, weights, curl=0.04, shaft=None):
    """One broad feather: a smooth vane rooted at root along direction, lying in the
    plane with the given normal (the camera side), its edges near parallel to a
    rounded tip; a raised shaft down its middle. Returns the vane's centre line."""
    d = np.asarray(direction, float)
    d /= np.linalg.norm(d)
    n = np.asarray(normal, float)
    n = n - d * np.dot(n, d)
    n /= np.linalg.norm(n)
    across = np.cross(n, d)
    centre = lambda t: root + d * length * t + n * (curl * length * t * t)
    grid, uvs = [], []
    for t in (0.0, 0.12, 0.32, 0.55, 0.74, 0.86, 0.94, 1.0):
        if t <= 0.78:
            w = width * (0.45 + 0.55 * min(1.0, t / 0.3))
        else:
            w = width * math.sqrt(max(0.0, 1.0 - ((t - 0.78) / 0.22) ** 2))
        c = centre(t)
        grid.append([c - across * w + n * 0.1 * w, c - n * 0.06 * width, c + across * w + n * 0.1 * w])
        uvs.append([(t, 0.0), (t, 0.5), (t, 1.0)])
    kit.sheet(m, key, grid, uvs, weights)
    if shaft:
        tube(m, shaft, [centre(0.0) - n * 0.08 * width, centre(0.45) - n * 0.08 * width, centre(0.9) - n * 0.06 * width],
             [width * 0.1, width * 0.08, width * 0.02], sides=3, caps=False, weights=weights)
    return centre


def wing_note(m, key, centre, up, right, size, weights, flag=True, beam=None):
    """A floating eighth note facing the camera behind the hero (-Z): a tilted head,
    a stem and a flag (or a beam to a second note's stem top)."""
    c = np.asarray(centre, float)
    sphere(m, key, tuple(c), size, rings=3, seg=7, squash=(1.35, 0.95, 0.6), weights=weights)
    top = c + right * size * 1.15 + up * size * 3.6
    tube(m, key, [c + right * size * 1.15, top], [size * 0.22, size * 0.18], sides=3, weights=weights)
    n = np.cross(right, up)
    if beam is not None:
        tube(m, key, [top, np.asarray(beam, float)], [size * 0.3, size * 0.3], sides=3, weights=weights)
    elif flag:
        pts = [top, top + right * size * 1.3 - up * size * 0.9, top + right * size * 1.1 - up * size * 1.9, top + right * size * 0.25 - up * size * 1.1]
        for face in (1.0, -1.0):
            peak = (pts[0] + pts[1] + pts[2] + pts[3]) / 4 + n * size * 0.2 * face
            for i in range(4):
                a, b = pts[i], pts[(i + 1) % 4]
                if np.dot(np.cross(b - a, peak - a), n * face) < 0:
                    a, b = b, a
                m.tri(key, a, b, peak, weights)
    return top


def song_wing(m, side, pos, jidx, star):
    """One wing of rose-gold (star: white-gold over rose) feathers: broad primaries fanned
    from the wrist, secondaries along the forearm, two rows of coverts over the roots,
    the five lines of a musical staff arcing across the fan with notes sitting on them,
    and glowing note heads at the tips of the longest primaries."""
    sx = 1.0 if side == "L" else -1.0
    names = ["Wing_%s_1" % side, "Wing_%s_2" % side, "Wing_%s_3" % side]
    weights = kit.wing_weights(jidx, pos, names)
    sh, el = pos[names[0]], pos[names[1]]
    wr = pos[names[2]] + np.array([0.02 * sx, 0.02, -0.02])
    grow = 1.22 if star else 1.0
    X = lambda x, y, z: np.array([x * sx, y, z])
    normal = X(0.06, -0.04, 1.0)
    camera = np.array([0.0, 0.0, -1.0])

    def fan(a_deg, back=0.0):
        """The wing plane's direction at angle a (degrees from out towards up)."""
        a = math.radians(a_deg)
        return np.array([math.cos(a) * sx, math.sin(a), -0.16 - 0.1 * (1.0 - (a_deg + 40.0) / 125.0) + back])

    # The arm: shoulder -> elbow -> wrist, gold.
    tube(m, "strut", [sh, el, wr, wr + fan(80.0) * 0.08 * grow], [0.017, 0.014, 0.012, 0.004], sides=6, weights=weights)
    # Primaries from the wrist, nearly upright to out-and-down, shingled towards the camera.
    count = 10 if star else 9
    lengths = [0.36, 0.45, 0.53, 0.59, 0.62, 0.6, 0.55, 0.48, 0.42, 0.36]
    primaries = []
    for k in range(count):
        t = k / (count - 1)
        a = 80.0 - 112.0 * t
        ln = lengths[int(round(t * 9))] * grow
        root = wr + X(0.012 * t, -0.03 * t, 0.0) + camera * 0.004 * (count - k)
        f = feather(m, "feather", root, fan(a), normal, ln, 0.05 * grow, weights, curl=0.035, shaft="strut")
        primaries.append((f, ln, a))
    # Secondaries along the forearm, falling out and down under the primaries.
    secondaries = 7 if star else 6
    for k in range(secondaries):
        t = k / (secondaries - 1)
        root = el + (wr - el) * (1.0 - t) + X(0.0, -0.01, 0.0) + camera * (0.002 * k - 0.004)
        a = -40.0 - 42.0 * t
        feather(m, "under", root, fan(a, -0.05), normal, (0.36 - 0.1 * t) * grow, 0.052 * grow, weights, curl=0.025)
    if star:
        # A lower rose wing behind the fan, spreading out and down from the elbow.
        for k in range(5):
            t = k / 4
            root = el + (wr - el) * (0.6 - 0.6 * t) + X(0.0, -0.03, 0.014)
            feather(m, "under", root, fan(-28.0 - 30.0 * t, -0.04), normal, (0.46 - 0.08 * t) * grow, 0.05 * grow, weights, curl=0.02)
    # Coverts over the roots, closest to the camera: a row along the arm and a short row
    # of scapulars at the shoulder.
    for k in range(8):
        t = k / 7
        root = sh + (wr - sh) * (0.2 + 0.85 * t) + camera * (0.03 + 0.002 * k)
        a = 50.0 - 115.0 * (1.0 - t) ** 1.2
        feather(m, "covert", root, fan(a), normal, (0.12 + 0.06 * math.sin(math.pi * t)) * grow, 0.036 * grow, weights, curl=0.02)
    for k in range(5):
        t = k / 4
        root = sh + (el - sh) * (0.1 + 0.8 * t) + camera * (0.05 + 0.002 * k)
        feather(m, "feather", root, fan(-30.0 - 40.0 * (1.0 - t)), normal, 0.1 * grow, 0.035 * grow, weights, curl=0.015)
    # The staff: a band of five glowing arcs across the primaries on the camera side,
    # running only where the feathers reach past it.
    lines = []
    for j in range(5):
        r = (0.27 + 0.032 * j) * grow
        top = 78.0 if r < 0.33 * grow else 64.0
        pts = [wr + fan(a) * r + camera * 0.03 for a in np.linspace(top, -30.0, 13)]
        tube(m, "staff", pts, [0.0028 * grow] * len(pts), sides=3, caps=False, weights=weights)
        lines.append(pts)
    up, right = np.array([0.0, 1.0, 0.0]), np.array([-sx, 0.0, 0.0])
    # Glowing note heads at the tips of the longest primaries.
    order = sorted(range(len(primaries)), key=lambda k: -primaries[k][1])
    for k in order[:(5 if star else 3)]:
        f, ln, a = primaries[k]
        wing_note(m, "notes", f(1.0) + camera * 0.02, up, right, 0.022 * grow, weights)
    # Notes sitting on the staff lines (a beamed pair on the star wings).
    spots = [(3, 1, True), (7, 3, True), (10, 2, False)] if not star else [(2, 1, True), (5, 3, True), (8, 0, True), (10, 2, False), (4, 4, False), (11, 4, True)]
    for i, line, flagged in spots:
        p = lines[line][i] + camera * 0.012
        wing_note(m, "notes", p, up, right, 0.016 * grow, weights, flag=flagged)
    if star:
        a, b = lines[1][6] + camera * 0.012, lines[2][7] + camera * 0.012
        top_b = b + right * 0.016 * grow * 1.15 + up * 0.016 * grow * 3.6
        wing_note(m, "notes", b, up, right, 0.016 * grow, weights, flag=False)
        wing_note(m, "notes", a, up, right, 0.016 * grow, weights, beam=top_b)
    # Mount at the shoulder blade.
    sphere(m, "strut", sh + np.array([0, 0, -0.01]), 0.028, rings=4, seg=8, weights=weights)
    gem(m, "notes", sh + np.array([0, 0, -0.036]), (0.009, 0.013, 0.006), weights=weights)


def bezier3(p0, p1, p2, p3, t):
    p0, p1, p2, p3 = (np.asarray(p, float) for p in (p0, p1, p2, p3))
    return p0 * (1 - t) ** 3 + p1 * 3 * t * (1 - t) ** 2 + p2 * 3 * t * t * (1 - t) + p3 * t ** 3


def lyre_halo(m, weights):
    """The star wings' lyre behind the head: two gold horns curving out and in to curled
    tips, a yoke across them, seven strings of light and an arc of constellation stars.
    Open in the middle and behind the head, so the face always shows."""
    z = -0.31
    for s in (-1.0, 1.0):
        horn = [bezier3((s * 0.08, 0.6, z), (s * 0.34, 0.66, z), (s * 0.34, 0.98, z), (s * 0.22, 1.08, z), t) for t in np.linspace(0, 1, 10)]
        horn.append(np.array([s * 0.25, 1.13, z]))
        horn.append(np.array([s * 0.29, 1.12, z]))
        tube(m, "halo", horn, [0.016, 0.017, 0.016, 0.014, 0.012, 0.011, 0.01, 0.009, 0.008, 0.007, 0.005, 0.002], sides=6, weights=weights)
        sphere(m, "notes", (s * 0.3, 1.115, z), 0.012, rings=3, seg=6, weights=weights)
    sphere(m, "halo", (0.0, 0.6, z + 0.005), 0.05, rings=4, seg=10, squash=(1.9, 0.7, 0.5), weights=weights)
    tube(m, "halo", [(-0.245, 1.035, z), (0.0, 1.05, z), (0.245, 1.035, z)], [0.008, 0.009, 0.008], sides=5, weights=weights)
    for k in range(7):
        x = (k - 3) * 0.032
        tube(m, "staff", [(x * 0.8, 0.62, z + 0.004), (x * 1.3, 1.04, z + 0.002)], [0.0022, 0.0022], sides=3, caps=False, weights=weights)
    for k in range(9):
        a = math.pi * (0.1 + 0.8 * k / 8)
        gem(m, "notes", (0.4 * math.cos(a), 0.86 + 0.4 * math.sin(a), z - 0.02), (0.012, 0.018, 0.006), weights=weights)


def note_wheel(m, centre, weights):
    """Eight notes on a thin gold ring round the WingHalo joint, turning like a music box."""
    c = np.asarray(centre, float)
    torus(m, "halo", tuple(c), (0, 0, 1), 0.36, 0.0045, seg=40, sides=4, weights=weights)
    torus(m, "staff", tuple(c), (0, 0, 1), 0.33, 0.0022, seg=40, sides=3, weights=weights)
    up, right = np.array([0.0, 1.0, 0.0]), np.array([-1.0, 0.0, 0.0])
    for k in range(8):
        a = 2 * math.pi * k / 8
        p = c + np.array([0.345 * math.cos(a), 0.345 * math.sin(a), -0.01])
        wing_note(m, "notes", p, up, right, 0.02, weights, flag=k % 2 == 0)


def wings(star):
    src = kit.Source(os.path.join(SRC, "star_wings" if star else "wings", "wings_mage.glb"))
    pos = src.joint_positions()
    joints = src.g["skins"][0]["joints"]
    jidx = {src.g["nodes"][j]["name"]: k for k, j in enumerate(joints)}
    m = Mesh()
    for side in ("L", "R"):
        song_wing(m, side, pos, jidx, star)
    if star:
        lyre_halo(m, kit.fixed_weight(jidx, "WingsRoot"))
        note_wheel(m, pos["WingHalo"] + np.array([0.0, 0.0, -0.015]), kit.fixed_weight(jidx, "WingHalo"))
    if not star:
        mats = {
            "feather": material("f8c4d2", 0.05, 0.55, glow="f8c4d2", glow_amount=0.12, double=True),
            "under": material("e08aac", 0.05, 0.55, glow="e08aac", glow_amount=0.1, double=True),
            "covert": material("f6c0b4", 0.1, 0.5, glow="f6c0b4", glow_amount=0.1, double=True),
            "strut": material("f0bc74", 0.3, 0.35),
            "staff": material("ffe6a0", 0.0, 0.3, glow="ffd36b", glow_amount=1.4),
            "notes": material("ff8fcf", 0.0, 0.25, glow="ff8fcf", glow_amount=1.6),
        }
    else:
        mats = {
            "feather": material("f9e9d6", 0.05, 0.55, glow="ffe8d0", glow_amount=0.08, double=True),
            "under": material("f49ac0", 0.08, 0.5, glow="f49ac0", glow_amount=0.14, double=True),
            "covert": material("fbdca0", 0.15, 0.4, glow="fbdca0", glow_amount=0.08, double=True),
            "strut": material("f6cc66", 0.35, 0.3),
            "staff": material("fff0c0", 0.0, 0.3, glow="ffd36b", glow_amount=1.6),
            "notes": material("ff9ad2", 0.0, 0.25, glow="ff9ad2", glow_amount=1.8),
            "halo": material("f2c45a", 0.85, 0.2, glow="ffd36b", glow_amount=0.5),
        }
    return m, mats


def main():
    report = []
    if not WINGS_ONLY:
        for tier in range(10):
            m, mats = lute(tier)
            size, tris = kit.write_static(os.path.join(OUT, "weapons", "lute_%d.glb" % tier), m, mats, "lute_%d" % tier)
            report.append(("weapons/lute_%d.glb" % tier, tris, size))
        m, mats = divine_lute()
        size, tris = kit.write_static(os.path.join(OUT, "divine_gear", "bard_lute.glb"), m, mats, "bard_lute")
        report.append(("divine_gear/bard_lute.glb", tris, size))
    for folder, star in (("wings", False), ("star_wings", True)):
        source = os.path.join(SRC, folder, "wings_mage.glb")
        m, mats = wings(star)
        size, tris = kit.write_skinned(os.path.join(OUT, folder, "wings_bard.glb"), source, m, mats)
        report.append(("%s/wings_bard.glb" % folder, tris, size))
    for name, tris, size in report:
        print("%-36s %6d tris %5d KB" % (name, tris, size // 1024))


if __name__ == "__main__":
    main()
