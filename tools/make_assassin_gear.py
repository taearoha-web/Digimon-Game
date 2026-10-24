#!/usr/bin/env python3
"""Author the Assassin's models procedurally (original geometry, no external art).

usage: python3 tools/make_assassin_gear.py [--wings] [OUT_ROOT]   (OUT_ROOT defaults to assets/models;
       --wings rewrites only the two wing pairs)

What it writes (same layout and conventions as the other classes):
  weapons/dagger_<0-9>.glb             Lv.10..100 daggers, static, grip at the origin, blade up +Y
  divine_gear/assassin_dagger.glb      the 200-star eclipse dagger, static
  wings/wings_assassin.glb             Lv.100 night wings (main + under wing, kunai fan, tendrils), skinned + clips
  star_wings/wings_assassin.glb        star wings: the same grown, a phantom double and the eclipse halo

Weapons follow WeaponKit: the real grip sits at the origin, the long axis along
+Y and the blade's flat faces towards +-Z. Wings reuse the armature, bind poses
and Unfold / Fold / Glide / Flap / Idle (and HaloSpin) clips of the mage's
wings, so they fold, flap and glide exactly like every other class's pair; only
the skinned mesh is new. Colours are authored in sRGB and stored linear, as glTF
requires. Requires numpy.
"""
import json
import math
import os
import struct
import sys

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
WINGS_ONLY = "--wings" in sys.argv[1:]
OUT = ARGS[0] if ARGS else os.path.join(ROOT, "assets", "models")


def lin(hex_color):
    c = [int(hex_color[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return [round(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4, 5) for x in c]


def material(color, metal=0.25, rough=0.4, glow=None, glow_amount=1.0, alpha=1.0, double=False):
    m = {"pbrMetallicRoughness": {"baseColorFactor": lin(color) + [alpha], "metallicFactor": metal, "roughnessFactor": rough}}
    if glow:
        m["emissiveFactor"] = [round(v * glow_amount, 5) for v in lin(glow)]
    if alpha < 1.0:
        m["alphaMode"] = "BLEND"
    if double:
        m["doubleSided"] = True
    return m


class Mesh:
    """Triangle soup per material. Skinned meshes carry one weight row per vertex;
    parts drawn by a runtime shader carry a UV per vertex (see sheet())."""

    def __init__(self):
        self.parts = {}

    def _part(self, key):
        return self.parts.setdefault(key, {"p": [], "n": [], "w": [], "uv": []})

    def tri(self, key, a, b, c, weights=None, normal=None, uv=None):
        a, b, c = np.asarray(a, float), np.asarray(b, float), np.asarray(c, float)
        n = np.cross(b - a, c - a) if normal is None else np.asarray(normal, float)
        length = np.linalg.norm(n)
        if length < 1e-12:
            return
        n = n / length
        part = self._part(key)
        for k, v in enumerate((a, b, c)):
            part["p"].append(v)
            part["n"].append(n)
            part["w"].append(weights(v) if weights else None)
            part["uv"].append(uv[k] if uv is not None else None)

    def quad(self, key, a, b, c, d, weights=None):
        self.tri(key, a, b, c, weights)
        self.tri(key, a, c, d, weights)

    def smooth_tri(self, key, verts, normals, weights=None, uvs=None):
        part = self._part(key)
        for k, (v, n) in enumerate(zip(verts, normals)):
            part["p"].append(np.asarray(v, float))
            nn = np.asarray(n, float)
            part["n"].append(nn / max(np.linalg.norm(nn), 1e-12))
            part["w"].append(weights(v) if weights else None)
            part["uv"].append(uvs[k] if uvs is not None else None)


# ---------------------------------------------------------------------------
# Building blocks (all in model units)
# ---------------------------------------------------------------------------

def frame(axis):
    axis = np.asarray(axis, float)
    axis = axis / np.linalg.norm(axis)
    helper = np.array([0.0, 0.0, 1.0]) if abs(axis[2]) < 0.9 else np.array([1.0, 0.0, 0.0])
    u = np.cross(axis, helper)
    u /= np.linalg.norm(u)
    v = np.cross(axis, u)
    return axis, u, v


def tube(m, key, points, radii, sides=8, weights=None, caps=True):
    """A smooth tube through points with a radius per point."""
    points = [np.asarray(p, float) for p in points]
    rings = []
    for i, p in enumerate(points):
        a = points[max(i - 1, 0)]
        b = points[min(i + 1, len(points) - 1)]
        axis, u, v = frame(b - a)
        ring = []
        for s in range(sides):
            t = 2 * math.pi * s / sides
            d = u * math.cos(t) + v * math.sin(t)
            ring.append((p + d * radii[i], d))
        rings.append(ring)
    for i in range(len(points) - 1):
        for s in range(sides):
            s2 = (s + 1) % sides
            a, b, c, d = rings[i][s], rings[i + 1][s], rings[i + 1][s2], rings[i][s2]
            m.smooth_tri(key, [a[0], b[0], c[0]], [a[1], b[1], c[1]], weights)
            m.smooth_tri(key, [a[0], c[0], d[0]], [a[1], c[1], d[1]], weights)
    if caps:
        for end, sign in ((0, -1.0), (len(points) - 1, 1.0)):
            centre = points[end]
            axis = points[min(end + 1, len(points) - 1)] - points[max(end - 1, 0)]
            for s in range(sides):
                s2 = (s + 1) % sides
                a, b = rings[end][s][0], rings[end][s2][0]
                if sign > 0:
                    m.tri(key, centre, a, b, weights)
                else:
                    m.tri(key, centre, b, a, weights)


def cylinder(m, key, y0, y1, r0, r1=None, sides=10, x=0.0, z=0.0):
    tube(m, key, [(x, y0, z), (x, y1, z)], [r0, r0 if r1 is None else r1], sides)


def torus(m, key, centre, axis, radius, thick, seg=20, sides=6, weights=None):
    centre = np.asarray(centre, float)
    axis, u, v = frame(axis)
    rings = []
    for i in range(seg):
        t = 2 * math.pi * i / seg
        c = centre + (u * math.cos(t) + v * math.sin(t)) * radius
        out = (u * math.cos(t) + v * math.sin(t))
        ring = []
        for s in range(sides):
            a = 2 * math.pi * s / sides
            d = out * math.cos(a) + axis * math.sin(a)
            ring.append((c + d * thick, d))
        rings.append(ring)
    for i in range(seg):
        j = (i + 1) % seg
        for s in range(sides):
            s2 = (s + 1) % sides
            a, b, c, d = rings[i][s], rings[j][s], rings[j][s2], rings[i][s2]
            m.smooth_tri(key, [a[0], b[0], c[0]], [a[1], b[1], c[1]], weights)
            m.smooth_tri(key, [a[0], c[0], d[0]], [a[1], c[1], d[1]], weights)


def sphere(m, key, centre, radius, rings=6, seg=10, squash=(1.0, 1.0, 1.0), weights=None):
    centre = np.asarray(centre, float)
    sq = np.asarray(squash, float)
    grid = []
    for r in range(rings + 1):
        phi = math.pi * r / rings
        row = []
        for s in range(seg + 1):
            th = 2 * math.pi * s / seg
            d = np.array([math.sin(phi) * math.cos(th), math.cos(phi), math.sin(phi) * math.sin(th)])
            row.append((centre + d * radius * sq, d / sq))
        grid.append(row)
    for r in range(rings):
        for s in range(seg):
            a, b, c, d = grid[r][s], grid[r + 1][s], grid[r + 1][s + 1], grid[r][s + 1]
            m.smooth_tri(key, [a[0], b[0], c[0]], [a[1], b[1], c[1]], weights)
            m.smooth_tri(key, [a[0], c[0], d[0]], [a[1], c[1], d[1]], weights)


def gem(m, key, centre, size, weights=None):
    """A faceted octahedron: width x, height y, depth z."""
    c = np.asarray(centre, float)
    sx, sy, sz = size
    top, bottom = c + (0, sy, 0), c - (0, sy, 0)
    ring = [c + (sx, 0, 0), c + (0, 0, sz), c - (sx, 0, 0), c - (0, 0, sz)]
    for i in range(4):
        a, b = ring[i], ring[(i + 1) % 4]
        m.tri(key, top, b, a, weights)
        m.tri(key, bottom, a, b, weights)


def ridge(m, key, outline, centre, depth, plane=("x", "y"), weights=None, offset=(0, 0, 0)):
    """A bevelled flat silhouette: every edge rises to a ridge point on both faces.
    outline: 2D points in the plane; depth: ridge height along the plane normal."""
    axes = {"x": np.array([1.0, 0, 0]), "y": np.array([0, 1.0, 0]), "z": np.array([0, 0, 1.0])}
    ua, va = axes[plane[0]], axes[plane[1]]
    normal = np.cross(ua, va)
    centre = np.asarray(centre, float) + np.asarray(offset, float)
    mid = np.mean(np.asarray(outline, float), axis=0)
    pts = [centre + ua * p[0] + va * p[1] for p in outline]
    peak_mid = centre + ua * mid[0] + va * mid[1]
    for face in (1.0, -1.0):
        peak = peak_mid + normal * depth * face
        for i in range(len(pts)):
            a, b = pts[i], pts[(i + 1) % len(pts)]
            n = np.cross(b - a, peak - a)
            if np.dot(n, normal * face) < 0:
                a, b = b, a
            m.tri(key, a, b, peak, weights)


def blade(m, key, y0, length, profile, thick, curve=0.0, wave=0.0, waves=0, zig=0.0, rows=26, edge=None, fuller=None):
    """A double-edged dagger blade along +Y with a diamond cross-section.
    profile(t) -> half width at t in 0..1 (0 at the guard, 1 at the tip)."""
    def centre_x(t):
        x = curve * t * t
        if waves:
            x += wave * math.sin(t * math.pi * waves) * (1.0 - 0.6 * t)
        if zig:
            phase = (t * 6.0) % 2.0
            x += zig * (phase if phase < 1.0 else 2.0 - phase) - zig * 0.5
        return x
    rings = []
    for i in range(rows + 1):
        t = i / rows
        w = max(profile(t), 0.0) if i < rows else 0.0
        y = y0 + t * length
        cx = centre_x(t)
        th = thick * (0.35 + 0.65 * (w / max(profile(0.0), 1e-6)))
        rings.append([np.array([cx - w, y, 0.0]), np.array([cx, y, th]), np.array([cx + w, y, 0.0]), np.array([cx, y, -th])])
    for i in range(rows):
        for k in range(4):
            k2 = (k + 1) % 4
            a, b, c, d = rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]
            m.tri(key, a, b, c)
            m.tri(key, a, c, d)
    base = rings[0]
    m.tri(key, base[0], base[2], base[1])
    m.tri(key, base[0], base[3], base[2])
    if edge:
        # A glowing line just outside both cutting edges.
        for side in (0, 2):
            pts = [rings[i][side] + np.array([(-1 if side == 0 else 1) * 0.0025, 0, 0]) for i in range(1, rows)]
            tube(m, edge, pts, [0.0045] * len(pts), sides=4, caps=False)
    if fuller:
        # The fuller: a dark inlaid channel down both faces.
        for face in (1, 3):
            pts = [rings[i][face] * np.array([1, 1, 1.02]) for i in range(2, int(rows * 0.7))]
            tube(m, fuller, pts, [0.004] * len(pts), sides=4, caps=False)
    return rings


# ---------------------------------------------------------------------------
# Daggers
# ---------------------------------------------------------------------------

def grip(m, wrap_key, grip_key, pommel_key, rings=4, pommel="ball", length=0.19):
    cylinder(m, grip_key, -length + 0.04, 0.075, 0.019, 0.017)
    for i in range(rings):
        y = -length + 0.07 + i * (length - 0.02) / max(rings, 1)
        torus(m, wrap_key, (0, y, 0), (0, 1, 0), 0.0195, 0.005, seg=14, sides=4)
    base = -length + 0.035
    if pommel == "ball":
        sphere(m, pommel_key, (0, base - 0.015, 0), 0.03)
    elif pommel == "disc":
        cylinder(m, pommel_key, base - 0.025, base, 0.034, 0.03, sides=12)
    elif pommel == "gem":
        gem(m, pommel_key, (0, base - 0.03, 0), (0.026, 0.04, 0.026))
    elif pommel == "fang":
        tube(m, pommel_key, [(0, base, 0), (0.012, base - 0.04, 0), (0.03, base - 0.07, 0)], [0.022, 0.014, 0.002])
    elif pommel == "crown":
        cylinder(m, pommel_key, base - 0.02, base, 0.03, 0.026, sides=10)
        for k in range(5):
            a = 2 * math.pi * k / 5
            tube(m, pommel_key, [(math.cos(a) * 0.024, base - 0.02, math.sin(a) * 0.024), (math.cos(a) * 0.03, base - 0.05, math.sin(a) * 0.03)], [0.007, 0.001], sides=5)
    elif pommel == "star":
        for k in range(4):
            a = math.pi * k / 2
            tube(m, pommel_key, [(0, base - 0.02, 0), (math.cos(a) * 0.05, base - 0.03, math.sin(a) * 0.05)], [0.01, 0.001], sides=5)
        sphere(m, pommel_key, (0, base - 0.02, 0), 0.022)


def straight_guard(m, key, half, y=0.085, bend=0.0, thick=0.014):
    pts = [(-half, y + bend, 0), (-half * 0.5, y, 0), (0, y, 0), (half * 0.5, y, 0), (half, y + bend, 0)]
    tube(m, key, pts, [thick * 0.7, thick, thick * 1.2, thick, thick * 0.7], sides=8)


def dagger(tier):
    m = Mesh()
    mats = {}
    def mat(name, *args, **kw):
        mats[name] = material(*args, **kw)
        return name
    L = [0.44, 0.47, 0.5, 0.52, 0.55, 0.56, 0.58, 0.6, 0.62, 0.66][tier]
    y0 = 0.1
    if tier == 0:
        steel = mat("blade", "b8c0cc", 0.35, 0.45)
        iron = mat("iron", "7a7f88", 0.4, 0.5)
        wood = mat("grip", "6b4a2f", 0.0, 0.8)
        blade(m, steel, y0, L, lambda t: 0.042 * (1 - t ** 1.6), 0.012)
        straight_guard(m, iron, 0.085)
        grip(m, iron, wood, iron, rings=2, pommel="ball")
    elif tier == 1:
        steel = mat("blade", "d6dde8", 0.4, 0.35)
        dark = mat("fuller", "5d6575", 0.3, 0.5)
        guard = mat("guard", "9aa3b0", 0.45, 0.4)
        leather = mat("grip", "3d2a20", 0.0, 0.85)
        bronze = mat("wrap", "b07a3a", 0.5, 0.4)
        blade(m, steel, y0, L, lambda t: 0.046 * (1 - t ** 1.5), 0.012, fuller=dark)
        straight_guard(m, guard, 0.095, bend=-0.03)
        grip(m, bronze, leather, guard, rings=3, pommel="disc")
    elif tier == 2:
        mith = mat("blade", "cfe8ff", 0.5, 0.25)
        silver = mat("guard", "e8eef6", 0.6, 0.3)
        navy = mat("grip", "23324f", 0.0, 0.7)
        blue = mat("gem", "3fa4ff", 0.1, 0.2, glow="3fa4ff", glow_amount=0.35)
        blade(m, mith, y0, L, lambda t: 0.05 * math.sin(math.pi * min(0.3 + t * 0.85, 1.0)) * (1 - t ** 3) + 0.004 * (1 - t), 0.012, fuller=silver)
        straight_guard(m, silver, 0.1, bend=-0.035)
        gem(m, blue, (0, 0.087, 0.018), (0.016, 0.022, 0.01))
        gem(m, blue, (0, 0.087, -0.018), (0.016, 0.022, 0.01))
        grip(m, silver, navy, blue, rings=3, pommel="gem")
    elif tier == 3:
        steel = mat("blade", "e9edf3", 0.45, 0.3)
        gold = mat("gold", "f0c050", 0.7, 0.3)
        red = mat("gem", "d02040", 0.1, 0.2, glow="d02040", glow_amount=0.25)
        crimson = mat("grip", "6a1424", 0.0, 0.7)
        blade(m, steel, y0, L, lambda t: 0.05 * (1 - t ** 1.4), 0.013, fuller=gold)
        for side in (-1, 1):
            tube(m, gold, [(0, 0.085, 0), (side * 0.06, 0.08, 0), (side * 0.1, 0.11, 0), (side * 0.095, 0.15, 0)], [0.015, 0.012, 0.009, 0.004])
        gem(m, red, (0, 0.09, 0.02), (0.02, 0.026, 0.01))
        gem(m, red, (0, 0.09, -0.02), (0.02, 0.026, 0.01))
        grip(m, gold, crimson, gold, rings=4, pommel="crown")
    elif tier == 4:
        dark = mat("blade", "3a2a2a", 0.4, 0.35)
        fire = mat("edge", "ff7a2a", 0.0, 0.3, glow="ff7a2a", glow_amount=1.4)
        claw = mat("guard", "8a2a1a", 0.4, 0.45)
        black = mat("grip", "1a1214", 0.0, 0.8)
        red = mat("wrap", "c0301a", 0.3, 0.4)
        rings = blade(m, dark, y0, L, lambda t: 0.052 * (1 - t ** 1.3), 0.013, curve=0.07, edge=fire)
        # Serrations on the back edge.
        for i in range(4, 20, 3):
            p = rings[i][0]
            tube(m, dark, [p, p + np.array([-0.022, 0.018, 0])], [0.008, 0.001], sides=4)
        for side in (-1, 1):
            tube(m, claw, [(0, 0.085, 0), (side * 0.05, 0.09, 0), (side * 0.085, 0.12, 0.01), (side * 0.08, 0.16, 0.0)], [0.016, 0.013, 0.008, 0.002])
            tube(m, claw, [(side * 0.04, 0.085, 0), (side * 0.07, 0.06, 0), (side * 0.075, 0.035, 0)], [0.01, 0.007, 0.001])
        sphere(m, fire, (0, 0.088, 0), 0.016)
        grip(m, red, black, claw, rings=3, pommel="fang")
    elif tier == 5:
        ice = mat("blade", "bff2ff", 0.1, 0.1, glow="6fe0ff", glow_amount=0.25)
        crystal = mat("crystal", "e8fbff", 0.1, 0.1, glow="9feaff", glow_amount=0.3)
        white = mat("grip", "dcecff", 0.0, 0.6)
        blue = mat("wrap", "3a7ad0", 0.3, 0.35)
        blade(m, ice, y0, L, lambda t: 0.05 * (1 - t ** 1.2) + 0.008 * math.sin(t * 18) * (1 - t), 0.014)
        for side in (-1, 1):
            for k, (dx, h) in enumerate(((0.05, 0.07), (0.085, 0.05), (0.11, 0.03))):
                tube(m, crystal, [(side * dx, 0.085, 0), (side * (dx + 0.02), 0.085 + h, 0)], [0.012 - k * 0.002, 0.001], sides=5)
        straight_guard(m, crystal, 0.08)
        grip(m, blue, white, crystal, rings=3, pommel="gem")
    elif tier == 6:
        night = mat("blade", "2a1a40", 0.45, 0.3)
        glow = mat("edge", "b070ff", 0.0, 0.3, glow="b070ff", glow_amount=1.5)
        moon = mat("guard", "5a3a8a", 0.55, 0.35)
        black = mat("grip", "141020", 0.0, 0.8)
        violet = mat("gem", "c060ff", 0.1, 0.2, glow="c060ff", glow_amount=0.8)
        blade(m, night, y0, L, lambda t: 0.05 * (1 - t ** 1.4), 0.013, wave=0.016, waves=5, edge=glow)
        # A crescent-moon guard.
        crescent = [(-0.11, 0.13), (-0.08, 0.09), (-0.03, 0.075), (0.03, 0.075), (0.08, 0.09), (0.11, 0.13), (0.06, 0.1), (0.0, 0.092), (-0.06, 0.1)]
        ridge(m, moon, crescent, (0, 0, 0), 0.014)
        gem(m, violet, (0, 0.085, 0.02), (0.018, 0.024, 0.01))
        gem(m, violet, (0, 0.085, -0.02), (0.018, 0.024, 0.01))
        grip(m, moon, black, violet, rings=3, pommel="fang")
    elif tier == 7:
        holy = mat("blade", "fff6e0", 0.35, 0.25)
        gold = mat("edge", "ffd86a", 0.4, 0.3, glow="ffd86a", glow_amount=0.9)
        feather = mat("guard", "fff2d0", 0.2, 0.4)
        white = mat("grip", "f4ecdc", 0.0, 0.6)
        blade(m, holy, y0, L, lambda t: 0.052 * (1 - t ** 1.5), 0.013, edge=gold, fuller=gold)
        for side in (-1, 1):
            for k in range(4):
                angle = 0.25 + k * 0.32
                x = side * (0.03 + k * 0.026)
                ridge(m, feather, [(0, 0), (side * 0.03, 0.012), (side * 0.06, 0.004 + 0.012 * k), (side * 0.035, -0.008)], (x, 0.083 + k * 0.012, 0), 0.006)
        torus(m, gold, (0, -0.2, 0), (0, 0, 1), 0.04, 0.006)
        grip(m, gold, white, gold, rings=3, pommel="ball")
    elif tier == 8:
        storm = mat("blade", "2a3a8a", 0.45, 0.3)
        spark = mat("edge", "9fd8ff", 0.0, 0.3, glow="9fd8ff", glow_amount=1.6)
        bolt = mat("bolt", "ffe86a", 0.2, 0.3, glow="ffe86a", glow_amount=1.2)
        dark = mat("grip", "141a3a", 0.0, 0.7)
        blade(m, storm, y0, L, lambda t: 0.05 * (1 - t ** 1.3), 0.013, zig=0.03, edge=spark)
        for side in (-1, 1):
            tube(m, bolt, [(0, 0.085, 0), (side * 0.045, 0.1, 0), (side * 0.03, 0.12, 0), (side * 0.09, 0.15, 0)], [0.012, 0.01, 0.008, 0.002], sides=5)
            tube(m, bolt, [(side * 0.03, 0.085, 0), (side * 0.07, 0.065, 0), (side * 0.1, 0.07, 0)], [0.009, 0.006, 0.001], sides=5)
        sphere(m, spark, (0, 0.088, 0), 0.017)
        grip(m, bolt, dark, spark, rings=4, pommel="star")
    else:
        core = mat("blade", "7a4dff", 0.4, 0.25, glow="7a4dff", glow_amount=0.45)
        edge = mat("edge", "f6f0ff", 0.2, 0.2, glow="e8d8ff", glow_amount=1.6)
        gold = mat("gold", "ffd36b", 0.7, 0.25)
        crimson = mat("gem", "ff3a6e", 0.1, 0.2, glow="ff3a6e", glow_amount=1.0)
        black = mat("grip", "1a1230", 0.0, 0.7)
        blade(m, core, y0, L, lambda t: 0.056 * (1 - t ** 1.25) + 0.006 * math.sin(t * math.pi), 0.014, curve=0.03, edge=edge, fuller=gold)
        crescent = [(-0.13, 0.16), (-0.1, 0.1), (-0.04, 0.075), (0.04, 0.075), (0.1, 0.1), (0.13, 0.16), (0.07, 0.11), (0.0, 0.094), (-0.07, 0.11)]
        ridge(m, gold, crescent, (0, 0, 0), 0.016)
        torus(m, edge, (0, 0.2, 0), (0, 1, 0), 0.075, 0.006, seg=24)
        gem(m, crimson, (0, 0.09, 0.022), (0.022, 0.03, 0.012))
        gem(m, crimson, (0, 0.09, -0.022), (0.022, 0.03, 0.012))
        for k in range(3):
            gem(m, crimson, (0.0, 0.2, 0.0) + np.array([math.cos(k * 2.09) * 0.075, 0.0, math.sin(k * 2.09) * 0.075]), (0.008, 0.014, 0.008))
        grip(m, gold, black, crimson, rings=4, pommel="star")
    return m, mats


def divine_dagger():
    """The 200-star eclipse dagger: a black curved blade with a crimson edge, a
    black-sun guard ringed in crimson and violet, and shards floating round it."""
    m = Mesh()
    mats = {"blade": material("1a1426", 0.5, 0.25), "edge": material("ff3a6e", 0.0, 0.25, glow="ff3a6e", glow_amount=1.8),
            "violet": material("9a6bff", 0.2, 0.3, glow="9a6bff", glow_amount=1.2), "gold": material("e6c27a", 0.75, 0.25),
            "grip": material("120c1c", 0.0, 0.75), "sun": material("06040c", 0.2, 0.5)}
    blade(m, "blade", 0.12, 0.7, lambda t: 0.06 * (1 - t ** 1.2) + 0.008 * math.sin(t * math.pi * 2), 0.015, curve=0.06, edge="edge", fuller="violet")
    torus(m, "edge", (0, 0.1, 0), (0, 0, 1), 0.075, 0.009, seg=28)
    torus(m, "violet", (0, 0.1, 0), (0, 0, 1), 0.098, 0.004, seg=28)
    ridge(m, "sun", [(math.cos(a) * 0.07, math.sin(a) * 0.07) for a in np.linspace(0, 2 * math.pi, 16, endpoint=False)], (0, 0.1, 0), 0.012)
    for k in range(8):
        a = 2 * math.pi * k / 8 + math.pi / 8
        long = 0.05 if k % 2 == 0 else 0.03
        tube(m, "gold", [(math.cos(a) * 0.1, 0.1 + math.sin(a) * 0.1, 0), (math.cos(a) * (0.1 + long), 0.1 + math.sin(a) * (0.1 + long), 0)], [0.008, 0.001], sides=5)
    for k in range(4):
        y = 0.35 + k * 0.12
        x = 0.1 if k % 2 == 0 else -0.08
        gem(m, "violet", (x, y, 0.0), (0.01, 0.025, 0.008))
    grip(m, "gold", "grip", "edge", rings=4, pommel="gem", length=0.2)
    return m, mats


# ---------------------------------------------------------------------------
# GLB writing
# ---------------------------------------------------------------------------

class Writer:
    def __init__(self):
        self.bin = bytearray()
        self.views = []
        self.accs = []

    def add(self, arr, ctype, atype, target=None, minmax=False):
        arr = np.ascontiguousarray(arr)
        while len(self.bin) % 4:
            self.bin.append(0)
        off = len(self.bin)
        self.bin += arr.tobytes()
        view = {"buffer": 0, "byteOffset": off, "byteLength": arr.nbytes}
        if target:
            view["target"] = target
        self.views.append(view)
        acc = {"bufferView": len(self.views) - 1, "componentType": ctype, "count": len(arr), "type": atype}
        if minmax:
            acc["min"] = [float(v) for v in arr.min(0)]
            acc["max"] = [float(v) for v in arr.max(0)]
        self.accs.append(acc)
        return len(self.accs) - 1


def weld(part, skinned):
    """Merge identical vertices (position, normal and weights) and index them."""
    p = np.asarray(part["p"], np.float32)
    n = np.asarray(part["n"], np.float32)
    cols = [np.round(p * 1e5), np.round(n * 1e3)]
    if skinned:
        w = np.asarray([x for x in part["w"]], np.float32)
        cols.append(np.round(w * 1e3))
    has_uv = any(x is not None for x in part["uv"])
    if has_uv:
        uv = np.asarray([x if x is not None else (0.0, 0.0) for x in part["uv"]], np.float32)
        cols.append(np.round(uv * 1e4))
    key = np.concatenate(cols, axis=1)
    _, first, inverse = np.unique(key, axis=0, return_index=True, return_inverse=True)
    out = {"p": p[first], "n": n[first], "i": inverse.reshape(-1).astype(np.uint32)}
    if skinned:
        out["w"] = np.asarray(part["w"], np.float32)[first]
    if has_uv:
        out["uv"] = uv[first]
    return out


def glb(doc, w, path):
    doc["accessors"] = w.accs
    doc["bufferViews"] = w.views
    while len(w.bin) % 4:
        w.bin.append(0)
    doc["buffers"] = [{"byteLength": len(w.bin)}]
    js = json.dumps(doc, separators=(",", ":")).encode()
    while len(js) % 4:
        js += b" "
    data = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(w.bin)) + struct.pack("<II", len(js), 0x4E4F534A) + js + struct.pack("<II", len(w.bin), 0x004E4942) + bytes(w.bin)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(data)
    return len(data)


def primitives(mesh, mats, w, joints=None):
    prims, materials = [], []
    tris = 0
    for key, part in mesh.parts.items():
        if not part["p"]:
            continue
        v = weld(part, joints is not None)
        attrs = {"POSITION": w.add(v["p"], 5126, "VEC3", 34962, True), "NORMAL": w.add(v["n"], 5126, "VEC3", 34962)}
        if "uv" in v:
            attrs["TEXCOORD_0"] = w.add(v["uv"], 5126, "VEC2", 34962)
        if joints is not None:
            weights = v["w"]
            order = np.argsort(-weights, axis=1)[:, :4]
            jo = np.take_along_axis(np.tile(np.arange(weights.shape[1]), (len(weights), 1)), order, axis=1)
            we = np.take_along_axis(weights, order, axis=1)
            we = we / np.maximum(we.sum(1, keepdims=True), 1e-9)
            attrs["JOINTS_0"] = w.add(jo.astype(np.uint16), 5123, "VEC4", 34962)
            attrs["WEIGHTS_0"] = w.add(we.astype(np.float32), 5126, "VEC4", 34962)
        big = len(v["p"]) > 65535
        idx = w.add(v["i"].astype(np.uint32 if big else np.uint16), 5125 if big else 5123, "SCALAR", 34963)
        # Named, so a runtime dresser can find the parts it re-shades (ShadowWingArt).
        materials.append(dict(mats[key], name=key))
        prims.append({"attributes": attrs, "indices": idx, "material": len(materials) - 1})
        tris += len(v["i"]) // 3
    return prims, materials, tris


def write_static(path, mesh, mats, name):
    w = Writer()
    prims, materials, tris = primitives(mesh, mats, w)
    doc = {"asset": {"version": "2.0", "generator": "Toon Tale make_assassin_gear.py"}, "scene": 0,
           "scenes": [{"nodes": [0]}], "nodes": [{"name": name, "mesh": 0}],
           "meshes": [{"name": name, "primitives": prims}], "materials": materials}
    return glb(doc, w, path), tris


class Source:
    """The armature, skin and clips of an existing class wing GLB."""

    def __init__(self, path):
        raw = open(path, "rb").read()
        jl = struct.unpack_from("<I", raw, 12)[0]
        self.g = json.loads(raw[20:20 + jl])
        bl = struct.unpack_from("<I", raw, 20 + jl)[0]
        self.bin = raw[28 + jl:28 + jl + bl]

    def acc(self, i):
        a = self.g["accessors"][i]
        v = self.g["bufferViews"][a["bufferView"]]
        n = {"SCALAR": 1, "VEC3": 3, "VEC4": 4, "MAT4": 16}[a["type"]]
        assert a["componentType"] == 5126
        off = v.get("byteOffset", 0) + a.get("byteOffset", 0)
        arr = np.frombuffer(self.bin, np.float32, a["count"] * n, off)
        return arr.reshape(a["count"], n) if n > 1 else arr

    def joint_positions(self):
        """Rest world position of every node (the wing rig has no rest rotation to speak of)."""
        nodes = self.g["nodes"]
        parent = {c: i for i, n in enumerate(nodes) for c in n.get("children", [])}
        def world(i):
            t = np.array(nodes[i].get("translation", [0, 0, 0]), float)
            s = np.array(nodes[i].get("scale", [1, 1, 1]), float)
            return (world(parent[i]) if i in parent else 0) + t * s
        return {n.get("name"): world(i) for i, n in enumerate(nodes)}


def write_skinned(path, source, mesh, mats):
    src = Source(source)
    g = src.g
    w = Writer()
    skin = g["skins"][0]
    joint_count = len(skin["joints"])
    prims, materials, tris = primitives(mesh, mats, w, joints=joint_count)
    nodes = [dict(n) for n in g["nodes"]]
    ibm = w.add(src.acc(skin["inverseBindMatrices"]).astype(np.float32), 5126, "MAT4")
    anims = []
    for a in g.get("animations", []):
        samplers, channels = [], []
        for ch in a["channels"]:
            smp = a["samplers"][ch["sampler"]]
            inp = src.acc(smp["input"]).astype(np.float32).reshape(-1)
            ii = w.add(inp, 5126, "SCALAR")
            w.accs[ii]["min"] = [float(inp.min())]
            w.accs[ii]["max"] = [float(inp.max())]
            oi = w.add(src.acc(smp["output"]).astype(np.float32), 5126, g["accessors"][smp["output"]]["type"])
            samplers.append({"input": ii, "output": oi, "interpolation": smp.get("interpolation", "LINEAR")})
            channels.append({"sampler": len(samplers) - 1, "target": ch["target"]})
        anims.append({"name": a["name"], "samplers": samplers, "channels": channels})
    doc = {"asset": {"version": "2.0", "generator": "Toon Tale make_assassin_gear.py"}, "scene": 0,
           "scenes": g["scenes"], "nodes": nodes, "skins": [{"joints": skin["joints"], "inverseBindMatrices": ibm}],
           "meshes": [{"name": "Body", "primitives": prims}], "materials": materials, "animations": anims}
    return glb(doc, w, path), tris


# ---------------------------------------------------------------------------
# Shadow wings
# ---------------------------------------------------------------------------

def wing_weights(joint_index, positions, side_names):
    """Blend shoulder -> elbow -> wrist along the arm; everything past the wrist rides the wrist."""
    s = positions[side_names[0]]
    wr = positions[side_names[2]]
    axis = wr - s
    count = len(joint_index)
    def weights(v):
        t = float(np.dot(np.asarray(v) - s, axis) / np.dot(axis, axis))
        row = np.zeros(count, np.float32)
        a, b, c = (joint_index[n] for n in side_names)
        if t < 0.5:
            k = max(t, 0.0) * 2.0
            row[a], row[b] = 1.0 - k, k
        elif t < 1.0:
            k = (t - 0.5) * 2.0
            row[b], row[c] = 1.0 - k, k
        else:
            row[c] = 1.0
        return row
    return weights


def fixed_weight(joint_index, name):
    count = len(joint_index)
    def weights(_v):
        row = np.zeros(count, np.float32)
        row[joint_index[name]] = 1.0
        return row
    return weights


# Layers, back to front as a camera behind the hero sees one side:
#   phantom (star)  a huge ghostly double of the main wing, drawn additively
#   under           a smaller second wing hanging below the main one
#   main            five (star: six) fingers of torn membrane on clawed bones
#   blades          a fan of kunai "feathers" lying over the membrane
#   wisps           shadow tendrils trailing from the lower edges
# Membranes, phantom, wisps and the halo's flames carry UVs (x: wrist -> trailing
# edge or root -> tip, y: across) for ShadowWingArt's animated shaders; every
# other part keeps its plain glTF material.

def bezier(a, k, b, t):
    return a * (1 - t) ** 2 + k * 2 * t * (1 - t) + b * t * t


def finger(wr, tip, sx, arch=0.07):
    """A bat finger from the wrist to its tip, bowed towards the wing's leading edge."""
    d = tip - wr
    lead = np.array([-d[1], d[0], 0.0]) * sx
    knuckle = wr + d * 0.5 + lead * arch
    return lambda t: bezier(wr, knuckle, tip, t)


def sheet(m, key, grid, uvs, weights):
    """Smooth-shaded triangles over a grid of points (rows x cols), one UV per point."""
    P = np.asarray(grid, float)
    rows, cols = P.shape[0], P.shape[1]
    N = np.zeros_like(P)
    for i in range(rows):
        for j in range(cols):
            du = P[min(i + 1, rows - 1), j] - P[max(i - 1, 0), j]
            dv = P[i, min(j + 1, cols - 1)] - P[i, max(j - 1, 0)]
            n = np.cross(du, dv)
            N[i, j] = n / max(np.linalg.norm(n), 1e-9)
    for i in range(rows):
        for j in range(cols):
            if np.linalg.norm(N[i, j]) < 0.5:
                N[i, j] = N[min(i + 1, rows - 1), j]
    for i in range(rows - 1):
        for j in range(cols - 1):
            for tri in (((i, j), (i + 1, j), (i + 1, j + 1)), ((i, j), (i + 1, j + 1), (i, j + 1))):
                pts = [P[a] for a in tri]
                if np.linalg.norm(np.cross(pts[1] - pts[0], pts[2] - pts[0])) < 1e-10:
                    continue
                m.smooth_tri(key, pts, [N[a] for a in tri], weights, [uvs[a[0]][a[1]] for a in tri])


def membrane(m, key, wr, fa, fb, weights, rows=6, cols=8, scallop=0.18, tears=(), billow=0.035, z=0.0):
    """A wing panel fanning from the wrist between two finger curves, its trailing edge
    scalloped and torn (tears: (across 0..1, depth, half width) notches). Returns the
    trailing edge, where the hem runs."""
    grid, uvs = [], []
    for i in range(rows + 1):
        u = i / rows
        row, uvrow = [], []
        for j in range(cols + 1):
            v = j / cols
            torn = sum(d * max(0.0, 1.0 - abs(v - c) / w) for c, d, w in tears)
            pull = 1.0 - (scallop * math.sin(math.pi * v) + torn) * u ** 2.2
            p = wr + (fa(u) * (1 - v) + fb(u) * v - wr) * pull
            p = p + np.array([0.0, 0.0, z * u - billow * math.sin(math.pi * v) * math.sin(math.pi * u * 0.9)])
            row.append(p)
            uvrow.append((u, v))
        grid.append(row)
        uvs.append(uvrow)
    sheet(m, key, grid, uvs, weights)
    return grid[rows]


def ribbon(m, key, start, length, sx, weights, width=0.035, sway=0.05, phase=0.0, segs=8):
    """A shadow tendril hanging from start: a camera-facing ribbon that narrows to a
    point and curls; UV x runs root -> tip."""
    grid, uvs = [], []
    for k in range(segs + 1):
        s = k / segs
        c = start + np.array([sx * (0.04 * s + sway * math.sin(s * math.pi * 1.4 + phase) * s), -length * s, -0.03 * s])
        w = width * (1.0 - s) ** 0.7 + 0.0015
        grid.append([c - np.array([w * 0.5, 0, 0]), c + np.array([w * 0.5, 0, 0])])
        uvs.append([(s, 0.0), (s, 1.0)])
    sheet(m, key, grid, uvs, weights)


def kunai(m, base, d, across, length, width, weights, body="blade", edge="edge", guard=None):
    """A flat throwing-knife feather: a double faceted blade with glowing cutting edges."""
    d = d / np.linalg.norm(d)
    across = across - d * np.dot(across, d)
    across = across / np.linalg.norm(across)
    n = np.cross(d, across)
    pts = [base - across * width * 0.28, base + d * length * 0.3 - across * width, base + d * length,
           base + d * length * 0.3 + across * width, base + across * width * 0.28]
    for face in (1.0, -1.0):
        peak = base + d * length * 0.34 + n * width * 0.35 * face
        for i in range(len(pts)):
            a, b = pts[i], pts[(i + 1) % len(pts)]
            if np.dot(np.cross(b - a, peak - a), n * face) < 0:
                a, b = b, a
            m.tri(body, a, b, peak, weights)
    tube(m, edge, [pts[1], pts[2], pts[3]], [0.0038, 0.0016, 0.0038], sides=3, caps=False, weights=weights)
    if guard:
        tube(m, guard, [base - across * width * 0.95, base + across * width * 0.95], [0.0045, 0.0045], sides=4, weights=weights)


def crescent(m, key, centre, right, up, radius, thick, weights, alpha=1.9, segs=10):
    """A flat crescent moon (horns along +-up, belly towards +right), bevelled on both faces."""
    right, up = np.asarray(right, float), np.asarray(up, float)
    n = np.cross(right, up)
    outer, inner, ridge_pts = [], [], []
    for k in range(segs + 1):
        th = -alpha / 2 + alpha * k / segs
        t = thick * math.cos(th / alpha * math.pi)
        d = right * math.cos(th) + up * math.sin(th)
        outer.append(centre + d * radius)
        inner.append(centre + d * (radius - t))
        ridge_pts.append(t)
    for face in (1.0, -1.0):
        for k in range(segs):
            r0 = (outer[k] + inner[k]) * 0.5 + n * ridge_pts[k] * 0.4 * face
            r1 = (outer[k + 1] + inner[k + 1]) * 0.5 + n * ridge_pts[k + 1] * 0.4 * face
            for a, b, c in ((outer[k], outer[k + 1], r1), (outer[k], r1, r0), (inner[k], r0, r1), (inner[k], r1, inner[k + 1])):
                if np.dot(np.cross(b - a, c - a), n * face) < 0:
                    b, c = c, b
                m.tri(key, a, b, c, weights)


def bat_wing(m, side, pos, jidx, star):
    sx = 1.0 if side == "L" else -1.0
    names = ["Wing_%s_1" % side, "Wing_%s_2" % side, "Wing_%s_3" % side]
    weights = wing_weights(jidx, pos, names)
    sh, el = pos[names[0]], pos[names[1]]
    X = lambda x, y, z: np.array([x * sx, y, z])
    wr = pos[names[2]] + X(0.05, 0.05, -0.03)
    grow = 1.24 if star else 1.0
    tips = [X(0.30, 1.24, -0.36), X(0.52, 1.13, -0.43), X(0.68, 0.93, -0.47), X(0.71, 0.67, -0.47), X(0.56, 0.44, -0.42)]
    if star:
        tips.insert(1, X(0.42, 1.21, -0.40))
    tips = [wr + (t - wr) * grow for t in tips]
    fingers = [finger(wr, t, sx) for t in tips]
    base = X(0.08, 0.40, -0.12)
    to_base = lambda t: wr + (base - wr) * t
    # Phantom: the same wing, larger and torn deeper, a ghost of night behind the real one.
    if star:
        ghost = [finger(wr, wr + (t - wr) * 1.32 + np.array([0, 0, 0.05]), sx, 0.09) for t in tips]
        for k, (fa, fb) in enumerate(zip(ghost[:-1], ghost[1:])):
            membrane(m, "phantom", wr, fa, fb, weights, rows=4, cols=6, scallop=0.24,
                     tears=((0.5, 0.16, 0.2),) if k % 2 == 0 else ((0.3, 0.1, 0.14), (0.72, 0.14, 0.16)), billow=0.02, z=0.04)
    # Main wing: panels between consecutive fingers, then from the last finger back to the body.
    hems = []
    tear_sets = [((0.42, 0.10, 0.12),), ((0.62, 0.14, 0.14),), ((0.3, 0.08, 0.1), (0.7, 0.12, 0.12)), ((0.5, 0.1, 0.16),), ((0.38, 0.12, 0.12),)]
    for k, (fa, fb) in enumerate(zip(fingers[:-1], fingers[1:])):
        hems.append(membrane(m, "membrane", wr, fa, fb, weights, tears=tear_sets[k % len(tear_sets)]))
    hems.append(membrane(m, "membrane", wr, fingers[-1], to_base, weights, scallop=0.32, tears=((0.3, 0.1, 0.12), (0.62, 0.08, 0.1)), billow=0.02))
    for edge in hems:
        tube(m, "corona" if star else "hem", edge, [0.0038] * len(edge), sides=3, caps=False, weights=weights)
    # Under wing: three shorter fingers hanging from the elbow below the main wing.
    ug = 1.18 if star else 1.0
    anchor = el + X(0.03, -0.07, -0.05)
    under_tips = [anchor + (t - anchor) * ug for t in (X(0.46, 0.38, -0.36), X(0.50, 0.17, -0.35), X(0.32, 0.04, -0.29))]
    under = [finger(anchor, t, sx, 0.05) for t in under_tips]
    under_base = X(0.07, 0.27, -0.11)
    under_edges = [membrane(m, "under", anchor, fa, fb, weights, rows=5, cols=7, scallop=0.2, tears=((0.5, 0.12, 0.16),))
                   for fa, fb in zip(under[:-1], under[1:])]
    under_edges.append(membrane(m, "under", anchor, under[-1], lambda t: anchor + (under_base - anchor) * t, weights, rows=5, cols=6, scallop=0.3))
    for edge in under_edges:
        tube(m, "hem", edge, [0.0032] * len(edge), sides=3, caps=False, weights=weights)
    for f in under:
        tube(m, "strut", [f(t) for t in (0.0, 0.35, 0.7, 1.0)], [0.01, 0.008, 0.005, 0.0015], sides=5, weights=weights)
    # Bones: arm, fingers with knuckles, hooked claws at the tips.
    tube(m, "strut", [sh, el, wr], [0.02, 0.017, 0.015], sides=7, weights=weights)
    for f, t in zip(fingers, tips):
        tube(m, "strut", [f(s) for s in (0.0, 0.3, 0.55, 0.8, 1.0)], [0.013, 0.011, 0.009, 0.006, 0.002], sides=5, weights=weights)
        sphere(m, "gold" if star else "strut", f(0.55), 0.013, rings=3, seg=6, weights=weights)
        d = (t - f(0.92)) / np.linalg.norm(t - f(0.92))
        hook = np.array([d[1], -d[0], 0.0]) * sx
        tube(m, "claw", [t, t + d * 0.03 + hook * 0.006, t + d * 0.05 + hook * 0.022], [0.006, 0.004, 0.0005], sides=4, caps=False, weights=weights)
    # Spikes along the top of the arm and a crescent blade crowning the wrist.
    for k, s in enumerate((0.25, 0.55, 0.85)):
        p = sh + (wr - sh) * s
        tube(m, "claw" if star else "strut", [p, p + X(-0.03, 0.05 + 0.012 * k, -0.025)], [0.009, 0.0008], sides=4, weights=weights)
    # The crescent cups the wrist, belly down, horns raised.
    radius = 0.07 if star else 0.055
    belly = X(-0.33, -0.94, 0.0)
    crescent(m, "blade", wr - belly * (radius + 0.008) + np.array([0, 0, -0.03]), belly, np.cross([0.0, 0.0, 1.0], belly), radius,
             0.028 if star else 0.022, weights)
    gem(m, "glow", wr + np.array([0, 0, -0.018]), (0.013, 0.02, 0.01), weights=weights)
    # The kunai fan: blades over the inner membrane, one (star: two) per panel.
    for k, (fa, fb) in enumerate(zip(fingers[:-1], fingers[1:])):
        mid = (fa(1.0) + fb(1.0)) * 0.5
        d = mid - wr
        across = np.cross(d, np.array([0.0, 0.0, 1.0]))
        lift = np.array([0.0, 0.0, -0.022])
        kunai(m, wr + d * 0.16 + lift, d, across, np.linalg.norm(d) * (0.46 if k % 2 == 0 else 0.38), 0.026, weights,
              guard="gold" if star else None)
        if star:
            side_dir = (fa(1.0) * 0.7 + fb(1.0) * 0.3) - wr
            kunai(m, wr + side_dir * 0.2 + lift * 1.3, side_dir, np.cross(side_dir, np.array([0.0, 0.0, 1.0])),
                  np.linalg.norm(side_dir) * 0.28, 0.02, weights)
    # Shadow tendrils from the lowest edges.
    low = hems[-2]
    for k, (edge, at) in enumerate(((low, 0.35), (low, 0.75), (hems[-1], 0.3))):
        p = edge[int(round(at * (len(edge) - 1)))]
        ribbon(m, "wisp", p, (0.36 if star else 0.28) * (1.0 - 0.18 * k), sx, weights, width=0.04 if star else 0.034, phase=k * 1.7)
    p = under_tips[1]
    ribbon(m, "wisp", p, 0.3 if star else 0.22, sx, weights, width=0.03, phase=0.9)
    # Mount at the shoulder blade.
    sphere(m, "strut", sh + np.array([0, 0, -0.01]), 0.03, rings=4, seg=8, weights=weights)
    gem(m, "claw", sh + np.array([0, 0, -0.036]), (0.008, 0.012, 0.006), weights=weights)


# Where the eclipse halo hangs: centred on the head, just behind it (chibi model space).
HALO_CENTRE = (0.0, 0.84, -0.30)


def eclipse_halo(m, centre, weights):
    """The star wings' halo, a black sun framing the head: a thin eclipse ring rimmed
    in crimson, a corona of flames (ShadowWingArt spins them about HALO_CENTRE), an
    outer gold ring set with crescent moons, and four long gold rays. Open in the
    middle, so the head always shows."""
    c = np.asarray(centre, float)
    torus(m, "strut", c, (0, 0, 1), 0.25, 0.009, seg=32, sides=4, weights=weights)
    torus(m, "corona", c, (0, 0, 1), 0.236, 0.004, seg=32, sides=3, weights=weights)
    torus(m, "gold", c, (0, 0, 1), 0.40, 0.0042, seg=36, sides=3, weights=weights)
    rng = np.random.default_rng(11)
    flames = 24
    for k in range(flames):
        a0 = 2 * math.pi * k / flames
        length = (0.13 if k % 2 == 0 else 0.075) * (0.8 + 0.4 * rng.random())
        grid, uvs = [], []
        for s_i in range(4):
            s = s_i / 3
            a = a0 + 0.24 * s * s
            r = 0.255 + length * s
            w = 0.038 * (1.0 - s) ** 0.8 + 0.001
            d = np.array([math.cos(a), math.sin(a), 0.0])
            t = np.array([-math.sin(a), math.cos(a), 0.0])
            grid.append([c + d * r - t * w * 0.5, c + d * r + t * w * 0.5])
            uvs.append([(s, 0.0), (s, 1.0)])
        sheet(m, "flare", grid, uvs, weights)
    for k in range(6):
        a = 2 * math.pi * k / 6 + math.pi / 2
        d = np.array([math.cos(a), math.sin(a), 0.0])
        t = np.array([-math.sin(a), math.cos(a), 0.0])
        crescent(m, "glow", c + d * 0.40 + np.array([0, 0, -0.004]), d, t, 0.034, 0.014, weights, segs=8)
    for k in range(4):
        a = 2 * math.pi * k / 4 + math.pi / 4
        d = np.array([math.cos(a), math.sin(a), 0.0])
        tube(m, "gold", [c + d * 0.41, c + d * 0.47, c + d * 0.56], [0.006, 0.004, 0.0006], sides=4, weights=weights)


def wings(source, star):
    src = Source(source)
    pos = src.joint_positions()
    joints = src.g["skins"][0]["joints"]
    jidx = {src.g["nodes"][j]["name"]: k for k, j in enumerate(joints)}
    m = Mesh()
    for side in ("L", "R"):
        bat_wing(m, side, pos, jidx, star)
    # Fallback looks; ShadowWingArt swaps membrane/under/wisp/phantom/flare for animated shaders.
    mats = {
        "membrane": material("4a2c86" if not star else "5a2f8e", 0.0, 0.55, glow="6a3ac0", glow_amount=0.25, alpha=0.9, double=True),
        "under": material("3a1f66", 0.0, 0.55, glow="4a2a80", glow_amount=0.2, alpha=0.9, double=True),
        "wisp": material("5a2f8e", 0.0, 0.5, glow="9a6bff", glow_amount=0.5, alpha=0.55, double=True),
        "phantom": material("7a4ad8", 0.0, 0.5, glow="9a6bff", glow_amount=0.6, alpha=0.3, double=True),
        "flare": material("ff3a6e", 0.0, 0.3, glow="ff3a6e", glow_amount=1.5, alpha=0.75, double=True),
        "strut": material("1e1630" if not star else "241a3c", 0.45, 0.35),
        "claw": material("ff4f7b", 0.2, 0.3, glow="ff4f7b", glow_amount=0.8),
        "glow": material("e4d6ff", 0.0, 0.3, glow="c9a7ff", glow_amount=1.4),
        "hem": material("b58cff", 0.0, 0.3, glow="9a6bff", glow_amount=1.4),
        "blade": material("8a7fb8", 0.35, 0.3, glow="5a4a96", glow_amount=0.55),
        "edge": material("efe4ff" if not star else "ffb3cb", 0.0, 0.3, glow="c9a7ff" if not star else "ff5c8a", glow_amount=1.8),
        "gold": material("ffd36b", 0.75, 0.25, glow="ffb84a", glow_amount=0.35),
        "corona": material("ff3a6e", 0.0, 0.3, glow="ff3a6e", glow_amount=1.6),
    }
    if star:
        eclipse_halo(m, HALO_CENTRE, fixed_weight(jidx, "WingsRoot"))
    return m, mats


def main():
    report = []
    if not WINGS_ONLY:
        for tier in range(10):
            m, mats = dagger(tier)
            size, tris = write_static(os.path.join(OUT, "weapons", "dagger_%d.glb" % tier), m, mats, "dagger_%d" % tier)
            report.append(("weapons/dagger_%d.glb" % tier, tris, size))
        m, mats = divine_dagger()
        size, tris = write_static(os.path.join(OUT, "divine_gear", "assassin_dagger.glb"), m, mats, "assassin_dagger")
        report.append(("divine_gear/assassin_dagger.glb", tris, size))
    for folder, star in (("wings", False), ("star_wings", True)):
        source = os.path.join(OUT, folder, "wings_mage.glb")
        m, mats = wings(source, star)
        size, tris = write_skinned(os.path.join(OUT, folder, "wings_assassin.glb"), source, m, mats)
        report.append(("%s/wings_assassin.glb" % folder, tris, size))
    for name, tris, size in report:
        print("%-36s %6d tris %5d KB" % (name, tris, size // 1024))


if __name__ == "__main__":
    main()
