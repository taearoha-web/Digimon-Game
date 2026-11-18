"""Remaster recipes for the fierce monsters (team "brutes"): orcs, demons, golems, ninjas,
yetis, dinos and their bosses. Same pipeline as remaster_monsters.py (see its docstring):

    /opt/bpy5/bin/python tools/blender/recipes_brutes.py [big/Demon ...]

writes assets/models/monsters/remaster/<dir>/<Name>.glb (all recipes with no argument).
remaster_monsters.py registers these recipes too. Design rule: no blush, no googly eyes -
glowing slit / narrow eyes under heavy lids, brows, tusks, horns, scars, runes, fur.
Several rigs are shared by tinted monsters (MonsterData "tint" multiplies Skin / Detail /
Glow): their skin is painted in light, low-saturation tones so every tint reads, while
bone, tusks and fixed-colour eyes sit on the untinted Ivory / IvoryGlow materials.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import remaster_lib as L  # noqa: E402
import kit_brutes as K  # noqa: E402
from mathutils import Vector  # noqa: E402

L.export = K.export  # unlit Glow, base colour factors (no-op for other models)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "assets", "models", "monsters")
OUT = os.path.join(SRC, "remaster")

C = L.srgb
SKIN, DETAIL, GLOW, IVORY, IVORY_GLOW = K.SKIN, K.DETAIL, K.GLOW, K.IVORY, K.IVORY_GLOW
WHITE = C("ffffff")


# ---------------------------------------------------------------- big/Demon

def demon(arm, body):
    """hell_orc (red) and void_emperor (violet boss): a horned, winged demon lord.
    Burnt-black hands and feet, lighter chest, glowing ember cracks over the chest and
    arms (tinted: lava red / void violet), fiery untinted eyes under a scowling brow,
    ivory fangs and lower tusks, obsidian-to-bone horns, the halo turned into a glowing
    ring of hellfire."""
    keys = K.regions(body)
    BODY, DARK, EYE, PUPIL = "b25868", "666966", "c5c7d0", "606266"
    K.tag_regions(body, keys)
    L.delete_faces(body, ("R_" + EYE, "R_" + PUPIL))
    crisp = K.split_where(body, lambda p: body.data.materials[p.material_index].name == "R_" + DARK)
    L.clean(body)
    L.subdivide(body, 1)
    L.decimate_to(body, 4100)
    L.relax(body, 2, 0.4)
    L.clean(crisp, quads=False)
    halo = K.face_islands(crisp, lambda p: abs(p.center.x) < 0.42 and p.center.z > 2.7 and abs(p.center.y) < 0.42)
    K.retag(crisp, {v for _c, _h, vs in halo for v in vs}, "R_halo")
    L.join(body, crisp)

    chest, main, back, burnt = C("f0d2c8"), C("cf9e94"), C("94635f"), C("2e2228")

    def paint(region, co, n, info):
        bone = info["bone"]
        r = region[2:]
        if r == "halo":
            return C("fff0d8"), GLOW  # the halo, turned into a ring of hellfire
        if r == DARK:
            if bone == "Middle1.L" or bone.startswith(("Index", "Pinky", "Thumb", "Middle")):
                # the trident: dark iron, bright edges
                return L.mix(C("2a2830"), C("8a8898"), L.smooth(0.0, 0.03, info["bump"])), IVORY

            if bone == "Head":  # horns: obsidian roots, bone tips
                t = L.smooth(2.5, 3.0, co.z)
                return L.mix(C("1e1820"), C("efe2c8"), t ** 1.3), IVORY
            # wing frame
            return L.mix(C("231c22"), C("4a3a40"), L.smooth(1.7, 2.3, co.z)), IVORY
        if bone == "Neck" and co.y > 0.4:  # wing membrane, darker to the edges
            d = (co - Vector((0.0, 0.5, 1.9))).length
            return L.mix(C("d6a49a"), C("5a3438"), L.smooth(0.35, 1.15, d))
        c = L.mix(back, main, L.smooth(0.45, -0.2, n.y))
        c = L.mix(c, chest, L.smooth(-0.35, -0.9, n.y) * L.smooth(0.9, 1.4, co.z) * L.smooth(2.3, 1.9, co.z))
        # burnt extremities: hands, forearm ends, feet and shins
        ext = max(L.smooth(1.25, 1.75, abs(co.x)), L.smooth(0.55, 0.15, co.z))
        c = L.mix(c, burnt, ext * 0.92)
        return c

    K.paint(body, paint)
    surf = L.Surface(body)
    parts = K.BParts(surf)
    head = {"Head": 1.0}
    lid = C("b07a74")
    for sx in (-1.0, 1.0):
        c = Vector((0.31 * sx, -0.47, 2.2))
        gaze = Vector((0.28 * sx, -1.0, 0.05)).normalized()
        K.fierce_eye(parts, c, 0.135, gaze, sx, C("fff6b0"), C("ff7a10"), head, lid=lid, open_=0.5,
                     glow_mat=IVORY_GLOW)
        # heavy brow ridge, low over the nose
        K.ridge(parts, Vector((0.5 * sx, -0.4, 2.42)), Vector((0.07 * sx, -0.6, 2.3)), 0.075, C("8a5550"), head,
                bulge=Vector((0, -0.05, 0.04)), tip=0.7)
        # upper fangs hanging over the lip, lower tusks jutting up
        K.fang(parts, Vector((0.14 * sx, -0.6, 1.98)), Vector((0.05 * sx, -0.25, -1.0)), 0.2, 0.045, head)
        K.fang(parts, Vector((0.26 * sx, -0.58, 1.86)), Vector((0.12 * sx, -0.3, 1.0)), 0.24, 0.055, head,
               root=C("d8c6a0"), bend=Vector((0.02 * sx, -0.05, 0.0)))
        # bone spikes on the shoulders
        for k, (dx, dz) in enumerate(((0.0, 0.0), (0.18, -0.06), (-0.16, -0.04))):
            p, n = K.dir_hit(surf, Vector((0.62 * sx + dx * sx, 0.15, 1.8)), Vector((0.35 * sx, 0.2, 1.0)))
            if p is not None:
                K.horn(parts, p - n * 0.03, (n + Vector((0.2 * sx, 0.1, 0.5))).normalized(), 0.26 - 0.06 * k,
                       0.06 - 0.01 * k, p, C("231c22"), C("efe2c8"), seg=8, rings=5)
    p, n = K.front_hit(surf, 0.0, 1.96)
    with parts.on(DETAIL):
        parts.stroke(p, n, [(x / 8.0 * 0.32, -0.04 * (1.0 - (x / 8.0) ** 2) - 0.02 * abs(x / 8.0)) for x in
                            range(-8, 9)], 0.05, C("2a0e12"), lift=0.012, taper=True)
    # Ember cracks: over the chest and down the arms.
    rng = random.Random(11)
    ember = C("ffe2c0")
    for (x, z, head_a, ln) in ((0.25, 1.55, -1.9, 0.55), (-0.3, 1.45, -1.2, 0.5), (0.05, 1.2, -1.6, 0.45),
                               (0.4, 1.25, -2.2, 0.35), (-0.15, 1.75, -0.6, 0.35)):
        p, n = K.front_hit(surf, x, z)
        if p is not None:
            K.glow_path(parts, p, n, K.crack_path(rng, ln, 6, 0.3, heading=head_a), 0.055, ember)
    for sx in (-1.0, 1.0):
        for k in range(2):
            p, n = K.dir_hit(surf, Vector((0.9 * sx + 0.3 * k * sx, 0.05, 1.82)), Vector((0, -0.3, 1.0)))
            if p is not None:
                K.glow_path(parts, p, n, K.crack_path(rng, 0.35, 5, 0.25, heading=0.0 if sx > 0 else math.pi), 0.035,
                            ember, up=Vector((0, -1, 0)))
    # a row of spines down the back
    for k, z in enumerate((2.45, 2.2, 1.95, 1.7, 1.45)):
        p, n = K.dir_hit(surf, Vector((0, 0.1, z)), Vector((0, 1.0, 0.15)))
        if p is not None:
            K.horn(parts, p - n * 0.03, (n + Vector((0, 0.0, 0.45))).normalized(), 0.34 - 0.035 * k, 0.07 - 0.007 * k,
                   p, C("231c22"), C("efe2c8"), seg=8, rings=5)
    K.join_parts(body, parts.to_object())
    K.bake_ao(body)


# ---------------------------------------------------------------- big/BlueDemon

def stone_golem(arm, body):
    """thunder_golem (yellow) and void_golem (violet): the goblin rig recut as a stone
    golem - flat-shaded faceted slate (untinted, so both share real stone), glowing cracks,
    eye slits, mouth and chest core on Glow (tinted: lightning yellow / void violet),
    boulder pauldrons and crystal growths that take the tint, a stone club with rune bands."""
    keys = K.regions(body)
    BODY, CLUB, WRAP, EYE, PUPIL, CLOTH = "79a6b7", "bfa985", "c5c7d0", "c5c7d0", "606266", "d2be5d"
    K.tag_regions(body, keys)
    groups = L.dominant_groups(body)
    L.delete_faces(body, ("R_" + PUPIL,), where=lambda c, n, g: n == "R_" + EYE and g == "Head")
    club = K.split_where(body, lambda p: body.data.materials[p.material_index].name in ("R_" + CLUB, "R_" + WRAP))
    L.clean(body)
    L.decimate_to(body, 2900)
    L.relax(body, 1, 0.3)
    L.clean(club, quads=False)
    L.join(body, club)
    lo, hi = L.bounds(body)
    slate_hi, slate, slate_lo = C("d4d4d2"), C("a6a8ac"), C("676a72")

    def stone(co, n, seed=0):
        c = L.mix(slate_lo, slate, L.smooth(0.0, 1.3, co.z))
        c = L.mix(c, slate_hi, L.smooth(1.6, 2.7, co.z) * 0.7 + max(0.0, n.z) * 0.25)
        j = K.hash01(co * 3.0, seed) - 0.5
        return c * (1.0 + j * 0.22)

    def paint(region, co, n, info):
        r = region[2:]
        cen = info["poly"]
        if r == CLUB:
            return stone(cen, n, 3) * 0.85, IVORY
        if r == WRAP:
            return L.mix(C("4a3a2c"), C("7a6450"), K.hash01(cen * 9.0)), IVORY  # leather grip
        if r == CLOTH:
            return C("5a4a3a"), IVORY
        return stone(cen, n), IVORY

    K.paint(body, paint)
    surf = L.Surface(body)
    parts = K.BParts(surf)
    head = {"Head": 1.0}
    glow, glow_core = C("fff6dc"), C("ffffff")
    for sx in (-1.0, 1.0):
        p, n = K.front_hit(surf, 0.33 * sx, 2.28)
        gaze = (n + Vector((0, -0.6, 0))).normalized()
        up = K.rot_about(Vector((0, 0, 1)), gaze, 0.42 * sx)
        side = gaze.cross(up).normalized()
        b = K.Matrix((side, up, gaze)).transposed()
        slit = [(sx * (-0.15 + 0.3 * i / 8.0), -0.06 + 0.12 * i / 8.0 + 0.03 * math.sin(math.pi * i / 8.0))
                for i in range(9)]
        with parts.on(DETAIL):
            parts.stroke(p, n, slit, 0.15, C("1e2028"), lift=0.014, weights=head)
        with parts.on(GLOW):
            parts.stroke(p, n, slit, 0.07, glow_core, lift=0.03, weights=head)
        # brow: a heavy slab of rock jutting over the eye slit
        K.ridge(parts, p + side * 0.2 * sx + up * 0.13 - gaze * 0.03, p - side * 0.2 * sx + up * 0.1 - gaze * 0.03,
                0.085, lambda t: stone(Vector((0, 0, 2.3)), Vector((0, 0, 1))) * (0.95 - 0.1 * t), head,
                bulge=gaze * 0.06 + up * 0.03, tip=0.75, mat=IVORY, seg=7, rings=5)
    # a jagged glowing mouth
    p, n = K.front_hit(surf, 0.0, 1.98)
    mouth = [(-0.3, 0.02), (-0.2, -0.03), (-0.1, 0.01), (0.0, -0.05), (0.1, 0.01), (0.2, -0.03), (0.3, 0.02)]
    with parts.on(DETAIL):
        parts.stroke(p, n, mouth, 0.1, C("1e2028"), lift=0.012, taper=False, weights=head)
    K.glow_path(parts, p, n, mouth, 0.04, glow_core)
    # chest core: a glowing gem set in a dark ring, cracks running out of it
    p, n = K.front_hit(surf, 0.0, 1.45)
    with parts.on(DETAIL):
        parts.decal(p, n, K.ellipse(0.17, 0.2, 16), C("1e2028"), rings=2)
    with parts.on(GLOW):
        parts.ellipsoid(p - n * 0.03, (0.11, 0.08, 0.15), K.basis(n), color=None, weights=p, seg=4, rings=4,
                        color_fn=lambda u: L.mix(glow_core, glow, abs(u.z)))
    rng = random.Random(7)
    for a in (0.5, 1.4, 2.4, 3.6, 4.6, 5.6):
        d = Vector((math.cos(a), 0, math.sin(a)))
        q, m = K.front_hit(surf, d.x * 0.24, 1.45 + d.z * 0.24)
        if q is not None:
            path = K.crack_path(rng, 0.45, 5, 0.25, heading=a)
            with parts.on(DETAIL):
                parts.stroke(q, m, path, 0.07, C("1e2028"), lift=0.01)
            K.glow_path(parts, q, m, path, 0.03, glow)
    # cracks over the back, the arms and the thighs
    for (c, d, heading, ln) in ((Vector((0, 0, 1.6)), Vector((0.2, 1, 0.3)), 1.2, 0.7),
                                (Vector((0, 0, 1.2)), Vector((-0.3, 1, -0.1)), -0.4, 0.6),
                                (Vector((0.95, 0.05, 1.82)), Vector((0, -0.2, 1)), 0.1, 0.5),
                                (Vector((-0.95, 0.05, 1.82)), Vector((0, -0.2, 1)), 3.0, 0.5),
                                (Vector((0.35, 0.2, 0.6)), Vector((0.6, -1, 0)), 1.7, 0.35),
                                (Vector((-0.35, 0.2, 0.6)), Vector((-0.6, -1, 0)), 1.4, 0.35),
                                (Vector((0, 0, 2.3)), Vector((0.2, -0.4, 1.0)), 0.2, 0.35)):
        q, m = K.dir_hit(surf, c, d)
        if q is not None:
            path = K.crack_path(rng, ln, 6, 0.3, heading=heading)
            with parts.on(DETAIL):
                parts.stroke(q, m, path, 0.065, C("1e2028"), lift=0.01)
            K.glow_path(parts, q, m, path, 0.028, glow)
    # boulder pauldrons and crystal growths (crystals take the tint)
    for sx in (-1.0, 1.0):
        q, m = K.dir_hit(surf, Vector((0.75 * sx, 0.15, 1.75)), Vector((0.3 * sx, 0.1, 1.0)))
        if q is not None:
            K.rock(parts, q + m * 0.05, 0.3, lambda u: stone(Vector((0, 0, 2.0)), u) * 0.95, q, seed=int(10 + sx),
                   squash=(1.15, 1.0, 0.7), up=m)
            for k in range(3):
                dd = (m + Vector((0.35 * sx * (k - 1), 0.5 + 0.2 * k, 0.6))).normalized()
                K.crystal(parts, q + m * 0.18 + Vector((0.1 * sx * (k - 1), 0.12, 0.0)), dd, 0.42 - 0.08 * abs(k - 1),
                          0.08, q, C("c8ccd8"), C("ffffff"), mat=SKIN)
    for k, (x, z) in enumerate(((0.3, 2.0), (-0.25, 1.75), (0.05, 1.35))):
        q, m = K.dir_hit(surf, Vector((x, 0.0, z)), Vector((x * 0.6, 1.0, 0.25)))
        if q is not None:
            K.crystal(parts, q - m * 0.03, (m + Vector((0, 0.1, 0.55))).normalized(), 0.5 - 0.08 * k, 0.1, q,
                      C("c8ccd8"), C("ffffff"), mat=SKIN)
    # rune bands of light around the club
    cv = [v.co for v, g in zip(body.data.vertices, L.dominant_groups(body)) if g == "Middle1.L"]
    for yb in (-0.62, -1.0):
        ring = [v for v in cv if abs(v.y - yb) < 0.22]
        if ring:
            cx = sum(v.x for v in ring) / len(ring)
            cz = sum(v.z for v in ring) / len(ring)
            rad = max(math.hypot(v.x - cx, v.z - cz) for v in ring)
            with parts.on(GLOW):
                parts.frustum(Vector((cx, yb + 0.025, cz)), Vector((0, -1, 0)), rad * 0.8, rad * 0.8, 0.05,
                              lambda t, side_: glow, {"Middle1.L": 1.0}, seg=10)
    K.join_parts(body, parts.to_object())
    K.flat(body, (IVORY, SKIN))
    K.bake_ao(body, strength=0.5)


# ---------------------------------------------------------------- big/Alien

def swamp_beast(arm, body):
    """swamp_dino: a bog monster. Mottled moss-and-mud hide (darker back, sallow belly),
    warts, moss hanging off the shoulders and head, the curly feelers turned into dripping
    swamp-weed fronds, sickly glowing slit eyes under heavy lids, a jagged maw with
    yellowed teeth. Painted through its green tint (pre-compensated)."""
    tint = (0.7, 1.3, 0.7)
    P = lambda h: K.pre(C(h), tint)  # noqa: E731
    keys = K.regions(body)
    BODY, WEED, BELLY, MOUTH, PUPIL = "9b70a8", "97b77e", "c5c7d0", "a17e93", "606266"
    K.tag_regions(body, keys)
    L.delete_faces(body, ("R_" + PUPIL,), where=lambda c, n, g: n == "R_" + BELLY and g == "Head")
    L.clean(body)
    L.subdivide(body, 1)
    L.decimate_to(body, 4400)
    L.relax(body, 2, 0.4)
    back, hide, belly, mud = C("5f7834"), C("86a04a"), C("d6cf86"), C("6e6034")

    def paint(region, co, n, info):
        r = region[2:]
        if r == WEED:  # swamp weed: dark roots, yellow-green tips, banded
            if abs(co.x) > 0.55:  # the curls by the ears
                t = L.smooth(0.6, 1.05, abs(co.x))
            elif co.z > 2.7:  # the horns
                t = L.smooth(2.6, 3.5, co.z)
            else:  # the snout
                t = 0.45
            c = L.mix(C("2e5a22"), C("b8e05a"), t)
            c = L.mix(c, C("1e4018"), L.smooth(0.55, 0.8, K.noise(co, 6.0, 3)) * 0.5)
            return K.pre(c, tint)
        if r == MOUTH:
            return K.pre(L.mix(C("200a0c"), C("6a2026"), L.smooth(-0.6, -0.2, n.y) * 0.5), tint)
        c = L.mix(back, hide, L.smooth(0.5, -0.4, n.y))
        if r == BELLY or (co.y < -0.3 and abs(co.x) < 0.45 and 0.9 < co.z < 1.8):
            c = L.mix(c, belly, 0.85 if r == BELLY else 0.5)
        m = K.fbm(co, 1.6, 7)
        c = L.mix(c, C("3e4a1e"), L.smooth(0.55, 0.75, m) * 0.55)  # dark blotches
        c = L.mix(c, C("b8c070"), L.smooth(0.42, 0.3, m) * 0.4)  # sallow patches
        c = L.mix(c, mud, L.smooth(0.7, 0.15, co.z))  # mud-caked legs
        return K.pre(c, tint)

    K.paint(body, paint)
    surf = L.Surface(body)
    parts = K.BParts(surf)
    head = {"Head": 1.0}
    lid = P("6a8238")
    for sx in (-1.0, 1.0):
        c = Vector((0.3 * sx, -0.43, 2.3))
        gaze = Vector((0.3 * sx, -1.0, 0.0)).normalized()
        K.fierce_eye(parts, c, 0.13, gaze, sx, C("f4ff8a"), C("7ab018"), head, lid=lid, open_=0.48,
                     glow_mat=IVORY_GLOW, slant=0.3)
        K.ridge(parts, Vector((0.48 * sx, -0.36, 2.52)), Vector((0.08 * sx, -0.58, 2.42)), 0.075, P("56702e"), head,
                bulge=Vector((0, -0.05, 0.03)), tip=0.7)
    # jagged yellowed teeth around the maw
    p, n = K.front_hit(surf, 0.0, 1.98)
    for k, x in enumerate((-0.13, -0.065, 0.0, 0.065, 0.13)):
        q, m = K.front_hit(surf, x * 1.2, 2.07)
        if q is not None:
            K.fang(parts, q + Vector((0, 0.02, 0)), Vector((0.1 * x, -0.35, -1.0)), 0.12 + 0.04 * (k % 2), 0.034, head,
                   root=C("b8a868"), tip_col=C("f0e8c0"), seg=6, rings=3)
        q, m = K.front_hit(surf, x * 0.9, 1.9)
        if q is not None and k % 2 == 0:
            K.fang(parts, q + Vector((0, 0.02, 0)), Vector((0.1 * x, -0.35, 1.0)), 0.1, 0.03, head,
                   root=C("b8a868"), tip_col=C("f0e8c0"), seg=6, rings=3)
    # warts over the back, shoulders and crown
    rng = random.Random(4)
    placed = []
    for d in K.fibonacci(160):
        if d.y < -0.35 and abs(d.x) < 0.6:
            continue
        p, n = K.dir_hit(surf, Vector((0, 0.05, 1.7)), d)
        if p is None or p.z < 0.7 or any((p - q).length < 0.22 for q in placed) or len(placed) > 26:
            continue
        placed.append(p)
        s = rng.uniform(0.035, 0.065)
        parts.ellipsoid(p, (s, s, s * 0.6), K.basis(n), color=None, weights=p, seg=6, rings=4,
                        color_fn=lambda u: K.pre(L.mix(C("5a6a2e"), C("c4d07a"), L.smooth(-0.2, 0.9, u.z)), tint))
    # moss hanging off the shoulders, the back of the head and the arms
    dirs = [d for d in K.fibonacci(90) if d.z > 0.15 and d.y > -0.2]
    K.tufts(parts, surf, Vector((0, 0.1, 1.9)), dirs, 0.22, 0.045, K.pre(C("3e6a24"), tint), K.pre(C("b4dc5a"), tint),
            seed=5, per=2, droop=0.9, lift_out=0.5, skip=lambda p, n: p.z < 1.6, seg=5, rings=3)
    for sx in (-1.0, 1.0):
        arm_dirs = [Vector((0.0, 0.3, 1.0)).normalized()]
        for k in range(5):
            K.tufts(parts, surf, Vector((sx * (0.6 + 0.22 * k), 0.15, 1.82)), arm_dirs, 0.2, 0.04,
                    K.pre(C("3e6a24"), tint), K.pre(C("b4dc5a"), tint), seed=10 + k, per=2, droop=1.2,
                    lift_out=0.3, seg=5, rings=3)
    # slime sheen streaks on the head and belly
    for (x, z) in ((-0.25, 2.65), (0.18, 1.45)):
        p, n = K.front_hit(surf, x, z)
        if p is not None:
            with parts.on(DETAIL):
                parts.stroke(p, n, [(math.cos(a) * 0.12, math.sin(a) * 0.1) for a in
                                    [math.radians(d) for d in range(100, 180, 15)]], 0.035,
                             K.pre(C("d8f0a0"), tint), lift=0.016)
    K.join_parts(body, parts.to_object())
    K.bake_ao(body, shade=Vector((0.5, 0.55, 0.45)))


RECIPES = {
    "big/Demon": demon,
    "big/BlueDemon": stone_golem,
    "big/Alien": swamp_beast,
}


def build(name):
    import bpy
    L.reset()
    arm, body = L.load(os.path.join(SRC, name + ".gltf"))
    clips = sorted(a.name for a in bpy.data.actions)
    before = L.tri_count(body)
    RECIPES[name](arm, body)
    out = os.path.join(OUT, name + ".glb")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    L.export(arm, body, out, clips)
    print("REMASTER %s tris %d -> %d, %d bytes, mats %s" % (name, before, L.tri_count(body), os.path.getsize(out),
                                                         ",".join(m.name for m in body.data.materials)))


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    for name in (args or list(RECIPES)):
        build(name)
