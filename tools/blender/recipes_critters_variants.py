"""Team critters' per-monster VARIANTS of shared rigs (see recipes_critters.py).

    /opt/bpy5/bin/python tools/blender/recipes_critters_variants.py [big/Fish_abyss_angler ...]

Several monsters used one remastered model and differed by a colour tint only. The first
monster of each group keeps the shared model (recipes_critters.RECIPES); every other one
gets its own recipe here, built from the same rig (every clip kept) and written to
remaster/<dir>/<Name>_<monster_id>.glb; that monster's "model" points at
"remaster/<dir>/<Name>_<monster_id>". They differ by shape and features, not only paint,
and are painted in final colours on the untinted ("Keep") materials, so the data's
"tint" does not change them.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import remaster_lib as L  # noqa: E402
import kit_critters as K  # noqa: E402
import remaster_monsters as M  # noqa: E402
import recipes_critters as R  # noqa: E402
from mathutils import Vector  # noqa: E402

V = Vector
C = L.srgb
D = R.D
WHITE = C("ffffff")
start, finish = R.start, R.finish


def all_keep(*_a):
    return "keep"


def glow_spot(parts, p, n, r, c0, c1, weights=None):
    """A small raised glowing photophore / gem."""
    with parts.use("glow"):
        parts.ellipsoid(p + n * 0.004, (r, r, r * 0.55), M.basis(n), color=None, weights=weights or p, seg=8, rings=5,
                        color_fn=lambda u: L.mix(c0, c1, L.smooth(-0.2, 1.0, u.z)))


# ================================================================ big/Fish  abyss_angler

def abyss_angler(arm, body):
    """Deep-sea angler (abyss_angler): an inky navy hide with rows of glowing photophores,
    a huge underslung jaw bristling with needle fangs, small milky glowing eyes, ragged
    dark fins rimmed in cyan, and the glowing lure on a stalk curling over its face."""
    R.drop_islands(body, lambda c, size, mat: (mat == "Eye_White" and c.z > 2.3) or mat == "Eye_Black")
    L.clean(body)
    L.decimate_to(body, 3900)
    L.relax(body, 2, 0.3, ("Fish_Main",))
    # A big jutting jaw: the face below the eyes widened and pushed forward, the chin dropped.
    K.scale_region(body, lambda c: 1.55 < c.z < 2.35 and c.y < -0.1, V((0, -0.2, 2.02)), (1.22, 1.3, 1.18),
                   lambda c: L.smooth(-0.1, -0.45, c.y) * L.smooth(1.55, 1.8, c.z) * L.smooth(2.35, 2.15, c.z))
    K.move_region(body, lambda c: 1.55 < c.z < 2.02 and c.y < -0.3,
                  lambda c: V((0, -0.1, -0.07)) * L.smooth(-0.3, -0.7, c.y) * L.smooth(1.55, 1.8, c.z))
    body.data.update()
    mouth = K.mat_islands(body, "Mouth")
    mc, mr = mouth[0] if mouth else (V((0, -0.8, 2.0)), 0.4)
    back, side, belly = D("141c38"), D("2c4468"), D("7a7c9c")
    cyan, cyan_hi = D("39e6ff"), D("d8fffa")

    def paint(name, co, n, info):
        if name == "Eye_White":
            return D("dff0ea")  # needle teeth
        if name == "Mouth":
            return D("12060e")
        if name == "Fish_Flaps":
            return L.mix(D("1a2240"), D("3ab0c8"), L.smooth(0.0, 0.07, info["bump"]))
        if name == "Fish_Secondary" and co.y > 0.2:
            return L.mix(D("101630"), D("2a8aa0"), L.smooth(0.0, 0.08, info["bump"]))  # dorsal fins
        if name == "Fish_Secondary":
            return L.mix(belly, D("9a9ab8"), L.smooth(1.0, 2.0, co.z))
        c = L.mix(side, back, L.smooth(-0.3, 0.6, n.y * 0.7 + n.z * 0.3))
        sc = 0.5 + 0.5 * math.sin(co.z * 11.0 + abs(co.x) * 5.0) * math.sin(co.y * 10.0 + co.x * 3.0)
        c = L.mix(c, D("0a0e20"), L.smooth(0.8, 0.97, sc) * 0.4)
        return L.mix(c, belly, max(0.0, -n.y) * L.smooth(2.2, 1.2, co.z) * 0.45)

    K.paint_body(body, paint, all_keep)
    surf, parts = start(body)
    parts.mode = "keep"
    for sx in (-1.0, 1.0):
        K.fierce_eye(parts, V((0.3 * sx, -0.42, 2.47)), 0.13, V((0.45 * sx, -1.0, 0.1)).normalized(), D("f4fff8"),
                     D("6ae8d8"), {"Head": 1.0}, lid=D("1a2444"), slant=0.3, side=sx, slit=False, iris=0.95,
                     glow=True, sclera=D("0a1020"), lid_drop=1.6)
    # Needle fangs round the lower jaw, pointing up and out.
    w = {"Head": 1.0}
    for k in range(9):
        a = math.pi * (0.12 + 0.76 * k / 8.0)
        x = math.cos(a) * mr * 1.1
        p, n = surf.toward(V((x, -4.0, mc.z - 0.02)), V((x * 0.6, mc.y, mc.z - 0.02)))
        if p is None:
            continue
        ln = 0.2 + 0.08 * math.sin(a) ** 4
        K.fang(parts, p - n * 0.02, (n * 0.35 + V((0, 0, 1))).normalized(), ln, 0.035, w, color=D("eef8f4"))
    # Lure: a stalk rising from the brow and curling forward over the face, a glowing bulb.
    root, rn = M.dir_hit(surf, V((0, -0.1, 3.0)), V((0, -0.45, 1)))
    if root is not None:
        axis = V((0, -0.35, 1)).normalized()
        ln = 0.95
        bend = V((0, -0.85, -0.25))
        parts.blob(root - rn * 0.03, (0.06, 0.05), axis, ln, None, weights=w, seg=8, rings=9, tip=0.55, bend=bend,
                   color_fn=lambda t: L.mix(D("1a2444"), D("3a5a7a"), t))
        tip = root + axis * ln + bend
        with parts.use("glow"):
            parts.ellipsoid(tip + V((0, 0, -0.1)), (0.17, 0.17, 0.2), color=None, weights=w, seg=14, rings=9,
                            color_fn=lambda u: L.mix(C("12d8ff"), C("eaffa0"), L.smooth(-0.4, 0.9, -u.y * 0.6 + u.z * 0.4)))
        parts.ellipsoid(tip + V((0, 0.02, 0.05)), (0.09, 0.09, 0.07), color=D("1a2444"), weights=w, seg=10, rings=5)
        with parts.use("glow"):
            for k in range(3):
                a = math.pi * (0.25 + 0.25 * k)
                d = V((math.cos(a) * 0.6, -0.2, -1.0)).normalized()
                parts.blob(tip + V((0, 0, -0.26)), 0.025, d, 0.16, cyan_hi, weights=w, seg=6, rings=4, tip=0.4)
    # Ragged dark spines along the dorsal ridge (instead of the ice fish's crystals).
    for k, (y, z, ln) in enumerate(((0.4, 3.25, 0.34), (0.7, 2.85, 0.42), (0.85, 2.4, 0.38), (0.9, 1.95, 0.32))):
        p, n = M.dir_hit(surf, V((0, 0.0, z - 0.2)), V((0, y + 0.3, 0.8)))
        if p is None:
            continue
        d = (n + V((0, 0.4, 0.2))).normalized()
        parts.blob(p - n * 0.05, (0.06, 0.035), d, ln, None, weights=p, seg=6, rings=4, tip=0.05,
                   color_fn=lambda t: L.mix(D("101630"), D("2a7a90"), t))
    # Photophores: a row along each flank, a few on the arms, two on the cheeks.
    for sx in (-1.0, 1.0):
        for k in range(6):
            z = 0.75 + 0.22 * k
            p, n = M.dir_hit(surf, V((0, 0.1, z)), V((sx, -0.45, 0.0)))
            if p is not None:
                glow_spot(parts, p, n, 0.045 if k % 2 else 0.035, cyan, cyan_hi)
        for k in range(4):
            x = 0.6 + 0.3 * k
            p, n = M.dir_hit(surf, V((x * sx, 0.17, 1.82)), V((0, -0.4, 1.0)))
            if p is not None:
                glow_spot(parts, p, n, 0.035, cyan, cyan_hi)
        p, n = M.front_hit(surf, 0.5 * sx, 2.25)
        if p is not None:
            glow_spot(parts, p, n, 0.04, cyan, cyan_hi)
    finish(body, parts)


# ================================================================ big/Frog  lotus_frog

def lotus_petal_col(along):
    return L.mix(C("fff4f6"), C("ff5a9a"), L.smooth(0.25, 1.0, along))


def lotus(parts, center, normal, size, weights, outer=8, inner=5, turn=0.0):
    """A lotus bloom facing along normal: a ring of open petals, an upright inner ring, a
    golden seed pod."""
    t_, b_, n_ = L.frame(normal)
    for ring, (count, lift, sz) in enumerate(((outer, 0.35, 1.0), (inner, 1.4, 0.8))):
        for i in range(count):
            a = turn + 2.0 * math.pi * (i + 0.5 * ring) / count
            d = (t_ * math.cos(a) + b_ * math.sin(a) + n_ * lift).normalized()
            parts.blob(center, (size * 0.36, size * 0.14), d, size * sz, None, weights=weights, seg=8, rings=5,
                       tip=0.35, color_fn=lotus_petal_col, up=n_, bend=n_ * size * 0.25)
    parts.ellipsoid(center + n_ * size * 0.18, (size * 0.3, size * 0.3, size * 0.16), M.basis(n_), color=None,
                    weights=weights, seg=12, rings=6,
                    color_fn=lambda u: L.mix(C("d89a1a"), C("ffe680"), L.smooth(-0.2, 0.9, u.z)))


def lotus_frog(arm, body):
    """Divine golden lotus frog (lotus_frog): gleaming gold skin with pearl belly and pink
    petal markings, a lotus bloom crowning its head, a collar of lotus petals, a lily pad
    worn on its back like a shawl, serene half-lidded jade eyes and a glowing jewel brow."""
    R._frog_base(body)
    L.decimate_to(body, 3600)
    gold_lo, gold_hi, pearl = D("d89820"), D("fff0a0"), C("fff8ec")

    def paint(name, co, n, info):
        if name == "Frog_Secondary":
            return L.mix(C("ffe8d0"), pearl, L.smooth(1.0, 1.8, co.z)) if R._frog_is_belly(co) else C("ff8ab4")
        c = L.mix(gold_lo, gold_hi, L.smooth(0.4, 2.5, co.z) * 0.6 + max(0.0, n.z) * 0.4)
        c = L.mix(c, D("c88a28"), max(0.0, n.y) * 0.3)
        return L.mix(c, D("fff6c8"), max(0.0, -n.z) * 0.4)

    K.paint_body(body, paint, all_keep)
    surf, parts = start(body)
    parts.mode = "keep"
    w = {"Head": 1.0}
    for sx in (-1.0, 1.0):
        M.sparkly_eye(parts, V((0.31 * sx, -0.43, 2.46)), 0.205, V((0.35 * sx, -1.0, 0.05)).normalized(),
                      C("0e4a34"), C("4ae0a0"), w, iris=0.62, pupil=0.3, lid=D("e8b840"))
        p, n = M.front_hit(surf, 0.38 * sx, 2.2)
        M.cheek(parts, p, n, 0.07, 0.04, C("ffa0b8"))
    R._frog_toes(parts, arm, body, lambda u: L.mix(C("ff8ab4"), C("ffe0ec"), L.smooth(-0.5, 0.8, u.z)),
                 lambda u: L.mix(C("e8a020"), C("ffe680"), L.smooth(-0.5, 0.8, u.z)))
    p, n = M.front_hit(surf, 0.0, 2.2)
    smile = [(x / 10.0 * 0.16, -0.035 * (1.0 - (x / 10.0) ** 2)) for x in range(-10, 11)]
    parts.stroke(p, n, smile, 0.035, C("8a3a20"), lift=0.012)
    # Jewel on the brow, between the eyes.
    p, n = M.front_hit(surf, 0.0, 2.5)
    if p is not None:
        glow_spot(parts, p, n, 0.06, C("2ae8a0"), C("e0fff0"), weights=w)
    # Pink petal markings over the back and arms (pairs of petals).
    for d in [V((0.35, 1.0, 0.3)), V((-0.4, 1.0, -0.2)), V((0.1, 1.0, -0.6)), V((0.6, 0.6, -0.4)),
              V((-0.75, 0.3, 0.1)), V((0.75, 0.3, 0.1)), V((-0.3, 0.6, 0.9))]:
        q, qn = M.dir_hit(surf, V((0, 0.1, 1.6)), d)
        if q is not None:
            for rot in (0.6, 0.0, -0.6):
                pts = [(x, y + 0.07) for x, y in M.ellipse(0.028, 0.07, 12)]
                pts = [(x * math.cos(rot) - y * math.sin(rot), x * math.sin(rot) + y * math.cos(rot)) for x, y in pts]
                parts.decal(q, qn, [(x, y - 0.04) for x, y in pts], C("ff86b4"), rings=1)
    # Lotus crown on the head.
    apex, an = M.dir_hit(surf, V((0, 0.1, 2.3)), V((0, 0.35, 1)))
    if apex is not None:
        lotus(parts, apex + V((0, 0, 0.06)), (an + V((0, 0, 1.2))).normalized(), 0.4, w, outer=9, inner=6)
    # Collar of lotus petals round the neck.
    neck = V((0, 0.12, 1.98))
    for i in range(12):
        a = 2.0 * math.pi * i / 12
        d = V((math.cos(a), math.sin(a) * 0.9, -0.15))
        q, qn = M.dir_hit(surf, neck, d)
        if q is None or (q - neck).length > 0.8:
            continue
        parts.blob(q - qn * 0.02, (0.13, 0.05), (qn + V((0, 0, -0.9))).normalized(), 0.3, None,
                   weights={"Torso": 0.5, "Neck": 0.5}, seg=6, rings=4, tip=0.35, color_fn=lotus_petal_col, up=qn)
    # A lily pad over the back like a shawl.
    q, qn = M.dir_hit(surf, V((0, 0.1, 1.55)), V((0, 1, 0.25)))
    if q is not None:
        def pad(u):
            a = math.atan2(u.y, u.x)
            r = math.hypot(u.x, u.y)
            vein = L.smooth(0.85, 0.98, abs(math.cos(a * 5.0))) * L.smooth(0.15, 0.4, r)
            c = L.mix(C("2e8a3a"), C("6ac850"), L.smooth(-0.3, 0.9, u.z) * 0.7 + r * 0.3)
            return L.mix(c, C("b8f080"), vein * 0.7)
        parts.ellipsoid(q + qn * 0.06, (0.62, 0.55, 0.05), M.basis(qn), color=None, weights=q, seg=20, rings=8,
                        color_fn=pad)
    finish(body, parts)


# ================================================================ registry / runner

RECIPES = {
    "big/Fish_abyss_angler": abyss_angler,
    "big/Frog_lotus_frog": lotus_frog,
}


def source(name):
    """The rig a variant is built from: remaster/<dir>/<Name>_<id> -> <dir>/<Name>."""
    d, f = name.split("/")
    return d + "/" + f.split("_")[0]


SOURCE = {name: source(name) for name in RECIPES}


def build(name):
    R.RECIPES.update(RECIPES)
    R.SOURCE.update(SOURCE)
    R.build(name)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    for name in (args or list(RECIPES)):
        build(name)
