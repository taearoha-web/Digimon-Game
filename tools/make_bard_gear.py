#!/usr/bin/env python3
"""Author the Bard's lutes and wings procedurally (original geometry, no external art).

usage: python3 tools/make_bard_gear.py [--wings] [OUT_ROOT]   (OUT_ROOT defaults to assets/models;
       --wings rewrites only the two wing pairs)

What it writes (same layout and conventions as the other classes):
  weapons/lute_<0-9>.glb        Lv.10..100 lutes, static: the left hand closes on the neck at the
                                origin, the neck runs up +Y, the soundboard and strings face +Z
  divine_gear/bard_lute.glb     the 200-star lute of the heavenly song, static
  wings/wings_bard.glb          Lv.100 wings of heavenly notes on the mage wing rig (skinned + clips)
  star_wings/wings_bard.glb     star symphony wings: the same rig, grander, with a lower aurora wing,
                                a lyre behind the head and a circular staff of notes turning on the
                                rig's WingHalo joint

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
mesh is new. Every wing is a great raised angel's wing in three rows (long primaries
fanned from the hand, secondaries falling from the forearm, rounded coverts over
their roots), crossed by a ribbon of five gold staff lines with notes on it, with
notes drifting off its tips; a gold treble clef joins the pair at the back.
SongWingArt (characters/song_wing_art.gd) shades the feathers, the staff and the
drifting notes, finding them by material key; the keys are stable (they become glTF
material names). Shares the mesh helpers and GLB writer of
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


def star_gem(m, key, centre, outer, inner, points, depth, weights=None):
    outline = []
    for k in range(points * 2):
        a = math.pi * k / points
        r = outer if k % 2 == 0 else inner
        outline.append((r * math.sin(a), r * math.cos(a)))
    ridge(m, key, outline, centre, depth, plane=("x", "y"), weights=weights)


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
        # The god-tier: a crown, a floating gold halo set with stars behind the pegbox (solid
        # gold, not glowing: held, the pegbox is beside the hero's cheek), an
        # eight-point star at the bridge, a halo round the rosette and great wings.
        crown(m, "trim", tip + [0, 0.012, 0], 0.017, points=5, height=0.028)
        hc = tip + np.array([0, 0.04, -0.03])
        torus(m, "trim", tuple(hc), (0, 0.45, -0.89), 0.08, 0.0042, seg=24, sides=3)
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
                 "gem": material("ff9ad2", 0.1, 0.15, glow="ff9ad2", glow_amount=1.1),
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
# Wings: great layered feathered wings with a golden staff of music
# ---------------------------------------------------------------------------
# One wing, back to front as a camera behind the hero sees it:
#   aurora (star)  a lower wing of long plumes sweeping out and down under the great wing
#   primary        long flight feathers fanned from the hand at the wing's top, the
#                  outermost pointing up, the innermost out
#   secondary      the forearm's flight feathers falling out and down towards the hip
#   covert         greater coverts over their roots, a scalloped row of small coverts
#                  along the arm, the alula at the wrist and scapulars over the root
#   staff          a ribbon of five gold lines (a musical staff) sweeping along the wing
#                  in an S and trailing off past the tips, notes sitting on its lines
#   drift          notes rising off the wing tips and fading (SongWingArt moves them)
# Each wing is laid out in the left wing's frame (x out from the spine, y up) on a
# surface that bends back as it reaches out (wing_z), then mirrored for the right.
# Feathers carry UVs (x: root -> tip; y: across, 0 leading edge, 0.5 on the shaft, 1
# trailing edge, plus 2 x the feather's number), the staff ribbons (x: along, y:
# across its lines) and each drifting note (x: its phase) for SongWingArt's shaders;
# the bones, the clef, the lyre and the notes on the staff keep plain glTF materials.

def wing_z(x):
    """Depth of the wing surface x out from the spine: just behind the back at the root,
    bending back about 35 degrees, flattening out towards the tips."""
    return -0.07 - 0.75 * x + 0.22 * x * x


def unit(v):
    v = np.asarray(v, float)
    return v / np.linalg.norm(v)


class WingFrame:
    """The left wing's layout coordinates mapped onto one side: 2D (x out, y up) points
    scaled about the shoulder, set on the wing surface and lifted towards the camera
    behind the hero (lift)."""

    def __init__(self, sx, grow):
        self.sx, self.grow = sx, grow
        self.origin = np.array([0.045, 0.485])

    def flat(self, p):
        return self.origin + (np.asarray(p, float) - self.origin) * self.grow

    def at(self, p, lift=0.0):
        x, y = self.flat(p)
        return np.array([x * self.sx, y, wing_z(x)]) + self.normal(x) * lift

    def normal(self, x):
        """The camera side of the wing surface (back and towards the spine)."""
        return unit([(-0.75 + 0.44 * x) * self.sx, 0.0, -1.0])

    def direction(self, p, degrees):
        """A direction in the wing surface at p: degrees from straight out towards up."""
        x = self.flat(p)[0]
        a = math.radians(degrees)
        return unit([math.cos(a) * self.sx, math.sin(a), (-0.75 + 0.44 * x) * math.cos(a)])


def plume(m, key, root, d, nb, sx, length, width, weights, number, sweep=0.06, curl=None, rounded=False):
    """One tapered feather from root along d, facing the camera side nb: a narrow
    leading vane and a broad trailing vane on a shaft raised into a shallow ridge,
    swept towards the trailing side (sweep) and curled by curl x length at the tip.
    rounded: a covert's round tip instead of a flight feather's point."""
    d = unit(d)
    nb = unit(nb - d * np.dot(nb, d))
    side = unit(np.cross(nb, d)) * sx
    curl = -nb * 0.05 if curl is None else np.asarray(curl, float)
    stations = (0.0, 0.25, 0.5, 0.72, 0.88, 1.0) if rounded else (0.0, 0.14, 0.3, 0.46, 0.6, 0.73, 0.85, 0.94, 1.0)
    grid, uvs = [], []
    for t in stations:
        if t < 0.6:
            w = 0.5 + 0.5 * math.sin(0.5 * math.pi * min(1.0, t / 0.45))
        elif rounded:
            w = math.sqrt(max(0.0, 1.0 - ((t - 0.6) / 0.4) ** 2))
        else:
            w = ((1.0 - t) / 0.4) ** 0.85
        w *= width * 0.5
        c = root + d * length * t + side * sweep * length * t * t + curl * length * t * t
        grid.append([c - side * w * 0.8 - nb * 0.1 * w, c + nb * 0.16 * w, c + side * w * 1.2 - nb * 0.1 * w])
        uvs.append([(t, 2.0 * number), (t, 2.0 * number + 0.5), (t, 2.0 * number + 1.0)])
    kit.sheet(m, key, grid, uvs, weights)


def stamp(m, key, build, uv, weights):
    """Builds a small part (build(mesh, key)) and copies it into m under key with one UV
    on every vertex, so a shader can move it as a whole."""
    tmp = Mesh()
    build(tmp, "x")
    part, out = tmp.parts["x"], m._part(key)
    for p, n in zip(part["p"], part["n"]):
        out["p"].append(p)
        out["n"].append(n)
        out["w"].append(weights(p))
        out["uv"].append(uv)


def wing_note(m, key, centre, size, weights, flag=True):
    """A floating note facing the camera behind the hero (-Z), written the same way
    round on both wings: a tilted head, a stem and (an eighth note) a flag."""
    c = np.asarray(centre, float)
    up, right = np.array([0.0, 1.0, 0.0]), np.array([-1.0, 0.0, 0.0])
    sphere(m, key, tuple(c), size, rings=3, seg=6, squash=(1.35, 0.95, 0.6), weights=weights)
    top = c + right * size * 1.15 + up * size * 3.6
    tube(m, key, [c + right * size * 1.15, top], [size * 0.24, size * 0.2], sides=3, weights=weights)
    if flag:
        n = np.array([0.0, 0.0, -1.0])
        pts = [top, top + right * size * 1.3 - up * size * 0.9, top + right * size * 1.1 - up * size * 1.9, top + right * size * 0.25 - up * size * 1.1]
        for face in (1.0, -1.0):
            peak = (pts[0] + pts[1] + pts[2] + pts[3]) / 4 + n * size * 0.2 * face
            for i in range(4):
                a, b = pts[i], pts[(i + 1) % 4]
                if np.dot(np.cross(b - a, peak - a), n * face) < 0:
                    a, b = b, a
                m.tri(key, a, b, peak, weights)
    return top


def bezier3(p0, p1, p2, p3, t):
    p0, p1, p2, p3 = (np.asarray(p, float) for p in (p0, p1, p2, p3))
    return p0 * (1 - t) ** 3 + p1 * 3 * t * (1 - t) ** 2 + p2 * 3 * t * t * (1 - t) + p3 * t ** 3


def lerp_list(values, u):
    """values sampled evenly over 0..1, read at u."""
    f = u * (len(values) - 1)
    i = min(int(f), len(values) - 2)
    return values[i] + (values[i + 1] - values[i]) * (f - i)


# The left wing's layout (x out from the spine, y up; Lv.100 size before WingFrame's
# grow). The leading edge leaves the shoulder outwards, sweeps up and eases out again
# in a gentle S to the wing's top, where the hand fans the primaries from out to
# straight up; the forearm below carries the secondaries, falling to the hip. (The
# rig's wrist joint is lower, at (0.19, 0.70): everything past it rides that joint.)
# How far a wing reaches out is held near 0.85: folded, that reach points down.
EDGE = [(0.05, 0.50), (0.25, 0.60), (0.40, 0.92), (0.58, 1.12)]
HAND_FROM = 0.6           # where along the edge the hand (the primaries) begins
PRIMARY_LENGTHS = [0.36, 0.44, 0.49, 0.52, 0.52, 0.51, 0.5, 0.48, 0.46, 0.45, 0.44]


def edge(s):
    """The leading edge, s from the shoulder (0) to the wing's tip (1)."""
    return bezier3(*EDGE, s)


def flight_angle(s):
    """Direction (degrees from straight out towards up) of the flight feather rooted at
    edge(s): the secondaries fall out and down, the primaries fan from out to up."""
    if s < HAND_FROM:
        return -86.0 + 56.0 * max(0.0, s - 0.06) / (HAND_FROM - 0.06)
    return -24.0 + 104.0 * (s - HAND_FROM) / (1.0 - HAND_FROM)


def primary(u):
    """Root, direction (degrees) and length of the primary u of the way in from the tip."""
    s = 1.0 - (1.0 - HAND_FROM) * u
    return edge(s), flight_angle(s), lerp_list(PRIMARY_LENGTHS, u)


def song_wing(m, side, pos, jidx, star, number):
    """One great wing: primaries, secondaries, coverts, the alula and scapulars, the gold
    arm, the staff ribbon with its notes, the drifting notes (star: and the aurora wing).
    number: the first feather number (UV) of this wing."""
    sx = 1.0 if side == "L" else -1.0
    names = ["Wing_%s_1" % side, "Wing_%s_2" % side, "Wing_%s_3" % side]
    weights = kit.wing_weights(jidx, pos, names)
    f = WingFrame(sx, 1.08 if star else 0.94)
    n = [number]

    def feather(key, p, degrees, length, width, lift, **kw):
        root = f.at(p, lift)
        plume(m, key, root, f.direction(p, degrees), f.normal(f.flat(p)[0]), sx, length * f.grow, width * f.grow, weights, n[0], **kw)
        n[0] += 1

    def outside(s, by):
        """The point by ahead of the leading edge at edge(s) (negative: behind it)."""
        t = edge(min(s + 0.01, 1.0)) - edge(max(s - 0.01, 0.0))
        t = t / np.linalg.norm(t)
        return edge(s) + np.array([-t[1], t[0]]) * by

    # The aurora (star): a lower wing of long plumes behind the great one, sweeping out
    # and down past the trailing edge between the primaries and the secondaries.
    if star:
        for k in range(7):
            u = k / 6
            feather("aurora", edge(0.5 - 0.3 * u), -34.0 - 28.0 * u, 0.66 - 0.1 * u, 0.1, -0.03 - 0.002 * k, sweep=0.14, curl=f.normal(0.5) * -0.04)
    # Primaries, outermost first: each inner feather lies over the next outer one.
    count = 13 if star else 11
    for i in range(count):
        p, degrees, length = primary(i / (count - 1))
        feather("primary", p, degrees, length, 0.1, 0.004 * i, sweep=0.12)
    # Secondaries along the forearm, falling out and down; their tips sweep back off
    # the hero's back. Outermost first, so each inner one lies over the next.
    count = 10 if star else 9
    for j in range(count):
        s = HAND_FROM - 0.02 - (HAND_FROM - 0.1) * j / (count - 1)
        feather("secondary", edge(s), flight_angle(s), 0.5 - 0.16 * j / (count - 1), 0.115, 0.05 + 0.004 * j, sweep=-0.05,
                curl=np.array([0.0, 0.0, -0.12]) - f.normal(0.1) * 0.02)
    # Greater coverts over the flight feathers' roots, from the shoulder out to the tip.
    count = 15 if star else 13
    for k in range(count):
        s = 0.07 + 0.9 * k / (count - 1)
        reach = 0.24 if s < HAND_FROM else 0.24 - 0.08 * (s - HAND_FROM) / (1.0 - HAND_FROM)
        feather("covert", edge(s), flight_angle(s) + 6.0, reach, 0.09, 0.085 + 0.003 * k, rounded=True, curl=f.normal(0.3) * -0.04)
    # Small coverts along the leading edge, rounded like scales.
    count = 12 if star else 10
    for k in range(count):
        s = 0.04 + 0.86 * k / (count - 1)
        feather("covert", outside(s, 0.015), flight_angle(s) + 14.0, 0.115 + 0.02 * math.sin(math.pi * k / (count - 1)), 0.075, 0.12 + 0.002 * k,
                rounded=True, sweep=0.02)
    # The alula where the hand begins and scapulars over the root.
    for k in range(3):
        s = HAND_FROM + 0.03 * k
        feather("covert", outside(s, 0.02), flight_angle(s) + 62.0 - 6.0 * k, 0.12 + 0.035 * k, 0.06, 0.14 + 0.003 * k, sweep=0.08)
    for k in range(4):
        feather("covert", (0.04 + 0.025 * k, 0.56 - 0.01 * k), -96.0 + 7.0 * k, 0.15, 0.08, 0.15 + 0.004 * k, rounded=True, curl=np.array([0.0, 0.0, -0.08]))
    # The arm: a gold bone along the leading edge from the shoulder to the tip.
    bone = [f.at(outside(s, 0.01), 0.11) for s in np.linspace(0.02, 0.97, 9)]
    tube(m, "strut", bone, [0.016 - 0.0014 * k for k in range(8)] + [0.003], sides=6, weights=weights)
    sphere(m, "strut", f.at(edge(HAND_FROM), 0.12), 0.02, rings=4, seg=8, weights=weights)
    gem(m, "notes", f.at(edge(HAND_FROM), 0.14), (0.012, 0.018, 0.008), weights=weights)
    # The staff: a ribbon of five gold lines in an S just inside the leading edge, from
    # the shoulder over the coverts and the primaries, its free tail flowing on past the
    # tip and curling down.
    curve = [outside(s, -0.14 - 0.04 * s) for s in np.linspace(0.1, 0.96, 20)]
    end, d = curve[-1], curve[-1] - curve[-2]
    d = d / np.linalg.norm(d)
    curve += [bezier3(end, end + d * 0.1, end + d * 0.2 + np.array([0.06, -0.06]), end + d * 0.16 + np.array([0.1, -0.18]), t) for t in np.linspace(0, 1, 9)[1:]]
    half = 0.034 * f.grow
    centres = [f.at(p, 0.2) for p in curve]
    grid, uvs, frames = [], [], []
    for k, c in enumerate(centres):
        tangent = unit(centres[min(k + 1, len(centres) - 1)] - centres[max(k - 1, 0)])
        nb = f.normal(f.flat(curve[k])[0])
        across = unit(np.cross(nb, tangent))
        u = k / (len(centres) - 1)
        twist = math.radians(80.0) * max(0.0, (u - 0.7) / 0.3) ** 1.5
        across = across * math.cos(twist) + nb * math.sin(twist)
        grid.append([c - across * half, c + across * half])
        uvs.append([(u, 0.0), (u, 1.0)])
        frames.append((c, across))
    kit.sheet(m, "staff", grid, uvs, weights)
    # Notes sitting on the staff's lines.
    spots = [(5, 1), (9, 3), (13, 2), (17, 0)] if not star else [(4, 1), (7, 3), (10, 0), (13, 2), (16, 4), (19, 1)]
    size = 0.019 * f.grow
    for k, line in spots:
        c, across = frames[k]
        wing_note(m, "notes", c + across * half * (line / 2.0 - 1.0) + np.array([0, 0, -0.012]), size, weights, flag=k % 2 == 1)
    # Notes drifting off the wing tips: each rises and fades, then starts again.
    tips = [0, 2, 4, 6, 8, 10][:6 if star else 4]
    for k, i in enumerate(tips):
        p, degrees, length = primary(i / 10.0)
        a = math.radians(degrees)
        tip = np.array(p) + np.array([math.cos(a), math.sin(a)]) * length * 1.02
        centre = f.at(tip, 0.06)
        phase = (k / len(tips) + (0.5 if sx < 0 else 0.0)) % 1.0
        stamp(m, "drift", lambda mm, key, c=centre, fl=k % 2 == 0: wing_note(mm, key, c, 0.024 * f.grow, None, flag=fl), (phase, 0.0), weights)
    return n[0]


def clef(m, key, origin, scale, weights):
    """A treble clef in gold at the centre of the back, joining the wings' roots: the
    bowl spirals out from its centre, the line climbs into the top loop, and the stem
    falls straight through the bowl to a hook with a ball."""
    pts = []
    for k in range(27):
        th = -0.4 + (2 * math.pi + math.pi / 2 + 0.4) * k / 26
        r = 0.045 + 0.17 * k / 26
        pts.append((r * math.cos(th), 0.30 + r * math.sin(th)))
    pts += [(-0.07, 0.53), (-0.13, 0.59), (-0.15, 0.67), (-0.12, 0.77), (-0.05, 0.87), (0.03, 0.96), (0.07, 1.03), (0.05, 1.07), (0.01, 1.03), (-0.01, 0.94)]
    pts += [(0.0, 0.8), (0.01, 0.6), (0.02, 0.35), (0.03, 0.1), (0.025, -0.06), (0.0, -0.14), (-0.05, -0.17), (-0.09, -0.15)]
    o = np.asarray(origin, float)
    at = lambda p: o + np.array([-p[0] * scale, p[1] * scale, 0.0])
    radii = [scale * (0.026 + 0.014 * math.sin(math.pi * k / 26)) for k in range(27)] + [scale * 0.024] * 10 + [scale * 0.03] * 8
    tube(m, key, [at(p) for p in pts], radii, sides=5, weights=weights)
    sphere(m, key, tuple(at((-0.1, -0.12))), scale * 0.055, rings=4, seg=8, weights=weights)


def lyre_halo(m, weights):
    """The star wings' lyre behind the head: two gold horns sweeping out and up into
    scrolls, a yoke with a star at its crown, seven strings of light and an arc of
    constellation stars. Open in the middle and behind the head, so the face shows."""
    z = -0.42
    for s in (-1.0, 1.0):
        horn = [bezier3((s * 0.07, 0.56, z), (s * 0.42, 0.62, z), (s * 0.42, 1.0, z), (s * 0.27, 1.16, z), t) for t in np.linspace(0, 1, 12)]
        curl = [np.array([s * (0.27 + 0.045 * math.sin(a)), 1.16 + 0.045 - 0.045 * math.cos(a) + 0.01, z]) for a in np.linspace(0.6, 4.2, 7)]
        pts = horn + curl
        radii = [0.02 - 0.012 * k / (len(pts) - 1) for k in range(len(pts))]
        tube(m, "halo", pts, radii, sides=6, weights=weights)
        gem(m, "gems", (s * 0.38, 0.8, z - 0.02), (0.016, 0.026, 0.01), weights=weights)
    sphere(m, "halo", (0.0, 0.56, z + 0.005), 0.05, rings=4, seg=10, squash=(2.0, 0.7, 0.5), weights=weights)
    tube(m, "halo", [(-0.3, 1.13, z), (0.0, 1.16, z), (0.3, 1.13, z)], [0.009, 0.011, 0.009], sides=5, weights=weights)
    star_gem(m, "gems", (0.0, 1.21, z - 0.01), 0.05, 0.02, 5, 0.012, weights)
    for k in range(7):
        x = (k - 3) * 0.04
        tube(m, "strings", [(x * 0.7, 0.58, z + 0.004), (x * 1.35, 1.14, z + 0.002)], [0.0024, 0.0024], sides=3, caps=False, weights=weights)
    for k in range(11):
        a = math.pi * (0.06 + 0.88 * k / 10)
        r = 0.58 if k % 2 == 0 else 0.53
        gem(m, "gems", (r * math.cos(a), 0.78 + r * math.sin(a) * 0.82, z - 0.03), (0.014, 0.022, 0.007), weights=weights)


def note_wheel(m, centre, weights):
    """A circular staff on the rig's WingHalo joint behind the wings, five gold lines
    turning like a music box disc with eight notes riding on them."""
    c = np.asarray(centre, float)
    grid, uvs = [], []
    for k in range(49):
        a = 2 * math.pi * k / 48
        d = np.array([math.cos(a), math.sin(a), 0.0])
        grid.append([c + d * 0.47, c + d * 0.53])
        uvs.append([(k / 48, 0.0), (k / 48, 1.0)])
    kit.sheet(m, "wheel", grid, uvs, weights)
    for k in range(8):
        a = 2 * math.pi * k / 8 + 0.2
        r = 0.47 + 0.015 * (k % 5)
        wing_note(m, "notes", c + np.array([r * math.cos(a), r * math.sin(a), -0.012]), 0.024, weights, flag=k % 2 == 0)


def wings(star):
    src = kit.Source(os.path.join(SRC, "star_wings" if star else "wings", "wings_mage.glb"))
    pos = src.joint_positions()
    joints = src.g["skins"][0]["joints"]
    jidx = {src.g["nodes"][j]["name"]: k for k, j in enumerate(joints)}
    m = Mesh()
    number = 0
    for side in ("L", "R"):
        number = song_wing(m, side, pos, jidx, star, number)
    fixed = kit.fixed_weight(jidx, "WingsRoot")
    clef(m, "clef", (0.0, 0.36, -0.17), 0.33 if star else 0.3, fixed)
    if star:
        lyre_halo(m, fixed)
        note_wheel(m, pos["WingHalo"] + np.array([0.0, 0.0, -0.26]), kit.fixed_weight(jidx, "WingHalo"))
    # Fallback looks; SongWingArt swaps the feathers, the staff, the wheel and the
    # drifting notes for its animated shaders.
    if not star:
        mats = {
            "primary": material("fbe6dc", 0.05, 0.6, double=True),
            "secondary": material("fcece2", 0.05, 0.6, double=True),
            "covert": material("fff6ee", 0.05, 0.6, double=True),
            "strut": material("f0c060", 0.5, 0.3),
            "clef": material("f2c45a", 0.5, 0.28, glow="ffcf70", glow_amount=0.2),
            "staff": material("ffd36b", 0.0, 0.3, glow="ffd36b", glow_amount=0.8, alpha=0.6, double=True),
            "notes": material("ffb8dc", 0.1, 0.3, glow="ff8fcf", glow_amount=0.6),
            "drift": material("ffc8e8", 0.0, 0.3, glow="ff9ad2", glow_amount=0.9),
        }
    else:
        mats = {
            "aurora": material("c8a0f0", 0.05, 0.5, glow="b08af0", glow_amount=0.2, double=True),
            "primary": material("f4dcf4", 0.05, 0.55, double=True),
            "secondary": material("f2e2f6", 0.05, 0.55, double=True),
            "covert": material("fcf6ff", 0.05, 0.55, double=True),
            "strut": material("f6cc66", 0.5, 0.28),
            "clef": material("f6cc66", 0.5, 0.25, glow="ffd36b", glow_amount=0.25),
            "staff": material("ffe08a", 0.0, 0.3, glow="ffd36b", glow_amount=0.9, alpha=0.6, double=True),
            "wheel": material("ffe08a", 0.0, 0.3, glow="ffd36b", glow_amount=0.9, alpha=0.6, double=True),
            "notes": material("ffc0e4", 0.1, 0.3, glow="ff9ad2", glow_amount=0.7),
            "drift": material("e0c8ff", 0.0, 0.3, glow="c8a8ff", glow_amount=1.0),
            "halo": material("f2c45a", 0.55, 0.25, glow="ffd36b", glow_amount=0.2),
            "strings": material("fff0c0", 0.0, 0.3, glow="ffe6a0", glow_amount=0.6),
            "gems": material("e8dcff", 0.1, 0.2, glow="c8b0ff", glow_amount=0.8),
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
