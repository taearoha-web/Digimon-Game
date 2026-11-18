"""Team critters' remaster recipes (see remaster_monsters.py for the pipeline).

    /opt/bpy5/bin/python tools/blender/recipes_critters.py [big/Bunny ...]

Same contract as remaster_monsters.RECIPES, built with kit_critters' material set so
eyes, teeth and glowing marks stay untinted ("Keep..." materials). A few outputs are
VARIANTS of a shared rig for one monster only (big/FrogKing = toad_king): they are
written to remaster/<dir>/<Variant>.glb and that monster's "model" points at
"remaster/<dir>/<Variant>" directly.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import remaster_lib as L  # noqa: E402
import kit_critters as K  # noqa: E402
import remaster_monsters as M  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

C = L.srgb
WHITE = C("ffffff")
V = Vector


def start(body, parts_cls=K.KParts):
    surf = L.Surface(body)
    return surf, parts_cls(surf)


def finish(body, parts, **ao):
    K.join_parts(body, parts.to_object())
    K.bake_ao(body, **ao)


def cute_eye(parts, *a, **kw):
    with parts.use("keep"):
        M.sparkly_eye(parts, *a, **kw)


# ================================================================ big/Frog (pilot fix + variants)

def _frog_base(body):
    L.delete_faces(body, ("Eye_White", "Eye_Black"))
    L.clean(body)


def _frog_is_belly(co):
    return abs(co.x) < 0.45 and co.z < 2.2 and co.y < 0.0


def _frog_toes(parts, arm, body, pad_fn, toe_fn):
    groups = L.dominant_groups(body)
    for sx in (-1.0, 1.0):
        side = "L" if sx > 0 else "R"
        for f in ("Index3", "Middle3", "Pinky3", "Thumb2"):
            b = arm.data.bones["%s.%s" % (f, side)]
            parts.ellipsoid(b.tail_local, (0.065, 0.065, 0.055), color=None, weights={b.name: 1.0}, seg=8, rings=5,
                            color_fn=pad_fn)
        foot = [body.data.vertices[i].co for i, g in enumerate(groups) if g == "Foot." + side]
        if foot:
            fy = min(v.y for v in foot)
            fz = min(v.z for v in foot)
            cx = sum(v.x for v in foot) / len(foot)
            for k in (-1, 0, 1):
                parts.ellipsoid(V((cx + 0.13 * k, fy + 0.05 + 0.03 * abs(k), fz + 0.05)), (0.07, 0.07, 0.05),
                                color=None, weights={"Foot." + side: 1.0}, seg=8, rings=5, color_fn=toe_fn)


def yellow_frog(arm, body):
    """Cute yellow poison frog (also lotus_frog, the summon frog): the pilot look, with the
    eyes and the cream belly on untinted materials so every tint keeps them clean."""
    _frog_base(body)
    yellow_top, yellow_low, belly, spot = C("ffe14d"), C("ffc233"), C("fff2b8"), C("2a2350")

    def paint(name, co, n, info):
        if name == "Frog_Secondary":
            return L.mix(belly, C("fffbe6"), L.smooth(1.0, 1.8, co.z)) if _frog_is_belly(co) else spot
        c = L.mix(yellow_low, yellow_top, L.smooth(0.5, 2.5, co.z))
        c = L.mix(c, C("ff9a1e"), max(0.0, n.y) * 0.25)
        return L.mix(c, C("fff3a0"), max(0.0, -n.z) * 0.4)

    K.paint_body(body, paint, lambda name, c, n, bone: "keep" if name == "Frog_Secondary" and _frog_is_belly(c)
                 else "skin")
    surf, parts = start(body)
    for sx in (-1.0, 1.0):
        cute_eye(parts, V((0.31 * sx, -0.43, 2.46)), 0.205, V((0.35 * sx, -1.0, 0.12)).normalized(),
                 C("2a1606"), C("e89a14"), {"Head": 1.0}, iris=0.62, pupil=0.36)
        p, n = M.front_hit(surf, 0.37 * sx, 2.22)
        M.cheek(parts, p, n, 0.075, 0.045, C("ff9a78"))
    _frog_toes(parts, arm, body, lambda u: L.mix(C("ffd36a"), C("fff4b0"), L.smooth(-0.5, 0.8, u.z)),
               lambda u: L.mix(C("ffc84a"), C("fff0a0"), L.smooth(-0.5, 0.8, u.z)))
    p, n = M.front_hit(surf, 0.0, 2.2)
    smile = [(x / 10.0 * 0.2, -0.06 * (1.0 - (x / 10.0) ** 2)) for x in range(-10, 11)]
    parts.stroke(p, n, smile, 0.04, C("7a3410"), lift=0.012)
    for d, s in [(V((0.35, 1.0, 0.3)), 0.11), (V((-0.4, 1.0, -0.2)), 0.09), (V((0.1, 1.0, -0.6)), 0.08),
                 (V((-0.2, 1.0, 0.8)), 0.07), (V((0.6, 0.6, -0.4)), 0.06), (V((-0.75, 0.3, 0.1)), 0.06)]:
        p, n = M.dir_hit(surf, V((0, 0.1, 1.6)), d)
        if p is not None:
            parts.decal(p, n, M.ellipse(s, s * 0.85, 16, rot=0.4), spot, rings=2)
    for sx in (-1.0, 1.0):
        p, n = M.dir_hit(surf, V((0.35 * sx, 0.2, 0.75)), V((0.8 * sx, 0.3, 0.2)))
        if p is not None:
            parts.decal(p, n, M.ellipse(0.07, 0.06, 14), spot, rings=2)
    finish(body, parts)


def toxic_frog(arm, body):
    """Deadly dart frog (toxic_frog only): near-black green hide laced with glowing neon
    venom stripes and glands, narrow glowing red eyes, a grim mouth dripping venom.
    Painted final colours (untinted)."""
    _frog_base(body)
    hide, hide_hi, under = C("173a26"), C("3f8a4a"), C("a8d84a")
    neon, neon_hi = C("8cff2a"), C("eaff8a")

    def paint(name, co, n, info):
        if name == "Frog_Secondary" and _frog_is_belly(co):
            return L.mix(C("6a9a2a"), under, L.smooth(1.0, 1.9, co.z))
        c = L.mix(hide, hide_hi, L.smooth(0.3, 2.4, co.z) * 0.5 + max(0.0, -n.y) * 0.35)
        return L.mix(c, C("4a7a3a"), max(0.0, -n.z) * 0.4)

    K.paint_body(body, paint, lambda *a: "keep")
    surf, parts = start(body)
    parts.mode = "keep"
    for sx in (-1.0, 1.0):
        K.fierce_eye(parts, V((0.31 * sx, -0.43, 2.46)), 0.205, V((0.3 * sx, -1.0, 0.1)).normalized(), C("ffb02a"),
                     C("ff1a1a"), {"Head": 1.0}, lid=C("1f4a2a"), slant=0.4, side=sx, slit=True, pupil_w=0.5,
                     iris=0.8, sclera=C("ffd23a"), glow=True, lid_drop=1.7)
    _frog_toes(parts, arm, body, lambda u: L.mix(C("1a3a1a"), C("4a8a2a"), L.smooth(-0.5, 0.8, u.z)),
               lambda u: L.mix(C("1a3a1a"), C("4a8a2a"), L.smooth(-0.5, 0.8, u.z)))
    p, n = M.front_hit(surf, 0.0, 2.2)
    grim = [(x / 10.0 * 0.26, -0.07 * (x / 10.0) ** 2 + 0.02) for x in range(-10, 11)]
    parts.stroke(p, n, grim, 0.045, C("050805"), lift=0.012, taper=False)
    with parts.use("glow"):
        q, qn = M.front_hit(surf, 0.2, 2.13)
        parts.ellipsoid(q + qn * 0.02, (0.03, 0.03, 0.055), color=neon, weights={"Head": 1.0}, seg=8, rings=6)
        # Neon venom stripes: down the spine sides and along each flank, eye to thigh.
        for sx in (-1.0, 1.0):
            for (y0, sweep) in ((0.6, 0.55), (0.0, 1.0)):
                path = []
                for k in range(9):
                    t = k / 8.0
                    p, n = M.dir_hit(surf, V((0, 0.15, 2.35 - 1.5 * t)), V((sx * sweep, y0 + 0.4, 0.15 - 0.2 * t)))
                    if p is not None:
                        path.append((p, n))
                for (p0, n0), (p1, n1) in zip(path, path[1:]):
                    d = p1 - p0
                    side = n0.cross(d).normalized() * 0.04
                    mid = (p0 + p1) * 0.5
                    parts.decal(mid, n0, [(-0.04, -d.length * 0.55), (0.04, -d.length * 0.55),
                                          (0.04, d.length * 0.55), (-0.04, d.length * 0.55)], neon, rings=1,
                                up=d.normalized(), lift=0.014)
        # Glowing venom glands.
        rng = random.Random(11)
        placed = []
        for d in M.fibonacci(80):
            if d.y < 0.1 or len(placed) >= 9:
                continue
            p, n = M.dir_hit(surf, V((0, 0.1, 1.5)), d)
            if p is None or p.z < 0.7 or any((p - q).length < 0.32 for q in placed):
                continue
            placed.append(p)
            s = rng.uniform(0.05, 0.08)
            parts.ellipsoid(p + n * 0.005, (s, s, s * 0.55), M.basis(n), color=None, weights=p, seg=8, rings=5,
                            color_fn=lambda u: L.mix(neon, neon_hi, L.smooth(-0.2, 1.0, u.z)))
        for sx in (-1.0, 1.0):
            for k in range(3):
                p, n = M.dir_hit(surf, V((0.35 * sx, 0.2, 1.0 - 0.25 * k)), V((0.9 * sx, -0.3, 0.1)))
                if p is not None:
                    parts.decal(p, n, M.ellipse(0.05, 0.04, 10), neon, rings=1)
            # Bands across the arms (seen from the front and the game camera above).
            for k in range(4):
                x = 0.55 + 0.32 * k
                p, n = M.dir_hit(surf, V((x * sx, 0.17, 1.82)), V((0, -0.3, 1.0)))
                if p is not None:
                    parts.decal(p, n, M.ellipse(0.06, 0.05, 12), neon, rings=1, lift=0.014)
            # Flank spots seen from the front.
            for k, (x, z) in enumerate(((0.5, 1.75), (0.55, 1.35), (0.45, 0.95), (0.62, 2.05))):
                p, n = M.front_hit(surf, x * sx, z)
                if p is not None:
                    parts.decal(p, n, M.ellipse(0.045, 0.04, 10), neon, rings=1)
    finish(body, parts)


def toad_king(arm, body):
    """Royal toad boss (toad_king only): stout warty royal-purple body with a golden belly,
    an ermine collar, a jewelled gold crown, heavy-lidded haughty eyes, a stern wide mouth."""
    _frog_base(body)
    purple, dusk, wart, gold, ink = C("8a4fc8"), C("40206e"), C("b48ae8"), C("ffd36a"), C("2a1240")

    def paint(name, co, n, info):
        if name == "Frog_Secondary":
            return L.mix(C("e8a83a"), gold, L.smooth(0.8, 1.9, co.z)) if _frog_is_belly(co) else ink
        c = L.mix(dusk, purple, L.smooth(0.3, 2.4, co.z) * 0.6 + max(0.0, -n.y) * 0.4)
        c = L.mix(c, C("2e1650"), max(0.0, n.y) * 0.4)
        return L.mix(c, C("c8a0e8"), max(0.0, -n.z) * 0.4)

    K.paint_body(body, paint, lambda *a: "keep")
    # Stouter (after painting, so the belly keeps its shape): belly and hips out, broader jowls.
    K.scale_region(body, lambda c: c.z < 2.0 and abs(c.x) < 0.75, V((0, 0.15, 1.3)), (1.22, 1.22, 1.0),
                   lambda c: L.smooth(0.3, 0.9, c.z) * L.smooth(2.05, 1.6, c.z))
    K.scale_region(body, lambda c: c.z >= 1.95 and abs(c.x) < 0.7, V((0, 0.0, 2.25)), (1.12, 1.06, 1.0),
                   lambda c: L.smooth(1.95, 2.15, c.z))
    body.data.update()
    surf, parts = start(body)
    parts.mode = "keep"
    eye_c = [V((0.33 * sx, -0.45, 2.46)) for sx in (-1.0, 1.0)]
    for sx, c in zip((-1.0, 1.0), eye_c):
        K.fierce_eye(parts, c, 0.205, V((0.3 * sx, -1.0, 0.05)).normalized(), C("fff0a0"),
                     C("e0901a"), {"Head": 1.0}, lid=C("7a46b8"), slant=0.12, side=sx, slit=True, pupil_w=0.5,
                     iris=0.72, sclera=C("fff6dc"), lid_drop=1.1)
    _frog_toes(parts, arm, body, lambda u: L.mix(C("c88a1a"), gold, L.smooth(-0.5, 0.8, u.z)),
               lambda u: L.mix(C("c88a1a"), gold, L.smooth(-0.5, 0.8, u.z)))
    p, n = M.front_hit(surf, 0.0, 2.2)
    stern = [(x / 10.0 * 0.32, -0.06 * (x / 10.0) ** 2 + 0.01) for x in range(-10, 11)]
    parts.stroke(p, n, stern, 0.05, C("1a0a28"), lift=0.012, taper=False)
    # Warts on the back and crown of the head.
    rng = random.Random(4)
    for d in M.fibonacci(46):
        if d.y < 0.0:
            continue
        p, n = M.dir_hit(surf, V((0, 0.1, 1.5)), d)
        if p is None or p.z < 0.7 or abs(p.x) > 0.8:
            continue
        s = rng.uniform(0.04, 0.075)
        parts.ellipsoid(p, (s, s, s * 0.6), M.basis(n), color=None, weights=p, seg=7, rings=4,
                        color_fn=lambda u: L.mix(C("6a3aa8"), C("d2b0f2"), L.smooth(-0.2, 1.0, u.z)))
    # Ermine collar around the neck.
    neck = V((0, 0.12, 1.98))
    for i in range(18):
        a = 2.0 * math.pi * i / 18
        d = V((math.cos(a), math.sin(a) * 0.9, -0.1))
        p, n = M.dir_hit(surf, neck, d)
        if p is None or (p - neck).length > 0.75:
            continue
        parts.ellipsoid(p + n * 0.05, (0.14, 0.14, 0.11), color=None, weights={"Torso": 0.5, "Neck": 0.5}, seg=9,
                        rings=6, color_fn=lambda u: L.mix(C("dcd6ea"), WHITE, L.smooth(-0.6, 0.7, u.z)))
        if i % 3 == 0:
            parts.ellipsoid(p + n * 0.18 + V((0, 0, -0.03)), (0.028, 0.028, 0.05), color=C("1a1420"),
                            weights={"Torso": 0.5, "Neck": 0.5}, seg=6, rings=4)
    # Jewelled gold crown.
    apex, _an = M.dir_hit(surf, V((0, 0.0, 2.3)), V((0, 0.2, 1)))
    gold_hi, gold_dk = C("fff0a0"), C("c8841a")
    base = apex - V((0, 0, 0.08))
    w = {"Head": 1.0}
    parts.frustum(base, V((0, 0, 1)), 0.36, 0.43, 0.24,
                  lambda t, side: L.mix(gold_dk, C("ffd84a"), 0.35 + 0.65 * t) if side else C("8a1030"), w, seg=24)
    for i in range(5):
        a = math.pi * 0.5 + 2.0 * math.pi * i / 5
        rim = base + V((math.cos(a) * 0.4, math.sin(a) * 0.4, 0.2))
        dd = V((math.cos(a) * 0.2, math.sin(a) * 0.2, 1.0)).normalized()
        parts.blob(rim, (0.1, 0.06), dd, 0.26, None, weights=w, seg=8, rings=5, tip=0.2,
                   color_fn=lambda a_: L.mix(gold_dk, gold_hi, a_), up=V((math.cos(a), math.sin(a), 0)))
        parts.ellipsoid(rim + dd * 0.27, (0.05, 0.05, 0.05), color=None, weights=w, seg=8, rings=5,
                        color_fn=lambda u: L.mix(C("1a8a5a"), C("b0ffd8"), L.smooth(0.0, 1.0, u.z)))
    parts.ellipsoid(base + V((0, -0.42, 0.12)), (0.09, 0.045, 0.1), color=None, weights=w, seg=12, rings=8,
                    color_fn=lambda u: L.mix(C("c4103c"), C("ff8aa8"), L.smooth(-0.3, 1.0, u.z)))
    finish(body, parts)


# ================================================================ registry / runner

RECIPES = {
    "big/Frog": yellow_frog,
    "big/FrogToxic": toxic_frog,
    "big/FrogKing": toad_king,
}
SOURCE = {"big/FrogToxic": "big/Frog", "big/FrogKing": "big/Frog"}


def build(name):
    import bpy
    L.reset()
    arm, body = L.load(os.path.join(M.SRC, SOURCE.get(name, name) + ".gltf"))
    clips = sorted(a.name for a in bpy.data.actions)
    before = L.tri_count(body)
    RECIPES[name](arm, body)
    out = os.path.join(M.OUT, name + ".glb")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    K.export(arm, body, out, clips)
    print("REMASTER %s tris %d -> %d, %d bytes, clips %s" % (name, before, L.tri_count(body), os.path.getsize(out),
                                                          ",".join(clips)))


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    for name in (args or list(RECIPES)):
        build(name)
